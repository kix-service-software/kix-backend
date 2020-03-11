# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

my $CommandObject = $Kernel::OM->Get('Kernel::System::Console::Command::Maint::SystemMonitoring::NagiosCheck');

my $ConfigFile = $Kernel::OM->Get('Kernel::Config')->Get('Home') . '/scripts/test/system/sample/NagiosCheckTesting.pm';

my $ExitCode = $CommandObject->Execute( '--config-file', $ConfigFile, '--as-checker', '--verbose', );

$Self->Is(
    $ExitCode,
    0,
    "Maint::SystemMonitoring::NagiosCheck exit code",
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
