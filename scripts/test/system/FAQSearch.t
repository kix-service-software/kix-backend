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

use vars qw($Self);

# set config options
my $FAQObject    = $Kernel::OM->Get('FAQ');
my $HelperObject = $Kernel::OM->Get('UnitTest::Helper');
$Kernel::OM->Get('Config')->Set(
    Key   => 'FAQ::ApprovalRequired',
    Value => 0,
);

# generate a random string to help searches
my $RandomID = $HelperObject->GetRandomID();

my @AddedUsers = _AddUsers();
my @AddedFAQs  = _AddFAQs(
    RandomID => $RandomID
);
_AddVotes(
    FAQs => \@AddedFAQs
);

# do vote search tests
my %SearchConfigTemplate = (
    Keyword          => $RandomID,
    Visibility       => [ 'public', 'internal' ],
    OrderBy          => ['FAQID'],
    OrderByDirection => ['Up'],
    Limit            => 150,
    UserID           => 1,
);

_VoteTests(
    Search => \%SearchConfigTemplate,
    FAQs   => \@AddedFAQs
);

_RateTests(
    Search => \%SearchConfigTemplate,
    FAQs   => \@AddedFAQs
);

_ComplexTests(
    Search => \%SearchConfigTemplate,
    FAQs   => \@AddedFAQs
);

_VisibilityTests(
    Search => \%SearchConfigTemplate,
    FAQs   => \@AddedFAQs
);

_UpdateFAQs(
    FAQs     => \@AddedFAQs,
    Users    => \@AddedUsers,
    RandomID => $RandomID,
);

_TimeTests(
    Search => \%SearchConfigTemplate,
    FAQs   => \@AddedFAQs
);

_CreatedUserTests (
    Search => \%SearchConfigTemplate,
    FAQs   => \@AddedFAQs,
    Users  => \@AddedUsers
);

_LastChangedUserTests (
    Search => \%SearchConfigTemplate,
    FAQs   => \@AddedFAQs,
    Users  => \@AddedUsers
);

_ApproveTests (
    Search => \%SearchConfigTemplate,
    FAQs   => \@AddedFAQs,
);

_CleanUp (
    FAQs => \@AddedFAQs
);

_ExecuteFormerTests();

# create different users for CreatedUserIDs search
sub _AddUsers {
    my (%Param) = @_;

    my @Users;
    for my $Counter ( 1 .. 4 ) {
        my $TestUserLogin = $HelperObject->TestUserCreate();
        my $UserID        = $Kernel::OM->Get('User')->UserLookup(
            UserLogin => $TestUserLogin,
        );

        $Self->IsNot(
            undef,
            $UserID,
            "UserCreate() UserID:'$UserID' for FAQSearch()",
        );

        push @Users, $UserID;
    }

    return @Users
}

sub _AddFAQs {
    my ( %Param) = @_;

    my @FAQs;

    # add some FAQs
    my %FAQAddTemplate = (
        Title       => "Some Text $Param{RandomID}",
        CategoryID  => 1,
        Language    => 'en',
        Keywords    => $Param{RandomID},
        Field1      => 'Problem...',
        Field2      => 'Solution...',
        UserID      => 1,
        ContentType => 'text/html',
        Visibility  => 'internal',
    );

    # set -4 minutes freeze time
    my $FixedTime = $HelperObject->FixedTimeSet();
    $HelperObject->FixedTimeAddSeconds(-360);

    for my $Counter ( 1 .. 2 ) {

        my $FAQID = $FAQObject->FAQAdd(
            %FAQAddTemplate,
            UserID => $AddedUsers[ $Counter - 1 ],
        );

        $Self->IsNot(
            undef,
            $FAQID,
            "FAQAdd() FAQID:'$FAQID' for FAQSearch()",
        );

        # add 1 minute to frozen time
        $HelperObject->FixedTimeAddSeconds(60);

        push @FAQs, $FAQID;
    }
    # FAQ 1 was created before 6 minutes
    # FAQ 2 was created before 5 minutes
    # current frozen time -4 minutes

    return @FAQs
}

