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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::FAQArticle::Vote';

# require module
return if ( !$Kernel::OM->Get('Main')->Require( $AttributeModule ) );

# create backend object
my $AttributeObject = $AttributeModule->new( %{ $Self } );
$Self->Is(
    ref( $AttributeObject ),
    $AttributeModule,
    'Attribute object has correct module ref'
);

# check supported methods
for my $Method ( qw(GetSupportedAttributes Search Sort) ) {
    $Self->True(
        $AttributeObject->can($Method),
        'Attribute object can "' . $Method . q{"}
    );
}

# check GetSupportedAttributes
my $AttributeList = $AttributeObject->GetSupportedAttributes();
$Self->IsDeeply(
    $AttributeList,
    {
        Votes => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType    => 'NUMERIC'
        },
        Rating => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType    => 'NUMERIC'
        }
    },
    'GetSupportedAttributes provides expected data'
);

# check Search
my @SearchTests = (
    {
        Name         => 'Search: undef search',
        Search       => undef,
        Expected     => undef
    },
    {
        Name         => 'Search: Value undef',
        Search       => {
            Field    => 'Votes',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Field undef',
        Search       => {
            Field    => undef,
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Field invalid',
        Search       => {
            Field    => 'Test',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator undef',
        Search       => {
            Field    => 'Votes',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'Votes',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field Rating / Operator EQ',
        Search       => {
            Field    => 'Rating',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'GroupBy' => [
                'f.id'
            ],
            'Having' => [
                'AVG(COALESCE(fv0.rate,-1)) = 1'
            ],
            'Join' => [
                'LEFT JOIN faq_voting fv0 ON fv0.item_id = f.id'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Rating / Operator NE',
        Search       => {
            Field    => 'Rating',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'GroupBy' => [
                'f.id'
            ],
            'Having' => [
                'AVG(COALESCE(fv0.rate,-1)) <> 1'
            ],
            'Join' => [
                'LEFT JOIN faq_voting fv0 ON fv0.item_id = f.id'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Rating / Operator LT',
        Search       => {
            Field    => 'Rating',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'GroupBy' => [
                'f.id'
            ],
            'Having' => [
                'AVG(COALESCE(fv0.rate,-1)) < 1'
            ],
            'Join' => [
                'LEFT JOIN faq_voting fv0 ON fv0.item_id = f.id'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Rating / Operator GT',
        Search       => {
            Field    => 'Rating',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'GroupBy' => [
                'f.id'
            ],
            'Having' => [
                'AVG(COALESCE(fv0.rate,-1)) > 1'
            ],
            'Join' => [
                'LEFT JOIN faq_voting fv0 ON fv0.item_id = f.id'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Rating / Operator LTE',
        Search       => {
            Field    => 'Rating',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'GroupBy' => [
                'f.id'
            ],
            'Having' => [
                'AVG(COALESCE(fv0.rate,-1)) <= 1'
            ],
            'Join' => [
                'LEFT JOIN faq_voting fv0 ON fv0.item_id = f.id'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Rating / Operator GTE',
        Search       => {
            Field    => 'Rating',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'GroupBy' => [
                'f.id'
            ],
            'Having' => [
                'AVG(COALESCE(fv0.rate,-1)) >= 1'
            ],
            'Join' => [
                'LEFT JOIN faq_voting fv0 ON fv0.item_id = f.id'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Rating / Operator EQ',
        Search       => {
            Field    => 'Rating',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'GroupBy' => [
                'f.id'
            ],
            'Having' => [
                'AVG(COALESCE(fv0.rate,-1)) = 1'
            ],
            'Join' => [
                'LEFT JOIN faq_voting fv0 ON fv0.item_id = f.id'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Rating / Operator NE',
        Search       => {
            Field    => 'Rating',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'GroupBy' => [
                'f.id'
            ],
            'Having' => [
                'AVG(COALESCE(fv0.rate,-1)) <> 1'
            ],
            'Join' => [
                'LEFT JOIN faq_voting fv0 ON fv0.item_id = f.id'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Rating / Operator LT',
        Search       => {
            Field    => 'Rating',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'GroupBy' => [
                'f.id'
            ],
            'Having' => [
                'AVG(COALESCE(fv0.rate,-1)) < 1'
            ],
            'Join' => [
                'LEFT JOIN faq_voting fv0 ON fv0.item_id = f.id'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Rating / Operator GT',
        Search       => {
            Field    => 'Rating',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'GroupBy' => [
                'f.id'
            ],
            'Having' => [
                'AVG(COALESCE(fv0.rate,-1)) > 1'
            ],
            'Join' => [
                'LEFT JOIN faq_voting fv0 ON fv0.item_id = f.id'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Rating / Operator LTE',
        Search       => {
            Field    => 'Rating',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'GroupBy' => [
                'f.id'
            ],
            'Having' => [
                'AVG(COALESCE(fv0.rate,-1)) <= 1'
            ],
            'Join' => [
                'LEFT JOIN faq_voting fv0 ON fv0.item_id = f.id'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Rating / Operator GTE',
        Search       => {
            Field    => 'Rating',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'GroupBy' => [
                'f.id'
            ],
            'Having' => [
                'AVG(COALESCE(fv0.rate,-1)) >= 1'
            ],
            'Join' => [
                'LEFT JOIN faq_voting fv0 ON fv0.item_id = f.id'
            ]
        }
    }
);
for my $Test ( @SearchTests ) {
    my $Result = $AttributeObject->Search(
        Search       => $Test->{Search},
        BoolOperator => 'AND',
        UserID       => 1,
        Silent       => defined( $Test->{Expected} ) ? 0 : 1
    );
    $Self->IsDeeply(
        $Result,
        $Test->{Expected},
        $Test->{Name}
    );
}

# check Sort
my @SortTests = (
    {
        Name      => 'Sort: Attribute undef',
        Attribute => undef,
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute invalid',
        Attribute => 'Test',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "Votes"',
        Attribute => 'Votes',
        Expected  => {
            'GroupBy' => [
                'f.id'
            ],
            'Join' => [
                'LEFT JOIN faq_voting fv0 ON fv0.item_id = f.id'
            ],
            'OrderBy' => [
                'votes'
            ],
            'Select' => [
                'COUNT(fv0.item_id) AS votes'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Rating"',
        Attribute => 'Rating',
        Expected  => {
            'GroupBy' => [
                'f.id'
            ],
            'Join' => [
                'LEFT JOIN faq_voting fv0 ON fv0.item_id = f.id'
            ],
            'OrderBy' => [
                'rates'
            ],
            'Select' => [
                'AVG(COALESCE(fv0.rate,-1)) AS rates'
            ]
        }
    }
);
for my $Test ( @SortTests ) {
    my $Result = $AttributeObject->Sort(
        Attribute => $Test->{Attribute},
        Language  => 'en',
        Silent    => defined( $Test->{Expected} ) ? 0 : 1
    );
    $Self->IsDeeply(
        $Result,
        $Test->{Expected},
        $Test->{Name}
    );
}

### Integration Test ###
# discard current object search object
$Kernel::OM->ObjectsDiscard(
    Objects => ['ObjectSearch'],
);

# make sure config 'ObjectSearch::Backend' is set to Module 'ObjectSearch::Database'
$Kernel::OM->Get('Config')->Set(
    Key   => 'ObjectSearch::Backend',
    Value => {
        Module => 'ObjectSearch::Database',
    }
);

# get objectsearch object
my $ObjectSearch = $Kernel::OM->Get('ObjectSearch');

# begin transaction on database
$Helper->BeginWork();

## prepare test faq articles ##
# first faq article
my $FAQArticleID1 = $Kernel::OM->Get('FAQ')->FAQAdd(
    Title       => $Helper->GetRandomID(),
    CategoryID  => 1,
    Visibility  => 'internal',
    Language    => 'en',
    ValidID     => 1,
    ContentType => 'text/plain',
    UserID      => 1,
);
$Self->True(
    $FAQArticleID1,
    'Created first faq article'
);
# second faq article
my $FAQArticleID2 = $Kernel::OM->Get('FAQ')->FAQAdd(
    Title       => $Helper->GetRandomID(),
    CategoryID  => 1,
    Visibility  => 'internal',
    Language    => 'en',
    ValidID     => 1,
    ContentType => 'text/plain',
    UserID      => 1,
);
$Self->True(
    $FAQArticleID1,
    'Created second faq article'
);
# third faq article
my $FAQArticleID3 = $Kernel::OM->Get('FAQ')->FAQAdd(
    Title       => $Helper->GetRandomID(),
    CategoryID  => 1,
    Visibility  => 'internal',
    Language    => 'en',
    ValidID     => 1,
    ContentType => 'text/plain',
    UserID      => 1,
);
$Self->True(
    $FAQArticleID1,
    'Created third faq article'
);

## prepare votes and rating ##
my @Votes = (
    {
        CreatedBy => $Helper->GetRandomID(),
        ItemID    => $FAQArticleID1,
        Rate      => 1
    },
    {
        CreatedBy => $Helper->GetRandomID(),
        ItemID    => $FAQArticleID1,
        Rate      => 4
    },
    {
        CreatedBy => $Helper->GetRandomID(),
        ItemID    => $FAQArticleID1,
        Rate      => 2
    },
    {
        CreatedBy => $Helper->GetRandomID(),
        ItemID    => $FAQArticleID1,
        Rate      => 5
    },
    {
        CreatedBy => $Helper->GetRandomID(),
        ItemID    => $FAQArticleID2,
        Rate      => 3
    },
    {
        CreatedBy => $Helper->GetRandomID(),
        ItemID    => $FAQArticleID2,
        Rate      => 2
    },
    {
        CreatedBy => $Helper->GetRandomID(),
        ItemID    => $FAQArticleID3,
        Rate      => 4
    }
);

# avg ratring and counted votes for testing
my $Rating1 = 3;
my $Vote1   = 4;
my $Rating2 = 3;
my $Vote2   = 2;
my $Rating3 = 4;
my $Vote3   = 1;

for my $Data ( @Votes ) {
    my $VoteID = $Kernel::OM->Get('FAQ')->VoteAdd(
        %{$Data},
        UserID    => 1,
    );

    $Self->True(
        $VoteID,
        "Created vote for FAQArticle $Data->{ItemID} with rate $Data->{Rate}"
    );

    $Kernel::OM->ObjectsDiscard(
        Objects => ['FAQ'],
    );
}

# test Search
my @IntegrationSearchTests = (
    {
        Name     => "Search: Field Votes / Operator EQ / Value \$Vote1",
        Search   => {
            'AND' => [
                {
                    Field    => 'Votes',
                    Operator => 'EQ',
                    Value    => $Vote1
                }
            ]
        },
        Expected => [$FAQArticleID1]
    },
    {
        Name     => "Search: Field Votes / Operator NE / Value \$Vote1",
        Search   => {
            'AND' => [
                {
                    Field    => 'Votes',
                    Operator => 'NE',
                    Value    => $Vote1
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Votes / Operator LT / Value \$Vote2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Votes',
                    Operator => 'LT',
                    Value    => $Vote2
                }
            ]
        },
        Expected => [$FAQArticleID3]
    },
    {
        Name     => "Search: Field Votes / Operator LTE / Value \$Vote2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Votes',
                    Operator => 'LTE',
                    Value    => $Vote2
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Votes / Operator GT / Value \$Vote3",
        Search   => {
            'AND' => [
                {
                    Field    => 'Votes',
                    Operator => 'GT',
                    Value    => $Vote3
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID2]
    },
    {
        Name     => "Search: Field Votes / Operator GTE / Value \$Vote3",
        Search   => {
            'AND' => [
                {
                    Field    => 'Votes',
                    Operator => 'GTE',
                    Value    => $Vote3
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Rating / Operator EQ / Value \$Rating1",
        Search   => {
            'AND' => [
                {
                    Field    => 'Rating',
                    Operator => 'EQ',
                    Value    => $Rating1
                }
            ]
        },
        Expected => [$FAQArticleID1]
    },
    {
        Name     => "Search: Field Rating / Operator NE / Value \$Rating1",
        Search   => {
            'AND' => [
                {
                    Field    => 'Rating',
                    Operator => 'NE',
                    Value    => $Rating1
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Rating / Operator LT / Value \$Rating2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Rating',
                    Operator => 'LT',
                    Value    => $Rating2
                }
            ]
        },
        Expected => [$FAQArticleID2]
    },
    {
        Name     => "Search: Field Rating / Operator LTE / Value \$Rating2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Rating',
                    Operator => 'LTE',
                    Value    => $Rating2
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID2]
    },
    {
        Name     => "Search: Field Rating / Operator GT / Value \$Rating3",
        Search   => {
            'AND' => [
                {
                    Field    => 'Rating',
                    Operator => 'GT',
                    Value    => $Rating3
                }
            ]
        },
        Expected => []
    },
    {
        Name     => "Search: Field Rating / Operator GTE / Value \$Rating3",
        Search   => {
            'AND' => [
                {
                    Field    => 'Rating',
                    Operator => 'GTE',
                    Value    => $Rating3
                }
            ]
        },
        Expected => [$FAQArticleID3]
    }
);

for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'FAQArticle',
        Result     => 'ARRAY',
        Search     => $Test->{Search},
        UserType   => 'Agent',
        UserID     => 1
    );
    $Self->IsDeeply(
        \@Result,
        $Test->{Expected},
        $Test->{Name}
    );
}

# test Sort
my @IntegrationSortTests = (
    {
        Name     => 'Sort: Field Votes',
        Sort     => [
            {
                Field => 'Votes'
            }
        ],
        Language => 'en',
        Expected => [$FAQArticleID3, $FAQArticleID2, $FAQArticleID1]
    },
    {
        Name     => 'Sort: Field Votes / Direction ascending',
        Sort     => [
            {
                Field     => 'Votes',
                Direction => 'ascending'
            }
        ],
        Language => 'en',
        Expected => [$FAQArticleID3, $FAQArticleID2, $FAQArticleID1]
    },
    {
        Name     => 'Sort: Field Votes / Direction descending',
        Sort     => [
            {
                Field     => 'Votes',
                Direction => 'descending'
            }
        ],
        Language => 'en',
        Expected => [$FAQArticleID1, $FAQArticleID2, $FAQArticleID3]
    },
    {
        Name     => 'Sort: Field Rating',
        Sort     => [
            {
                Field => 'Rating'
            }
        ],
        Language => 'en',
        Expected => [$FAQArticleID2, $FAQArticleID1, $FAQArticleID3]
    },
    {
        Name     => 'Sort: Field Rating / Direction ascending',
        Sort     => [
            {
                Field     => 'Rating',
                Direction => 'ascending'
            }
        ],
        Language => 'en',
        Expected => [$FAQArticleID2, $FAQArticleID1, $FAQArticleID3]
    },
    {
        Name     => 'Sort: Field Rating / Direction descending',
        Sort     => [
            {
                Field     => 'Rating',
                Direction => 'descending'
            }
        ],
        Language => 'en',
        Expected => [$FAQArticleID3, $FAQArticleID1, $FAQArticleID2]
    },
    {
        Name     => 'Sort: Field Votes + Rating',
        Sort     => [
            {
                Field => 'Votes'
            },
            {
                Field => 'Rating'
            }
        ],
        Language => 'en',
        Expected => [$FAQArticleID3, $FAQArticleID2, $FAQArticleID1]
    },
    {
        Name     => 'Sort: Field Votes + Rating / Direction ascending',
        Sort     => [
            {
                Field     => 'Votes',
                Direction => 'ascending'
            },
            {
                Field     => 'Rating',
                Direction => 'ascending'
            }
        ],
        Language => 'en',
        Expected => [$FAQArticleID3, $FAQArticleID2, $FAQArticleID1]
    },
    {
        Name     => 'Sort: Field Votes + Rating / Direction descending',
        Sort     => [
            {
                Field     => 'Votes',
                Direction => 'descending'
            },
            {
                Field     => 'Rating',
                Direction => 'descending'
            }
        ],
        Language => 'en',
        Expected => [$FAQArticleID1, $FAQArticleID2, $FAQArticleID3]
    },
    {
        Name     => 'Sort: Field Votes + Rating / Direction ascending + descending',
        Sort     => [
            {
                Field     => 'Votes',
                Direction => 'ascending'
            },
            {
                Field     => 'Rating',
                Direction => 'descending'
            }
        ],
        Language => 'en',
        Expected => [$FAQArticleID3, $FAQArticleID2, $FAQArticleID1]
    },
    {
        Name     => 'Sort: Field Votes + Rating / Direction descending + ascending',
        Sort     => [
            {
                Field     => 'Votes',
                Direction => 'descending'
            },
            {
                Field     => 'Rating',
                Direction => 'ascending'
            }
        ],
        Language => 'en',
        Expected => [$FAQArticleID1, $FAQArticleID2, $FAQArticleID3]
    },
    {
        Name     => 'Sort: Field Rating + Votes',
        Sort     => [
            {
                Field => 'Rating'
            },
            {
                Field => 'Votes'
            }
        ],
        Language => 'en',
        Expected => [$FAQArticleID2, $FAQArticleID1, $FAQArticleID3]
    },
    {
        Name     => 'Sort: Field Rating + Votes / Direction ascending',
        Sort     => [
            {
                Field     => 'Rating',
                Direction => 'ascending'
            },
            {
                Field     => 'Votes',
                Direction => 'ascending'
            }
        ],
        Language => 'en',
        Expected => [$FAQArticleID2, $FAQArticleID1, $FAQArticleID3]
    },
    {
        Name     => 'Sort: Field Rating + Votes / Direction descending',
        Sort     => [
            {
                Field     => 'Rating',
                Direction => 'descending'
            },
            {
                Field     => 'Votes',
                Direction => 'descending'
            }
        ],
        Language => 'en',
        Expected => [$FAQArticleID3, $FAQArticleID1, $FAQArticleID2]
    },
    {
        Name     => 'Sort: Field Rating + Votes / Direction ascending + descending',
        Sort     => [
            {
                Field     => 'Rating',
                Direction => 'ascending'
            },
            {
                Field     => 'Votes',
                Direction => 'descending'
            }
        ],
        Language => 'en',
        Expected => [$FAQArticleID2, $FAQArticleID1, $FAQArticleID3]
    },
    {
        Name     => 'Sort: Field Rating + Votes / Direction descending + ascending',
        Sort     => [
            {
                Field     => 'Rating',
                Direction => 'descending'
            },
            {
                Field     => 'Votes',
                Direction => 'ascending'
            }
        ],
        Language => 'en',
        Expected => [$FAQArticleID3, $FAQArticleID1, $FAQArticleID2]
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'FAQArticle',
        Result     => 'ARRAY',
        Sort       => $Test->{Sort},
        Language   => $Test->{Language},
        UserType   => 'Agent',
        UserID     => 1,
    );
    $Self->IsDeeply(
        \@Result,
        $Test->{Expected},
        $Test->{Name}
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
