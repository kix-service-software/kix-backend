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

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# create test contact
my $ContactID = $Helper->TestContactCreate();

# get contact data
my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
    ID            => $ContactID,
    DynamicFields => 0,
);

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


# define tests
my @Tests = (
    {
        Name   => 'Note, not visible, no recipient',
        Article => {
            Channel         => 'note',
            CustomerVisible => 0,
            To              => undef,
            Cc              => undef,
            Bcc             => undef,
        },
        CustomerVisible => 0,
    },
    {
        Name   => 'Note, visible, no recipient',
        Article => {
            Channel         => 'note',
            CustomerVisible => 1,
            To              => undef,
            Cc              => undef,
            Bcc             => undef,
        },
        CustomerVisible => 1,
    },
    {
        Name   => 'Note, not visible, foreign recipient',
        Article => {
            Channel         => 'note',
            CustomerVisible => 0,
            To              => 'test@test.de',
            Cc              => undef,
            Bcc             => undef,
        },
        CustomerVisible => 0,
    },
    {
        Name   => 'Note, not visible, to contact primary',
        Article => {
            Channel         => 'note',
            CustomerVisible => 0,
            To              => $Contact{Email},
            Cc              => undef,
            Bcc             => undef,
        },
        CustomerVisible => 0,
    },
    {
        Name   => 'Note, not visible, to contact secondary',
        Article => {
            Channel         => 'note',
            CustomerVisible => 0,
            To              => $Contact{Email1},
            Cc              => undef,
            Bcc             => undef,
        },
        CustomerVisible => 0,
    },
    {
        Name   => 'Email, not visible, foreign recipient',
        Article => {
            Channel         => 'email',
            CustomerVisible => 0,
            To              => 'test@test.de',
            Cc              => undef,
            Bcc             => undef,
        },
        CustomerVisible => 0,
    },
    {
        Name   => 'Email, visible, foreign recipient',
        Article => {
            Channel         => 'email',
            CustomerVisible => 1,
            To              => 'test@test.de',
            Cc              => undef,
            Bcc             => undef,
        },
        CustomerVisible => 1,
    },
    {
        Name   => 'Email, not visible, to contact primary',
        Article => {
            Channel         => 'email',
            CustomerVisible => 0,
            To              => $Contact{Email},
            Cc              => undef,
            Bcc             => undef,
        },
        CustomerVisible => 1,
    },
    {
        Name   => 'Email, not visible, to contact secondary',
        Article => {
            Channel         => 'email',
            CustomerVisible => 0,
            To              => $Contact{Email1},
            Cc              => undef,
            Bcc             => undef,
        },
        CustomerVisible => 1,
    },
    {
        Name   => 'Email, not visible, to foreign recipient, cc contact secondary',
        Article => {
            Channel         => 'email',
            CustomerVisible => 0,
            To              => 'test@test.de',
            Cc              => $Contact{Email1},
            Bcc             => undef,
        },
        CustomerVisible => 1,
    },
);

for my $Test (@Tests) {
    my $ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
        TicketID        => $TicketID,
        Channel         => $Test->{Article}->{Channel},
        CustomerVisible => $Test->{Article}->{CustomerVisible},
        To              => $Test->{Article}->{To},
        Cc              => $Test->{Article}->{Cc},
        Bcc             => $Test->{Article}->{Bcc},
        From            => 'test@localhost',
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
