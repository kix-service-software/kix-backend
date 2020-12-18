# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
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

    my %ChangeByMapping;

    $Self->InitProgress(Type => $Param{Type}, ItemCount => scalar(@{$SourceData}));

    foreach my $Item ( @{$SourceData} ) {
        my %Contact;

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

        # some special handling if the login already exists
        if ( $ID ) {
            $Item->{login} = 'Migration-'.$Item->{login}; 
            # do the lookup again
            goto LOOKUP;
        }

        # insert row
        if ( !$ID ) {
            my $ChangeBy = $Item->{change_by};

            $Item->{is_agent}    = 1;
            $Item->{is_customer} = 1;
            $Item->{comments}    = $Preferences{$Item->{id}}->{UserComment};
            $Item->{pw}        //= '';
            $Item->{change_by}   = 1;        # set to user_id that exists for sure to prevent ring deps

            $ID = $Self->Insert(
                Table          => 'users',
                PrimaryKey     => 'id',
                Item           => $Item,
                AutoPrimaryKey => 1,
            );

            # build the mapping for later
            $ChangeByMapping{$ID} = $ChangeBy;
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

            # create associated contact
            $Success = $Kernel::OM->Get('Contact')->ContactAdd(
                AssignedUserID => $ID,
                Firstname      => $Contact{first_name},
                Lastname       => $Contact{last_name},
                Title          => $Contact{title},
                Phone          => $Contact{UserPhone},
                Mobile         => $Contact{UserMobile},
                Email          => $Contact{UserEmail},
                ValidID        => 1,
                UserID         => 1,
            );
            if ( !$Success ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unable to create contact for user $ID!"
                );
            }

            # assign role
            foreach my $Role ( 'Agent User', 'Customer' ) {
                my $RoleID = $Kernel::OM->Get('Role')->RoleLookup(
                    Role => $Role
                );
                if ( !$RoleID ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => "No role \"$Role\" found!"
                    );
                    next;
                }
                my $Success = $Kernel::OM->Get('Role')->RoleUserAdd(
                    RoleID       => $RoleID,
                    AssignUserID => $ID,
                    UserID       => 1,
                );
                if ( !$Success ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => "Unable to assign \"$Role\" to user $ID!"
                    );
                }
            }
        }
        else {
            $Self->UpdateProgress($Param{Type}, 'Error');
        }
    }

    if ( %ChangeByMapping ) {
        foreach my $ID ( sort keys %ChangeByMapping ) {
            my $MappedID = $Self->GetOIDMapping(
                ObjectType     => 'users',
                SourceObjectID => $ChangeByMapping{$ID}
            );

            $Self->Update(
                Table      => 'users',
                PrimaryKey => 'id',
                Item       => {
                    id        => $ID,
                    change_by => $MappedID
                },
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
