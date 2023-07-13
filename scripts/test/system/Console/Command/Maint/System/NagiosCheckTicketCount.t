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

my $CommandObject
    = $Kernel::OM->Get('Console::Command::Maint::SystemMonitoring::NagiosCheckTicketCount');

my $ConfigFile = $Kernel::OM->Get('Config')->Get('Home') . '/scripts/test/system/sample/NagiosCheckTesting.pm';

my $ExitCode = $CommandObject->Execute( '--config-file', $ConfigFile, '--as-checker', );

$Self->Is(
    $ExitCode,
    0,
    "Maint::SystemMonitoring::NagiosCheckTicketCount exit code",
);

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
