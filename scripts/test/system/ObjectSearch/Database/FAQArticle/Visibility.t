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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::FAQArticle::Visibility';

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
        CustomerVisible => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE'],
            ValueType    => 'NUMERIC'
        },
        Visibility => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
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
            Field    => 'Visibility',
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
            Value    => 'internal'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Field invalid',
        Search       => {
            Field    => 'Test',
            Operator => 'EQ',
            Value    => 'internal'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator undef',
        Search       => {
            Field    => 'Visibility',
            Operator => undef,
            Value    => 'internal'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'Visibility',
            Operator => 'Test',
            Value    => 'internal'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field Visibility / Operator EQ',
        Search       => {
            Field    => 'Visibility',
            Operator => 'EQ',
            Value    => 'internal'
        },
        Expected     => {
            'Where' => [
                'f.visibility = \'internal\''
            ]

        }
    },
    {
        Name         => 'Search: valid search / Field Visibility / Operator NE',
        Search       => {
            Field    => 'Visibility',
            Operator => 'NE',
            Value    => 'internal'
        },
        Expected     => {
            'Where' => [
                'f.visibility != \'internal\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Visibility / Operator IN',
        Search       => {
            Field    => 'Visibility',
            Operator => 'IN',
            Value    => ['internal']
        },
        BoolOperator => 'AND',
        Expected     => {
            'Where' => [
                'f.visibility IN (\'internal\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Visibility / Operator !IN',
        Search       => {
            Field    => 'Visibility',
            Operator => '!IN',
            Value    => ['internal']
        },
        Expected     => {
            'Where' => [
                'f.visibility NOT IN (\'internal\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Visibility / Operator STARTSWITH',
        Search       => {
            Field    => 'Visibility',
            Operator => 'STARTSWITH',
            Value    => 'internal'
        },
        Expected     => {
            'Where' => [
                'f.visibility LIKE \'internal%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Visibility / Operator ENDSWITH',
        Search       => {
            Field    => 'Visibility',
            Operator => 'ENDSWITH',
            Value    => 'internal'
        },
        Expected     => {
            'Where' => [
                'f.visibility LIKE \'%internal\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Visibility / Operator CONTAINS',
        Search       => {
            Field    => 'Visibility',
            Operator => 'CONTAINS',
            Value    => 'internal'
        },
        Expected     => {
            'Where' => [
                'f.visibility LIKE \'%internal%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Visibility / Operator LIKE',
        Search       => {
            Field    => 'Visibility',
            Operator => 'LIKE',
            Value    => 'internal'
        },
        Expected     => {
            'Where' => [
                'f.visibility LIKE \'internal\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CustomerVisible / Operator EQ',
        Search       => {
            Field    => 'CustomerVisible',
            Operator => 'EQ',
            Value    => '0'
        },
        Expected     => {
            'Search' => {
                'AND' => [
                    {
                        'Field' => 'Visibility',
                        'Operator' => 'IN',
                        'Value' => [
                            'internal'
                        ]
                    }
                ]
            }
        }
    },
    {
        Name         => 'Search: valid search / Field CustomerVisible / Operator EQ',
        Search       => {
            Field    => 'CustomerVisible',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Search' => {
                'AND' => [
                    {
                        'Field' => 'Visibility',
                        'Operator' => 'IN',
                        'Value' => [
                            'external',
                            'public'
                        ]
                    }
                ]
            }
        }
    },
    {
        Name         => 'Search: valid search / Field CustomerVisible / Operator NE',
        Search       => {
            Field    => 'CustomerVisible',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Search' => {
                'AND' => [
                    {
                        'Field' => 'Visibility',
                        'Operator' => '!IN',
                        'Value' => [
                            'external',
                            'public'
                        ]
                    }
                ]
            }
        }
    },
    {
        Name         => 'Search: valid search / Field CustomerVisible / Operator NE',
        Search       => {
            Field    => 'CustomerVisible',
            Operator => 'NE',
            Value    => '0'
        },
        Expected     => {
            'Search' => {
                'AND' => [
                    {
                        'Field' => 'Visibility',
                        'Operator' => '!IN',
                        'Value' => [
                            'internal'
                        ]
                    }
                ]
            }
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
        Name      => 'Sort: Attribute "CustomerVisible"',
        Attribute => 'CustomerVisible',
        Expected  => {
            'OrderBy' => [
                <<'EOF'
CASE
    WHEN f.visibility = 'internal'
        OR f.visibility IS NULL
    THEN 0
    ELSE 1
END
EOF
            ],
            'Select' => [
                'f.visibility'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Visibility"',
        Attribute => 'Visibility',
        Expected  => {
            'OrderBy' => [
                'f.visibility'
            ],
            'Select' => [
                'f.visibility'
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
    Visibility  => 'external',
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
    Visibility  => 'public',
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
        Name     => "Search: Field CustomerVisible / Operator EQ / Value 1",
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => 'EQ',
                    Value    => '1'
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID3]
    },
    {
        Name     => "Search: Field CustomerVisible / Operator NE / Value 1",
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => 'NE',
                    Value    => '1'
                }
            ]
        },
        Expected => [$FAQArticleID2]
    },
    {
        Name     => "Search: Field Visibility / Operator EQ / Value internal",
        Search   => {
            'AND' => [
                {
                    Field    => 'Visibility',
                    Operator => 'EQ',
                    Value    => 'internal'
                }
            ]
        },
        Expected => [$FAQArticleID2]
    },
    {
        Name     => "Search: Field Visibility / Operator NE / Value internal",
        Search   => {
            'AND' => [
                {
                    Field    => 'Visibility',
                    Operator => 'NE',
                    Value    => 'internal'
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Visibility / Operator IN / Value ['internal','external']",
        Search   => {
            'AND' => [
                {
                    Field    => 'Visibility',
                    Operator => 'IN',
                    Value    => ['internal','external']
                }
            ]
        },
        Expected => [$FAQArticleID1, $FAQArticleID2]
    },
    {
        Name     => "Search: Field Visibility / Operator !IN / Value ['internal','external']",
        Search   => {
            'AND' => [
                {
                    Field    => 'Visibility',
                    Operator => '!IN',
                    Value    => ['internal','external']
                }
            ]
        },
        Expected => [$FAQArticleID3]
    },
    {
        Name     => "Search: Field Visibility / Operator STARTSWITH / Value 'internal'",
        Search   => {
            'AND' => [
                {
                    Field    => 'Visibility',
                    Operator => 'STARTSWITH',
                    Value    => 'internal'
                }
            ]
        },
        Expected => [$FAQArticleID2]
    },
    {
        Name     => "Search: Field Visibility / Operator STARTSWITH / Value substr('internal',0,4)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Visibility',
                    Operator => 'STARTSWITH',
                    Value    => substr('internal',0,4)
                }
            ]
        },
        Expected => [$FAQArticleID2]
    },
    {
        Name     => "Search: Field Visibility / Operator ENDSWITH / Value 'internal'",
        Search   => {
            'AND' => [
                {
                    Field    => 'Visibility',
                    Operator => 'ENDSWITH',
                    Value    => 'internal'
                }
            ]
        },
        Expected => [$FAQArticleID2]
    },
    {
        Name     => "Search: Field Visibility / Operator ENDSWITH / Value substr('internal',-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Visibility',
                    Operator => 'ENDSWITH',
                    Value    => substr('internal',-5)
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID2]
    },
    {
        Name     => "Search: Field Visibility / Operator CONTAINS / Value 'internal'",
        Search   => {
            'AND' => [
                {
                    Field    => 'Visibility',
                    Operator => 'CONTAINS',
                    Value    => 'internal'
                }
            ]
        },
        Expected => [$FAQArticleID2]
    },
    {
        Name     => "Search: Field Visibility / Operator CONTAINS / Value substr('internal,2,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Visibility',
                    Operator => 'CONTAINS',
                    Value    => substr('internal',2,-2)
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID2]
    },
    {
        Name     => "Search: Field Category / Operator LIKE / Value 'internal'",
        Search   => {
            'AND' => [
                {
                    Field    => 'Visibility',
                    Operator => 'LIKE',
                    Value    => 'internal'
                }
            ]
        },
        Expected => [$FAQArticleID2]
    },
    {
        Name     => "Search: Field Visibility / Operator LIKE / Value 'internal',0,2)*",
        Search   => {
            'AND' => [
                {
                    Field    => 'Visibility',
                    Operator => 'LIKE',
                    Value    => substr('internal',0,2) . q{*}
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
        Name     => 'Sort: Field Visibility',
        Sort     => [
            {
                Field => 'Visibility'
            }
        ],
        Language => 'en',
        Expected => [$FAQArticleID1, $FAQArticleID2, $FAQArticleID3]
    },
    {
        Name     => 'Sort: Field Visibility / Direction ascending',
        Sort     => [
            {
                Field     => 'Visibility',
                Direction => 'ascending'
            }
        ],
        Language => 'en',
        Expected => [$FAQArticleID1, $FAQArticleID2, $FAQArticleID3]
    },
    {
        Name     => 'Sort: Field Visibility / Direction descending',
        Sort     => [
            {
                Field     => 'Visibility',
                Direction => 'descending'
            }
        ],
        Language => 'en',
        Expected => [$FAQArticleID3, $FAQArticleID2, $FAQArticleID1]
    },
    {
        Name     => 'Sort: Field CustomerVisible',
        Sort     => [
            {
                Field => 'CustomerVisible'
            }
        ],
        Language => 'en',
        Expected => [$FAQArticleID2, $FAQArticleID1, $FAQArticleID3]
    },
    {
        Name     => 'Sort: Field CustomerVisible / Direction ascending',
        Sort     => [
            {
                Field     => 'CustomerVisible',
                Direction => 'ascending'
            }
        ],
        Language => 'en',
        Expected => [$FAQArticleID2, $FAQArticleID1, $FAQArticleID3]
    },
    {
        Name     => 'Sort: Field CustomerVisible / Direction descending',
        Sort     => [
            {
                Field     => 'CustomerVisible',
                Direction => 'descending'
            }
        ],
        Language => 'en',
        Expected => [$FAQArticleID1, $FAQArticleID3, $FAQArticleID2]
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
