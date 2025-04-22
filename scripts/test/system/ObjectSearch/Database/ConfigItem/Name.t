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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::ConfigItem::Name';

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
        Name => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        }
    },
    'GetSupportedAttributes provides expected data'
);

# Quoting ESCAPE character backslash
my $QuoteBack = $Kernel::OM->Get('DB')->GetDatabaseFunction('QuoteBack');
my $Escape = "\\";
if ( $QuoteBack ) {
    $Escape =~ s/\\/$QuoteBack\\/g;
}

# Quoting single quote character
my $QuoteSingle = $Kernel::OM->Get('DB')->GetDatabaseFunction('QuoteSingle');

# Quoting semicolon character
my $QuoteSemicolon = $Kernel::OM->Get('DB')->GetDatabaseFunction('QuoteSemicolon');

# check if database is casesensitive
my $CaseSensitive = $Kernel::OM->Get('DB')->GetDatabaseFunction('CaseSensitive');

# get handling of order by null
my $OrderByNull = $Kernel::OM->Get('DB')->GetDatabaseFunction('OrderByNull') || '';

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
            Field    => 'Name',
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
            Field    => 'Name',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'Name',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field Name / Operator EQ',
        Search       => {
            Field    => 'Name',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [],
            'Where' => [
                $CaseSensitive ? 'LOWER(ci.name) = \'test\'' : 'ci.name = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator NE',
        Search       => {
            Field    => 'Name',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [],
            'Where' => [
                $CaseSensitive ? 'LOWER(ci.name) != \'test\'' : 'ci.name != \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator IN',
        Search       => {
            Field    => 'Name',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [],
            'Where' => [
                $CaseSensitive ? 'LOWER(ci.name) IN (\'test\')' : 'ci.name IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator !IN',
        Search       => {
            Field    => 'Name',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [],
            'Where' => [
                $CaseSensitive ? 'LOWER(ci.name) NOT IN (\'test\')' : 'ci.name NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator STARTSWITH',
        Search       => {
            Field    => 'Name',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [],
            'Where' => [
                $CaseSensitive ? 'LOWER(ci.name) LIKE \'test%\'' : 'ci.name LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator ENDSWITH',
        Search       => {
            Field    => 'Name',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [],
            'Where' => [
                $CaseSensitive ? 'LOWER(ci.name) LIKE \'%test\'' : 'ci.name LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator CONTAINS',
        Search       => {
            Field    => 'Name',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [],
            'Where' => [
                $CaseSensitive ? 'LOWER(ci.name) LIKE \'%test%\'' : 'ci.name LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator LIKE',
        Search       => {
            Field    => 'Name',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [],
            'Where' => [
                $CaseSensitive ? 'LOWER(ci.name) LIKE \'test\'' : 'ci.name LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator EQ / PreviousVersionSearch',
        Search       => {
            Field    => 'Name',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(civ.name) = \'test\'' : 'civ.name = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator NE / PreviousVersionSearch',
        Search       => {
            Field    => 'Name',
            Operator => 'NE',
            Value    => 'Test'
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(civ.name) != \'test\'' : 'civ.name != \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator IN / PreviousVersionSearch',
        Search       => {
            Field    => 'Name',
            Operator => 'IN',
            Value    => ['Test']
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(civ.name) IN (\'test\')' : 'civ.name IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator !IN / PreviousVersionSearch',
        Search       => {
            Field    => 'Name',
            Operator => '!IN',
            Value    => ['Test']
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(civ.name) NOT IN (\'test\')' : 'civ.name NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator STARTSWITH / PreviousVersionSearch',
        Search       => {
            Field    => 'Name',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(civ.name) LIKE \'test%\'' : 'civ.name LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator ENDSWITH / PreviousVersionSearch',
        Search       => {
            Field    => 'Name',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(civ.name) LIKE \'%test\'' : 'civ.name LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator CONTAINS / PreviousVersionSearch',
        Search       => {
            Field    => 'Name',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(civ.name) LIKE \'%test%\'' : 'civ.name LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator LIKE / PreviousVersionSearch',
        Search       => {
            Field    => 'Name',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(civ.name) LIKE \'test\'' : 'civ.name LIKE \'test\''
            ]
        }
    }
);
for my $Test ( @SearchTests ) {
    my $Result = $AttributeObject->Search(
        Search       => $Test->{Search},
        Flags        => $Test->{Flags},
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
        Name      => 'Sort: Attribute "Name"',
        Attribute => 'Name',
        Expected  => {
            'OrderBy' => [
                'LOWER(ci.name)'
            ],
            'Select'  => [
                'ci.name'
            ]
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

# prepare depl state mapping
my $DeplStateRef = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class => 'ITSM::ConfigItem::DeploymentState',
    Name  => 'Production',
);

# prepare inci state mapping
my $InciStateRef = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class => 'ITSM::Core::IncidentState',
    Name  => 'Operational',
);

# prepare name mapping
my $ConfigItemName1 = 'Test001';
my $ConfigItemName2 = 'Test002';
my $ConfigItemName3 = 'Test003';

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
my $VersionID1 = $Kernel::OM->Get('ITSMConfigItem')->VersionAdd(
    ConfigItemID => $ConfigItemID1,
    Name         => $ConfigItemName1,
    DefinitionID => 1,
    DeplStateID  => $DeplStateRef->{ItemID},
    InciStateID  => $InciStateRef->{ItemID},
    UserID       => 1,
);
$Self->True(
    $VersionID1,
    'Created version for first asset'
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
my $VersionID2_1 = $Kernel::OM->Get('ITSMConfigItem')->VersionAdd(
    ConfigItemID => $ConfigItemID2,
    Name         => $ConfigItemName2,
    DefinitionID => 1,
    DeplStateID  => $DeplStateRef->{ItemID},
    InciStateID  => $InciStateRef->{ItemID},
    UserID       => 1,
);
$Self->True(
    $VersionID2_1,
    'Created version for second asset'
);
my $VersionID2_2 = $Kernel::OM->Get('ITSMConfigItem')->VersionAdd(
    ConfigItemID => $ConfigItemID2,
    Name         => $ConfigItemName3,
    DefinitionID => 1,
    DeplStateID  => $DeplStateRef->{ItemID},
    InciStateID  => $InciStateRef->{ItemID},
    UserID       => 1,
);
$Self->True(
    $VersionID2_2,
    'Created second version for second asset'
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
        Name     => 'Search: Field Name / Operator EQ / Value $ConfigItemName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'EQ',
                    Value    => $ConfigItemName2
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field Name / Operator NE / Value $ConfigItemName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'NE',
                    Value    => $ConfigItemName2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Name / Operator IN / Value [$ConfigItemName1,$ConfigItemName3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'IN',
                    Value    => [$ConfigItemName1,$ConfigItemName3]
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Name / Operator !IN / Value [$ConfigItemName1,$ConfigItemName3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => '!IN',
                    Value    => [$ConfigItemName1,$ConfigItemName3]
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field Name / Operator STARTSWITH / Value $ConfigItemName3',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'STARTSWITH',
                    Value    => $ConfigItemName3
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Name / Operator STARTSWITH / Value substr($ConfigItemName3,0,4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'STARTSWITH',
                    Value    => substr($ConfigItemName3,0,4)
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Name / Operator ENDSWITH / Value $ConfigItemName3',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'ENDSWITH',
                    Value    => $ConfigItemName3
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Name / Operator ENDSWITH / Value substr($ConfigItemName3,-5)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'ENDSWITH',
                    Value    => substr($ConfigItemName3,-5)
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Name / Operator CONTAINS / Value $ConfigItemName3',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'CONTAINS',
                    Value    => $ConfigItemName3
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Name / Operator CONTAINS / Value substr($ConfigItemName3,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'CONTAINS',
                    Value    => substr($ConfigItemName3,2,-2)
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Name / Operator LIKE / Value $ConfigItemName3',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'LIKE',
                    Value    => $ConfigItemName3
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Name / Operator EQ / Value $ConfigItemName2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'Name',
                    Operator => 'EQ',
                    Value    => $ConfigItemName2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Name / Operator NE / Value $ConfigItemName2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'Name',
                    Operator => 'NE',
                    Value    => $ConfigItemName2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Name / Operator IN / Value [$ConfigItemName1,$ConfigItemName3] / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'Name',
                    Operator => 'IN',
                    Value    => [$ConfigItemName1,$ConfigItemName3]
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Name / Operator !IN / Value [$ConfigItemName1,$ConfigItemName3] / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'Name',
                    Operator => '!IN',
                    Value    => [$ConfigItemName1,$ConfigItemName3]
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Name / Operator STARTSWITH / Value $ConfigItemName3 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'Name',
                    Operator => 'STARTSWITH',
                    Value    => $ConfigItemName3
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Name / Operator STARTSWITH / Value substr($ConfigItemName3,0,4) / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'Name',
                    Operator => 'STARTSWITH',
                    Value    => substr($ConfigItemName3,0,4)
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Name / Operator ENDSWITH / Value $ConfigItemName3 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'Name',
                    Operator => 'ENDSWITH',
                    Value    => $ConfigItemName3
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Name / Operator ENDSWITH / Value substr($ConfigItemName3,-5) / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'Name',
                    Operator => 'ENDSWITH',
                    Value    => substr($ConfigItemName3,-5)
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Name / Operator CONTAINS / Value $ConfigItemName3 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'Name',
                    Operator => 'CONTAINS',
                    Value    => $ConfigItemName3
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Name / Operator CONTAINS / Value substr($ConfigItemName3,2,-2) / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'Name',
                    Operator => 'CONTAINS',
                    Value    => substr($ConfigItemName3,2,-2)
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Name / Operator LIKE / Value $ConfigItemName3 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'Name',
                    Operator => 'LIKE',
                    Value    => $ConfigItemName3
                }
            ]
        },
        Expected => [$ConfigItemID2]
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
        Name     => 'Sort: Field Name',
        Sort     => [
            {
                Field => 'Name'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ConfigItemID1, $ConfigItemID2, $ConfigItemID3] : [$ConfigItemID3, $ConfigItemID1, $ConfigItemID2]
    },
    {
        Name     => 'Sort: Field Name / Direction ascending',
        Sort     => [
            {
                Field     => 'Name',
                Direction => 'ascending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ConfigItemID1, $ConfigItemID2, $ConfigItemID3] : [$ConfigItemID3, $ConfigItemID1, $ConfigItemID2]
    },
    {
        Name     => 'Sort: Field Name / Direction descending',
        Sort     => [
            {
                Field     => 'Name',
                Direction => 'descending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ConfigItemID3,$ConfigItemID2,$ConfigItemID1] : [$ConfigItemID2, $ConfigItemID1, $ConfigItemID3]
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
