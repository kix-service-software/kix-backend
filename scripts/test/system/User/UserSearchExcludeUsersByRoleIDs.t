# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
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

# get needed objects
my $UserObject    = $Kernel::OM->Get('User');
my $RoleObject    = $Kernel::OM->Get('Role');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my ($RoleIDAdmin, $RoleIDAdminNoBase, $RoleIDTicket, $RoleIDTicketBaseNone, $RoleIDQueue3, %LoginRoleMapping, %LoginUserIDMapping, @Tests);
_CreateRoles();

if ($RoleIDAdmin && $RoleIDTicket && $RoleIDQueue3) {
    %LoginRoleMapping = (
        'UserSearchTestAdmin'               => [$RoleIDAdmin],
        'UserSearchTestAdminNobase'         => [$RoleIDAdminNoBase],
        'UserSearchTestTicket'              => [$RoleIDTicket],
        'UserSearchTestTicketBaseNone'      => [$RoleIDTicketBaseNone],
        'UserSearchTestAdminTicket'         => [$RoleIDAdmin,$RoleIDTicket],
        'UserSearchTestAdminTicketBaseNone' => [$RoleIDAdmin,$RoleIDTicketBaseNone],
        'UserSearchTestAdminNoBaseTicketBaseNone' => [$RoleIDAdminNoBase,$RoleIDTicketBaseNone],
        'UserSearchTestTicketQueue3'        => [$RoleIDQueue3]
    );
    _CreateUsers();

    if (scalar(keys %LoginRoleMapping) == scalar(keys %LoginUserIDMapping)) {

        # forbid admin roles
        my $Succes = _SetConfig();

        if ($Succes) {
            @Tests = (
                {
                    Result => ["UserSearchTestTicket", "UserSearchTestAdminTicket"],
                    Name   => 'Only allowed roles'
                },
                {
                    Result => ["UserSearchTestAdmin", "UserSearchTestTicket", "UserSearchTestAdminTicket"],
                    Name   => 'Only allowed roles + given user id exception',
                    UserID => $LoginUserIDMapping{UserSearchTestAdmin}
                },
                # FIXME: currently not usable - see KIX2018-11535
                # {
                #     Result      => ["UserSearchTestTicketQueue3"],
                #     Name        => 'Only allowed roles + queue 3',
                #     ObjectID    => 3
                # },
                {
                    Result   => ["UserSearchTestAdminTicket", "UserSearchTestTicket"],
                    Name     => 'Only allowed roles + queue 8',
                    ObjectID => 8
                },
            );

            _DoTests();
        }

        # allow all roles
        $Succes = _SetConfig([]);

        # remove cache so config change is considered
        $Kernel::OM->Get('Cache')->CleanUp( Type => $UserObject->{CacheType});

        if ($Succes) {
            @Tests = (
                {
                    Result => ["UserSearchTestAdmin", "UserSearchTestAdminNobase", "UserSearchTestTicket", "UserSearchTestAdminTicket", 'UserSearchTestAdminTicketBaseNone'],
                    Name   => 'No roles forbidden'
                },
                {
                    Result => ["UserSearchTestAdmin", "UserSearchTestAdminNobase", "UserSearchTestTicket", "UserSearchTestAdminTicket", "UserSearchTestAdminTicketBaseNone"],
                    Name   => 'No roles forbidden + given user id exception',
                    UserID => $LoginUserIDMapping{UserSearchTestAdmin}
                },
                # FIXME: currently not usable - see KIX2018-11535
                # {
                #     Result      => ["UserSearchTestAdmin", "UserSearchTestAdminNobase", "UserSearchTestTicketQueue3", "UserSearchTestAdminTicketBaseNone"],
                #     Name        => 'No roles forbidden + queue 3',
                #     ObjectID    => 3
                # },
                {
                    Result   => ["UserSearchTestAdmin", "UserSearchTestAdminNobase", "UserSearchTestTicket", "UserSearchTestAdminTicket", "UserSearchTestAdminTicketBaseNone"],
                    Name     => 'No roles forbidden + queue 8',
                    ObjectID => 8
                },
            );

            _DoTests();
        }
    }
    else {
        $Self->Is(
            scalar(keys %LoginRoleMapping),
            scalar(keys %LoginUserIDMapping),
            "Size of LoginRoleMapping do not match LoginUserIDMapping",
        );
    }
}

