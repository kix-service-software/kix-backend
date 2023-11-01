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
use Kernel::System::VariableCheck qw(:all);

# get needed objects for rollback
my $QueueObject   = $Kernel::OM->Get('Queue');
my $StateObject   = $Kernel::OM->Get('State');
my $TimeObject    = $Kernel::OM->Get('Time');
my $TypeObject    = $Kernel::OM->Get('Type');

# get actual needed objects
my $ConfigObject       = $Kernel::OM->Get('Config');
my $TicketObject       = $Kernel::OM->Get('Ticket');
my $ContactObject      = $Kernel::OM->Get('Contact');
my $UserObject         = $Kernel::OM->Get('User');
my $DynamicFieldObject = $Kernel::OM->Get('DynamicField');
my $DFBackendObject    = $Kernel::OM->Get('DynamicField::Backend');
my $Helper             = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# prepare test data
my %TestData = _PrepareData();

_CheckWithStaticData();

_DoNegativeTests();

sub _PrepareData {

    # create ticket
    my $TicketID = $TicketObject->TicketCreate(
        Title          => 'some test ticket',
        Queue          => 'Junk',
        Lock           => 'unlock',
        Priority       => '3 normal',
        State          => 'closed',
        OrganisationID => 1,
        ContactID      => 1,
        OwnerID        => 1,
        UserID         => 1,
    );
    $Self->True(
        $TicketID,
        'Create Ticket',
    );

    # create articles
    my $ArticleIDVisible_1 = $TicketObject->ArticleCreate(
        TicketID         => $TicketID,
        ChannelID        => 1,
        CustomerVisible  => 1,
        SenderType       => 'external',
        Subject          => 'Visible 1',
        Body             => 'Visible 1',
        ContentType      => 'text/plain; charset=utf-8',
        HistoryType      => 'AddNote',
        HistoryComment   => q{%%},
        UserID           => 1
    );
    $Self->True(
        $ArticleIDVisible_1,
        'Create 1st visible Article',
    );
    my $ArticleIDVisible_2 = $TicketObject->ArticleCreate(
        TicketID         => $TicketID,
        ChannelID        => 1,
        CustomerVisible  => 1,
        SenderType       => 'external',
        Subject          => 'Visible 2',
        Body             => 'Visible 2',
        ContentType      => 'text/plain; charset=utf-8',
        HistoryType      => 'AddNote',
        HistoryComment   => q{%%},
        UserID           => 1
    );
    $Self->True(
        $ArticleIDVisible_2,
        'Create 2nd visible Article',
    );
    my $ArticleIDNotVisible_1 = $TicketObject->ArticleCreate(
        TicketID         => $TicketID,
        ChannelID        => 1,
        CustomerVisible  => 0,
        SenderType       => 'external',
        Subject          => 'Not Visible 1',
        Body             => 'Not Visible 1',
        ContentType      => 'text/plain; charset=utf-8',
        HistoryType      => 'AddNote',
        HistoryComment   => q{%%},
        UserID           => 1
    );
    $Self->True(
        $ArticleIDNotVisible_1,
        'Create 1st not visible Article',
    );

    return (
        TicketID          => $TicketID,
        VisibleArticleIDs => [
            $ArticleIDVisible_1,
            $ArticleIDVisible_2
        ],
        NotVisibleArticleIDs => [
            $ArticleIDNotVisible_1
        ]
    );
}

