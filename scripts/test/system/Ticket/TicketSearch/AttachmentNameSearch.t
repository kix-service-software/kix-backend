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

use Kernel::System::VariableCheck qw(:all);

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

$Helper->UseTmpArticleDir();

# initially set article storage to DB, so that subsequent FS tests succeed.
$Kernel::OM->Get('Config')->Set(
    Key   => 'Ticket::StorageModule',
    Value => "Kernel::System::Ticket::ArticleStorageDB",
);

my $UserID = 1;

# get a random id
my $RandomID = $Helper->GetRandomID();

$Kernel::OM->Get('Config')->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

my @TicketIDs;

# create 2 tickets
for my $Item ( 1 .. 2 ) {
    my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
        Title      => ( $Item == 1 ) ? ( $RandomID . 'Ticket One Title' ) : ( $RandomID . 'Ticket Two Title ' . $RandomID ),
        Queue      => 'Junk',
        Lock       => 'unlock',
        Priority   => '3 normal',
        State      => 'new',
        CustomerID => '123465' . $RandomID,
        Contact    => 'customerOne@example.com',
        OwnerID    => 1,
        UserID     => 1,
    );

    # sanity check
    $Self->True(
        $TicketID,
        "TicketCreate() successful for Ticket ID $TicketID",
    );

    # get the Ticket entry
    my %TicketEntry = $Kernel::OM->Get('Ticket')->TicketGet(
        TicketID      => $TicketID,
        DynamicFields => 0,
        UserID        => $UserID,
    );

    $Self->True(
        IsHashRefWithData( \%TicketEntry ),
        "TicketGet() successful for Local TicketGet ID $TicketID",
    );

    push @TicketIDs, $TicketID;
}

my $TicketCounter = 1;

# create articles and attachments
TICKET:
for my $TicketID (@TicketIDs) {

    # create 2 articles per ticket
    ARTICLE:
    for my $ArticleCounter ( 1 .. 2 ) {
        my $ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
            TicketID        => $TicketID,
            Channel         => 'note',
            CustomerVisible => 1,
            SenderType      => 'agent',
            From            => 'Agent Some Agent Some Agent <email@example.com>',
            To              => 'Customer A <customer-a@example.com>',
            Cc              => 'Customer B <customer-b@example.com>',
            ReplyTo         => 'Customer B <customer-b@example.com>',
            Subject         => 'T' . $TicketCounter . 'A' . $ArticleCounter . $RandomID,
            Body            => 'A text for the body, Title äöüßÄÖÜ€ис',
            ContentType     => 'text/plain; charset=ISO-8859-15',
            HistoryType     => 'OwnerUpdate',
            HistoryComment  => 'first article',
            UserID          => 1,
            NoAgentNotify   => 1,
        );

        $Self->True(
            $ArticleID,
            'Article created',
        );

        next ARTICLE if $ArticleCounter == 1;

        # add attachment only to second article
        my $Location = $Kernel::OM->Get('Config')->Get('Home')
            . "/scripts/test/system/sample/StdAttachment/StdAttachment-Test1.txt";

        my $ContentRef = $Kernel::OM->Get('Main')->FileRead(
            Location => $Location,
            Mode     => 'binmode',
            Type     => 'Local',
        );

        my $ArticleWriteAttachment = $Kernel::OM->Get('Ticket')->ArticleWriteAttachment(
            Content     => ${$ContentRef},
            Filename    => 'StdAttachment-Test1' . $RandomID . '.txt',
            ContentType => 'txt',
            ArticleID   => $ArticleID,
            UserID      => 1,
        );

        $Self->True(
            $ArticleWriteAttachment,
            'Attachment created',
        );
    }
    $TicketCounter++;
}

# add an internal article
my $ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID       => $TicketIDs[1],
    Channel        => 'note',
    SenderType     => 'agent',
    From           => 'Agent Some Agent Some Agent <email@example.com>',
    To             => 'Customer A <customer-a@example.com>',
    Cc             => 'Customer B <customer-b@example.com>',
    ReplyTo        => 'Customer B <customer-b@example.com>',
    Subject        => 'T2A3' . $RandomID,
    Body           => 'A text for the body, Title äöüßÄÖÜ€ис',
    ContentType    => 'text/plain; charset=ISO-8859-15',
    HistoryType    => 'OwnerUpdate',
    HistoryComment => 'first article',
    UserID         => 1,
    NoAgentNotify  => 1,
);

$Self->True(
    $ArticleID,
    'Article created',
);

