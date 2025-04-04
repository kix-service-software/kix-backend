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

# create a new users for current test
my $UserLogin1 = $Helper->TestUserCreate(
    Roles => ["Ticket Agent"],
);
my %UserData1 = $Kernel::OM->Get('User')->GetUserData(
    User => $UserLogin1,
);
my $UserID1 = $UserData1{UserID};

my $UserLogin2 = $Helper->TestUserCreate(
    Roles => ["Ticket Agent"],
);
my %UserData2 = $Kernel::OM->Get('User')->GetUserData(
    User => $UserLogin2,
);
my $UserID2 = $UserData2{UserID};

my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => 'Some Ticket_Title',
    Queue          => 'Junk',
    Lock           => 'unlock',
    Priority       => '3 normal',
    State          => 'closed',
    OrganisationID => '123465',
    ContactID      => 'customer@example.com',
    OwnerID        => 1,
    UserID         => $UserID1,
);
$Self->True(
    $TicketID,
    'TicketCreate()',
);

my @ArticleIDs;

for my $Item ( 0 .. 2 ) {
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
        UserID         => $UserID1,
        NoAgentNotify  => 1,                                          # if you don't want to send agent notifications
    );

    $Self->True(
        $ArticleID,
        'ArticleCreate()',
    );

    push @ArticleIDs, $ArticleID;
}

my @Tests = (
    {
        Name   => 'initial after creation',
        Expect => {
            $UserID1 => {
                TicketSeenCount  => 1,
                ArticleSeenCount => scalar @ArticleIDs
            },
            $UserID2 => {
                TicketSeenCount  => 0,
                ArticleSeenCount => 0
            }
        }
    },
    {
        Name   => 'user 2 marks article 1 as seen',
        Action => sub {
            return $Kernel::OM->Get('Ticket')->ArticleFlagSet(
                ArticleID => $ArticleIDs[0],
                TicketID  => $TicketID,
                Key      => 'Seen',
                Value    => 1,
                UserID   => $UserID2,
                Silent   => 1,
                NoEvents => 1,
            );
        },
        Expect => {
            $UserID1 => {
                TicketSeenCount  => 1,
                ArticleSeenCount => 3
            },
            $UserID2 => {
                TicketSeenCount  => 0,
                ArticleSeenCount => 1
            }
        }
    },
    {
        Name   => 'user 2 marks whole ticket as seen',
        Action => sub {
            return $Kernel::OM->Get('Ticket')->MarkAsSeen(
                TicketID  => $TicketID,
                UserID    => $UserID2,
            );
        },
        Expect => {
            $UserID1 => {
                TicketSeenCount  => 1,
                ArticleSeenCount => 3
            },
            $UserID2 => {
                TicketSeenCount  => 1,
                ArticleSeenCount => 3
            }
        }
    },
    {
        Name   => 'user 2 adds new article',
        Action => sub {
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
                UserID         => $UserID2,
                NoAgentNotify  => 1,                                          # if you don't want to send agent notifications
            );
            push @ArticleIDs, $ArticleID;
            return $ArticleID;
        },
        Expect => {
            $UserID1 => {
                TicketSeenCount  => 0,
                ArticleSeenCount => 3
            },
            $UserID2 => {
                TicketSeenCount  => 1,
                ArticleSeenCount => 4
            }
        }
    },
    {
        Name   => 'user 1 marks article 4 as seen',
        Action => sub {
            return $Kernel::OM->Get('Ticket')->ArticleFlagSet(
                ArticleID => $ArticleIDs[3],
                TicketID  => $TicketID,
                Key      => 'Seen',
                Value    => 1,
                UserID   => $UserID1,
                Silent   => 1,
                NoEvents => 1,
            );
        },
        Expect => {
            $UserID1 => {
                TicketSeenCount  => 1,
                ArticleSeenCount => 4
            },
            $UserID2 => {
                TicketSeenCount  => 1,
                ArticleSeenCount => 4
            }
        }
    },
    {
        Name   => 'user 2 adds another article',
        Action => sub {
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
                UserID         => $UserID2,
                NoAgentNotify  => 1,                                          # if you don't want to send agent notifications
            );
            push @ArticleIDs, $ArticleID;
            return $ArticleID;
        },
        Expect => {
            $UserID1 => {
                TicketSeenCount  => 0,
                ArticleSeenCount => 4
            },
            $UserID2 => {
                TicketSeenCount  => 1,
                ArticleSeenCount => 5
            }
        }
    },
    {
        Name   => 'user 1 marks whole ticket as seen',
        Action => sub {
            return $Kernel::OM->Get('Ticket')->MarkAsSeen(
                TicketID  => $TicketID,
                UserID    => $UserID1,
            );
        },
        Expect => {
            $UserID1 => {
                TicketSeenCount  => 1,
                ArticleSeenCount => 5
            },
            $UserID2 => {
                TicketSeenCount  => 1,
                ArticleSeenCount => 5
            }
        }
    },
);

foreach my $Test (@Tests) {

    if ( $Test->{Action} ) {
        my $Method  = $Test->{Action};
        my $Success = &$Method();
        $Self->True(
            $Success,
            "Test: $Test->{Name}",
        );
    }

    foreach my $UserID ( sort keys %{$Test->{Expect}} ) {
        my %Result;

        # get article seen count
        foreach my $ArticleID ( @ArticleIDs ) {
            my %Flags = $Kernel::OM->Get('Ticket')->ArticleFlagGet(
                ArticleID => $ArticleID,
                TicketID  => $TicketID,
                UserID    => $UserID,
            );
            $Result{ArticleSeenCount} //= 0;
            $Result{ArticleSeenCount}++ if $Flags{Seen};
        }

        my %Flags = $Kernel::OM->Get('Ticket')->TicketFlagGet(
            TicketID => $TicketID,
            UserID   => $UserID
        );
        $Result{TicketSeenCount} //= 0;
        $Result{TicketSeenCount}++ if $Flags{Seen};

        $Self->IsDeeply(
            \%Result,
            $Test->{Expect}->{$UserID},
            "Test: $Test->{Name} - Seen flags for UserID $UserID",
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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
