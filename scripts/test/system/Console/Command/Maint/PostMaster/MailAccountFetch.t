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
my $CommandObject = $Kernel::OM->Get('Console::Command::Maint::PostMaster::MailAccountFetch');

my $ExitCode = $CommandObject->Execute();

# just check exit code; should be 0 also if no accounts are configured
$Self->Is(
    $ExitCode,
    0,
    "Maint::PostMaster::MailAccountFetch exit code",
);

$ExitCode = $CommandObject->Execute( '--mail-account-id', 99999 );

# just check exit code; should be 0 also if no accounts are configured
$Self->Is(
    $ExitCode,
    1,
    "Maint::PostMaster::MailAccountFetch exit code for nonexisting mail account",
);

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
