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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Ticket::Lock';

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
        LockID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','GT','GTE','LT','LTE'],
            ValueType    => 'NUMERIC'
        },
        Lock => {
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
            Field    => 'LockID',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'LockID',
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
            Field    => 'LockID',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'LockID',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field LockID / Operator EQ',
        Search       => {
            Field    => 'LockID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.ticket_lock_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field LockID / Operator NE',
        Search       => {
            Field    => 'LockID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.ticket_lock_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field LockID / Operator IN',
        Search       => {
            Field    => 'LockID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.ticket_lock_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field LockID / Operator !IN',
        Search       => {
            Field    => 'LockID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.ticket_lock_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field LockID / Operator LT',
        Search       => {
            Field    => 'LockID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.ticket_lock_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field LockID / Operator GT',
        Search       => {
            Field    => 'LockID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.ticket_lock_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field LockID / Operator LTE',
        Search       => {
            Field    => 'LockID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.ticket_lock_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field LockID / Operator GTE',
        Search       => {
            Field    => 'LockID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.ticket_lock_id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Lock / Operator EQ',
        Search       => {
            Field    => 'Lock',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_lock_type tl ON tl.id = st.ticket_lock_id'
            ],
            'Where' => [
                'tl.name = \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Lock / Operator NE',
        Search       => {
            Field    => 'Lock',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_lock_type tl ON tl.id = st.ticket_lock_id'
            ],
            'Where' => [
                'tl.name != \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Lock / Operator IN',
        Search       => {
            Field    => 'Lock',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_lock_type tl ON tl.id = st.ticket_lock_id'
            ],
            'Where' => [
                'tl.name IN (\'Test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Lock / Operator !IN',
        Search       => {
            Field    => 'Lock',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_lock_type tl ON tl.id = st.ticket_lock_id'
            ],
            'Where' => [
                'tl.name NOT IN (\'Test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Lock / Operator STARTSWITH',
        Search       => {
            Field    => 'Lock',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_lock_type tl ON tl.id = st.ticket_lock_id'
            ],
            'Where' => [
                'tl.name LIKE \'Test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Lock / Operator ENDSWITH',
        Search       => {
            Field    => 'Lock',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_lock_type tl ON tl.id = st.ticket_lock_id'
            ],
            'Where' => [
                'tl.name LIKE \'%Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Lock / Operator CONTAINS',
        Search       => {
            Field    => 'Lock',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_lock_type tl ON tl.id = st.ticket_lock_id'
            ],
            'Where' => [
                'tl.name LIKE \'%Test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Lock / Operator LIKE',
        Search       => {
            Field    => 'Lock',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_lock_type tl ON tl.id = st.ticket_lock_id'
            ],
            'Where' => [
                'tl.name LIKE \'Test\''
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
        Name      => 'Sort: Attribute "LockID"',
        Attribute => 'LockID',
        Expected  => {
            'Join'    => [],
            'OrderBy' => [
                'st.ticket_lock_id'
            ],
            'Select'  => [
                'st.ticket_lock_id'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Lock"',
        Attribute => 'Lock',
        Expected  => {
            'Join'    => [
                'INNER JOIN ticket_lock_type tl ON tl.id = st.ticket_lock_id',
                'LEFT OUTER JOIN translation_pattern tlp0 ON tlp0.value = tl.name',
                'LEFT OUTER JOIN translation_language tl0 ON tl0.pattern_id = tlp0.id AND tl0.language = \'en\''
            ],
            'OrderBy' => [
                'TranslateLock'
            ],
            'Select'  => [
                'LOWER(COALESCE(tl0.value, tl.name)) AS TranslateLock'
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
my $LockID1 = 1;
my $LockID2 = 2;
my $LockName1 = $Kernel::OM->Get('Lock')->LockLookup(
    LockID => $LockID1
);
$Self->Is(
    $LockName1,
    'unlock',
    'LockID 1 has expected name'
);
$Self->Is(
    $TranslationsDE{ $LockName1 },
    'entsperrt',
    'LockID 1 has expected translation (de)'
);
my $LockName2 = $Kernel::OM->Get('Lock')->LockLookup(
    LockID => $LockID2
);
$Self->Is(
    $LockName2,
    'lock',
    'LockID 2 has expected name'
);
$Self->Is(
    $TranslationsDE{ $LockName2 },
    'gesperrt',
    'LockID 2 has expected translation (de)'
);


## prepare test tickets ##
# first ticket
my $TicketID1 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => 1,
    LockID         => $LockID1,
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
# second ticket
my $TicketID2 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => 1,
    LockID         => $LockID2,
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
# third ticket
my $TicketID3 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => 1,
    LockID         => $LockID1,
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
    'Created third ticket'
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Ticket'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field LockID / Operator EQ / Value $LockID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'LockID',
                    Operator => 'EQ',
                    Value    => $LockID2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field LockID / Operator NE / Value $LockID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'LockID',
                    Operator => 'NE',
                    Value    => $LockID2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field LockID / Operator IN / Value [$LockID1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'LockID',
                    Operator => 'IN',
                    Value    => [$LockID1]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID3]
    },
    {
        Name     => 'Search: Field LockID / Operator !IN / Value [$LockID1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'LockID',
                    Operator => '!IN',
                    Value    => [$LockID1]
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field LockID / Operator LT / Value $LockID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'LockID',
                    Operator => 'LT',
                    Value    => $LockID2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field LockID / Operator GT / Value $LockID1',
        Search   => {
            'AND' => [
                {
                    Field    => 'LockID',
                    Operator => 'GT',
                    Value    => $LockID1
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field LockID / Operator LTE / Value $LockID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'LockID',
                    Operator => 'LTE',
                    Value    => $LockID2
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2,$TicketID3]
    },
    {
        Name     => 'Search: Field LockID / Operator GTE / Value $LockID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'LockID',
                    Operator => 'GTE',
                    Value    => $LockID2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Lock / Operator EQ / Value $LockName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Lock',
                    Operator => 'EQ',
                    Value    => $LockName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Lock / Operator NE / Value $LockName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Lock',
                    Operator => 'NE',
                    Value    => $LockName2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field Lock / Operator IN / Value [$LockName1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Lock',
                    Operator => 'IN',
                    Value    => [$LockName1]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID3]
    },
    {
        Name     => 'Search: Field Lock / Operator !IN / Value [$LockName1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Lock',
                    Operator => '!IN',
                    Value    => [$LockName1]
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Lock / Operator STARTSWITH / Value $LockName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Lock',
                    Operator => 'STARTSWITH',
                    Value    => $LockName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Lock / Operator STARTSWITH / Value substr($LockName2,0,2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Lock',
                    Operator => 'STARTSWITH',
                    Value    => substr($LockName2,0,2)
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Lock / Operator ENDSWITH / Value $LockName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Lock',
                    Operator => 'ENDSWITH',
                    Value    => $LockName2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => 'Search: Field Lock / Operator ENDSWITH / Value substr($LockName1,-5)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Lock',
                    Operator => 'ENDSWITH',
                    Value    => substr($LockName1,-5)
                }
            ]
        },
        Expected => [$TicketID1, $TicketID3]
    },
    {
        Name     => 'Search: Field Lock / Operator CONTAINS / Value $LockName1',
        Search   => {
            'AND' => [
                {
                    Field    => 'Lock',
                    Operator => 'CONTAINS',
                    Value    => $LockName1
                }
            ]
        },
        Expected => [$TicketID1, $TicketID3]
    },
    {
        Name     => 'Search: Field Lock / Operator CONTAINS / Value substr($LockName1,1,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Lock',
                    Operator => 'CONTAINS',
                    Value    => substr($LockName1,1,-2)
                }
            ]
        },
        Expected => [$TicketID1, $TicketID3]
    },
    {
        Name     => 'Search: Field Lock / Operator LIKE / Value $LockName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Lock',
                    Operator => 'LIKE',
                    Value    => $LockName2
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
        Name     => 'Sort: Field LockID',
        Sort     => [
            {
                Field => 'LockID'
            }
        ],
        Expected => [$TicketID1, $TicketID3, $TicketID2]
    },
    {
        Name     => 'Sort: Field LockID / Direction ascending',
        Sort     => [
            {
                Field     => 'LockID',
                Direction => 'ascending'
            }
        ],
        Expected => [$TicketID1, $TicketID3, $TicketID2]
    },
    {
        Name     => 'Sort: Field LockID / Direction descending',
        Sort     => [
            {
                Field     => 'LockID',
                Direction => 'descending'
            }
        ],
        Expected => [$TicketID2, $TicketID1, $TicketID3]
    },
    {
        Name     => 'Sort: Field Lock',
        Sort     => [
            {
                Field => 'Lock'
            }
        ],
        Expected => [$TicketID2, $TicketID1, $TicketID3]
    },
    {
        Name     => 'Sort: Field Lock / Direction ascending',
        Sort     => [
            {
                Field     => 'Lock',
                Direction => 'ascending'
            }
        ],
        Expected => [$TicketID2, $TicketID1, $TicketID3]
    },
    {
        Name     => 'Sort: Field Lock / Direction descending',
        Sort     => [
            {
                Field     => 'Lock',
                Direction => 'descending'
            }
        ],
        Expected => [$TicketID1, $TicketID3, $TicketID2]
    },
    {
        Name     => 'Sort: Field Lock / Language de',
        Sort     => [
            {
                Field => 'Lock'
            }
        ],
        Language => 'de',
        Expected => [$TicketID1, $TicketID3, $TicketID2]
    },
    {
        Name     => 'Sort: Field Lock / Direction ascending / Language de',
        Sort     => [
            {
                Field     => 'Lock',
                Direction => 'ascending'
            }
        ],
        Language => 'de',
        Expected => [$TicketID1, $TicketID3, $TicketID2]
    },
    {
        Name     => 'Sort: Field Lock / Direction descending / Language de',
        Sort     => [
            {
                Field     => 'Lock',
                Direction => 'descending'
            }
        ],
        Language => 'de',
        Expected => [$TicketID2, $TicketID1, $TicketID3]
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
