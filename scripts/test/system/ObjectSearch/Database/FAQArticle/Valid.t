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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::FAQArticle::Valid';

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
        Valid => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN']
        },
        ValidID => {
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
            Field    => 'ValidID',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'ValidID',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field ValidID / Operator EQ',
        Search       => {
            Field    => 'ValidID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'f.valid_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ValidID / Operator NE',
        Search       => {
            Field    => 'ValidID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'f.valid_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ValidID / Operator IN',
        Search       => {
            Field    => 'ValidID',
            Operator => 'IN',
            Value    => ['1']
        },
        BoolOperator => 'AND',
        Expected     => {
            'Join'  => [],
            'Where' => [
                'f.valid_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ValidID / Operator !IN',
        Search       => {
            Field    => 'ValidID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'f.valid_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Valid / Operator EQ',
        Search       => {
            Field    => 'Valid',
            Operator => 'EQ',
            Value    => 'valid'
        },
        Expected     => {
            'Join'  => [
                'INNER JOIN valid v0 ON f.valid_id = v0.id'
            ],
            'Where' => [
                'v0.name = \'valid\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Valid / Operator NE',
        Search       => {
            Field    => 'Valid',
            Operator => 'NE',
            Value    => 'valid'
        },
        Expected     => {
            'Join'  => [
                'INNER JOIN valid v0 ON f.valid_id = v0.id'
            ],
            'Where' => [
                'v0.name != \'valid\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Valid / Operator IN',
        Search       => {
            Field    => 'Valid',
            Operator => 'IN',
            Value    => ['valid']
        },
        BoolOperator => 'AND',
        Expected     => {
            'Join'  => [
                'INNER JOIN valid v0 ON f.valid_id = v0.id'
            ],
            'Where' => [
                'v0.name IN (\'valid\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ID / Operator !IN',
        Search       => {
            Field    => 'Valid',
            Operator => '!IN',
            Value    => ['valid']
        },
        Expected     => {
            'Join'  => [
                'INNER JOIN valid v0 ON f.valid_id = v0.id'
            ],
            'Where' => [
                'v0.name NOT IN (\'valid\')'
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
        Name      => 'Sort: Attribute "ValidID"',
        Attribute => 'ValidID',
        Expected  => {
            'OrderBy' => [
                'f.valid_id'
            ],
            'Select'  => [
                'f.valid_id'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Valid"',
        Attribute => 'Valid',
        Expected  => {
            'Join' => [
                'INNER JOIN valid v0 ON f.valid_id = v0.id'
            ],
            'OrderBy' => [
                'v0.name'
            ],
            'Select'  => [
                'v0.name'
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

## prepare test valid ##
my $ValidID1 = 1;
my $ValidID2 = 2;
my $ValidID3 = 3;

## prepare test faq articles ##
# first faq article
my $FAQArticleID1 = $Kernel::OM->Get('FAQ')->FAQAdd(
    Title       => $Helper->GetRandomID(),
    CategoryID  => 1,
    Visibility  => 'internal',
    Language    => 'en',
    ValidID     => $ValidID1,
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
    ValidID     => $ValidID2,
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
    ValidID     => $ValidID3,
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
        Name     => "Search: Field ValidID / Operator EQ / Value \$ValidID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ValidID',
                    Operator => 'EQ',
                    Value    => $ValidID2
                }
            ]
        },
        Expected => [$FAQArticleID2]
    },
    {
        Name     => "Search: Field FAQArticleID / Operator NE / Value \$ValidID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ValidID',
                    Operator => 'NE',
                    Value    => $ValidID2
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID3]
    },
    {
        Name     => "Search: Field FAQArticleID / Operator IN / Value [\$ValidID1,\$ValidID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'ValidID',
                    Operator => 'IN',
                    Value    => [$ValidID1,$ValidID3]
                }
            ]
        },
        Expected => [$FAQArticleID1, $FAQArticleID3]
    },
    {
        Name     => "Search: Field FAQArticleID / Operator !IN / Value [\$ValidID1,\$ValidID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'ValidID',
                    Operator => '!IN',
                    Value    => [$ValidID1,$ValidID3]
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
        Name     => 'Sort: Field ValidID',
        Sort     => [
            {
                Field => 'ValidID'
            }
        ],
        Expected => [$FAQArticleID1, $FAQArticleID2, $FAQArticleID3]
    },
    {
        Name     => 'Sort: Field ValidID / Direction ascending',
        Sort     => [
            {
                Field     => 'ValidID',
                Direction => 'ascending'
            }
        ],
        Expected => [$FAQArticleID1, $FAQArticleID2, $FAQArticleID3]
    },
    {
        Name     => 'Sort: Field ValidID / Direction descending',
        Sort     => [
            {
                Field     => 'ValidID',
                Direction => 'descending'
            }
        ],
        Expected => [$FAQArticleID3, $FAQArticleID2, $FAQArticleID1]
    }
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