sub _CheckWithStaticData {

    _SetConfig(
        'with static for CustomerVisible = 1',
        <<"END",
{
    "Contact": {
        "Ticket": {
            "OwnerID": {
                "SearchStatic": [
                    1
                ]
            }
        },
        "TicketArticle": {
            "CustomerVisible": {
                "SearchStatic": [
                    1
                ]
            }
        }
    }
}
END
        1
    );

    # get visible articles
    my $VisibleArticleIDList = $TicketObject->GetAssignedArticlesForObject(
        TicketID     => $TestData{TicketID},
        ObjectType   => 'Contact',
        UserID       => 1
    );
    $Self->Is(
        scalar(@{$VisibleArticleIDList}),
        scalar(@{ $TestData{VisibleArticleIDs} }),
        'Article list should contain '.scalar(@{ $TestData{VisibleArticleIDs} }).' articles (visible = 1)',
    );
    for my $VisibleArticleID (@{ $TestData{VisibleArticleIDs} }) {
        $Self->ContainedIn(
            $VisibleArticleID,
            $VisibleArticleIDList,
            'List should contain visible articles',
        );
    }
    for my $NotVisibleArticleID (@{ $TestData{NotVisibleArticleIDs} }) {
        $Self->NotContainedIn(
            $NotVisibleArticleID,
            $VisibleArticleIDList,
            'List should NOT contain not visible articles',
        );
    }

    _SetConfig(
        'with static for CustomerVisible = 0',
        <<"END"
{
    "Contact": {
        "Ticket": {
            "OwnerID": {
                "SearchStatic": [
                    1
                ]
            }
        },
        "TicketArticle": {
            "CustomerVisible": {
                "SearchStatic": [
                    0
                ]
            }
        }
    }
}
END
    );

    # get not visible articles
    my $NotVisibleArticleIDList = $TicketObject->GetAssignedArticlesForObject(
        TicketID     => $TestData{TicketID},
        ObjectType   => 'Contact',
        UserID       => 1
    );
    # TODO: 'not visible' is not possible = currently it is like 'all articles'
    $Self->Is(
        scalar(@{$NotVisibleArticleIDList}),
        (scalar(@{ $TestData{VisibleArticleIDs} }) + scalar(@{ $TestData{NotVisibleArticleIDs} })),
        'Article list should contain '.(scalar(@{ $TestData{VisibleArticleIDs} }) + scalar(@{ $TestData{NotVisibleArticleIDs} })).' articles (visible = 1 and 0)',
    );

    for my $NotVisibleArticleID (@{ $TestData{NotVisibleArticleIDs} }) {
        $Self->ContainedIn(
            $NotVisibleArticleID,
            $NotVisibleArticleIDList,
            'List should contain not visible articles',
        );
    }

    _SetConfig(
        'with static for CustomerVisible = 1 OR CustomerVisible = 0 (all)',
        <<"END"
{
    "Contact": {
        "Ticket": {
            "OwnerID": {
                "SearchStatic": [
                    1
                ]
            }
        },
        "TicketArticle": {
            "CustomerVisible": {
                "SearchStatic": [
                    1, 0
                ]
            }
        }
    }
}
END
    );

    # get all articles
    my $AllArticleIDList = $TicketObject->GetAssignedArticlesForObject(
        TicketID     => $TestData{TicketID},
        ObjectType   => 'Contact',
        UserID       => 1
    );
    $Self->Is(
        scalar(@{$AllArticleIDList}),
        (scalar(@{ $TestData{VisibleArticleIDs} }) + scalar(@{ $TestData{NotVisibleArticleIDs} })),
        'Article list should contain '.(scalar(@{ $TestData{VisibleArticleIDs} }) + scalar(@{ $TestData{NotVisibleArticleIDs} })).' articles (visible = 1 and 0)',
    );
    for my $VisibleArticleID (@{ $TestData{VisibleArticleIDs} }) {
        $Self->ContainedIn(
            $VisibleArticleID,
            $AllArticleIDList,
            'List should contain visible articles',
        );
    }
    for my $NotVisibleArticleID (@{ $TestData{NotVisibleArticleIDs} }) {
        $Self->ContainedIn(
            $NotVisibleArticleID,
            $AllArticleIDList,
            'List should contain not visible articles',
        );
    }

    return 1;
}

