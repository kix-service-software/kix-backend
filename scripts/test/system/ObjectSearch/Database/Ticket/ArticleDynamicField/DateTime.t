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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Ticket::ArticleDynamicField';
my $FieldType       = 'DateTime';

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

# begin transaction on database
$Helper->BeginWork();

# create dynamic field for unit test
my $DynamicFieldID = $Kernel::OM->Get('DynamicField')->DynamicFieldAdd(
    InternalField => 0,
    Name          => 'UnitTest',
    Label         => 'UnitTest',
    FieldType     => $FieldType,
    ObjectType    => 'Article',
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
        IsSortable   => 0,
        Operators    => ['EQ','NE','GT','GTE','LT','LTE'],
        ValueType    => 'DATETIME'
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

for my $UserType ( qw(Agent Customer) ) {

    # prepare suffix for article join
    my $JoinArticleSuffix = '';
    if ( $UserType eq 'Customer' ) {
        $JoinArticleSuffix = ' AND ta.customer_visible = 1'
    }
    my @JoinTests = (
    {
        Name         => 'Search: valid search / UserType ' . $UserType . ' / Field DynamicField_UnitTest / Operator EQ / absolute value',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'EQ',
            Value    => '2014-01-01 00:00:00'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = ta.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                'dfv_left0.value_date = \'2014-01-01 00:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / UserType ' . $UserType . ' / Field DynamicField_UnitTest / Operator EQ / relative value',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'EQ',
            Value    => '+1h'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = ta.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                'dfv_left0.value_date = \'2014-01-01 01:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / UserType ' . $UserType . ' / Field DynamicField_UnitTest / Operator NE / absolute value',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'NE',
            Value    => '2014-01-01 00:00:00'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = ta.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                '(dfv_left0.value_date != \'2014-01-01 00:00:00\' OR dfv_left0.value_date IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / UserType ' . $UserType . ' / Field DynamicField_UnitTest / Operator NE / relative value',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'NE',
            Value    => '+1h'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = ta.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                '(dfv_left0.value_date != \'2014-01-01 01:00:00\' OR dfv_left0.value_date IS NULL)'
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / UserType ' . $UserType . ' / Field DynamicField_UnitTest / Operator LT / absolute value',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'LT',
            Value    => '2014-01-01 00:00:00'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = ta.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                'dfv_left0.value_date < \'2014-01-01 00:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / UserType ' . $UserType . ' / Field DynamicField_UnitTest / Operator LT / relative value',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'LT',
            Value    => '+1h'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = ta.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                'dfv_left0.value_date < \'2014-01-01 01:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / UserType ' . $UserType . ' / Field DynamicField_UnitTest / Operator GT / absolute value',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'GT',
            Value    => '2014-01-01 00:00:00'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = ta.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                'dfv_left0.value_date > \'2014-01-01 00:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / UserType ' . $UserType . ' / Field DynamicField_UnitTest / Operator GT / relative value',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'GT',
            Value    => '+1h'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = ta.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                'dfv_left0.value_date > \'2014-01-01 01:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / UserType ' . $UserType . ' / Field DynamicField_UnitTest / Operator LTE / absolute value',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'LTE',
            Value    => '2014-01-01 00:00:00'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = ta.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                'dfv_left0.value_date <= \'2014-01-01 00:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / UserType ' . $UserType . ' / Field DynamicField_UnitTest / Operator LTE / relative value',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'LTE',
            Value    => '+1h'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = ta.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                'dfv_left0.value_date <= \'2014-01-01 01:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / UserType ' . $UserType . ' / Field DynamicField_UnitTest / Operator GTE / absolute value',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'GTE',
            Value    => '2014-01-01 00:00:00'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = ta.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                'dfv_left0.value_date >= \'2014-01-01 00:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / UserType ' . $UserType . ' / Field DynamicField_UnitTest / Operator GTE / relative value',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'GTE',
            Value    => '+1h'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = ta.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where' => [
                'dfv_left0.value_date >= \'2014-01-01 01:00:00\''
            ],
            'IsRelative' => 1
        }
    }
    );
    for my $Test ( @JoinTests ) {
        my $Result = $AttributeObject->Search(
            Search       => $Test->{Search},
            UserType     => $UserType,
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
# first article of first ticket (customer visible)
my $ArticleID1 = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID         => $TicketID1,
    ChannelID        => 1,
    CustomerVisible  => 1,
    SenderType       => 'agent',
    Subject          => 'first article of first ticket',
    Body             => 'object search dynamic field',
    Charset          => 'utf-8',
    MimeType         => 'text/plain',
    HistoryType      => 'AddNote',
    HistoryComment   => 'object search dynamic field',
    UserID           => 1
);
$Self->True(
    $ArticleID1,
    'Created first article of first ticket'
);
my $ValueSet1 = $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
    DynamicFieldConfig => $DynamicFieldConfig,
    ObjectID           => $ArticleID1,
    Value              => '2014-01-01 00:00:00',
    UserID             => 1,
);
$Self->True(
    $ValueSet1,
    'Dynamic field value set for first article of first ticket'
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
# first article of second ticket (customer NOT visible)
my $ArticleID2 = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID         => $TicketID2,
    ChannelID        => 1,
    SenderType       => 'agent',
    Subject          => 'first article of second ticket',
    Body             => 'object search dynamic field',
    Charset          => 'utf-8',
    MimeType         => 'text/plain',
    HistoryType      => 'AddNote',
    HistoryComment   => 'object search dynamic field',
    UserID           => 1
);
$Self->True(
    $ArticleID2,
    'Created first article of second ticket'
);
my $ValueSet2 = $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
    DynamicFieldConfig => $DynamicFieldConfig,
    ObjectID           => $ArticleID2,
    Value              => '2014-01-02 00:00:00',
    UserID             => 1,
);
$Self->True(
    $ValueSet2,
    'Dynamic field value set for first artciel of second ticket'
);
# third ticket without article
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
    'Created third ticket without article'
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Ticket'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: UserType Agent / Field DynamicField_UnitTest / Operator EQ / Value 2014-01-01 00:00:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'EQ',
                    Value    => '2014-01-01 00:00:00'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: UserType Customer / Field DynamicField_UnitTest / Operator EQ / Value 2014-01-01 00:00:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'EQ',
                    Value    => '2014-01-01 00:00:00'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: UserType Agent / Field DynamicField_UnitTest / Operator EQ / Value 2014-01-02 00:00:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'EQ',
                    Value    => '2014-01-02 00:00:00'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: UserType Customer / Field DynamicField_UnitTest / Operator EQ / Value 2014-01-02 00:00:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'EQ',
                    Value    => '2014-01-02 00:00:00'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [] # article of second ticket is NOT customer visible
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
        Expected => [$TicketID2]
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
        Expected => [$TicketID1,$TicketID3]
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
        Expected => [$TicketID1,$TicketID3]
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
        Expected => [$TicketID1]
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
        Expected => [$TicketID1]
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
        Expected => [$TicketID1,$TicketID2]
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
        Expected => [$TicketID1,$TicketID2]
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
        Expected => [$TicketID1,$TicketID2]
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
        Expected => [$TicketID2]
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
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: UserType Customer / Field DynamicField_UnitTest / Operator GTE / Value +1d',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'GTE',
                    Value    => '+1d'
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Ticket',
        Result     => 'ARRAY',
        Search     => $Test->{Search},
        UserType   => $Test->{UserType} || 'Agent',
        UserID     => 1,
    );
    $Self->IsDeeply(
        \@Result,
        $Test->{Expected},
        $Test->{Name}
    );
}

# test Sort
# attributes of this backend are not sortable

my $TimeStamp = $Kernel::OM->Get('Time')->CurrentTimestamp();
$Self->Is(
    $TimeStamp,
    '2014-01-01 00:00:00',
    'Timestamp before first relative search'
);
my @FirstResult = $ObjectSearch->Search(
    ObjectType => 'Ticket',
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
    [$TicketID2],
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
    ObjectType => 'Ticket',
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
