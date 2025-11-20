# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::System::Role;
use Kernel::System::Role::Permission qw(:all);

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# get needed objects
my $RoleObject = $Kernel::OM->Get('Role');
my $UserObject  = $Kernel::OM->Get('User');

# create test users
my %UserIDByUserLogin;
for my $UserCount ( 0 .. 2 ) {
    my $UserLogin = $Helper->TestUserCreate();
    my $UserID = $UserObject->UserLookup( UserLogin => $UserLogin );

    $UserIDByUserLogin{$UserLogin} = $UserID;
}
my @UserIDs = values %UserIDByUserLogin;

my @InitialRoleIDs = $RoleObject->UserRoleList(
    UserID => $UserIDs[0]
);
$Self->Is(
    scalar( @InitialRoleIDs ),
    1,
    "UserRoleList() - user ID $UserIDs[0] should be assigned to context role"
);

@InitialRoleIDs = $RoleObject->UserRoleList(
    UserID             => $UserIDs[0],
    IgnoreContextRoles => 1
);
$Self->Is(
    scalar( @InitialRoleIDs ),
    0,
    "UserRoleList() - user ID $UserIDs[0] should be assigned to no role beside context role"
);

# create test roles
my %RoleIDByRoleName;
my $RoleNameRandomPartBase = $Helper->GetRandomID();
for my $RoleCount ( 1 .. 3 ) {
    my $RoleName = 'test-permission-role-' . $RoleNameRandomPartBase . '-' . $RoleCount;
    my $RoleID   = $RoleObject->RoleAdd(
        Name    => $RoleName,
        UsageContext => Kernel::System::Role->USAGE_CONTEXT->{AGENT},
        ValidID => 1,
        UserID  => 1,
    );

    $RoleIDByRoleName{$RoleName} = $RoleID;
}
my @RoleIDs = values %RoleIDByRoleName;
#
# Permission tests (users and roles)
#
my @PermissionTests = (
    {
        RoleIDs => [
            $RoleIDs[0], $RoleIDs[1],
        ],
        UserIDs => [
            $UserIDs[1], $UserIDs[2],
        ],
        Permissions => [
            {
                TypeID => 1,
                Target => '/users',
                Value  => Kernel::System::Role::Permission::PERMISSION->{CREATE} + Kernel::System::Role::Permission::PERMISSION->{READ},
            }
        ]
    },
    {
        RoleIDs => [
            $RoleIDs[1],
        ],
        UserIDs => [
            $UserIDs[2],
        ],
        Permissions => [
            {
                TypeID => 1,
                Target => '/tickets/1',
                Value  => Kernel::System::Role::Permission::PERMISSION->{READ},
            }
        ]
    },
    {
        RoleIDs => [
            $RoleIDs[0], $RoleIDs[2],
        ],
        UserIDs => [
            $UserIDs[0], $UserIDs[2],
        ],
        Permissions => [
            {
                TypeID  => 1,
                Target  => '/queues',
                Comment => 'full permission on queues',
                Value   => Kernel::System::Role::Permission::PERMISSION_CRUD,
            },
            {
                TypeID  => 1,
                Target  => '/queues/1',
                Comment => 'read permission on queue 1',
                Value   => Kernel::System::Role::Permission::PERMISSION->{READ},
            }
        ]
    },
    {
        RoleIDs => [
            $RoleIDs[0], $RoleIDs[1], $RoleIDs[2],
        ],
        UserIDs => [
            $UserIDs[0], $UserIDs[1], $UserIDs[2],
        ],
        Permissions => [
            {
                TypeID => 1,
                Target => '/tickets',
                Value  => Kernel::System::Role::Permission::PERMISSION->{READ} + Kernel::System::Role::Permission::PERMISSION->{UPDATE},
            }
        ]
    },
);

my %PermissionTypeList = $RoleObject->PermissionTypeList();

$Self->Is(
    scalar(keys %PermissionTypeList),
    4,
    "PermissionTypeList() - returns 3 permission types"
);

%PermissionTypeList = $RoleObject->PermissionTypeList( Valid => 1 );

$Self->Is(
    scalar(keys %PermissionTypeList),
    4,
    "PermissionTypeList(valid) - returns 3 valid permission types"
);

