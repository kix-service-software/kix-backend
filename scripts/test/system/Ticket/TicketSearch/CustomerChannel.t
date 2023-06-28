# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::System::VariableCheck qw(:all);

# get config object
my $ConfigObject = $Kernel::OM->Get('Config');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

$ConfigObject->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

$ConfigObject->Set(
    Key   => 'Ticket::StorageModule',
    Value => 'Kernel::System::Ticket::ArticleStorageDB',
);

my $UserID = 1;

# get a random id
my $RandomID = $Helper->GetRandomID();

# Make sure that the TicketObject gets recreated for each loop.
$Kernel::OM->ObjectsDiscard( Objects => ['Ticket'] );

# create test ticket object
my $TicketObject = $Kernel::OM->Get('Ticket');

my @TicketIDs;

# create tickets
for my $TitleDataItem ( 'Ticket One Title', 'Ticket Two Title' ) {
    my $TicketID = $TicketObject->TicketCreate(
        Title        => "$TitleDataItem$RandomID",
        Queue        => 'Junk',
        Lock         => 'unlock',
        Priority     => '3 normal',
        State        => 'new',
        CustomerID   => '123465' . $RandomID,
        Contact      => 'customerOne@example.com',
        OwnerID      => 1,
        UserID       => 1,
    );

    # sanity check
    $Self->True(
        $TicketID,
        "$TitleDataItem TicketCreate() successful for Ticket ID $TicketID",
    );

    # get the Ticket entry
    my %TicketEntry = $TicketObject->TicketGet(
        TicketID      => $TicketID,
        DynamicFields => 0,
        UserID        => $UserID,
    );

    $Self->True(
        IsHashRefWithData( \%TicketEntry ),
        "$TitleDataItem TicketGet() successful for Local TicketGet ID $TicketID",
    );

    push @TicketIDs, $TicketID;
}

# create articles (Channel is 'note', only first article of first ticket is visible for customer)
for my $Item ( 0 .. 1 ) {
    for my $SubjectDataItem (qw( Kumbala Acua )) {
        my $ArticleID = $TicketObject->ArticleCreate(
            TicketID       => $TicketIDs[$Item],
            Channel        => 'note',
            CustomerVisible => ( $Item == 0 && $SubjectDataItem eq 'Kumbala' ) ? 0 : 1,
            SenderType     => 'agent',
            From           => 'Agent Some Agent Some Agent <email@example.com>',
            To             => 'Customer A <customer-a@example.com>',
            Cc             => 'Customer B <customer-b@example.com>',
            ReplyTo        => 'Customer B <customer-b@example.com>',
            Subject        => "$SubjectDataItem$RandomID",
            Body           => 'A text for the body, Title äöüßÄÖÜ€ис',
            ContentType    => 'text/plain; charset=ISO-8859-15',
            HistoryType    => 'OwnerUpdate',
            HistoryComment => 'first article',
            UserID         => 1,
            NoAgentNotify  => 1,
        );
        $Self->True(
            $ArticleID,
            "Article is created - $ArticleID "
        );
    }
}

# actual tests
my @Tests = (
    {
        Name   => 'Agent Interface (Internal/External)',
        Config => {
            Subject => 'Kumbala' . $RandomID,
            UserID  => 1,
        },
        ExpectedResults => [ $TicketIDs[0], $TicketIDs[1] ],
    },
    {
        Name   => 'Customer Interface (Internal/External)',
        Config => {
            Subject        => 'Kumbala' . $RandomID,
            ContactID => 'customerOne@example.com',
        },
        ExpectedResults => [ $TicketIDs[1] ],
        ForBothStorages => 1,
    },
    {
        Name   => 'Customer Interface (External/External)',
        Config => {
            Subject => 'Acua' . $RandomID,
            UserID  => 1,
        },
        ExpectedResults => [ $TicketIDs[0], $TicketIDs[1] ],
    },
);

for my $Test (@Tests) {

    my @FoundTicketIDs = $TicketObject->TicketSearch(
        Result              => 'ARRAY',
        SortBy              => 'Age',
        OrderBy             => 'Down',
        Limit               => 100,
        UserID              => 1,
        ConditionInline     => 0,
        ContentSearchPrefix => '*',
        ContentSearchSuffix => '*',
        FullTextIndex       => 1,
        %{ $Test->{Config} },
    );

    @FoundTicketIDs = sort @FoundTicketIDs;

    $Self->IsDeeply(
        \@FoundTicketIDs,
        $Test->{ExpectedResults},
        "$Test->{Name} TicketSearch() -"
    );
}

# cleanup is done by RestoreDatabase.

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
