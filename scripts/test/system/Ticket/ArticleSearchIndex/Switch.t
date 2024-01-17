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
    Key   => 'Ticket::SearchIndexModule',
    Value => 'Kernel::System::Ticket::ArticleSearchIndex::StaticDB',
);

$Self->True(
    $Kernel::OM->Get('Ticket')->isa('Kernel::System::Ticket::ArticleSearchIndex::StaticDB'),
    "TicketObject loaded the correct backend",
);

# create some content
my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => 'Some Ticket_Title',
    Queue          => 'Junk',
    Lock           => 'unlock',
    Priority       => '3 normal',
    State          => 'closed',
    OrganisationID => '123465',
    ContactID      => 'customer@example.com',
    OwnerID        => 1,
    UserID         => 1,
);
$Self->True(
    $TicketID,
    'TicketCreate()',
);

my $ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID       => $TicketID,
    Channel        => 'note',
    SenderType     => 'agent',
    From           => 'Some Agent <email@example.com>',
    To             => 'Some Customer <customer@example.com>',
    Subject        => 'some short description',
    Body           => 'the message text
Perl modules provide a range of features to help you avoid reinventing the wheel, and can be downloaded from CPAN ( http://www.cpan.org/ ). A number of popular modules are included with the Perl distribution itself.',
    ContentType    => 'text/plain; charset=ISO-8859-15',
    HistoryType    => 'OwnerUpdate',
    HistoryComment => 'Some free text!',
    UserID         => 1,
    NoAgentNotify  => 1,                                   # if you don't want to send agent notifications
);
$Self->True(
    $ArticleID,
    'ArticleCreate()',
);

my $IndexBuilt = $Kernel::OM->Get('Ticket')->ArticleIndexBuild(
    ArticleID => $ArticleID,
    UserID    => 1,
);
$Self->True(
    $ArticleID,
    'Search index was created.',
);

# Make sure that the TicketObject gets recreated for each loop.
$Kernel::OM->ObjectsDiscard( Objects => ['Ticket'] );

$Kernel::OM->Get('Config')->Set(
    Key   => 'Ticket::SearchIndexModule',
    Value => 'Kernel::System::Ticket::ArticleSearchIndex::RuntimeDB',
);

my $Delete = $Kernel::OM->Get('Ticket')->TicketDelete(
    TicketID => $TicketID,
    UserID   => 1,
);
$Self->True(
    $Delete,
    'TicketDelete()',
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
