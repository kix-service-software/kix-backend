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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Ticket::TicketID';

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
        TicketID => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType      => 'NUMERIC'
        },
        ID => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType      => 'NUMERIC'
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
            Field    => 'TicketID',
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
            Field    => 'TicketID',
            Operator => undef,
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'TicketID',
            Operator => 'Test',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field TicketID / Operator EQ',
        Search       => {
            Field    => 'TicketID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'st.id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TicketID / Operator NE',
        Search       => {
            Field    => 'TicketID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'st.id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TicketID / Operator IN',
        Search       => {
            Field    => 'TicketID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'st.id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TicketID / Operator !IN',
        Search       => {
            Field    => 'TicketID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'st.id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TicketID / Operator LT',
        Search       => {
            Field    => 'TicketID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'st.id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TicketID / Operator LTE',
        Search       => {
            Field    => 'TicketID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'st.id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TicketID / Operator GT',
        Search       => {
            Field    => 'TicketID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'st.id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TicketID / Operator GTE',
        Search       => {
            Field    => 'TicketID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'st.id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ID / Operator EQ',
        Search       => {
            Field    => 'ID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'st.id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ID / Operator NE',
        Search       => {
            Field    => 'ID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'st.id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ID / Operator IN',
        Search       => {
            Field    => 'ID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'st.id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ID / Operator !IN',
        Search       => {
            Field    => 'ID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'st.id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ID / Operator LT',
        Search       => {
            Field    => 'ID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'st.id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ID / Operator LTE',
        Search       => {
            Field    => 'ID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'st.id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ID / Operator GT',
        Search       => {
            Field    => 'ID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'st.id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ID / Operator GTE',
        Search       => {
            Field    => 'ID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'st.id >= 1'
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
        Name      => 'Sort: Attribute "TicketID"',
        Attribute => 'TicketID',
        Expected  => {
            'Select'  => ['st.id AS SortAttr0'],
            'OrderBy' => ['SortAttr0']
        }
    },
    {
        Name      => 'Sort: Attribute "ID"',
        Attribute => 'ID',
        Expected  => {
            'Select'  => ['st.id AS SortAttr0'],
            'OrderBy' => ['SortAttr0']
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
my $TicketID1 = $Kernel::OM->Get('Ticket')->TicketCreate(
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
# second ticket
my $TicketID2 = $Kernel::OM->Get('Ticket')->TicketCreate(
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
# third ticket
my $TicketID3 = $Kernel::OM->Get('Ticket')->TicketCreate(
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
    'Created third ticket'
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Ticket'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field TicketID / Operator EQ / Value $TicketID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketID',
                    Operator => 'EQ',
                    Value    => $TicketID2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field TicketID / Operator NE / Value $TicketID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketID',
                    Operator => 'NE',
                    Value    => $TicketID2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field TicketID / Operator IN / Value [$TicketID1,$TicketID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketID',
                    Operator => 'IN',
                    Value    => [$TicketID1,$TicketID3]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID3]
    },
    {
        Name     => 'Search: Field TicketID / Operator !IN / Value [$TicketID1,$TicketID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketID',
                    Operator => '!IN',
                    Value    => [$TicketID1,$TicketID3]
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field TicketID / Operator LT / Value $TicketID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketID',
                    Operator => 'LT',
                    Value    => $TicketID2
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: Field TicketID / Operator LTE / Value $TicketID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketID',
                    Operator => 'LTE',
                    Value    => $TicketID2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: Field TicketID / Operator GT / Value $TicketID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketID',
                    Operator => 'GT',
                    Value    => $TicketID2
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field TicketID / Operator GTE / Value $TicketID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketID',
                    Operator => 'GTE',
                    Value    => $TicketID2
                }
            ]
        },
        Expected => [$TicketID2,$TicketID3]
    },
    {
        Name     => 'Search: Field ID / Operator EQ / Value $TicketID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'EQ',
                    Value    => $TicketID2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field ID / Operator NE / Value $TicketID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'NE',
                    Value    => $TicketID2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field ID / Operator IN / Value [$TicketID1,$TicketID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'IN',
                    Value    => [$TicketID1,$TicketID3]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID3]
    },
    {
        Name     => 'Search: Field ID / Operator !IN / Value [$TicketID1,$TicketID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => '!IN',
                    Value    => [$TicketID1,$TicketID3]
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field ID / Operator LT / Value $TicketID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'LT',
                    Value    => $TicketID2
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: Field ID / Operator LTE / Value $TicketID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'LTE',
                    Value    => $TicketID2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: Field ID / Operator GT / Value $TicketID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'GT',
                    Value    => $TicketID2
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field ID / Operator GTE / Value $TicketID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'GTE',
                    Value    => $TicketID2
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
        Name     => 'Sort: Field TicketID',
        Sort     => [
            {
                Field => 'TicketID'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field TicketID / Direction ascending',
        Sort     => [
            {
                Field     => 'TicketID',
                Direction => 'ascending'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field TicketID / Direction descending',
        Sort     => [
            {
                Field     => 'TicketID',
                Direction => 'descending'
            }
        ],
        Expected => [$TicketID3, $TicketID2, $TicketID1]
    },
    {
        Name     => 'Sort: Field ID',
        Sort     => [
            {
                Field => 'ID'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field ID / Direction ascending',
        Sort     => [
            {
                Field     => 'ID',
                Direction => 'ascending'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field ID / Direction descending',
        Sort     => [
            {
                Field     => 'ID',
                Direction => 'descending'
            }
        ],
        Expected => [$TicketID3, $TicketID2, $TicketID1]
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Ticket',
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