sub _UpdateFAQs {
    my ( %Param ) = @_;

    # update FAQs
    my %FAQUpdateTemplate = (
        Title       => "New Text $Param{RandomID}",
        CategoryID  => 1,
        Visibility  => 'internal',
        Language    => 'en',
        Keywords    => $Param{RandomID},
        Field1      => 'Problem...',
        Field2      => 'Solution...',
        UserID      => 1,
        ContentType => 'text/html',
    );

    for my $Index ( 0 .. 1  ) {

        # add 1 minute to frozen time
        $HelperObject->FixedTimeAddSeconds(60);

        my %FAQ = $FAQObject->FAQGet(
            ItemID => $Param{FAQs}->[$Index],
            UserID => $Param{Users}->[$Index+2]
        );

        my $Success = $FAQObject->FAQUpdate(
            %FAQ,
            %FAQUpdateTemplate,
            ItemID => $Param{FAQs}->[$Index],
            UserID => $Param{Users}->[$Index+2],
        );

        %FAQ = $FAQObject->FAQGet(
            ItemID => $Param{FAQs}->[$Index],
            UserID => $Param{Users}->[$Index+2]
        );

        $Self->True(
            $Success,
            "FAQUpdate() FAQID:'$Param{FAQs}->[$Index]' for FAQSearch()",
        );
    }

    #  add 2 minute to frozen time ( should be +/- 0 like before first add)
    $HelperObject->FixedTimeAddSeconds(120);

    return 1;
}

sub _AddVotes {
    my ( %Param) = @_;

    # add some votes
    my @VotesToAdd = (
        {
            CreatedBy => 'Some Text',
            ItemID    => $Param{FAQs}->[0],
            IP        => '54.43.30.1',
            Interface => '2',
            Rate      => 100,
            UserID    => 1,
        },
        {
            CreatedBy => 'Some Text',
            ItemID    => $Param{FAQs}->[0],
            IP        => '54.43.30.2',
            Interface => '2',
            Rate      => 50,
            UserID    => 1,
        },
        {
            CreatedBy => 'Some Text',
            ItemID    => $Param{FAQs}->[0],
            IP        => '54.43.30.3',
            Interface => '2',
            Rate      => 50,
            UserID    => 1,
        },
        {
            CreatedBy => 'Some Text',
            ItemID    => $Param{FAQs}->[1],
            IP        => '54.43.30.1',
            Interface => '2',
            Rate      => 50,
            UserID    => 1,
        },
        {
            CreatedBy => 'Some Text',
            ItemID    => $Param{FAQs}->[1],
            IP        => '54.43.30.2',
            Interface => '2',
            Rate      => 50,
            UserID    => 1,
        },
    );

    for my $Vote (@VotesToAdd) {
        my $Success = $FAQObject->VoteAdd( %{$Vote} );

        $Self->True(
            $Success,
            "VoteAdd(): FAQID:'$Vote->{ItemID}' IP:'$Vote->{IP}' Rate:'$Vote->{Rate}' with true",
        );
    }
    return 1;
}

