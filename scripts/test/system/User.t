# --
# Modified version of the work: Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/
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

# init fixed time
my $SystemTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
    String => '2024-02-09 00:00:00',
);
$Helper->FixedTimeSet($SystemTime);

$Kernel::OM->Get('Config')->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

# create non existing user login
my $UserRand;
TRY:
for my $Try ( 1 .. 20 ) {

    $UserRand = 'unittest-' . $Helper->GetRandomID();

    my $UserID = $Kernel::OM->Get('User')->UserLookup(
        UserLogin => $UserRand,
        Silent    => 1,
    );

    last TRY if !$UserID;

    next TRY if $Try ne 20;

    $Self->True(
        0,
        'Find non existing user login.',
    );
}

# add user
my $UserID = $Kernel::OM->Get('User')->UserAdd(
    UserLogin    => $UserRand,
    ValidID      => 1,
    ChangeUserID => 1,
    IsAgent      => 1,
);

$Self->True(
    $UserID,
    'UserAdd()',
);

my %UserList = $Kernel::OM->Get('User')->UserList(
    Type  => 'Short',
    Valid => 0,
);

$Self->Is(
    $UserList{$UserID},
    $UserRand,
    "UserList valid 0",
);

%UserList = $Kernel::OM->Get('User')->UserList(
    Type  => 'Short',
    Valid => 1,
);

$Self->Is(
    $UserList{$UserID},
    $UserRand,
    "UserList valid 1",
);

%UserList = $Kernel::OM->Get('User')->UserList(
    Type  => 'Short',
    Valid => 0,
);

$Self->Is(
    $UserList{$UserID},
    $UserRand,
    "UserList valid 0 cached",
);

%UserList = $Kernel::OM->Get('User')->UserList(
    Type  => 'Short',
    Valid => 1,
);

$Self->Is(
    $UserList{$UserID},
    $UserRand,
    "UserList valid 1 cached",
);

my $Update = $Kernel::OM->Get('User')->UserUpdate(
    UserID        => $UserID,
    UserLogin     => $UserRand . '房治郎',
    ValidID       => 2,
    ChangeUserID  => 1,
);

$Self->True(
    $Update,
    'UserUpdate()',
);

my %UserData = $Kernel::OM->Get('User')->GetUserData( UserID => $UserID );

$Self->Is(
    $UserData{UserLogin} || '',
    $UserRand . '房治郎',
    'GetUserData() - UserLogin',
);

%UserList = $Kernel::OM->Get('User')->UserList(
    Type  => 'Short',
    Valid => 0,
);

$Self->Is(
    $UserList{$UserID},
    $UserRand . '房治郎',
    "UserList valid 0",
);

%UserList = $Kernel::OM->Get('User')->UserList(
    Type  => 'Short',
    Valid => 1,
);

$Self->Is(
    $UserList{$UserID},
    undef,
    "UserList valid 1",
);

%UserList = $Kernel::OM->Get('User')->UserList(
    Type  => 'Short',
    Valid => 0,
);

$Self->Is(
    $UserList{$UserID},
    $UserRand . '房治郎',
    "UserList valid 0 cached",
);

%UserList = $Kernel::OM->Get('User')->UserList(
    Type  => 'Short',
    Valid => 1,
);

$Self->Is(
    $UserList{$UserID},
    undef,
    "UserList valid 1 cached",
);

my %UserSearch = $Kernel::OM->Get('User')->UserSearch(
    UserLogin => '*房治郎*',
    Valid     => 0,
);

$Self->Is(
    $UserSearch{$UserID},
    $UserRand . '房治郎',
    "UserSearch(Search) for login after update",
);

# check token support
my $Token = $Kernel::OM->Get('User')->TokenGenerate( UserID => 1 );
$Self->True(
    $Token || 0,
    "TokenGenerate() - $Token",
);

my $TokenValid = $Kernel::OM->Get('User')->TokenCheck(
    Token  => $Token,
    UserID => 1,
);

$Self->True(
    $TokenValid || 0,
    "TokenCheck() - $Token",
);

$TokenValid = $Kernel::OM->Get('User')->TokenCheck(
    Token  => $Token,
    UserID => 1,
);

$Self->True(
    !$TokenValid || 0,
    "TokenCheck() - $Token",
);

$TokenValid = $Kernel::OM->Get('User')->TokenCheck(
    Token  => $Token . '123',
    UserID => 1,
);

