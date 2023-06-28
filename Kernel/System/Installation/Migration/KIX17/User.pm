# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Installation::Migration::KIX17::User;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::Installation::Migration::KIX17::Common
);

our @ObjectDependencies = (
    'Config',
    'DB',
    'Log',
);

=item Describe()

describe what is supported and what is required

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    return {
        Supports => [
            'users'
        ],
    }
}

=item Run()

create a new item in the DB

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # get source data
    my $SourceData = $Self->GetSourceData(Type => 'users', OrderBy => 'id');

    # bail out if we don't have something to todo
    return if !IsArrayRefWithData($SourceData);

    # prepare preferences
    my $PreferencesData = $Self->GetSourceData(Type => 'user_preferences', NoProgress => 1);
    my %Preferences;
    foreach my $Item ( @{$PreferencesData} ) {
        $Preferences{$Item->{user_id}}->{$Item->{preferences_key}} = $Item->{preferences_value};
    }

    my %UserReferenceMapping;

    $Self->InitProgress(Type => $Param{Type}, ItemCount => scalar(@{$SourceData}));

    # migrate as long as there are users to migrate
    foreach my $Item ( @{$SourceData} ) {
        my %Contact;
        my $CreatedContactID;

        # prepare contact attributes
        foreach my $Attr ( qw( title first_name last_name ) ) {
            $Contact{$Attr} = $Item->{$Attr};
        }
        foreach my $Attr ( qw( UserMobile UserPhone UserEmail ) ) {
            $Contact{$Attr} = $Preferences{$Item->{id}}->{$Attr}
        }

        # check if this object is already mapped
        my $MappedID = $Self->GetOIDMapping(
            ObjectType     => 'users',
            SourceObjectID => $Item->{id}
        );
        if ( $MappedID ) {
            $Self->UpdateProgress($Param{Type}, 'Ignored');
            next;
        }

        # special handling for UserID 1
        if ( $Item->{id} == 1 ) {
            $Item->{login} = 'admin';
        }

        # check if this item already exists (i.e. some initial data)
        LOOKUP:
        my $ID = $Self->Lookup(
            Table        => 'users',
            PrimaryKey   => 'id',
            Item         => $Item,
            RelevantAttr => [
                'login'
            ],
        );
        next if $Item->{id} == 1;

        # insert row
        if ( !$ID ) {
            my $CreateBy = $Item->{create_by};
            my $ChangeBy = $Item->{change_by};

            $Item->{is_agent}    = 1;
            $Item->{is_customer} = 1;
            $Item->{comments}    = $Preferences{$Item->{id}}->{UserComment};
            $Item->{pw}        //= '';
            $Item->{create_by}   = 1;        # set to user_id that exists for sure to prevent ring deps
            $Item->{change_by}   = 1;        # set to user_id that exists for sure to prevent ring deps

            $ID = $Self->Insert(
                Table          => 'users',
                PrimaryKey     => 'id',
                Item           => $Item,
                AutoPrimaryKey => 1,
            );

            # build the mapping for later
            $UserReferenceMapping{$ID} = {
                change_by => $ChangeBy,
                create_by => $CreateBy,
            };
        }

        if ( $ID ) {
            $Self->UpdateProgress($Param{Type}, 'OK');

            # set language preference
            my $Success = $Kernel::OM->Get('User')->SetPreferences(
                Key    => 'UserLanguage',
                Value  => $Preferences{$Item->{id}}->{UserLanguage},
                UserID => $ID,
            );
            if ( !$Success ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unable to set language preference for user $ID!"
                );
            }

            # check if there already is a contact
            my $ContactID = $Self->Lookup(
                Table        => 'contact',
                PrimaryKey   => 'id',
                IgnoreCase   => 1,
                Item         => {
                    'firstname' => $Contact{first_name},
                    'lastname'  => $Contact{last_name},
                    'email'     => $Contact{UserEmail},
                },
                RelevantAttr => [
                    'firstname',
                    'lastname',
                    'email'
                ]
            );

            if ( !$ContactID ) {
                # create associated contact
                $CreatedContactID = $Kernel::OM->Get('Contact')->ContactAdd(
                    AssignedUserID => $ID,
                    Firstname      => $Contact{first_name},
                    Lastname       => $Contact{last_name},
                    Title          => $Contact{title},
                    Phone          => $Contact{UserPhone},
                    Mobile         => $Contact{UserMobile},
                    Email          => $Contact{UserEmail},
                    ValidID        => $Item->{valid_id},
                    UserID         => 1,
                );
                if ( !$CreatedContactID ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => "Unable to create contact for user $ID!"
                    );
                }
            }
            else {
                # assign contact if not already assigned
                my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
                    ID => $ContactID
                );
                if ( !$Contact{AssignedUserID} ) {
                    $Self->Update(
                        Table      => 'contact',
                        PrimaryKey => 'id',
                        Item       => {
                            id      => $ContactID,
                            user_id => $ID,
                        },
                    );
                }
                else {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => "Found matching contact $ContactID but it's already assigned to a different user ID $Contact{AssignedUserID}!"
                    );
                }
            }

            my $UserObject = $Kernel::OM->Get('User');

            # delete user cache
            $Kernel::OM->Get('Cache')->CleanUp(
                Type => $UserObject->{CacheType},
            );

            # assign role
            my $Success = $UserObject->_AssignRolesByContext(
                UserID => $ID,
            );
            if ( !$Success ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unable to assign context roles to user $ID!"
                );
            }
        }
        else {
            $Self->UpdateProgress($Param{Type}, 'Error');
        }
    }

    if ( %UserReferenceMapping ) {
        foreach my $ID ( sort keys %UserReferenceMapping ) {
            my %Item = (
                id => $ID,
            );
            foreach my $RefAttr ( sort keys %{$UserReferenceMapping{$ID}} ) {
                my $MappedID = $Self->GetOIDMapping(
                    ObjectType     => 'users',
                    SourceObjectID => $UserReferenceMapping{$ID}->{$RefAttr},
                );
                $Item{$RefAttr} = $MappedID;
            }

            # update the references
            $Self->Update(
                Table      => 'users',
                PrimaryKey => 'id',
                Item       => \%Item,
            );
        }
    }

    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
