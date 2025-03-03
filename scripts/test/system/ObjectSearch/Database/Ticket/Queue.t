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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Ticket::Queue';

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
        QueueID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','GT','GTE','LT','LTE'],
            ValueType    => 'NUMERIC'
        },
        Queue => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        MyQueues => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ'],
            ValueType    => 'NUMERIC'
        }
    },
    'GetSupportedAttributes provides expected data'
);

# begin transaction on database
$Helper->BeginWork();

# init queue mapping
my $QueueID1 = 1;
my $QueueID2 = 2;
my $QueueID3 = 3;

# set 'MyQueues' for admin user
$Kernel::OM->Get('User')->SetPreferences(
    Key    => 'MyQueues',
    Value  => [ $QueueID1 ],
    UserID => 1
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
            Field    => 'QueueID',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'QueueID',
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
            Field    => 'QueueID',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'QueueID',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field QueueID / Operator EQ',
        Search       => {
            Field    => 'QueueID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.queue_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field QueueID / Operator NE',
        Search       => {
            Field    => 'QueueID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.queue_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field QueueID / Operator IN',
        Search       => {
            Field    => 'QueueID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.queue_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field QueueID / Operator !IN',
        Search       => {
            Field    => 'QueueID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.queue_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field QueueID / Operator LT',
        Search       => {
            Field    => 'QueueID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.queue_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field QueueID / Operator GT',
        Search       => {
            Field    => 'QueueID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.queue_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field QueueID / Operator LTE',
        Search       => {
            Field    => 'QueueID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.queue_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field QueueID / Operator GTE',
        Search       => {
            Field    => 'QueueID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.queue_id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Queue / Operator EQ',
        Search       => {
            Field    => 'Queue',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN queue tq ON tq.id = st.queue_id'
            ],
            'Where' => [
                'tq.name = \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Queue / Operator NE',
        Search       => {
            Field    => 'Queue',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN queue tq ON tq.id = st.queue_id'
            ],
            'Where' => [
                'tq.name != \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Queue / Operator IN',
        Search       => {
            Field    => 'Queue',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN queue tq ON tq.id = st.queue_id'
            ],
            'Where' => [
                'tq.name IN (\'Test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Queue / Operator !IN',
        Search       => {
            Field    => 'Queue',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN queue tq ON tq.id = st.queue_id'
            ],
            'Where' => [
                'tq.name NOT IN (\'Test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Queue / Operator STARTSWITH',
        Search       => {
            Field    => 'Queue',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN queue tq ON tq.id = st.queue_id'
            ],
            'Where' => [
                'tq.name LIKE \'Test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Queue / Operator ENDSWITH',
        Search       => {
            Field    => 'Queue',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN queue tq ON tq.id = st.queue_id'
            ],
            'Where' => [
                'tq.name LIKE \'%Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Queue / Operator CONTAINS',
        Search       => {
            Field    => 'Queue',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN queue tq ON tq.id = st.queue_id'
            ],
            'Where' => [
                'tq.name LIKE \'%Test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Queue / Operator LIKE',
        Search       => {
            Field    => 'Queue',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN queue tq ON tq.id = st.queue_id'
            ],
            'Where' => [
                'tq.name LIKE \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field MyQueues / Operator EQ / Value 1',
        Search       => {
            Field    => 'MyQueues',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.queue_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field MyQueues / Operator EQ / Value 0',
        Search       => {
            Field    => 'MyQueues',
            Operator => 'EQ',
            Value    => '0'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.queue_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field MyQueues / Operator EQ / Value [0,1]',
        Search       => {
            Field    => 'MyQueues',
            Operator => 'EQ',
            Value    => ['0','1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                '(st.queue_id NOT IN (1) OR st.queue_id IN (1))'
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

# test with user that has no set 'MyQueues' preference
my @SearchTestsSpecial = (
    {
        Name         => 'Search: valid search / Field MyQueues / Operator EQ / Value 1 / Preference not set',
        Search       => {
            Field    => 'MyQueues',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                '1=0'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field MyQueues / Operator EQ / Value 0 / Preference not set',
        Search       => {
            Field    => 'MyQueues',
            Operator => 'EQ',
            Value    => '0'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                '1=1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field MyQueues / Operator EQ / Value [0,1] / Preference not set',
        Search       => {
            Field    => 'MyQueues',
            Operator => 'EQ',
            Value    => ['0','1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                '(1=1 OR 1=0)'
            ]
        }
    }
);
for my $Test ( @SearchTestsSpecial ) {
    my $Result = $AttributeObject->Search(
        Search       => $Test->{Search},
        BoolOperator => 'AND',
        UserID       => 2,
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
        Name      => 'Sort: Attribute "QueueID"',
        Attribute => 'QueueID',
        Expected  => {
            'Join'    => [],
            'OrderBy' => [
                'st.queue_id'
            ],
            'Select'  => [
                'st.queue_id'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Queue"',
        Attribute => 'Queue',
        Expected  => {
            'Join'    => [
                'INNER JOIN queue tq ON tq.id = st.queue_id',
                'LEFT OUTER JOIN translation_pattern tlp0 ON tlp0.value = tq.name',
                'LEFT OUTER JOIN translation_language tl0 ON tl0.pattern_id = tlp0.id AND tl0.language = \'en\''
            ],
            'OrderBy' => [
                'TranslateQueue'
            ],
            'Select'  => [
                'LOWER(COALESCE(tl0.value, tq.name)) AS TranslateQueue'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "MyQueues" is not sortable',
        Attribute => 'MyQueues',
        Expected  => undef
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

# load translations for given language
my @Translations = $Kernel::OM->Get('Translation')->TranslationList();
my %TranslationsDE;
for my $Translation ( @Translations ) {
    $TranslationsDE{ $Translation->{Pattern} } = $Translation->{Languages}->{'de'};
}

## prepare queue mapping
my $QueueName1 = $Kernel::OM->Get('Queue')->QueueLookup(
    QueueID => $QueueID1
);
$Self->Is(
    $QueueName1,
    'Service Desk',
    'QueueID 1 has expected name'
);
$Self->Is(
    $TranslationsDE{ $QueueName1 },
    undef,
    'QueueID 1 has expected translation (de)'
);
my $QueueName2 = $Kernel::OM->Get('Queue')->QueueLookup(
    QueueID => $QueueID2
);
$Self->Is(
    $QueueName2,
    'Service Desk::Monitoring',
    'QueueID 2 has expected name'
);
$Self->Is(
    $TranslationsDE{ $QueueName2 },
    undef,
    'QueueID 2 has expected translation (de)'
);
my $QueueName3 = $Kernel::OM->Get('Queue')->QueueLookup(
    QueueID => $QueueID3
);
$Self->Is(
    $QueueName3,
    'Junk',
    'QueueID 3 has expected name'
);
$Self->Is(
    $TranslationsDE{ $QueueName3 },
    undef,
    'QueueID 3 has expected translation (de)'
);

# set 'MyQueues' for admin user
$Kernel::OM->Get('User')->SetPreferences(
    Key    => 'MyQueues',
    Value  => [ $QueueID1 ],
    UserID => 1
);

## prepare test tickets ##
# first ticket
my $TicketID1 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => $QueueID1,
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
# second ticket
my $TicketID2 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => $QueueID2,
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
# third ticket
my $TicketID3 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => $QueueID3,
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
    'Created third ticket'
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Ticket'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field QueueID / Operator EQ / Value $QueueID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'QueueID',
                    Operator => 'EQ',
                    Value    => $QueueID2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field QueueID / Operator NE / Value $QueueID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'QueueID',
                    Operator => 'NE',
                    Value    => $QueueID2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field QueueID / Operator IN / Value [$QueueID1,$QueueID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'QueueID',
                    Operator => 'IN',
                    Value    => [$QueueID1,$QueueID3]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID3]
    },
    {
        Name     => 'Search: Field QueueID / Operator !IN / Value [$QueueID1,$QueueID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'QueueID',
                    Operator => '!IN',
                    Value    => [$QueueID1,$QueueID3]
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field QueueID / Operator LT / Value $QueueID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'QueueID',
                    Operator => 'LT',
                    Value    => $QueueID2
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: Field QueueID / Operator GT / Value $QueueID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'QueueID',
                    Operator => 'GT',
                    Value    => $QueueID2
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field QueueID / Operator LTE / Value $QueueID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'QueueID',
                    Operator => 'LTE',
                    Value    => $QueueID2
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2]
    },
    {
        Name     => 'Search: Field QueueID / Operator GTE / Value $QueueID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'QueueID',
                    Operator => 'GTE',
                    Value    => $QueueID2
                }
            ]
        },
        Expected => [$TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field Queue / Operator EQ / Value $QueueName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Queue',
                    Operator => 'EQ',
                    Value    => $QueueName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Queue / Operator NE / Value $QueueName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Queue',
                    Operator => 'NE',
                    Value    => $QueueName2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field Queue / Operator IN / Value [$QueueName1,$QueueName3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Queue',
                    Operator => 'IN',
                    Value    => [$QueueName1,$QueueName3]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID3]
    },
    {
        Name     => 'Search: Field Queue / Operator !IN / Value [$QueueName1,$QueueName3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Queue',
                    Operator => '!IN',
                    Value    => [$QueueName1,$QueueName3]
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Queue / Operator STARTSWITH / Value $QueueName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Queue',
                    Operator => 'STARTSWITH',
                    Value    => $QueueName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Queue / Operator STARTSWITH / Value substr($QueueName2,0,4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Queue',
                    Operator => 'STARTSWITH',
                    Value    => substr($QueueName2,0,4)
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: Field Queue / Operator ENDSWITH / Value $QueueName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Queue',
                    Operator => 'ENDSWITH',
                    Value    => $QueueName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Queue / Operator ENDSWITH / Value substr($QueueName2,-5)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Queue',
                    Operator => 'ENDSWITH',
                    Value    => substr($QueueName2,-5)
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Queue / Operator CONTAINS / Value $QueueName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Queue',
                    Operator => 'CONTAINS',
                    Value    => $QueueName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Queue / Operator CONTAINS / Value substr($QueueName2,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Queue',
                    Operator => 'CONTAINS',
                    Value    => substr($QueueName2,2,-2)
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Queue / Operator LIKE / Value $QueueName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Queue',
                    Operator => 'LIKE',
                    Value    => $QueueName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field MyQueues / Operator EQ / Value 1',
        Search   => {
            'AND' => [
                {
                    Field    => 'MyQueues',
                    Operator => 'EQ',
                    Value    => 1
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: Field MyQueues / Operator EQ / Value 0',
        Search   => {
            'AND' => [
                {
                    Field    => 'MyQueues',
                    Operator => 'EQ',
                    Value    => 0
                }
            ]
        },
        Expected => [$TicketID2,$TicketID3]
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
        Name     => 'Sort: Field QueueID',
        Sort     => [
            {
                Field => 'QueueID'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field QueueID / Direction ascending',
        Sort     => [
            {
                Field     => 'QueueID',
                Direction => 'ascending'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field QueueID / Direction descending',
        Sort     => [
            {
                Field     => 'QueueID',
                Direction => 'descending'
            }
        ],
        Expected => [$TicketID3, $TicketID2, $TicketID1]
    },
    {
        Name     => 'Sort: Field Queue',
        Sort     => [
            {
                Field => 'Queue'
            }
        ],
        Expected => [$TicketID3, $TicketID1, $TicketID2]
    },
    {
        Name     => 'Sort: Field Queue / Direction ascending',
        Sort     => [
            {
                Field     => 'Queue',
                Direction => 'ascending'
            }
        ],
        Expected => [$TicketID3, $TicketID1, $TicketID2]
    },
    {
        Name     => 'Sort: Field Queue / Direction descending',
        Sort     => [
            {
                Field     => 'Queue',
                Direction => 'descending'
            }
        ],
        Expected => [$TicketID2, $TicketID1, $TicketID3]
    },
    {
        Name     => 'Sort: Field Queue / Language de',
        Sort     => [
            {
                Field => 'Queue'
            }
        ],
        Language => 'de',
        Expected => [$TicketID3, $TicketID1, $TicketID2]
    },
    {
        Name     => 'Sort: Field Queue / Direction ascending / Language de',
        Sort     => [
            {
                Field     => 'Queue',
                Direction => 'ascending'
            }
        ],
        Language => 'de',
        Expected => [$TicketID3, $TicketID1, $TicketID2]
    },
    {
        Name     => 'Sort: Field Queue / Direction descending / Language de',
        Sort     => [
            {
                Field     => 'Queue',
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
