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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::FAQArticle::Category';

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
        Category => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        CategoryID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN'],
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
            Field    => 'CategoryID',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'CategoryID',
            Operator => 'EQ',
            Value    => 'Test'
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
            Field    => 'CategoryID',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'CategoryID',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field CategoryID / Operator EQ',
        Search       => {
            Field    => 'CategoryID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'f.category_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CategoryID / Operator NE',
        Search       => {
            Field    => 'CategoryID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'f.category_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CategoryID / Operator IN',
        Search       => {
            Field    => 'CategoryID',
            Operator => 'IN',
            Value    => ['1']
        },
        BoolOperator => 'AND',
        Expected     => {
            'Join'  => [],
            'Where' => [
                'f.category_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CategoryID / Operator !IN',
        Search       => {
            Field    => 'CategoryID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'f.category_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Category / Operator EQ',
        Search       => {
            Field    => 'Category',
            Operator => 'EQ',
            Value    => 'Misc'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN faq_category fc0 ON fc0.id = f.category_id'
            ],
            'Where' => [
                'fc0.name = \'Misc\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Category / Operator NE',
        Search       => {
            Field    => 'Category',
            Operator => 'NE',
            Value    => 'Misc'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN faq_category fc0 ON fc0.id = f.category_id'
            ],
            'Where' => [
                'fc0.name != \'Misc\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Category / Operator IN',
        Search       => {
            Field    => 'Category',
            Operator => 'IN',
            Value    => ['Misc']
        },
        BoolOperator => 'AND',
        Expected     => {
            'Join' => [
                'INNER JOIN faq_category fc0 ON fc0.id = f.category_id'
            ],
            'Where' => [
                'fc0.name IN (\'Misc\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Category / Operator !IN',
        Search       => {
            Field    => 'Category',
            Operator => '!IN',
            Value    => ['Misc']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN faq_category fc0 ON fc0.id = f.category_id'
            ],
            'Where' => [
                'fc0.name NOT IN (\'Misc\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Category / Operator STARTSWITH',
        Search       => {
            Field    => 'Category',
            Operator => 'STARTSWITH',
            Value    => 'Misc'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN faq_category fc0 ON fc0.id = f.category_id'
            ],
            'Where' => [
                'fc0.name LIKE \'Misc%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Category / Operator ENDSWITH',
        Search       => {
            Field    => 'Category',
            Operator => 'ENDSWITH',
            Value    => 'Misc'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN faq_category fc0 ON fc0.id = f.category_id'
            ],
            'Where' => [
                'fc0.name LIKE \'%Misc\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Category / Operator CONTAINS',
        Search       => {
            Field    => 'Category',
            Operator => 'CONTAINS',
            Value    => 'Misc'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN faq_category fc0 ON fc0.id = f.category_id'
            ],
            'Where' => [
                'fc0.name LIKE \'%Misc%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Category / Operator LIKE',
        Search       => {
            Field    => 'Category',
            Operator => 'LIKE',
            Value    => 'Misc'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN faq_category fc0 ON fc0.id = f.category_id'
            ],
            'Where' => [
                'fc0.name LIKE \'Misc\''
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
        Name      => 'Sort: Attribute "CategoryID"',
        Attribute => 'CategoryID',
        Expected  => {
            'Join' => [],
            'OrderBy' => [
                'f.category_id'
            ],
            'Select' => [
                'f.category_id'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Category"',
        Attribute => 'Category',
        Expected  => {
            'Join' => [
                'INNER JOIN faq_category fc0 ON fc0.id = f.category_id'
            ],
            'OrderBy' => [
                'fc0.name'
            ],
            'Select' => [
                'fc0.name'
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

## prepare faq categories ##
my $Number      = $Helper->GetRandomID();
my $Category1   = "Test-$Number-001";
my $CategoryID1 = $Kernel::OM->Get('FAQ')->CategoryAdd(
    Name     => $Category1,
    Comment  => 'UnitTest FAQ Category',
    ParentID => 0,
    ValidID  => 1,
    UserID   => 1,
);
$Self->True(
    $CategoryID1,
    'Created first faq category'
);
my $Category2   = "test-$Number-002";
my $CategoryID2 = $Kernel::OM->Get('FAQ')->CategoryAdd(
    Name     => $Category2,
    Comment  => 'UnitTest FAQ Category',
    ParentID => $CategoryID1,
    ValidID  => 1,
    UserID   => 1,
);
$Self->True(
    $CategoryID2,
    'Created second faq category'
);
my $Category3   = "Test-$Number-003";
my $CategoryID3 = $Kernel::OM->Get('FAQ')->CategoryAdd(
    Name     => $Category3,
    Comment  => 'UnitTest FAQ Category',
    ParentID => 0,
    ValidID  => 1,
    UserID   => 1,
);
$Self->True(
    $CategoryID3,
    'Created third faq category'
);

## prepare test faq articles ##
# first faq article
my $FAQArticleID1 = $Kernel::OM->Get('FAQ')->FAQAdd(
    Title       => $Helper->GetRandomID(),
    CategoryID  => $CategoryID1,
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
    CategoryID  => $CategoryID2,
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
    CategoryID  => $CategoryID3,
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

# test Search
my @IntegrationSearchTests = (
    {
        Name     => "Search: Field CategoryID / Operator EQ / Value \$CategoryID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'CategoryID',
                    Operator => 'EQ',
                    Value    => $CategoryID2
                }
            ]
        },
        Expected => [$FAQArticleID2]
    },
    {
        Name     => "Search: Field CategoryID / Operator NE / Value \$CategoryID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'CategoryID',
                    Operator => 'NE',
                    Value    => $CategoryID2
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID3]
    },
    {
        Name     => "Search: Field CategoryID / Operator IN / Value [\$CategoryID1,\$CategoryID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'CategoryID',
                    Operator => 'IN',
                    Value    => [$CategoryID1,$CategoryID3]
                }
            ]
        },
        Expected => [$FAQArticleID1, $FAQArticleID3]
    },
    {
        Name     => "Search: Field CategoryID / Operator !IN / Value [\$CategoryID1,\$CategoryID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'CategoryID',
                    Operator => '!IN',
                    Value    => [$CategoryID1,$CategoryID3]
                }
            ]
        },
        Expected => [$FAQArticleID2]
    },
    {
        Name     => "Search: Field Category / Operator EQ / Value \$Category2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Category',
                    Operator => 'EQ',
                    Value    => $Category2
                }
            ]
        },
        Expected => [$FAQArticleID2]
    },
    {
        Name     => "Search: Field Category / Operator NE / Value \$Category2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Category',
                    Operator => 'NE',
                    Value    => $Category2
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Category / Operator IN / Value [\$Category1,\$Category3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Category',
                    Operator => 'IN',
                    Value    => [$Category1,$Category3]
                }
            ]
        },
        Expected => [$FAQArticleID1, $FAQArticleID3]
    },
    {
        Name     => "Search: Field Category / Operator !IN / Value [\$Category1,\$Category3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Category',
                    Operator => '!IN',
                    Value    => [$Category1,$Category3]
                }
            ]
        },
        Expected => [$FAQArticleID2]
    },
    {
        Name     => "Search: Field Category / Operator STARTSWITH / Value \$Category2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Category',
                    Operator => 'STARTSWITH',
                    Value    => $Category2
                }
            ]
        },
        Expected => [$FAQArticleID2]
    },
    {
        Name     => "Search: Field Category / Operator STARTSWITH / Value substr(\$Category1,0,4)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Category',
                    Operator => 'STARTSWITH',
                    Value    => substr($Category1,0,4)
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Category / Operator ENDSWITH / Value \$Category2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Category',
                    Operator => 'ENDSWITH',
                    Value    => $Category2
                }
            ]
        },
        Expected => [$FAQArticleID2]
    },
    {
        Name     => "Search: Field Category / Operator ENDSWITH / Value substr(\$Category2,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Category',
                    Operator => 'ENDSWITH',
                    Value    => substr($Category2,-5)
                }
            ]
        },
        Expected => [$FAQArticleID2]
    },
    {
        Name     => "Search: Field Category / Operator CONTAINS / Value \$Category3",
        Search   => {
            'AND' => [
                {
                    Field    => 'Category',
                    Operator => 'CONTAINS',
                    Value    => $Category3
                }
            ]
        },
        Expected => [$FAQArticleID3]
    },
    {
        Name     => "Search: Field Category / Operator CONTAINS / Value substr(\$Category3,2,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Category',
                    Operator => 'CONTAINS',
                    Value    => substr($Category3,2,-2)
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Category / Operator LIKE / Value \$Category1",
        Search   => {
            'AND' => [
                {
                    Field    => 'Category',
                    Operator => 'LIKE',
                    Value    => "$Category1"
                }
            ]
        },
        Expected => [$FAQArticleID1]
    },
    {
        Name     => "Search: Field Category / Operator LIKE / Value \$Category2,0,2)*",
        Search   => {
            'AND' => [
                {
                    Field    => 'Category',
                    Operator => 'LIKE',
                    Value    => substr($Category2,0,2) . q{*}
                }
            ]
        },
        Expected => [$FAQArticleID2]
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
        Name     => 'Sort: Field CategoryID',
        Sort     => [
            {
                Field => 'CategoryID'
            }
        ],
        Language => 'en',
        Expected => [$FAQArticleID1, $FAQArticleID2, $FAQArticleID3]
    },
    {
        Name     => 'Sort: Field CategoryID / Direction ascending',
        Sort     => [
            {
                Field     => 'CategoryID',
                Direction => 'ascending'
            }
        ],
        Language => 'en',
        Expected => [$FAQArticleID1, $FAQArticleID2, $FAQArticleID3]
    },
    {
        Name     => 'Sort: Field CategoryID / Direction descending',
        Sort     => [
            {
                Field     => 'CategoryID',
                Direction => 'descending'
            }
        ],
        Language => 'en',
        Expected => [$FAQArticleID3, $FAQArticleID2, $FAQArticleID1]
    },
    {
        Name     => 'Sort: Field Category',
        Sort     => [
            {
                Field => 'Category'
            }
        ],
        Language => 'en',
        Expected => [$FAQArticleID1, $FAQArticleID3, $FAQArticleID2]
    },
    {
        Name     => 'Sort: Field Category / Direction ascending',
        Sort     => [
            {
                Field     => 'Category',
                Direction => 'ascending'
            }
        ],
        Language => 'en',
        Expected => [$FAQArticleID1, $FAQArticleID3, $FAQArticleID2]
    },
    {
        Name     => 'Sort: Field Category / Direction descending',
        Sort     => [
            {
                Field     => 'Category',
                Direction => 'descending'
            }
        ],
        Language => 'en',
        Expected => [$FAQArticleID2, $FAQArticleID3, $FAQArticleID1]
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
