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

use vars (qw($Self));

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# get command object
my $CommandObject = $Kernel::OM->Get('Console::Command::Dev::Tools::Database::XMLExecute');

my ( $Result, $ExitCode );

my $Home           = $Kernel::OM->Get('Config')->Get('Home');
my $TableCreateXML = "$Home/scripts/test/system/Console/Command/Dev/Tools/Database/XMLExecute/TableCreate.xml";
my $TableDropXML   = "$Home/scripts/test/system/Console/Command/Dev/Tools/Database/XMLExecute/TableDrop.xml";

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

$ExitCode = $CommandObject->Execute($TableCreateXML);
$Self->Is(
    $ExitCode,
    0,
    "Table created",
);

my $Success = $Kernel::OM->Get('DB')->Prepare(
    SQL => "SELECT * FROM test_xml_execute",
);
$Self->True(
    $Success,
    "SELECT after table create",
);
while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) { }

$ExitCode = $CommandObject->Execute($TableDropXML);
$Self->Is(
    $ExitCode,
    0,
    "Table dropped",
);

$Success = $Kernel::OM->Get('DB')->Prepare(
    SQL => "SELECT * FROM test_xml_execute",
);
$Self->False(
    $Success,
    "SELECT after table drop",
);

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
