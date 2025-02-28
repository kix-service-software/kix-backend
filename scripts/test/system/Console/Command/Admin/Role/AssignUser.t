# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use Kernel::System::Role;

use vars (qw($Self));

my $CommandObject = $Kernel::OM->Get('Console::Command::Admin::Role::AssignUser');

my ( $Result, $ExitCode );

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my $RandomName = $Helper->GetRandomID();
my $UserRand   = 'user' . $RandomName;
my $RoleRand   = 'role' . $RandomName;

# silence console output
local *STDOUT;
local *STDERR;
open STDOUT, '>>', "/dev/null";
open STDERR, '>>', "/dev/null";

# try to execute command without any options
$ExitCode = $CommandObject->Execute();
$Self->Is(
    $ExitCode,
    1,
    "No options",
);

# provide minimum options (invalid user)
$ExitCode = $CommandObject->Execute( '--user-name', $UserRand, '--role-name', $RoleRand );
$Self->Is(
    $ExitCode,
    1,
    "Minimum options (but user doesn't exist)",
);

# add users
my $UserID = $Kernel::OM->Get('User')->UserAdd(
    UserLogin    => $UserRand,
    ValidID      => 1,
    ChangeUserID => 1,
    IsAgent      => 1,
);

$Self->True(
    $UserID,
    "Test user is created - $UserRand",
);

# add role
my $RoleID = $Kernel::OM->Get('Role')->RoleAdd(
    Name    => $RoleRand,
    UsageContext => Kernel::System::Role->USAGE_CONTEXT->{AGENT},
    ValidID => 1,
    UserID  => 1,
);

$Self->True(
    $RoleID,
    "Test role is created - $RoleRand",
);

# provide minimum options (invalid role)
$ExitCode = $CommandObject->Execute( '--user-name', $UserRand, '--role-name', $RandomName );
$Self->Is(
    $ExitCode,
    1,
    "Minimum options (but role doesn't exist)",
);

# provide minimum options (OK)
$ExitCode = $CommandObject->Execute( '--user-name', $UserRand, '--role-name', $RoleRand );
$Self->Is(
    $ExitCode,
    0,
    "Minimum options (parameters OK: linked user $UserRand to role $RoleRand)",
);

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
