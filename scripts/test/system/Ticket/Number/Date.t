# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
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

# set fixed time to have predetermined verifiable results
my $SystemTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
    String => '2014-01-01 12:00:00',
);
$Helper->FixedTimeSet($SystemTime);

# set config to match test cases
$Kernel::OM->Get('Config')->Set(
    Key   => 'Ticket::NumberGenerator',
    Value => 'Kernel::System::Ticket::Number::Date'
);
$Kernel::OM->Get('Config')->Set(
    Key   => 'Ticket::NumberGenerator::Date::UseFormattedCounter',
    Value => '1'
);
$Kernel::OM->Get('Config')->Set(
    Key   => 'Ticket::NumberGenerator::MinCounterSize',
    Value => '5'
);
$Kernel::OM->Get('Config')->Set(
    Key   => 'SystemID',
    Value => '17'
);

# begin transaction on database
$Helper->BeginWork();

# first ticket
my $TicketID1 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => 1,
    Lock           => 'unlock',
    PriorityID     => 1,
    StateID        => 1,
    TypeID         => 1,
    OrganisationID => 1,
    ContactID      => 1,
    OwnerID        => 1,
    ResponsibleID  => 1,
    UserID         => 1
);
$Self->True(
    $TicketID1,
    'Created first ticket'
);
my $TicketNumber1 = $Kernel::OM->Get('Ticket')->TicketNumberLookup(
    TicketID => $TicketID1,
    UserID   => 1,
);
$Self->Is(
    $TicketNumber1,
    '201401011700001',
    'Ticketnumber of first ticket'
);

# second ticket
my $TicketID2 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => 1,
    Lock           => 'unlock',
    PriorityID     => 1,
    StateID        => 1,
    TypeID         => 1,
    OrganisationID => 1,
    ContactID      => 1,
    OwnerID        => 1,
    ResponsibleID  => 1,
    UserID         => 1
);
$Self->True(
    $TicketID2,
    'Created second ticket'
);
my $TicketNumber2 = $Kernel::OM->Get('Ticket')->TicketNumberLookup(
    TicketID => $TicketID2,
    UserID   => 1,
);
$Self->Is(
    $TicketNumber2,
    '201401011700002',
    'Ticketnumber of second ticket'
);

# add one day to time
$Helper->FixedTimeAddSeconds(86400);

# third ticket
my $TicketID3 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => 1,
    Lock           => 'unlock',
    PriorityID     => 1,
    StateID        => 1,
    TypeID         => 1,
    OrganisationID => 1,
    ContactID      => 1,
    OwnerID        => 1,
    ResponsibleID  => 1,
    UserID         => 1
);
$Self->True(
    $TicketID3,
    'Created third ticket one day later'
);
my $TicketNumber3 = $Kernel::OM->Get('Ticket')->TicketNumberLookup(
    TicketID => $TicketID3,
    UserID   => 1,
);
$Self->Is(
    $TicketNumber3,
    '201401021700001',
    'Ticketnumber of third ticket'
);

# reset fixed time
$Helper->FixedTimeUnset();

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
