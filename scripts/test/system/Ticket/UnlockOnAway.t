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

$Kernel::OM->Get('Config')->Set(
    Key   => 'Ticket::UnlockOnAway',
    Value => 1,
);

my $TestUserLogin = $Helper->TestUserCreate(
    Roles => [ 'Ticket Agent' ],
);

my $TestUserID = $Kernel::OM->Get('User')->UserLookup(
    UserLogin => $TestUserLogin,
);

my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => 'Some Ticket_Title',
    Queue          => 'Junk',
    Lock           => 'lock',
    Priority       => '3 normal',
    State          => 'open',
    OrganisationID => '123465',
    ContactID      => 'customer@example.com',
    OwnerID        => $TestUserID,
    UserID         => 1,
);
$Self->True(
    $TicketID,
    'Could create ticket'
);

my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
    TicketID => $TicketID,
    UserID   => 1
);

$Self->Is(
    $Ticket{Lock},
    'lock',
    'Ticket is locked',
);

my $ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID       => $TicketID,
    Channel        => 'note',
    SenderType     => 'agent',
    Subject        => 'Should not unlock',
    Body           => '.',
    ContentType    => 'text/plain; charset=UTF-8',
    HistoryComment => 'Just a test',
    HistoryType    => 'OwnerUpdate',
    UserID         => 1,
    NoAgentNotify  => 1,
    UnlockOnAway   => 1,
);
$Self->True(
    $ArticleID,
    'Could create article'
);

%Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
    TicketID => $TicketID,
    UserID   => 1
);

$Self->Is(
    $Ticket{Lock},
    'lock',
    'Ticket still locked (UnlockOnAway)',
);

my ( $Sec, $Min, $Hour, $Day, $Month, $Year, $WeekDay ) = $Kernel::OM->Get('Time')->SystemTime2Date(
    SystemTime => $Kernel::OM->Get('Time')->SystemTime(),
);
# Special case for leap years. There is no Feb 29 in the next and previous years in this case.
if ( $Month == 2 && $Day == 29 ) {
    $Day--;
}

$Kernel::OM->Get('User')->SetPreferences(
    UserID => $Ticket{OwnerID},
    Key    => 'OutOfOfficeStart',
    Value  => sprintf( '%04d-%02d-%02d', ( $Year - 1 ), $Month, $Day ),
);
$Kernel::OM->Get('User')->SetPreferences(
    UserID => $Ticket{OwnerID},
    Key    => 'OutOfOfficeEnd',
    Value  => sprintf( '%04d-%02d-%02d', ( $Year + 1 ), $Month, $Day ),
);

$Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID       => $TicketID,
    Channel        => 'note',
    SenderType     => 'agent',
    Subject        => 'Should now unlock',
    Body           => '.',
    ContentType    => 'text/plain; charset=UTF-8',
    HistoryComment => 'Just a test',
    HistoryType    => 'OwnerUpdate',
    UserID         => 1,
    NoAgentNotify  => 1,
    UnlockOnAway   => 1,
);
%Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
    TicketID => $TicketID,
    UserID   => 1
);

$Self->Is(
    $Ticket{Lock},
    'unlock',
    'Ticket now unlocked (UnlockOnAway)',
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
