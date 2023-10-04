# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use Kernel::System::Role;

use vars (qw($Self));

# get role object
my $RoleObject = $Kernel::OM->Get('Role');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my $NameRandom  = $Helper->GetRandomID();
my %RoleIDByRoleName = (
    'test-role-' . $NameRandom . '-1' => undef,
    'test-role-' . $NameRandom . '-2' => undef,
    'test-role-' . $NameRandom . '-3' => undef,
);

# try to add roles
for my $RoleName ( sort keys %RoleIDByRoleName ) {
    my $RoleID = $RoleObject->RoleAdd(
        Name         => $RoleName,
        UsageContext => Kernel::System::Role->USAGE_CONTEXT->{AGENT},
        ValidID      => 1,
        UserID       => 1,
    );

    $Self->True(
        $RoleID,
        'RoleAdd() for new role ' . $RoleName,
    );

    if ($RoleID) {
        $RoleIDByRoleName{$RoleName} = $RoleID;
    }
}

# try to add already added roles
for my $RoleName ( sort keys %RoleIDByRoleName ) {
    my $RoleID = $RoleObject->RoleAdd(
        Name         => $RoleName,
        UsageContext => Kernel::System::Role->USAGE_CONTEXT->{AGENT},
        ValidID      => 1,
        UserID       => 1,
        Silent       => 1,
    );

    $Self->False(
        $RoleID,
        'RoleAdd() for already existing role ' . $RoleName,
    );
}

# try to fetch data of existing roles
for my $RoleName ( sort keys %RoleIDByRoleName ) {
    my $RoleID = $RoleIDByRoleName{$RoleName};
    my %Role = $RoleObject->RoleGet( ID => $RoleID );

    $Self->Is(
        $Role{Name},
        $RoleName,
        'RoleGet() for role ' . $RoleName,
    );
}

# look up existing roles
for my $RoleName ( sort keys %RoleIDByRoleName ) {
    my $RoleID = $RoleIDByRoleName{$RoleName};

    my $FetchedRoleID = $RoleObject->RoleLookup( Role => $RoleName );
    $Self->Is(
        $FetchedRoleID,
        $RoleID,
        'RoleLookup() for role name ' . $RoleName,
    );

    my $FetchedRoleName = $RoleObject->RoleLookup( RoleID => $RoleID );
    $Self->Is(
        $FetchedRoleName,
        $RoleName,
        'RoleLookup() for role ID ' . $RoleID,
    );
}

# list roles
my %Roles = $RoleObject->RoleList();
for my $RoleName ( sort keys %RoleIDByRoleName ) {
    my $RoleID = $RoleIDByRoleName{$RoleName};

    $Self->True(
        exists $Roles{$RoleID} && $Roles{$RoleID} eq $RoleName,
        'RoleList() contains role ' . $RoleName . ' with ID ' . $RoleID,
    );
}

# role data list
my %RoleDataList = $RoleObject->RoleList();
for my $RoleName ( sort keys %RoleIDByRoleName ) {
    my $RoleID = $RoleIDByRoleName{$RoleName};

    $Self->True(
        exists $RoleDataList{$RoleID} && $RoleDataList{$RoleID} eq $RoleName,
        'RoleDataList() contains role ' . $RoleName . ' with ID ' . $RoleID,
    );
}

# change name of a single role
my $RoleNameToChange = 'test-role-' . $NameRandom . '-1';
my $ChangedRoleName  = $RoleNameToChange . '-changed';
my $RoleIDToChange   = $RoleIDByRoleName{$RoleNameToChange};

my $RoleUpdateResult = $RoleObject->RoleUpdate(
    ID           => $RoleIDToChange,
    Name         => $ChangedRoleName,
    UsageContext => Kernel::System::Role->USAGE_CONTEXT->{AGENT},
    ValidID      => 1,
    UserID       => 1,
);

$Self->True(
    $RoleUpdateResult,
    'RoleUpdate() for changing name of role ' . $RoleNameToChange . ' to ' . $ChangedRoleName,
);

$RoleIDByRoleName{$ChangedRoleName} = $RoleIDToChange;
delete $RoleIDByRoleName{$RoleNameToChange};

# try to add role with previous name
my $RoleID1 = $RoleObject->RoleAdd(
    Name         => $RoleNameToChange,
    UsageContext => Kernel::System::Role->USAGE_CONTEXT->{AGENT},
    ValidID      => 1,
    UserID       => 1,
);

$Self->True(
    $RoleID1,
    'RoleAdd() for new role ' . $RoleNameToChange,
);

if ($RoleID1) {
    $RoleIDByRoleName{$RoleNameToChange} = $RoleID1;
}

# try to add role with changed name
$RoleID1 = $RoleObject->RoleAdd(
    Name         => $ChangedRoleName,
    UsageContext => Kernel::System::Role->USAGE_CONTEXT->{AGENT},
    ValidID      => 1,
    UserID       => 1,
    Silent       => 1,
);

$Self->False(
    $RoleID1,
    'RoleAdd() add role with existing name ' . $ChangedRoleName,
);

my $RoleName2 = $ChangedRoleName . 'update';
my $RoleID2   = $RoleObject->RoleAdd(
    Name         => $RoleName2,
    UsageContext => Kernel::System::Role->USAGE_CONTEXT->{AGENT},
    ValidID      => 1,
    UserID       => 1,
);

$Self->True(
    $RoleID2,
    'RoleAdd() add the second test role ' . $RoleName2,
);

# try to update role with existing name
my $RoleUpdateWrong = $RoleObject->RoleUpdate(
    ID           => $RoleID2,
    Name         => $ChangedRoleName,
    UsageContext => Kernel::System::Role->USAGE_CONTEXT->{AGENT},
    ValidID      => 2,
    UserID       => 1,
    Silent       => 1,
);

$Self->False(
    $RoleUpdateWrong,
    'RoleUpdate() update role with existing name ' . $ChangedRoleName,
);

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