sub _DoNegativeTests {

    # negative (unknown attribute) ---------------------------
    _SetConfig(
        'unknown attribute',
        <<"END"
{
    "Contact": {
        "Ticket": {
            "OwnerID": {
                "SearchStatic": [
                    1
                ]
            }
        },
        "TicketArticle": {
            "UnknownAttribute": {
                "SearchStatic": [
                    1
                ]
            }
        }
    }
}
END
    );
    my $ArticleIDList = $TicketObject->GetAssignedArticlesForObject(
        TicketID     => $TestData{TicketID},
        ObjectType   => 'Contact',
        UserID       => 1
    );
    $Self->Is(
        scalar(@{$ArticleIDList}),
        0,
        'Article list should be empty (unknown attribute)',
    );

    # negative (missing ticket config - no ticket = no article) ---------------------------
    _SetConfig(
        'negative (missing ticket config)',
        <<"END"
{
    "Contact": {
        "FAQArticle": {
            "CustomerVisible": {
                "SearchStatic": [
                    1
                ]
            }
        },
        "TicketArticle": {
            "CustomerVisible": {
                "SearchStatic": [
                    1
                ]
            }
        }
    }
}
END
    );
    $ArticleIDList = $TicketObject->GetAssignedArticlesForObject(
        TicketID     => $TestData{TicketID},
        ObjectType   => 'Contact',
        UserID       => 1
    );
    $Self->Is(
        scalar(@{$ArticleIDList}),
        0,
        'Article list should be empty (missing ticket config)',
    );

    # negative (missing article config) ---------------------------
    _SetConfig(
        'negative (missing article config)',
        <<"END"
{
    "Contact": {
        "Ticket": {
            "ContactID": {
                "SearchStatic": [
                    1
                ]
            }
        }
    }
}
END
    );
    $ArticleIDList = $TicketObject->GetAssignedArticlesForObject(
        TicketID     => $TestData{TicketID},
        ObjectType   => 'Contact',
        UserID       => 1
    );
    $Self->Is(
        scalar(@{$ArticleIDList}),
        0,
        'Article list should be empty (missing article config)',
    );

    # negative (empty article config) ---------------------------
    _SetConfig(
        'negative (missing article config)',
        <<"END"
{
    "Contact": {
        "Ticket": {
            "ContactID": {
                "SearchStatic": [
                    1
                ]
            }
        },
        "TicketArticle": {}
    }
}
END
    );
    $ArticleIDList = $TicketObject->GetAssignedArticlesForObject(
        TicketID     => $TestData{TicketID},
        ObjectType   => 'Contact',
        UserID       => 1
    );
    $Self->Is(
        scalar(@{$ArticleIDList}),
        0,
        'Article list should be empty (empty article config)',
    );

    # negative (empty attribute) ---------------------------
    _SetConfig(
        'negative (missing attribute)',
        <<"END"
{
    "Contact": {
        "Ticket": {
            "ContactID": {
                "SearchStatic": [
                    1
                ]
            }
        },
        "TicketArticle": {
            "CustomerVisible": {}
        }
    }
}
END
    );
    $ArticleIDList = $TicketObject->GetAssignedArticlesForObject(
        TicketID     => $TestData{TicketID},
        ObjectType   => 'Contact',
        UserID       => 1
    );
    $Self->Is(
        scalar(@{$ArticleIDList}),
        0,
        'Article list should be empty (empty attribute)',
    );

    # negative (empty value) ---------------------------
    _SetConfig(
        'negative (empty value)',
        <<"END"
{
    "Contact": {
        "TicketArticle": {
            "CustomerVisible": {
                "SearchStatic": []
            }
        }
    }
}
END
    );
    $ArticleIDList = $TicketObject->GetAssignedArticlesForObject(
        TicketID     => $TestData{TicketID},
        ObjectType   => 'Contact',
        UserID       => 1
    );
    $Self->Is(
        scalar(@{$ArticleIDList}),
        0,
        'Article list should be empty (empty value)',
    );

    # negative (empty config) ---------------------------
    _SetConfig(
        'negative (empty config)',
        q{}
    );
    $ArticleIDList = $TicketObject->GetAssignedArticlesForObject(
        TicketID     => $TestData{TicketID},
        ObjectType   => 'Contact',
        UserID       => 1
    );
    $Self->Is(
        scalar(@{$ArticleIDList}),
        0,
        'Article list should be empty (empty config)',
    );

    # negative (invalid config, missing " and unnecessary ,) ---------------------------
    _SetConfig(
        'negative (invalid config)',
        <<"END"
{
    "Contact": {
        "Ticket": {
            "ContactID": {
                SearchStatic: [
                    1
                ]
            }
        },
    }
}
END
    );
    $ArticleIDList = $TicketObject->GetAssignedArticlesForObject(
        TicketID     => $TestData{TicketID},
        ObjectType   => 'Contact',
        UserID       => 1,
        Silent       => 1
    );
    $Self->Is(
        scalar(@{$ArticleIDList}),
        0,
        'Article list should be empty (invalid config)',
    );

    # negative (missing ticket id) ---------------------------
    _SetConfig(
        'negative (missing ticket id)',
        <<"END"
{
    "Contact": {
        "Ticket": {
            "ContactID": {
                "SearchStatic": [
                    1
                ]
            }
        },
        "TicketArticle": {
            "CustomerVisible": {
                "SearchStatic": [
                    1
                ]
            }
        }
    }
}
END
    );
    $ArticleIDList = $TicketObject->GetAssignedArticlesForObject(
        # TicketID     => $TestData{TicketID},    # without ticket id
        ObjectType   => 'Contact',
        UserID       => 1
    );
    $Self->Is(
        scalar(@{$ArticleIDList}),
        0,
        'Article list should be empty (missing ticket id)',
    );

    return 1;
}

sub _SetConfig {
    my ($Name, $Config, $DoCheck) = @_;

    $ConfigObject->Set(
        Key   => 'AssignedObjectsMapping',
        Value => $Config,
    );

    # check config
    if ($DoCheck) {
        my $MappingString = $ConfigObject->Get('AssignedObjectsMapping');
        $Self->True(
            IsStringWithData($MappingString) || 0,
            "AssignedObjectsMapping - get config string ($Name)",
        );

        my $NewConfig = 0;
        if ($MappingString && $MappingString eq $Config) {
            $NewConfig = 1;
        }
        $Self->True(
            $NewConfig,
            "AssignedObjectsMapping - mapping is new value",
        );
    }

    return 1;
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
