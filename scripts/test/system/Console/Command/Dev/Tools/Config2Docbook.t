# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
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
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# get command object
my $CommandObject = $Kernel::OM->Get('Console::Command::Dev::Tools::Config2Docbook');

my $ExitCode = $CommandObject->Execute();

$Self->Is(
    $ExitCode,
    1,
    "Dev::Tools::Config2Docbook exit code without arguments",
);

my $Result;
{
    local *STDOUT;
    open STDOUT, '>:encoding(UTF-8)', \$Result;
    $ExitCode = $CommandObject->Execute( '--language', 'en' );
    $Kernel::OM->Get('Encode')->EncodeInput( \$Result );
}

$Self->Is(
    $ExitCode,
    0,
    "Dev::Tools::Config2Docbook exit code",
);

my $Test = '<variablelist id="ConfigReference_Ticket:Frontend::SLA::Preferences">
    <title>Ticket → Frontend::SLA::Preferences</title>';

$Self->True(
    index( $Result, $Test ) > -1,
    "Config entry found in docbook content",
);

print $Result;

# cleanup cache is done by RestoreDatabase

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
