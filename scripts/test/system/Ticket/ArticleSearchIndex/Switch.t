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

#
# This test should make sure that after switching from StaticDB to RuntimeDB,
# tickets with stale entries in article_search can still be deleted (see bug#11677).
#

# get config object
my $ConfigObject = $Kernel::OM->Get('Config');

$ConfigObject->Set(
    Key   => 'Ticket::SearchIndexModule',
    Value => 'Ticket::ArticleSearchIndex::StaticDB',
);

# get ticket object
my $TicketObject = $Kernel::OM->Get('Ticket');

$Self->True(
    $TicketObject->isa('Ticket::ArticleSearchIndex::StaticDB'),
    "TicketObject loaded the correct backend",
);

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# create some content
my $TicketID = $TicketObject->TicketCreate(
    Title        => 'Some Ticket_Title',
    Queue        => 'Junk',
    Lock         => 'unlock',
    Priority     => '3 normal',
    State        => 'closed',
    OrganisationID => '123465',
    ContactID    => 'customer@example.com',
    OwnerID      => 1,
    UserID       => 1,
);
$Self->True(
    $TicketID,
    'TicketCreate()',
);

my $ArticleID = $TicketObject->ArticleCreate(
    TicketID    => $TicketID,
    Channels    => 'note',
    SenderType  => 'agent',
    From        => 'Some Agent <email@example.com>',
    To          => 'Some Customer <customer@example.com>',
    Subject     => 'some short description',
    Body        => 'the message text
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

my $IndexBuilt = $TicketObject->ArticleIndexBuild(
    ArticleID => $ArticleID,
    UserID    => 1,
);
$Self->True(
    $ArticleID,
    'Search index was created.',
);

# Make sure that the TicketObject gets recreated for each loop.
$Kernel::OM->ObjectsDiscard( Objects => ['Ticket'] );

$ConfigObject->Set(
    Key   => 'Ticket::SearchIndexModule',
    Value => 'Ticket::ArticleSearchIndex::RuntimeDB',
);

$TicketObject = $Kernel::OM->Get('Ticket');

my $Delete = $TicketObject->TicketDelete(
    TicketID => $TicketID,
    UserID   => 1,
);
$Self->True(
    $Delete,
    'TicketDelete()',
);

# cleanup is done by RestoreDatabase.

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
