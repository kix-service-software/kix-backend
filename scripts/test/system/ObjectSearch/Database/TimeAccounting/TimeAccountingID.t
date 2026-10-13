# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/
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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::TimeAccounting::TimeAccountingID';

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
        TimeAccountingID => {
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
            Field    => 'TimeAccountingID',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'TimeAccountingID',
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
            Field    => 'TimeAccountingID',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'TimeAccountingID',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field TimeAccountingID / Operator EQ',
        Search       => {
            Field    => 'TimeAccountingID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ta.id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TimeAccountingID / Operator NE',
        Search       => {
            Field    => 'TimeAccountingID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ta.id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TimeAccountingID / Operator IN',
        Search       => {
            Field    => 'TimeAccountingID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'ta.id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TimeAccountingID / Operator !IN',
        Search       => {
            Field    => 'TimeAccountingID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'ta.id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TimeAccountingID / Operator LT',
        Search       => {
            Field    => 'TimeAccountingID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ta.id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TimeAccountingID / Operator LTE',
        Search       => {
            Field    => 'TimeAccountingID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ta.id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TimeAccountingID / Operator GT',
        Search       => {
            Field    => 'TimeAccountingID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ta.id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TimeAccountingID / Operator GTE',
        Search       => {
            Field    => 'TimeAccountingID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ta.id >= 1'
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
                'ta.id = 1'
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
                'ta.id <> 1'
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
                'ta.id IN (1)'
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
                'ta.id NOT IN (1)'
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
                'ta.id < 1'
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
                'ta.id <= 1'
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
                'ta.id > 1'
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
                'ta.id >= 1'
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
        Name      => 'Sort: Attribute "TimeAccountingID"',
        Attribute => 'TimeAccountingID',
        Expected  => {
            'Select'  => ['ta.id AS SortAttr0'],
            'OrderBy' => ['SortAttr0']
        }
    },
    {
        Name      => 'Sort: Attribute "ID"',
        Attribute => 'ID',
        Expected  => {
            'Select'  => ['ta.id AS SortAttr0'],
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

## prepare Ticket ##
my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title    => 'UnitTest',
    OwnerID  => 1,
    Queue    => 'Junk',
    Priority => '3 normal',
    UserID   => 1,
    State    => 'new',
    Lock     => 'unlock'
);
$Self->True(
    $TicketID,
    'ticket created'
);

my $TimeStamp = $Kernel::OM->Get('Time')->CurrentTimestamp();

## prepare TimeAccounting ##
my $TimeAccountingID1 = $Kernel::OM->Get('TimeAccounting')->TimeAccountingCreate(
    TicketID           => $TicketID,
    StartTime          => $TimeStamp,
    TimeUnit           => 1,
    IsInvoiced         => 0,
    UserID             => 1,
    UserType           => 'Agent',
    ExecutingContactID => 1,
);
$Self->True(
    $TimeAccountingID1,
    'first time accounting created'
);

my $TimeAccountingID2 = $Kernel::OM->Get('TimeAccounting')->TimeAccountingCreate(
    TicketID           => $TicketID,
    StartTime          => $TimeStamp,
    TimeUnit           => 1,
    IsInvoiced         => 0,
    UserID             => 1,
    UserType           => 'Agent',
    ExecutingContactID => 1,
);
$Self->True(
    $TimeAccountingID2,
    'second time accounting created'
);

my $TimeAccountingID3 = $Kernel::OM->Get('TimeAccounting')->TimeAccountingCreate(
    TicketID           => $TicketID,
    StartTime          => $TimeStamp,
    TimeUnit           => 1,
    IsInvoiced         => 0,
    UserID             => 1,
    UserType           => 'Agent',
    ExecutingContactID => 1,
);
$Self->True(
    $TimeAccountingID3,
    'third time accounting created'
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['TimeAccounting'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field TimeAccountingID / Operator EQ / Value $TimeAccountingID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'TimeAccountingID',
                    Operator => 'EQ',
                    Value    => $TimeAccountingID2
                }
            ]
        },
        Expected => [$TimeAccountingID2]
    },
    {
        Name     => 'Search: Field TimeAccountingID / Operator NE / Value $TimeAccountingID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'TimeAccountingID',
                    Operator => 'NE',
                    Value    => $TimeAccountingID2
                }
            ]
        },
        Expected => [$TimeAccountingID1,$TimeAccountingID3]
    },
    {
        Name     => 'Search: Field TimeAccountingID / Operator IN / Value [$TimeAccountingID1,$TimeAccountingID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'TimeAccountingID',
                    Operator => 'IN',
                    Value    => [$TimeAccountingID1,$TimeAccountingID3]
                }
            ]
        },
        Expected => [$TimeAccountingID1,$TimeAccountingID3]
    },
    {
        Name     => 'Search: Field TimeAccountingID / Operator !IN / Value [$TimeAccountingID1,$TimeAccountingID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'TimeAccountingID',
                    Operator => '!IN',
                    Value    => [$TimeAccountingID1,$TimeAccountingID3]
                }
            ]
        },
        Expected => [$TimeAccountingID2]
    },
    {
        Name     => 'Search: Field TimeAccountingID / Operator LT / Value $TimeAccountingID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'TimeAccountingID',
                    Operator => 'LT',
                    Value    => $TimeAccountingID2
                }
            ]
        },
        Expected => [$TimeAccountingID1]
    },
    {
        Name     => 'Search: Field TimeAccountingID / Operator LTE / Value $TimeAccountingID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'TimeAccountingID',
                    Operator => 'LTE',
                    Value    => $TimeAccountingID2
                }
            ]
        },
        Expected => [$TimeAccountingID1,$TimeAccountingID2]
    },
    {
        Name     => 'Search: Field TimeAccountingID / Operator GT / Value $TimeAccountingID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'TimeAccountingID',
                    Operator => 'GT',
                    Value    => $TimeAccountingID2
                }
            ]
        },
        Expected => [$TimeAccountingID3]
    },
    {
        Name     => 'Search: Field TimeAccountingID / Operator GTE / Value $TimeAccountingID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'TimeAccountingID',
                    Operator => 'GTE',
                    Value    => $TimeAccountingID2
                }
            ]
        },
        Expected => [$TimeAccountingID2,$TimeAccountingID3]
    },
    {
        Name     => 'Search: Field ID / Operator EQ / Value $TimeAccountingID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'EQ',
                    Value    => $TimeAccountingID2
                }
            ]
        },
        Expected => [$TimeAccountingID2]
    },
    {
        Name     => 'Search: Field ID / Operator NE / Value $TimeAccountingID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'NE',
                    Value    => $TimeAccountingID2
                }
            ]
        },
        Expected => [$TimeAccountingID1,$TimeAccountingID3]
    },
    {
        Name     => 'Search: Field ID / Operator IN / Value [$TimeAccountingID1,$TimeAccountingID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'IN',
                    Value    => [$TimeAccountingID1,$TimeAccountingID3]
                }
            ]
        },
        Expected => [$TimeAccountingID1,$TimeAccountingID3]
    },
    {
        Name     => 'Search: Field ID / Operator !IN / Value [$TimeAccountingID1,$TimeAccountingID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => '!IN',
                    Value    => [$TimeAccountingID1,$TimeAccountingID3]
                }
            ]
        },
        Expected => [$TimeAccountingID2]
    },
    {
        Name     => 'Search: Field ID / Operator LT / Value $TimeAccountingID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'LT',
                    Value    => $TimeAccountingID2
                }
            ]
        },
        Expected => [$TimeAccountingID1]
    },
    {
        Name     => 'Search: Field ID / Operator LTE / Value $TimeAccountingID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'LTE',
                    Value    => $TimeAccountingID2
                }
            ]
        },
        Expected => [$TimeAccountingID1,$TimeAccountingID2]
    },
    {
        Name     => 'Search: Field ID / Operator GT / Value $TimeAccountingID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'GT',
                    Value    => $TimeAccountingID2
                }
            ]
        },
        Expected => [$TimeAccountingID3]
    },
    {
        Name     => 'Search: Field ID / Operator GTE / Value $TimeAccountingID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'GTE',
                    Value    => $TimeAccountingID2
                }
            ]
        },
        Expected => [$TimeAccountingID2,$TimeAccountingID3]
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'TimeAccounting',
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
        Name     => 'Sort: Field TimeAccountingID',
        Sort     => [
            {
                Field => 'TimeAccountingID'
            }
        ],
        Expected => [$TimeAccountingID1,$TimeAccountingID2,$TimeAccountingID3]
    },
    {
        Name     => 'Sort: Field TimeAccountingID / Direction ascending',
        Sort     => [
            {
                Field     => 'TimeAccountingID',
                Direction => 'ascending'
            }
        ],
        Expected => [$TimeAccountingID1,$TimeAccountingID2,$TimeAccountingID3]
    },
    {
        Name     => 'Sort: Field TimeAccountingID / Direction descending',
        Sort     => [
            {
                Field     => 'TimeAccountingID',
                Direction => 'descending'
            }
        ],
        Expected => [$TimeAccountingID3,$TimeAccountingID2,$TimeAccountingID1]
    },
    {
        Name     => 'Sort: Field ID',
        Sort     => [
            {
                Field => 'ID'
            }
        ],
        Expected => [$TimeAccountingID1,$TimeAccountingID2,$TimeAccountingID3]
    },
    {
        Name     => 'Sort: Field ID / Direction ascending',
        Sort     => [
            {
                Field     => 'ID',
                Direction => 'ascending'
            }
        ],
        Expected => [$TimeAccountingID1,$TimeAccountingID2,$TimeAccountingID3]
    },
    {
        Name     => 'Sort: Field ID / Direction descending',
        Sort     => [
            {
                Field     => 'ID',
                Direction => 'descending'
            }
        ],
        Expected => [$TimeAccountingID3,$TimeAccountingID2,$TimeAccountingID1]
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'TimeAccounting',
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