sub _VoteTests {
    my ( %Param ) = @_;

    my %SearchConfig = %{$Param{Search}};

    my @Tests = (
        {
            Name   => 'Votes, Simple Equals Operator',
            Config => {
                %SearchConfig,
                Votes => {
                    Equals => 3,
                },
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
            ],
        },
        {
            Name   => 'Votes, Simple GreaterThan Operator',
            Config => {
                %SearchConfig,
                Votes => {
                    GreaterThan => 2,
                },
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
            ],
        },
        {
            Name   => 'Votes, Simple GreaterThanEquals Operator',
            Config => {
                %SearchConfig,
                Votes => {
                    GreaterThanEquals => 2,
                },
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
                $Param{FAQs}->[1],
            ],
        },
        {
            Name   => 'Votes, Simple SmallerThan Operator',
            Config => {
                %SearchConfig,
                Votes => {
                    SmallerThan => 3,
                },
            },
            ExpectedResults => [
                $Param{FAQs}->[1],
            ],
        },
        {
            Name   => 'Votes, Simple SmallerThanEquals Operator',
            Config => {
                %SearchConfig,
                Votes => {
                    SmallerThanEquals => 3,
                },
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
                $Param{FAQs}->[1],
            ],
        },
        {
            Name   => 'Votes, Multiple Equals Operator',
            Config => {
                %SearchConfig,
                Votes => {
                    Equals => [ 2, 3 ],
                },
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
                $Param{FAQs}->[1],
            ],
        },
        {
            Name   => 'Votes, Multiple GreaterThan Operator',
            Config => {
                %SearchConfig,
                Votes => {
                    GreaterThan => [ 1, 2 ],
                },
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
                $Param{FAQs}->[1],
            ],
        },
        {
            Name   => 'Votes, Multiple GreaterThanEquals Operator',
            Config => {
                %SearchConfig,
                Votes => {
                    GreaterThanEquals => [ 2, 3 ]
                },
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
                $Param{FAQs}->[1],
            ],
        },
        {
            Name   => 'Votes, Multiple SmallerThan Operator',
            Config => {
                %SearchConfig,
                Votes => {
                    SmallerThan => [ 3, 2 ]
                },
            },
            ExpectedResults => [
                $Param{FAQs}->[1],
            ],
        },
        {
            Name   => 'Votes, Multiple SmallerThanEquals Operator',
            Config => {
                %SearchConfig,
                Votes => {
                    SmallerThanEquals => [ 2, 3 ]
                },
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
                $Param{FAQs}->[1],
            ],
        },
        {
            Name   => 'Votes, Wrong Operator',
            Config => {
                %SearchConfig,
                Votes => {
                    LessThanEquals => [4]
                },
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
                $Param{FAQs}->[1],
            ],
        },
        {
            Name   => 'Votes, Complex Operator',
            Config => {
                %SearchConfig,
                Votes => {
                    GreaterThan       => 2,
                    SmallerThanEquals => 3,
                },
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
            ],
        },
        {
            Name   => 'Rate, Simple Equals Operator',
            Config => {
                %SearchConfig,
                Rate => {
                    Equals => 50,
                },
            },
            ExpectedResults => [
                $Param{FAQs}->[1],
            ],
        },
    );

    # execute the tests
    for my $Test (@Tests) {
        my @FAQIDs = $FAQObject->FAQSearch( %{ $Test->{Config} } );

        $Self->IsDeeply(
            \@FAQIDs,
            $Test->{ExpectedResults},
            "$Test->{Name} FAQSearch()",
        );
    }

    return 1;
}

sub _RateTests {
    my ( %Param ) = @_;

    my %SearchConfig = %{$Param{Search}};

    my @Tests = (
        {
            Name   => 'Rate, Simple GreaterThan Operator',
            Config => {
                %SearchConfig,
                Rate => {
                    GreaterThan => 50,
                },
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
            ],
        },
        {
            Name   => 'Rate, Simple GreaterThanEquals Operator',
            Config => {
                %SearchConfig,
                Rate => {
                    GreaterThanEquals => 50,
                },
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
                $Param{FAQs}->[1],
            ],
        },
        {
            Name   => 'Rate, Simple SmallerThan Operator',
            Config => {
                %SearchConfig,
                Rate => {
                    SmallerThan => 66,
                },
            },
            ExpectedResults => [
                $Param{FAQs}->[1],
            ],
        },
        {
            Name   => 'Rate, Simple SmallerThanEquals Operator',
            Config => {
                %SearchConfig,
                Rate => {
                    SmallerThanEquals => 67,
                },
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
                $Param{FAQs}->[1],
            ],
        },
        {
            Name   => 'Rate, Multiple Equals Operator',
            Config => {
                %SearchConfig,
                Rate => {
                    Equals => [ 50, 66.67 ],
                },
            },
            ExpectedResults => [
                $Param{FAQs}->[1],
            ],
        },
        {
            Name   => 'Rate, Multiple GreaterThan Operator',
            Config => {
                %SearchConfig,
                Rate => {
                    GreaterThan => [ 20, 40 ],
                },
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
                $Param{FAQs}->[1],
            ],
        },
        {
            Name   => 'Rate, Multiple GreaterThanEquals Operator',
            Config => {
                %SearchConfig,
                Rate => {
                    GreaterThanEquals => [ 50, 66 ]
                },
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
                $Param{FAQs}->[1],
            ],
        },
        {
            Name   => 'Rate, Multiple SmallerThan Operator',
            Config => {
                %SearchConfig,
                Rate => {
                    SmallerThan => [ 66, 60 ]
                },
            },
            ExpectedResults => [
                $Param{FAQs}->[1],
            ],
        },
        {
            Name   => 'Rate, Multiple SmallerThanEquals Operator',
            Config => {
                %SearchConfig,
                Rate => {
                    SmallerThanEquals => [ 50, 67 ]
                },
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
                $Param{FAQs}->[1],
            ],
        },
        {
            Name   => 'Rate, Wrong Operator',
            Config => {
                %SearchConfig,
                Rate => {
                    LessThanEquals => [10]
                },
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
                $Param{FAQs}->[1],
            ],
        },
        {
            Name   => 'Rate, Complex Operator',
            Config => {
                %SearchConfig,
                Rate => {
                    GreaterThan       => [ 50, 60 ],
                    SmallerThanEquals => 67,
                },
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
            ],
        },
    );

    # execute the tests
    for my $Test (@Tests) {
        my @FAQIDs = $FAQObject->FAQSearch( %{ $Test->{Config} } );

        $Self->IsDeeply(
            \@FAQIDs,
            $Test->{ExpectedResults},
            "$Test->{Name} FAQSearch()",
        );
    }

    return 1;
}