# add attachment only to second article
my $Location = $Kernel::OM->Get('Config')->Get('Home') . '/scripts/test/system/sample/StdAttachment/StdAttachment-Test1.txt';

my $ContentRef = $Kernel::OM->Get('Main')->FileRead(
    Location => $Location,
    Mode     => 'binmode',
    Type     => 'Local',
);

my $ArticleWriteAttachment = $Kernel::OM->Get('Ticket')->ArticleWriteAttachment(
    Content     => ${$ContentRef},
    Filename    => 'StdAttachment-Test1' . $RandomID . '.txt',
    ContentType => 'txt',
    ArticleID   => $ArticleID,
    UserID      => 1,
);

$Self->True(
    $ArticleWriteAttachment,
    'Attachment created',
);

# actual tests
my @Tests = (
    {
        Name   => 'AttachmentName',
        Search => [
            {
                Field    => 'AttachmentName',
                Value    => 'StdAttachment-Test1' . $RandomID . '.txt',
                Operator => 'EQ',
            },
        ],
        ExpectedResultsArticleStorageDB => [ $TicketIDs[0], $TicketIDs[1] ],
        ExpectedResultsArticleStorageFS => [],
    },
    {
        Name   => 'AttachmentName nonexisting',
        Search => [
            {
                Field    => 'AttachmentName',
                Value    => 'nonexisting-attachment-name-search.txt',
                Operator => 'EQ',
            },
        ],
        ExpectedResultsArticleStorageDB => [],
        ExpectedResultsArticleStorageFS => [],
    },
    {
        Name   => 'AttachmentName Ticket1 Article1',
        Search => [
            {
                Field    => 'AttachmentName',
                Value    => 'StdAttachment-Test1' . $RandomID . '.txt',
                Operator => 'EQ',
            },
            {
                Field    => 'Subject',
                Value    => 'T1A1' . $RandomID,
                Operator => 'EQ',
            },
        ],
        ExpectedResultsArticleStorageDB => [ $TicketIDs[0] ],
        ExpectedResultsArticleStorageFS => [],
    },
    {
        Name   => 'AttachmentName Ticket1 Article2',
        Search => [
            {
                Field    => 'AttachmentName',
                Value    => 'StdAttachment-Test1' . $RandomID . '.txt',
                Operator => 'EQ',
            },
            {
                Field    => 'Subject',
                Value    => 'T1A2' . $RandomID,
                Operator => 'EQ',
            },
        ],
        ExpectedResultsArticleStorageDB => [ $TicketIDs[0] ],
        ExpectedResultsArticleStorageFS => [],
    },
    {
        Name   => 'AttachmentName Ticket2 Article1',
        Search => [
            {
                Field    => 'AttachmentName',
                Value    => 'StdAttachment-Test1' . $RandomID . '.txt',
                Operator => 'EQ',
            },
            {
                Field    => 'Subject',
                Value    => 'T2A1' . $RandomID,
                Operator => 'EQ',
            },
        ],
        ExpectedResultsArticleStorageDB => [ $TicketIDs[1] ],
        ExpectedResultsArticleStorageFS => [],
    },
    {
        Name   => 'AttachmentName Ticket2 Article2',
        Search => [
            {
                Field    => 'AttachmentName',
                Value    => 'StdAttachment-Test1' . $RandomID . '.txt',
                Operator => 'EQ',
            },
            {
                Field    => 'Subject',
                Value    => 'T2A2' . $RandomID,
                Operator => 'EQ',
            },
        ],
        ExpectedResultsArticleStorageDB => [ $TicketIDs[1] ],
        ExpectedResultsArticleStorageFS => [],
    },
    {
        Name   => 'AttachmentName Ticket2 Article3',
        Search => [
            {
                Field    => 'AttachmentName',
                Value    => 'StdAttachment-Test1' . $RandomID . '.txt',
                Operator => 'EQ',
            },
            {
                Field    => 'Subject',
                Value    => 'T2A3' . $RandomID,
                Operator => 'EQ',
            },
        ],
        ExpectedResultsArticleStorageDB => [ $TicketIDs[1] ],
        ExpectedResultsArticleStorageFS => [],
    },
    {
        Name   => 'AttachmentName Title Ticket 1',
        Search => [
            {
                Field    => 'AttachmentName',
                Value    => 'StdAttachment-Test1' . $RandomID . '.txt',
                Operator => 'EQ',
            },
            {
                Field    => 'Title',
                Value    => $RandomID . 'Ticket One Title',
                Operator => 'EQ',
            },
        ],
        ExpectedResultsArticleStorageDB => [ $TicketIDs[0] ],
        ExpectedResultsArticleStorageFS => [],
    },
    {
        Name   => 'AttachmentName Title (Like) Ticket 1',
        Search => [
            {
                Field    => 'AttachmentName',
                Value    => 'StdAttachment-Test1' . $RandomID . '.txt',
                Operator => 'EQ',
            },
            {
                Field    => 'Title',
                Value    => $RandomID . '*Title',
                Operator => 'LIKE',
            },
        ],
        ExpectedResultsArticleStorageDB => [ $TicketIDs[0] ],
        ExpectedResultsArticleStorageFS => [],
    },
    {
        Name   => 'AttachmentName (AsCustomer)',
        Search => [
            {
                Field    => 'AttachmentName',
                Value    => 'StdAttachment-Test1' . $RandomID . '.txt',
                Operator => 'EQ',
            },
        ],
        UserType                        => 'Customer',
        ExpectedResultsArticleStorageDB => [ $TicketIDs[0], $TicketIDs[1] ],
        ExpectedResultsArticleStorageFS => [],
    },
    {
        Name   => 'AttachmentName (AsCustomer) Ticket2 Article2',
        Search => [
            {
                Field    => 'AttachmentName',
                Value    => 'StdAttachment-Test1' . $RandomID . '.txt',
                Operator => 'EQ',
            },
            {
                Field    => 'Subject',
                Value    => 'T2A2' . $RandomID,
                Operator => 'EQ',
            },
        ],
        UserType                        => 'Customer',
        ExpectedResultsArticleStorageDB => [ $TicketIDs[1] ],
        ExpectedResultsArticleStorageFS => [],
    },
    {
        Name   => 'AttachmentName (AsCustomer) Ticket2 Article3',
        Search => [
            {
                Field    => 'AttachmentName',
                Value    => 'StdAttachment-Test1' . $RandomID . '.txt',
                Operator => 'EQ',
            },
            {
                Field    => 'Subject',
                Value    => 'T23' . $RandomID,
                Operator => 'EQ',
            },
        ],
        UserType                        => 'Customer',
        ExpectedResultsArticleStorageDB => [],
        ExpectedResultsArticleStorageFS => [],
    },
);

