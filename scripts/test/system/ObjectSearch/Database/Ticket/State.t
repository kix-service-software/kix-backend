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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Ticket::State';

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
        StateID     => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType      => 'NUMERIC'
        },
        State       => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        StateTypeID => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType      => 'NUMERIC'
        },
        StateType   => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        }
    },
    'GetSupportedAttributes provides expected data'
);

my @ViewableStateIDs = $Kernel::OM->Get('State')->StateGetStatesByType(
    Type   => 'Viewable',
    Result => 'ID',
);
my $ViewableStateIDsString = join( ',', @ViewableStateIDs );

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
            Field    => 'StateID',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'StateID',
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
            Field    => 'StateID',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'StateID',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field StateID / Operator EQ',
        Search       => {
            Field    => 'StateID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.ticket_state_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateID / Operator NE',
        Search       => {
            Field    => 'StateID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.ticket_state_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateID / Operator IN',
        Search       => {
            Field    => 'StateID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.ticket_state_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateID / Operator !IN',
        Search       => {
            Field    => 'StateID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.ticket_state_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateID / Operator LT',
        Search       => {
            Field    => 'StateID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.ticket_state_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateID / Operator GT',
        Search       => {
            Field    => 'StateID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.ticket_state_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateID / Operator LTE',
        Search       => {
            Field    => 'StateID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.ticket_state_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateID / Operator GTE',
        Search       => {
            Field    => 'StateID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.ticket_state_id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field State / Operator EQ',
        Search       => {
            Field    => 'State',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id'
            ],
            'Where' => [
                'ts.name = \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field State / Operator NE',
        Search       => {
            Field    => 'State',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id'
            ],
            'Where' => [
                'ts.name != \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field State / Operator IN',
        Search       => {
            Field    => 'State',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id'
            ],
            'Where' => [
                'ts.name IN (\'Test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field State / Operator !IN',
        Search       => {
            Field    => 'State',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id'
            ],
            'Where' => [
                'ts.name NOT IN (\'Test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field State / Operator STARTSWITH',
        Search       => {
            Field    => 'State',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id'
            ],
            'Where' => [
                'ts.name LIKE \'Test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field State / Operator ENDSWITH',
        Search       => {
            Field    => 'State',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id'
            ],
            'Where' => [
                'ts.name LIKE \'%Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field State / Operator CONTAINS',
        Search       => {
            Field    => 'State',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id'
            ],
            'Where' => [
                'ts.name LIKE \'%Test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field State / Operator LIKE',
        Search       => {
            Field    => 'State',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id'
            ],
            'Where' => [
                'ts.name LIKE \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateTypeID / Operator EQ',
        Search       => {
            Field    => 'StateTypeID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id'
            ],
            'Where' => [
                'ts.type_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateTypeID / Operator NE',
        Search       => {
            Field    => 'StateTypeID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id'
            ],
            'Where' => [
                'ts.type_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateTypeID / Operator IN',
        Search       => {
            Field    => 'StateTypeID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id'
            ],
            'Where' => [
                'ts.type_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateTypeID / Operator !IN',
        Search       => {
            Field    => 'StateTypeID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id'
            ],
            'Where' => [
                'ts.type_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateTypeID / Operator LT',
        Search       => {
            Field    => 'StateTypeID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id'
            ],
            'Where' => [
                'ts.type_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateTypeID / Operator GT',
        Search       => {
            Field    => 'StateTypeID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id'
            ],
            'Where' => [
                'ts.type_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateTypeID / Operator LTE',
        Search       => {
            Field    => 'StateTypeID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id'
            ],
            'Where' => [
                'ts.type_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateTypeID / Operator GTE',
        Search       => {
            Field    => 'StateTypeID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id'
            ],
            'Where' => [
                'ts.type_id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateType / Operator EQ',
        Search       => {
            Field    => 'StateType',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id',
                'INNER JOIN ticket_state_type tst ON tst.id = ts.type_id'
            ],
            'Where' => [
                'tst.name = \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateType / Operator NE',
        Search       => {
            Field    => 'StateType',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id',
                'INNER JOIN ticket_state_type tst ON tst.id = ts.type_id'
            ],
            'Where' => [
                'tst.name != \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateType / Operator IN',
        Search       => {
            Field    => 'StateType',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id',
                'INNER JOIN ticket_state_type tst ON tst.id = ts.type_id'
            ],
            'Where' => [
                'tst.name IN (\'Test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateType / Operator !IN',
        Search       => {
            Field    => 'StateType',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id',
                'INNER JOIN ticket_state_type tst ON tst.id = ts.type_id'
            ],
            'Where' => [
                'tst.name NOT IN (\'Test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateType / Operator STARTSWITH',
        Search       => {
            Field    => 'StateType',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id',
                'INNER JOIN ticket_state_type tst ON tst.id = ts.type_id'
            ],
            'Where' => [
                'tst.name LIKE \'Test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateType / Operator ENDSWITH',
        Search       => {
            Field    => 'StateType',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id',
                'INNER JOIN ticket_state_type tst ON tst.id = ts.type_id'
            ],
            'Where' => [
                'tst.name LIKE \'%Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateType / Operator CONTAINS',
        Search       => {
            Field    => 'StateType',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id',
                'INNER JOIN ticket_state_type tst ON tst.id = ts.type_id'
            ],
            'Where' => [
                'tst.name LIKE \'%Test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateType / Operator LIKE',
        Search       => {
            Field    => 'StateType',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id',
                'INNER JOIN ticket_state_type tst ON tst.id = ts.type_id'
            ],
            'Where' => [
                'tst.name LIKE \'Test\''
            ]
        }
    },
    ## special handling StateType 'Open' and 'Closed'
    {
        Name         => 'Search: valid search / Field StateType / Operator EQ / Value Open',
        Search       => {
            Field    => 'StateType',
            Operator => 'EQ',
            Value    => 'Open'
        },
        Expected     => {
            'Join' => [],
            'Where' => [
                'st.ticket_state_id IN (' . $ViewableStateIDsString . ')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateType / Operator NE / Value Open',
        Search       => {
            Field    => 'StateType',
            Operator => 'NE',
            Value    => 'Open'
        },
        Expected     => {
            'Join' => [],
            'Where' => [
                'st.ticket_state_id NOT IN (' . $ViewableStateIDsString . ')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateType / Operator IN / Value Closed',
        Search       => {
            Field    => 'StateType',
            Operator => 'IN',
            Value    => 'Closed'
        },
        Expected     => {
            'Join' => [],
            'Where' => [
                'st.ticket_state_id NOT IN (' . $ViewableStateIDsString . ')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateType / Operator !IN / Value Closed',
        Search       => {
            Field    => 'StateType',
            Operator => '!IN',
            Value    => 'Closed'
        },
        Expected     => {
            'Join' => [],
            'Where' => [
                'st.ticket_state_id IN (' . $ViewableStateIDsString . ')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateType / Operator EQ / Value Open and Closed',
        Search       => {
            Field    => 'StateType',
            Operator => 'EQ',
            Value    => ['Open','Closed']
        },
        Expected     => {
            'Join' => [],
            'Where' => [
                '(st.ticket_state_id IN (' . $ViewableStateIDsString . ') OR st.ticket_state_id NOT IN (' . $ViewableStateIDsString . '))'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateType / Operator STARTSWITH / Value Open, Closed and Test',
        Search       => {
            Field    => 'StateType',
            Operator => 'STARTSWITH',
            Value    => ['Open','Closed','Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id',
                'INNER JOIN ticket_state_type tst ON tst.id = ts.type_id'
            ],
            'Where' => [
                '(st.ticket_state_id IN (' . $ViewableStateIDsString . ') OR st.ticket_state_id NOT IN (' . $ViewableStateIDsString . ') OR tst.name LIKE \'Test%\')'
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
        Name      => 'Sort: Attribute "StateID"',
        Attribute => 'StateID',
        Expected  => {
            'Join'    => [],
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select'  => [
                'st.ticket_state_id AS SortAttr0'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "State"',
        Attribute => 'State',
        Expected  => {
            'Join'    => [
                'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id',
                'LEFT OUTER JOIN translation_pattern tlp0 ON tlp0.value = ts.name',
                'LEFT OUTER JOIN translation_language tl0 ON tl0.pattern_id = tlp0.id AND tl0.language = \'en\''
            ],
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select'  => [
                'LOWER(COALESCE(tl0.value, ts.name)) AS SortAttr0'
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

# load translations for given language
my @Translations = $Kernel::OM->Get('Translation')->TranslationList();
my %TranslationsDE;
for my $Translation ( @Translations ) {
    $TranslationsDE{ $Translation->{Pattern} } = $Translation->{Languages}->{'de'};
}

## prepare type mapping
my $StateID1 = 1;
my %State1 = $Kernel::OM->Get('State')->StateGet(
    ID => $StateID1
);
my $StateName1     = $State1{Name};
my $StateTypeID1   = $State1{TypeID};
my $StateTypeName1 = $State1{TypeName};
my $StateID2 = 2;
my %State2 = $Kernel::OM->Get('State')->StateGet(
    ID => $StateID2
);
my $StateName2     = $State2{Name};
my $StateTypeID2   = $State2{TypeID};
my $StateTypeName2 = $State2{TypeName};
my $StateID3 = 3;
my %State3 = $Kernel::OM->Get('State')->StateGet(
    ID => $StateID3
);
my $StateName3     = $State3{Name};
my $StateTypeID3   = $State3{TypeID};
my $StateTypeName3 = $State3{TypeName};
$Self->Is(
    $StateName1,
    'new',
    'StateID 1 has expected name'
);
$Self->Is(
    $TranslationsDE{ $StateName1 },
    'neu',
    'StateID 1 has expected translation (de)'
);
$Self->Is(
    $StateTypeID1,
    '1',
    'StateID 1 has expected state type id'
);
$Self->Is(
    $StateTypeName1,
    'new',
    'StateID 1 has expected state type name'
);
$Self->Is(
    $TranslationsDE{ $StateTypeName1 },
    'neu',
    'StateID 1 has expected translation for state type (de)'
);
$Self->Is(
    $StateName2,
    'open',
    'StateID 2 has expected name'
);
$Self->Is(
    $TranslationsDE{ $StateName2 },
    'offen',
    'StateID 2 has expected translation (de)'
);
$Self->Is(
    $StateTypeID2,
    '2',
    'StateID 2 has expected state type id'
);
$Self->Is(
    $StateTypeName2,
    'open',
    'StateID 2 has expected state type name'
);
$Self->Is(
    $TranslationsDE{ $StateTypeName2 },
    'offen',
    'StateID 2 has expected translation for state type (de)'
);
$Self->Is(
    $StateName3,
    'pending reminder',
    'StateID 3 has expected name'
);
$Self->Is(
    $TranslationsDE{ $StateName3 },
    'warten zur Erinnerung',
    'StateID 3 has expected translation (de)'
);
$Self->Is(
    $StateTypeID3,
    '4',
    'StateID 3 has expected state type id'
);
$Self->Is(
    $StateTypeName3,
    'pending reminder',
    'StateID 3 has expected state type name'
);
$Self->Is(
    $TranslationsDE{ $StateTypeName3 },
    'warten zur Erinnerung',
    'StateID 3 has expected translation for state type (de)'
);


## prepare test tickets ##
# first ticket
my $TicketID1 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => 1,
    Lock           => 'unlock',
    PriorityID     => 1,
    StateID        => $StateID1,
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
# second ticket
my $TicketID2 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => 1,
    Lock           => 'unlock',
    PriorityID     => 1,
    StateID        => $StateID2,
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
# third ticket
my $TicketID3 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => 1,
    Lock           => 'unlock',
    PriorityID     => 1,
    StateID        => $StateID3,
    TypeID         => 1,
    OrganisationID => 1,
    ContactID      => 1,
    OwnerID        => 1,
    ResponsibleID  => 1,
    UserID         => 1
);
$Self->True(
    $TicketID3,
    'Created third ticket'
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Ticket'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field StateID / Operator EQ / Value $StateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateID',
                    Operator => 'EQ',
                    Value    => $StateID2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field StateID / Operator NE / Value $StateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateID',
                    Operator => 'NE',
                    Value    => $StateID2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field StateID / Operator IN / Value [$StateID1,$StateID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateID',
                    Operator => 'IN',
                    Value    => [$StateID1,$StateID3]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID3]
    },
    {
        Name     => 'Search: Field StateID / Operator !IN / Value [$StateID1,$StateID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateID',
                    Operator => '!IN',
                    Value    => [$StateID1,$StateID3]
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field StateID / Operator LT / Value $StateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateID',
                    Operator => 'LT',
                    Value    => $StateID2
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: Field StateID / Operator GT / Value $StateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateID',
                    Operator => 'GT',
                    Value    => $StateID2
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field StateID / Operator LTE / Value $StateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateID',
                    Operator => 'LTE',
                    Value    => $StateID2
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2]
    },
    {
        Name     => 'Search: Field StateID / Operator GTE / Value $StateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateID',
                    Operator => 'GTE',
                    Value    => $StateID2
                }
            ]
        },
        Expected => [$TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field State / Operator EQ / Value $StateName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'State',
                    Operator => 'EQ',
                    Value    => $StateName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field State / Operator NE / Value $StateName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'State',
                    Operator => 'NE',
                    Value    => $StateName2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field State / Operator IN / Value [$StateName1,$StateName3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'State',
                    Operator => 'IN',
                    Value    => [$StateName1,$StateName3]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID3]
    },
    {
        Name     => 'Search: Field State / Operator !IN / Value [$StateName1,$StateName3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'State',
                    Operator => '!IN',
                    Value    => [$StateName1,$StateName3]
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field State / Operator STARTSWITH / Value $StateName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'State',
                    Operator => 'STARTSWITH',
                    Value    => $StateName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field State / Operator STARTSWITH / Value substr($StateName3,0,4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'State',
                    Operator => 'STARTSWITH',
                    Value    => substr($StateName3,0,4)
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field State / Operator ENDSWITH / Value $StateName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'State',
                    Operator => 'ENDSWITH',
                    Value    => $StateName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field State / Operator ENDSWITH / Value substr($StateName3,-4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'State',
                    Operator => 'ENDSWITH',
                    Value    => substr($StateName3,-4)
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field State / Operator CONTAINS / Value $StateName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'State',
                    Operator => 'CONTAINS',
                    Value    => $StateName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field State / Operator CONTAINS / Value substr($StateName3,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'State',
                    Operator => 'CONTAINS',
                    Value    => substr($StateName3,2,-2)
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field State / Operator LIKE / Value $StateName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'State',
                    Operator => 'LIKE',
                    Value    => $StateName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field StateTypeID / Operator EQ / Value $StateTypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateTypeID',
                    Operator => 'EQ',
                    Value    => $StateTypeID2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field StateTypeID / Operator NE / Value $StateTypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateTypeID',
                    Operator => 'NE',
                    Value    => $StateTypeID2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field StateTypeID / Operator IN / Value [$StateTypeID1,$StateTypeID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateTypeID',
                    Operator => 'IN',
                    Value    => [$StateTypeID1,$StateTypeID3]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID3]
    },
    {
        Name     => 'Search: Field StateTypeID / Operator !IN / Value [$StateTypeID1,$StateTypeID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateTypeID',
                    Operator => '!IN',
                    Value    => [$StateTypeID1,$StateTypeID3]
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field StateTypeID / Operator LT / Value $StateTypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateTypeID',
                    Operator => 'LT',
                    Value    => $StateTypeID2
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: Field StateTypeID / Operator GT / Value $StateTypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateTypeID',
                    Operator => 'GT',
                    Value    => $StateTypeID2
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field StateTypeID / Operator LTE / Value $StateTypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateTypeID',
                    Operator => 'LTE',
                    Value    => $StateTypeID2
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2]
    },
    {
        Name     => 'Search: Field StateTypeID / Operator GTE / Value $StateTypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateTypeID',
                    Operator => 'GTE',
                    Value    => $StateTypeID2
                }
            ]
        },
        Expected => [$TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field StateType / Operator EQ / Value $StateTypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateType',
                    Operator => 'EQ',
                    Value    => $StateTypeName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field StateType / Operator NE / Value $StateTypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateType',
                    Operator => 'NE',
                    Value    => $StateTypeName2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field StateType / Operator IN / Value [$StateTypeName1,$StateTypeName3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateType',
                    Operator => 'IN',
                    Value    => [$StateTypeName1,$StateTypeName3]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID3]
    },
    {
        Name     => 'Search: Field StateType / Operator !IN / Value [$StateTypeName1,$StateTypeName3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'State',
                    Operator => '!IN',
                    Value    => [$StateName1,$StateName3]
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field StateType / Operator STARTSWITH / Value $StateTypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateType',
                    Operator => 'STARTSWITH',
                    Value    => $StateTypeName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field StateType / Operator STARTSWITH / Value substr($StateTypeName3,0,4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateType',
                    Operator => 'STARTSWITH',
                    Value    => substr($StateTypeName3,0,4)
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field StateType / Operator ENDSWITH / Value $StateTypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateType',
                    Operator => 'ENDSWITH',
                    Value    => $StateTypeName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field StateType / Operator ENDSWITH / Value substr($StateTypeName3,-4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateType',
                    Operator => 'ENDSWITH',
                    Value    => substr($StateTypeName3,-4)
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field StateType / Operator CONTAINS / Value $StateTypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateType',
                    Operator => 'CONTAINS',
                    Value    => $StateTypeName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field StateType / Operator CONTAINS / Value substr($StateTypeName3,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateType',
                    Operator => 'CONTAINS',
                    Value    => substr($StateTypeName3,2,-2)
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field StateType / Operator LIKE / Value $StateTypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateType',
                    Operator => 'LIKE',
                    Value    => $StateTypeName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    ## special handling StateType 'Open' and 'Closed'
    {
        Name     => 'Search: Field StateType / Operator EQ / Value Open',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateType',
                    Operator => 'EQ',
                    Value    => 'Open'
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => 'Search: Field StateType / Operator EQ / Value Closed',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateType',
                    Operator => 'EQ',
                    Value    => 'Closed'
                }
            ]
        },
        Expected => []
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
        Name     => 'Sort: Field StateID',
        Sort     => [
            {
                Field => 'StateID'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field StateID / Direction ascending',
        Sort     => [
            {
                Field     => 'StateID',
                Direction => 'ascending'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field StateID / Direction descending',
        Sort     => [
            {
                Field     => 'StateID',
                Direction => 'descending'
            }
        ],
        Expected => [$TicketID3, $TicketID2, $TicketID1]
    },
    {
        Name     => 'Sort: Field State',
        Sort     => [
            {
                Field => 'State'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field State / Direction ascending',
        Sort     => [
            {
                Field     => 'State',
                Direction => 'ascending'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field State / Direction descending',
        Sort     => [
            {
                Field     => 'State',
                Direction => 'descending'
            }
        ],
        Expected => [$TicketID3, $TicketID2, $TicketID1]
    },
    {
        Name     => 'Sort: Field State / Language de',
        Sort     => [
            {
                Field => 'State'
            }
        ],
        Language => 'de',
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field State / Direction ascending / Language de',
        Sort     => [
            {
                Field     => 'State',
                Direction => 'ascending'
            }
        ],
        Language => 'de',
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field State / Direction descending / Language de',
        Sort     => [
            {
                Field     => 'State',
                Direction => 'descending'
            }
        ],
        Language => 'de',
        Expected => [$TicketID3, $TicketID2, $TicketID1]
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
