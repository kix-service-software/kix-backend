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

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# get needed objects
my $CommandObject = $Kernel::OM->Get('Console::Command::Maint::Ticket::PendingCheck');
my $TimeObject    = $Kernel::OM->Get('Time');
my $TicketObject  = $Kernel::OM->Get('Ticket');

my $TicketID = $TicketObject->TicketCreate(
    Title        => 'My ticket created by Agent A',
    Queue        => 'Junk',
    Lock         => 'unlock',
    Priority     => '3 normal',
    State        => 'pending auto close',
    OwnerID      => 1,
    UserID       => 1,
);

$Self->True(
    $TicketID,
    "Ticket created",
);

my $Success = $TicketObject->TicketPendingTimeSet(
    String   => '2014-01-03 00:00:00',
    TicketID => $TicketID,
    UserID   => 1,
);

$Self->True(
    $TicketID,
    "Set pending time",
);

# test the pending auto close, with a time before the pending time
my $SystemTime = $TimeObject->TimeStamp2SystemTime(
    String => '2014-01-01 12:00:00',
);

# set the fixed time
$Helper->FixedTimeSet($SystemTime);

# silence console output
local *STDOUT;
local *STDERR;
open STDOUT, '>>', "/dev/null";
open STDERR, '>>', "/dev/null";

my $ExitCode = $CommandObject->Execute();

$Self->Is(
    $ExitCode,
    0,
    "Maint::Ticket::PendingCheck exit code",
);

my %Ticket = $TicketObject->TicketGet(
    TicketID => $TicketID,
);

$Self->Is(
    $Ticket{State},
    'pending auto close',
    "Ticket pending auto close time not reached",
);

# test the pending auto close, for a reached pending time
$SystemTime = $TimeObject->TimeStamp2SystemTime(
    String => '2014-01-03 03:00:00',
);

# set the fixed time
$Helper->FixedTimeSet($SystemTime);

$ExitCode = $CommandObject->Execute();

$Self->Is(
    $ExitCode,
    0,
    "Maint::Ticket::PendingCheck exit code",
);

%Ticket = $TicketObject->TicketGet(
    TicketID => $TicketID,
);

$Self->Is(
    $Ticket{State},
    'closed',
    "Ticket pending auto closed time reached",
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