for my $PermissionTest (@PermissionTests) {

    # add permissions to roles
    for my $RoleID ( @{ $PermissionTest->{RoleIDs} } ) {
        for my $Permission ( @{$PermissionTest->{Permissions}} ) {
            my $Success = $RoleObject->PermissionAdd(
                RoleID  => $RoleID,
                UserID  => 1,
                %{$Permission}
            );

            $Self->True(
                $Success,
                "PermissionAdd() - add permission 0x".sprintf('%04x', $Permission->{Value})." on $Permission->{Target} for role ID $RoleID"
            );
        }
    }

    # add users to roles
    for my $UserID ( @{ $PermissionTest->{UserIDs} } ) {
        for my $RoleID ( @{ $PermissionTest->{RoleIDs} } ) {
            my $Success = $RoleObject->RoleUserAdd(
                RoleID       => $RoleID,
                AssignUserID => $UserID,
                UserID       => 1,
            );

            $Self->True(
                $Success,
                "RoleUserAdd() - assign user ID $UserID to role ID $RoleID "
            );
        }
    }

    # check if the correct users are assigned to the roles (RoleUserGet)
    for my $RoleID ( @{ $PermissionTest->{RoleIDs} } ) {
        my %UserList = map { $_ => 1 } $RoleObject->RoleUserList(
            RoleID => $RoleID,
        );

        for my $UserID ( @{ $PermissionTest->{UserIDs} } ) {
            $Self->True(
                $UserList{$UserID},
                "RoleUserList() - user ID $UserID should be assigned to role ID $RoleID"
            );
        }
    }

    # check if the correct permissions are assigned to the roles (PermissionGet)
    for my $RoleID ( @{ $PermissionTest->{RoleIDs} } ) {
        for my $Permission ( @{ $PermissionTest->{Permissions} } ) {

            my $PermissionID = $RoleObject->PermissionLookup(
                RoleID => $RoleID,
                %{$Permission},
            );

            my %PermissionData = $RoleObject->PermissionGet(
                ID => $PermissionID
            );

            $Self->Is(
                $PermissionData{TypeID}.'::'.sprintf('%04x', $PermissionData{Value}).'::'.$PermissionData{Target},
                $Permission->{TypeID}.'::'.sprintf('%04x', $Permission->{Value}).'::'.$Permission->{Target},
                "PermissionGet() - permission 0x".sprintf('%04x', $Permission->{Value})." on $Permission->{Target} should be assigned to role ID $RoleID"
            );
        }
    }

    # remove users from roles
    for my $UserID ( @{ $PermissionTest->{UserIDs} } ) {
        for my $RoleID ( @{ $PermissionTest->{RoleIDs} } ) {
            my $Success = $RoleObject->RoleUserDelete(
                RoleID => $RoleID,
                UserID => $UserID,
            );

            $Self->True(
                $Success,
                "RoleUserDelete() - remove user ID $UserID from role ID $RoleID"
            );
        }
    }

    # check if the all users are removed from the roles (RoleUserGet)
    for my $RoleID ( @{ $PermissionTest->{RoleIDs} } ) {
        my %UserList = $RoleObject->RoleUserList(
            RoleID => $RoleID,
        );

        for my $UserID ( @{ $PermissionTest->{UserIDs} } ) {
            $Self->False(
                $UserList{$UserID},
                "RoleUserList() - user ID $UserID should not be assigned to role ID $RoleID after deletion"
            );
        }
    }

    # add users to roles
    for my $UserID ( @{ $PermissionTest->{UserIDs} } ) {
        for my $RoleID ( @{ $PermissionTest->{RoleIDs} } ) {
            my $Success = $RoleObject->RoleUserAdd(
                RoleID       => $RoleID,
                AssignUserID => $UserID,
                UserID       => 1,
            );

            $Self->True(
                $Success,
                "RoleUserAdd() - assign user ID $UserID to role ID $RoleID "
            );
        }
    }

    # remove users from roles with one call
    for my $UserID ( @{ $PermissionTest->{UserIDs} } ) {
        my $Success = $RoleObject->RoleUserDelete(
            RoleIDs => $PermissionTest->{RoleIDs},
            UserID  => $UserID,
        );

        $Self->True(
            $Success,
            "RoleUserDelete() - remove user ID $UserID from role IDs " . join( ',', @{ $PermissionTest->{RoleIDs} } )
        );
    }

    # check if the all users are removed from the roles (RoleUserGet)
    for my $RoleID ( @{ $PermissionTest->{RoleIDs} } ) {
        my %UserList = $RoleObject->RoleUserList(
            RoleID => $RoleID,
        );

        for my $UserID ( @{ $PermissionTest->{UserIDs} } ) {
            $Self->False(
                $UserList{$UserID},
                "RoleUserList() - user ID $UserID should not be assigned to role ID $RoleID after deletion"
            );
        }
    }

    # remove permissions from roles
    for my $RoleID ( @{ $PermissionTest->{RoleIDs} } ) {
        for my $Permission ( @{ $PermissionTest->{Permissions} } ) {

            my $PermissionID = $RoleObject->PermissionLookup(
                RoleID => $RoleID,
                %{$Permission}
            );

            my $Success = $RoleObject->PermissionDelete(
                ID => $PermissionID
            );

            $Self->True(
                $Success,
                "PermissionDelete() - remove permission 0x".sprintf('%04x', $Permission->{Value})." on $Permission->{Target} from role ID $RoleID"
            );
        }
    }

    # check if all permissions have been removed from the roles
    for my $RoleID ( @{ $PermissionTest->{RoleIDs} } ) {
        for my $Permission ( @{ $PermissionTest->{Permissions} } ) {

            my $PermissionID = $RoleObject->PermissionLookup(
                RoleID => $RoleID,
                %{$Permission}
            );

            $Self->False(
                $PermissionID,
                "PermissionList() - permission 0x".sprintf('%04x', $Permission->{Value})." on $Permission->{Target} should not be assigned to role ID $RoleID"
            );
        }
    }
}

# rollback transaction on database
$Helper->Rollback();

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
