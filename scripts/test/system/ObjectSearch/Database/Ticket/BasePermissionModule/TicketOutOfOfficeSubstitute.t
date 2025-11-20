# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::System::Role::Permission;

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $ObjectTypeModule = 'Kernel::System::ObjectSearch::Database::Ticket';

# require module
return if ( !$Kernel::OM->Get('Main')->Require( $ObjectTypeModule ) );

# create backend object
my $ObjectTypeObject = $ObjectTypeModule->new(
    %{ $Self },
    ObjectType => 'Ticket'
);
$Self->Is(
    ref( $ObjectTypeObject ),
    $ObjectTypeModule,
    'ObjectType object has correct module ref'
);

# check supported methods
for my $Method ( qw(GetPermissionDef) ) {
    $Self->True(
        $ObjectTypeObject->can($Method),
        'ObjectType object can "' . $Method . '"'
    );
}

# begin transaction on database
$Helper->BeginWork();

# get objectsearch object
my $ObjectSearch = $Kernel::OM->Get('ObjectSearch');

# set fixed time for test
$Helper->FixedTimeSet(
    $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
        String => '2025-10-30 14:00:00',
    )
);

## prepare test datas
my %RoleTypeList = reverse(
    $Kernel::OM->Get('Role')->PermissionTypeList(
        Valid => 0
    )
);

my $Role1 = 'Ticket Agent Base Permission';
my $Role2 = 'UnitTest';

## prepare queue mapping
my $QueueID1 = $Kernel::OM->Get('Queue')->QueueAdd(
    Name                => $Helper->GetRandomID(),
    ValidID             => 1,
    SystemAddressID     => 1,
    Signature           => '',
    Comment             => 'unit test queue',
    UserID              => 1,
);
$Self->True(
    $QueueID1,
    "First queue created"
);

my $QueueID2 = $Kernel::OM->Get('Queue')->QueueAdd(
    Name                => $Helper->GetRandomID(),
    ValidID             => 1,
    SystemAddressID     => 1,
    Signature           => '',
    Comment             => 'unit test queue',
    UserID              => 1,
);
$Self->True(
    $QueueID2,
    "Second queue created"
);

my $QueueID3 = $Kernel::OM->Get('Queue')->QueueAdd(
    Name                => $Helper->GetRandomID(),
    ValidID             => 1,
    SystemAddressID     => 1,
    Signature           => '',
    Comment             => 'unit test queue',
    UserID              => 1,
);
$Self->True(
    $QueueID3,
    "Third queue created"
);
# discard user and role object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Queue'],
);

## prepare role/permission mapping
my $RoleID1 = $Kernel::OM->Get('Role')->RoleLookup(
    Role => $Role1
);
$Self->True(
    $RoleID1,
    "Get Role '$Role1'"
);

my $RoleID2 = $Kernel::OM->Get('Role')->RoleAdd(
    Name         => $Role2,
    ValidID      => 1,
    UsageContext => Kernel::System::Role->USAGE_CONTEXT->{CUSTOMER} + Kernel::System::Role->USAGE_CONTEXT->{AGENT},
    UserID       => 1,
);
$Self->True(
    $RoleID2,
    "Role '$Role2' created"
);
my $PermissionID2 = $Kernel::OM->Get('Role')->PermissionAdd(
    RoleID     => $RoleID2,
    TypeID     => $RoleTypeList{'Base::Ticket'},
    Target     => $QueueID1,
    Value      => Kernel::System::Role::Permission::PERMISSION_CRUD,
    UserID     => 1,
);
$Self->True(
    $PermissionID2,
    "Permission to role '$Role2' created"
);

## prepare user mapping
# first user
my $UserID1 = $Kernel::OM->Get('User')->UserAdd(
    UserLogin     => 'UnitTest1',
    ValidID       => 1,
    ChangeUserID  => 1,
    IsAgent       => 1
);
$Self->True(
    $UserID1,
    'First user created'
);

# second user
my $UserID2 = $Kernel::OM->Get('User')->UserAdd(
    UserLogin     => 'UnitTest2',
    ValidID       => 1,
    ChangeUserID  => 1,
    IsAgent       => 1
);
$Self->True(
    $UserID2,
    'Second user created'
);

my $Result1 = $Kernel::OM->Get('Role')->RoleUserAdd(
    AssignUserID => $UserID2,
    RoleID       => $RoleID1,
    UserID       => 1,
);
$Self->True(
    $Result1,
    "Second user role '$Role1' added"
);

# third user
my $UserID3 = $Kernel::OM->Get('User')->UserAdd(
    UserLogin     => 'UnitTest3',
    ValidID       => 1,
    ChangeUserID  => 1,
    IsAgent       => 1
);
$Self->True(
    $UserID3,
    'Third user created'
);
my $Pref1 = $Kernel::OM->Get('User')->SetPreferences(
    Key    => 'OutOfOfficeStart',
    Value  => '2025-10-29',
    UserID => $UserID2
);
$Self->True(
    $Pref1,
    'Set preference "OutOfOfficeStart" to second user'
);
my $Pref2 = $Kernel::OM->Get('User')->SetPreferences(
    Key    => 'OutOfOfficeEnd',
    Value  => '2025-10-31',
    UserID => $UserID2
);
$Self->True(
    $Pref2,
    'Set preference "OutOfOfficeEnd" to second user'
);
my $Pref3 = $Kernel::OM->Get('User')->SetPreferences(
    Key    => 'OutOfOfficeSubstitute',
    Value  => $UserID3,
    UserID => $UserID2
);
$Self->True(
    $Pref3,
    'Set preferences OutOfOfficeSubstitute for third user'
);

