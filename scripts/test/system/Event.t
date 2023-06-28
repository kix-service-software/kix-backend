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

# get event object
my $EventObject = $Kernel::OM->Get('Event');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my %EventList = $EventObject->EventList();

$Self->Is(
    $EventList{Ticket}[0],
    'TicketCreate',
    "EventList() Ticket"
);

$Self->Is(
    $EventList{Article}[0],
    'ArticleCreate',
    "EventList() Article"
);

my %EventListTicket = $EventObject->EventList(
    ObjectTypes => ['Ticket'],
);

$Self->Is(
    $EventListTicket{Ticket}[0],
    'TicketCreate',
    "EventListTicket() Ticket"
);

$Self->Is(
    $EventListTicket{Article}[0],
    undef,
    "EventListTicket() Article"
);

# cleanup is done by RestoreDatabase

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
