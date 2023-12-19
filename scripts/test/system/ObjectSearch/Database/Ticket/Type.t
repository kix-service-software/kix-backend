# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Ticket::Type';

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
        TypeID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','GT','GTE','LT','LTE'],
            ValueType    => 'NUMERIC'
        },
        Type => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
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
            Field    => 'TypeID',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'TypeID',
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
            Field    => 'TypeID',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'TypeID',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field TypeID / Operator EQ',
        Search       => {
            Field    => 'TypeID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.type_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TypeID / Operator NE',
        Search       => {
            Field    => 'TypeID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.type_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TypeID / Operator IN',
        Search       => {
            Field    => 'TypeID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.type_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TypeID / Operator !IN',
        Search       => {
            Field    => 'TypeID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.type_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TypeID / Operator LT',
        Search       => {
            Field    => 'TypeID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.type_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TypeID / Operator GT',
        Search       => {
            Field    => 'TypeID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.type_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TypeID / Operator LTE',
        Search       => {
            Field    => 'TypeID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.type_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TypeID / Operator GTE',
        Search       => {
            Field    => 'TypeID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.type_id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Type / Operator EQ',
        Search       => {
            Field    => 'Type',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_type tt ON tt.id = st.type_id'
            ],
            'Where' => [
                'tt.name = \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Type / Operator NE',
        Search       => {
            Field    => 'Type',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_type tt ON tt.id = st.type_id'
            ],
            'Where' => [
                'tt.name != \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Type / Operator IN',
        Search       => {
            Field    => 'Type',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_type tt ON tt.id = st.type_id'
            ],
            'Where' => [
                'tt.name IN (\'Test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Type / Operator !IN',
        Search       => {
            Field    => 'Type',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_type tt ON tt.id = st.type_id'
            ],
            'Where' => [
                'tt.name NOT IN (\'Test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Type / Operator STARTSWITH',
        Search       => {
            Field    => 'Type',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_type tt ON tt.id = st.type_id'
            ],
            'Where' => [
                'tt.name LIKE \'Test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Type / Operator ENDSWITH',
        Search       => {
            Field    => 'Type',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_type tt ON tt.id = st.type_id'
            ],
            'Where' => [
                'tt.name LIKE \'%Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Type / Operator CONTAINS',
        Search       => {
            Field    => 'Type',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_type tt ON tt.id = st.type_id'
            ],
            'Where' => [
                'tt.name LIKE \'%Test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Type / Operator LIKE',
        Search       => {
            Field    => 'Type',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_type tt ON tt.id = st.type_id'
            ],
            'Where' => [
                'tt.name LIKE \'Test\''
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
        Name      => 'Sort: Attribute "TypeID"',
        Attribute => 'TypeID',
        Expected  => {
            'Join'    => [],
            'OrderBy' => [
                'st.type_id'
            ],
            'Select'  => [
                'st.type_id'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Type"',
        Attribute => 'Type',
        Expected  => {
            'Join'    => [
                'INNER JOIN ticket_type tt ON tt.id = st.type_id',
                'LEFT OUTER JOIN translation_pattern tlp0 ON tlp0.value = tt.name',
                'LEFT OUTER JOIN translation_language tl0 ON tl0.pattern_id = tlp0.id AND tl0.language = \'en\''
            ],
            'OrderBy' => [
                'TranslateType'
            ],
            'Select'  => [
                'LOWER(COALESCE(tl0.value, tt.name)) AS TranslateType'
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
my $TypeID1 = 1;
my $TypeID2 = 2;
my $TypeID3 = 3;
my $TypeName1 = $Kernel::OM->Get('Type')->TypeLookup(
    TypeID => $TypeID1
);
$Self->Is(
    $TypeName1,
    'Unclassified',
    'TypeID 1 has expected name'
);
$Self->Is(
    $TranslationsDE{ $TypeName1 },
    'Unklassifiziert',
    'TypeID 1 has expected translation (de)'
);
my $TypeName2 = $Kernel::OM->Get('Type')->TypeLookup(
    TypeID => $TypeID2
);
$Self->Is(
    $TypeName2,
    'Incident',
    'TypeID 2 has expected name'
);
$Self->Is(
    $TranslationsDE{ $TypeName2 },
    'Störung',
    'TypeID 2 has expected translation (de)'
);
my $TypeName3 = $Kernel::OM->Get('Type')->TypeLookup(
    TypeID => $TypeID3
);
$Self->Is(
    $TypeName3,
    'Service Request',
    'TypeID 3 has expected name'
);
$Self->Is(
    $TranslationsDE{ $TypeName3 },
    'Service Anfrage',
    'TypeID 3 has expected translation (de)'
);


## prepare test tickets ##
# first ticket
my $TicketID1 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => 1,
    Lock           => 'unlock',
    PriorityID     => 1,
    StateID        => 1,
    TypeID         => $TypeID1,
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
    StateID        => 1,
    TypeID         => $TypeID2,
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
    StateID        => 1,
    TypeID         => $TypeID3,
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
        Name     => 'Search: Field TypeID / Operator EQ / Value $TypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'TypeID',
                    Operator => 'EQ',
                    Value    => $TypeID2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field TypeID / Operator NE / Value $TypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'TypeID',
                    Operator => 'NE',
                    Value    => $TypeID2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field TypeID / Operator IN / Value [$TypeID1,$TypeID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'TypeID',
                    Operator => 'IN',
                    Value    => [$TypeID1,$TypeID3]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID3]
    },
    {
        Name     => 'Search: Field TypeID / Operator !IN / Value [$TypeID1,$TypeID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'TypeID',
                    Operator => '!IN',
                    Value    => [$TypeID1,$TypeID3]
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field TypeID / Operator LT / Value $TypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'TypeID',
                    Operator => 'LT',
                    Value    => $TypeID2
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: Field TypeID / Operator GT / Value $TypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'TypeID',
                    Operator => 'GT',
                    Value    => $TypeID2
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field TypeID / Operator LTE / Value $TypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'TypeID',
                    Operator => 'LTE',
                    Value    => $TypeID2
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2]
    },
    {
        Name     => 'Search: Field TypeID / Operator GTE / Value $TypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'TypeID',
                    Operator => 'GTE',
                    Value    => $TypeID2
                }
            ]
        },
        Expected => [$TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field Type / Operator EQ / Value $TypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Type',
                    Operator => 'EQ',
                    Value    => $TypeName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Type / Operator NE / Value $TypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Type',
                    Operator => 'NE',
                    Value    => $TypeName2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field Type / Operator IN / Value [$TypeName1,$TypeName3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Type',
                    Operator => 'IN',
                    Value    => [$TypeName1,$TypeName3]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID3]
    },
    {
        Name     => 'Search: Field Type / Operator !IN / Value [$TypeName1,$TypeName3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Type',
                    Operator => '!IN',
                    Value    => [$TypeName1,$TypeName3]
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Type / Operator STARTSWITH / Value $TypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Type',
                    Operator => 'STARTSWITH',
                    Value    => $TypeName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Type / Operator STARTSWITH / Value substr($TypeName2,0,4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Type',
                    Operator => 'STARTSWITH',
                    Value    => substr($TypeName2,0,4)
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Type / Operator ENDSWITH / Value $TypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Type',
                    Operator => 'ENDSWITH',
                    Value    => $TypeName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Type / Operator ENDSWITH / Value substr($TypeName2,-4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Type',
                    Operator => 'ENDSWITH',
                    Value    => substr($TypeName2,-4)
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Type / Operator CONTAINS / Value $TypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Type',
                    Operator => 'CONTAINS',
                    Value    => $TypeName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Type / Operator CONTAINS / Value substr($TypeName2,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Type',
                    Operator => 'CONTAINS',
                    Value    => substr($TypeName2,2,-2)
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Type / Operator LIKE / Value $TypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Type',
                    Operator => 'LIKE',
                    Value    => $TypeName2
                }
            ]
        },
        Expected => [$TicketID2]
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
        Name     => 'Sort: Field TypeID',
        Sort     => [
            {
                Field => 'TypeID'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field TypeID / Direction ascending',
        Sort     => [
            {
                Field     => 'TypeID',
                Direction => 'ascending'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field TypeID / Direction descending',
        Sort     => [
            {
                Field     => 'TypeID',
                Direction => 'descending'
            }
        ],
        Expected => [$TicketID3, $TicketID2, $TicketID1]
    },
    {
        Name     => 'Sort: Field Type',
        Sort     => [
            {
                Field => 'Type'
            }
        ],
        Expected => [$TicketID2, $TicketID3, $TicketID1]
    },
    {
        Name     => 'Sort: Field Type / Direction ascending',
        Sort     => [
            {
                Field     => 'Type',
                Direction => 'ascending'
            }
        ],
        Expected => [$TicketID2, $TicketID3, $TicketID1]
    },
    {
        Name     => 'Sort: Field Type / Direction descending',
        Sort     => [
            {
                Field     => 'Type',
                Direction => 'descending'
            }
        ],
        Expected => [$TicketID1, $TicketID3, $TicketID2]
    },
    {
        Name     => 'Sort: Field Type / Language de',
        Sort     => [
            {
                Field => 'Type'
            }
        ],
        Language => 'de',
        Expected => [$TicketID3, $TicketID2, $TicketID1]
    },
    {
        Name     => 'Sort: Field Type / Direction ascending / Language de',
        Sort     => [
            {
                Field     => 'Type',
                Direction => 'ascending'
            }
        ],
        Language => 'de',
        Expected => [$TicketID3, $TicketID2, $TicketID1]
    },
    {
        Name     => 'Sort: Field Type / Direction descending / Language de',
        Sort     => [
            {
                Field     => 'Type',
                Direction => 'descending'
            }
        ],
        Language => 'de',
        Expected => [$TicketID1, $TicketID2, $TicketID3]
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
