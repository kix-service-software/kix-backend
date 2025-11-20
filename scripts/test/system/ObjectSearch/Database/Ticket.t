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
for my $Method ( qw(Init GetBaseDef GetPermissionDef GetSearchDef GetSortDef GetSupportedAttributes) ) {
    $Self->True(
        $ObjectTypeObject->can($Method),
        'ObjectType object can "' . $Method . '"'
    );
}

# check Init
my $InitReturn = $ObjectTypeObject->Init();
$Self->Is(
    $InitReturn,
    1,
    'Init provides expected data'
);

# check GetBaseDef
my $GetBaseDefReturn = $ObjectTypeObject->GetBaseDef();
$Self->IsDeeply(
    $GetBaseDefReturn,
    {
        Select  => ['st.id', 'st.tn'],
        From    => ['ticket st'],
        OrderBy => ['st.id ASC']
    },
    'GetBaseDef provides expected data'
);

# begin transaction on database
$Helper->BeginWork();

## prepare user mapping
my $RoleID1 = $Kernel::OM->Get('Role')->RoleLookup(
    Role => 'Ticket Agent Base Permission'
);
my $RoleID2 = $Kernel::OM->Get('Role')->RoleAdd(
    Name         => 'UnitTest',
    ValidID      => 1,
    UsageContext => 0x0003,
    UserID       => 1,
);
my $PermissionID = $Kernel::OM->Get('Role')->PermissionAdd(
    RoleID     => $RoleID2,
    TypeID     => 4,
    Target     => '1',
    Value      => 0x000F,
    UserID     => 1,
);

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

my $UserID2 = $Kernel::OM->Get('User')->UserAdd(
    UserLogin     => 'UnitTest2',
    ValidID       => 1,
    ChangeUserID  => 1,
    IsAgent       => 1
);
$Kernel::OM->Get('Role')->RoleUserAdd(
    AssignUserID => $UserID2,
    RoleID       => $RoleID1,
    UserID       => 1,
);
$Self->True(
    $UserID2,
    'Second user created'
);

my $UserID3 = $Kernel::OM->Get('User')->UserAdd(
    UserLogin     => 'UnitTest3',
    ValidID       => 1,
    ChangeUserID  => 1,
    IsAgent       => 1
);
$Kernel::OM->Get('Role')->RoleUserAdd(
    AssignUserID => $UserID3,
    RoleID       => $RoleID1,
    UserID       => 1,
);
$Kernel::OM->Get('Role')->RoleUserAdd(
    AssignUserID => $UserID3,
    RoleID       => $RoleID2,
    UserID       => 1,
);
$Self->True(
    $UserID3,
    'Third user created'
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
            Where   => [ '(1=0 OR 1=0)' ]
        }
    },
    {
        Name      => 'GetPermissionDef: UserID ' . $UserID3 . ', UserType Agent (Base Permissions, One Team)',
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
            Where   => [ '(st.queue_id IN (1) OR 1=0)' ]
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