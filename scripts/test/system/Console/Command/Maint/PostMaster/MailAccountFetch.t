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
my $CommandObject = $Kernel::OM->Get('Console::Command::Maint::PostMaster::MailAccountFetch');

# silence console output
local *STDOUT;
local *STDERR;
open STDOUT, '>>', "/dev/null";
open STDERR, '>>', "/dev/null";

# begin transaction on database
$Helper->BeginWork();

# deactivate all mail accounts for this test
my %MailAccountList = $Kernel::OM->Get('MailAccount')->MailAccountList(
    Valid => 1,
);
for my $MailAccountID ( keys( %MailAccountList ) ) {
    my %MailAccount = $Kernel::OM->Get('MailAccount')->MailAccountGet(
        ID => $MailAccountID,
    );
    $Kernel::OM->Get('MailAccount')->MailAccountUpdate(
        %MailAccount,
        ID      => $MailAccountID,
        ValidID => 2,
        UserID  => 1,
    );
}

my $ExitCode = $CommandObject->Execute();

# just check exit code; should be 0 also if no accounts are configured
if ( !$ExitCode ) {
    $Self->Is(
        $ExitCode,
        0,
        "Maint::PostMaster::MailAccountFetch exit code",
    );
}
else {
    my $LogMessage = $Kernel::OM->Get('Log')->GetLogEntry(
        Type => 'error',
        What => 'Message',
    );
    $Self->True(
        0,
        "Maint::PostMaster::MailAccountFetch unexpected exit code (error: $LogMessage)"
    );
}

$ExitCode = $CommandObject->Execute( '--mail-account-id', 99999 );

# just check exit code; should be 0 also if no accounts are configured
$Self->Is(
    $ExitCode,
    1,
    "Maint::PostMaster::MailAccountFetch exit code for nonexisting mail account",
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
