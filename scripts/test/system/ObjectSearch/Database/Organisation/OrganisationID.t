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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Organisation::OrganisationID';

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
        OrganisationID => {
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
            Field    => 'OrganisationID',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'OrganisationID',
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
            Field    => 'OrganisationID',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'OrganisationID',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field OrganisationID / Operator EQ',
        Search       => {
            Field    => 'OrganisationID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'o.id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field OrganisationID / Operator NE',
        Search       => {
            Field    => 'OrganisationID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'o.id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field OrganisationID / Operator IN',
        Search       => {
            Field    => 'OrganisationID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'o.id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field OrganisationID / Operator !IN',
        Search       => {
            Field    => 'OrganisationID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'o.id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field OrganisationID / Operator LT',
        Search       => {
            Field    => 'OrganisationID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'o.id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field OrganisationID / Operator LTE',
        Search       => {
            Field    => 'OrganisationID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'o.id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field OrganisationID / Operator GT',
        Search       => {
            Field    => 'OrganisationID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'o.id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field OrganisationID / Operator GTE',
        Search       => {
            Field    => 'OrganisationID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'o.id >= 1'
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
                'o.id = 1'
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
                'o.id <> 1'
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
                'o.id IN (1)'
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
                'o.id NOT IN (1)'
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
                'o.id < 1'
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
                'o.id <= 1'
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
                'o.id > 1'
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
                'o.id >= 1'
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
        Name      => 'Sort: Attribute "OrganisationID"',
        Attribute => 'OrganisationID',
        Expected  => {
            'Select'  => ['o.id'],
            'OrderBy' => ['o.id']
        }
    },
    {
        Name      => 'Sort: Attribute "ID"',
        Attribute => 'ID',
        Expected  => {
            'Select'  => ['o.id'],
            'OrderBy' => ['o.id']
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

## prepare test organisation ##
# first organisation
my $OrganisationID1 = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number => $Helper->GetRandomID(),
    Name   => $Helper->GetRandomID(),
    UserID => 1
);
$Self->True(
    $OrganisationID1,
    'Created first organisation'
);
# second organisation
my $OrganisationID2 = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number => $Helper->GetRandomID(),
    Name   => $Helper->GetRandomID(),
    UserID => 1
);
$Self->True(
    $OrganisationID2,
    'Created second organisation'
);
# third organisation
my $OrganisationID3 = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number => $Helper->GetRandomID(),
    Name   => $Helper->GetRandomID(),
    UserID => 1
);
$Self->True(
    $OrganisationID3,
    'Created third organisation'
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Organisation'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field OrganisationID / Operator EQ / Value $OrganisationID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationID',
                    Operator => 'EQ',
                    Value    => $OrganisationID2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field OrganisationID / Operator NE / Value $OrganisationID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationID',
                    Operator => 'NE',
                    Value    => $OrganisationID2
                }
            ]
        },
        Expected => ['1',$OrganisationID1,$OrganisationID3]
    },
    {
        Name     => 'Search: Field OrganisationID / Operator IN / Value [$OrganisationID1,$OrganisationID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationID',
                    Operator => 'IN',
                    Value    => [$OrganisationID1,$OrganisationID3]
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID3]
    },
    {
        Name     => 'Search: Field OrganisationID / Operator !IN / Value [$OrganisationID1,$OrganisationID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationID',
                    Operator => '!IN',
                    Value    => [$OrganisationID1,$OrganisationID3]
                }
            ]
        },
        Expected => ['1',$OrganisationID2]
    },
    {
        Name     => 'Search: Field OrganisationID / Operator LT / Value $OrganisationID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationID',
                    Operator => 'LT',
                    Value    => $OrganisationID2
                }
            ]
        },
        Expected => ['1',$OrganisationID1]
    },
    {
        Name     => 'Search: Field OrganisationID / Operator LTE / Value $OrganisationID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationID',
                    Operator => 'LTE',
                    Value    => $OrganisationID2
                }
            ]
        },
        Expected => ['1',$OrganisationID1,$OrganisationID2]
    },
    {
        Name     => 'Search: Field OrganisationID / Operator GT / Value $OrganisationID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationID',
                    Operator => 'GT',
                    Value    => $OrganisationID2
                }
            ]
        },
        Expected => [$OrganisationID3]
    },
    {
        Name     => 'Search: Field OrganisationID / Operator GTE / Value $OrganisationID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationID',
                    Operator => 'GTE',
                    Value    => $OrganisationID2
                }
            ]
        },
        Expected => [$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Search: Field ID / Operator EQ / Value $OrganisationID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'EQ',
                    Value    => $OrganisationID2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field ID / Operator NE / Value $OrganisationID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'NE',
                    Value    => $OrganisationID2
                }
            ]
        },
        Expected => ['1',$OrganisationID1,$OrganisationID3]
    },
    {
        Name     => 'Search: Field ID / Operator IN / Value [$OrganisationID1,$OrganisationID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'IN',
                    Value    => [$OrganisationID1,$OrganisationID3]
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID3]
    },
    {
        Name     => 'Search: Field ID / Operator !IN / Value [$OrganisationID1,$OrganisationID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => '!IN',
                    Value    => [$OrganisationID1,$OrganisationID3]
                }
            ]
        },
        Expected => ['1',$OrganisationID2]
    },
    {
        Name     => 'Search: Field ID / Operator LT / Value $OrganisationID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'LT',
                    Value    => $OrganisationID2
                }
            ]
        },
        Expected => ['1',$OrganisationID1]
    },
    {
        Name     => 'Search: Field ID / Operator LTE / Value $OrganisationID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'LTE',
                    Value    => $OrganisationID2
                }
            ]
        },
        Expected => ['1',$OrganisationID1,$OrganisationID2]
    },
    {
        Name     => 'Search: Field ID / Operator GT / Value $OrganisationID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'GT',
                    Value    => $OrganisationID2
                }
            ]
        },
        Expected => [$OrganisationID3]
    },
    {
        Name     => 'Search: Field ID / Operator GTE / Value $OrganisationID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'GTE',
                    Value    => $OrganisationID2
                }
            ]
        },
        Expected => [$OrganisationID2,$OrganisationID3]
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Organisation',
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
        Name     => 'Sort: Field OrganisationID',
        Sort     => [
            {
                Field => 'OrganisationID'
            }
        ],
        Expected => ['1',$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Sort: Field OrganisationID / Direction ascending',
        Sort     => [
            {
                Field     => 'OrganisationID',
                Direction => 'ascending'
            }
        ],
        Expected => ['1',$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Sort: Field OrganisationID / Direction descending',
        Sort     => [
            {
                Field     => 'OrganisationID',
                Direction => 'descending'
            }
        ],
        Expected => [$OrganisationID3,$OrganisationID2,$OrganisationID1,'1']
    },
    {
        Name     => 'Sort: Field ID',
        Sort     => [
            {
                Field => 'ID'
            }
        ],
        Expected => ['1',$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Sort: Field ID / Direction ascending',
        Sort     => [
            {
                Field     => 'ID',
                Direction => 'ascending'
            }
        ],
        Expected => ['1',$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Sort: Field ID / Direction descending',
        Sort     => [
            {
                Field     => 'ID',
                Direction => 'descending'
            }
        ],
        Expected => [$OrganisationID3,$OrganisationID2,$OrganisationID1,'1']
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Organisation',
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