sub _ComplexTests {
    my ( %Param ) = @_;

    my %SearchConfig = %{$Param{Search}};

    my @Tests = (
        {
            Name   => 'Votes, Rate, Complex + Wrong Operator',
            Config => {
                %SearchConfig,
                Votes => {
                    Equals            => [ 2, 3, 4 ],
                    GreaterThanEquals => [3],
                },
                Rate => {
                    GreaterThan => [ 20,  50 ],
                    SmallerThan => [ 100, 120 ],
                    LowerThan   => [99],
                },
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
            ],
        },
    );

    # execute the tests
    for my $Test (@Tests) {
        my @FAQIDs = $FAQObject->FAQSearch( %{ $Test->{Config} } );

        $Self->IsDeeply(
            \@FAQIDs,
            $Test->{ExpectedResults},
            "$Test->{Name} FAQSearch()",
        );
    }

    return 1;
}

sub _VisibilityTests {
    my ( %Param ) = @_;

    my %SearchConfig = %{$Param{Search}};

    my @Tests = (
        {
            Name   => 'Visibility corrtect array',
            Config => {
                %SearchConfig,
                Visibility => [
                    'internal',
                    'external',
                    'public',
                ],
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
                $Param{FAQs}->[1]
            ],
        },
        {
            Name   => 'Visibility Incorrect',
            Config => {
                %SearchConfig,
                Visibility => ['customer'],
            },
            ExpectedResults => [],
        }

    );

    # execute the tests
    for my $Test (@Tests) {
        my @FAQIDs = $FAQObject->FAQSearch( %{ $Test->{Config} } );

        $Self->IsDeeply(
            \@FAQIDs,
            $Test->{ExpectedResults},
            "$Test->{Name} FAQSearch()",
        );
    }

    return 1;
}

