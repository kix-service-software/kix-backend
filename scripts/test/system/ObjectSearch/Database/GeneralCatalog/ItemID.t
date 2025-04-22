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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::GeneralCatalog::ItemID';

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
        'Attribute object can "' . $Method . q{"}
    );
}

# check GetSupportedAttributes
my $AttributeList = $AttributeObject->GetSupportedAttributes();
$Self->IsDeeply(
    $AttributeList,
    {
        ItemID => {
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
            Field    => 'ItemID',
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
            Field    => 'ItemID',
            Operator => undef,
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'ItemID',
            Operator => 'Test',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field ItemID / Operator EQ',
        Search       => {
            Field    => 'ItemID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'gc.id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ItemID / Operator NE',
        Search       => {
            Field    => 'ItemID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'gc.id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ItemID / Operator IN',
        Search       => {
            Field    => 'ItemID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'gc.id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ItemID / Operator !IN',
        Search       => {
            Field    => 'ItemID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'gc.id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ItemID / Operator LT',
        Search       => {
            Field    => 'ItemID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'gc.id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ItemID / Operator LTE',
        Search       => {
            Field    => 'ItemID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'gc.id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ItemID / Operator GT',
        Search       => {
            Field    => 'ItemID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'gc.id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ItemID / Operator GTE',
        Search       => {
            Field    => 'ItemID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'gc.id >= 1'
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
                'gc.id = 1'
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
                'gc.id <> 1'
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
                'gc.id IN (1)'
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
                'gc.id NOT IN (1)'
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
                'gc.id < 1'
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
                'gc.id <= 1'
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
                'gc.id > 1'
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
                'gc.id >= 1'
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
        Name      => 'Sort: Attribute "ItemID"',
        Attribute => 'ItemID',
        Expected  => {
            'Select'  => ['gc.id'],
            'OrderBy' => ['gc.id']
        }
    },
    {
        Name      => 'Sort: Attribute "ID"',
        Attribute => 'ID',
        Expected  => {
            'Select'  => ['gc.id'],
            'OrderBy' => ['gc.id']
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

## prepare test general catalog ##
my $ItemID1 = $Kernel::OM->Get('GeneralCatalog')->ItemLookup(
    Class => 'ITSM::ConfigItem::Class',
    Name  => 'Computer'
);

$Self->True(
    $ItemID1,
    'ItemID: GET / Class ITSM::ConfigItem::Class / Name Computer'
);

my $ItemID2 = $Kernel::OM->Get('GeneralCatalog')->ItemLookup(
    Class => 'ITSM::ConfigItem::DeploymentState',
    Name  => 'Production'
);

$Self->True(
    $ItemID1,
    'ItemID: GET / Class ITSM::ConfigItem::DeploymentState / Name Productive'
);

my $ItemID3 = $Kernel::OM->Get('GeneralCatalog')->ItemLookup(
    Class => 'ITSM::Core::IncidentState',
    Name  => 'Incident'
);

$Self->True(
    $ItemID1,
    'ItemID: GET / Class ITSM::Core::IncidentState / Name Incident'
);

my @ItemIDs = $ObjectSearch->Search(
    ObjectType => 'GeneralCatalog',
    Result     => 'ARRAY',
    UserType   => 'Agent',
    UserID     => 1,
);

$Self->True(
    scalar( @ItemIDs ),
    'ItemID: GET / All Items'
);

# prepare result lists
# List for NE
my @TmpList = @ItemIDs;
splice(@TmpList, ($ItemID2-1),1);
my @List1 = @TmpList;

# List for !IN
@TmpList = @ItemIDs;
splice(@TmpList, ($ItemID1-1),1);
splice(@TmpList, ($ItemID3-1),1);
my @List2 = @TmpList;

# List for LT
@TmpList = @ItemIDs;
splice(@TmpList, $ItemID2-1);
my @List3 = @TmpList;

# List for LTE
@TmpList = @ItemIDs;
splice(@TmpList, $ItemID2);
my @List4 = @TmpList;

# List for GT
@TmpList = @ItemIDs;
splice(@TmpList, 0,$ItemID2);
my @List5 = @TmpList;

# List for GTE
@TmpList = @ItemIDs;
splice(@TmpList, 0, $ItemID2-1);
my @List6 = @TmpList;

# Reverse List
my @Reverse = reverse @ItemIDs;

# discard contact object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['GeneralCatalog'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field ItemID / Operator EQ / Value $ItemID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ItemID',
                    Operator => 'EQ',
                    Value    => $ItemID2
                }
            ]
        },
        Expected => [$ItemID2]
    },
    {
        Name     => 'Search: Field ItemID / Operator NE / Value $ItemID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ItemID',
                    Operator => 'NE',
                    Value    => $ItemID2
                }
            ]
        },
        Expected => \@List1
    },
    {
        Name     => 'Search: Field ItemID / Operator IN / Value [$ItemID1,$ItemID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ItemID',
                    Operator => 'IN',
                    Value    => [$ItemID1, $ItemID3]
                }
            ]
        },
        Expected => [$ItemID3, $ItemID1]
    },
    {
        Name     => 'Search: Field ItemID / Operator !IN / Value [$ItemID1,$ItemID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ItemID',
                    Operator => '!IN',
                    Value    => [$ItemID1, $ItemID3]
                }
            ]
        },
        Expected => \@List2
    },
    {
        Name     => 'Search: Field ItemID / Operator LT / Value $ItemID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ItemID',
                    Operator => 'LT',
                    Value    => $ItemID2
                }
            ]
        },
        Expected => \@List3
    },
    {
        Name     => 'Search: Field ItemID / Operator LTE / Value $ItemID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ItemID',
                    Operator => 'LTE',
                    Value    => $ItemID2
                }
            ]
        },
        Expected => \@List4
    },
    {
        Name     => 'Search: Field ItemID / Operator GT / Value $ItemID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ItemID',
                    Operator => 'GT',
                    Value    => $ItemID2
                }
            ]
        },
        Expected => \@List5
    },
    {
        Name     => 'Search: Field ItemID / Operator GTE / Value $ItemID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ItemID',
                    Operator => 'GTE',
                    Value    => $ItemID2
                }
            ]
        },
        Expected => \@List6
    },
    {
        Name     => 'Search: Field ID / Operator EQ / Value $ItemID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'EQ',
                    Value    => $ItemID2
                }
            ]
        },
        Expected => [$ItemID2]
    },
    {
        Name     => 'Search: Field ID / Operator NE / Value $ItemID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'NE',
                    Value    => $ItemID2
                }
            ]
        },
        Expected => \@List1
    },
    {
        Name     => 'Search: Field ID / Operator IN / Value [$ItemID1,$ItemID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'IN',
                    Value    => [$ItemID1,$ItemID3]
                }
            ]
        },
        Expected => [$ItemID3, $ItemID1]
    },
    {
        Name     => 'Search: Field ID / Operator !IN / Value [$ItemID1,$ItemID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => '!IN',
                    Value    => [$ItemID1,$ItemID3]
                }
            ]
        },
        Expected => \@List2
    },
    {
        Name     => 'Search: Field ID / Operator LT / Value $ItemID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'LT',
                    Value    => $ItemID2
                }
            ]
        },
        Expected => \@List3
    },
    {
        Name     => 'Search: Field ID / Operator LTE / Value $ItemID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'LTE',
                    Value    => $ItemID2
                }
            ]
        },
        Expected => \@List4
    },
    {
        Name     => 'Search: Field ID / Operator GT / Value $ItemID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'GT',
                    Value    => $ItemID2
                }
            ]
        },
        Expected => \@List5
    },
    {
        Name     => 'Search: Field ID / Operator GTE / Value $ItemID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'GTE',
                    Value    => $ItemID2
                }
            ]
        },
        Expected => \@List6
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'GeneralCatalog',
        Result     => 'ARRAY',
        Search     => $Test->{Search},
        UserType   => 'Agent',
        UserID     => 1,
        Limit      => $Test->{Limit}
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
        Name     => 'Sort: Field ItemID',
        Sort     => [
            {
                Field => 'ItemID'
            }
        ],
        Expected => \@ItemIDs
    },
    {
        Name     => 'Sort: Field ItemID / Direction ascending',
        Sort     => [
            {
                Field     => 'ItemID',
                Direction => 'ascending'
            }
        ],
        Expected => \@ItemIDs
    },
    {
        Name     => 'Sort: Field ItemID / Direction descending',
        Sort     => [
            {
                Field     => 'ItemID',
                Direction => 'descending'
            }
        ],
        Expected => \@Reverse
    },
    {
        Name     => 'Sort: Field ID',
        Sort     => [
            {
                Field => 'ID'
            }
        ],
        Expected => \@ItemIDs
    },
    {
        Name     => 'Sort: Field ID / Direction ascending',
        Sort     => [
            {
                Field     => 'ID',
                Direction => 'ascending'
            }
        ],
        Expected => \@ItemIDs
    },
    {
        Name     => 'Sort: Field ID / Direction descending',
        Sort     => [
            {
                Field     => 'ID',
                Direction => 'descending'
            }
        ],
        Expected => \@Reverse
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'GeneralCatalog',
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