$Self->True(
    !$TokenValid || 0,
    "TokenCheck() - $Token" . "123",
);

# testing preferences
my $SetPreferences = $Kernel::OM->Get('User')->SetPreferences(
    Key    => 'UserLanguage',
    Value  => 'fr',
    UserID => $UserID,
);
$Self->True(
    $SetPreferences,
    "SetPreferences - $UserID",
);

my %UserPreferences = $Kernel::OM->Get('User')->GetPreferences(
    UserID => $UserID,
);
$Self->True(
    %UserPreferences || '',
    "GetPreferences - $UserID",
);
$Self->Is(
    $UserPreferences{UserLanguage},
    "fr",
    "GetPreferences $UserID - fr",
);

%UserList = $Kernel::OM->Get('User')->SearchPreferences(
    Key   => 'UserLanguage',
    Value => 'fr',
);

$Self->True(
    %UserList || '',
    "SearchPreferences - $UserID",
);

$Self->Is(
    $UserList{$UserID},
    'fr',
    "SearchPreferences() - $UserID",
);

%UserList = $Kernel::OM->Get('User')->SearchPreferences(
    Key   => 'UserLanguage',
    Value => 'de',
);

$Self->False(
    $UserList{$UserID},
    "SearchPreferences() - $UserID",
);

# look for any value
%UserList = $Kernel::OM->Get('User')->SearchPreferences(
    Key => 'UserLanguage',
);

$Self->True(
    %UserList || '',
    "SearchPreferences - $UserID",
);

$Self->Is(
    $UserList{$UserID},
    'fr',
    "SearchPreferences() - $UserID",
);

#update existing prefs
my $UpdatePreferences = $Kernel::OM->Get('User')->SetPreferences(
    Key    => 'UserLanguage',
    Value  => 'da',
    UserID => $UserID,
);

$Self->True(
    $UpdatePreferences,
    "UpdatePreferences - $UserID",
);

%UserPreferences = $Kernel::OM->Get('User')->GetPreferences(
    UserID => $UserID,
);

$Self->True(
    %UserPreferences || '',
    "GetPreferences - $UserID",
);

$Self->Is(
    $UserPreferences{UserLanguage},
    "da",
    "UpdatePreferences $UserID - da",
);

### UserSearch with IsOutOfOffice ###
## Check without set preference ##
my %UserSearchResult = $Kernel::OM->Get('User')->UserSearch(
    IsOutOfOffice => 1,
    Valid         => 0,
);
$Self->False(
    $UserSearchResult{ $UserID },
    'UserSearch() - IsOutOfOffice = 1, OutOfOffice not set',
);
%UserSearchResult = $Kernel::OM->Get('User')->UserSearch(
    IsOutOfOffice => 0,
    Valid         => 0,
);
$Self->True(
    $UserSearchResult{ $UserID },
    'UserSearch() - IsOutOfOffice = 0, OutOfOffice not set',
);

## Check with set OutOfOffice on same day ##
my $CurrDate = $Kernel::OM->Get('Time')->CurrentTimestamp();
$CurrDate =~ s/^(\d{4}-\d{2}-\d{2}).+$/$1/;
my %Values = (
    'OutOfOfficeStart' => $CurrDate,
    'OutOfOfficeEnd'   => $CurrDate,
);
my %CurrUser = $Kernel::OM->Get('User')->GetUserData(
    UserID => $UserID
);
$Kernel::OM->Get('User')->UserUpdate(
    %CurrUser,
    %Values,
    ChangeUserID => 1
);
%UserSearchResult = $Kernel::OM->Get('User')->UserSearch(
    IsOutOfOffice => 1,
    Valid         => 0,
);
$Self->True(
    $UserSearchResult{ $UserID },
    'UserSearch() - IsOutOfOffice = 1, OutOfOffice set, correct day',
);
%UserSearchResult = $Kernel::OM->Get('User')->UserSearch(
    IsOutOfOffice => 0,
    Valid         => 0,
);
$Self->False(
    $UserSearchResult{ $UserID },
    'UserSearch() - IsOutOfOffice = 0, OutOfOffice set, correct day',
);

