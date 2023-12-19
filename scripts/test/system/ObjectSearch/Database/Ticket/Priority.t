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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Ticket::Priority';

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
        PriorityID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','GT','GTE','LT','LTE'],
            ValueType    => 'NUMERIC'
        },
        Priority => {
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
            Field    => 'PriorityID',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'PriorityID',
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
            Field    => 'PriorityID',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'PriorityID',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field PriorityID / Operator EQ',
        Search       => {
            Field    => 'PriorityID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.ticket_priority_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field PriorityID / Operator NE',
        Search       => {
            Field    => 'PriorityID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.ticket_priority_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field PriorityID / Operator IN',
        Search       => {
            Field    => 'PriorityID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.ticket_priority_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field PriorityID / Operator !IN',
        Search       => {
            Field    => 'PriorityID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.ticket_priority_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field PriorityID / Operator LT',
        Search       => {
            Field    => 'PriorityID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.ticket_priority_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field PriorityID / Operator GT',
        Search       => {
            Field    => 'PriorityID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.ticket_priority_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field PriorityID / Operator LTE',
        Search       => {
            Field    => 'PriorityID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.ticket_priority_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field PriorityID / Operator GTE',
        Search       => {
            Field    => 'PriorityID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.ticket_priority_id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Priority / Operator EQ',
        Search       => {
            Field    => 'Priority',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_priority tp ON tp.id = st.ticket_priority_id'
            ],
            'Where' => [
                'tp.name = \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Priority / Operator NE',
        Search       => {
            Field    => 'Priority',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_priority tp ON tp.id = st.ticket_priority_id'
            ],
            'Where' => [
                'tp.name != \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Priority / Operator IN',
        Search       => {
            Field    => 'Priority',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_priority tp ON tp.id = st.ticket_priority_id'
            ],
            'Where' => [
                'tp.name IN (\'Test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Priority / Operator !IN',
        Search       => {
            Field    => 'Priority',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_priority tp ON tp.id = st.ticket_priority_id'
            ],
            'Where' => [
                'tp.name NOT IN (\'Test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Priority / Operator STARTSWITH',
        Search       => {
            Field    => 'Priority',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_priority tp ON tp.id = st.ticket_priority_id'
            ],
            'Where' => [
                'tp.name LIKE \'Test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Priority / Operator ENDSWITH',
        Search       => {
            Field    => 'Priority',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_priority tp ON tp.id = st.ticket_priority_id'
            ],
            'Where' => [
                'tp.name LIKE \'%Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Priority / Operator CONTAINS',
        Search       => {
            Field    => 'Priority',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_priority tp ON tp.id = st.ticket_priority_id'
            ],
            'Where' => [
                'tp.name LIKE \'%Test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Priority / Operator LIKE',
        Search       => {
            Field    => 'Priority',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_priority tp ON tp.id = st.ticket_priority_id'
            ],
            'Where' => [
                'tp.name LIKE \'Test\''
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
        Name      => 'Sort: Attribute "PriorityID"',
        Attribute => 'PriorityID',
        Expected  => {
            'Join'    => [],
            'OrderBy' => [
                'st.ticket_priority_id'
            ],
            'Select'  => [
                'st.ticket_priority_id'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Priority"',
        Attribute => 'Priority',
        Expected  => {
            'Join'    => [
                'INNER JOIN ticket_priority tp ON tp.id = st.ticket_priority_id',
                'LEFT OUTER JOIN translation_pattern tlp0 ON tlp0.value = tp.name',
                'LEFT OUTER JOIN translation_language tl0 ON tl0.pattern_id = tlp0.id AND tl0.language = \'en\''
            ],
            'OrderBy' => [
                'TranslatePriority'
            ],
            'Select'  => [
                'LOWER(COALESCE(tl0.value, tp.name)) AS TranslatePriority'
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

## prepare priority mapping
my $PriorityID1 = 1;
my $PriorityID2 = 2;
my $PriorityID3 = 3;
my $PriorityName1 = $Kernel::OM->Get('Priority')->PriorityLookup(
    PriorityID => $PriorityID1
);
$Self->Is(
    $PriorityName1,
    '5 very low',
    'PriorityID 1 has expected name'
);
$Self->Is(
    $TranslationsDE{ $PriorityName1 },
    '5 sehr niedrig',
    'PriorityID 1 has expected translation (de)'
);
my $PriorityName2 = $Kernel::OM->Get('Priority')->PriorityLookup(
    PriorityID => $PriorityID2
);
$Self->Is(
    $PriorityName2,
    '4 low',
    'PriorityID 2 has expected name'
);
$Self->Is(
    $TranslationsDE{ $PriorityName2 },
    '4 niedrig',
    'PriorityID 2 has expected translation (de)'
);
my $PriorityName3 = $Kernel::OM->Get('Priority')->PriorityLookup(
    PriorityID => $PriorityID3
);
$Self->Is(
    $PriorityName3,
    '3 normal',
    'PriorityID 3 has expected name'
);
$Self->Is(
    $TranslationsDE{ $PriorityName3 },
    '3 normal',
    'PriorityID 3 has expected translation (de)'
);

## prepare test tickets ##
# first ticket
my $TicketID1 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => 1,
    Lock           => 'unlock',
    PriorityID     => $PriorityID1,
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
# second ticket
my $TicketID2 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => 1,
    Lock           => 'unlock',
    PriorityID     => $PriorityID2,
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
# third ticket
my $TicketID3 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => 1,
    Lock           => 'unlock',
    PriorityID     => $PriorityID3,
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
    'Created third ticket'
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Ticket'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field PriorityID / Operator EQ / Value $PriorityID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'PriorityID',
                    Operator => 'EQ',
                    Value    => $PriorityID2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field PriorityID / Operator NE / Value $PriorityID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'PriorityID',
                    Operator => 'NE',
                    Value    => $PriorityID2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field PriorityID / Operator IN / Value [$PriorityID1,$PriorityID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'PriorityID',
                    Operator => 'IN',
                    Value    => [$PriorityID1,$PriorityID3]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID3]
    },
    {
        Name     => 'Search: Field PriorityID / Operator !IN / Value [$PriorityID1,$PriorityID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'PriorityID',
                    Operator => '!IN',
                    Value    => [$PriorityID1,$PriorityID3]
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field PriorityID / Operator LT / Value $PriorityID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'PriorityID',
                    Operator => 'LT',
                    Value    => $PriorityID2
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: Field PriorityID / Operator GT / Value $PriorityID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'PriorityID',
                    Operator => 'GT',
                    Value    => $PriorityID2
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field PriorityID / Operator LTE / Value $PriorityID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'PriorityID',
                    Operator => 'LTE',
                    Value    => $PriorityID2
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2]
    },
    {
        Name     => 'Search: Field PriorityID / Operator GTE / Value $PriorityID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'PriorityID',
                    Operator => 'GTE',
                    Value    => $PriorityID2
                }
            ]
        },
        Expected => [$TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field Priority / Operator EQ / Value $PriorityName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Priority',
                    Operator => 'EQ',
                    Value    => $PriorityName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Priority / Operator NE / Value $PriorityName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Priority',
                    Operator => 'NE',
                    Value    => $PriorityName2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field Priority / Operator IN / Value [$PriorityName1,$PriorityName3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Priority',
                    Operator => 'IN',
                    Value    => [$PriorityName1,$PriorityName3]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID3]
    },
    {
        Name     => 'Search: Field Priority / Operator !IN / Value [$PriorityName1,$PriorityName3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Priority',
                    Operator => '!IN',
                    Value    => [$PriorityName1,$PriorityName3]
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Priority / Operator STARTSWITH / Value $PriorityName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Priority',
                    Operator => 'STARTSWITH',
                    Value    => $PriorityName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Priority / Operator STARTSWITH / Value substr($PriorityName2,0,4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Priority',
                    Operator => 'STARTSWITH',
                    Value    => substr($PriorityName2,0,4)
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Priority / Operator ENDSWITH / Value $PriorityName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Priority',
                    Operator => 'ENDSWITH',
                    Value    => $PriorityName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Priority / Operator ENDSWITH / Value substr($PriorityName2,-5)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Priority',
                    Operator => 'ENDSWITH',
                    Value    => substr($PriorityName2,-5)
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Priority / Operator CONTAINS / Value $PriorityName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Priority',
                    Operator => 'CONTAINS',
                    Value    => $PriorityName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Priority / Operator CONTAINS / Value substr($PriorityName3,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Priority',
                    Operator => 'CONTAINS',
                    Value    => substr($PriorityName3,2,-2)
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field Priority / Operator LIKE / Value $PriorityName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Priority',
                    Operator => 'LIKE',
                    Value    => $PriorityName2
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
        Name     => 'Sort: Field PriorityID',
        Sort     => [
            {
                Field => 'PriorityID'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field PriorityID / Direction ascending',
        Sort     => [
            {
                Field     => 'PriorityID',
                Direction => 'ascending'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field PriorityID / Direction descending',
        Sort     => [
            {
                Field     => 'PriorityID',
                Direction => 'descending'
            }
        ],
        Expected => [$TicketID3, $TicketID2, $TicketID1]
    },
    {
        Name     => 'Sort: Field Priority',
        Sort     => [
            {
                Field => 'Priority'
            }
        ],
        Expected => [$TicketID3, $TicketID2, $TicketID1]
    },
    {
        Name     => 'Sort: Field Priority / Direction ascending',
        Sort     => [
            {
                Field     => 'Priority',
                Direction => 'ascending'
            }
        ],
        Expected => [$TicketID3, $TicketID2, $TicketID1]
    },
    {
        Name     => 'Sort: Field Priority / Direction descending',
        Sort     => [
            {
                Field     => 'Priority',
                Direction => 'descending'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field Priority / Language de',
        Sort     => [
            {
                Field => 'Priority'
            }
        ],
        Language => 'de',
        Expected => [$TicketID3, $TicketID2, $TicketID1]
    },
    {
        Name     => 'Sort: Field Priority / Direction ascending / Language de',
        Sort     => [
            {
                Field     => 'Priority',
                Direction => 'ascending'
            }
        ],
        Language => 'de',
        Expected => [$TicketID3, $TicketID2, $TicketID1]
    },
    {
        Name     => 'Sort: Field Priority / Direction descending / Language de',
        Sort     => [
            {
                Field     => 'Priority',
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
