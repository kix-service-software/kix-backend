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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::ObjectTag::General';

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
        Name      => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        ObjectType => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        ObjectID   => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType    => 'NUMERIC',
            Requires     => ['ObjectType']
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
                $CaseSensitive ? 'LOWER(ot.name) = \'test\'' : 'ot.name = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator EQ / Value empty string',
        Search       => {
            Field    => 'Name',
            Operator => 'EQ',
            Value    => ''
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(ot.name) = \'\'' : 'ot.name = \'\''
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
                $CaseSensitive ? 'LOWER(ot.name) != \'test\'' : 'ot.name != \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator NE / Value empty string',
        Search       => {
            Field    => 'Name',
            Operator => 'NE',
            Value    => ''
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(ot.name) != \'\'' : 'ot.name != \'\''
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
                $CaseSensitive ? 'LOWER(ot.name) IN (\'test\')' : 'ot.name IN (\'test\')'
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
                $CaseSensitive ? 'LOWER(ot.name) NOT IN (\'test\')' : 'ot.name NOT IN (\'test\')'
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
                $CaseSensitive ? 'LOWER(ot.name) LIKE \'test%\'' : 'ot.name LIKE \'test%\''
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
                $CaseSensitive ? 'LOWER(ot.name) LIKE \'%test\'' : 'ot.name LIKE \'%test\''
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
                $CaseSensitive ? 'LOWER(ot.name) LIKE \'%test%\'' : 'ot.name LIKE \'%test%\''
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
                $CaseSensitive ? 'LOWER(ot.name) LIKE \'test\'' : 'ot.name LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ObjectType / Operator EQ',
        Search       => {
            Field    => 'ObjectType',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(ot.object_type) = \'test\'' : 'ot.object_type = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ObjectType / Operator EQ / Value empty string',
        Search       => {
            Field    => 'ObjectType',
            Operator => 'EQ',
            Value    => ''
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(ot.object_type) = \'\'' : 'ot.object_type = \'\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ObjectType / Operator NE',
        Search       => {
            Field    => 'ObjectType',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(ot.object_type) != \'test\'' : 'ot.object_type != \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ObjectType / Operator NE / Value empty string',
        Search       => {
            Field    => 'ObjectType',
            Operator => 'NE',
            Value    => ''
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(ot.object_type) != \'\'' : 'ot.object_type != \'\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ObjectType / Operator IN',
        Search       => {
            Field    => 'ObjectType',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(ot.object_type) IN (\'test\')' : 'ot.object_type IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ObjectType / Operator !IN',
        Search       => {
            Field    => 'ObjectType',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(ot.object_type) NOT IN (\'test\')' : 'ot.object_type NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ObjectType / Operator STARTSWITH',
        Search       => {
            Field    => 'ObjectType',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(ot.object_type) LIKE \'test%\'' : 'ot.object_type LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ObjectType / Operator ENDSWITH',
        Search       => {
            Field    => 'ObjectType',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(ot.object_type) LIKE \'%test\'' : 'ot.object_type LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ObjectType / Operator CONTAINS',
        Search       => {
            Field    => 'ObjectType',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(ot.object_type) LIKE \'%test%\'' : 'ot.object_type LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ObjectType / Operator LIKE',
        Search       => {
            Field    => 'ObjectType',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(ot.object_type) LIKE \'test\'' : 'ot.object_type LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ObjectID / Operator EQ',
        Search       => {
            Field    => 'ObjectID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Requires' => [
                'ObjectType'
            ],
            'Where' => [
                'ot.object_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ObjectID / Operator NE',
        Search       => {
            Field    => 'ObjectID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Requires' => [
                'ObjectType'
            ],
            'Where' => [
                'ot.object_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ObjectID / Operator IN',
        Search       => {
            Field    => 'ObjectID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Requires' => [
                'ObjectType'
            ],
            'Where' => [
                'ot.object_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ObjectID / Operator !IN',
        Search       => {
            Field    => 'ObjectID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Requires' => [
                'ObjectType'
            ],
            'Where' => [
                'ot.object_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ObjectID / Operator LT',
        Search       => {
            Field    => 'ObjectID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Requires' => [
                'ObjectType'
            ],
            'Where' => [
                'ot.object_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ObjectID / Operator LTE',
        Search       => {
            Field    => 'ObjectID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Requires' => [
                'ObjectType'
            ],
            'Where' => [
                'ot.object_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ObjectID / Operator GT',
        Search       => {
            Field    => 'ObjectID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Requires' => [
                'ObjectType'
            ],
            'Where' => [
                'ot.object_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ObjectID / Operator GTE',
        Search       => {
            Field    => 'ObjectID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Requires' => [
                'ObjectType'
            ],
            'Where' => [
                'ot.object_id >= 1'
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
            'Select'  => ['LOWER(ot.name)'],
            'OrderBy' => ['LOWER(ot.name)']
        }
    },
    {
        Name      => 'Sort: Attribute "ObjectType"',
        Attribute => 'ObjectType',
        Expected  => {
            'Select'  => ['LOWER(ot.object_type)'],
            'OrderBy' => ['LOWER(ot.object_type)']
        }
    },
    {
        Name      => 'Sort: Attribute "ObjectID"',
        Attribute => 'ObjectID',
        Expected  => {
            'Select'  => ['ot.object_id'],
            'OrderBy' => ['ot.object_id']
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

## prepare test objecttag ##
my $TestData1 = 'Test001';
my $TestData2 = 'test002';
my $TestData3 = 'Test003';

# first objecttag
my $ObjectTagID1 = $Kernel::OM->Get('ObjectTag')->ObjectTagAdd(
    Name       => $TestData1,
    ObjectType => $TestData1,
    ObjectID   => 1,
    UserID     => 1
);
$Self->True(
    $ObjectTagID1,
    'Created first objecttag'
);
# second objecttag
my $ObjectTagID2 = $Kernel::OM->Get('ObjectTag')->ObjectTagAdd(
    Name       => $TestData2,
    ObjectType => $TestData2,
    ObjectID   => 2,
    UserID     => 1
);
$Self->True(
    $ObjectTagID2,
    'Created second objecttag'
);
# third objecttag
my $ObjectTagID3 = $Kernel::OM->Get('ObjectTag')->ObjectTagAdd(
    Name       => $TestData3,
    ObjectType => $TestData3,
    ObjectID   => 3,
    UserID     => 1
);
$Self->True(
    $ObjectTagID3,
    'Created third objecttag'
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['ObjectTag'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field Name / Operator EQ / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'EQ',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$TestData2]
    },
    {
        Name     => 'Search: Field Name / Operator EQ / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'EQ',
                    Value    => ''
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field Name / Operator NE / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'NE',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$TestData1,$TestData3]
    },
    {
        Name     => 'Search: Field Name / Operator NE / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'NE',
                    Value    => ''
                }
            ]
        },
        Expected => [$TestData1,$TestData2,$TestData3]
    },
    {
        Name     => 'Search: Field Name / Operator IN / Value [$TestData1,$TestData3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'IN',
                    Value    => [$TestData1,$TestData3]
                }
            ]
        },
        Expected => [$TestData1,$TestData3]
    },
    {
        Name     => 'Search: Field Name / Operator !IN / Value [$TestData1,$TestData3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => '!IN',
                    Value    => [$TestData1,$TestData3]
                }
            ]
        },
        Expected => [$TestData2]
    },
    {
        Name     => 'Search: Field Name / Operator STARTSWITH / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'STARTSWITH',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$TestData2]
    },
    {
        Name     => 'Search: Field Name / Operator STARTSWITH / Value substr($TestData2,0,4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'STARTSWITH',
                    Value    => substr($TestData2,0,4)
                }
            ]
        },
        Expected => [$TestData1,$TestData2,$TestData3]
    },
    {
        Name     => 'Search: Field Name / Operator ENDSWITH / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'ENDSWITH',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$TestData2]
    },
    {
        Name     => 'Search: Field Name / Operator ENDSWITH / Value substr($TestData2,-5)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'ENDSWITH',
                    Value    => substr($TestData2,-5)
                }
            ]
        },
        Expected => [$TestData2]
    },
    {
        Name     => 'Search: Field Name / Operator CONTAINS / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'CONTAINS',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$TestData2]
    },
    {
        Name     => 'Search: Field Name / Operator CONTAINS / Value substr($TestData2,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'CONTAINS',
                    Value    => substr($TestData2,2,-2)
                }
            ]
        },
        Expected => [$TestData1,$TestData2,$TestData3]
    },
    {
        Name     => 'Search: Field Name / Operator LIKE / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'LIKE',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$TestData2]
    },
    {
        Name     => 'Search: Field ObjectType / Operator EQ / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ObjectType',
                    Operator => 'EQ',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$TestData2]
    },
    {
        Name     => 'Search: Field ObjectType / Operator EQ / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'ObjectType',
                    Operator => 'EQ',
                    Value    => ''
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field ObjectType / Operator NE / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ObjectType',
                    Operator => 'NE',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$TestData1,$TestData3]
    },
    {
        Name     => 'Search: Field ObjectType / Operator NE / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'ObjectType',
                    Operator => 'NE',
                    Value    => ''
                }
            ]
        },
        Expected => [$TestData1,$TestData2,$TestData3]
    },
    {
        Name     => 'Search: Field ObjectType / Operator IN / Value [$TestData1,$TestData3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ObjectType',
                    Operator => 'IN',
                    Value    => [$TestData1,$TestData3]
                }
            ]
        },
        Expected => [$TestData1,$TestData3]
    },
    {
        Name     => 'Search: Field ObjectType / Operator !IN / Value [$TestData1,$TestData3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ObjectType',
                    Operator => '!IN',
                    Value    => [$TestData1,$TestData3]
                }
            ]
        },
        Expected => [$TestData2]
    },
    {
        Name     => 'Search: Field ObjectType / Operator STARTSWITH / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ObjectType',
                    Operator => 'STARTSWITH',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$TestData2]
    },
    {
        Name     => 'Search: Field ObjectType / Operator STARTSWITH / Value substr($TestData2,0,4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'ObjectType',
                    Operator => 'STARTSWITH',
                    Value    => substr($TestData2,0,4)
                }
            ]
        },
        Expected => [$TestData1,$TestData2,$TestData3]
    },
    {
        Name     => 'Search: Field ObjectType / Operator ENDSWITH / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ObjectType',
                    Operator => 'ENDSWITH',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$TestData2]
    },
    {
        Name     => 'Search: Field ObjectType / Operator ENDSWITH / Value substr($TestData2,-5)',
        Search   => {
            'AND' => [
                {
                    Field    => 'ObjectType',
                    Operator => 'ENDSWITH',
                    Value    => substr($TestData2,-5)
                }
            ]
        },
        Expected => [$TestData2]
    },
    {
        Name     => 'Search: Field ObjectType / Operator CONTAINS / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ObjectType',
                    Operator => 'CONTAINS',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$TestData2]
    },
    {
        Name     => 'Search: Field ObjectType / Operator CONTAINS / Value substr($TestData2,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'ObjectType',
                    Operator => 'CONTAINS',
                    Value    => substr($TestData2,2,-2)
                }
            ]
        },
        Expected => [$TestData1,$TestData2,$TestData3]
    },
    {
        Name     => 'Search: Field ObjectType / Operator LIKE / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ObjectType',
                    Operator => 'LIKE',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$TestData2]
    },
    {
        Name     => 'Search: Field ObjectID / Operator EQ / Value $ObjectTagID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ObjectID',
                    Operator => 'EQ',
                    Value    => 2
                },
                {
                    Field    => 'ObjectType',
                    Operator => 'LIKE',
                    Value    => '*'
                }
            ]
        },
        Expected => [$TestData2]
    },
    {
        Name     => 'Search: Field ObjectID / Operator NE / Value $ObjectTagID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ObjectID',
                    Operator => 'NE',
                    Value    => 2
                },
                {
                    Field    => 'ObjectType',
                    Operator => 'LIKE',
                    Value    => '*'
                }
            ]
        },
        Expected => [$TestData1,$TestData3]
    },
    {
        Name     => 'Search: Field ObjectID / Operator IN / Value [$ObjectTagID1,$ObjectTagID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ObjectID',
                    Operator => 'IN',
                    Value    => [1,3]
                },
                {
                    Field    => 'ObjectType',
                    Operator => 'LIKE',
                    Value    => '*'
                }
            ]
        },
        Expected => [$TestData1,$TestData3]
    },
    {
        Name     => 'Search: Field ObjectID / Operator !IN / Value [$ObjectTagID1,$ObjectTagID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ObjectID',
                    Operator => '!IN',
                    Value    => [1,3]
                },
                {
                    Field    => 'ObjectType',
                    Operator => 'LIKE',
                    Value    => '*'
                }
            ]
        },
        Expected => [$TestData2]
    },
    {
        Name     => 'Search: Field ObjectID / Operator LT / Value $ObjectTagID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ObjectID',
                    Operator => 'LT',
                    Value    => 2
                },
                {
                    Field    => 'ObjectType',
                    Operator => 'LIKE',
                    Value    => '*'
                }
            ]
        },
        Expected => [$TestData1]
    },
    {
        Name     => 'Search: Field ObjectID / Operator LTE / Value $ObjectTagID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ObjectID',
                    Operator => 'LTE',
                    Value    => 2
                },
                {
                    Field    => 'ObjectType',
                    Operator => 'LIKE',
                    Value    => '*'
                }
            ]
        },
        Expected => [$TestData1,$TestData2]
    },
    {
        Name     => 'Search: Field ObjectID / Operator GT / Value $ObjectTagID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ObjectID',
                    Operator => 'GT',
                    Value    => 2
                },
                {
                    Field    => 'ObjectType',
                    Operator => 'LIKE',
                    Value    => '*'
                }
            ]
        },
        Expected => [$TestData3]
    },
    {
        Name     => 'Search: Field ObjectID / Operator GTE / Value $ObjectTagID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ObjectID',
                    Operator => 'GTE',
                    Value    => 2
                },
                {
                    Field    => 'ObjectType',
                    Operator => 'LIKE',
                    Value    => '*'
                }
            ]
        },
        Expected => [$TestData2,$TestData3]
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'ObjectTag',
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
        Expected => [$TestData1,$TestData2,$TestData3]
    },
    {
        Name     => 'Sort: Field Name / Direction ascending',
        Sort     => [
            {
                Field     => 'Name',
                Direction => 'ascending'
            }
        ],
        Expected => [$TestData1,$TestData2,$TestData3]
    },
    {
        Name     => 'Sort: Field Name / Direction descending',
        Sort     => [
            {
                Field     => 'Name',
                Direction => 'descending'
            }
        ],
        Expected => [$TestData3,$TestData2,$TestData1]
    },
    {
        Name     => 'Sort: Field ObjectType',
        Sort     => [
            {
                Field => 'ObjectType'
            }
        ],
        Expected => [$TestData1,$TestData2,$TestData3]
    },
    {
        Name     => 'Sort: Field ObjectType / Direction ascending',
        Sort     => [
            {
                Field     => 'ObjectType',
                Direction => 'ascending'
            }
        ],
        Expected => [$TestData1,$TestData2,$TestData3]
    },
    {
        Name     => 'Sort: Field ObjectType / Direction descending',
        Sort     => [
            {
                Field     => 'ObjectType',
                Direction => 'descending'
            }
        ],
        Expected => [$TestData3,$TestData2,$TestData1]
    },
    {
        Name     => 'Sort: Field ObjectID',
        Sort     => [
            {
                Field => 'ObjectID'
            }
        ],
        Expected => [$TestData1,$TestData2,$TestData3]
    },
    {
        Name     => 'Sort: Field ObjectID / Direction ascending',
        Sort     => [
            {
                Field     => 'ObjectID',
                Direction => 'ascending'
            }
        ],
        Expected => [$TestData1,$TestData2,$TestData3]
    },
    {
        Name     => 'Sort: Field ObjectID / Direction descending',
        Sort     => [
            {
                Field     => 'ObjectID',
                Direction => 'descending'
            }
        ],
        Expected => [$TestData3,$TestData2,$TestData1]
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'ObjectTag',
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