## Check with set OutOfOffice on day before ##
$SystemTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
    String => '2024-02-08 00:00:00',
);
$Helper->FixedTimeSet($SystemTime);
%UserSearchResult = $Kernel::OM->Get('User')->UserSearch(
    IsOutOfOffice => 1,
    Valid         => 0,
);
$Self->False(
    $UserSearchResult{ $UserID },
    'UserSearch() - IsOutOfOffice = 1, OutOfOffice set, day before',
);
%UserSearchResult = $Kernel::OM->Get('User')->UserSearch(
    IsOutOfOffice => 0,
    Valid         => 0,
);
$Self->True(
    $UserSearchResult{ $UserID },
    'UserSearch() - IsOutOfOffice = 0, OutOfOffice set, day before',
);

## Check with set OutOfOffice on day after ##
$SystemTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
    String => '2024-02-10 00:00:00',
);
$Helper->FixedTimeSet($SystemTime);
%UserSearchResult = $Kernel::OM->Get('User')->UserSearch(
    IsOutOfOffice => 1,
    Valid         => 0,
);
$Self->False(
    $UserSearchResult{ $UserID },
    'UserSearch() - IsOutOfOffice = 1, OutOfOffice set, day after',
);
%UserSearchResult = $Kernel::OM->Get('User')->UserSearch(
    IsOutOfOffice => 0,
    Valid         => 0,
);
$Self->True(
    $UserSearchResult{ $UserID },
    'UserSearch() - IsOutOfOffice = 0, OutOfOffice set, day after',
);

my $DeleteResult = $Kernel::OM->Get('User')->DeleteNewlyCreatedUser(
    UserID => $UserID,
    ChangeUserID => 1,
);
$Self->True(
    $DeleteResult,
    'DeleteNewlyCreatedUser()',
);

# testing preferences setting empty array
$SetPreferences = $Kernel::OM->Get('User')->SetPreferences(
    Key    => 'UnitTest',
    Value  => [],
    UserID => $UserID,
);
$Self->True(
    $SetPreferences,
    "SetPreferences with empty array - $UserID",
);

### KIX2018-16212 and KIX2018-16652 ###
## Combined tests for UpdateUserCounterObject, PrepareUserCounters,       ##
## GetObjectIDsForCounter, PrepareUserCounters and GetObjectIDsForCounter ##
# prepare user #
$UserID = $Helper->TestUserCreate(
    Result => 'ID',
    Roles  => ['Ticket Agent Base Permission', 'Ticket Agent'],
);
$Self->True(
    $UserID,
    'Created user'
);

# prepare tickets #
my $TicketID1 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => 1,
    Lock           => 'unlock',
    PriorityID     => 1,
    StateID        => 1,
    TypeID         => 1,
    OrganisationID => 1,
    ContactID      => 1,
    OwnerID        => 1,
    ResponsibleID  => 1,
    UserID         => 1
);
$Self->True(
    $TicketID1,
    'Created first ticket'
);
my $TicketID2 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => 1,
    Lock           => 'unlock',
    PriorityID     => 1,
    StateID        => 1,
    TypeID         => 1,
    OrganisationID => 1,
    ContactID      => 1,
    OwnerID        => 1,
    ResponsibleID  => 1,
    UserID         => 1
);
$Self->True(
    $TicketID2,
    'Created second ticket'
);

