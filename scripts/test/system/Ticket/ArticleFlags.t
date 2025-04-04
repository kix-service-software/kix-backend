# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
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

my @ArticleIDs;

for my $Item ( 0 .. 1 ) {
    my $ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
        TicketID       => $TicketID,
        Channel        => 'note',
        SenderType     => 'agent',
        From           => 'Some Agent <email@example.com>',
        To             => 'Some Customer <customer-a@example.com>',
        Subject        => 'some short description',
        Body           => 'the message text',
        ContentType    => 'text/plain; charset=ISO-8859-15',
        HistoryType    => 'OwnerUpdate',
        HistoryComment => 'Some free text!',
        UserID         => 1,
        NoAgentNotify  => 1,                                          # if you don't want to send agent notifications
    );

    $Self->True(
        $ArticleID,
        'ArticleCreate()',
    );

    push @ArticleIDs, $ArticleID;
}

# article flag tests
my @Tests = (
    {
        Name   => 'seen flag',
        Key    => 'seen',
        Value  => 1,
        UserID => 1,
    },
    {
        Name   => 'not seen flag',
        Key    => 'not seen',
        Value  => 2,
        UserID => 1,
    },
);

# delete pre-existing article flags which are created on TicketCreate
$Kernel::OM->Get('Ticket')->ArticleFlagDelete(
    ArticleID => $ArticleIDs[0],
    Key       => 'Seen',
    UserID    => 1,
);
$Kernel::OM->Get('Ticket')->ArticleFlagDelete(
    ArticleID => $ArticleIDs[1],
    Key       => 'Seen',
    UserID    => 1,
);

