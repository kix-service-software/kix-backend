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

my $CommandObject = $Kernel::OM->Get('Console::Command::Admin::Contact::Add');

# get helper object
my $Helper     = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my $RandomName = $Helper->GetRandomID();

$Kernel::OM->Get('Config')->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

my $OrgaName   = $Helper->GetRandomID();
my $OrgeNumber = $Helper->GetRandomID();

# create test organisation
my $OrgID = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => $OrgeNumber,
    Name    => $OrgaName,
    ValidID => 1,
    UserID  => 1,
);

$Self->True(
    $OrgID,
    "Added Organisation",
);

# silence console output
local *STDOUT;
local *STDERR;
open STDOUT, '>>', "/dev/null";
open STDERR, '>>', "/dev/null";

# try to execute command without any options
my $ExitCode = $CommandObject->Execute();
$Self->Is(
    $ExitCode,
    1,
    "No options",
);

# provide minimum options
$ExitCode = $CommandObject->Execute(
    '--user-login', $RandomName, '--first-name', 'Test',
    '--last-name', 'Test', '--email-address', $RandomName . '@test.test',
    '--primary-organisation', $OrgaName,
);
$Self->Is(
    $ExitCode,
    0,
    "Minimum options",
);

# provide minimum options
$ExitCode = $CommandObject->Execute(
    '--user-login', $RandomName, '--first-name', 'Test',
    '--last-name', 'Test', '--email-address', $RandomName . '@test.test',
    '--primary-organisation', $OrgaName,
);
$Self->Is(
    $ExitCode,
    1,
    "Minimum options (contact already exists)",
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