# tests for article search index modules
for my $Module (qw(StaticDB RuntimeDB)) {

    for my $Test (@Tests) {

        # attachment name is not considering for searches using ArticleSotrageFS
        for my $StorageBackend (qw(ArticleStorageDB ArticleStorageFS)) {

            # Make sure that the TicketObject gets recreated for each loop.
            $Kernel::OM->ObjectsDiscard( Objects => ['Ticket'] );

            # For the search it is enough to change the config, the TicketObject does not
            # have to be recreated to use the different base class
            $Kernel::OM->Get('Config')->Set(
                Key   => 'Ticket::StorageModule',
                Value => "Kernel::System::Ticket::$StorageBackend",
            );

            $Kernel::OM->Get('Config')->Set(
                Key   => 'Ticket::SearchIndexModule',
                Value => 'Kernel::System::Ticket::ArticleSearchIndex::' . $Module,
            );

            $Self->True(
                $Kernel::OM->Get('Ticket')->isa( 'Kernel::System::Ticket::' . $StorageBackend ),
                "$Module - $StorageBackend - TicketObject loaded the correct StorageModule",
            );

            $Self->True(
                $Kernel::OM->Get('Ticket')->isa( 'Kernel::System::Ticket::ArticleSearchIndex::' . $Module ),
                "$Module - $StorageBackend - TicketObject loaded the correct ArticleSearchIndex",
            );

            # prepare search
            my @SearchData = (
                {
                    Field    => 'TicketID',
                    Value    => [@TicketIDs],
                    Operator => 'IN',
                }
            );
            push( @SearchData, @{ $Test->{Search} } );

            my @FoundTicketIDs =  $Kernel::OM->Get('ObjectSearch')->Search(
                ObjectType => 'Ticket',
                Result     => 'ARRAY',
                Limit      => 2,
                Search     => {
                    AND => \@SearchData,
                },
                Sort       => [
                    {
                        Field     => 'Age',
                        Direction => 'descending',
                    }
                ],
                UserType   => $Test->{UserType},
                UserID     => 1,
            );

            @FoundTicketIDs = sort @FoundTicketIDs;

            $Self->IsDeeply(
                \@FoundTicketIDs,
                $Test->{"ExpectedResults$StorageBackend"},
                "$Module - $Test->{Name} $StorageBackend TicketSearch() -"
            );
        }
    }
}

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
