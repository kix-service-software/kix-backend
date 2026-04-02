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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Role::RoleID';

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
        'Attribute object can "' . $Method . q{"}
    );
}

# check GetSupportedAttributes
my $AttributeList = $AttributeObject->GetSupportedAttributes();
$Self->IsDeeply(
    $AttributeList,
    {
        RoleID => {
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
        },
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
            Field    => 'RoleID',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'RoleID',
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
            Field    => 'RoleID',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'RoleID',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field RoleID / Operator EQ',
        Search       => {
            Field    => 'RoleID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'r.id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field RoleID / Operator NE',
        Search       => {
            Field    => 'RoleID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'r.id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field RoleID / Operator IN',
        Search       => {
            Field    => 'RoleID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'r.id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field RoleID / Operator !IN',
        Search       => {
            Field    => 'RoleID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'r.id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field RoleID / Operator LT',
        Search       => {
            Field    => 'RoleID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'r.id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field RoleID / Operator LTE',
        Search       => {
            Field    => 'RoleID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'r.id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field RoleID / Operator GT',
        Search       => {
            Field    => 'RoleID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'r.id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field RoleID / Operator GTE',
        Search       => {
            Field    => 'RoleID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'r.id >= 1'
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
                'r.id = 1'
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
                'r.id <> 1'
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
                'r.id IN (1)'
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
                'r.id NOT IN (1)'
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
                'r.id < 1'
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
                'r.id <= 1'
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
                'r.id > 1'
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
                'r.id >= 1'
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
        Name      => 'Sort: Attribute "RoleID"',
        Attribute => 'RoleID',
        Expected  => {
            'Select'  => ['r.id AS SortAttr0'],
            'OrderBy' => ['SortAttr0']
        }
    },
    {
        Name      => 'Sort: Attribute "ID"',
        Attribute => 'ID',
        Expected  => {
            'Select'  => ['r.id AS SortAttr0'],
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


my %RoleList = $Kernel::OM->Get('Role')->RoleList();
my @RoleIDs = sort { $a <=> $b } keys %RoleList;

## prepare test roles ##
# first role
my $RoleID1 = $Kernel::OM->Get('Role')->RoleAdd(
    Name         => $Helper->GetRandomNumber(),
    UsageContext => Kernel::System::Role->USAGE_CONTEXT->{AGENT},
    ValidID      => 1,
    UserID       => 1,
);
$Self->True(
    $RoleID1,
    'Created first role'
);
# second role
my $RoleID2 = $Kernel::OM->Get('Role')->RoleAdd(
    Name         => $Helper->GetRandomNumber(),
    UsageContext => Kernel::System::Role->USAGE_CONTEXT->{CUSTOMER},
    ValidID      => 1,
    UserID       => 1,
);
$Self->True(
    $RoleID1,
    'Created second role'
);
# third role
my $RoleID3 = $Kernel::OM->Get('Role')->RoleAdd(
    Name         => $Helper->GetRandomNumber(),
    UsageContext => Kernel::System::Role->USAGE_CONTEXT->{CUSTOMER} + Kernel::System::Role->USAGE_CONTEXT->{AGENT},
    ValidID      => 1,
    UserID       => 1,
);
$Self->True(
    $RoleID1,
    'Created third role'
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Contact'],
);


# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field RoleID / Operator EQ / Value $RoleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'RoleID',
                    Operator => 'EQ',
                    Value    => $RoleID2
                }
            ]
        },
        Expected => [$RoleID2]
    },
    {
        Name     => 'Search: Field RoleID / Operator NE / Value $RoleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'RoleID',
                    Operator => 'NE',
                    Value    => $RoleID2
                }
            ]
        },
        Expected => [@RoleIDs,$RoleID1,$RoleID3]
    },
    {
        Name     => 'Search: Field RoleID / Operator IN / Value [$RoleID1,$RoleID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'RoleID',
                    Operator => 'IN',
                    Value    => [$RoleID1,$RoleID3]
                }
            ]
        },
        Expected => [$RoleID1,$RoleID3]
    },
    {
        Name     => 'Search: Field RoleID / Operator !IN / Value [$RoleID1,$RoleID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'RoleID',
                    Operator => '!IN',
                    Value    => [$RoleID1,$RoleID3]
                }
            ]
        },
        Expected => [@RoleIDs,$RoleID2]
    },
    {
        Name     => 'Search: Field RoleID / Operator LT / Value $RoleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'RoleID',
                    Operator => 'LT',
                    Value    => $RoleID2
                }
            ]
        },
        Expected => [@RoleIDs,$RoleID1]
    },
    {
        Name     => 'Search: Field RoleID / Operator LTE / Value $RoleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'RoleID',
                    Operator => 'LTE',
                    Value    => $RoleID2
                }
            ]
        },
        Expected => [@RoleIDs,$RoleID1,$RoleID2]
    },
    {
        Name     => 'Search: Field RoleID / Operator GT / Value $RoleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'RoleID',
                    Operator => 'GT',
                    Value    => $RoleID2
                }
            ]
        },
        Expected => [$RoleID3]
    },
    {
        Name     => 'Search: Field RoleID / Operator GTE / Value $RoleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'RoleID',
                    Operator => 'GTE',
                    Value    => $RoleID2
                }
            ]
        },
        Expected => [$RoleID2,$RoleID3]
    },
    {
        Name     => 'Search: Field ID / Operator EQ / Value $RoleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'EQ',
                    Value    => $RoleID2
                }
            ]
        },
        Expected => [$RoleID2]
    },
    {
        Name     => 'Search: Field ID / Operator NE / Value $RoleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'NE',
                    Value    => $RoleID2
                }
            ]
        },
        Expected => [@RoleIDs,$RoleID1,$RoleID3]
    },
    {
        Name     => 'Search: Field ID / Operator IN / Value [$RoleID1,$RoleID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'IN',
                    Value    => [$RoleID1,$RoleID3]
                }
            ]
        },
        Expected => [$RoleID1,$RoleID3]
    },
    {
        Name     => 'Search: Field ID / Operator !IN / Value [$RoleID1,$RoleID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => '!IN',
                    Value    => [$RoleID1,$RoleID3]
                }
            ]
        },
        Expected => [@RoleIDs,$RoleID2]
    },
    {
        Name     => 'Search: Field ID / Operator LT / Value $RoleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'LT',
                    Value    => $RoleID2
                }
            ]
        },
        Expected => [@RoleIDs,$RoleID1]
    },
    {
        Name     => 'Search: Field ID / Operator LTE / Value $RoleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'LTE',
                    Value    => $RoleID2
                }
            ]
        },
        Expected => [@RoleIDs,$RoleID1,$RoleID2]
    },
    {
        Name     => 'Search: Field ID / Operator GT / Value $RoleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'GT',
                    Value    => $RoleID2
                }
            ]
        },
        Expected => [$RoleID3]
    },
    {
        Name     => 'Search: Field ID / Operator GTE / Value $RoleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'GTE',
                    Value    => $RoleID2
                }
            ]
        },
        Expected => [$RoleID2,$RoleID3]
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Role',
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
        Name     => 'Sort: Field RoleID',
        Sort     => [
            {
                Field => 'RoleID'
            }
        ],
        Expected => [@RoleIDs,$RoleID1,$RoleID2,$RoleID3]
    },
    {
        Name     => 'Sort: Field RoleID / Direction ascending',
        Sort     => [
            {
                Field     => 'RoleID',
                Direction => 'ascending'
            }
        ],
        Expected => [@RoleIDs,$RoleID1,$RoleID2,$RoleID3]
    },
    {
        Name     => 'Sort: Field RoleID / Direction descending',
        Sort     => [
            {
                Field     => 'RoleID',
                Direction => 'descending'
            }
        ],
        Expected => [$RoleID3,$RoleID2,$RoleID1,reverse(@RoleIDs)]
    },
    {
        Name     => 'Sort: Field ID',
        Sort     => [
            {
                Field => 'ID'
            }
        ],
        Expected => [@RoleIDs,$RoleID1,$RoleID2,$RoleID3]
    },
    {
        Name     => 'Sort: Field ID / Direction ascending',
        Sort     => [
            {
                Field     => 'ID',
                Direction => 'ascending'
            }
        ],
        Expected => [@RoleIDs,$RoleID1,$RoleID2,$RoleID3]
    },
    {
        Name     => 'Sort: Field ID / Direction descending',
        Sort     => [
            {
                Field     => 'ID',
                Direction => 'descending'
            }
        ],
        Expected => [$RoleID3,$RoleID2,$RoleID1,reverse(@RoleIDs)]
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Role',
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