# prepare tests #
my @Tests = (
    {
        Name        => 'Ticket ' . $TicketID1 . ' / Unseen / Closed / Not owned / Unlocked / Unwatched',
        Parameter   => {
            ObjectID => $TicketID1,
        },
        TicketState => {
            Seen    => 0,
            State   => 0,
            Owner   => 0,
            Locked  => 0,
            Watched => 0,
        },
        Expected    => {
            PrepareUserCounters => {
                All      => {
                    Ticket => {
                        Owned                   => [],
                        OwnedAndLocked          => [],
                        OwnedAndUnseen          => [],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [],
                        WatchedAndUnseen        => [],
                    }
                },
                ObjectID => {
                    Ticket => {
                        Owned                   => [],
                        OwnedAndLocked          => [],
                        OwnedAndUnseen          => [],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [],
                        WatchedAndUnseen        => [],
                    }
                }
            },
            PrepareObjectCounters => {
                Ticket => {
                    Owned                   => [],
                    OwnedAndLocked          => [],
                    OwnedAndUnseen          => [],
                    OwnedAndLockedAndUnseen => [],
                    Watched                 => [],
                    WatchedAndUnseen        => [],
                }
            },
            GetObjectIDsForCounter => {
                All      => {
                    Ticket => {
                        Owned                   => [],
                        OwnedAndLocked          => [],
                        OwnedAndUnseen          => [],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [],
                        WatchedAndUnseen        => [],
                    }
                },
                ObjectID => {
                    Ticket => {
                        Owned                   => [],
                        OwnedAndLocked          => [],
                        OwnedAndUnseen          => [],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [],
                        WatchedAndUnseen        => [],
                    }
                }
            },
            GetUserIDsForCounter => {
                All      => {
                    Ticket => {
                        Owned                   => [],
                        OwnedAndLocked          => [],
                        OwnedAndUnseen          => [],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [],
                        WatchedAndUnseen        => [],
                    }
                },
                UserID => {
                    Ticket => {
                        Owned                   => [],
                        OwnedAndLocked          => [],
                        OwnedAndUnseen          => [],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [],
                        WatchedAndUnseen        => [],
                    }
                }
            }
        }
    },
    {
        Name        => 'Ticket ' . $TicketID1 . ' / Unseen / Open / Owned / Unlocked / Unwatched',
        Parameter   => {
            ObjectID => $TicketID1,
        },
        TicketState => {
            Seen    => 0,
            State   => 1,
            Owner   => 1,
            Locked  => 0,
            Watched => 0,
        },
        Expected    => {
            PrepareUserCounters => {
                All      => {
                    Ticket => {
                        Owned                   => [$TicketID1],
                        OwnedAndLocked          => [],
                        OwnedAndUnseen          => [$TicketID1],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [],
                        WatchedAndUnseen        => [],
                    }
                },
                ObjectID => {
                    Ticket => {
                        Owned                   => [$TicketID1],
                        OwnedAndLocked          => [],
                        OwnedAndUnseen          => [$TicketID1],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [],
                        WatchedAndUnseen        => [],
                    }
                }
            },
            PrepareObjectCounters => {
                Ticket => {
                    Owned                   => [$UserID],
                    OwnedAndLocked          => [],
                    OwnedAndUnseen          => [$UserID],
                    OwnedAndLockedAndUnseen => [],
                    Watched                 => [],
                    WatchedAndUnseen        => [],
                }
            },
            GetObjectIDsForCounter => {
                All      => {
                    Ticket => {
                        Owned                   => [$TicketID1],
                        OwnedAndLocked          => [],
                        OwnedAndUnseen          => [$TicketID1],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [],
                        WatchedAndUnseen        => [],
                    }
                },
                ObjectID => {
                    Ticket => {
                        Owned                   => [$TicketID1],
                        OwnedAndLocked          => [],
                        OwnedAndUnseen          => [$TicketID1],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [],
                        WatchedAndUnseen        => [],
                    }
                }
            },
            GetUserIDsForCounter => {
                All      => {
                    Ticket => {
                        Owned                   => [$UserID],
                        OwnedAndLocked          => [],
                        OwnedAndUnseen          => [$UserID],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [],
                        WatchedAndUnseen        => [],
                    }
                },
                UserID => {
                    Ticket => {
                        Owned                   => [$UserID],
                        OwnedAndLocked          => [],
                        OwnedAndUnseen          => [$UserID],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [],
                        WatchedAndUnseen        => [],
                    }
                }
            }
        }
    },
    {
        Name        => 'Ticket ' . $TicketID2 . ' / Unseen / Closed / Not owned / Unlocked / Watched',
        Parameter   => {
            ObjectID => $TicketID2,
        },
        TicketState => {
            Seen    => 0,
            State   => 0,
            Owner   => 0,
            Locked  => 0,
            Watched => 1,
        },
        Expected    => {
            PrepareUserCounters => {
                All      => {
                    Ticket => {
                        Owned                   => [$TicketID1],
                        OwnedAndLocked          => [],
                        OwnedAndUnseen          => [$TicketID1],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [$TicketID2],
                        WatchedAndUnseen        => [$TicketID2],
                    }
                },
                ObjectID => {
                    Ticket => {
                        Owned                   => [],
                        OwnedAndLocked          => [],
                        OwnedAndUnseen          => [],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [$TicketID2],
                        WatchedAndUnseen        => [$TicketID2],
                    }
                }
            },
            PrepareObjectCounters => {
                Ticket => {
                    Owned                   => [],
                    OwnedAndLocked          => [],
                    OwnedAndUnseen          => [],
                    OwnedAndLockedAndUnseen => [],
                    Watched                 => [$UserID],
                    WatchedAndUnseen        => [$UserID],
                }
            },
            GetObjectIDsForCounter => {
                All      => {
                    Ticket => {
                        Owned                   => [$TicketID1],
                        OwnedAndLocked          => [],
                        OwnedAndUnseen          => [$TicketID1],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [$TicketID2],
                        WatchedAndUnseen        => [$TicketID2],
                    }
                },
                ObjectID => {
                    Ticket => {
                        Owned                   => [],
                        OwnedAndLocked          => [],
                        OwnedAndUnseen          => [],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [$TicketID2],
                        WatchedAndUnseen        => [$TicketID2],
                    }
                }
            },
            GetUserIDsForCounter => {
                All      => {
                    Ticket => {
                        Owned                   => [],
                        OwnedAndLocked          => [],
                        OwnedAndUnseen          => [],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [$UserID],
                        WatchedAndUnseen        => [$UserID],
                    }
                },
                UserID => {
                    Ticket => {
                        Owned                   => [],
                        OwnedAndLocked          => [],
                        OwnedAndUnseen          => [],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [$UserID],
                        WatchedAndUnseen        => [$UserID],
                    }
                }
            }
        }
    },
    {
        Name        => 'Ticket ' . $TicketID1 . ' / Seen / Open / Owned / Locked / Unwatched',
        Parameter   => {
            ObjectID => $TicketID1,
        },
        TicketState => {
            Seen    => 1,
            State   => 1,
            Owner   => 1,
            Locked  => 1,
            Watched => 0,
        },
        Expected    => {
            PrepareUserCounters => {
                All      => {
                    Ticket => {
                        Owned                   => [$TicketID1],
                        OwnedAndLocked          => [$TicketID1],
                        OwnedAndUnseen          => [],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [$TicketID2],
                        WatchedAndUnseen        => [$TicketID2],
                    }
                },
                ObjectID => {
                    Ticket => {
                        Owned                   => [$TicketID1],
                        OwnedAndLocked          => [$TicketID1],
                        OwnedAndUnseen          => [],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [],
                        WatchedAndUnseen        => [],
                    }
                }
            },
            PrepareObjectCounters => {
                Ticket => {
                    Owned                   => [$UserID],
                    OwnedAndLocked          => [$UserID],
                    OwnedAndUnseen          => [],
                    OwnedAndLockedAndUnseen => [],
                    Watched                 => [],
                    WatchedAndUnseen        => [],
                }
            },
            GetObjectIDsForCounter => {
                All      => {
                    Ticket => {
                        Owned                   => [$TicketID1],
                        OwnedAndLocked          => [$TicketID1],
                        OwnedAndUnseen          => [],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [$TicketID2],
                        WatchedAndUnseen        => [$TicketID2],
                    }
                },
                ObjectID => {
                    Ticket => {
                        Owned                   => [$TicketID1],
                        OwnedAndLocked          => [$TicketID1],
                        OwnedAndUnseen          => [],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [],
                        WatchedAndUnseen        => [],
                    }
                }
            },
            GetUserIDsForCounter => {
                All      => {
                    Ticket => {
                        Owned                   => [$UserID],
                        OwnedAndLocked          => [$UserID],
                        OwnedAndUnseen          => [],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [],
                        WatchedAndUnseen        => [],
                    }
                },
                UserID => {
                    Ticket => {
                        Owned                   => [$UserID],
                        OwnedAndLocked          => [$UserID],
                        OwnedAndUnseen          => [],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [],
                        WatchedAndUnseen        => [],
                    }
                }
            }
        }
    },
    {
        Name        => 'Ticket ' . $TicketID2 . ' / Seen / Open / Not owned / Unlocked / Watched',
        Parameter   => {
            ObjectID => $TicketID2,
        },
        TicketState => {
            Seen    => 1,
            State   => 1,
            Owner   => 0,
            Locked  => 0,
            Watched => 1,
        },
        Expected    => {
            PrepareUserCounters => {
                All      => {
                    Ticket => {
                        Owned                   => [$TicketID1],
                        OwnedAndLocked          => [$TicketID1],
                        OwnedAndUnseen          => [],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [$TicketID2],
                        WatchedAndUnseen        => [],
                    }
                },
                ObjectID => {
                    Ticket => {
                        Owned                   => [],
                        OwnedAndLocked          => [],
                        OwnedAndUnseen          => [],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [$TicketID2],
                        WatchedAndUnseen        => [],
                    }
                }
            },
            PrepareObjectCounters => {
                Ticket => {
                    Owned                   => [1],
                    OwnedAndLocked          => [],
                    OwnedAndUnseen          => [1],
                    OwnedAndLockedAndUnseen => [],
                    Watched                 => [$UserID],
                    WatchedAndUnseen        => [],
                }
            },
            GetObjectIDsForCounter => {
                All      => {
                    Ticket => {
                        Owned                   => [$TicketID1],
                        OwnedAndLocked          => [$TicketID1],
                        OwnedAndUnseen          => [],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [$TicketID2],
                        WatchedAndUnseen        => [],
                    }
                },
                ObjectID => {
                    Ticket => {
                        Owned                   => [],
                        OwnedAndLocked          => [],
                        OwnedAndUnseen          => [],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [$TicketID2],
                        WatchedAndUnseen        => [],
                    }
                }
            },
            GetUserIDsForCounter => {
                All      => {
                    Ticket => {
                        Owned                   => [1],
                        OwnedAndLocked          => [],
                        OwnedAndUnseen          => [1],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [$UserID],
                        WatchedAndUnseen        => [],
                    }
                },
                UserID => {
                    Ticket => {
                        Owned                   => [],
                        OwnedAndLocked          => [],
                        OwnedAndUnseen          => [],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [$UserID],
                        WatchedAndUnseen        => [],
                    }
                }
            }
        }
    },
    {
        Name        => 'Ticket ' . $TicketID1 . ' / Unseen / Closed / Owned / Locked / Watched',
        Parameter   => {
            ObjectID => $TicketID1,
        },
        TicketState => {
            Seen    => 0,
            State   => 0,
            Owner   => 1,
            Locked  => 1,
            Watched => 1,
        },
        Expected    => {
            PrepareUserCounters => {
                All      => {
                    Ticket => {
                        Owned                   => [],
                        OwnedAndLocked          => [],
                        OwnedAndUnseen          => [],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [$TicketID1,$TicketID2],
                        WatchedAndUnseen        => [$TicketID1],
                    }
                },
                ObjectID => {
                    Ticket => {
                        Owned                   => [],
                        OwnedAndLocked          => [],
                        OwnedAndUnseen          => [],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [$TicketID1],
                        WatchedAndUnseen        => [$TicketID1],
                    }
                }
            },
            PrepareObjectCounters => {
                Ticket => {
                    Owned                   => [],
                    OwnedAndLocked          => [],
                    OwnedAndUnseen          => [],
                    OwnedAndLockedAndUnseen => [],
                    Watched                 => [$UserID],
                    WatchedAndUnseen        => [$UserID],
                }
            },
            GetObjectIDsForCounter => {
                All      => {
                    Ticket => {
                        Owned                   => [],
                        OwnedAndLocked          => [],
                        OwnedAndUnseen          => [],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [$TicketID1,$TicketID2],
                        WatchedAndUnseen        => [$TicketID1],
                    }
                },
                ObjectID => {
                    Ticket => {
                        Owned                   => [],
                        OwnedAndLocked          => [],
                        OwnedAndUnseen          => [],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [$TicketID1],
                        WatchedAndUnseen        => [$TicketID1],
                    }
                }
            },
            GetUserIDsForCounter => {
                All      => {
                    Ticket => {
                        Owned                   => [],
                        OwnedAndLocked          => [],
                        OwnedAndUnseen          => [],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [$UserID],
                        WatchedAndUnseen        => [$UserID],
                    }
                },
                UserID => {
                    Ticket => {
                        Owned                   => [],
                        OwnedAndLocked          => [],
                        OwnedAndUnseen          => [],
                        OwnedAndLockedAndUnseen => [],
                        Watched                 => [$UserID],
                        WatchedAndUnseen        => [$UserID],
                    }
                }
            }
        }
    }
);