$Kernel::OM->Get('Role')->RoleUserAdd(
    AssignUserID => $UserID3,
    RoleID       => $RoleID1,
    UserID       => 1,
);
$Self->True(
    $UserID2,
    "Third user role '$Role1' added"
);

$Kernel::OM->Get('Role')->RoleUserAdd(
    AssignUserID => $UserID3,
    RoleID       => $RoleID2,
    UserID       => 1,
);
$Self->True(
    $UserID2,
    "Third user role '$Role2' added"
);
# discard user and role object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['User','Role'],
);

## prepare test tickets ##
# first ticket
my $TicketID1 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => $QueueID1,
    Lock           => 'unlock',
    PriorityID     => 1,
    StateID        => 1,
    TypeID         => 1,
    OrganisationID => 1,
    ContactID      => 1,
    OwnerID        => $UserID2,
    ResponsibleID  => $UserID2,
    UserID         => 1
);
$Self->True(
    $TicketID1,
    'Created first ticket'
);
# second ticket
my $TicketID2 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => $QueueID2,
    Lock           => 'unlock',
    PriorityID     => 1,
    StateID        => 1,
    TypeID         => 1,
    OrganisationID => 1,
    ContactID      => 1,
    OwnerID        => $UserID2,
    ResponsibleID  => $UserID2,
    UserID         => 1
);
$Self->True(
    $TicketID2,
    'Created second ticket'
);
# third ticket
my $TicketID3 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => $QueueID3,
    Lock           => 'unlock',
    PriorityID     => 1,
    StateID        => 1,
    TypeID         => 1,
    OrganisationID => 1,
    ContactID      => 1,
    OwnerID        => $UserID2,
    ResponsibleID  => $UserID2,
    UserID         => 1
);
$Self->True(
    $TicketID3,
    'Created third ticket'
);
# fourth ticket
my $TicketID4 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => $QueueID1,
    Lock           => 'unlock',
    PriorityID     => 1,
    StateID        => 1,
    TypeID         => 1,
    OrganisationID => 1,
    ContactID      => 1,
    OwnerID        => 1,
    ResponsibleID  => 1,
    UserID         => 1
);
$Self->True(
    $TicketID4,
    'Created fourth ticket'
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Ticket'],
);

# check GetPermissionDef
my @GetPermissionDefTests = (
    {
        Name      => 'GetPermissionDef: undef parameter',
        Parameter => undef,
        Expected  => {
            Where => [ '0=1' ]
        }
    },
    {
        Name      => 'GetPermissionDef: UserID ' . $UserID1 . ', UserType Agent (No Base Permissions)',
        Parameter => {
            UserID   => $UserID1,
            UserType => 'Agent'
        },
        Expected  => {}
    },
    {
        Name      => 'GetPermissionDef: UserID ' . $UserID2 . ', UserType Agent (Base Permissions, No Team)',
        Parameter => {
            UserID   => $UserID2,
            UserType => 'Agent'
        },
        Expected  => {
            From    => [],
            Having  => [],
            Join    => [],
            OrderBy => [],
            Select  => [],
            Where   => [ "(1=0 OR 1=0)" ]
        }
    },
    {
        Name      => 'GetPermissionDef: UserID ' . $UserID3 . ', UserType Agent (Base Permissions, one Team)',
        Parameter => {
            UserID   => $UserID3,
            UserType => 'Agent'
        },
        Expected  => {
            From    => [],
            Having  => [],
            Join    => [],
            OrderBy => [],
            Select  => [],
            Where   => [ "(st.queue_id IN ($QueueID1) OR st.id IN ($TicketID1,$TicketID2,$TicketID3))" ]
        }
    }
);
for my $Test ( @GetPermissionDefTests ) {
    my $GetPermissionDefReturn = $ObjectTypeObject->GetPermissionDef(
        %{ $Test->{Parameter} || {} }
    );
    $Self->IsDeeply(
        $GetPermissionDefReturn,
        $Test->{Expected},
        $Test->{Name}
    );
}


# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field Fulltext / Operator LIKE / UserID $UserID1 / Result [$TicketID1,$TicketID2,$TicketID3,$TicketID4]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => 'Test'
                }
            ]
        },
        UserID   => $UserID1,
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2,$TicketID3,$TicketID4]
    },
    {
        Name     => 'Search: Field Fulltext / Operator LIKE / UserID $UserID2 / Result []',
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => 'Test'
                }
            ]
        },
        UserID   => $UserID2,
        UserType => 'Agent',
        Expected => []
    },
    {
        Name     => 'Search: Field Fulltext / Operator LIKE / UserID $UserID3 / Result [$TicketID1,$TicketID2,$TicketID3,$TicketID4]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => 'Test'
                }
            ]
        },
        UserID   => $UserID3,
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2,$TicketID3,$TicketID4]
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Ticket',
        Result     => 'ARRAY',
        Search     => $Test->{Search},
        UserType   => $Test->{UserType},
        UserID     => $Test->{UserID},
        Permission => 'UPDATE'
    );
    $Self->IsDeeply(
        \@Result,
        $Test->{Expected},
        $Test->{Name}
    );
}

# rollback transaction on database
$Helper->Rollback();

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut