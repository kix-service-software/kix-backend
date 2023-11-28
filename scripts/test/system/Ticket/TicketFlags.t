# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
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

# get ticket object
my $TicketObject = $Kernel::OM->Get('Ticket');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# create a new ticket
my $TicketID = $TicketObject->TicketCreate(
    Title        => 'My ticket created by Agent A',
    Queue        => 'Junk',
    Lock         => 'unlock',
    Priority     => '3 normal',
    State        => 'open',
    ContactID    => 'customer@example.com',
    OwnerID      => 1,
    UserID       => 1,
);

my @Tests = (
    {
        Name   => "$TicketID flag 1",
        Key    => "$TicketID flag 1 key",
        Value  => "$TicketID flag 1 value",
        UserID => 1,
    },
    {
        Name   => "$TicketID flag 2",
        Key    => "$TicketID flag 2 key",
        Value  => "$TicketID flag 2 value",
        UserID => 1,
    },
);

for my $Test (@Tests) {
    my %Flag = $TicketObject->TicketFlagGet(
        TicketID => $TicketID,
        UserID   => 1,
    );
    $Self->False(
        $Flag{ $Test->{Key} },
        "TicketFlagGet() - 1#  Flag '$Test->{Key}' is not given",
    );
    my $Set = $TicketObject->TicketFlagSet(
        TicketID => $TicketID,
        Key      => $Test->{Key},
        Value    => $Test->{Value},
        UserID   => 1,
    );
    $Self->True(
        $Set,
        "TicketFlagSet() - 1# set flag '$Test->{Key}' with true",
    );
    %Flag = $TicketObject->TicketFlagGet(
        TicketID => $TicketID,
        UserID   => 1,
    );
    $Self->Is(
        $Flag{ $Test->{Key} },
        $Test->{Value},
        "TicketFlagGet() - 1# Flag '$Test->{Key}' is given",
    );
    my $Delete = $TicketObject->TicketFlagDelete(
        TicketID => $TicketID,
        Key      => $Test->{Key},
        UserID   => 1,
    );
    $Self->True(
        $Delete,
        "TicketFlagDelete() - 1# delete flag '$Test->{Key}' is given",
    );
    %Flag = $TicketObject->TicketFlagGet(
        TicketID => $TicketID,
        UserID   => 1,
    );
    $Self->False(
        $Flag{ $Test->{Key} },
        "TicketFlagGet() - 2#  Flag '$Test->{Key}' is not deleted (with false)",
    );

    # check delete for all users
    $Set = $TicketObject->TicketFlagSet(
        TicketID => $TicketID,
        Key      => $Test->{Key},
        Value    => $Test->{Value},
        UserID   => 1,
    );
    $Self->True(
        $Set,
        "TicketFlagSet() - 2# set flag '$Test->{Key}' with true",
    );
    %Flag = $TicketObject->TicketFlagGet(
        TicketID => $TicketID,
        UserID   => 1,
    );
    $Self->Is(
        $Flag{ $Test->{Key} },
        $Test->{Value},
        "TicketFlagGet() - 2# Flag '$Test->{Key}' is given",
    );
    $Delete = $TicketObject->TicketFlagDelete(
        TicketID => $TicketID,
        Key      => $Test->{Key},
        AllUsers => 1,
    );
    $Self->True(
        $Delete,
        'TicketFlagDelete() - 2# for AllUsers',
    );
    %Flag = $TicketObject->TicketFlagGet(
        TicketID => $TicketID,
        UserID   => 1,
    );
    $Self->False(
        $Flag{ $Test->{Key} },
        "TicketFlagGet() - 3# Flag '$Test->{Key}' is not given",
    );

    $Set = $TicketObject->TicketFlagSet(
        TicketID => $TicketID,
        Key      => $Test->{Key},
        Value    => $Test->{Value},
        UserID   => 1,
    );
    $Self->True(
        $Set,
        "TicketFlagSet() - 3# set flag '$Test->{Key}' with true",
    );
}

my @SearchTests = (
    {
        Name        => 'One matching flag',
        TicketFlags => [
            {
                Flag  => "$TicketID flag 1 key",
                Value => "$TicketID flag 1 value",
            }
        ],
        Result => 1,
    },
    {
        Name        => 'Another matching flag',
        TicketFlags => [
            {
                Flag  => "$TicketID flag 2 key",
                Value => "$TicketID flag 2 value",
            }
        ],
        Result => 1,
    },
    {
        Name        => 'Two matching flags',
        TicketFlags => [
            {
                Flag  => "$TicketID flag 1 key",
                Value => "$TicketID flag 1 value",
            },
            {
                Flag  => "$TicketID flag 2 key",
                Value => "$TicketID flag 2 value",
            }
        ],
        Result => 1,
    },
    {
        Name        => 'Two flags, one matching',
        TicketFlags => [
            {
                Flag  => "$TicketID flag 1 key",
                Value => "$TicketID flag 1 valueOFF",
            },
            {
                Flag  => "$TicketID flag 2 key",
                Value => "$TicketID flag 2 value",
            }
        ],
        Result => 0,
    },
    {
        Name        => 'Two flags, another matching',
        TicketFlags => [
            {
                Flag  => "$TicketID flag 1 key",
                Value => "$TicketID flag 1 value",
            },
            {
                Flag  => "$TicketID flag 2 key",
                Value => "$TicketID flag 2 valueOFF",
            }
        ],
        Result => 0,
    },
);

