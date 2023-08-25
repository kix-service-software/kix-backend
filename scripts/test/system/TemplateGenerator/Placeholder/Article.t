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

my $TicketID = _CreateTicket(
    Contact  => \%Contact,
    User     => \%User,
    TestName => '_CreateTicket(): ticket create'
);

my %FirstArticle = (
    TicketID         => $TicketID,
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

my %ArticleFirst = _CreateArticle(
    Config   => \%FirstArticle,
    TestName => '_CreateArticle(): First article create'
);

my %LastArticle = (
    TicketID         => $TicketID,
    Channel          => 'note',
    CustomerVisible  => 1,
    SenderType       => 'agent',
    From             => 'unit.test@ut.com',
    To               => "$Contact{Fullname} <$Contact{Email}>",
    Subject          => 'UnitTest Last Article',
    Body             => 'UnitTest Body',
    ContentType      => 'text/plain; charset=utf8',
    HistoryType      => 'AddNote',
    HistoryComment   => 'UnitTest Article!',
    TimeUnit         => 5,
    UserID           => $User{UserID},
);

my %ArticleLast = _CreateArticle(
    Config   => \%LastArticle,
    TestName => '_CreateArticle(): Last article create'
);

my @UnitTests;
# placeholder of KIX_ARTICLE_ with first article
for my $Attribute ( sort keys %ArticleFirst ) {
    push(
        @UnitTests,
        {
            TestName  => "Placeholder: <KIX_ARTICLE_$Attribute>",
            ArticleID => $ArticleFirst{ArticleID},
            Test      => "<KIX_ARTICLE_$Attribute>",
            Expection => defined $ArticleFirst{$Attribute} ? $ArticleFirst{$Attribute} : q{-},
        }
    );
}

# placeholder of KIX_FIRST_ with first article
for my $Attribute ( sort keys %ArticleFirst ) {
    push(
        @UnitTests,
        {
            TestName  => "Placeholder: <KIX_FIRST_$Attribute>",
            TicketID  => $ArticleFirst{TicketID},
            Test      => "<KIX_FIRST_$Attribute>",
            Expection => defined $ArticleFirst{$Attribute} ? $ArticleFirst{$Attribute} : q{-},
        }
    );
}

# placeholder of KIX_ARTICLE_DATA_ with second article
for my $Attribute ( sort keys %ArticleLast ) {
    push(
        @UnitTests,
        {
            TestName  => "Placeholder: <KIX_ARTICLE_DATA_$Attribute>",
            ArticleID => $ArticleLast{ArticleID},
            Test      => "<KIX_ARTICLE_DATA_$Attribute>",
            Expection => defined $ArticleLast{$Attribute} ? $ArticleLast{$Attribute} : q{-},
        }
    );
}

# placeholder of KIX_LAST_ with second article
for my $Attribute ( sort keys %ArticleLast ) {
    push(
        @UnitTests,
        {
            TestName  => "Placeholder: <KIX_LAST_$Attribute>",
            TicketID  => $ArticleLast{TicketID},
            Test      => "<KIX_LAST_$Attribute>",
            Expection => defined $ArticleLast{$Attribute} ? $ArticleLast{$Attribute} : q{-},
        }
    );
}

# placeholder of KIX_AGENT_ with last agent article
for my $Attribute ( sort keys %ArticleLast ) {
    push(
        @UnitTests,
        {
            TestName  => "Placeholder: <KIX_AGENT_$Attribute>",
            TicketID  => $ArticleLast{TicketID},
            Test      => "<KIX_AGENT_$Attribute>",
            Expection => defined $ArticleLast{$Attribute} ? $ArticleLast{$Attribute} : q{-},
        }
    );
}

# placeholder of KIX_CUSTOMER_ with last customer article
for my $Attribute ( sort keys %ArticleLast ) {
    push(
        @UnitTests,
        {
            TestName  => "Placeholder: <KIX_CUSTOMER_$Attribute>",
            TicketID  => $ArticleFirst{TicketID},
            Test      => "<KIX_CUSTOMER_$Attribute>",
            Expection => defined $ArticleFirst{$Attribute} ? $ArticleFirst{$Attribute} : q{-},
        }
    );
}

# placeholder of KIX_ARTICLE_ with ticket attributes there are not exists in article
for my $Attribute (
    qw(
        Queue State Type Priority
    )
) {
    push(
        @UnitTests,
        {
            TestName  => "Placeholder: <KIX_ARTICLE_$Attribute> not exists",
            TicketID  => $ArticleFirst{TicketID},
            Test      => "<KIX_ARTICLE_$Attribute>",
            Expection => defined $ArticleFirst{$Attribute} ? $ArticleFirst{$Attribute} : q{-},
        }
    );
}

_TestRun(
    Tests => \@UnitTests
);

sub _TestRun {
    my (%Param) = @_;

    for my $Test ( @{$Param{Tests}} ) {
        my $Result = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
            RichText  => 0,                                         # if html qouting is needed
            Text      => $Test->{Test},
            Data      => {
                ArticleID => $Test->{ArticleID} || undef
            },
            TicketID  => $Test->{TicketID} || undef,
            UserID    => 1
        );

        $Self->Is(
            $Result,
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

    $Self->True(
        $ID,
        $Param{TestName}
    );

    $Kernel::OM->ObjectsDiscard(
        Objects => [
            'Ticket'
        ]
    );

    return $ID;
}

sub _CreateArticle {
    my (%Param) = @_;

    my $ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
        %{$Param{Config}}
    );

    my %Article = $Kernel::OM->Get('Ticket')->ArticleGet(
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

    return %Article;
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