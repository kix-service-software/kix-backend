# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::FAQArticle::General';

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
        Title => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        Number => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        Keywords => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        Language => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        }
    },
    'GetSupportedAttributes provides expected data'
);

# Quoting ESCAPE character backslash
my $QuoteBack = $Kernel::OM->Get('DB')->GetDatabaseFunction('QuoteBack');
my $Escape = "\\";
if ( $QuoteBack ) {
    $Escape =~ s/\\/$QuoteBack\\/g;
}

# Quoting single quote character
my $QuoteSingle = $Kernel::OM->Get('DB')->GetDatabaseFunction('QuoteSingle');

# Quoting semicolon character
my $QuoteSemicolon = $Kernel::OM->Get('DB')->GetDatabaseFunction('QuoteSemicolon');

# check if database is casesensitive
my $CaseSensitive = $Kernel::OM->Get('DB')->GetDatabaseFunction('CaseSensitive');

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
            Field    => 'Title',
            Operator => 'LIKE',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Field undef',
        Search       => {
            Field    => undef,
            Operator => 'LIKE',
            Value    => 'test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Field invalid',
        Search       => {
            Field    => 'Test',
            Operator => 'LIKE',
            Value    => 'test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator undef',
        Search       => {
            Field    => 'Title',
            Operator => undef,
            Value    => 'test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'Title',
            Operator => 'Test',
            Value    => 'test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field Title / Operator EQ',
        Search       => {
            Field    => 'Title',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_subject) = \'test\'' : 'f.f_subject = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Title / Operator NE',
        Search       => {
            Field    => 'Title',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(f.f_subject) != \'test\' OR f.f_subject IS NULL)' : '(f.f_subject != \'test\' OR f.f_subject IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Title / Operator IN',
        Search       => {
            Field    => 'Title',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_subject) IN (\'test\')' : 'f.f_subject IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Title / Operator !IN',
        Search       => {
            Field    => 'Title',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_subject) NOT IN (\'test\')' : 'f.f_subject NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Title / Operator STARTSWITH',
        Search       => {
            Field    => 'Title',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_subject) LIKE \'test%\'' : 'f.f_subject LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Title / Operator ENDSWITH',
        Search       => {
            Field    => 'Title',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_subject) LIKE \'%test\'' : 'f.f_subject LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Title / Operator CONTAINS',
        Search       => {
            Field    => 'Title',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_subject) LIKE \'%test%\'' : 'f.f_subject LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Title / Operator LIKE',
        Search       => {
            Field    => 'Title',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_subject) LIKE \'test\'' : 'f.f_subject LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Number / Operator EQ',
        Search       => {
            Field    => 'Number',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_number) = \'test\'' : 'f.f_number = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Number / Operator NE',
        Search       => {
            Field    => 'Number',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(f.f_number) != \'test\' OR f.f_number IS NULL)' : '(f.f_number != \'test\' OR f.f_number IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Number / Operator IN',
        Search       => {
            Field    => 'Number',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_number) IN (\'test\')' : 'f.f_number IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Number / Operator !IN',
        Search       => {
            Field    => 'Number',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_number) NOT IN (\'test\')' : 'f.f_number NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Number / Operator STARTSWITH',
        Search       => {
            Field    => 'Number',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_number) LIKE \'test%\'' : 'f.f_number LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Number / Operator ENDSWITH',
        Search       => {
            Field    => 'Number',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_number) LIKE \'%test\'' : 'f.f_number LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Number / Operator CONTAINS',
        Search       => {
            Field    => 'Number',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_number) LIKE \'%test%\'' : 'f.f_number LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Number / Operator LIKE',
        Search       => {
            Field    => 'Number',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_number) LIKE \'test\'' : 'f.f_number LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Keywords / Operator EQ',
        Search       => {
            Field    => 'Keywords',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_keywords) = \'test\'' : 'f.f_keywords = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Keywords / Operator NE',
        Search       => {
            Field    => 'Keywords',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(f.f_keywords) != \'test\' OR f.f_keywords IS NULL)' : '(f.f_keywords != \'test\' OR f.f_keywords IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Keywords / Operator IN',
        Search       => {
            Field    => 'Keywords',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_keywords) IN (\'test\')' : 'f.f_keywords IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Keywords / Operator !IN',
        Search       => {
            Field    => 'Keywords',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_keywords) NOT IN (\'test\')' : 'f.f_keywords NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Keywords / Operator STARTSWITH',
        Search       => {
            Field    => 'Keywords',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_keywords) LIKE \'test%\'' : 'f.f_keywords LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Keywords / Operator ENDSWITH',
        Search       => {
            Field    => 'Keywords',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_keywords) LIKE \'%test\'' : 'f.f_keywords LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Keywords / Operator CONTAINS',
        Search       => {
            Field    => 'Keywords',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_keywords) LIKE \'%test%\'' : 'f.f_keywords LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Keywords / Operator LIKE',
        Search       => {
            Field    => 'Keywords',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_keywords) LIKE \'test\'' : 'f.f_keywords LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Language / Operator EQ',
        Search       => {
            Field    => 'Language',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.language) = \'test\'' : 'f.language = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Language / Operator NE',
        Search       => {
            Field    => 'Language',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(f.language) != \'test\' OR f.language IS NULL)' : '(f.language != \'test\' OR f.language IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Language / Operator IN',
        Search       => {
            Field    => 'Language',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.language) IN (\'test\')' : 'f.language IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Language / Operator !IN',
        Search       => {
            Field    => 'Language',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.language) NOT IN (\'test\')' : 'f.language NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Language / Operator STARTSWITH',
        Search       => {
            Field    => 'Language',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.language) LIKE \'test%\'' : 'f.language LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Language / Operator ENDSWITH',
        Search       => {
            Field    => 'Language',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.language) LIKE \'%test\'' : 'f.language LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Language / Operator CONTAINS',
        Search       => {
            Field    => 'Language',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.language) LIKE \'%test%\'' : 'f.language LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Language / Operator LIKE',
        Search       => {
            Field    => 'Language',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.language) LIKE \'test\'' : 'f.language LIKE \'test\''
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
        Name      => 'Sort: Attribute "Title"',
        Attribute => 'Title',
        Expected  => {
            'OrderBy' => [
                'LOWER(f.f_subject)'
            ],
            'Select' => [
                'LOWER(f.f_subject)'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Number"',
        Attribute => 'Number',
        Expected  => {
            'OrderBy' => [
                'f.f_number'
            ],
            'Select' => [
                'f.f_number'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Keywords"',
        Attribute => 'Keywords',
        Expected  => {
            'OrderBy' => [
                'LOWER(COALESCE(f.f_keywords,\'\'))'
            ],
            'Select' => [
                'LOWER(COALESCE(f.f_keywords,\'\'))'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Language"',
        Attribute => 'Language',
        Expected  => {
            'OrderBy' => [
                'f.language'
            ],
            'Select' => [
                'f.language'
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

## prepare faq params ##
my %FAQParam;
for my $Key (
    qw(
        Title Number Language Keywords
    )
) {
    my $LCount = 658;
    my $Count  = 658_849;
    for ( 0..3 ) {
        push(
            @{$FAQParam{$Key}},
            ($Key eq 'Language' ? 'Lang' : $Key)
                . q{-}
                . ($Key eq 'Language' ? $LCount++ : $Count++)
        );
    }
}

## prepare test faq articles ##
# first faq article
my $FAQArticleID1 = $Kernel::OM->Get('FAQ')->FAQAdd(
    Title       => $FAQParam{Title}[0],
    CategoryID  => 1,
    Visibility  => 'internal',
    Language    => $FAQParam{Language}[0],
    ValidID     => 1,
    ContentType => 'text/plain',
    UserID      => 1,
    Keywords    => $FAQParam{Keywords}[0],
    Number      => $FAQParam{Number}[0]
);
$Self->True(
    $FAQArticleID1,
    'Created first faq article'
);
# second faq article
my $FAQArticleID2 = $Kernel::OM->Get('FAQ')->FAQAdd(
    Title       => $FAQParam{Title}[1],
    CategoryID  => 1,
    Visibility  => 'internal',
    Language    => $FAQParam{Language}[1],
    ValidID     => 1,
    ContentType => 'text/plain',
    UserID      => 1,
    Keywords    => $FAQParam{Keywords}[1],
    Number      => $FAQParam{Number}[1]
);
$Self->True(
    $FAQArticleID1,
    'Created second faq article'
);
# third faq article
my $FAQArticleID3 = $Kernel::OM->Get('FAQ')->FAQAdd(
    Title       => $FAQParam{Title}[2],
    CategoryID  => 1,
    Visibility  => 'internal',
    Language    => $FAQParam{Language}[2],
    ValidID     => 1,
    ContentType => 'text/plain',
    UserID      => 1,
    Keywords    => $FAQParam{Keywords}[2],
    Number      => $FAQParam{Number}[2]
);
$Self->True(
    $FAQArticleID1,
    'Created third faq article'
);

my %Results = $ObjectSearch->Search(
    ObjectType => 'FAQArticle',
    Result     => 'HASH',
    Language   => 'en',
    UserType   => 'Agent',
    UserID     => 1,
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => "Search: Field Title / Operator EQ / Value \$FAQParam{Title}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'EQ',
                    Value    => $FAQParam{Title}[0]
                }
            ]
        },
        Expected => [$FAQArticleID1]
    },
    {
        Name     => "Search: Field Title / Operator NE / Value \$FAQParam{Title}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'NE',
                    Value    => $FAQParam{Title}[0]
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Title / Operator IN / Value \$FAQParam{Title}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'IN',
                    Value    => $FAQParam{Title}[0]
                }
            ]
        },
        Expected => [$FAQArticleID1]
    },
    {
        Name     => "Search: Field Title / Operator !IN / Value \$FAQParam{Title}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => '!IN',
                    Value    => $FAQParam{Title}[0]
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Title / Operator STARTSWITH / Value \$FAQParam{Title}[1]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'STARTSWITH',
                    Value    => $FAQParam{Title}[1]
                }
            ]
        },
        Expected => [$FAQArticleID2]
    },
    {
        Name     => "Search: Field Title / Operator STARTSWITH / Value substr(\$FAQParam{Title}[1],0,5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'STARTSWITH',
                    Value    => substr($FAQParam{Title}[1],0,5)
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Title / Operator ENDSWITH / Value \$FAQParam{Title}[2]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'ENDSWITH',
                    Value    => $FAQParam{Title}[2]
                }
            ]
        },
        Expected => [$FAQArticleID3]
    },
    {
        Name     => "Search: Field Title / Operator ENDSWITH / Value substr(\$FAQParam{Title}[2],-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'ENDSWITH',
                    Value    => substr($FAQParam{Title}[2],-5)
                }
            ]
        },
        Expected => [$FAQArticleID3]
    },
    {
        Name     => "Search: Field Title / Operator CONTAINS / Value \$FAQParam{Title}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'CONTAINS',
                    Value    => $FAQParam{Title}[0]
                }
            ]
        },
        Expected => [$FAQArticleID1]
    },
    {
        Name     => "Search: Field Title / Operator CONTAINS / Value substr(\$FAQParam{Title}[0],5,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'CONTAINS',
                    Value    => substr($FAQParam{Title}[0],5,-5)
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Title / Operator LIKE / Value \$FAQParam{Title}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'LIKE',
                    Value    => $FAQParam{Title}[0]
                }
            ]
        },
        Expected => [$FAQArticleID1]
    },
    {
        Name     => "Search: Field Title / Operator LIKE / Value *substr(\$FAQParam{Title}[0],5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'LIKE',
                    Value    => q{*} . substr($FAQParam{Title}[0],5)
                }
            ]
        },
        Expected => [$FAQArticleID1]
    },
    {
        Name     => "Search: Field Number / Operator EQ / Value \$FAQParam{Number}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'EQ',
                    Value    => $FAQParam{Number}[0]
                }
            ]
        },
        Expected => [$FAQArticleID1]
    },
    {
        Name     => "Search: Field Number / Operator NE / Value \$FAQParam{Number}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'NE',
                    Value    => $FAQParam{Number}[0]
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Number / Operator IN / Value \$FAQParam{Number}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'IN',
                    Value    => $FAQParam{Number}[0]
                }
            ]
        },
        Expected => [$FAQArticleID1]
    },
    {
        Name     => "Search: Field Number / Operator !IN / Value \$FAQParam{Number}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => '!IN',
                    Value    => $FAQParam{Number}[0]
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Number / Operator STARTSWITH / Value \$FAQParam{Number}[1]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'STARTSWITH',
                    Value    => $FAQParam{Number}[1]
                }
            ]
        },
        Expected => [$FAQArticleID2]
    },
    {
        Name     => "Search: Field Number / Operator STARTSWITH / Value substr(\$FAQParam{Number}[1],0,5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'STARTSWITH',
                    Value    => substr($FAQParam{Number}[1],0,5)
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Number / Operator ENDSWITH / Value \$FAQParam{Number}[2]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'ENDSWITH',
                    Value    => $FAQParam{Number}[2]
                }
            ]
        },
        Expected => [$FAQArticleID3]
    },
    {
        Name     => "Search: Field Number / Operator ENDSWITH / Value substr(\$FAQParam{Number}[2],-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'ENDSWITH',
                    Value    => substr($FAQParam{Number}[2],-2)
                }
            ]
        },
        Expected => [$FAQArticleID3]
    },
    {
        Name     => "Search: Field Number / Operator CONTAINS / Value \$FAQParam{Number}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'CONTAINS',
                    Value    => $FAQParam{Number}[0]
                }
            ]
        },
        Expected => [$FAQArticleID1]
    },
    {
        Name     => "Search: Field Number / Operator CONTAINS / Value substr(\$FAQParam{Number}[0],3,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'CONTAINS',
                    Value    => substr($FAQParam{Number}[0],3,-2)
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Number / Operator LIKE / Value \$FAQParam{Number}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'LIKE',
                    Value    => $FAQParam{Number}[0]
                }
            ]
        },
        Expected => [$FAQArticleID1]
    },
    {
        Name     => "Search: Field Number / Operator LIKE / Value *substr(\$FAQParam{Number}[0],5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'LIKE',
                    Value    => q{*} . substr($FAQParam{Number}[0],5)
                }
            ]
        },
        Expected => [$FAQArticleID1]
    },
    {
        Name     => "Search: Field Language / Operator EQ / Value \$FAQParam{Language}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Language',
                    Operator => 'EQ',
                    Value    => $FAQParam{Language}[0]
                }
            ]
        },
        Expected => [$FAQArticleID1]
    },
    {
        Name     => "Search: Field Language / Operator NE / Value \$FAQParam{Language}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Language',
                    Operator => 'NE',
                    Value    => $FAQParam{Language}[0]
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Language / Operator IN / Value \$FAQParam{Language}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Language',
                    Operator => 'IN',
                    Value    => $FAQParam{Language}[0]
                }
            ]
        },
        Expected => [$FAQArticleID1]
    },
    {
        Name     => "Search: Field Language / Operator !IN / Value \$FAQParam{Language}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Language',
                    Operator => '!IN',
                    Value    => $FAQParam{Language}[0]
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Language / Operator STARTSWITH / Value \$FAQParam{Language}[1]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Language',
                    Operator => 'STARTSWITH',
                    Value    => $FAQParam{Language}[1]
                }
            ]
        },
        Expected => [$FAQArticleID2]
    },
    {
        Name     => "Search: Field Language / Operator STARTSWITH / Value substr(\$FAQParam{Language}[1],0,2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Language',
                    Operator => 'STARTSWITH',
                    Value    => substr($FAQParam{Language}[1],0,2)
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Language / Operator ENDSWITH / Value \$FAQParam{Language}[2]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Language',
                    Operator => 'ENDSWITH',
                    Value    => $FAQParam{Language}[2]
                }
            ]
        },
        Expected => [$FAQArticleID3]
    },
    {
        Name     => "Search: Field Language / Operator ENDSWITH / Value substr(\$FAQParam{Language}[2],-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Language',
                    Operator => 'ENDSWITH',
                    Value    => substr($FAQParam{Language}[2],-2)
                }
            ]
        },
        Expected => [$FAQArticleID3]
    },
    {
        Name     => "Search: Field Language / Operator CONTAINS / Value \$FAQParam{Language}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Language',
                    Operator => 'CONTAINS',
                    Value    => $FAQParam{Language}[0]
                }
            ]
        },
        Expected => [$FAQArticleID1]
    },
    {
        Name     => "Search: Field Language / Operator CONTAINS / Value substr(\$FAQParam{Language}[0],2,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Language',
                    Operator => 'CONTAINS',
                    Value    => substr($FAQParam{Language}[0],2,-2)
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Language / Operator LIKE / Value \$FAQParam{Language}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Language',
                    Operator => 'LIKE',
                    Value    => $FAQParam{Language}[0]
                }
            ]
        },
        Expected => [$FAQArticleID1]
    },
    {
        Name     => "Search: Field Language / Operator LIKE / Value *substr(\$FAQParam{Language}[0],5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Language',
                    Operator => 'LIKE',
                    Value    => q{*} . substr($FAQParam{Language}[0],5)
                }
            ]
        },
        Expected => [$FAQArticleID1]
    },
    {
        Name     => "Search: Field Keywords / Operator EQ / Value \$FAQParam{Keywords}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Keywords',
                    Operator => 'EQ',
                    Value    => $FAQParam{Keywords}[0]
                }
            ]
        },
        Expected => [$FAQArticleID1]
    },
    {
        Name     => "Search: Field Keywords / Operator NE / Value \$FAQParam{Keywords}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Keywords',
                    Operator => 'NE',
                    Value    => $FAQParam{Keywords}[0]
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Keywords / Operator IN / Value \$FAQParam{Keywords}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Keywords',
                    Operator => 'IN',
                    Value    => $FAQParam{Keywords}[0]
                }
            ]
        },
        Expected => [$FAQArticleID1]
    },
    {
        Name     => "Search: Field Keywords / Operator !IN / Value \$FAQParam{Keywords}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Keywords',
                    Operator => '!IN',
                    Value    => $FAQParam{Keywords}[0]
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Keywords / Operator STARTSWITH / Value \$FAQParam{Keywords}[1]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Keywords',
                    Operator => 'STARTSWITH',
                    Value    => $FAQParam{Keywords}[1]
                }
            ]
        },
        Expected => [$FAQArticleID2]
    },
    {
        Name     => "Search: Field Keywords / Operator STARTSWITH / Value substr(\$FAQParam{Keywords}[1],0,5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Keywords',
                    Operator => 'STARTSWITH',
                    Value    => substr($FAQParam{Keywords}[1],0,5)
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Keywords / Operator ENDSWITH / Value \$FAQParam{Keywords}[2]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Keywords',
                    Operator => 'ENDSWITH',
                    Value    => $FAQParam{Keywords}[2]
                }
            ]
        },
        Expected => [$FAQArticleID3]
    },
    {
        Name     => "Search: Field Keywords / Operator ENDSWITH / Value substr(\$FAQParam{Keywords}[2],-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Keywords',
                    Operator => 'ENDSWITH',
                    Value    => substr($FAQParam{Keywords}[2],-5)
                }
            ]
        },
        Expected => [$FAQArticleID3]
    },
    {
        Name     => "Search: Field Keywords / Operator CONTAINS / Value \$FAQParam{Keywords}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Keywords',
                    Operator => 'CONTAINS',
                    Value    => $FAQParam{Keywords}[0]
                }
            ]
        },
        Expected => [$FAQArticleID1]
    },
    {
        Name     => "Search: Field Keywords / Operator CONTAINS / Value substr(\$FAQParam{Keywords}[0],5,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Keywords',
                    Operator => 'CONTAINS',
                    Value    => substr($FAQParam{Keywords}[0],5,-5)
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Keywords / Operator LIKE / Value \$FAQParam{Keywords}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Keywords',
                    Operator => 'LIKE',
                    Value    => $FAQParam{Keywords}[0]
                }
            ]
        },
        Expected => [$FAQArticleID1]
    },
    {
        Name     => "Search: Field Keywords / Operator LIKE / Value *substr(\$FAQParam{Keywords}[0],5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Keywords',
                    Operator => 'LIKE',
                    Value    => q{*} . substr($FAQParam{Keywords}[0],5)
                }
            ]
        },
        Expected => [$FAQArticleID1]
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

