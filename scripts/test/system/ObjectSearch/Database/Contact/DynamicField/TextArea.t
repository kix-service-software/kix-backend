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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Contact::DynamicField';
my $FieldType       = 'TextArea';

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
    ObjectType    => 'Contact',
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
        Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE'],
        ValueType    => ''
    },
    'GetSupportedAttributes provides expected data'
);

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
            Field    => 'DynamicField_UnitTest',
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
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = c.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(dfv_left0.value_text) = \'test\'' : 'dfv_left0.value_text = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DynamicField_UnitTest / Operator EQ / Value empty string',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'EQ',
            Value    => ''
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = c.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(dfv_left0.value_text) = \'\' OR dfv_left0.value_text IS NULL)' : '(dfv_left0.value_text = \'\' OR dfv_left0.value_text IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DynamicField_UnitTest / Operator NE',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = c.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(dfv_left0.value_text) != \'test\' OR dfv_left0.value_text IS NULL)' : '(dfv_left0.value_text != \'test\' OR dfv_left0.value_text IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DynamicField_UnitTest / Operator NE / Value empty string',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'NE',
            Value    => ''
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = c.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(dfv_left0.value_text) != \'\'' : 'dfv_left0.value_text != \'\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DynamicField_UnitTest / Operator STARTSWITH',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = c.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(dfv_left0.value_text) LIKE \'test%\'' : 'dfv_left0.value_text LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DynamicField_UnitTest / Operator ENDSWITH',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = c.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(dfv_left0.value_text) LIKE \'%test\'' : 'dfv_left0.value_text LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DynamicField_UnitTest / Operator CONTAINS',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = c.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(dfv_left0.value_text) LIKE \'%test%\'' : 'dfv_left0.value_text LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DynamicField_UnitTest / Operator LIKE',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = c.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(dfv_left0.value_text) LIKE \'test\'' : 'dfv_left0.value_text LIKE \'test\''
            ]
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
                "LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = c.id AND dfv_left0.field_id = $DynamicFieldID AND dfv_left0.first_value = 1"
            ],
            Select  => [ 'dfv_left0.value_text' ],
            OrderBy => [ 'dfv_left0.value_text' ]
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
my $ContactID1   = $Kernel::OM->Get('Contact')->ContactAdd(
    Firstname => $Helper->GetRandomID(),
    Lastname  => $Helper->GetRandomID(),
    ValidID   => 1,
    UserID    => 1
);
$Self->True(
    $ContactID1,
    'Created first organisation'
);
my $ValueSet1 = $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
    DynamicFieldConfig => $DynamicFieldConfig,
    ObjectID           => $ContactID1,
    Value              => 'Test1',
    UserID             => 1,
);
$Self->True(
    $ValueSet1,
    'Dynamic field value set for first organisation'
);
# second ticket
my $ContactID2   = $Kernel::OM->Get('Contact')->ContactAdd(
    Firstname => $Helper->GetRandomID(),
    Lastname  => $Helper->GetRandomID(),
    ValidID   => 1,
    UserID    => 1
);
$Self->True(
    $ContactID2,
    'Created second organisation'
);
my $ValueSet2 = $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
    DynamicFieldConfig => $DynamicFieldConfig,
    ObjectID           => $ContactID2,
    Value              => 'Test2',
    UserID             => 1,
);
$Self->True(
    $ValueSet2,
    'Dynamic field value set for first organisation'
);
# third ticket
my $ContactID3   = $Kernel::OM->Get('Contact')->ContactAdd(
    Firstname => $Helper->GetRandomID(),
    Lastname  => $Helper->GetRandomID(),
    ValidID   => 1,
    UserID    => 1
);
$Self->True(
    $ContactID3,
    'Created third organisation without df value'
);

# discard contact object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Contact'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator EQ / Value Test2',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'EQ',
                    Value    => 'Test2'
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator EQ / Value test2',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'EQ',
                    Value    => 'test2'
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator EQ / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'EQ',
                    Value    => ''
                }
            ]
        },
        Expected => [1,$ContactID3]
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator NE / Value Test2',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'NE',
                    Value    => 'Test2'
                }
            ]
        },
        Expected => [1,$ContactID1,$ContactID3]
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator NE / Value test2',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'NE',
                    Value    => 'test2'
                }
            ]
        },
        Expected => [1,$ContactID1,$ContactID3]
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator NE / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'NE',
                    Value    => ''
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2]
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator STARTSWITH / Value Test',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'STARTSWITH',
                    Value    => 'Test'
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2]
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator STARTSWITH / Value test',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'STARTSWITH',
                    Value    => 'test'
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2]
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator ENDSWITH / Value t2',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'ENDSWITH',
                    Value    => 't2'
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator ENDSWITH / Value T2',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'ENDSWITH',
                    Value    => 'T2'
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator CONTAINS / Value est',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'CONTAINS',
                    Value    => 'est'
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2]
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator CONTAINS / Value EST',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'CONTAINS',
                    Value    => 'EST'
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2]
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator LIKE / Value Test*',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'LIKE',
                    Value    => 'Test*'
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2]
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator LIKE / Value test*',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'LIKE',
                    Value    => 'test*'
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2]
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Contact',
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
        Expected => $OrderByNull eq 'LAST' ? [$ContactID1,$ContactID2,1,$ContactID3] : [1,$ContactID3,$ContactID1,$ContactID2]
    },
    {
        Name     => 'Sort: Field DynamicField_UnitTest / Direction ascending',
        Sort     => [
            {
                Field     => 'DynamicField_UnitTest',
                Direction => 'ascending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ContactID1,$ContactID2,1,$ContactID3] : [1,$ContactID3,$ContactID1,$ContactID2]
    },
    {
        Name     => 'Sort: Field DynamicField_UnitTest / Direction descending',
        Sort     => [
            {
                Field     => 'DynamicField_UnitTest',
                Direction => 'descending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [1,$ContactID3,$ContactID2,$ContactID1] : [$ContactID2,$ContactID1,1,$ContactID3]
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Contact',
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