sub _CreateRoles {
    $RoleIDAdmin = $RoleObject->RoleAdd(
        Name         => 'TestRole_Admin',
        UsageContext => Kernel::System::Role->USAGE_CONTEXT->{AGENT},
        ValidID      => 1,
        UserID       => 1
    );
    $Self->True(
        $RoleIDAdmin,
        "RoleAdd() - Admin role ($RoleIDAdmin)",
    );
    if ($RoleIDAdmin) {
        # all resoucre
        $RoleObject->PermissionAdd(
            RoleID     => $RoleIDAdmin,
            TypeID     => 1,
            Target     => '/*',
            Value      => Kernel::System::Role::Permission::PERMISSION_CRUD,
            UserID     => 1
        );
        # all object
        $RoleObject->PermissionAdd(
            RoleID     => $RoleIDAdmin,
            TypeID     => 2,
            Target     => '/*{}',
            Value      => Kernel::System::Role::Permission::PERMISSION_CRUD,
            UserID     => 1
        );
        # all properties
        $RoleObject->PermissionAdd(
            RoleID     => $RoleIDAdmin,
            TypeID     => 3,
            Target     => '/*{}',
            Value      => Kernel::System::Role::Permission::PERMISSION_CRUD,
            UserID     => 1
        );
        # all Base::Ticket
        $RoleObject->PermissionAdd(
            RoleID     => $RoleIDAdmin,
            TypeID     => 4,
            Target     => '*',
            Value      => Kernel::System::Role::Permission::PERMISSION_CRUD,
            UserID     => 1
        );
    }


    $RoleIDAdminNoBase = $RoleObject->RoleAdd(
        Name         => 'TestRole_AdminNoBase',
        UsageContext => Kernel::System::Role->USAGE_CONTEXT->{AGENT},
        ValidID      => 1,
        UserID       => 1
    );
    $Self->True(
        $RoleIDAdminNoBase,
        "RoleAdd() - AdminNoBase role ($RoleIDAdminNoBase)",
    );
    if ($RoleIDAdminNoBase) {
        # all resoucre
        $RoleObject->PermissionAdd(
            RoleID     => $RoleIDAdminNoBase,
            TypeID     => 1,
            Target     => '/*',
            Value      => Kernel::System::Role::Permission::PERMISSION_CRUD,
            UserID     => 1
        );
        # all object
        $RoleObject->PermissionAdd(
            RoleID     => $RoleIDAdminNoBase,
            TypeID     => 2,
            Target     => '/*{}',
            Value      => Kernel::System::Role::Permission::PERMISSION_CRUD,
            UserID     => 1
        );
        # all properties
        $RoleObject->PermissionAdd(
            RoleID     => $RoleIDAdminNoBase,
            TypeID     => 3,
            Target     => '/*{}',
            Value      => Kernel::System::Role::Permission::PERMISSION_CRUD,
            UserID     => 1
        );
    }

    $RoleIDTicket = $RoleObject->RoleAdd(
        Name         => 'TestRole_Ticket',
        UsageContext => Kernel::System::Role->USAGE_CONTEXT->{AGENT},
        ValidID      => 1,
        UserID       => 1
    );
    $Self->True(
        $RoleIDTicket,
        "RoleAdd() - Ticket role ($RoleIDTicket)",
    );
    if ($RoleIDTicket) {
        # all tickets
        $RoleObject->PermissionAdd(
            RoleID     => $RoleIDTicket,
            TypeID     => 1,
            Target     => '/tickets',
            Value      => Kernel::System::Role::Permission::PERMISSION_CRUD,
            UserID     => 1
        );
        # all Base::Ticket
        $RoleObject->PermissionAdd(
            RoleID     => $RoleIDTicket,
            TypeID     => 4,
            Target     => '*',
            Value      => Kernel::System::Role::Permission::PERMISSION_CRUD,
            UserID     => 1
        );
        # but not Queue 3
        $RoleObject->PermissionAdd(
            RoleID     => $RoleIDTicket,
            TypeID     => 4,
            Target     => '3',
            Value      => Kernel::System::Role::Permission::PERMISSION->{DENY},
            UserID     => 1
        );
    }

    $RoleIDTicketBaseNone = $RoleObject->RoleAdd(
        Name         => 'TestRole_TicketBaseNone',
        UsageContext => Kernel::System::Role->USAGE_CONTEXT->{AGENT},
        ValidID      => 1,
        UserID       => 1
    );
    $Self->True(
        $RoleIDTicketBaseNone,
        "RoleAdd() - TicketBaseNone role ($RoleIDTicketBaseNone)",
    );
    if ($RoleIDTicketBaseNone) {
        # all tickets
        $RoleObject->PermissionAdd(
            RoleID     => $RoleIDTicketBaseNone,
            TypeID     => 1,
            Target     => '/tickets',
            Value      => Kernel::System::Role::Permission::PERMISSION_CRUD,
            UserID     => 1
        );
        # no Base::Ticket
        $RoleObject->PermissionAdd(
            RoleID     => $RoleIDTicketBaseNone,
            TypeID     => 4,
            Target     => '*',
            Value      => Kernel::System::Role::Permission::PERMISSION->{NONE},
            UserID     => 1
        );
    }

    $RoleIDQueue3 = $RoleObject->RoleAdd(
        Name         => 'TestRole_Queue3',
        UsageContext => Kernel::System::Role->USAGE_CONTEXT->{AGENT},
        ValidID      => 1,
        UserID       => 1
    );
    $Self->True(
        $RoleIDQueue3,
        "RoleAdd() - Queue3 role ($RoleIDQueue3)",
    );
    if ($RoleIDQueue3) {
        # all tickets
        $RoleObject->PermissionAdd(
            RoleID     => $RoleIDQueue3,
            TypeID     => 1,
            Target     => '/tickets',
            Value      => Kernel::System::Role::Permission::PERMISSION_CRUD,
            UserID     => 1
        );
        # Base::Ticket only queue 3
        $RoleObject->PermissionAdd(
            RoleID     => $RoleIDQueue3,
            TypeID     => 4,
            Target     => '3',
            Value      => Kernel::System::Role::Permission::PERMISSION_CRUD,
            UserID     => 1
        );
    }
}