sub _TimeTests {
    my ( %Param ) = @_;

    my %SearchConfig = %{$Param{Search}};

    # get time object
    my $TimeObject = $Kernel::OM->Get('Time');

    my $SystemTime = $TimeObject->SystemTime();

    my $DateMinus2Mins = $TimeObject->SystemTime2TimeStamp(
        SystemTime => ( $SystemTime - 120 - 1 ),
    );
    my $DateMinus5Mins = $TimeObject->SystemTime2TimeStamp(
        SystemTime => ( $SystemTime - 300 - 1 ),
    );
    my $DateMinus6Mins = $TimeObject->SystemTime2TimeStamp(
        SystemTime => ( $SystemTime - 360 - 1 ),
    );

    my @Tests = (
        {
            Name   => 'CreateTimeOlderMinutes 3 min',
            Config => {
                %SearchConfig,
                ItemCreateTimeOlderMinutes => 3,
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
                $Param{FAQs}->[1],
            ],
        },
        {
            Name   => 'CreateTimeOlderMinutes 6 min',
            Config => {
                %SearchConfig,
                ItemCreateTimeOlderMinutes => 6,
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
            ],
        },
        {
            Name   => 'CreateTimeNewerMinutes 6 min',
            Config => {
                %SearchConfig,
                ItemCreateTimeNewerMinutes => 6,
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
                $Param{FAQs}->[1],
            ],
        },
        {
            Name   => 'CreateTimeNewerMinutes 5 min',
            Config => {
                %SearchConfig,
                ItemCreateTimeNewerMinutes => 5,
            },
            ExpectedResults => [
                $Param{FAQs}->[1],
            ],
        },
        {
            Name   => 'CreateTimeOlderDate 5 min',
            Config => {
                %SearchConfig,
                ItemCreateTimeOlderDate => $DateMinus5Mins,
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
            ],
        },
        {
            Name   => 'CreateTimeNewerDate 5 min',
            Config => {
                %SearchConfig,
                ItemCreateTimeNewerDate => $DateMinus5Mins,
            },
            ExpectedResults => [
                $Param{FAQs}->[1],
            ],
        },
        {
            Name   => 'CreateTimeOlderDate CreateTimeNewerDate',
            Config => {
                %SearchConfig,
                ItemCreateTimeNewerDate => $DateMinus6Mins,
                ItemCreateTimeOlderDate => $DateMinus5Mins,
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
            ],
        },
        {
            Name   => 'ChangeTimeOlderMinutes 3 min',
            Config => {
                %SearchConfig,
                ItemChangeTimeOlderMinutes => 3,
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
            ],
        },
        {
            Name   => 'ChangeTimeNewerMinutes 2 min',
            Config => {
                %SearchConfig,
                ItemChangeTimeNewerMinutes => 2,
            },
            ExpectedResults => [
                $Param{FAQs}->[1],
            ],
        },
        {
            Name   => 'ChangeTimeOlderDate 2 Min',
            Config => {
                %SearchConfig,
                ItemChangeTimeOlderDate => $DateMinus2Mins,
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
            ],
        },
        {
            Name   => 'ChangeTimeNewerDate 2 Min',
            Config => {
                %SearchConfig,
                ItemChangeTimeNewerDate => $DateMinus2Mins,
            },
            ExpectedResults => [
                $Param{FAQs}->[1],
            ],
        },
    );

    # execute the tests
    for my $Test (@Tests) {

        my @FAQIDs = $FAQObject->FAQSearch( %{ $Test->{Config} } );

        $Self->IsDeeply(
            \@FAQIDs,
            $Test->{ExpectedResults},
            "$Test->{Name} FAQSearch()",
        );
    }

    return 1;
}

sub _CreatedUserTests {
    my ( %Param ) = @_;

    my %SearchConfig = %{$Param{Search}};

    # created user tests
    my @Tests = (
        {
            Name   => 'CreatedUserIDs 1',
            Config => {
                %SearchConfig,
                CreatedUserIDs => [
                    $Param{Users}->[0]
                ],
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
            ],
        },
        {
            Name   => 'CreatedUserIDs 2',
            Config => {
                %SearchConfig,
                CreatedUserIDs => [
                    $Param{Users}->[1]
                ],
            },
            ExpectedResults => [
                $Param{FAQs}->[1],
            ],
        },
        {
            Name   => 'CreatedUserIDs 1 and 2',
            Config => {
                %SearchConfig,
                CreatedUserIDs => [
                    $Param{Users}->[0],
                    $Param{Users}->[1]
                ],
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
                $Param{FAQs}->[1],
            ],
        },
        {
            Name   => 'Wrong CreatedUserIDs Format',
            Config => {
                %SearchConfig,
                CreatedUserIDs => $Param{Users}->[0],
                Silent         => 1
            },
            ExpectedResults => [],
        },
    );

    # execute the tests
    for my $Test (@Tests) {

        my @FAQIDs = $FAQObject->FAQSearch( %{ $Test->{Config} } );

        $Self->IsDeeply(
            \@FAQIDs,
            $Test->{ExpectedResults},
            "$Test->{Name} FAQSearch()",
        );
    }
    return 1;
}

