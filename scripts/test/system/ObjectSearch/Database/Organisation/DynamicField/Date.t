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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Organisation::DynamicField';
my $FieldType       = 'Date';

# require module
return if ( !$Kernel::OM->Get('Main')->Require( $AttributeModule ) );

# create backend object
my $AttributeObject = $AttributeModule->new( %{ $Self } );
$Self->Is(
    ref( $AttributeObject ),
    $AttributeModule,
    'Attribute object has correct module ref'
);

# check GetSupportedAttributes before field is created
my $AttributeListBefore = $AttributeObject->GetSupportedAttributes();
$Self->IsDeeply(
    $AttributeListBefore->{'DynamicField_UnitTest'},
    undef,
    'GetSupportedAttributes provides expected data before creation of test field'
);

# get handling of order by null
my $OrderByNull = $Kernel::OM->Get('DB')->GetDatabaseFunction('OrderByNull') || '';

# begin transaction on database
$Helper->BeginWork();

# create dynamic field for unit test
my $DynamicFieldID = $Kernel::OM->Get('DynamicField')->DynamicFieldAdd(
    InternalField => 0,
    Name          => 'UnitTest',
    Label         => 'UnitTest',
    FieldType     => $FieldType,
    ObjectType    => 'Organisation',
    Config        => {},
    ValidID       => 1,
    UserID        => 1,
);
$Self->True(
    $DynamicFieldID,
    'Created dynamic field for UnitTest'
);
my $DynamicFieldConfig = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
    ID => $DynamicFieldID
);

# check GetSupportedAttributes
my $AttributeList = $AttributeObject->GetSupportedAttributes();
$Self->IsDeeply(
    $AttributeList->{'DynamicField_UnitTest'},
    {
        IsSearchable => 1,
        IsSortable   => 1,
        Operators    => ['EQ','NE','GT','GTE','LT','LTE'],
        ValueType    => 'DATE'
    },
    'GetSupportedAttributes provides expected data'
);

