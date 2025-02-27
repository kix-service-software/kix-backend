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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::FAQArticle::FAQArticleID';

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
        FAQArticleID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN'],
            ValueType    => 'NUMERIC'
        },
        ID => {
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
            Field    => 'FAQArticleID',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'FAQArticleID',
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
            Field    => 'FAQArticleID',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'FAQArticleID',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field FAQArticleID / Operator EQ',
        Search       => {
            Field    => 'FAQArticleID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'f.id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field FAQArticleID / Operator NE',
        Search       => {
            Field    => 'FAQArticleID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'f.id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field FAQArticleID / Operator IN',
        Search       => {
            Field    => 'FAQArticleID',
            Operator => 'IN',
            Value    => ['1']
        },
        BoolOperator => 'AND',
        Expected     => {
            'Where' => [
                'f.id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field FAQArticleID / Operator !IN',
        Search       => {
            Field    => 'FAQArticleID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'f.id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ID / Operator EQ',
        Search       => {
            Field    => 'ID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'f.id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ID / Operator NE',
        Search       => {
            Field    => 'ID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'f.id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ID / Operator IN',
        Search       => {
            Field    => 'ID',
            Operator => 'IN',
            Value    => ['1']
        },
        BoolOperator => 'AND',
        Expected     => {
            'Where' => [
                'f.id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ID / Operator !IN',
        Search       => {
            Field    => 'ID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'f.id NOT IN (1)'
            ]
        }
    },
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
        Name      => 'Sort: Attribute "FAQArticleID"',
        Attribute => 'FAQArticleID',
        Expected  => {
            'OrderBy' => [
                'f.id'
            ],
            'Select'  => [
                'f.id'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "ID"',
        Attribute => 'ID',
        Expected  => {
            'OrderBy' => [
                'f.id'
            ],
            'Select'  => [
                'f.id'
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
    Visibility  => 'public',
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
    Visibility  => 'external',
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
        Name     => "Search: Field FAQArticleID / Operator EQ / Value \$FAQArticleID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'FAQArticleID',
                    Operator => 'EQ',
                    Value    => $FAQArticleID2
                }
            ]
        },
        Expected => [$FAQArticleID2]
    },
    {
        Name     => "Search: Field FAQArticleID / Operator NE / Value \$FAQArticleID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'FAQArticleID',
                    Operator => 'NE',
                    Value    => $FAQArticleID2
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID3]
    },
    {
        Name     => "Search: Field FAQArticleID / Operator IN / Value [\$FAQArticleID1,\$FAQArticleID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'FAQArticleID',
                    Operator => 'IN',
                    Value    => [$FAQArticleID1,$FAQArticleID3]
                }
            ]
        },
        Expected => [$FAQArticleID1, $FAQArticleID3]
    },
    {
        Name     => "Search: Field FAQArticleID / Operator !IN / Value [\$FAQArticleID1,\$FAQArticleID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'FAQArticleID',
                    Operator => '!IN',
                    Value    => [$FAQArticleID1,$FAQArticleID3]
                }
            ]
        },
        Expected => [$FAQArticleID2]
    },
    {
        Name     => "Search: Field ID / Operator EQ / Value \$FAQArticleID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'EQ',
                    Value    => $FAQArticleID2
                }
            ]
        },
        Expected => [$FAQArticleID2]
    },
    {
        Name     => "Search: Field ID / Operator NE / Value \$FAQArticleID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'NE',
                    Value    => $FAQArticleID2
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID3]
    },
    {
        Name     => "Search: Field ID / Operator IN / Value [\$FAQArticleID1,\$FAQArticleID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'IN',
                    Value    => [$FAQArticleID1,$FAQArticleID3]
                }
            ]
        },
        Expected => [$FAQArticleID1, $FAQArticleID3]
    },
    {
        Name     => "Search: Field ID / Operator !IN / Value [\$FAQArticleID1,\$FAQArticleID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => '!IN',
                    Value    => [$FAQArticleID1,$FAQArticleID3]
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
        UserID     => 1,
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
        Name     => 'Sort: Field FAQArticleID',
        Sort     => [
            {
                Field => 'FAQArticleID'
            }
        ],
        Expected => [$FAQArticleID1, $FAQArticleID2, $FAQArticleID3]
    },
    {
        Name     => 'Sort: Field FAQArticleID / Direction ascending',
        Sort     => [
            {
                Field     => 'FAQArticleID',
                Direction => 'ascending'
            }
        ],
        Expected => [$FAQArticleID1, $FAQArticleID2, $FAQArticleID3]
    },
    {
        Name     => 'Sort: Field FAQArticleID / Direction descending',
        Sort     => [
            {
                Field     => 'FAQArticleID',
                Direction => 'descending'
            }
        ],
        Expected => [$FAQArticleID3, $FAQArticleID2, $FAQArticleID1]
    },
    {
        Name     => 'Sort: Field ID',
        Sort     => [
            {
                Field => 'ID'
            }
        ],
        Expected => [$FAQArticleID1, $FAQArticleID2, $FAQArticleID3]
    },
    {
        Name     => 'Sort: Field ID / Direction ascending',
        Sort     => [
            {
                Field     => 'ID',
                Direction => 'ascending'
            }
        ],
        Expected => [$FAQArticleID1, $FAQArticleID2, $FAQArticleID3]
    },
    {
        Name     => 'Sort: Field ID / Direction descending',
        Sort     => [
            {
                Field     => 'ID',
                Direction => 'descending'
            }
        ],
        Expected => [$FAQArticleID3, $FAQArticleID2, $FAQArticleID1]
    },
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'FAQArticle',
        Result     => 'ARRAY',
        Language   => 'en',
        Sort       => $Test->{Sort},
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
