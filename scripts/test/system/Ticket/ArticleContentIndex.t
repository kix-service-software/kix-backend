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

# get ticket object
my $TicketObject = $Kernel::OM->Get('Ticket');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my $TicketID = $TicketObject->TicketCreate(
    Title          => 'Some test ticket for ArticleContentIndex',
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

my @ArticleIDs;

my %Channels = $Kernel::OM->Get('Channel')->ChannelList(
    Result => 'HASH',
);
my @ChannelIDs         = sort keys %Channels;
my %ArticleSenderTypes = $TicketObject->ArticleSenderTypeList(
    Result => 'HASH',
);
my @SenderTypeIDs = ( sort keys %ArticleSenderTypes )[ 0 .. 1 ];

for my $Number ( 1 .. 15 ) {
    my $ArticleID = $TicketObject->ArticleCreate(
        TicketID       => $TicketID,
        ChannelID      => $ChannelIDs[ $Number % 2 ],
        SenderTypeID   => $SenderTypeIDs[ $Number % 2 ],
        From           => 'Some Agent <email@example.com>',
        To             => 'Some Customer <customer-a@example.com>',
        Subject        => "Test article $Number",
        Body           => 'the message text',
        ContentType    => 'text/plain; charset=ISO-8859-1',
        HistoryType    => 'OwnerUpdate',
        HistoryComment => 'Some free text!',
        UserID         => 1,
        NoAgentNotify  => 1,
    );
    $Self->True( $ArticleID, "ArticleCreate $Number" );
    push @ArticleIDs, $ArticleID;
}

my @ArticleBox = $TicketObject->ArticleContentIndex(
    TicketID      => $TicketID,
    DynamicFields => 0,
    UserID        => 1,
);

$Self->Is(
    scalar(@ArticleBox),
    15,
    "ArticleContentIndex by default fetches all articles",
);

@ArticleBox = $TicketObject->ArticleContentIndex(
    TicketID      => $TicketID,
    DynamicFields => 0,
    UserID        => 1,
    Limit         => 10,
);

$Self->Is(
    scalar(@ArticleBox),
    10,
    "ArticleContentIndex with Limit => 10 fetches only 10 articles",
);

$Self->Is(
    $ArticleBox[0]{Subject},
    "Test article 1",
    "First article on first page",
);

$Self->Is(
    $ArticleBox[0]{Subject},
    "Test article 1",
    "First article on first page",
);

@ArticleBox = $TicketObject->ArticleContentIndex(
    TicketID      => $TicketID,
    DynamicFields => 0,
    UserID        => 1,
    Page          => 1,
    Limit         => 10,
);

$Self->Is(
    scalar(@ArticleBox),
    10,
    "ArticleContentIndex with Limit => 10, Page => 1 fetches 10 articles",
);

@ArticleBox = $TicketObject->ArticleContentIndex(
    TicketID      => $TicketID,
    DynamicFields => 0,
    UserID        => 1,
    Page          => 2,
    Limit         => 10,
);

$Self->Is(
    scalar(@ArticleBox),
    5,
    "ArticleContentIndex with Limit => 10, Page => 2 fetches the rest",
);

$Self->Is(
    $ArticleBox[0]{Subject},
    "Test article 11",
    "First article on second page",
);

$Self->Is(
    $TicketObject->ArticleCount( TicketID => $TicketID ),
    15,
    'ArticleCount',
);

$Self->Is(
    $TicketObject->ArticlePage(
        TicketID    => $TicketID,
        ArticleID   => $ArticleBox[0]{ArticleID},
        RowsPerPage => 10,
    ),
    2,
    'ArticlePage works',
);

# Test filter
#
@ArticleBox = $TicketObject->ArticleContentIndex(
    TicketID      => $TicketID,
    DynamicFields => 0,
    UserID        => 1,
    ChannelID     => [ $ChannelIDs[ 0 ] ],
);

$Self->Is(
    scalar(@ArticleBox),
    7,
    'Filtering by ChannelID',
);

$Self->Is(
    $TicketObject->ArticleCount(
        TicketID  => $TicketID,
        ChannelID => [ $ChannelIDs[ 0 ] ],
    ),
    7,
    'ArticleCount is consistent with ArticleContentIndex (ChannelID)',
);

@ArticleBox = $TicketObject->ArticleContentIndex(
    TicketID            => $TicketID,
    DynamicFields       => 0,
    UserID              => 1,
    ArticleSenderTypeID => [ $SenderTypeIDs[0] ],
);

$Self->Is(
    scalar(@ArticleBox),
    7,
    'Filtering by ArticleSenderTypeID',
);

$Self->Is(
    $TicketObject->ArticleCount(
        TicketID            => $TicketID,
        ArticleSenderTypeID => [ $SenderTypeIDs[0] ],
    ),
    7,
    'ArticleCount is consistent with ArticleContentIndex (ArticleSenderTypeID)',
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
