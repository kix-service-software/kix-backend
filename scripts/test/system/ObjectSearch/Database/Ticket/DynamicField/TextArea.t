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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Ticket::DynamicField';
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
    ObjectType    => 'Ticket',
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
        IsSelectable   => 1,
        IsSearchable   => 1,
        IsSortable     => 1,
        IsFulltextable => 1,
        Operators      => ['EMPTY','EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE'],
        ValueType      => ''
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
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = st.id AND dfv_left0.field_id = ' . $DynamicFieldID
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
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = st.id AND dfv_left0.field_id = ' . $DynamicFieldID
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
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = st.id AND dfv_left0.field_id = ' . $DynamicFieldID
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
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = st.id AND dfv_left0.field_id = ' . $DynamicFieldID
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
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = st.id AND dfv_left0.field_id = ' . $DynamicFieldID
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
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = st.id AND dfv_left0.field_id = ' . $DynamicFieldID
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
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = st.id AND dfv_left0.field_id = ' . $DynamicFieldID
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
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = st.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(dfv_left0.value_text) LIKE \'test\'' : 'dfv_left0.value_text LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DynamicField_UnitTest / Operator EMPTY / Value 1',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'EMPTY',
            Value    => 1
        },
        Expected     => {
            'IsRelative' => undef,
            'Join'       => [
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = st.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where'      => [
                '(dfv_left0.value_text = \'\' OR dfv_left0.value_text IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DynamicField_UnitTest / Operator EMPTY / Value 0',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'EMPTY',
            Value    => 0
        },
        Expected     => {
            'IsRelative' => undef,
            'Join'       => [
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = st.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where'      => [
                '(dfv_left0.value_text != \'\' AND dfv_left0.value_text IS NOT NULL)'
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
                "LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = st.id AND dfv_left0.field_id = $DynamicFieldID AND dfv_left0.first_value = 1"
            ],
            Select  => [ 'dfv_left0.value_text AS SortAttr0' ],
            OrderBy => [ 'SortAttr0' ]
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

## prepare test tickets ##
# first ticket
my $TicketID1   = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => 1,
    Lock           => 'unlock',
    PriorityID     => 1,
    StateID        => 1,
    TypeID         => 1,
    OrganisationID => 1,
    ContactID      => 1,
    OwnerID        => 1,
    ResponsibleID  => 1,
    UserID         => 1
);
$Self->True(
    $TicketID1,
    'Created first ticket'
);
my $ValueSet1 = $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
    DynamicFieldConfig => $DynamicFieldConfig,
    ObjectID           => $TicketID1,
    Value              => 'Test1',
    UserID             => 1,
);
$Self->True(
    $ValueSet1,
    'Dynamic field value set for first ticket'
);
# second ticket
my $TicketID2   = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => 1,
    Lock           => 'unlock',
    PriorityID     => 1,
    StateID        => 1,
    TypeID         => 1,
    OrganisationID => 1,
    ContactID      => 1,
    OwnerID        => 1,
    ResponsibleID  => 1,
    UserID         => 1
);
$Self->True(
    $TicketID2,
    'Created second ticket'
);
my $ValueSet2 = $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
    DynamicFieldConfig => $DynamicFieldConfig,
    ObjectID           => $TicketID2,
    Value              => 'Test2',
    UserID             => 1,
);
$Self->True(
    $ValueSet2,
    'Dynamic field value set for second ticket'
);
# third ticket
my $TicketID3   = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => 1,
    Lock           => 'unlock',
    PriorityID     => 1,
    StateID        => 1,
    TypeID         => 1,
    OrganisationID => 1,
    ContactID      => 1,
    OwnerID        => 1,
    ResponsibleID  => 1,
    UserID         => 1
);
$Self->True(
    $TicketID3,
    'Created third ticket without df value'
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Ticket'],
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
        Expected => [$TicketID2]
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
        Expected => [$TicketID2]
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
        Expected => [$TicketID3]
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
        Expected => [$TicketID1,$TicketID3]
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
        Expected => [$TicketID1,$TicketID3]
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
        Expected => [$TicketID1,$TicketID2]
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
        Expected => [$TicketID1,$TicketID2]
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
        Expected => [$TicketID1,$TicketID2]
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
        Expected => [$TicketID2]
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
        Expected => [$TicketID2]
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
        Expected => [$TicketID1,$TicketID2]
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
        Expected => [$TicketID1,$TicketID2]
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
        Expected => [$TicketID1,$TicketID2]
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
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator EMPTY / Value 1',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'EMPTY',
                    Value    => 1
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator EMPTY / Value 0',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'EMPTY',
                    Value    => 0
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2]
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Ticket',
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
        Expected => $OrderByNull eq 'LAST' ? [$TicketID1,$TicketID2,$TicketID3] : [$TicketID3,$TicketID1,$TicketID2]
    },
    {
        Name     => 'Sort: Field DynamicField_UnitTest / Direction ascending',
        Sort     => [
            {
                Field     => 'DynamicField_UnitTest',
                Direction => 'ascending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$TicketID1,$TicketID2,$TicketID3] : [$TicketID3,$TicketID1,$TicketID2]
    },
    {
        Name     => 'Sort: Field DynamicField_UnitTest / Direction descending',
        Sort     => [
            {
                Field     => 'DynamicField_UnitTest',
                Direction => 'descending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$TicketID3,$TicketID2,$TicketID1] : [$TicketID2,$TicketID1,$TicketID3]
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Ticket',
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
