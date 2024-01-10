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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Ticket::TicketNumber';

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
        TicketNumber => {
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
            Field    => 'TicketNumber',
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
            Field    => 'TicketNumber',
            Operator => undef,
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'TicketNumber',
            Operator => 'Test',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field TicketNumber / Operator EQ',
        Search       => {
            Field    => 'TicketNumber',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                'LOWER(st.tn) = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TicketNumber / Operator NE',
        Search       => {
            Field    => 'TicketNumber',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                'LOWER(st.tn) != \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TicketNumber / Operator IN',
        Search       => {
            Field    => 'TicketNumber',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                'LOWER(st.tn) IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TicketNumber / Operator !IN',
        Search       => {
            Field    => 'TicketNumber',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                'LOWER(st.tn) NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TicketNumber / Operator STARTSWITH',
        Search       => {
            Field    => 'TicketNumber',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                'LOWER(st.tn) LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TicketNumber / Operator ENDSWITH',
        Search       => {
            Field    => 'TicketNumber',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                'LOWER(st.tn) LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TicketNumber / Operator CONTAINS',
        Search       => {
            Field    => 'TicketNumber',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                'LOWER(st.tn) LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TicketNumber / Operator LIKE',
        Search       => {
            Field    => 'TicketNumber',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                'LOWER(st.tn) LIKE \'test\''
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
        Name      => 'Sort: Attribute "TicketNumber"',
        Attribute => 'TicketNumber',
        Expected  => {
            'Select'  => ['st.tn'],
            'OrderBy' => ['st.tn']
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
my $TicketNumber1 = '123000001';
my $TicketID1     = $Kernel::OM->Get('Ticket')->TicketCreate(
    TN             => $TicketNumber1,
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
my $TicketNumber2 = '123000002';
my $TicketID2     = $Kernel::OM->Get('Ticket')->TicketCreate(
    TN             => $TicketNumber2,
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
my $TicketNumber3 = '123000003';
my $TicketID3     = $Kernel::OM->Get('Ticket')->TicketCreate(
    TN             => $TicketNumber3,
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
        Name     => 'Search: Field TicketNumber / Operator EQ / Value $TicketNumber2',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketNumber',
                    Operator => 'EQ',
                    Value    => $TicketNumber2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field TicketNumber / Operator NE / Value $TicketNumber2',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketNumber',
                    Operator => 'NE',
                    Value    => $TicketNumber2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field TicketNumber / Operator IN / Value [$TicketNumber1,$TicketNumber3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketNumber',
                    Operator => 'IN',
                    Value    => [$TicketNumber1,$TicketNumber3]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID3]
    },
    {
        Name     => 'Search: Field TicketNumber / Operator !IN / Value [$TicketNumber1,$TicketNumber3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketNumber',
                    Operator => '!IN',
                    Value    => [$TicketNumber1,$TicketNumber3]
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field TicketNumber / Operator STARTSWITH / Value $TicketNumber2',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketNumber',
                    Operator => 'STARTSWITH',
                    Value    => $TicketNumber2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field TicketNumber / Operator STARTSWITH / Value substr($TicketNumber2,0,5)',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketNumber',
                    Operator => 'STARTSWITH',
                    Value    => substr($TicketNumber2,0,5)
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => 'Search: Field TicketNumber / Operator ENDSWITH / Value $TicketNumber2',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketNumber',
                    Operator => 'ENDSWITH',
                    Value    => $TicketNumber2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field TicketNumber / Operator ENDSWITH / Value substr($TicketNumber2,-4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketNumber',
                    Operator => 'ENDSWITH',
                    Value    => substr($TicketNumber2,-4)
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field TicketNumber / Operator CONTAINS / Value $TicketNumber2',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketNumber',
                    Operator => 'CONTAINS',
                    Value    => $TicketNumber2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field TicketNumber / Operator CONTAINS / Value substr($TicketNumber2,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketNumber',
                    Operator => 'CONTAINS',
                    Value    => substr($TicketNumber2,2,-2)
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => 'Search: Field TicketNumber / Operator LIKE / Value $TicketNumber2',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketNumber',
                    Operator => 'LIKE',
                    Value    => $TicketNumber2
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
        Name     => 'Sort: Field TicketNumber',
        Sort     => [
            {
                Field => 'TicketNumber'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field TicketNumber / Direction ascending',
        Sort     => [
            {
                Field     => 'TicketNumber',
                Direction => 'ascending'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field TicketNumber / Direction descending',
        Sort     => [
            {
                Field     => 'TicketNumber',
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