sub _LastChangedUserTests {
    my ( %Param ) = @_;

    my %SearchConfig = %{$Param{Search}};

    # last changed user tests
    my @Tests = (
        {
            Name   => 'LastChangedUserIDs 3',
            Config => {
                %SearchConfig,
                LastChangedUserIDs => [
                    $Param{Users}->[2]
                ],
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
            ],
        },
        {
            Name   => 'LastChangedUserIDs 4',
            Config => {
                %SearchConfig,
                LastChangedUserIDs => [
                    $Param{Users}->[3]
                ],
            },
            ExpectedResults => [
                $Param{FAQs}->[1],
            ],
        },
        {
            Name   => 'LastChangedUserIDs 3 and 4',
            Config => {
                %SearchConfig,
                LastChangedUserIDs => [
                    $Param{Users}->[2],
                    $Param{Users}->[3]
                ],
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
                $Param{FAQs}->[1],
            ],
        },
        {
            Name   => 'Wrong LastChangedUserIDs Format',
            Config => {
                %SearchConfig,
                LastChangedUserIDs => $Param{Users}->[2],
                Silent             => 1
            },
            ExpectedResults => [],
        },
    );

    # execute the tests
    for my $Test (@Tests) {

        my @FAQIDs = $FAQObject->FAQSearch( %{ $Test->{Config} } );

        $Self->IsDeeply(
            \@FAQIDs,
            $Test->{ExpectedResults},
            "$Test->{Name} FAQSearch()",
        );
    }

    return 1;
}

sub _ApproveTests {
    my ( %Param ) = @_;

    my %SearchConfig = %{$Param{Search}};

    # approval tests
    # update database to prevent generation of approval ticket
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => <<"END",
            UPDATE faq_item
            SET approved = ?
            WHERE id = ?
END
        Bind => [
            \0,
            \$Param{FAQs}->[1],
        ],
    );

    my @Tests = (
        {
            Name   => 'Approved 1',
            Config => {
                %SearchConfig,
                Approved => 1,
            },
            ExpectedResults => [
                $Param{FAQs}->[0],
            ],
        },
        {
            Name   => 'Approved 0',
            Config => {
                %SearchConfig,
                Approved => 0,
            },
            ExpectedResults => [
                $Param{FAQs}->[1],
            ],
        },
    );

    # execute the tests
    for my $Test (@Tests) {

        my @FAQIDs = $FAQObject->FAQSearch( %{ $Test->{Config} } );

        $Self->IsDeeply(
            \@FAQIDs,
            $Test->{ExpectedResults},
            "$Test->{Name} FAQSearch()",
        );
    }
    return 1;
}

sub _CleanUp {
    my ( %Param ) = @_;

    # clean the system
    for my $FAQID (@{$Param{FAQs}}) {
        my $Success = $FAQObject->FAQDelete(
            ItemID => $FAQID,
            UserID => 1,
        );

        $Self->True(
            $Success,
            "FAQDelete() for FAQID:'$FAQID' with True",
        );
    }

    # restore time
    $HelperObject->FixedTimeUnset();

    return 1;
}

