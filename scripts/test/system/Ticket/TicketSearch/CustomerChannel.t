# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
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

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my $UserID = 1;

# get a random id
my $RandomID = $Helper->GetRandomID();

# tests for article search index modules
for my $Module (qw(StaticDB RuntimeDB)) {

    # Make sure that the TicketObject gets recreated for each loop.
    $Kernel::OM->ObjectsDiscard( Objects => ['Ticket'] );

    $Kernel::OM->Get('Config')->Set(
        Key   => 'Ticket::SearchIndexModule',
        Value => 'Kernel::System::Ticket::ArticleSearchIndex::' . $Module,
    );

    $Kernel::OM->Get('Config')->Set(
        Key   => 'CheckEmailAddresses',
        Value => 0,
    );

    $Self->True(
        $Kernel::OM->Get('Ticket')->isa( 'Kernel::System::Ticket::ArticleSearchIndex::' . $Module ),
        "$Module - TicketObject loaded the correct backend",
    );

    my @TicketIDs;

    # create tickets
    for my $TitleDataItem ( 'Ticket One Title', 'Ticket Two Title' ) {
        my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
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
            "$Module - $TitleDataItem TicketCreate() successful for Ticket ID $TicketID",
        );

        # get the Ticket entry
        my %TicketEntry = $Kernel::OM->Get('Ticket')->TicketGet(
            TicketID      => $TicketID,
            DynamicFields => 0,
            UserID        => $UserID,
        );

        $Self->True(
            IsHashRefWithData( \%TicketEntry ),
            "$Module - $TitleDataItem TicketGet() successful for Local TicketGet ID $TicketID",
        );

        push( @TicketIDs, $TicketID );
    }

    # create articles (Channel is 'note', only first article of first ticket is visible for customer)
    for my $Item ( 0 .. 1 ) {
        for my $SubjectDataItem (qw( Kumbala Acua )) {
            my $ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
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
                "$Module - Article is created - $ArticleID "
            );
        }
    }

    # actual tests
    my @Tests = (
        {
            Name   => 'Agent Interface (Internal/External)',
            Search => [
                {
                    Field    => 'Subject',
                    Value    => 'Kumbala' . $RandomID,
                    Operator => 'EQ',
                },
            ],
            ExpectedResults => [ $TicketIDs[0], $TicketIDs[1] ],
        },
        {
            Name   => 'Customer Interface (Internal/External)',
            Search => [
                {
                    Field    => 'Subject',
                    Value    => 'Kumbala' . $RandomID,
                    Operator => 'EQ',
                },
            ],
            UserType        => 'Customer',
            ExpectedResults => [ $TicketIDs[1] ],
        },
        {
            Name   => 'Customer Interface (External/External)',
            Search => [
                {
                    Field    => 'Subject',
                    Value    => 'Acua' . $RandomID,
                    Operator => 'EQ',
                },
            ],
            ExpectedResults => [ $TicketIDs[0], $TicketIDs[1] ],
        },
    );

    for my $Test (@Tests) {

        my @FoundTicketIDs =  $Kernel::OM->Get('ObjectSearch')->Search(
            ObjectType => 'Ticket',
            Result     => 'ARRAY',
            Search     => {
                'AND' => $Test->{Search},
            },
            UserType => $Test->{UserType},
            Limit    => 100,
            UserID   => 1,
        );

        @FoundTicketIDs = sort @FoundTicketIDs;

        $Self->IsDeeply(
            \@FoundTicketIDs,
            $Test->{ExpectedResults},
            "$Module - $Test->{Name} TicketSearch() -"
        );
    }

    for my $TicketID (@TicketIDs) {

        # the ticket is no longer needed
        $Kernel::OM->Get('Ticket')->TicketDelete(
            TicketID => $TicketID,
            UserID   => 1,
        );
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
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