# run tests #
for my $Test ( @Tests ) {
    # prepare ticket state
    if ( $Test->{TicketState}->{Seen} ) {
        my $Success = $Kernel::OM->Get('Ticket')->TicketFlagSet(
            TicketID => $Test->{Parameter}->{ObjectID},
            Key      => 'Seen',
            Value    => 1,
            UserID   => $UserID,
        );
        $Self->True(
            $Success,
            $Test->{Name} . ' - Set ticket seen'
        );
    }
    else {
        my $Success = $Kernel::OM->Get('Ticket')->TicketFlagDelete(
            TicketID => $Test->{Parameter}->{ObjectID},
            Key      => 'Seen',
            UserID   => $UserID,
        );
        $Self->True(
            $Success,
            $Test->{Name} . ' - Set ticket unseen'
        );
    }

    if ( $Test->{TicketState}->{State} ) {
        my $Success = $Kernel::OM->Get('Ticket')->TicketStateSet(
            TicketID => $Test->{Parameter}->{ObjectID},
            State    => 'open',
            UserID   => $UserID,
        );
        $Self->True(
            $Success,
            $Test->{Name} . ' - Set ticket open'
        );
    }
    else {
        my $Success = $Kernel::OM->Get('Ticket')->TicketStateSet(
            TicketID => $Test->{Parameter}->{ObjectID},
            State    => 'closed',
            UserID   => $UserID,
        );
        $Self->True(
            $Success,
            $Test->{Name} . ' - Set ticket closed'
        );
    }

    if ( $Test->{TicketState}->{Owner} ) {
        my $Success = $Kernel::OM->Get('Ticket')->TicketOwnerSet(
            TicketID  => $Test->{Parameter}->{ObjectID},
            NewUserID => $UserID,
            UserID    => $UserID,
        );
        $Self->True(
            $Success,
            $Test->{Name} . ' - Set ticket owner to self'
        );
    }
    else {
        my $Success = $Kernel::OM->Get('Ticket')->TicketOwnerSet(
            TicketID  => $Test->{Parameter}->{ObjectID},
            NewUserID => 1,
            UserID    => $UserID,
        );
        $Self->True(
            $Success,
            $Test->{Name} . ' - Set ticket owner to someone else'
        );
    }

    if ( $Test->{TicketState}->{Locked} ) {
        my $Success = $Kernel::OM->Get('Ticket')->TicketLockSet(
            TicketID => $Test->{Parameter}->{ObjectID},
            Lock     => 'lock',
            UserID   => $UserID,
        );
        $Self->True(
            $Success,
            $Test->{Name} . ' - Set ticket locked'
        );
    }
    else {
        my $Success = $Kernel::OM->Get('Ticket')->TicketLockSet(
            TicketID => $Test->{Parameter}->{ObjectID},
            Lock     => 'unlock',
            UserID   => $UserID,
        );
        $Self->True(
            $Success,
            $Test->{Name} . ' - Set ticket unlocked'
        );
    }

    if ( $Test->{TicketState}->{Watched} ) {
        my $Success = $Kernel::OM->Get('Watcher')->WatcherAdd(
            Object      => 'Ticket',
            ObjectID    => $Test->{Parameter}->{ObjectID},
            WatchUserID => $UserID,
            UserID      => $UserID,
        );
        $Self->True(
            $Success,
            $Test->{Name} . ' - Set ticket watched'
        );
    }
    else {
        my $Success = $Kernel::OM->Get('Watcher')->WatcherDelete(
            Object      => 'Ticket',
            ObjectID    => $Test->{Parameter}->{ObjectID},
            WatchUserID => $UserID,
            UserID      => $UserID,
        );
        $Self->True(
            $Success,
            $Test->{Name} . ' - Set ticket unwatched'
        );
    }

    # check PrepareUserCounters
    my $UserCountersHashAll = $Kernel::OM->Get('User')->PrepareUserCounters(
        UserID => $UserID,
    );
    $Self->IsDeeply(
        $UserCountersHashAll,
        $Test->{Expected}->{PrepareUserCounters}->{All},
        $Test->{Name} . ' - PrepareUserCounters / All'
    );
    my $UserCountersHashObjectID = $Kernel::OM->Get('User')->PrepareUserCounters(
        UserID   => $UserID,
        Category => 'Ticket',
        ObjectID => $Test->{Parameter}->{ObjectID},
    );
    $Self->IsDeeply(
        $UserCountersHashObjectID,
        $Test->{Expected}->{PrepareUserCounters}->{ObjectID},
        $Test->{Name} . ' - PrepareUserCounters / ObjectID'
    );

    # check PrepareObjectCounters
    if ( $Test->{Parameter}->{ObjectID} ) {
        my $ObjectCountersHash = $Kernel::OM->Get('User')->PrepareObjectCounters(
            Category => 'Ticket',
            ObjectID => $Test->{Parameter}->{ObjectID},
        );
        $Self->IsDeeply(
            $ObjectCountersHash,
            $Test->{Expected}->{PrepareObjectCounters},
            $Test->{Name} . ' - PrepareObjectCounters'
        );
    }

    # run UpdateUserCounterObject
    my $Success = $Kernel::OM->Get('User')->UpdateUserCounterObject(
        Category      => 'Ticket',
        ObjectID      => $Test->{Parameter}->{ObjectID},
        CurrentUserID => $UserID
    );
    $Self->True(
        $Success,
        $Test->{Name} . ' - UpdateUserCounterObject'
    );

    # check GetObjectIDsForCounter
    for my $Category ( keys( %{ $Test->{Expected}->{GetObjectIDsForCounter}->{All} } ) ) {
        for my $Counter ( keys( %{ $Test->{Expected}->{GetObjectIDsForCounter}->{All}->{ $Category } } ) ) {
            my @ObjectIDs = $Kernel::OM->Get('User')->GetObjectIDsForCounter(
                UserID   => $UserID,
                Category => $Category,
                Counter  => $Counter,
            );
            $Self->IsDeeply(
                \@ObjectIDs,
                $Test->{Expected}->{GetObjectIDsForCounter}->{All}->{ $Category }->{ $Counter },
                $Test->{Name} . ' - GetObjectIDsForCounter / All / ' . $Category . ' / ' . $Counter
            );
        }
    }
    if ( $Test->{Parameter}->{ObjectID} ) {
        for my $Category ( keys( %{ $Test->{Expected}->{GetObjectIDsForCounter}->{ObjectID} } ) ) {
            for my $Counter ( keys( %{ $Test->{Expected}->{GetObjectIDsForCounter}->{ObjectID}->{ $Category } } ) ) {
                my @ObjectIDs = $Kernel::OM->Get('User')->GetObjectIDsForCounter(
                    UserID   => $UserID,
                    Category => $Category,
                    Counter  => $Counter,
                    ObjectID => $Test->{Parameter}->{ObjectID},
                );
                $Self->IsDeeply(
                    \@ObjectIDs,
                    $Test->{Expected}->{GetObjectIDsForCounter}->{ObjectID}->{ $Category }->{ $Counter },
                    $Test->{Name} . ' - GetObjectIDsForCounter / ObjectID / ' . $Category . ' / ' . $Counter
                );
            }
        }
    }

    # check GetUserIDsForCounter
    if ( $Test->{Parameter}->{ObjectID} ) {
        for my $Category ( keys( %{ $Test->{Expected}->{GetUserIDsForCounter}->{All} } ) ) {
            for my $Counter ( keys( %{ $Test->{Expected}->{GetUserIDsForCounter}->{All}->{ $Category } } ) ) {
                my @UserIDs = $Kernel::OM->Get('User')->GetUserIDsForCounter(
                    ObjectID => $Test->{Parameter}->{ObjectID},
                    Category => $Category,
                    Counter  => $Counter,
                );
                $Self->IsDeeply(
                    \@UserIDs,
                    $Test->{Expected}->{GetUserIDsForCounter}->{All}->{ $Category }->{ $Counter },
                    $Test->{Name} . ' - GetUserIDsForCounter / All / ' . $Category . ' / ' . $Counter
                );
            }
        }
        for my $Category ( keys( %{ $Test->{Expected}->{GetUserIDsForCounter}->{UserID} } ) ) {
            for my $Counter ( keys( %{ $Test->{Expected}->{GetUserIDsForCounter}->{UserID}->{ $Category } } ) ) {
                my @UserIDs = $Kernel::OM->Get('User')->GetUserIDsForCounter(
                    ObjectID => $Test->{Parameter}->{ObjectID},
                    Category => $Category,
                    Counter  => $Counter,
                    UserID   => $UserID,
                );
                $Self->IsDeeply(
                    \@UserIDs,
                    $Test->{Expected}->{GetUserIDsForCounter}->{UserID}->{ $Category }->{ $Counter },
                    $Test->{Name} . ' - GetUserIDsForCounter / UserID / ' . $Category . ' / ' . $Counter
                );
            }
        }
    }
}

# reset fixed time
$Helper->FixedTimeUnset();

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