for my $SearchTest (@SearchTests) {

    my @Tickets = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Ticket',
        Result     => 'ARRAY',
        Limit      => 2,
        Search     => {
            AND => [
                {
                    Field    => "TicketFlag",
                    Value    => $SearchTest->{TicketFlags},
                    Operator => "EQ"
                }
            ]
        },
        UserID     => 1,
        UserType   => 'Agent',
    );

    $Self->Is(
        scalar @Tickets,
        $SearchTest->{Result},
        "$SearchTest->{Name} - number of found tickets",
    );
}

# create 2 new users
my @UserIDs;
for ( 1 .. 2 ) {
    my $UserLogin = $Helper->TestUserCreate();
    my $UserID = $Kernel::OM->Get('User')->UserLookup( UserLogin => $UserLogin );
    push @UserIDs, $UserID;
}

# create some content
$TicketID = $TicketObject->TicketCreate(
    Title          => 'Some Ticket Title',
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

# create article
my @ArticleIDs;
for ( 1 .. 2 ) {
    my $ArticleID = $TicketObject->ArticleCreate(
        TicketID    => $TicketID,
        Channel     => 'note',
        SenderType  => 'agent',
        From        => 'Some Agent <email@example.com>',
        To          => 'Some Customer <customer@example.com>',
        Subject     => 'Fax Agreement laalala',
        Body        => 'the message text
Perl modules provide a range of features to help you avoid reinventing the wheel, and can be downloaded from CPAN ( http://www.cpan.org/ ). A number of popular modules are included with the Perl distribution itself.',
        ContentType    => 'text/plain; charset=ISO-8859-15',
        HistoryType    => 'OwnerUpdate',
        HistoryComment => 'Some free text!',
        UserID         => 1,
        NoAgentNotify  => 1,                                   # if you don't want to send agent notifications
    );
    push @ArticleIDs, $ArticleID;
}

# check initial ticket and article flags
for my $UserID (@UserIDs) {
    my %TicketFlag = $TicketObject->TicketFlagGet(
        TicketID => $TicketID,
        UserID   => $UserID,
    );
    $Self->False(
        $TicketFlag{Seen},
        "Initial FlagCheck (false) - TicketFlagGet() - TicketID($TicketID) - UserID($UserID)",
    );
    for my $ArticleID (@ArticleIDs) {
        my %ArticleFlag = $TicketObject->ArticleFlagGet(
            TicketID  => $TicketID,
            ArticleID => $ArticleID,
            UserID    => $UserID,
        );
        $Self->False(
            $ArticleFlag{Seen},
            "Initial FlagCheck (false) - ArticleFlagGet() - TicketID($TicketID) - ArticleID($ArticleID) - UserID($UserID)",
        );
    }
}

# update one article
for my $UserID (@UserIDs) {
    my $Success = $TicketObject->ArticleFlagSet(
        ArticleID => $ArticleIDs[0],
        Key       => 'Seen',
        Value     => 1,
        UserID    => $UserID,
    );
    $Self->True(
        $Success,
        "UpdateOne FlagCheck ArticleFlagSet() - ArticleID($ArticleIDs[0])",
    );
    my %TicketFlag = $TicketObject->TicketFlagGet(
        TicketID => $TicketID,
        UserID   => $UserID,
    );
    $Self->False(
        $TicketFlag{Seen},
        "UpdateOne FlagCheck (false) TicketFlagGet() - TicketID($TicketID) - ArticleID($ArticleIDs[0]) - UserID($UserID)",
    );
    my %ArticleFlag = $TicketObject->ArticleFlagGet(
        TicketID  => $TicketID,
        ArticleID => $ArticleIDs[0],
        UserID    => $UserID,
    );
    $Self->True(
        $ArticleFlag{Seen},
        "UpdateOne FlagCheck (true) ArticleFlagGet() - TicketID($TicketID) - ArticleID($ArticleIDs[0]) - UserID($UserID)",
    );
    %ArticleFlag = $TicketObject->ArticleFlagGet(
        TicketID  => $TicketID,
        ArticleID => $ArticleIDs[1],
        UserID    => $UserID,
    );
    $Self->False(
        $ArticleFlag{Seen},
        "UpdateOne FlagCheck (false) ArticleFlagGet() - TicketID($TicketID) - ArticleID($ArticleIDs[1]) - UserID($UserID)",
    );
}

# update second article
for my $UserID (@UserIDs) {
    my $Success = $TicketObject->ArticleFlagSet(
        ArticleID => $ArticleIDs[1],
        Key       => 'Seen',
        Value     => 1,
        UserID    => $UserID,
    );
    $Self->True(
        $Success,
        "UpdateTwo FlagCheck ArticleFlagSet() - ArticleID($ArticleIDs[1])",
    );
    my %TicketFlag = $TicketObject->TicketFlagGet(
        TicketID => $TicketID,
        UserID   => $UserID,
    );
    $Self->True(
        $TicketFlag{Seen},
        "UpdateTwo FlagCheck (true) TicketFlagGet() - TicketID($TicketID) - ArticleID($ArticleIDs[1]) - UserID($UserID)",
    );
    for my $ArticleID (@ArticleIDs) {
        my %ArticleFlag = $TicketObject->ArticleFlagGet(
            TicketID  => $TicketID,
            ArticleID => $ArticleID,
            UserID    => $UserID,
        );
        $Self->True(
            $ArticleFlag{Seen},
            "UpdateTwo FlagCheck (true) ArticleFlagGet() - TicketID($TicketID) - ArticleID($ArticleID) - UserID($UserID)",
        );
    }
}

# tests for the NotTicketFlag TicketSearch feature
#
my $Count = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    UserType   => 'Agent',
    UserID     => 1,
    Search     => {
        AND => [
            {
                Field    => "TicketFlag",
                Value    => [
                    {
                        Flag   => "JustOne",
                        Value  => 42,
                        UserID => $UserIDs[0]
                    }
                ],
                Operator => "EQ",
                Not      => 1
            }
        ]
    },
    Result => 'COUNT',
);

$Self->Is(
    $Count,
    2,
    'NotTicketFlag with non-existing flag'
);

$TicketObject->TicketFlagSet(
    TicketID => $TicketID,
    Key      => 'JustOne',
    Value    => 42,
    UserID   => $UserIDs[0],
);

$TicketObject->TicketFlagSet(
    TicketID => $TicketID,
    Key      => 'AnotherOne',
    Value    => 23,
    UserID   => $UserIDs[0],
);

# ToDo: Clearing the TicketSearch cache should be done in the TicketFlagSet at the end
$Kernel::OM->Get('Cache')->CleanUp(
    Type => "TicketSearch",
);

@Tests = (
    {
        Name     => 'NotTicketFlag excludes ticket with correct flag value',
        Expected => 1,
        Search   => {
            Search     => {
            AND => [
                    {
                        Field    => "TicketFlag",
                        Value    => [
                            {
                                Flag   => "JustOne",
                                Value  => 42,
                                UserID => $UserIDs[0]
                            }
                        ],
                        Operator => "EQ",
                        Not      => 1
                    }
                ]
            }
        },
    },
    {
        Name     => 'NotTicketFlag excludes ticket with correct flag value, and ignores non-existing flags',
        Expected => 1,
        Search   => {
            Search     => {
            AND => [
                    {
                        Field    => "TicketFlag",
                        Value    => [
                            {
                                Flag   => "JustOne",
                                Value  => 42,
                                UserID => $UserIDs[0]
                            },
                            {
                                Flag   => "does not matter",
                                Value  => q{},
                                UserID => $UserIDs[0]
                            },
                        ],
                        Operator => "EQ",
                        Not      => 1
                    }
                ]
            }
        },
    },
    {
        Name     => 'NotTicketFlag ignores flags with different value',
        Expected => 2,
        Search   => {
            Search     => {
            AND => [
                    {
                        Field    => "TicketFlag",
                        Value    => [
                            {
                                Flag   => "JustOne",
                                Value  => 999,
                                UserID => $UserIDs[0]
                            }
                        ],
                        Operator => "EQ",
                        Not      => 1
                    }
                ]
            }
        },
    },
    {
        Name     => 'NotTicketFlag combines with TicketFlag',
        Expected => 1,
        Search   => {
            Search     => {
            AND => [
                    {
                        Field    => "TicketFlag",
                        Value    => [
                            {
                                Flag   => "JustOne",
                                Value  => 42,
                                UserID => $UserIDs[0]
                            },
                            {
                                Flag   => "AnotherOne",
                                Value  => 23,
                                UserID => $UserIDs[0]
                            },
                        ],
                        Operator => "EQ"
                    },
                    {
                        Field    => "TicketFlag",
                        Value    => [
                            {
                                Flag   => "JustOne",
                                Value  => 999,
                                UserID => $UserIDs[0]
                            },
                            {
                                Flag   => "DoesNotExist",
                                Value  => 0,
                                UserID => $UserIDs[0]
                            },
                        ],
                        Operator => "EQ",
                        Not      => 1
                    }
                ]
            }
        },
    },
    {
        Name     => 'NotTicketFlag ignores flags from other users',
        Expected => 2,
        Search   => {
            Search     => {
            AND => [
                    {
                        Field    => "TicketFlag",
                        Value    => [
                            {
                                Flag   => "JustOne",
                                Value  => 42,
                                UserID => $UserIDs[1]
                            }
                        ],
                        Operator => "EQ",
                        Not      => 1
                    }
                ]
            }
        },
    },
);

for my $Test (@Tests) {
    $Count = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Ticket',
        UserType   => 'Agent',
        UserID     => 1,
        Result     => 'COUNT',
        %{ $Test->{Search} },
    );
    $Self->Is( $Count, $Test->{Expected}, $Test->{Name} );
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
