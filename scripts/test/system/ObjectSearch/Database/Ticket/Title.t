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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Ticket::Title';

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
        Title => {
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
            Field    => 'Title',
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
            Field    => 'Title',
            Operator => undef,
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'Title',
            Operator => 'Test',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field Title / Operator EQ',
        Search       => {
            Field    => 'Title',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                'LOWER(st.title) = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Title / Operator NE',
        Search       => {
            Field    => 'Title',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                'LOWER(st.title) != \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Title / Operator IN',
        Search       => {
            Field    => 'Title',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                'LOWER(st.title) IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Title / Operator !IN',
        Search       => {
            Field    => 'Title',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                'LOWER(st.title) NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Title / Operator STARTSWITH',
        Search       => {
            Field    => 'Title',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                'LOWER(st.title) LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Title / Operator ENDSWITH',
        Search       => {
            Field    => 'Title',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                'LOWER(st.title) LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Title / Operator CONTAINS',
        Search       => {
            Field    => 'Title',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                'LOWER(st.title) LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Title / Operator LIKE',
        Search       => {
            Field    => 'Title',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                'LOWER(st.title) LIKE \'test\''
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
        Name      => 'Sort: Attribute "Title"',
        Attribute => 'Title',
        Expected  => {
            'Select'  => ['st.title'],
            'OrderBy' => ['LOWER(st.title)']
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
my $TicketName1 = 'Test123';
my $TicketID1   = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $TicketName1,
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
my $TicketName2 = 'test456';
my $TicketID2   = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $TicketName2,
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
my $TicketName3 = 'Test789';
my $TicketID3   = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $TicketName3,
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
        Name     => 'Search: Field Title / Operator EQ / Value $TicketName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'EQ',
                    Value    => $TicketName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Title / Operator NE / Value $TicketName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'NE',
                    Value    => $TicketName2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field Title / Operator IN / Value [$TicketName1,$TicketName3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'IN',
                    Value    => [$TicketName1,$TicketName3]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID3]
    },
    {
        Name     => 'Search: Field Title / Operator !IN / Value [$TicketName1,$TicketName3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => '!IN',
                    Value    => [$TicketName1,$TicketName3]
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Title / Operator STARTSWITH / Value $TicketName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'STARTSWITH',
                    Value    => $TicketName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Title / Operator STARTSWITH / Value substr($TicketName2,0,5)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'STARTSWITH',
                    Value    => substr($TicketName2,0,5)
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Title / Operator ENDSWITH / Value $TicketName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'ENDSWITH',
                    Value    => $TicketName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Title / Operator ENDSWITH / Value substr($TicketName2,-4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'ENDSWITH',
                    Value    => substr($TicketName2,-4)
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Title / Operator CONTAINS / Value $TicketName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'CONTAINS',
                    Value    => $TicketName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Title / Operator CONTAINS / Value substr($TicketName2,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'CONTAINS',
                    Value    => substr($TicketName2,2,-2)
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field Title / Operator LIKE / Value $TicketName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'LIKE',
                    Value    => $TicketName2
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
        Name     => 'Sort: Field Title',
        Sort     => [
            {
                Field => 'Title'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field Title / Direction ascending',
        Sort     => [
            {
                Field     => 'Title',
                Direction => 'ascending'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field Title / Direction descending',
        Sort     => [
            {
                Field     => 'Title',
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
