# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
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

# create test contact
my $ContactID = $Helper->TestContactCreate();

my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title     => 'Test ticket',
    Queue     => 'Junk',
    Lock      => 'unlock',
    Priority  => '3 normal',
    State     => 'new',
    ContactID => $ContactID,
    OwnerID   => 1,
    UserID    => 1,
);
my $FirstArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID        => $TicketID,
    Channel         => 'email',
    CustomerVisible => 1,
    To              => 'test@localhost',
    From            => 'test@localhost',
    MessageID       => '<test@localhost>',
    SenderType      => 'agent',
    Subject         => 'Test',
    Body            => 'Test',
    ContentType     => 'text/plain; charset=utf-8',
    HistoryType     => 'Misc',
    HistoryComment  => 'article',
    UserID          => 1,
    NoAgentNotify   => 1,
);

# define tests
my @Tests = (
    {
        Name   => 'Note, not visible, no in-reply-to, no references',
        Article => {
            Channel         => 'note',
            CustomerVisible => 0,
            InReplyTo       => undef,
            References      => undef,
        },
        CustomerVisible => 0,
    },
    {
        Name   => 'Note, visible, no in-reply-to, no references',
        Article => {
            Channel         => 'note',
            CustomerVisible => 1,
            InReplyTo       => undef,
            References      => undef,
        },
        CustomerVisible => 1,
    },
    {
        Name   => 'Note, not visible, foreign in-reply-to, no references',
        Article => {
            Channel         => 'note',
            CustomerVisible => 0,
            InReplyTo       => '<test@test.de>',
            References      => undef,
        },
        CustomerVisible => 0,
    },
    {
        Name   => 'Note, not visible, known in-reply-to, no references',
        Article => {
            Channel         => 'note',
            CustomerVisible => 0,
            InReplyTo       => '<test@localhost>',
            References      => undef,
        },
        CustomerVisible => 0,
    },
    {
        Name   => 'Note, not visible, no in-reply-to, known references',
        Article => {
            Channel         => 'note',
            CustomerVisible => 0,
            InReplyTo       => undef,
            References      => '<test@localhost>',
        },
        CustomerVisible => 0,
    },
    {
        Name   => 'Email, not visible, foreign in-reply-to, no references',
        Article => {
            Channel         => 'email',
            CustomerVisible => 0,
            InReplyTo       => '<test@test.de>',
            References      => undef,
        },
        CustomerVisible => 0,
    },
    {
        Name   => 'Email, visible, foreign in-reply-to, no references',
        Article => {
            Channel         => 'email',
            CustomerVisible => 1,
            InReplyTo       => '<test@test.de>',
            References      => undef,
        },
        CustomerVisible => 1,
    },
    {
        Name   => 'Email, not visible, known in-reply-to, no references',
        Article => {
            Channel         => 'email',
            CustomerVisible => 0,
            InReplyTo       => '<test@localhost>',
            References      => undef,
        },
        CustomerVisible => 1,
    },
    {
        Name   => 'Email, not visible, no in-reply-to, known references',
        Article => {
            Channel         => 'email',
            CustomerVisible => 0,
            InReplyTo       => undef,
            References      => '<test@localhost>',
        },
        CustomerVisible => 1,
    },
    {
        Name   => 'Email, not visible, foreign in-reply-to, known and foreign references',
        Article => {
            Channel         => 'email',
            CustomerVisible => 0,
            InReplyTo       => '<test@test.de>',
            References      => '<test@localhost>,<test1@localhost>',
        },
        CustomerVisible => 1,
    },
);

for my $Test (@Tests) {
    my $ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
        TicketID        => $TicketID,
        Channel         => $Test->{Article}->{Channel},
        CustomerVisible => $Test->{Article}->{CustomerVisible},
        To              => 'test@localhost',
        From            => 'test@localhost',
        InReplyTo       => $Test->{Article}->{InReplyTo},
        References      => $Test->{Article}->{References},
        SenderType      => 'agent',
        Subject         => 'Test',
        Body            => 'Test',
        ContentType     => 'text/plain; charset=utf-8',
        HistoryType     => 'Misc',
        HistoryComment  => 'article',
        UserID          => 1,
        NoAgentNotify   => 1,
    );
    $Self->True(
        $ArticleID,
        "$Test->{Name} - Article created"
    );

    my %Article = $Kernel::OM->Get('Ticket')->ArticleGet(
        ArticleID     => $ArticleID,
        DynamicFields => 0,
        UserID        => 1,
    );
    $Self->Is(
        $Article{CustomerVisible},
        $Test->{CustomerVisible},
        "$Test->{Name} - Article has correct visibility"
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
