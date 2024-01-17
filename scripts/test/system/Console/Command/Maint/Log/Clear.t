# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
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

my $CommandObject = $Kernel::OM->Get('Console::Command::Maint::Log::Clear');
my $LogObject     = $Kernel::OM->Get('Log');

$LogObject->CleanUp();
$LogObject->Log(
    Priority => 'error',
    Message  => 'test',
);

$Self->True(
    length $LogObject->GetLog(),
    "Error log before resetting",
);

my ( $Result, $ExitCode );
{
    local *STDOUT;
    open STDOUT, '>:encoding(UTF-8)', \$Result;
    $ExitCode = $CommandObject->Execute();
    $Kernel::OM->Get('Encode')->EncodeInput( \$Result );
}

$Self->Is(
    $ExitCode,
    0,
    "Exit code for log reset",
);

$Self->Is(
    $LogObject->GetLog(),
    '',
    "Error log after resetting",
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
