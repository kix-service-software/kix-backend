# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Installation::Migration::KIX17::CustomerUser;

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
            'customer_user'
        ],
        DependsOnType => [
            'customer_company'
        ],
        Depends => {
            'create_by' => 'users',
            'change_by' => 'users',
        }
    }
}

=item Run()

create a new item in the DB

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $EmailUniqueCheck = $Kernel::OM->Get('Config')->Get('ContactEmailUniqueCheck');

    # get source data
    my $SourceData = $Self->GetSourceData(Type => 'customer_user');

    # bail out if we don't have something to todo
    return if !IsArrayRefWithData($SourceData);

    # prepare preferences
    my $PreferencesData = $Self->GetSourceData(Type => 'customer_preferences', NoProgress => 1);

    my %Preferences;
    foreach my $Item ( @{$PreferencesData} ) {
        $Preferences{$Item->{user_id}}->{$Item->{preferences_key}} = $Item->{preferences_value};
    }

    my $Now = $Kernel::OM->Get('Time')->CurrentTimestamp();

    $Self->InitProgress(Type => $Param{Type}, ItemCount => scalar(@{$SourceData}));

    foreach my $Item ( @{$SourceData} ) {

        # remember the CustomerID
        my $CustomerID = $Item->{customer_id};

        # data for new user
        my %User = (
            login       => $Item->{login},
            pw          => $Item->{pw} || '',
            valid_id    => $Item->{valid_id},
            create_time => $Now,
            create_by   => 1,
            change_time => $Now,
            change_by   => 1,
        );

        # map renamed attributes
        $Item->{firstname} = $Item->{first_name};
        $Item->{lastname}  = $Item->{last_name};

        # check if this object is already mapped
        my $MappedID = $Self->GetOIDMapping(
            ObjectType     => 'contact',
            SourceObjectID => $Item->{login}
        );
        if ( $MappedID ) {
            $Self->UpdateProgress($Param{Type}, 'Ignored');
            next;
        }

        # check if this item already exists (i.e. some initial data)
        my @RelevantAttr;
        if ( $EmailUniqueCheck ) {
            @RelevantAttr = ( 'email' );
        }
        else {
            @RelevantAttr = ( 'firstname', 'lastname', 'email' );
        }
        
        my $ID = $Self->Lookup(
            Table        => 'contact',
            PrimaryKey   => 'id',
            IgnoreCase   => 1,
            Item         => $Item,
            RelevantAttr => \@RelevantAttr
        );

        # insert row
        if ( !$ID ) {
            # check and assign user
            $Item->{user_id} = $Self->_AssignUser(
                Item        => $Item,
                User        => \%User,
                Preferences => $Preferences{$User{login}}
            );

            $ID = $Self->Insert(
                Table          => 'contact',
                PrimaryKey     => 'id',
                Item           => $Item,
                AutoPrimaryKey => 1,
                SourceObjectID => $User{login}
            );

            # check an assigned organisation
            if ( $CustomerID ) {
                $Self->_AssignOrganisation(
                    ContactID  => $ID,
                    CustomerID => $CustomerID
                );
            }
        }

        if ( $ID ) {
            $Self->UpdateProgress($Param{Type}, 'OK');
        }
        else {
            $Self->UpdateProgress($Param{Type}, 'Error');
        }
    }

    return 1;
}

sub _AssignUser {
    my ( $Self, %Param ) = @_;
    my $Result;

    # check needed params
    for my $Needed (qw(Item User)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # check for user with the same login
    my $UserID = $Kernel::OM->Get('User')->UserLookup(
        UserLogin => $Param{User}->{login},
        Silent    => 1
    );

    if ( !$UserID ) {
        # add Customer context
        $Param{User}->{is_customer} = 1;

        # create associated user
        $UserID = $Self->Insert(
            Table          => 'users',
            PrimaryKey     => 'id',
            Item           => $Param{User},
            AutoPrimaryKey => 1,
            NoOIDMapping   => 1,
        );

        if ( !$UserID ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to create user for contact $Param{Item}->{id}!"
            );
        }

        # set language preference
        my $Success = $Kernel::OM->Get('User')->SetPreferences(
            Key    => 'UserLanguage',
            Value  => $Param{Preferences}->{UserLanguage},
            UserID => $UserID,
        );
        if ( !$Success ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to set language preference for user $UserID!"
            );
        }

        # assign role
        foreach my $Role ( 'Customer' ) {
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
                AssignUserID => $UserID,
                UserID       => 1,
            );
            if ( !$Success ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unable to assign role \"$Role\" to user $UserID!"
                );
            }
        }

        $Result = $UserID;
    }
    else {
        # check if the UserID is already assigned to another contact
        my $Exists = $Self->Lookup(
            Table        => 'contact',
            PrimaryKey   => 'id',
            Item         => {
                user_id => $UserID
            },
            RelevantAttr => [
                'user_id',
            ]
        );

        $Result = $UserID if !$Exists;
    }

    return $Result;
}

sub _AssignOrganisation {
    my ( $Self, %Param ) = @_;

    # check needed params
    for my $Needed (qw(ContactID CustomerID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # check for organisation
    my $OrgID = $Kernel::OM->Get('Organisation')->OrganisationLookup(
        Number => $Param{CustomerID},
        Silent => 1,
    );

    if ( $OrgID ) {
        # check if contact-org mapping exists
        my $Success = $Self->Lookup(
            Table        => 'contact_organisation',
            PrimaryKey   => 'contact_id',
            Item         => {
                contact_id => $Param{ContactID},
                org_id     => $OrgID
            },
            RelevantAttr => [
                'contact_id',
                'org_id',
            ]
        );
        if ( !$Success ) {
            $Success = $Self->Insert(
                Table          => 'contact_organisation',
                PrimaryKey     => 'contact_id',
                Item         => {
                    contact_id => $Param{ContactID},
                    org_id     => $OrgID,
                    is_primary => 1,
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