# check Sort
my @IntegrationSortTests = (
    {
        Name     => 'Sort: Field Title',
        Sort     => [
            {
                Field => 'Title'
            }
        ],
        Expected => [$FAQArticleID1, $FAQArticleID2, $FAQArticleID3]
    },
    {
        Name     => 'Sort: Field Title / Direction ascending',
        Sort     => [
            {
                Field     => 'Title',
                Direction => 'ascending'
            }
        ],
        Expected => [$FAQArticleID1, $FAQArticleID2, $FAQArticleID3]
    },
    {
        Name     => 'Sort: Field Title / Direction descending',
        Sort     => [
            {
                Field     => 'Title',
                Direction => 'descending'
            }
        ],
        Expected => [$FAQArticleID3, $FAQArticleID2, $FAQArticleID1]
    },
    {
        Name     => 'Sort: Field Number',
        Sort     => [
            {
                Field => 'Number'
            }
        ],
        Expected => [$FAQArticleID1, $FAQArticleID2, $FAQArticleID3]
    },
    {
        Name     => 'Sort: Field Number / Direction ascending',
        Sort     => [
            {
                Field     => 'Number',
                Direction => 'ascending'
            }
        ],
        Expected => [$FAQArticleID1, $FAQArticleID2, $FAQArticleID3]
    },
    {
        Name     => 'Sort: Field Number / Direction descending',
        Sort     => [
            {
                Field     => 'Number',
                Direction => 'descending'
            }
        ],
        Expected => [$FAQArticleID3, $FAQArticleID2, $FAQArticleID1]
    },
    {
        Name     => 'Sort: Field Language',
        Sort     => [
            {
                Field => 'Language'
            }
        ],
        Expected => [$FAQArticleID1, $FAQArticleID2, $FAQArticleID3]
    },
    {
        Name     => 'Sort: Field Language / Direction ascending',
        Sort     => [
            {
                Field     => 'Language',
                Direction => 'ascending'
            }
        ],
        Expected => [$FAQArticleID1, $FAQArticleID2, $FAQArticleID3]
    },
    {
        Name     => 'Sort: Field Language / Direction descending',
        Sort     => [
            {
                Field     => 'Language',
                Direction => 'descending'
            }
        ],
        Expected => [$FAQArticleID3, $FAQArticleID2, $FAQArticleID1]
    },
    {
        Name     => 'Sort: Field Keywords',
        Sort     => [
            {
                Field => 'Keywords'
            }
        ],
        Expected => [$FAQArticleID1, $FAQArticleID2, $FAQArticleID3]
    },
    {
        Name     => 'Sort: Field Keywords / Direction ascending',
        Sort     => [
            {
                Field     => 'Keywords',
                Direction => 'ascending'
            }
        ],
        Expected => [$FAQArticleID1, $FAQArticleID2, $FAQArticleID3]
    },
    {
        Name     => 'Sort: Field Keywords / Direction descending',
        Sort     => [
            {
                Field     => 'Keywords',
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
        Sort       => $Test->{Sort},
        Language   => 'en',
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