# set fixed time to have predetermined verifiable results
my $SystemTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
    String => '2014-01-01 00:00:00',
);
$Helper->FixedTimeSet($SystemTime);

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
            Field    => 'DynamicField_UnitTest',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'DynamicField_UnitTest',
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
            Field    => 'DynamicField_UnitTest',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field DynamicField_UnitTest / Operator EQ',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'EQ',
            Value    => '2014-01-01'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = o.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                'dfv_left0.value_date = \'2014-01-01 00:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DynamicField_UnitTest / Operator NE',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'NE',
            Value    => '2014-01-01'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = o.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                '(dfv_left0.value_date != \'2014-01-01 00:00:00\' OR dfv_left0.value_date IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DynamicField_UnitTest / Operator LT',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'LT',
            Value    => '2014-01-01'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = o.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                'dfv_left0.value_date < \'2014-01-01 00:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DynamicField_UnitTest / Operator GT',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'GT',
            Value    => '2014-01-01'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = o.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                'dfv_left0.value_date > \'2014-01-01 00:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DynamicField_UnitTest / Operator LTE',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'LTE',
            Value    => '2014-01-01'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = o.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                'dfv_left0.value_date <= \'2014-01-01 00:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DynamicField_UnitTest / Operator GTE',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'GTE',
            Value    => '2014-01-01'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = o.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                'dfv_left0.value_date >= \'2014-01-01 00:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DynamicField_UnitTest / Operator EQ / absolute value',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'EQ',
            Value    => '2014-01-01 00:00:00'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = o.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                'dfv_left0.value_date = \'2014-01-01 00:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DynamicField_UnitTest / Operator EQ / relative value',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'EQ',
            Value    => '+1h'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = o.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                'dfv_left0.value_date = \'2014-01-01 01:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field DynamicField_UnitTest / Operator NE / absolute value',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'NE',
            Value    => '2014-01-01 00:00:00'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = o.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                '(dfv_left0.value_date != \'2014-01-01 00:00:00\' OR dfv_left0.value_date IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DynamicField_UnitTest / Operator NE / relative value',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'NE',
            Value    => '+1h'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = o.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                '(dfv_left0.value_date != \'2014-01-01 01:00:00\' OR dfv_left0.value_date IS NULL)'
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field DynamicField_UnitTest / Operator LT / absolute value',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'LT',
            Value    => '2014-01-01 00:00:00'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = o.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                'dfv_left0.value_date < \'2014-01-01 00:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DynamicField_UnitTest / Operator LT / relative value',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'LT',
            Value    => '+1h'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = o.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                'dfv_left0.value_date < \'2014-01-01 01:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field DynamicField_UnitTest / Operator GT / absolute value',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'GT',
            Value    => '2014-01-01 00:00:00'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = o.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                'dfv_left0.value_date > \'2014-01-01 00:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DynamicField_UnitTest / Operator GT / relative value',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'GT',
            Value    => '+1h'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = o.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                'dfv_left0.value_date > \'2014-01-01 01:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field DynamicField_UnitTest / Operator LTE / absolute value',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'LTE',
            Value    => '2014-01-01 00:00:00'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = o.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                'dfv_left0.value_date <= \'2014-01-01 00:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DynamicField_UnitTest / Operator LTE / relative value',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'LTE',
            Value    => '+1h'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = o.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                'dfv_left0.value_date <= \'2014-01-01 01:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field DynamicField_UnitTest / Operator GTE / absolute value',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'GTE',
            Value    => '2014-01-01 00:00:00'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = o.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                'dfv_left0.value_date >= \'2014-01-01 00:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DynamicField_UnitTest / Operator GTE / relative value',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'GTE',
            Value    => '+1h'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = o.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                'dfv_left0.value_date >= \'2014-01-01 01:00:00\''
            ],
            'IsRelative' => 1
        }
    }
);
for my $Test ( @SearchTests ) {
    my $Result = $AttributeObject->Search(
        Search       => $Test->{Search},
        BoolOperator => $Test->{BoolOperator},
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
        Name      => 'Sort: Attribute "DynamicField_UnitTest"',
        Attribute => 'DynamicField_UnitTest',
        Expected  => {
            Join    => [
                "LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = o.id AND dfv_left0.field_id = $DynamicFieldID AND dfv_left0.first_value = 1"
            ],
            Select  => [ 'dfv_left0.value_date' ],
            OrderBy => [ 'dfv_left0.value_date' ]
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

## prepare test organisations ##
# first ticket
my $OrganisationID1   = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => $Helper->GetRandomID(),
    Name    => $Helper->GetRandomID(),
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $OrganisationID1,
    'Created first organisation'
);
my $ValueSet1 = $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
    DynamicFieldConfig => $DynamicFieldConfig,
    ObjectID           => $OrganisationID1,
    Value              => '2014-01-01',
    UserID             => 1,
);
$Self->True(
    $ValueSet1,
    'Dynamic field value set for first organisation'
);
# second ticket
my $OrganisationID2   = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => $Helper->GetRandomID(),
    Name    => $Helper->GetRandomID(),
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $OrganisationID2,
    'Created second organisation'
);
my $ValueSet2 = $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
    DynamicFieldConfig => $DynamicFieldConfig,
    ObjectID           => $OrganisationID2,
    Value              => '2014-01-02',
    UserID             => 1,
);
$Self->True(
    $ValueSet2,
    'Dynamic field value set for second organisation'
);
# third ticket
my $OrganisationID3   = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => $Helper->GetRandomID(),
    Name    => $Helper->GetRandomID(),
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $OrganisationID3,
    'Created third organisation without df value'
);