for my $Test (@Tests) {

    # set for article 1
    my %Flag = $Kernel::OM->Get('Ticket')->ArticleFlagGet(
        TicketID  => $TicketID,
        ArticleID => $ArticleIDs[0],
        UserID    => 1,
    );
    $Self->False(
        $Flag{ $Test->{Key} },
        'ArticleFlagGet() article 1',
    );
    my $Set = $Kernel::OM->Get('Ticket')->ArticleFlagSet(
        ArticleID => $ArticleIDs[0],
        Key       => $Test->{Key},
        Value     => $Test->{Value},
        UserID    => 1,
    );
    $Self->True(
        $Set,
        'ArticleFlagSet() article 1',
    );

    # set for article 2
    %Flag = $Kernel::OM->Get('Ticket')->ArticleFlagGet(
        TicketID  => $TicketID,
        ArticleID => $ArticleIDs[1],
        UserID    => 1,
    );
    $Self->False(
        $Flag{ $Test->{Key} },
        'ArticleFlagGet() article 2',
    );
    $Set = $Kernel::OM->Get('Ticket')->ArticleFlagSet(
        ArticleID => $ArticleIDs[1],
        Key       => $Test->{Key},
        Value     => $Test->{Value},
        UserID    => 1,
    );
    $Self->True(
        $Set,
        'ArticleFlagSet() article 2',
    );
    %Flag = $Kernel::OM->Get('Ticket')->ArticleFlagGet(
        TicketID  => $TicketID,
        ArticleID => $ArticleIDs[1],
        UserID    => 1,
    );
    $Self->Is(
        $Flag{ $Test->{Key} },
        $Test->{Value},
        'ArticleFlagGet() article 2',
    );

    # get all flags of ticket
    %Flag = $Kernel::OM->Get('Ticket')->ArticleFlagsOfTicketGet(
        TicketID => $TicketID,
        UserID   => 1,
    );
    $Self->IsDeeply(
        \%Flag,
        {
            $ArticleIDs[0] => {
                $Test->{Key} => $Test->{Value},
            },
            $ArticleIDs[1] => {
                $Test->{Key} => $Test->{Value},
            },
        },
        'ArticleFlagsOfTicketGet() both articles',
    );

    # delete for article 1
    my $Delete = $Kernel::OM->Get('Ticket')->ArticleFlagDelete(
        ArticleID => $ArticleIDs[0],
        Key       => $Test->{Key},
        UserID    => 1,
    );
    $Self->True(
        $Delete,
        'ArticleFlagDelete() article 1',
    );
    %Flag = $Kernel::OM->Get('Ticket')->ArticleFlagGet(
        TicketID  => $TicketID,
        ArticleID => $ArticleIDs[0],
        UserID    => 1,
    );
    $Self->False(
        $Flag{ $Test->{Key} },
        'ArticleFlagGet() article 1',
    );

    %Flag = $Kernel::OM->Get('Ticket')->ArticleFlagsOfTicketGet(
        TicketID => $TicketID,
        UserID   => 1,
    );
    $Self->IsDeeply(
        \%Flag,
        {
            $ArticleIDs[1] => {
                $Test->{Key} => $Test->{Value},
            },
        },
        'ArticleFlagsOfTicketGet() only one article',
    );

    # delete for article 2
    $Delete = $Kernel::OM->Get('Ticket')->ArticleFlagDelete(
        ArticleID => $ArticleIDs[1],
        Key       => $Test->{Key},
        UserID    => 1,
    );
    $Self->True(
        $Delete,
        'ArticleFlagDelete() article 2',
    );

    %Flag = $Kernel::OM->Get('Ticket')->ArticleFlagsOfTicketGet(
        TicketID => $TicketID,
        UserID   => 1,
    );
    $Self->IsDeeply(
        \%Flag,
        {},
        'ArticleFlagsOfTicketGet() empty articles',
    );

    # test ArticleFlagsDelete for AllUsers
    $Set = $Kernel::OM->Get('Ticket')->ArticleFlagSet(
        ArticleID => $ArticleIDs[0],
        Key       => $Test->{Key},
        Value     => $Test->{Value},
        UserID    => 1,
    );
    $Self->True(
        $Set,
        'ArticleFlagSet() article 1',
    );
    %Flag = $Kernel::OM->Get('Ticket')->ArticleFlagGet(
        TicketID  => $TicketID,
        ArticleID => $ArticleIDs[0],
        UserID    => 1,
    );
    $Self->Is(
        $Flag{ $Test->{Key} },
        $Test->{Value},
        'ArticleFlagGet() article 1',
    );
    # test duplicate set
    $Set = $Kernel::OM->Get('Ticket')->ArticleFlagSet(
        ArticleID => $ArticleIDs[0],
        Key       => $Test->{Key},
        Value     => $Test->{Value},
        UserID    => 1,
    );
    $Self->True(
        $Set,
        'ArticleFlagSet() article 1 (duplicate)',
    );
    $Delete = $Kernel::OM->Get('Ticket')->ArticleFlagDelete(
        ArticleID => $ArticleIDs[0],
        Key       => $Test->{Key},
        AllUsers  => 1,
    );
    $Self->True(
        $Delete,
        'ArticleFlagDelete() article 1 for AllUsers',
    );
    %Flag = $Kernel::OM->Get('Ticket')->ArticleFlagGet(
        TicketID  => $TicketID,
        ArticleID => $ArticleIDs[0],
        UserID    => 1,
    );
    $Self->Is(
        $Flag{ $Test->{Key} },
        scalar undef,
        'ArticleFlagGet() article 1 after delete for AllUsers',
    );
}

# test searching for article flags

my @SearchTestFlagsSet = qw( f1 f2 f3 );

for my $Flag (@SearchTestFlagsSet) {
    my $Set = $Kernel::OM->Get('Ticket')->ArticleFlagSet(
        ArticleID => $ArticleIDs[0],
        Key       => $Flag,
        Value     => 42,
        UserID    => 1,
    );

    $Self->True(
        $Set,
        "Can set article flag $Flag",
    );
}

my @FlagSearchTests = (
    {
        Search => {
            AND => [
                {
                    Field    => 'ArticleFlag.Seen',
                    Value    => '42',
                    Operator => 'EQ',
                },
            ],
        },
        Expected => 0,
        Name     => "Wrong flag value leads to no match",
    },
);

for my $Test (@FlagSearchTests) {
    my $Found = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Ticket',
        Result     => 'COUNT',
        UserType   => 'Agent',
        UserID     => 1,
        Search     => $Test->{Search},
    );

    $Self->Is(
        $Found,
        $Test->{Expected},
        $Test->{Name},
    );
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
