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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::ObjectTag::ObjectTagID';

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
        ObjectTagID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType    => 'NUMERIC'
        },
        ID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType    => 'NUMERIC'
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
            Field    => 'ObjectTagID',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'ObjectTagID',
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
            Field    => 'ObjectTagID',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'ObjectTagID',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field ObjectTagID / Operator EQ',
        Search       => {
            Field    => 'ObjectTagID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ot.id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ObjectTagID / Operator NE',
        Search       => {
            Field    => 'ObjectTagID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ot.id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ObjectTagID / Operator IN',
        Search       => {
            Field    => 'ObjectTagID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'ot.id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ObjectTagID / Operator !IN',
        Search       => {
            Field    => 'ObjectTagID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'ot.id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ObjectTagID / Operator LT',
        Search       => {
            Field    => 'ObjectTagID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ot.id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ObjectTagID / Operator LTE',
        Search       => {
            Field    => 'ObjectTagID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ot.id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ObjectTagID / Operator GT',
        Search       => {
            Field    => 'ObjectTagID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ot.id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ObjectTagID / Operator GTE',
        Search       => {
            Field    => 'ObjectTagID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ot.id >= 1'
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
                'ot.id = 1'
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
                'ot.id <> 1'
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
                'ot.id IN (1)'
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
                'ot.id NOT IN (1)'
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
                'ot.id < 1'
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
                'ot.id <= 1'
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
                'ot.id > 1'
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
                'ot.id >= 1'
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
        Name      => 'Sort: Attribute "ObjectTagID"',
        Attribute => 'ObjectTagID',
        Expected  => {
            'Select'  => ['ot.id'],
            'OrderBy' => ['ot.id']
        }
    },
    {
        Name      => 'Sort: Attribute "ID"',
        Attribute => 'ID',
        Expected  => {
            'Select'  => ['ot.id'],
            'OrderBy' => ['ot.id']
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

## prepare test objecttag ##
my $TestData1 = 'Test001';
my $TestData2 = 'test002';
my $TestData3 = 'Test003';

# first objecttag
my $ObjectTagID1 = $Kernel::OM->Get('ObjectTag')->ObjectTagAdd(
    Name       => $TestData1,
    ObjectType => $Helper->GetRandomID(),
    ObjectID   => 1,
    UserID     => 1
);
$Self->True(
    $ObjectTagID1,
    'Created first objecttag'
);
# second objecttag
my $ObjectTagID2 = $Kernel::OM->Get('ObjectTag')->ObjectTagAdd(
    Name       => $TestData2,
    ObjectType => $Helper->GetRandomID(),
    ObjectID   => 1,
    UserID     => 1
);
$Self->True(
    $ObjectTagID2,
    'Created second objecttag'
);
# third objecttag
my $ObjectTagID3 = $Kernel::OM->Get('ObjectTag')->ObjectTagAdd(
    Name       => $TestData3,
    ObjectType => $Helper->GetRandomID(),
    ObjectID   => 1,
    UserID     => 1
);
$Self->True(
    $ObjectTagID3,
    'Created third objecttag'
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['ObjectTag'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field ObjectTagID / Operator EQ / Value $ObjectTagID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ObjectTagID',
                    Operator => 'EQ',
                    Value    => $ObjectTagID2
                }
            ]
        },
        Expected => [$TestData2]
    },
    {
        Name     => 'Search: Field ObjectTagID / Operator NE / Value $ObjectTagID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ObjectTagID',
                    Operator => 'NE',
                    Value    => $ObjectTagID2
                }
            ]
        },
        Expected => [$TestData1,$TestData3]
    },
    {
        Name     => 'Search: Field ObjectTagID / Operator IN / Value [$ObjectTagID1,$ObjectTagID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ObjectTagID',
                    Operator => 'IN',
                    Value    => [$ObjectTagID1,$ObjectTagID3]
                }
            ]
        },
        Expected => [$TestData1,$TestData3]
    },
    {
        Name     => 'Search: Field ObjectTagID / Operator !IN / Value [$ObjectTagID1,$ObjectTagID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ObjectTagID',
                    Operator => '!IN',
                    Value    => [$ObjectTagID1,$ObjectTagID3]
                }
            ]
        },
        Expected => [$TestData2]
    },
    {
        Name     => 'Search: Field ObjectTagID / Operator LT / Value $ObjectTagID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ObjectTagID',
                    Operator => 'LT',
                    Value    => $ObjectTagID2
                }
            ]
        },
        Expected => [$TestData1]
    },
    {
        Name     => 'Search: Field ObjectTagID / Operator LTE / Value $ObjectTagID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ObjectTagID',
                    Operator => 'LTE',
                    Value    => $ObjectTagID2
                }
            ]
        },
        Expected => [$TestData1,$TestData2]
    },
    {
        Name     => 'Search: Field ObjectTagID / Operator GT / Value $ObjectTagID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ObjectTagID',
                    Operator => 'GT',
                    Value    => $ObjectTagID2
                }
            ]
        },
        Expected => [$TestData3]
    },
    {
        Name     => 'Search: Field ObjectTagID / Operator GTE / Value $ObjectTagID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ObjectTagID',
                    Operator => 'GTE',
                    Value    => $ObjectTagID2
                }
            ]
        },
        Expected => [$TestData2,$TestData3]
    },
    {
        Name     => 'Search: Field ID / Operator EQ / Value $ObjectTagID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'EQ',
                    Value    => $ObjectTagID2
                }
            ]
        },
        Expected => [$TestData2]
    },
    {
        Name     => 'Search: Field ID / Operator NE / Value $ObjectTagID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'NE',
                    Value    => $ObjectTagID2
                }
            ]
        },
        Expected => [$TestData1,$TestData3]
    },
    {
        Name     => 'Search: Field ID / Operator IN / Value [$ObjectTagID1,$ObjectTagID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'IN',
                    Value    => [$ObjectTagID1,$ObjectTagID3]
                }
            ]
        },
        Expected => [$TestData1,$TestData3]
    },
    {
        Name     => 'Search: Field ID / Operator !IN / Value [$ObjectTagID1,$ObjectTagID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => '!IN',
                    Value    => [$ObjectTagID1,$ObjectTagID3]
                }
            ]
        },
        Expected => [$TestData2]
    },
    {
        Name     => 'Search: Field ID / Operator LT / Value $ObjectTagID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'LT',
                    Value    => $ObjectTagID2
                }
            ]
        },
        Expected => [$TestData1]
    },
    {
        Name     => 'Search: Field ID / Operator LTE / Value $ObjectTagID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'LTE',
                    Value    => $ObjectTagID2
                }
            ]
        },
        Expected => [$TestData1,$TestData2]
    },
    {
        Name     => 'Search: Field ID / Operator GT / Value $ObjectTagID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'GT',
                    Value    => $ObjectTagID2
                }
            ]
        },
        Expected => [$TestData3]
    },
    {
        Name     => 'Search: Field ID / Operator GTE / Value $ObjectTagID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'GTE',
                    Value    => $ObjectTagID2
                }
            ]
        },
        Expected => [$TestData2,$TestData3]
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'ObjectTag',
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
        Name     => 'Sort: Field ObjectTagID',
        Sort     => [
            {
                Field => 'ObjectTagID'
            }
        ],
        Expected => [$TestData1,$TestData2,$TestData3]
    },
    {
        Name     => 'Sort: Field ObjectTagID / Direction ascending',
        Sort     => [
            {
                Field     => 'ObjectTagID',
                Direction => 'ascending'
            }
        ],
        Expected => [$TestData1,$TestData2,$TestData3]
    },
    {
        Name     => 'Sort: Field ObjectTagID / Direction descending',
        Sort     => [
            {
                Field     => 'ObjectTagID',
                Direction => 'descending'
            }
        ],
        Expected => [$TestData3,$TestData2,$TestData1]
    },
    {
        Name     => 'Sort: Field ID',
        Sort     => [
            {
                Field => 'ID'
            }
        ],
        Expected => [$TestData1,$TestData2,$TestData3]
    },
    {
        Name     => 'Sort: Field ID / Direction ascending',
        Sort     => [
            {
                Field     => 'ID',
                Direction => 'ascending'
            }
        ],
        Expected => [$TestData1,$TestData2,$TestData3]
    },
    {
        Name     => 'Sort: Field ID / Direction descending',
        Sort     => [
            {
                Field     => 'ID',
                Direction => 'descending'
            }
        ],
        Expected => [$TestData3,$TestData2,$TestData1]
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'ObjectTag',
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