# discard organisation object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Organisation'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator EQ / Value 2014-01-02',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'EQ',
                    Value    => '2014-01-02'
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator NE / Value 2014-01-02',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'NE',
                    Value    => '2014-01-02'
                }
            ]
        },
        Expected => [1,$OrganisationID1,$OrganisationID3]
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator LT / Value 2014-01-02',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'LT',
                    Value    => '2014-01-02'
                }
            ]
        },
        Expected => [$OrganisationID1]
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator GT / Value 2014-01-02',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'GT',
                    Value    => '2014-01-02'
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator LTE / Value 2014-01-02',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'LTE',
                    Value    => '2014-01-02'
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2]
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator GTE / Value 2014-01-02',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'GTE',
                    Value    => '2014-01-02'
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator EQ / Value 2014-01-02 00:00:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'EQ',
                    Value    => '2014-01-02 00:00:00'
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator EQ / Value +1d',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'EQ',
                    Value    => '+1d'
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator NE / Value 2014-01-02 00:00:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'NE',
                    Value    => '2014-01-02 00:00:00'
                }
            ]
        },
        Expected => [1,$OrganisationID1,$OrganisationID3]
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator NE / Value +1d',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'NE',
                    Value    => '+1d'
                }
            ]
        },
        Expected => [1,$OrganisationID1,$OrganisationID3]
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator LT / Value 2014-01-02 00:00:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'LT',
                    Value    => '2014-01-02 00:00:00'
                }
            ]
        },
        Expected => [$OrganisationID1]
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator LT / Value +1d',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'LT',
                    Value    => '+1d'
                }
            ]
        },
        Expected => [$OrganisationID1]
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator GT / Value 2014-01-02 00:00:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'GT',
                    Value    => '2014-01-02 00:00:00'
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator GT / Value +1d',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'GT',
                    Value    => '+1d'
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator LTE / Value +1d',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'LTE',
                    Value    => '+1d'
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2]
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator LTE / Value 2014-01-02 00:00:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'LTE',
                    Value    => '2014-01-02 00:00:00'
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2]
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator LTE / Value +1d',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'LTE',
                    Value    => '+1d'
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2]
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator GTE / Value 2014-01-02 00:00:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'GTE',
                    Value    => '2014-01-02 00:00:00'
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator GTE / Value +1d',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'GTE',
                    Value    => '+1d'
                }
            ]
        },
        Expected => [$OrganisationID2]
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Organisation',
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
        Name     => 'Sort: Field DynamicField_UnitTest',
        Sort     => [
            {
                Field => 'DynamicField_UnitTest'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$OrganisationID1,$OrganisationID2,1,$OrganisationID3] : [1,$OrganisationID3,$OrganisationID1,$OrganisationID2]
    },
    {
        Name     => 'Sort: Field DynamicField_UnitTest / Direction ascending',
        Sort     => [
            {
                Field     => 'DynamicField_UnitTest',
                Direction => 'ascending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$OrganisationID1,$OrganisationID2,1,$OrganisationID3] : [1,$OrganisationID3,$OrganisationID1,$OrganisationID2]
    },
    {
        Name     => 'Sort: Field DynamicField_UnitTest / Direction descending',
        Sort     => [
            {
                Field     => 'DynamicField_UnitTest',
                Direction => 'descending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [1,$OrganisationID3,$OrganisationID2,$OrganisationID1] : [$OrganisationID2,$OrganisationID1,1,$OrganisationID3]
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Organisation',
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

my $TimeStamp = $Kernel::OM->Get('Time')->CurrentTimestamp();
$Self->Is(
    $TimeStamp,
    '2014-01-01 00:00:00',
    'Timestamp before first relative search'
);
my @FirstResult = $ObjectSearch->Search(
    ObjectType => 'Organisation',
    Result     => 'ARRAY',
    Search     => {
        'AND' => [
            {
                Field    => 'DynamicField_UnitTest',
                Operator => 'GTE',
                Value    => '+1d'
            }
        ]
    },
    UserType   => 'Agent',
    UserID     => 1,
);
$Self->IsDeeply(
    \@FirstResult,
    [$OrganisationID2],
    'Result of first relative search'
);
$Helper->FixedTimeAddSeconds(60);
$TimeStamp = $Kernel::OM->Get('Time')->CurrentTimestamp();
$Self->Is(
    $TimeStamp,
    '2014-01-01 00:01:00',
    'Timestamp before second relative search'
);
my @SecondResult = $ObjectSearch->Search(
    ObjectType => 'Organisation',
    Result     => 'ARRAY',
    Search     => {
        'AND' => [
            {
                Field    => 'DynamicField_UnitTest',
                Operator => 'GTE',
                Value    => '+1d'
            }
        ]
    },
    UserType   => 'Agent',
    UserID     => 1,
);
$Self->IsDeeply(
    \@SecondResult,
    [],
    'Result of second relative search'
);

# reset fixed time
$Helper->FixedTimeUnset();

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
