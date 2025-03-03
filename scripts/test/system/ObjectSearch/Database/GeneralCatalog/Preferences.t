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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::GeneralCatalog::Preferences';

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
        'Attribute object can "' . $Method . '"'
    );
}


# check GetSupportedAttributes before test attribute is created
my $AttributeListBefore = $AttributeObject->GetSupportedAttributes();
$Self->IsDeeply(
    $AttributeListBefore->{'UnitTest'},
    undef,
    'GetSupportedAttributes provides expected data before creation of test attribute'
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

# get handling of order by null
my $OrderByNull = $Kernel::OM->Get('DB')->GetDatabaseFunction('OrderByNull') || '';

# begin transaction on database
$Helper->BeginWork();

# add option
my $Success = $Kernel::OM->Get('Config')->Set(
    Key   => 'GeneralCatalogPreferences###UnitTest',
    Value => {
        Class   => 'Unit::Test::Type',
        PrefKey => 'UnitTest'
    }
);

$Self->True(
    $Success,
    'Create SysConfig Option'
);

$Kernel::OM->Get('Cache')->CleanUp(
    Type => 'GeneralCatalog'
);
$Kernel::OM->Get('Cache')->CleanUp(
    Type => 'ObjectSearch_GeneralCatalog'
);

# check GetSupportedAttributes
my $AttributeList = $AttributeObject->GetSupportedAttributes();
$Self->IsDeeply(
    $AttributeList->{'UnitTest'},
    {
        IsSearchable => 1,
        IsSortable   => 1,
        Operators    => ['EQ','NE','IN','!IN','ENDSWITH','STARTSWITH','CONTAINS','LIKE'],
        Class        => [ 'Unit::Test::Type' ]
    },
    'GetSupportedAttributes provides expected data for searchable attribute'
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
            Field    => 'Name',
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
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Field invalid',
        Search       => {
            Field    => 'Test',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator undef',
        Search       => {
            Field    => 'Name',
            Operator => undef,
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'Name',
            Operator => 'Test',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field UnitTest / Operator EQ',
        Search       => {
            Field    => 'UnitTest',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN general_catalog_preferences gcp0 ON gcp0.general_catalog_id = gc.id',
                'AND gcp0.pref_key = \'UnitTest\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(gcp0.pref_value) = \'test\'' : 'gcp0.pref_value = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field UnitTest / Operator EQ / Value empty string',
        Search       => {
            Field    => 'UnitTest',
            Operator => 'EQ',
            Value    => q{}
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN general_catalog_preferences gcp0 ON gcp0.general_catalog_id = gc.id',
                'AND gcp0.pref_key = \'UnitTest\''
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(gcp0.pref_value) = \'\' OR gcp0.pref_value IS NULL)' : '(gcp0.pref_value = \'\' OR gcp0.pref_value IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field UnitTest / Operator NE',
        Search       => {
            Field    => 'UnitTest',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN general_catalog_preferences gcp0 ON gcp0.general_catalog_id = gc.id',
                'AND gcp0.pref_key = \'UnitTest\''
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(gcp0.pref_value) != \'test\' OR gcp0.pref_value IS NULL)' : '(gcp0.pref_value != \'test\' OR gcp0.pref_value IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field UnitTest / Operator NE / Value empty string',
        Search       => {
            Field    => 'UnitTest',
            Operator => 'NE',
            Value    => q{}
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN general_catalog_preferences gcp0 ON gcp0.general_catalog_id = gc.id',
                'AND gcp0.pref_key = \'UnitTest\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(gcp0.pref_value) != \'\'' : 'gcp0.pref_value != \'\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field UnitTest / Operator IN',
        Search       => {
            Field    => 'UnitTest',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN general_catalog_preferences gcp0 ON gcp0.general_catalog_id = gc.id',
                'AND gcp0.pref_key = \'UnitTest\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(gcp0.pref_value) IN (\'test\')' : 'gcp0.pref_value IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field UnitTest / Operator !IN',
        Search       => {
            Field    => 'UnitTest',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN general_catalog_preferences gcp0 ON gcp0.general_catalog_id = gc.id',
                'AND gcp0.pref_key = \'UnitTest\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(gcp0.pref_value) NOT IN (\'test\')' : 'gcp0.pref_value NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field UnitTest / Operator STARTSWITH',
        Search       => {
            Field    => 'UnitTest',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN general_catalog_preferences gcp0 ON gcp0.general_catalog_id = gc.id',
                'AND gcp0.pref_key = \'UnitTest\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(gcp0.pref_value) LIKE \'test%\'' : 'gcp0.pref_value LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field UnitTest / Operator ENDSWITH',
        Search       => {
            Field    => 'UnitTest',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN general_catalog_preferences gcp0 ON gcp0.general_catalog_id = gc.id',
                'AND gcp0.pref_key = \'UnitTest\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(gcp0.pref_value) LIKE \'%test\'' : 'gcp0.pref_value LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field UnitTest / Operator CONTAINS',
        Search       => {
            Field    => 'UnitTest',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN general_catalog_preferences gcp0 ON gcp0.general_catalog_id = gc.id',
                'AND gcp0.pref_key = \'UnitTest\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(gcp0.pref_value) LIKE \'%test%\'' : 'gcp0.pref_value LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field UnitTest / Operator LIKE',
        Search       => {
            Field    => 'UnitTest',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN general_catalog_preferences gcp0 ON gcp0.general_catalog_id = gc.id',
                'AND gcp0.pref_key = \'UnitTest\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(gcp0.pref_value) LIKE \'test\'' : 'gcp0.pref_value LIKE \'test\''
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
        Name      => 'Sort: Attribute "UnitTest"',
        Attribute => 'UnitTest',
        Expected  => {
            'Join' => [
                'LEFT OUTER JOIN general_catalog_preferences gcp0 ON gcp0.general_catalog_id = gc.id',
                'AND gcp0.pref_key = \'UnitTest\''
            ],
            'OrderBy' => [
                'gcp0.pref_value'
            ],
            'Select' => [
                'gcp0.pref_value'
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

# prepare result lists
my @ItemIDs = $ObjectSearch->Search(
    ObjectType => 'GeneralCatalog',
    Result     => 'ARRAY',
    UserType   => 'Agent',
    UserID     => 1,
);

$Self->True(
    scalar( @ItemIDs ),
    'ItemID: GET / All Items'
);

## prepare test general catalog items ##
my $Value1 = 'Unit Test';
my $Value2 = 'Test';
my $Value3 = 'Unit';

# first item
my $ItemID1     = $Kernel::OM->Get('GeneralCatalog')->ItemAdd(
    Class   => 'Unit::Test::Type',
    Name    => 'Foo',
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $ItemID1,
    'Created first item'
);
my $Pref1 = $Kernel::OM->Get('GeneralCatalog')->GeneralCatalogPreferencesSet(
    ItemID => $ItemID1,
    Key    => 'UnitTest',
    Value  => 'Unit Test',
);
$Self->True(
    $Pref1,
    'Add preference to first item'
);

# second item
my $ItemID2 = $Kernel::OM->Get('GeneralCatalog')->ItemAdd(
    Class   => 'Unit::Test::Type',
    Name    => 'Baa',
    Comment => 'UnitTest',
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $ItemID2,
    'Created second item'
);
my $Pref2 = $Kernel::OM->Get('GeneralCatalog')->GeneralCatalogPreferencesSet(
    ItemID => $ItemID2,
    Key    => 'UnitTest',
    Value  => 'Test Unit',
);
$Self->True(
    $Pref2,
    'Add preference to second item'
);

# third item
my $ItemID3 = $Kernel::OM->Get('GeneralCatalog')->ItemAdd(
    Class   => 'Unit::Test::Test',
    Name    => 'Baa',
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $ItemID3,
    'Created third item'
);
my $Pref3 = $Kernel::OM->Get('GeneralCatalog')->GeneralCatalogPreferencesSet(
    ItemID => $ItemID3,
    Key    => 'UnitTest',
    Value  => 'Unit Test',
);
$Self->True(
    $Pref3,
    'Add preference to third item'
);

# discard config item object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['GeneralCatalog'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field UnitTest / Operator EQ / Value $Value1',
        Search   => {
            'AND' => [
                {
                    Field    => 'UnitTest',
                    Operator => 'EQ',
                    Value    => $Value1
                }
            ]
        },
        Expected => [$ItemID1, $ItemID3]
    },
    {
        Name     => 'Search: Field UnitTest / Operator EQ / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'UnitTest',
                    Operator => 'EQ',
                    Value    => q{}
                }
            ]
        },
        Expected => [@ItemIDs]
    },
    {
        Name     => 'Search: Field UnitTest / Operator NE / Value $Value1',
        Search   => {
            'AND' => [
                {
                    Field    => 'UnitTest',
                    Operator => 'NE',
                    Value    => $Value1
                }
            ]
        },
        Expected => [@ItemIDs, $ItemID2]
    },
    {
        Name     => 'Search: Field UnitTest / Operator NE / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'UnitTest',
                    Operator => 'NE',
                    Value    => q{}
                }
            ]
        },

        Expected => [$ItemID1,$ItemID2,$ItemID3]
    },
    {
        Name     => 'Search: Field UnitTest / Operator IN / Value [$Value2,$Value3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'UnitTest',
                    Operator => 'IN',
                    Value    => [$Value2,$Value3]
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field UnitTest / Operator !IN / Value [$Value2,$Value3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'UnitTest',
                    Operator => '!IN',
                    Value    => [$Value2,$Value3]
                }
            ]
        },
        Expected => [$ItemID1,$ItemID2,$ItemID3]
    },
    {
        Name     => 'Search: Field UnitTest / Operator STARTSWITH / Value $Value1',
        Search   => {
            'AND' => [
                {
                    Field    => 'UnitTest',
                    Operator => 'STARTSWITH',
                    Value    => $Value1
                }
            ]
        },
        Expected => [$ItemID1,$ItemID3]
    },
    {
        Name     => 'Search: Field UnitTest / Operator STARTSWITH / Value substr($Value1,0,2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'UnitTest',
                    Operator => 'STARTSWITH',
                    Value    => substr($Value1,0,2)
                }
            ]
        },
        Expected => [$ItemID1,$ItemID3]
    },
    {
        Name     => 'Search: Field UnitTest / Operator ENDSWITH / Value $Value1',
        Search   => {
            'AND' => [
                {
                    Field    => 'UnitTest',
                    Operator => 'ENDSWITH',
                    Value    => $Value1
                }
            ]
        },
        Expected => [$ItemID1,$ItemID3]
    },
    {
        Name     => 'Search: Field UnitTest / Operator ENDSWITH / Value substr($Value2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'UnitTest',
                    Operator => 'ENDSWITH',
                    Value    => substr($Value2,-2)
                }
            ]
        },
        Expected => [$ItemID1,$ItemID3]
    },
    {
        Name     => 'Search: Field UnitTest / Operator CONTAINS / Value $Value2',
        Search   => {
            'AND' => [
                {
                    Field    => 'UnitTest',
                    Operator => 'CONTAINS',
                    Value    => $Value2
                }
            ]
        },
        Expected => [$ItemID1,$ItemID2,$ItemID3]
    },
    {
        Name     => 'Search: Field UnitTest / Operator CONTAINS / Value substr($Value2,1,-1)',
        Search   => {
            'AND' => [
                {
                    Field    => 'UnitTest',
                    Operator => 'CONTAINS',
                    Value    => substr($Value2,1,-1)
                }
            ]
        },
        Expected => [$ItemID1,$ItemID2,$ItemID3]
    },
    {
        Name     => 'Search: Field UnitTest / Operator LIKE / Value $Value3',
        Search   => {
            'AND' => [
                {
                    Field    => 'UnitTest',
                    Operator => 'LIKE',
                    Value    => $Value3
                }
            ]
        },
        Expected => []
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'GeneralCatalog',
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
        Name     => 'Sort: Field UnitTest',
        Sort     => [
            {
                Field => 'UnitTest'
            }
        ],
        Expected => [$ItemID2,$ItemID1,$ItemID3,@ItemIDs]
    },
    {
        Name     => 'Sort: Field UnitTest / Direction ascending',
        Sort     => [
            {
                Field     => 'UnitTest',
                Direction => 'ascending'
            }
        ],
        Expected => [$ItemID2,$ItemID1,$ItemID3,@ItemIDs]
    },
    {
        Name     => 'Sort: Field UnitTest / Direction descending',
        Sort     => [
            {
                Field     => 'UnitTest',
                Direction => 'descending'
            }
        ],
        Expected => [@ItemIDs,$ItemID1,$ItemID3,$ItemID2]
    }
);
if ( $OrderByNull eq 'LAST' ) {
    for my $Test ( @IntegrationSortTests ) {
        my @Result = $ObjectSearch->Search(
            ObjectType => 'GeneralCatalog',
            Result     => 'ARRAY',
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
}
else {
    $Self->True(
        1,
        '## TODO ## Check Sort for OrderByNull FIRST'
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
