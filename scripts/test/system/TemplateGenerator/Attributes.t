# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
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

my $TestUser    = $Helper->TestUserCreate(
    Roles => [
        'Ticket Agent'
    ]
);

my %User = $Kernel::OM->Get('User')->GetUserData(
    User  => $TestUser
);

my $TestContactID = $Helper->TestContactCreate();

my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
    ID => $TestContactID
);

my %Ticket = _CreateTicket(
    Contact  => \%Contact,
    User     => \%User,
    TestName => '_CreateTicket(): Ticket create'
);

my $TicketHook = $Kernel::OM->Get('Config')->Get('Ticket::Hook');

my %ArticleConfig = (
    TicketID         => $Ticket{TicketID},
    Channel          => 'email',
    CustomerVisible  => 1,
    SenderType       => 'external',
    To               => 'unit.test@ut.com',
    From             => "$Contact{Fullname} <$Contact{Email}>",
    Subject          => 'UnitTest First Article',
    Body             => 'UnitTest Body',
    ContentType      => 'text/plain; charset=utf8',
    HistoryType      => 'AddNote',
    HistoryComment   => 'UnitTest Article!',
    TimeUnit         => 5,
    UserID           => 1,
    Loop             => 0,
);

my %Article = _CreateArticle(
    Config   => \%ArticleConfig,
    TestName => '_CreateArticle(): Article create'
);

my %Address = $Kernel::OM->Get('Queue')->GetSystemAddress(
    QueueID => $Ticket{QueueID}
);

my @UnitTests = (
    {
        TestName  => "Attributes(): missing TicketID",
        Data      => {
            Subject => $Article{Subject}
        },
        Expection => {},
        Silent    => 1
    },
    {
        TestName  => "Attributes(): missing Subject",
        TicketID  => $Ticket{TicketID},
        Data      => {},
        Expection => {
            Subject => 'RE:  [' . $TicketHook . $Ticket{TicketNumber} . ']',
            From    => "$Address{RealName} <$Address{Email}>"
        }
    },
    {
        TestName  => "Attributes(): get subject and from",
        TicketID  => $Ticket{TicketID},
        Data      => {
            Subject => $Article{Subject}
        },
        Expection => {
            Subject => 'RE: ' . $Article{Subject} . ' [' . $TicketHook . $Ticket{TicketNumber} . ']',
            From    => "$Address{RealName} <$Address{Email}>"
        },
    },
);

_TestRun(
    Tests => \@UnitTests
);

sub _TestRun {
    my (%Param) = @_;

    for my $Test ( @{$Param{Tests}} ) {
        my %Result = $Kernel::OM->Get('TemplateGenerator')->Attributes(
            RichText  => 0,
            Text      => $Test->{Test},
            Data      => $Test->{Data},
            TicketID  => $Test->{TicketID} || undef,
            UserID    => 1,
            Silent    => $Test->{Silent} || 0
        );
        $Self->IsDeeply(
            \%Result,
            $Test->{Expection},
            $Test->{TestName}
        );
    }

    return 1;
}

sub _CreateTicket {
    my (%Param) = @_;

    my $ID = $Kernel::OM->Get('Ticket')->TicketCreate(
        Title           => 'UnitTest Ticket ' . $Helper->GetRandomID(),
        Queue           => 'Junk',
        Lock            => 'unlock',
        Priority        => '3 normal',
        State           => 'new',
        OrganisationID  => $Contact{PrimaryOrganisationID},
        ContactID       => $Contact{UserID},
        OwnerID         => $User{UserID},
        UserID          => 1
    );

    my %Data = $Kernel::OM->Get('Ticket')->TicketGet(
        TicketID => $ID,
        UserID   => 1
    );

    $Self->True(
        $ID,
        $Param{TestName}
    );

    $Kernel::OM->ObjectsDiscard(
        Objects => [
            'Ticket'
        ]
    );

    return %Data;
}

sub _CreateArticle {
    my (%Param) = @_;

    my $ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
        %{$Param{Config}}
    );

    my %Data = $Kernel::OM->Get('Ticket')->ArticleGet(
        ArticleID => $ArticleID,
        UserID   => 1
    );

    $Self->True(
        $ArticleID,
        $Param{TestName}
    );

    $Kernel::OM->ObjectsDiscard(
        Objects => [
            'Ticket'
        ]
    );

    return %Data;
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