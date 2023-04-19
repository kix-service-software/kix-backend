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

use vars (qw($Self));

my $CommandObject = $Kernel::OM->Get('Console::Command::Admin::Contact::Add');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper     = $Kernel::OM->Get('UnitTest::Helper');
my $RandomName = $Helper->GetRandomID();

$Kernel::OM->Get('Config')->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

# create test organisation
my $OrgID = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => $Helper->GetRandomID(),
    Name    => $Helper->GetRandomID(),
    ValidID => 1,
    UserID  => 1,
);


# try to execute command without any options
my $ExitCode = $CommandObject->Execute();
$Self->Is(
    $ExitCode,
    1,
    "No options",
);

# provide minimum options
$ExitCode = $CommandObject->Execute(
    '--user-name', $RandomName, '--first-name', 'Test',
    '--last-name', 'Test', '--email-address', $RandomName . '@test.test',
    '--primary-organisation-id', $OrgID, 'Test',
);
$Self->Is(
    $ExitCode,
    0,
    "Minimum options",
);

# provide minimum options
$ExitCode = $CommandObject->Execute(
    '--user-name', $RandomName, '--first-name', 'Test',
    '--last-name', 'Test', '--email-address', $RandomName . '@test.test',
    '--primary-organisation-id', 'Test',
);
$Self->Is(
    $ExitCode,
    1,
    "Minimum options (contact already exists)",
);

# cleanup is done by RestoreDatabase

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
