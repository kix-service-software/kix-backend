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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::GeneralCatalog::General';

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

# check GetSupportedAttributes
my $AttributeList = $AttributeObject->GetSupportedAttributes();
$Self->IsDeeply(
    $AttributeList,
    {
        Name => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Comment => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Class => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
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
        Name         => 'Search: valid search / Field Name / Operator EQ',
        Search       => {
            Field    => 'Name',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(gc.name) = \'test\'' : 'gc.name = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator EQ / Value empty string',
        Search       => {
            Field    => 'Name',
            Operator => 'EQ',
            Value    => q{}
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(gc.name) = \'\'' : 'gc.name = \'\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator NE',
        Search       => {
            Field    => 'Name',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(gc.name) != \'test\'' : 'gc.name != \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator NE / Value empty string',
        Search       => {
            Field    => 'Name',
            Operator => 'NE',
            Value    => q{}
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(gc.name) != \'\'' : 'gc.name != \'\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator IN',
        Search       => {
            Field    => 'Name',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(gc.name) IN (\'test\')' : 'gc.name IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator !IN',
        Search       => {
            Field    => 'Name',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(gc.name) NOT IN (\'test\')' : 'gc.name NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator STARTSWITH',
        Search       => {
            Field    => 'Name',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(gc.name) LIKE \'test%\'' : 'gc.name LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator ENDSWITH',
        Search       => {
            Field    => 'Name',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(gc.name) LIKE \'%test\'' : 'gc.name LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator CONTAINS',
        Search       => {
            Field    => 'Name',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(gc.name) LIKE \'%test%\'' : 'gc.name LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator LIKE',
        Search       => {
            Field    => 'Name',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(gc.name) LIKE \'test\'' : 'gc.name LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Class / Operator EQ',
        Search       => {
            Field    => 'Class',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(gc.general_catalog_class) = \'test\'' : 'gc.general_catalog_class = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Class / Operator EQ / Value empty string',
        Search       => {
            Field    => 'Class',
            Operator => 'EQ',
            Value    => q{}
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(gc.general_catalog_class) = \'\'' : 'gc.general_catalog_class = \'\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Class / Operator NE',
        Search       => {
            Field    => 'Class',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(gc.general_catalog_class) != \'test\'' : 'gc.general_catalog_class != \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Class / Operator NE / Value empty string',
        Search       => {
            Field    => 'Class',
            Operator => 'NE',
            Value    => q{}
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(gc.general_catalog_class) != \'\'' : 'gc.general_catalog_class != \'\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Class / Operator IN',
        Search       => {
            Field    => 'Class',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(gc.general_catalog_class) IN (\'test\')' : 'gc.general_catalog_class IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Class / Operator !IN',
        Search       => {
            Field    => 'Class',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(gc.general_catalog_class) NOT IN (\'test\')' : 'gc.general_catalog_class NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Class / Operator STARTSWITH',
        Search       => {
            Field    => 'Class',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(gc.general_catalog_class) LIKE \'test%\'' : 'gc.general_catalog_class LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Class / Operator ENDSWITH',
        Search       => {
            Field    => 'Class',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(gc.general_catalog_class) LIKE \'%test\'' : 'gc.general_catalog_class LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Class / Operator CONTAINS',
        Search       => {
            Field    => 'Class',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(gc.general_catalog_class) LIKE \'%test%\'' : 'gc.general_catalog_class LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Class / Operator LIKE',
        Search       => {
            Field    => 'Class',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(gc.general_catalog_class) LIKE \'test\'' : 'gc.general_catalog_class LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Comment / Operator EQ',
        Search       => {
            Field    => 'Comment',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(gc.comments) = \'test\'' : 'gc.comments = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Comment / Operator EQ / Value empty string',
        Search       => {
            Field    => 'Comment',
            Operator => 'EQ',
            Value    => q{}
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(gc.comments) = \'\' OR gc.comments IS NULL)' : '(gc.comments = \'\' OR gc.comments IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Comment / Operator NE',
        Search       => {
            Field    => 'Comment',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(gc.comments) != \'test\' OR gc.comments IS NULL)' : '(gc.comments != \'test\' OR gc.comments IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Comment / Operator NE / Value empty string',
        Search       => {
            Field    => 'Comment',
            Operator => 'NE',
            Value    => q{}
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(gc.comments) != \'\'' : 'gc.comments != \'\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Comment / Operator IN',
        Search       => {
            Field    => 'Comment',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(gc.comments) IN (\'test\')' : 'gc.comments IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Comment / Operator !IN',
        Search       => {
            Field    => 'Comment',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(gc.comments) NOT IN (\'test\')' : 'gc.comments NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Comment / Operator STARTSWITH',
        Search       => {
            Field    => 'Comment',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(gc.comments) LIKE \'test%\'' : 'gc.comments LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Comment / Operator ENDSWITH',
        Search       => {
            Field    => 'Comment',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(gc.comments) LIKE \'%test\'' : 'gc.comments LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Comment / Operator CONTAINS',
        Search       => {
            Field    => 'Comment',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(gc.comments) LIKE \'%test%\'' : 'gc.comments LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Comment / Operator LIKE',
        Search       => {
            Field    => 'Comment',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(gc.comments) LIKE \'test\'' : 'gc.comments LIKE \'test\''
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
        Name      => 'Sort: Attribute "Name"',
        Attribute => 'Name',
        Expected  => {
            'OrderBy' => [
                'LOWER(gc.name)'
            ],
            'Select' => [
                'gc.name'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Class"',
        Attribute => 'Class',
        Expected  => {
            'OrderBy' => [
                'LOWER(gc.general_catalog_class)'
            ],
            'Select' => [
                'gc.general_catalog_class'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Comment"',
        Attribute => 'Comment',
        Expected  => {
            'OrderBy' => [
                'SortComment'
            ],
            'Select' => [
                'LOWER(COALESCE(gc.comments,\'\')) AS SortComment'
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
my $SearchName1 = 'Baa';
my $SearchName2 = 'Foo';
my $SearchName3 = 'Unit';
my $SearchClass1 = 'Unit::Test::Type';
my $SearchClass2 = 'Unit::Test::Test';
my $SearchClass3 = 'Unit::Type::Test';
my $SearchComment1 = 'Unit';
my $SearchComment2 = 'Test';
my $SearchComment3 = 'Unit::Test';

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

# discard config item object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['GeneralCatalog'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field Name / Operator EQ / Value $SearchName1',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'EQ',
                    Value    => $SearchName1
                }
            ]
        },
        Expected => [$ItemID2,$ItemID3]
    },
    {
        Name     => 'Search: Field Name / Operator EQ / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'EQ',
                    Value    => q{}
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field Name / Operator NE / Value $SearchName1',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'NE',
                    Value    => $SearchName1
                }
            ]
        },
        Expected => [@ItemIDs,$ItemID1]
    },
    {
        Name     => 'Search: Field Name / Operator NE / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'NE',
                    Value    => q{}
                }
            ]
        },

        Expected => [@ItemIDs,$ItemID1,$ItemID2,$ItemID3]
    },
    {
        Name     => 'Search: Field Name / Operator IN / Value [$SearchName2,$SearchName3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'IN',
                    Value    => [$SearchName2,$SearchName3]
                }
            ]
        },
        Expected => [$ItemID1]
    },
    {
        Name     => 'Search: Field Name / Operator !IN / Value [$SearchName2,$SearchName3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => '!IN',
                    Value    => [$SearchName2,$SearchName3]
                }
            ]
        },
        Expected => [@ItemIDs,$ItemID2,$ItemID3]
    },
    {
        Name     => 'Search: Field Name / Operator STARTSWITH / Value $SearchName1',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'STARTSWITH',
                    Value    => $SearchName1
                }
            ]
        },
        Expected => [$ItemID2,$ItemID3]
    },
    {
        Name     => 'Search: Field Name / Operator STARTSWITH / Value substr($SearchName1,0,4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'STARTSWITH',
                    Value    => substr($SearchName1,0,4)
                }
            ]
        },
        Expected => [$ItemID2,$ItemID3]
    },
    {
        Name     => 'Search: Field Name / Operator ENDSWITH / Value $SearchName1',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'ENDSWITH',
                    Value    => $SearchName1
                }
            ]
        },
        Expected => [$ItemID2,$ItemID3]
    },
    {
        Name     => 'Search: Field Name / Operator ENDSWITH / Value substr($SearchName2,-5)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'ENDSWITH',
                    Value    => substr($SearchName2,-5)
                }
            ]
        },
        Expected => [$ItemID1]
    },
    {
        Name     => 'Search: Field Name / Operator CONTAINS / Value $SearchName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'CONTAINS',
                    Value    => $SearchName2
                }
            ]
        },
        Expected => [$ItemID1]
    },
    {
        Name     => 'Search: Field Name / Operator CONTAINS / Value substr($SearchName2,1,-1)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'CONTAINS',
                    Value    => substr($SearchName2,1,-1)
                },
                {
                    Field    => 'Class',
                    Operator => 'IN',
                    Value    => ['Unit::Test::Type','Unit::Test::Test']
                }
            ]
        },
        Expected => [$ItemID1]
    },
    {
        Name     => 'Search: Field Name / Operator LIKE / Value $SearchName3',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'LIKE',
                    Value    => $SearchName3
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field Class / Operator EQ / Value $SearchClass2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Class',
                    Operator => 'EQ',
                    Value    => $SearchClass2
                }
            ]
        },
        Expected => [$ItemID3]
    },
    {
        Name     => 'Search: Field Class / Operator EQ / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Class',
                    Operator => 'EQ',
                    Value    => q{}
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field Class / Operator NE / Value $SearchClass2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Class',
                    Operator => 'NE',
                    Value    => $SearchClass2
                }
            ]
        },
        Expected => [@ItemIDs,$ItemID1,$ItemID2]
    },
    {
        Name     => 'Search: Field Class / Operator NE / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Class',
                    Operator => 'NE',
                    Value    => q{}
                }
            ]
        },
        Expected => [@ItemIDs,$ItemID1,$ItemID2,$ItemID3]
    },
    {
        Name     => 'Search: Field Class / Operator IN / Value [$SearchClass1,$SearchClass3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Class',
                    Operator => 'IN',
                    Value    => [$SearchClass1,$SearchClass3]
                }
            ]
        },
        Expected => [$ItemID1,$ItemID2]
    },
    {
        Name     => 'Search: Field Class / Operator !IN / Value [$SearchClass1,$SearchClass3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Class',
                    Operator => '!IN',
                    Value    => [$SearchClass1,$SearchClass3]
                }
            ]
        },
        Expected => [@ItemIDs,$ItemID3]
    },
    {
        Name     => 'Search: Field Class / Operator STARTSWITH / Value $SearchClass2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Class',
                    Operator => 'STARTSWITH',
                    Value    => $SearchClass2
                }
            ]
        },
        Expected => [$ItemID3]
    },
    {
        Name     => 'Search: Field Class / Operator STARTSWITH / Value substr($SearchClass2,0,4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Class',
                    Operator => 'STARTSWITH',
                    Value    => substr($SearchClass2,0,4)
                }
            ]
        },
        Expected => [$ItemID1,$ItemID2,$ItemID3]
    },
    {
        Name     => 'Search: Field Class / Operator ENDSWITH / Value $SearchClass2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Class',
                    Operator => 'ENDSWITH',
                    Value    => $SearchClass2
                }
            ]
        },
        Expected => [$ItemID3]
    },
    {
        Name     => 'Search: Field Class / Operator ENDSWITH / Value substr($SearchClass2,-5)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Class',
                    Operator => 'ENDSWITH',
                    Value    => substr($SearchClass2,-5)
                }
            ]
        },
        Expected => [$ItemID3]
    },
    {
        Name     => 'Search: Field Class / Operator CONTAINS / Value $SearchClass2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Class',
                    Operator => 'CONTAINS',
                    Value    => $SearchClass2
                }
            ]
        },
        Expected => [$ItemID3]
    },
    {
        Name     => 'Search: Field Class / Operator CONTAINS / Value substr($SearchClass2,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Class',
                    Operator => 'CONTAINS',
                    Value    => substr($SearchClass2,2,-2)
                }
            ]
        },
        Expected => [$ItemID3]
    },
    {
        Name     => 'Search: Field Class / Operator LIKE / Value $SearchClass2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Class',
                    Operator => 'LIKE',
                    Value    => $SearchClass2
                }
            ]
        },
        Expected => [$ItemID3]
    },
    {
        Name     => 'Search: Field Comment / Operator EQ / Value $SearchComment2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'EQ',
                    Value    => $SearchComment2
                },
                {
                    Field    => 'Class',
                    Operator => 'IN',
                    Value    => ['Unit::Test::Type','Unit::Test::Test']
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field Comment / Operator EQ / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'EQ',
                    Value    => q{}
                },
                {
                    Field    => 'Class',
                    Operator => 'IN',
                    Value    => ['Unit::Test::Type','Unit::Test::Test']
                }
            ]
        },
        Expected => [$ItemID1,$ItemID3]
    },
    {
        Name     => 'Search: Field Comment / Operator NE / Value $SearchComment2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'NE',
                    Value    => $SearchComment2
                },
                {
                    Field    => 'Class',
                    Operator => 'IN',
                    Value    => ['Unit::Test::Type','Unit::Test::Test']
                }
            ]
        },
        Expected => [$ItemID1,$ItemID2,$ItemID3,]
    },
    {
        Name     => 'Search: Field Comment / Operator NE / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'NE',
                    Value    => q{}
                },
                {
                    Field    => 'Class',
                    Operator => 'IN',
                    Value    => ['Unit::Test::Type','Unit::Test::Test']
                }
            ]
        },
        Expected => [$ItemID2]
    },
    {
        Name     => 'Search: Field Comment / Operator IN / Value [$SearchComment1,$SearchComment3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'IN',
                    Value    => [$SearchComment1,$SearchComment3]
                },
                {
                    Field    => 'Class',
                    Operator => 'IN',
                    Value    => ['Unit::Test::Type','Unit::Test::Test']
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field Comment / Operator !IN / Value [$SearchComment1,$SearchComment3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => '!IN',
                    Value    => [$SearchComment1,$SearchComment3]
                },
                {
                    Field    => 'Class',
                    Operator => 'IN',
                    Value    => ['Unit::Test::Type','Unit::Test::Test']
                }
            ]
        },
        Expected => [$ItemID1,$ItemID2,$ItemID3]
    },
    {
        Name     => 'Search: Field Comment / Operator STARTSWITH / Value $SearchComment2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'STARTSWITH',
                    Value    => $SearchComment2
                },
                {
                    Field    => 'Class',
                    Operator => 'IN',
                    Value    => ['Unit::Test::Type','Unit::Test::Test']
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field Comment / Operator STARTSWITH / Value substr($SearchComment2,0,2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'STARTSWITH',
                    Value    => substr($SearchComment2,0,2)
                },
                {
                    Field    => 'Class',
                    Operator => 'IN',
                    Value    => ['Unit::Test::Type','Unit::Test::Test']
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field Comment / Operator ENDSWITH / Value $SearchComment2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'ENDSWITH',
                    Value    => $SearchComment2
                },
                {
                    Field    => 'Class',
                    Operator => 'IN',
                    Value    => ['Unit::Test::Type','Unit::Test::Test']
                }
            ]
        },
        Expected => [$ItemID2]
    },
    {
        Name     => 'Search: Field Comment / Operator ENDSWITH / Value substr($SearchComment2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'ENDSWITH',
                    Value    => substr($SearchComment2,-2)
                },
                {
                    Field    => 'Class',
                    Operator => 'IN',
                    Value    => ['Unit::Test::Type','Unit::Test::Test']
                }
            ]
        },
        Expected => [$ItemID2]
    },
    {
        Name     => 'Search: Field Comment / Operator CONTAINS / Value $SearchComment2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'CONTAINS',
                    Value    => $SearchComment2
                },
                {
                    Field    => 'Class',
                    Operator => 'IN',
                    Value    => ['Unit::Test::Type','Unit::Test::Test']
                }
            ]
        },
        Expected => [$ItemID2]
    },
    {
        Name     => 'Search: Field Comment / Operator CONTAINS / Value substr($SearchComment2,1,-1)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'CONTAINS',
                    Value    => substr($SearchComment2,1,-1)
                },
                {
                    Field    => 'Class',
                    Operator => 'IN',
                    Value    => ['Unit::Test::Type','Unit::Test::Test']
                }
            ]
        },
        Expected => [$ItemID2]
    },
    {
        Name     => 'Search: Field Comment / Operator LIKE / Value $SearchComment2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'LIKE',
                    Value    => $SearchComment2
                },
                {
                    Field    => 'Class',
                    Operator => 'IN',
                    Value    => ['Unit::Test::Type','Unit::Test::Test']
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
        Name     => 'Sort: Field Name',
        Sort     => [
            {
                Field => 'Name'
            }
        ],
        Expected => [$ItemID2,$ItemID3,$ItemID1]
    },
    {
        Name     => 'Sort: Field Name / Direction ascending',
        Sort     => [
            {
                Field     => 'Name',
                Direction => 'ascending'
            }
        ],
        Expected => [$ItemID2,$ItemID3,$ItemID1]
    },
    {
        Name     => 'Sort: Field Name / Direction descending',
        Sort     => [
            {
                Field     => 'Name',
                Direction => 'descending'
            }
        ],
        Expected => [$ItemID1,$ItemID2,$ItemID3]
    },
    {
        Name     => 'Sort: Field Class',
        Sort     => [
            {
                Field => 'Class'
            }
        ],
        Expected => [$ItemID3,$ItemID1,$ItemID2]
    },
    {
        Name     => 'Sort: Field Class / Direction ascending',
        Sort     => [
            {
                Field     => 'Class',
                Direction => 'ascending'
            }
        ],
        Expected => [$ItemID3,$ItemID1,$ItemID2]
    },
    {
        Name     => 'Sort: Field Class / Direction descending',
        Sort     => [
            {
                Field     => 'Class',
                Direction => 'descending'
            }
        ],
        Expected => [$ItemID1,$ItemID2,$ItemID3]
    },
    {
        Name     => 'Sort: Field Comment',
        Sort     => [
            {
                Field => 'Comment'
            }
        ],
        Expected => [$ItemID1,$ItemID3,$ItemID2]
    },
    {
        Name     => 'Sort: Field Comment / Direction ascending',
        Sort     => [
            {
                Field     => 'Comment',
                Direction => 'ascending'
            }
        ],
        Expected => [$ItemID1,$ItemID3,$ItemID2]
    },
    {
        Name     => 'Sort: Field Comment / Direction descending',
        Sort     => [
            {
                Field     => 'Comment',
                Direction => 'descending'
            }
        ],
        Expected => [$ItemID2,$ItemID1,$ItemID3]
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'GeneralCatalog',
        Result     => 'ARRAY',
        Sort       => $Test->{Sort},
        Search     => {
            AND => [
                {
                    Field    => 'Class',
                    Operator => 'IN',
                    Value    => ['Unit::Test::Type','Unit::Test::Test']
                }
            ]
        },
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