sub _SetConfig {
    my ($Value) = @_;
    $Value //= [$RoleIDAdmin, $RoleIDAdminNoBase];
    my $Success;

    $Kernel::OM->Get('Config')->Set(
        Key   => 'ExcludeUsersByRoleIDs',
        Value => $Value
    );
    my $ConfigValue = $Kernel::OM->Get('Config')->Get('ExcludeUsersByRoleIDs');
    $Self->True(
        IsArrayRef($ConfigValue) ? 1 : 0,
        "Check Config() - is array ref",
    );
    if (IsArrayRef($ConfigValue)) {
        $Self->Is(
            scalar(@{$ConfigValue}),
            scalar(@{$Value}),
            "Check Config() - length",
        );
        $Success = scalar(@{$ConfigValue}) == scalar(@{$Value}) ? 1 : 0;
        if ($Success && IsArrayRefWithData($Value)) {
            $Success = $Self->IsDeeply(
                $ConfigValue,
                $Value,
                'Check Config() - value',
            );
        }
    }
    return $Success;
}

sub _CreateUsers {
    for my $Login (keys %LoginRoleMapping) {
        my $UserID = $UserObject->UserAdd(
            UserLogin    => $Login,
            ValidID      => 1,
            ChangeUserID => 1,
            IsAgent      => 1
        );
        $Self->True(
            $UserID,
            "UserAdd() - $Login",
        );

        if ($UserID) {
            $LoginUserIDMapping{$Login} = $UserID;
            if (IsArrayRefWithData($LoginRoleMapping{$Login})) {
                for my $RoleID ( @{$LoginRoleMapping{$Login}} ) {
                    my $Success = $RoleObject->RoleUserAdd(
                        AssignUserID => $UserID,
                        RoleID       => $RoleID,
                        UserID       => 1,
                    );
                    $Self->True(
                        $Success ? 1 : 0,
                        "RoleUserAdd() - $Login ($RoleID)",
                    );
                }
            }
        }
    }
}

sub _DoTests {
    for my $Test (@Tests) {
        my %List = $UserObject->UserSearch(
            UserLogin       => 'UserSearchTest*',
            IsAgent         => 1,
            ValidID         => 1,
            HasPermission   => {
                Object => 'Queue',
                ObjectID => $Test->{ObjectID},
                Permission => 'WRITE,READ'
            },
            ExcludeUsersByRoleIDsIgnoreUserIDs => $Test->{UserID} ? [$Test->{UserID}] : undef
        );

        $Self->Is(
            scalar(keys %List),
            scalar( @{ $Test->{Result} } ),
            "UserSearch() - $Test->{Name}",
        );

        if ( IsHashRefWithData(\%List) && IsArrayRefWithData($Test->{Result}) ) {
            my %ReversedList = reverse(%List);

            for my $ResultValue ( @{$Test->{Result}} ) {
                $Self->ContainedIn(
                    $ResultValue,
                    [keys %ReversedList],
                    'UserSearch() - value included'
                );
            }
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
