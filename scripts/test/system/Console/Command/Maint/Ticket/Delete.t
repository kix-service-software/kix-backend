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
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# get needed object
my $CommandObject = $Kernel::OM->Get('Console::Command::Maint::Ticket::Delete');
my $TicketObject  = $Kernel::OM->Get('Ticket');

$Kernel::OM->Get('Cache')->Configure(
    CacheInMemory => 0,
);

my $ContactID = $Helper->TestContactCreate();

# create a new tickets
my @Tickets;
for ( 1 .. 4 ) {
    my $TicketNumber = $TicketObject->TicketCreateNumber();
    my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
        TN        => $TicketNumber,
        Title     => 'Test ticket',
        Queue     => 'Junk',
        Lock      => 'unlock',
        Priority  => '3 normal',
        State     => 'open',
        ContactID => $ContactID,
        OwnerID   => 1,
        UserID    => 1,
    );

    $Self->True(
        $TicketID,
        "Ticket is created - $TicketID",
    );

    my %TicketHash = (
        TicketID => $TicketID,
        TN       => $TicketNumber,
    );
    push @Tickets, \%TicketHash;
}

# silence console output
local *STDOUT;
local *STDERR;
open STDOUT, '>>', "/dev/null";
open STDERR, '>>', "/dev/null";

my $ExitCode = $CommandObject->Execute();

$Self->Is(
    $ExitCode,
    1,
    "Maint::Ticket::Delete exit code without arguments.",
);

$ExitCode = $CommandObject->Execute( '--ticket-id', $Tickets[0]->{TicketID}, '--ticket-id', $Tickets[1]->{TicketID} );

$Self->Is(
    $ExitCode,
    0,
    "Maint::Ticket::Delete exit code - delete by --ticket-id options.",
);

my %TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectSearch => 'Ticket',
    Result       => 'HASH',
    Search       => {
        AND => [
            {
                Field    => 'ContactID',
                Operator => 'EQ',
                Type     => 'NUMERIC',
                VALUE    => $ContactID
            }
        ]
    },
    UserID       => 1,
    UserType     => 'Agent'
);

$Self->False(
    $TicketIDs{ $Tickets[0]->{TicketID} },
    "Ticket is deleted - $Tickets[0]->{TicketID}",
);

$Self->False(
    $TicketIDs{ $Tickets[1]->{TicketID} },
    "Ticket is deleted - $Tickets[1]->{TicketID}",
);

$ExitCode = $CommandObject->Execute( '--ticket-number', $Tickets[2]->{TN}, '--ticket-number', $Tickets[3]->{TN} );

$Self->Is(
    $ExitCode,
    0,
    "Maint::Ticket::Delete exit code - delete by --ticket-number options.",
);

%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectSearch => 'Ticket',
    Result       => 'HASH',
    Search       => {
        AND => [
            {
                Field    => 'ContactID',
                Operator => 'EQ',
                Type     => 'NUMERIC',
                VALUE    => $ContactID
            }
        ]
    },
    UserID       => 1,
    UserType     => 'Agent'
);

$Self->False(
    $TicketIDs{ $Tickets[2]->{TicketID} },
    "Ticket is deleted - $Tickets[2]->{TicketID}",
);

$Self->False(
    $TicketIDs{ $Tickets[3]->{TicketID} },
    "Ticket is deleted - $Tickets[3]->{TicketID}",
);

$ExitCode = $CommandObject->Execute(
    '--ticket-id',     $Tickets[0]->{TicketID}, '--ticket-id',     $Tickets[1]->{TicketID},
    '--ticket-number', $Tickets[2]->{TN},       '--ticket-number', $Tickets[3]->{TN}
);

$Self->Is(
    $ExitCode,
    1,
    "Maint::Ticket::Delete exit code - try to delete with wrong ticket numbers and ticket IDs.",
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
