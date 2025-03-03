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

use Kernel::System::Role::Permission;
use Kernel::System::VariableCheck qw(:all);

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

my %TicketIDs = (
    'User Counter Test' => 0,
    'User Counter Test 2' => 0,
);

my @Tests = (
    {
        Name   => 'TicketCreate for UserID 1',
        Action => sub {
            return $TicketIDs{'User Counter Test'} = $Kernel::OM->Get('Ticket')->TicketCreate(
                Title          => 'User Counter Test',
                QueueID        => 1,
                Lock           => 'unlock',
                Priority       => '3 normal',
                State          => 'new',
                OrganisationID => 1,
                ContactID      => 1,
                OwnerID        => $UserID1,
                UserID         => 1,
            );
        },
        Expect => {
            $UserID1 => {
                Owned => 1,
                OwnedAndUnseen => 1,
                OwnedAndLocked => undef,
                OwnedAndLockedAndUnseen => undef,
                Watched => undef,
                WatchedAndUnseen => undef,
            },
            $UserID2 => {
                Owned => undef,
                OwnedAndUnseen => undef,
                OwnedAndLocked => undef,
                OwnedAndLockedAndUnseen => undef,
                Watched => undef,
                WatchedAndUnseen => undef,
            },
        }
    },
    {
        Name   => 'LockSet for UserID 1 and TicketID '.$TicketIDs{'User Counter Test'},
        Action => sub {
            return $Kernel::OM->Get('Ticket')->TicketLockSet(
                TicketID => $TicketIDs{'User Counter Test'},
                Lock     => 'lock',
                UserID   => $UserID1,
            );
        },
        Expect => {
            $UserID1 => {
                Owned => 1,
                OwnedAndUnseen => 1,
                OwnedAndLocked => 1,
                OwnedAndLockedAndUnseen => 1,
                Watched => undef,
                WatchedAndUnseen => undef,
            },
            $UserID2 => {
                Owned => undef,
                OwnedAndUnseen => undef,
                OwnedAndLocked => undef,
                OwnedAndLockedAndUnseen => undef,
                Watched => undef,
                WatchedAndUnseen => undef,
            },
        }
    },
    {
        Name   => 'FlagSet for UserID 1 and TicketID '.$TicketIDs{'User Counter Test'},
        Action => sub {
            return $Kernel::OM->Get('Ticket')->TicketFlagSet(
                TicketID => $TicketIDs{'User Counter Test'},
                Key      => 'Seen',
                Value    => 1,
                UserID   => $UserID1,
            );
        },
        Expect => {
            $UserID1 => {
                Owned => 1,
                OwnedAndUnseen => undef,
                OwnedAndLocked => 1,
                OwnedAndLockedAndUnseen => undef,
                Watched => undef,
                WatchedAndUnseen => undef,
            },
            $UserID2 => {
                Owned => undef,
                OwnedAndUnseen => undef,
                OwnedAndLocked => undef,
                OwnedAndLockedAndUnseen => undef,
                Watched => undef,
                WatchedAndUnseen => undef,
            },
        }
    },
    {
        Name   => 'WatcherAdd for UserID 1 and TicketID '.$TicketIDs{'User Counter Test'},
        Action => sub {
            return $Kernel::OM->Get('Watcher')->WatcherAdd(
                Object      => 'Ticket',
                ObjectID    => $TicketIDs{'User Counter Test'},
                WatchUserID => $UserID1,
                UserID      => 1,
            );
        },
        Expect => {
            $UserID1 => {
                Owned => 1,
                OwnedAndUnseen => undef,
                OwnedAndLocked => 1,
                OwnedAndLockedAndUnseen => undef,
                Watched => 1,
                WatchedAndUnseen => undef,
            },
            $UserID2 => {
                Owned => undef,
                OwnedAndUnseen => undef,
                OwnedAndLocked => undef,
                OwnedAndLockedAndUnseen => undef,
                Watched => undef,
                WatchedAndUnseen => undef,
            },
        }
    },
    {
        Name   => 'FlagDelete for UserID 1 and TicketID '.$TicketIDs{'User Counter Test'},
        Action => sub {
            return $Kernel::OM->Get('Ticket')->TicketFlagDelete(
                TicketID => $TicketIDs{'User Counter Test'},
                Key      => 'Seen',
                UserID   => $UserID1,
            );
        },
        Expect => {
            $UserID1 => {
                Owned => 1,
                OwnedAndUnseen => 1,
                OwnedAndLocked => 1,
                OwnedAndLockedAndUnseen => 1,
                Watched => 1,
                WatchedAndUnseen => 1,
            },
            $UserID2 => {
                Owned => undef,
                OwnedAndUnseen => undef,
                OwnedAndLocked => undef,
                OwnedAndLockedAndUnseen => undef,
                Watched => undef,
                WatchedAndUnseen => undef,
            },
        }
    },
    {
        Name   => 'WatcherDelete for UserID 1 and TicketID '.$TicketIDs{'User Counter Test'},
        Action => sub {
            return $Kernel::OM->Get('Watcher')->WatcherDelete(
                Object      => 'Ticket',
                ObjectID    => $TicketIDs{'User Counter Test'},
                WatchUserID => $UserID1,
                UserID      => 1,
            );
        },
        Expect => {
            $UserID1 => {
                Owned => 1,
                OwnedAndUnseen => 1,
                OwnedAndLocked => 1,
                OwnedAndLockedAndUnseen => 1,
                Watched => undef,
                WatchedAndUnseen => undef,
            },
            $UserID2 => {
                Owned => undef,
                OwnedAndUnseen => undef,
                OwnedAndLocked => undef,
                OwnedAndLockedAndUnseen => undef,
                Watched => undef,
                WatchedAndUnseen => undef,
            },
        }
    },
    {
        Name   => 'OwnerSet to UserID 2 for TicketID '.$TicketIDs{'User Counter Test'},
        Action => sub {
            return $Kernel::OM->Get('Ticket')->TicketOwnerSet(
                TicketID  => $TicketIDs{'User Counter Test'},
                NewUserID => $UserID2,
                UserID    => $UserID1,
            );
        },
        Expect => {
            $UserID1 => {
                Owned => undef,
                OwnedAndUnseen => undef,
                OwnedAndLocked => undef,
                OwnedAndLockedAndUnseen => undef,
                Watched => undef,
                WatchedAndUnseen => undef,
            },
            $UserID2 => {
                Owned => 1,
                OwnedAndUnseen => 1,
                OwnedAndLocked => 1,
                OwnedAndLockedAndUnseen => 1,
                Watched => undef,
                WatchedAndUnseen => undef,
            }
        }
    },
    {
        Name   => 'FlagSet for UserID 2 and TicketID '.$TicketIDs{'User Counter Test'},
        Action => sub {
            return $Kernel::OM->Get('Ticket')->TicketFlagSet(
                TicketID => $TicketIDs{'User Counter Test'},
                Key      => 'Seen',
                Value    => 1,
                UserID   => $UserID2,
            );
        },
        Expect => {
            $UserID1 => {
                Owned => undef,
                OwnedAndUnseen => undef,
                OwnedAndLocked => undef,
                OwnedAndLockedAndUnseen => undef,
                Watched => undef,
                WatchedAndUnseen => undef,
            },
            $UserID2 => {
                Owned => 1,
                OwnedAndUnseen => undef,
                OwnedAndLocked => 1,
                OwnedAndLockedAndUnseen => undef,
                Watched => undef,
                WatchedAndUnseen => undef,
            }
        }
    },
    {
        Name   => 'ArticleCreate for TicketID '.$TicketIDs{'User Counter Test'},
        Action => sub {
            return $Kernel::OM->Get('Ticket')->ArticleCreate(
                TicketID      => $TicketIDs{'User Counter Test'},
                Channel       => 'note',
                SenderType    => 'external',
                Charset       => 'utf-8',
                ContentType   => 'text/plain',
                CustomerVisible => 1,
                From          => 'test@example.com',
                To            => 'test123@example.com',
                Subject       => 'article subject test',
                Body          => 'article body test',
                HistoryType   => 'NewTicket',
                HistoryComment => q{%%},
                UserID        => 1,
            );
        },
        Expect => {
            $UserID1 => {
                Owned => undef,
                OwnedAndUnseen => undef,
                OwnedAndLocked => undef,
                OwnedAndLockedAndUnseen => undef,
                Watched => undef,
                WatchedAndUnseen => undef,
            },
            $UserID2 => {
                Owned => 1,
                OwnedAndUnseen => 1,
                OwnedAndLocked => 1,
                OwnedAndLockedAndUnseen => 1,
                Watched => undef,
                WatchedAndUnseen => undef,
            }
        }
    },
    {
        Name   => 'TicketCreate for UserID 2',
        Action => sub {
            return $TicketIDs{'User Counter Test 2'} = $Kernel::OM->Get('Ticket')->TicketCreate(
                Title          => 'User Counter Test 2',
                QueueID        => 1,
                Lock           => 'unlock',
                Priority       => '3 normal',
                State          => 'new',
                OrganisationID => 1,
                ContactID      => 1,
                OwnerID        => $UserID2,
                UserID         => 1,
            );
        },
        Expect => {
            $UserID1 => {
                Owned => undef,
                OwnedAndUnseen => undef,
                OwnedAndLocked => undef,
                OwnedAndLockedAndUnseen => undef,
                Watched => undef,
                WatchedAndUnseen => undef,
            },
            $UserID2 => {
                Owned => 2,
                OwnedAndUnseen => 2,
                OwnedAndLocked => 1,
                OwnedAndLockedAndUnseen => 1,
                Watched => undef,
                WatchedAndUnseen => undef,
            }
        }
    },
    {
        Name   => 'LockSet for UserID 2 and TicketID '.$TicketIDs{'User Counter Test 2'},
        Action => sub {
            return $Kernel::OM->Get('Ticket')->TicketLockSet(
                TicketID => $TicketIDs{'User Counter Test 2'},
                Lock     => 'lock',
                UserID   => $UserID2,
            );
        },
        Expect => {
            $UserID1 => {
                Owned => undef,
                OwnedAndUnseen => undef,
                OwnedAndLocked => undef,
                OwnedAndLockedAndUnseen => undef,
                Watched => undef,
                WatchedAndUnseen => undef,
            },
            $UserID2 => {
                Owned => 2,
                OwnedAndUnseen => 2,
                OwnedAndLocked => 2,
                OwnedAndLockedAndUnseen => 2,
                Watched => undef,
                WatchedAndUnseen => undef,
            }
        }
    },
    {
        Name   => 'TicketDelete of TicketID '.$TicketIDs{'User Counter Test'},
        Action => sub {
            return $Kernel::OM->Get('Ticket')->TicketDelete(
                TicketID => $TicketIDs{'User Counter Test'},
                UserID   => $UserID1,
            );

        },
        Expect => {
            $UserID1 => {
                Owned => undef,
                OwnedAndUnseen => undef,
                OwnedAndLocked => undef,
                OwnedAndLockedAndUnseen => undef,
                Watched => undef,
                WatchedAndUnseen => undef,
            },
            $UserID2 => {
                Owned => 1,
                OwnedAndUnseen => 1,
                OwnedAndLocked => 1,
                OwnedAndLockedAndUnseen => 1,
                Watched => undef,
                WatchedAndUnseen => undef,
            }
        }
    },
    {
        Name   => 'StateSet(closed) for TicketID '.$TicketIDs{'User Counter Test 2'},
        Action => sub {
            return $Kernel::OM->Get('Ticket')->TicketStateSet(
                TicketID => $TicketIDs{'User Counter Test 2'},
                State    => 'closed',
                UserID   => $UserID2,
            );
        },
        Expect => {
            $UserID1 => {
                Owned => undef,
                OwnedAndUnseen => undef,
                OwnedAndLocked => undef,
                OwnedAndLockedAndUnseen => undef,
                Watched => undef,
                WatchedAndUnseen => undef,
            },
            $UserID2 => {
                Owned => 1,
                OwnedAndUnseen => 1,
                OwnedAndLocked => 1,
                OwnedAndLockedAndUnseen => 1,
                Watched => undef,
                WatchedAndUnseen => undef,
            }
        }
    },
    {
        Name   => 'StateSet(open) for TicketID '.$TicketIDs{'User Counter Test 2'},
        Action => sub {
            return $Kernel::OM->Get('Ticket')->TicketStateSet(
                TicketID => $TicketIDs{'User Counter Test 2'},
                State    => 'open',
                UserID   => $UserID2,
            );
        },
        Expect => {
            $UserID1 => {
                Owned => undef,
                OwnedAndUnseen => undef,
                OwnedAndLocked => undef,
                OwnedAndLockedAndUnseen => undef,
                Watched => undef,
                WatchedAndUnseen => undef,
            },
            $UserID2 => {
                Owned => 1,
                OwnedAndUnseen => 1,
                OwnedAndLocked => 1,
                OwnedAndLockedAndUnseen => 1,
                Watched => undef,
                WatchedAndUnseen => undef,
            }
        }
    },
    {
        Name   => 'WatcherAdd and FlagDelete for TicketID '.$TicketIDs{'User Counter Test 2'},
        Action => sub {
            $Kernel::OM->Get('Ticket')->TicketFlagDelete(
                TicketID => $TicketIDs{'User Counter Test 2'},
                Key      => 'Seen',
                UserID   => $UserID2,
            );
            return $Kernel::OM->Get('Watcher')->WatcherAdd(
                Object      => 'Ticket',
                ObjectID    => $TicketIDs{'User Counter Test 2'},
                WatchUserID => $UserID2,
                UserID      => 1,
            );
        },
        Expect => {
            $UserID1 => {
                Owned => undef,
                OwnedAndUnseen => undef,
                OwnedAndLocked => undef,
                OwnedAndLockedAndUnseen => undef,
                Watched => undef,
                WatchedAndUnseen => undef,
            },
            $UserID2 => {
                Owned => 1,
                OwnedAndUnseen => 1,
                OwnedAndLocked => 1,
                OwnedAndLockedAndUnseen => 1,
                Watched => 1,
                WatchedAndUnseen => 1,
            }
        }
    },
    {
        Name   => 'FlagSet for TicketID '.$TicketIDs{'User Counter Test 2'},
        Action => sub {
            return $Kernel::OM->Get('Ticket')->TicketFlagSet(
                TicketID => $TicketIDs{'User Counter Test 2'},
                Key      => 'Seen',
                Value    => 1,
                UserID   => $UserID2,
            );
        },
        Expect => {
            $UserID1 => {
                Owned => undef,
                OwnedAndUnseen => undef,
                OwnedAndLocked => undef,
                OwnedAndLockedAndUnseen => undef,
                Watched => undef,
                WatchedAndUnseen => undef,
            },
            $UserID2 => {
                Owned => 1,
                OwnedAndUnseen => undef,
                OwnedAndLocked => 1,
                OwnedAndLockedAndUnseen => undef,
                Watched => 1,
                WatchedAndUnseen => undef,
            }
        }
    },
    {
        Name   => 'WatcherDelete on closed ticket',
        Action => sub {
            $TicketIDs{'User Counter Test 3'} = $Kernel::OM->Get('Ticket')->TicketCreate(
                Title          => 'User Counter Test 3',
                QueueID        => 1,
                Lock           => 'unlock',
                Priority       => '3 normal',
                State          => 'new',
                OrganisationID => 1,
                ContactID      => 1,
                OwnerID        => $UserID2,
                UserID         => 1,
            );
            $Kernel::OM->Get('Watcher')->WatcherAdd(
                Object      => 'Ticket',
                ObjectID    => $TicketIDs{'User Counter Test 3'},
                WatchUserID => $UserID1,
                UserID      => 1,
            );
            $Kernel::OM->Get('Ticket')->TicketStateSet(
                TicketID => $TicketIDs{'User Counter Test 3'},
                State    => 'closed',
                UserID   => $UserID2,
            );
            return $Kernel::OM->Get('Watcher')->WatcherDelete(
                Object      => 'Ticket',
                ObjectID    => $TicketIDs{'User Counter Test 3'},
                WatchUserID => $UserID1,
                UserID      => 1,
            );
        },
        Expect => {
            $UserID1 => {
                Owned => undef,
                OwnedAndUnseen => undef,
                OwnedAndLocked => undef,
                OwnedAndLockedAndUnseen => undef,
                Watched => undef,
                WatchedAndUnseen => undef,
            },
            $UserID2 => {
                Owned => 2,
                OwnedAndUnseen => 1,
                OwnedAndLocked => 1,
                OwnedAndLockedAndUnseen => undef,
                Watched => 1,
                WatchedAndUnseen => undef,
            }
        }
    },
);


foreach my $Test ( @Tests ) {

    my $Method  = $Test->{Action};
    my $Success = &$Method();
    $Self->True(
        $Success,
        "Test: $Test->{Name}",
    );

    foreach my $UserID ( sort keys %{$Test->{Expect}} ) {
        # check counters
        my %Counters = $Kernel::OM->Get('User')->GetUserCounters(
            UserID => $UserID
        );
        foreach my $Counter ( sort keys %{$Test->{Expect}->{$UserID}} ) {
            $Self->Is(
                $Counters{Ticket}->{$Counter},
                $Test->{Expect}->{$UserID}->{$Counter},
                "Counter \"$Counter\" for UserID $UserID is ".(defined $Test->{Expect}->{$UserID}->{$Counter} ? $Test->{Expect}->{$UserID}->{$Counter} : 'undef'),
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
