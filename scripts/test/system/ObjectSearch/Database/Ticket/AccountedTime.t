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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Ticket::AccountedTime';

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
for my $Method ( qw(GetSupportedAttributes AttributePrepare Select Search Sort) ) {
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
        AccountedTime => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType      => 'NUMERIC'
        }
    },
    'GetSupportedAttributes provides expected data'
);

# check AttributePrepare
my @AttributePrepareTests = (
    {
        Name      => 'AttributePrepare: empty parameter',
        Parameter => {},
        Expected  => {
            Column => 'st.accounted_time',
        }
    },
    {
        Name      => 'AttributePrepare: PrepareType "Select"',
        Parameter => {
            PrepareType => 'Select'
        },
        Expected  => {
            Column => 'st.accounted_time',
        }
    },
    {
        Name      => 'AttributePrepare: PrepareType "Condition"',
        Parameter => {
            PrepareType => 'Condition'
        },
        Expected  => {
            Column       => 'st.accounted_time',
            ConditionDef => {
                ValueType => 'NUMERIC',
                NULLValue => 1
            }
        }
    },
    {
        Name      => 'AttributePrepare: PrepareType "Sort"',
        Parameter => {
            PrepareType => 'Sort'
        },
        Expected  => {
            Column => 'st.accounted_time',
        }
    },
    {
        Name      => 'AttributePrepare: PrepareType "Fulltext"',
        Parameter => {
            PrepareType => 'Fulltext'
        },
        Expected  => {
            Column => 'st.accounted_time',
        }
    },
);
for my $Test ( @AttributePrepareTests ) {
    my $Result = $AttributeObject->AttributePrepare(
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

# check Search
my @SearchTests = (
    {
        Name     => 'Search: undef search',
        Search   => undef,
        Expected => undef
    },
    {
        Name     => 'Search: Value undef',
        Search   => {
            Field    => 'AccountedTime',
            Operator => 'EQ',
            Value    => undef

        },
        Expected => undef
    },
    {
        Name     => 'Search: Value invalid',
        Search   => {
            Field    => 'AccountedTime',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected => undef
    },
    {
        Name     => 'Search: Field undef',
        Search   => {
            Field    => undef,
            Operator => 'EQ',
            Value    => '1'
        },
        Expected => undef
    },
    {
        Name     => 'Search: Field invalid',
        Search   => {
            Field    => 'Test',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected => undef
    },
    {
        Name     => 'Search: Operator undef',
        Search   => {
            Field    => 'AccountedTime',
            Operator => undef,
            Value    => '1'
        },
        Expected => undef
    },
    {
        Name     => 'Search: Operator invalid',
        Search   => {
            Field    => 'AccountedTime',
            Operator => 'Test',
            Value    => '1'
        },
        Expected => undef
    },
    {
        Name     => 'Search: valid search / Operator EQ',
        Search   => {
            Field    => 'AccountedTime',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected => {
            Where => ['st.accounted_time = 1']
        }
    },
    {
        Name     => 'Search: valid search / Operator EQ / negative integer',
        Search   => {
            Field    => 'AccountedTime',
            Operator => 'EQ',
            Value    => '-1'
        },
        Expected => {
            Where => ['st.accounted_time = -1']
        }
    },
    {
        Name     => 'Search: valid search / Operator NE',
        Search   => {
            Field    => 'AccountedTime',
            Operator => 'NE',
            Value    => '1'
        },
        Expected => {
            Where => ['(st.accounted_time <> 1 OR st.accounted_time IS NULL)']
        }
    },
    {
        Name     => 'Search: valid search / Operator IN',
        Search   => {
            Field    => 'AccountedTime',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected => {
            Where => ['st.accounted_time IN (1)']
        }
    },
    {
        Name     => 'Search: valid search / Operator !IN',
        Search   => {
            Field    => 'AccountedTime',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected => {
            Where => ['st.accounted_time NOT IN (1)']
        }
    },
    {
        Name     => 'Search: valid search / Operator LT',
        Search   => {
            Field    => 'AccountedTime',
            Operator => 'LT',
            Value    => '1'
        },
        Expected => {
            Where => ['st.accounted_time < 1']
        }
    },
    {
        Name     => 'Search: valid search / Operator GT',
        Search   => {
            Field    => 'AccountedTime',
            Operator => 'GT',
            Value    => '1'
        },
        Expected => {
            Where => ['st.accounted_time > 1']
        }
    },
    {
        Name     => 'Search: valid search / Operator LTE',
        Search   => {
            Field    => 'AccountedTime',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected => {
            Where => ['st.accounted_time <= 1']
        }
    },
    {
        Name     => 'Search: valid search / Operator GTE',
        Search   => {
            Field    => 'AccountedTime',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected => {
            Where => ['st.accounted_time >= 1']
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
        Name      => 'Sort: Attribute "AccountedTime"',
        Attribute => 'AccountedTime',
        Expected  => {
            Select  => [ 'st.accounted_time AS SortAttr0' ],
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
my $TicketAccountTime1 = $Kernel::OM->Get('Ticket')->TicketAccountTime(
    TicketID  => $TicketID1,
    TimeUnit  => '1',
    UserID    => 1,
);
$Self->True(
    $TicketAccountTime1,
    'Accounted time for first ticket'
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
my $TicketAccountTime2 = $Kernel::OM->Get('Ticket')->TicketAccountTime(
    TicketID  => $TicketID2,
    TimeUnit  => '2',
    UserID    => 1,
);
$Self->True(
    $TicketAccountTime2,
    'Accounted time for second ticket'
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
my $TicketAccountTime3 = $Kernel::OM->Get('Ticket')->TicketAccountTime(
    TicketID  => $TicketID3,
    TimeUnit  => '3',
    UserID    => 1,
);
$Self->True(
    $TicketAccountTime3,
    'Accounted time for third ticket'
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Ticket'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field AccountedTime / Operator EQ / Value 2',
        Search   => {
            'AND' => [
                {
                    Field    => 'AccountedTime',
                    Operator => 'EQ',
                    Value    => '2'
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field AccountedTime / Operator EQ / Value 2',
        Search   => {
            'AND' => [
                {
                    Field    => 'AccountedTime',
                    Operator => 'NE',
                    Value    => '2'
                }
            ]
        },
        Expected => [$TicketID1, $TicketID3]
    },
    {
        Name     => 'Search: Field AccountedTime / Operator LT / Value 2',
        Search   => {
            'AND' => [
                {
                    Field    => 'AccountedTime',
                    Operator => 'LT',
                    Value    => '2'
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: Field AccountedTime / Operator GT / Value 2',
        Search   => {
            'AND' => [
                {
                    Field    => 'AccountedTime',
                    Operator => 'GT',
                    Value    => '2'
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field AccountedTime / Operator LTE / Value 2',
        Search   => {
            'AND' => [
                {
                    Field    => 'AccountedTime',
                    Operator => 'LTE',
                    Value    => '2'
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2]
    },
    {
        Name     => 'Search: Field AccountedTime / Operator GTE / Value 2',
        Search   => {
            'AND' => [
                {
                    Field    => 'AccountedTime',
                    Operator => 'GTE',
                    Value    => '2'
                }
            ]
        },
        Expected => [$TicketID2, $TicketID3]
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
        Name     => 'Sort: Field AccountedTime',
        Sort     => [
            {
                Field => 'AccountedTime'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field AccountedTime / Direction ascending',
        Sort     => [
            {
                Field     => 'AccountedTime',
                Direction => 'ascending'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field AccountedTime / Direction descending',
        Sort     => [
            {
                Field     => 'AccountedTime',
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