sub _ExecuteFormerTests {
    my ( %Param ) = @_;

    # execute old tests
    $Self->True(
        1,
        "--Execute Former Tests--",
    );

    my $FAQID1 = $FAQObject->FAQAdd(
        CategoryID  => 1,
        Visibility  => 'external',
        Language    => 'de',
        Approved    => 1,
        Title       => 'Some Text2',
        Keywords    => 'some keywords2',
        Field1      => 'Problem...2',
        Field2      => 'Solution found...2',
        UserID      => 1,
        ContentType => 'text/html',
    );

    $Self->True(
        $FAQID1,
        "FAQAdd() - 1",
    );

    my $FAQID2 = $FAQObject->FAQAdd(
        Title       => 'Title',
        CategoryID  => 1,
        Visibility  => 'internal',
        Language    => 'en',
        Keywords    => q{},
        Field1      => 'Problem Description 1...',
        Field2      => 'Solution not found1...',
        UserID      => 1,
        ContentType => 'text/html',
    );

    $Self->True(
        $FAQID2,
        "FAQAdd() - 2",
    );

    my @FAQIDs = $FAQObject->FAQSearch(
        Number           => q{*},
        What             => '*s*',
        Keyword          => 'some*',
        States           => [ 'public', 'internal' ],
        OrderBy          => ['Votes'],
        OrderByDirection => ['Up'],
        Limit            => 150,
        UserID           => 1,
    );

    my $FAQSearchFound  = 0;
    my $FAQSearchFound2 = 0;
    for my $FAQIDSearch (@FAQIDs) {
        if ( $FAQIDSearch eq $FAQID1 ) {
            $FAQSearchFound = 1;
        }
        if ( $FAQIDSearch eq $FAQID2 ) {
            $FAQSearchFound2 = 1;
        }
    }
    $Self->True(
        $FAQSearchFound,
        "FAQSearch() - $FAQID1",
    );
    $Self->False(
        $FAQSearchFound2,
        "FAQSearch() - $FAQID2",
    );

    @FAQIDs = $FAQObject->FAQSearch(
        Number           => q{*},
        Title            => 'tITLe',
        What             => 'l',
        States           => [ 'public', 'internal' ],
        OrderBy          => ['Created'],
        OrderByDirection => ['Up'],
        Limit            => 150,
        UserID           => 1,
    );

    $FAQSearchFound  = 0;
    $FAQSearchFound2 = 0;
    for my $FAQIDSearch (@FAQIDs) {
        if ( $FAQIDSearch eq $FAQID1 ) {
            $FAQSearchFound = 1;
        }
        if ( $FAQIDSearch eq $FAQID2 ) {
            $FAQSearchFound2 = 1;
        }
    }
    $Self->False(
        $FAQSearchFound,
        "FAQSearch() - $FAQID1",
    );
    $Self->True(
        $FAQSearchFound2,
        "FAQSearch() - $FAQID2",
    );

    @FAQIDs = $FAQObject->FAQSearch(
        Number           => q{*},
        Title            => q{},
        What             => 'solution found',
        States           => [ 'public', 'internal' ],
        OrderBy          => ['Created'],
        OrderByDirection => ['Up'],
        Limit            => 150,
        UserID           => 1,
    );

    $FAQSearchFound  = 0;
    $FAQSearchFound2 = 0;
    for my $FAQIDSearch (@FAQIDs) {
        if ( $FAQIDSearch eq $FAQID1 ) {
            $FAQSearchFound = 1;
        }
        if ( $FAQIDSearch eq $FAQID2 ) {
            $FAQSearchFound2 = 1;
        }
    }
    $Self->True(
        $FAQSearchFound,
        "FAQSearch() literal text - $FAQID1",
    );
    $Self->False(
        $FAQSearchFound2,
        "FAQSearch() literal text - $FAQID2",
    );

    @FAQIDs = $FAQObject->FAQSearch(
        Number           => q{*},
        Title            => q{},
        What             => 'solution+found',
        States           => [ 'public', 'internal' ],
        OrderBy          => ['Created'],
        OrderByDirection => ['Up'],
        Limit            => 150,
        UserID           => 1,
    );

    $FAQSearchFound  = 0;
    $FAQSearchFound2 = 0;
    for my $FAQIDSearch (@FAQIDs) {
        if ( $FAQIDSearch eq $FAQID1 ) {
            $FAQSearchFound = 1;
        }
        if ( $FAQIDSearch eq $FAQID2 ) {
            $FAQSearchFound2 = 1;
        }
    }
    $Self->True(
        $FAQSearchFound,
        "FAQSearch() AND - $FAQID1",
    );
    $Self->True(
        $FAQSearchFound2,
        "FAQSearch() AND - $FAQID2",
    );

    # cleanup the system
    for my $FAQID ( $FAQID1, $FAQID2 ) {
        my $Success = $FAQObject->FAQDelete(
            ItemID => $FAQID,
            UserID => 1,
        );

        $Self->True(
            $Success,
            "FAQDelete() for FAQID:'$FAQID' with True",
        );
    }
    return 1;
}

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
