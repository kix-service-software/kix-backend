# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::ConfigItem::ConfigItemID';

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
        ConfigItemID => {
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
            Field    => 'ConfigItemID',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'ConfigItemID',
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
            Field    => 'ConfigItemID',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'ConfigItemID',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field ConfigItemID / Operator EQ',
        Search       => {
            Field    => 'ConfigItemID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ci.id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ConfigItemID / Operator NE',
        Search       => {
            Field    => 'ConfigItemID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ci.id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ConfigItemID / Operator IN',
        Search       => {
            Field    => 'ConfigItemID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'ci.id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ConfigItemID / Operator !IN',
        Search       => {
            Field    => 'ConfigItemID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'ci.id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ConfigItemID / Operator LT',
        Search       => {
            Field    => 'ConfigItemID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ci.id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ConfigItemID / Operator GT',
        Search       => {
            Field    => 'ConfigItemID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ci.id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ConfigItemID / Operator LTE',
        Search       => {
            Field    => 'ConfigItemID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ci.id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ConfigItemID / Operator GTE',
        Search       => {
            Field    => 'ConfigItemID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ci.id >= 1'
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
                'ci.id = 1'
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
                'ci.id <> 1'
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
                'ci.id IN (1)'
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
                'ci.id NOT IN (1)'
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
                'ci.id < 1'
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
                'ci.id > 1'
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
                'ci.id <= 1'
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
                'ci.id >= 1'
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
        Name      => 'Sort: Attribute "ConfigItemID"',
        Attribute => 'ConfigItemID',
        Expected  => {
            'OrderBy' => [ 'ci.id' ],
            'Select'  => [ 'ci.id' ]
        }
    },
    {
        Name      => 'Sort: Attribute "ID"',
        Attribute => 'ID',
        Expected  => {
            'OrderBy' => [ 'ci.id' ],
            'Select'  => [ 'ci.id' ]
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

# prepare class mapping
my $ClassRef = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class         => 'ITSM::ConfigItem::Class',
    Name          => 'Building',
    NoPreferences => 1
);

## prepare test assets ##
# first asset
my $ConfigItemID1 = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
    ClassID => $ClassRef->{ItemID},
    UserID  => 1,
);
$Self->True(
    $ConfigItemID1,
    'Created first asset'
);
# second asset
my $ConfigItemID2 = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
    ClassID => $ClassRef->{ItemID},
    UserID  => 1,
);
$Self->True(
    $ConfigItemID2,
    'Created second asset'
);
# third asset
my $ConfigItemID3 = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
    ClassID => $ClassRef->{ItemID},
    UserID  => 1,
);
$Self->True(
    $ConfigItemID3,
    'Created third asset'
);

# discard config item object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['ITSMConfigItem'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field ConfigItemID / Operator EQ / Value $ConfigItemID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ConfigItemID',
                    Operator => 'EQ',
                    Value    => $ConfigItemID2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field ConfigItemID / Operator NE / Value $ConfigItemID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ConfigItemID',
                    Operator => 'NE',
                    Value    => $ConfigItemID2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID3]
    },
    {
        Name     => 'Search: Field ConfigItemID / Operator IN / Value [$ConfigItemID1,$ConfigItemID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ConfigItemID',
                    Operator => 'IN',
                    Value    => [$ConfigItemID1,$ConfigItemID3]
                }
            ]
        },
        Expected => [$ConfigItemID1, $ConfigItemID3]
    },
    {
        Name     => 'Search: Field ConfigItemID / Operator !IN / Value [$ConfigItemID1,$ConfigItemID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ConfigItemID',
                    Operator => '!IN',
                    Value    => [$ConfigItemID1,$ConfigItemID3]
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field ConfigItemID / Operator LT / Value $ConfigItemID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ConfigItemID',
                    Operator => 'LT',
                    Value    => $ConfigItemID2
                }
            ]
        },
        Expected => [$ConfigItemID1]
    },
    {
        Name     => 'Search: Field ConfigItemID / Operator GT / Value $ConfigItemID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ConfigItemID',
                    Operator => 'GT',
                    Value    => $ConfigItemID2
                }
            ]
        },
        Expected => [$ConfigItemID3]
    },
    {
        Name     => 'Search: Field ConfigItemID / Operator LTE / Value $ConfigItemID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ConfigItemID',
                    Operator => 'LTE',
                    Value    => $ConfigItemID2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field ConfigItemID / Operator GTE / Value $ConfigItemID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ConfigItemID',
                    Operator => 'GTE',
                    Value    => $ConfigItemID2
                }
            ]
        },
        Expected => [$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => 'Search: Field ID / Operator EQ / Value $ConfigItemID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'EQ',
                    Value    => $ConfigItemID2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field ID / Operator NE / Value $ConfigItemID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'NE',
                    Value    => $ConfigItemID2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID3]
    },
    {
        Name     => 'Search: Field ID / Operator IN / Value [$ConfigItemID1,$ConfigItemID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'IN',
                    Value    => [$ConfigItemID1,$ConfigItemID3]
                }
            ]
        },
        Expected => [$ConfigItemID1, $ConfigItemID3]
    },
    {
        Name     => 'Search: Field ID / Operator !IN / Value [$ConfigItemID1,$ConfigItemID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => '!IN',
                    Value    => [$ConfigItemID1,$ConfigItemID3]
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field ID / Operator LT / Value $ConfigItemID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'LT',
                    Value    => $ConfigItemID2
                }
            ]
        },
        Expected => [$ConfigItemID1]
    },
    {
        Name     => 'Search: Field ID / Operator GT / Value $ConfigItemID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'GT',
                    Value    => $ConfigItemID2
                }
            ]
        },
        Expected => [$ConfigItemID3]
    },
    {
        Name     => 'Search: Field ID / Operator LTE / Value $ConfigItemID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'LTE',
                    Value    => $ConfigItemID2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field ID / Operator GTE / Value $ConfigItemID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'GTE',
                    Value    => $ConfigItemID2
                }
            ]
        },
        Expected => [$ConfigItemID2,$ConfigItemID3]
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'ConfigItem',
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
        Name     => 'Sort: Field ConfigItemID',
        Sort     => [
            {
                Field => 'ConfigItemID'
            }
        ],
        Expected => [$ConfigItemID1,$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => 'Sort: Field ConfigItemID / Direction ascending',
        Sort     => [
            {
                Field     => 'ConfigItemID',
                Direction => 'ascending'
            }
        ],
        Expected => [$ConfigItemID1,$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => 'Sort: Field ConfigItemID / Direction descending',
        Sort     => [
            {
                Field     => 'ConfigItemID',
                Direction => 'descending'
            }
        ],
        Expected => [$ConfigItemID3,$ConfigItemID2,$ConfigItemID1]
    },
    {
        Name     => 'Sort: Field ID',
        Sort     => [
            {
                Field => 'ID'
            }
        ],
        Expected => [$ConfigItemID1,$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => 'Sort: Field ID / Direction ascending',
        Sort     => [
            {
                Field     => 'ID',
                Direction => 'ascending'
            }
        ],
        Expected => [$ConfigItemID1,$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => 'Sort: Field ID / Direction descending',
        Sort     => [
            {
                Field     => 'ID',
                Direction => 'descending'
            }
        ],
        Expected => [$ConfigItemID3,$ConfigItemID2,$ConfigItemID1]
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'ConfigItem',
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
