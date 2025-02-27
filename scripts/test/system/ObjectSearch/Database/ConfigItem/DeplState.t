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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::ConfigItem::DeplState';

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
        DeplStateID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ', 'NE', 'IN','!IN','GT','GTE','LT','LTE'],
            ValueType    => 'NUMERIC'
        },
        DeplStateIDs => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ', 'NE', 'IN','!IN','GT','GTE','LT','LTE'],
            ValueType    => 'NUMERIC'
        },
        DeplState => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ', 'NE', 'IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        }
    },
    'GetSupportedAttributes provides expected data'
);

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
            Field    => 'DeplStateID',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'DeplStateID',
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
            Field    => 'DeplStateID',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'DeplStateID',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field DeplStateID / Operator EQ',
        Search       => {
            Field    => 'DeplStateID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_depl_state_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplStateID / Operator NE',
        Search       => {
            Field    => 'DeplStateID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_depl_state_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplStateID / Operator IN',
        Search       => {
            Field    => 'DeplStateID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_depl_state_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplStateID / Operator !IN',
        Search       => {
            Field    => 'DeplStateID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_depl_state_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplStateID / Operator LT',
        Search       => {
            Field    => 'DeplStateID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_depl_state_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplStateID / Operator GT',
        Search       => {
            Field    => 'DeplStateID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_depl_state_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplStateID / Operator LTE',
        Search       => {
            Field    => 'DeplStateID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_depl_state_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplStateID / Operator GTE',
        Search       => {
            Field    => 'DeplStateID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_depl_state_id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplStateIDs / Operator EQ',
        Search       => {
            Field    => 'DeplStateIDs',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_depl_state_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplStateIDs / Operator NE',
        Search       => {
            Field    => 'DeplStateIDs',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_depl_state_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplStateIDs / Operator IN',
        Search       => {
            Field    => 'DeplStateIDs',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_depl_state_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplStateIDs / Operator !IN',
        Search       => {
            Field    => 'DeplStateIDs',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_depl_state_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplStateIDs / Operator LT',
        Search       => {
            Field    => 'DeplStateIDs',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_depl_state_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplStateIDs / Operator GT',
        Search       => {
            Field    => 'DeplStateIDs',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_depl_state_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplStateIDs / Operator LTE',
        Search       => {
            Field    => 'DeplStateIDs',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_depl_state_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplStateIDs / Operator GTE',
        Search       => {
            Field    => 'DeplStateIDs',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_depl_state_id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplState / Operator EQ',
        Search       => {
            Field    => 'DeplState',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN general_catalog cids ON cids.id = ci.cur_depl_state_id AND general_catalog_class = \'ITSM::ConfigItem::DeploymentState\''
            ],
            'Where' => [
                'cids.name = \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplState / Operator NE',
        Search       => {
            Field    => 'DeplState',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN general_catalog cids ON cids.id = ci.cur_depl_state_id AND general_catalog_class = \'ITSM::ConfigItem::DeploymentState\''
            ],
            'Where' => [
                'cids.name != \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplState / Operator IN',
        Search       => {
            Field    => 'DeplState',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN general_catalog cids ON cids.id = ci.cur_depl_state_id AND general_catalog_class = \'ITSM::ConfigItem::DeploymentState\''
            ],
            'Where' => [
                'cids.name IN (\'Test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplState / Operator !IN',
        Search       => {
            Field    => 'DeplState',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN general_catalog cids ON cids.id = ci.cur_depl_state_id AND general_catalog_class = \'ITSM::ConfigItem::DeploymentState\''
            ],
            'Where' => [
                'cids.name NOT IN (\'Test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplState / Operator STARTSWITH',
        Search       => {
            Field    => 'DeplState',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN general_catalog cids ON cids.id = ci.cur_depl_state_id AND general_catalog_class = \'ITSM::ConfigItem::DeploymentState\''
            ],
            'Where' => [
                'cids.name LIKE \'Test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplState / Operator ENDSWITH',
        Search       => {
            Field    => 'DeplState',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN general_catalog cids ON cids.id = ci.cur_depl_state_id AND general_catalog_class = \'ITSM::ConfigItem::DeploymentState\''
            ],
            'Where' => [
                'cids.name LIKE \'%Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplState / Operator CONTAINS',
        Search       => {
            Field    => 'DeplState',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN general_catalog cids ON cids.id = ci.cur_depl_state_id AND general_catalog_class = \'ITSM::ConfigItem::DeploymentState\''
            ],
            'Where' => [
                'cids.name LIKE \'%Test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplState / Operator LIKE',
        Search       => {
            Field    => 'DeplState',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN general_catalog cids ON cids.id = ci.cur_depl_state_id AND general_catalog_class = \'ITSM::ConfigItem::DeploymentState\''
            ],
            'Where' => [
                'cids.name LIKE \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplStateID / Operator EQ / PreviousVersionSearch',
        Search       => {
            Field    => 'DeplStateID',
            Operator => 'EQ',
            Value    => '1'
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join'  => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id'
            ],
            'Where' => [
                'civ.depl_state_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplStateID / Operator NE / PreviousVersionSearch',
        Search       => {
            Field    => 'DeplStateID',
            Operator => 'NE',
            Value    => '1'
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join'  => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id'
            ],
            'Where' => [
                'civ.depl_state_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplStateID / Operator IN / PreviousVersionSearch',
        Search       => {
            Field    => 'DeplStateID',
            Operator => 'IN',
            Value    => ['1']
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join'  => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id'
            ],
            'Where' => [
                'civ.depl_state_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplStateID / Operator !IN / PreviousVersionSearch',
        Search       => {
            Field    => 'DeplStateID',
            Operator => '!IN',
            Value    => ['1']
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join'  => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id'
            ],
            'Where' => [
                'civ.depl_state_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplStateID / Operator LT / PreviousVersionSearch',
        Search       => {
            Field    => 'DeplStateID',
            Operator => 'LT',
            Value    => '1'
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join'  => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id'
            ],
            'Where' => [
                'civ.depl_state_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplStateID / Operator GT / PreviousVersionSearch',
        Search       => {
            Field    => 'DeplStateID',
            Operator => 'GT',
            Value    => '1'
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join'  => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id'
            ],
            'Where' => [
                'civ.depl_state_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplStateID / Operator LTE / PreviousVersionSearch',
        Search       => {
            Field    => 'DeplStateID',
            Operator => 'LTE',
            Value    => '1'
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join'  => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id'
            ],
            'Where' => [
                'civ.depl_state_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplStateID / Operator GTE / PreviousVersionSearch',
        Search       => {
            Field    => 'DeplStateID',
            Operator => 'GTE',
            Value    => '1'
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join'  => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id'
            ],
            'Where' => [
                'civ.depl_state_id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplStateIDs / Operator EQ / PreviousVersionSearch',
        Search       => {
            Field    => 'DeplStateIDs',
            Operator => 'EQ',
            Value    => '1'
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join'  => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id'
            ],
            'Where' => [
                'civ.depl_state_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplStateIDs / Operator NE / PreviousVersionSearch',
        Search       => {
            Field    => 'DeplStateIDs',
            Operator => 'NE',
            Value    => '1'
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join'  => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id'
            ],
            'Where' => [
                'civ.depl_state_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplStateIDs / Operator IN / PreviousVersionSearch',
        Search       => {
            Field    => 'DeplStateIDs',
            Operator => 'IN',
            Value    => ['1']
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join'  => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id'
            ],
            'Where' => [
                'civ.depl_state_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplStateIDs / Operator !IN / PreviousVersionSearch',
        Search       => {
            Field    => 'DeplStateIDs',
            Operator => '!IN',
            Value    => ['1']
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join'  => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id'
            ],
            'Where' => [
                'civ.depl_state_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplStateIDs / Operator LT / PreviousVersionSearch',
        Search       => {
            Field    => 'DeplStateIDs',
            Operator => 'LT',
            Value    => '1'
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join'  => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id'
            ],
            'Where' => [
                'civ.depl_state_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplStateIDs / Operator GT / PreviousVersionSearch',
        Search       => {
            Field    => 'DeplStateIDs',
            Operator => 'GT',
            Value    => '1'
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join'  => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id'
            ],
            'Where' => [
                'civ.depl_state_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplStateIDs / Operator LTE / PreviousVersionSearch',
        Search       => {
            Field    => 'DeplStateIDs',
            Operator => 'LTE',
            Value    => '1'
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join'  => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id'
            ],
            'Where' => [
                'civ.depl_state_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplStateIDs / Operator GTE / PreviousVersionSearch',
        Search       => {
            Field    => 'DeplStateIDs',
            Operator => 'GTE',
            Value    => '1'
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join'  => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id'
            ],
            'Where' => [
                'civ.depl_state_id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplState / Operator EQ / PreviousVersionSearch',
        Search       => {
            Field    => 'DeplState',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                'INNER JOIN general_catalog civds ON civds.id = civ.depl_state_id AND general_catalog_class = \'ITSM::ConfigItem::DeploymentState\''
            ],
            'Where' => [
                'civds.name = \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplState / Operator NE / PreviousVersionSearch',
        Search       => {
            Field    => 'DeplState',
            Operator => 'NE',
            Value    => 'Test'
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                'INNER JOIN general_catalog civds ON civds.id = civ.depl_state_id AND general_catalog_class = \'ITSM::ConfigItem::DeploymentState\''
            ],
            'Where' => [
                'civds.name != \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplState / Operator IN / PreviousVersionSearch',
        Search       => {
            Field    => 'DeplState',
            Operator => 'IN',
            Value    => ['Test']
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                'INNER JOIN general_catalog civds ON civds.id = civ.depl_state_id AND general_catalog_class = \'ITSM::ConfigItem::DeploymentState\''
            ],
            'Where' => [
                'civds.name IN (\'Test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplState / Operator !IN / PreviousVersionSearch',
        Search       => {
            Field    => 'DeplState',
            Operator => '!IN',
            Value    => ['Test']
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                'INNER JOIN general_catalog civds ON civds.id = civ.depl_state_id AND general_catalog_class = \'ITSM::ConfigItem::DeploymentState\''
            ],
            'Where' => [
                'civds.name NOT IN (\'Test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplState / Operator STARTSWITH / PreviousVersionSearch',
        Search       => {
            Field    => 'DeplState',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                'INNER JOIN general_catalog civds ON civds.id = civ.depl_state_id AND general_catalog_class = \'ITSM::ConfigItem::DeploymentState\''
            ],
            'Where' => [
                'civds.name LIKE \'Test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplState / Operator ENDSWITH / PreviousVersionSearch',
        Search       => {
            Field    => 'DeplState',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                'INNER JOIN general_catalog civds ON civds.id = civ.depl_state_id AND general_catalog_class = \'ITSM::ConfigItem::DeploymentState\''
            ],
            'Where' => [
                'civds.name LIKE \'%Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplState / Operator CONTAINS / PreviousVersionSearch',
        Search       => {
            Field    => 'DeplState',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                'INNER JOIN general_catalog civds ON civds.id = civ.depl_state_id AND general_catalog_class = \'ITSM::ConfigItem::DeploymentState\''
            ],
            'Where' => [
                'civds.name LIKE \'%Test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DeplState / Operator LIKE / PreviousVersionSearch',
        Search       => {
            Field    => 'DeplState',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                'INNER JOIN general_catalog civds ON civds.id = civ.depl_state_id AND general_catalog_class = \'ITSM::ConfigItem::DeploymentState\''
            ],
            'Where' => [
                'civds.name LIKE \'Test\''
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
        Name      => 'Sort: Attribute "DeplStateID"',
        Attribute => 'DeplStateID',
        Expected  => {
            'Join'    => [],
            'OrderBy' => [
                'ci.cur_depl_state_id'
            ],
            'Select'  => [
                'ci.cur_depl_state_id'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "DeplStateIDs"',
        Attribute => 'DeplStateID',
        Expected  => {
            'Join'    => [],
            'OrderBy' => [
                'ci.cur_depl_state_id'
            ],
            'Select'  => [
                'ci.cur_depl_state_id'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "DeplState"',
        Attribute => 'DeplState',
        Expected  => {
            'Join'    => [
                'LEFT OUTER JOIN general_catalog cids ON cids.id = ci.cur_depl_state_id AND general_catalog_class = \'ITSM::ConfigItem::DeploymentState\'',
                'LEFT OUTER JOIN translation_pattern tlp0 ON tlp0.value = cids.name',
                'LEFT OUTER JOIN translation_language tl0 ON tl0.pattern_id = tlp0.id AND tl0.language = \'en\''
            ],
            'OrderBy' => [
                'TranslateDeplState'
            ],
            'Select'  => [
                'LOWER(COALESCE(tl0.value, cids.name)) AS TranslateDeplState'
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

# load translations for given language
my @Translations = $Kernel::OM->Get('Translation')->TranslationList();
my %TranslationsDE;
for my $Translation ( @Translations ) {
    $TranslationsDE{ $Translation->{Pattern} } = $Translation->{Languages}->{'de'};
}

# prepare class mapping
my $ClassRef = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class         => 'ITSM::ConfigItem::Class',
    Name          => 'Building',
    NoPreferences => 1
);

# prepare depl state mapping
my $ItemDataRef1 = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class         => 'ITSM::ConfigItem::DeploymentState',
    Name          => 'Maintenance',
    NoPreferences => 1
);
my $DeplStateID1   = $ItemDataRef1->{ItemID};
my $DeplStateName1 = $ItemDataRef1->{Name};
$Self->True(
    $DeplStateID1,
    'DeplState 1 has id'
);
$Self->Is(
    $DeplStateName1,
    'Maintenance',
    'DeplState 1 has expected name'
);
$Self->Is(
    $TranslationsDE{ $DeplStateName1 },
    'Wartung',
    'DeplState 1 has expected translation (de)'
);
my $ItemDataRef2 = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class         => 'ITSM::ConfigItem::DeploymentState',
    Name          => 'Production',
    NoPreferences => 1
);
my $DeplStateID2   = $ItemDataRef2->{ItemID};
my $DeplStateName2 = $ItemDataRef2->{Name};
$Self->True(
    $DeplStateID2,
    'DeplState 2 has id'
);
$Self->Is(
    $DeplStateName2,
    'Production',
    'DeplState 2 has expected name'
);
$Self->Is(
    $TranslationsDE{ $DeplStateName2 },
    'Produktiv',
    'DeplState 2 has expected translation (de)'
);
my $ItemDataRef3 = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class         => 'ITSM::ConfigItem::DeploymentState',
    Name          => 'Retired',
    NoPreferences => 1
);
my $DeplStateID3   = $ItemDataRef3->{ItemID};
my $DeplStateName3 = $ItemDataRef3->{Name};
$Self->True(
    $DeplStateID3,
    'DeplState 3 has id'
);
$Self->Is(
    $DeplStateName3,
    'Retired',
    'DeplState 3 has expected name'
);
$Self->Is(
    $TranslationsDE{ $DeplStateName3 },
    'Außer Dienst',
    'DeplState 3 has expected translation (de)'
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
my $VersionID1 = $Kernel::OM->Get('ITSMConfigItem')->VersionAdd(
    ConfigItemID => $ConfigItemID1,
    Name         => $Helper->GetRandomID(),
    DefinitionID => 1,
    DeplStateID  => $DeplStateID1,
    InciStateID  => 1,
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
    Name         => $Helper->GetRandomID(),
    DefinitionID => 1,
    DeplStateID  => $DeplStateID2,
    InciStateID  => 1,
    UserID       => 1,
);
$Self->True(
    $VersionID2_1,
    'Created version for second asset'
);
my $VersionID2_2 = $Kernel::OM->Get('ITSMConfigItem')->VersionAdd(
    ConfigItemID => $ConfigItemID2,
    Name         => $Helper->GetRandomID(),
    DefinitionID => 1,
    DeplStateID  => $DeplStateID3,
    InciStateID  => 1,
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
        Name     => 'Search: Field DeplStateID / Operator EQ / Value $DeplStateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'DeplStateID',
                    Operator => 'EQ',
                    Value    => $DeplStateID2
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field DeplStateID / Operator NE / Value $DeplStateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'DeplStateID',
                    Operator => 'NE',
                    Value    => $DeplStateID2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplStateID / Operator IN / Value [$DeplStateID1,$DeplStateID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'DeplStateID',
                    Operator => 'IN',
                    Value    => [$DeplStateID1,$DeplStateID3]
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplStateID / Operator !IN / Value [$DeplStateID1,$DeplStateID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'DeplStateID',
                    Operator => '!IN',
                    Value    => [$DeplStateID1,$DeplStateID3]
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field DeplStateID / Operator LT / Value $DeplStateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'DeplStateID',
                    Operator => 'LT',
                    Value    => $DeplStateID2
                }
            ]
        },
        Expected => [$ConfigItemID1]
    },
    {
        Name     => 'Search: Field DeplStateID / Operator GT / Value $DeplStateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'DeplStateID',
                    Operator => 'GT',
                    Value    => $DeplStateID2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplStateID / Operator LTE / Value $DeplStateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'DeplStateID',
                    Operator => 'LTE',
                    Value    => $DeplStateID2
                }
            ]
        },
        Expected => [$ConfigItemID1]
    },
    {
        Name     => 'Search: Field DeplStateID / Operator GTE / Value $DeplStateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'DeplStateID',
                    Operator => 'GTE',
                    Value    => $DeplStateID2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplStateIDs / Operator EQ / Value $DeplStateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'DeplStateIDs',
                    Operator => 'EQ',
                    Value    => $DeplStateID2
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field DeplStateIDs / Operator NE / Value $DeplStateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'DeplStateIDs',
                    Operator => 'NE',
                    Value    => $DeplStateID2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplStateIDs / Operator IN / Value [$DeplStateID1,$DeplStateID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'DeplStateIDs',
                    Operator => 'IN',
                    Value    => [$DeplStateID1,$DeplStateID3]
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplStateIDs / Operator !IN / Value [$DeplStateID1,$DeplStateID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'DeplStateIDs',
                    Operator => '!IN',
                    Value    => [$DeplStateID1,$DeplStateID3]
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field DeplStateIDs / Operator LT / Value $DeplStateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'DeplStateIDs',
                    Operator => 'LT',
                    Value    => $DeplStateID2
                }
            ]
        },
        Expected => [$ConfigItemID1]
    },
    {
        Name     => 'Search: Field DeplStateIDs / Operator GT / Value $DeplStateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'DeplStateIDs',
                    Operator => 'GT',
                    Value    => $DeplStateID2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplStateIDs / Operator LTE / Value $DeplStateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'DeplStateIDs',
                    Operator => 'LTE',
                    Value    => $DeplStateID2
                }
            ]
        },
        Expected => [$ConfigItemID1]
    },
    {
        Name     => 'Search: Field DeplStateIDs / Operator GTE / Value $DeplStateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'DeplStateIDs',
                    Operator => 'GTE',
                    Value    => $DeplStateID2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplState / Operator EQ / Value $DeplStateName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'DeplState',
                    Operator => 'EQ',
                    Value    => $DeplStateName2
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field DeplState / Operator NE / Value $DeplStateName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'DeplState',
                    Operator => 'NE',
                    Value    => $DeplStateName2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplState / Operator IN / Value [$DeplStateName1,$DeplStateName3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'DeplState',
                    Operator => 'IN',
                    Value    => [$DeplStateName1,$DeplStateName3]
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplState / Operator !IN / Value [$DeplStateName1,$DeplStateName3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'DeplState',
                    Operator => '!IN',
                    Value    => [$DeplStateName1,$DeplStateName3]
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field DeplState / Operator STARTSWITH / Value $DeplStateName3',
        Search   => {
            'AND' => [
                {
                    Field    => 'DeplState',
                    Operator => 'STARTSWITH',
                    Value    => $DeplStateName3
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplState / Operator STARTSWITH / Value substr($DeplStateName3,0,4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'DeplState',
                    Operator => 'STARTSWITH',
                    Value    => substr($DeplStateName3,0,4)
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplState / Operator ENDSWITH / Value $DeplStateName3',
        Search   => {
            'AND' => [
                {
                    Field    => 'DeplState',
                    Operator => 'ENDSWITH',
                    Value    => $DeplStateName3
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplState / Operator ENDSWITH / Value substr($DeplStateName3,-5)',
        Search   => {
            'AND' => [
                {
                    Field    => 'DeplState',
                    Operator => 'ENDSWITH',
                    Value    => substr($DeplStateName3,-5)
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplState / Operator CONTAINS / Value $DeplStateName3',
        Search   => {
            'AND' => [
                {
                    Field    => 'DeplState',
                    Operator => 'CONTAINS',
                    Value    => $DeplStateName3
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplState / Operator CONTAINS / Value substr($DeplStateName3,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'DeplState',
                    Operator => 'CONTAINS',
                    Value    => substr($DeplStateName3,2,-2)
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplState / Operator LIKE / Value $DeplStateName3',
        Search   => {
            'AND' => [
                {
                    Field    => 'DeplState',
                    Operator => 'LIKE',
                    Value    => $DeplStateName3
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplStateID / Operator EQ / Value $DeplStateID2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'DeplStateID',
                    Operator => 'EQ',
                    Value    => $DeplStateID2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplStateID / Operator NE / Value $DeplStateID2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'DeplStateID',
                    Operator => 'NE',
                    Value    => $DeplStateID2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplStateID / Operator IN / Value [$DeplStateID1,$DeplStateID3] / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'DeplStateID',
                    Operator => 'IN',
                    Value    => [$DeplStateID1,$DeplStateID3]
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplStateID / Operator !IN / Value [$DeplStateID1,$DeplStateID3] / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'DeplStateID',
                    Operator => '!IN',
                    Value    => [$DeplStateID1,$DeplStateID3]
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplStateID / Operator LT / Value $DeplStateID2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'DeplStateID',
                    Operator => 'LT',
                    Value    => $DeplStateID2
                }
            ]
        },
        Expected => [$ConfigItemID1]
    },
    {
        Name     => 'Search: Field DeplStateID / Operator GT / Value $DeplStateID2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'DeplStateID',
                    Operator => 'GT',
                    Value    => $DeplStateID2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplStateID / Operator LTE / Value $DeplStateID2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'DeplStateID',
                    Operator => 'LTE',
                    Value    => $DeplStateID2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplStateID / Operator GTE / Value $DeplStateID2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'DeplStateID',
                    Operator => 'GTE',
                    Value    => $DeplStateID2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplStateIDs / Operator EQ / Value $DeplStateID2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'DeplStateIDs',
                    Operator => 'EQ',
                    Value    => $DeplStateID2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplStateIDs / Operator NE / Value $DeplStateID2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'DeplStateIDs',
                    Operator => 'NE',
                    Value    => $DeplStateID2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplStateIDs / Operator IN / Value [$DeplStateID1,$DeplStateID3] / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'DeplStateIDs',
                    Operator => 'IN',
                    Value    => [$DeplStateID1,$DeplStateID3]
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplStateIDs / Operator !IN / Value [$DeplStateID1,$DeplStateID3] / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'DeplStateIDs',
                    Operator => '!IN',
                    Value    => [$DeplStateID1,$DeplStateID3]
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplStateIDs / Operator LT / Value $DeplStateID2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'DeplStateIDs',
                    Operator => 'LT',
                    Value    => $DeplStateID2
                }
            ]
        },
        Expected => [$ConfigItemID1]
    },
    {
        Name     => 'Search: Field DeplStateIDs / Operator GT / Value $DeplStateID2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'DeplStateIDs',
                    Operator => 'GT',
                    Value    => $DeplStateID2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplStateIDs / Operator LTE / Value $DeplStateID2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'DeplStateIDs',
                    Operator => 'LTE',
                    Value    => $DeplStateID2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplStateIDs / Operator GTE / Value $DeplStateID2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'DeplStateIDs',
                    Operator => 'GTE',
                    Value    => $DeplStateID2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplState / Operator EQ / Value $DeplStateName2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'DeplState',
                    Operator => 'EQ',
                    Value    => $DeplStateName2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplState / Operator NE / Value $DeplStateName2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'DeplState',
                    Operator => 'NE',
                    Value    => $DeplStateName2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplState / Operator IN / Value [$DeplStateName1,$DeplStateName3] / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'DeplState',
                    Operator => 'IN',
                    Value    => [$DeplStateName1,$DeplStateName3]
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplState / Operator !IN / Value [$DeplStateName1,$DeplStateName3] / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'DeplState',
                    Operator => '!IN',
                    Value    => [$DeplStateName1,$DeplStateName3]
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplState / Operator STARTSWITH / Value $DeplStateName3 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'DeplState',
                    Operator => 'STARTSWITH',
                    Value    => $DeplStateName3
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplState / Operator STARTSWITH / Value substr($DeplStateName3,0,4) / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'DeplState',
                    Operator => 'STARTSWITH',
                    Value    => substr($DeplStateName3,0,4)
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplState / Operator ENDSWITH / Value $DeplStateName3 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'DeplState',
                    Operator => 'ENDSWITH',
                    Value    => $DeplStateName3
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplState / Operator ENDSWITH / Value substr($DeplStateName3,-5) / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'DeplState',
                    Operator => 'ENDSWITH',
                    Value    => substr($DeplStateName3,-5)
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplState / Operator CONTAINS / Value $DeplStateName3 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'DeplState',
                    Operator => 'CONTAINS',
                    Value    => $DeplStateName3
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplState / Operator CONTAINS / Value substr($DeplStateName3,2,-2) / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'DeplState',
                    Operator => 'CONTAINS',
                    Value    => substr($DeplStateName3,2,-2)
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field DeplState / Operator LIKE / Value $DeplStateName3 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'DeplState',
                    Operator => 'LIKE',
                    Value    => $DeplStateName3
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
        Name     => 'Sort: Field DeplStateID',
        Sort     => [
            {
                Field => 'DeplStateID'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ConfigItemID1, $ConfigItemID2, $ConfigItemID3] : [$ConfigItemID3, $ConfigItemID1, $ConfigItemID2]
    },
    {
        Name     => 'Sort: Field DeplStateID / Direction ascending',
        Sort     => [
            {
                Field     => 'DeplStateID',
                Direction => 'ascending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ConfigItemID1, $ConfigItemID2, $ConfigItemID3] : [$ConfigItemID3, $ConfigItemID1, $ConfigItemID2]
    },
    {
        Name     => 'Sort: Field DeplStateID / Direction descending',
        Sort     => [
            {
                Field     => 'DeplStateID',
                Direction => 'descending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ConfigItemID3,$ConfigItemID2,$ConfigItemID1] : [$ConfigItemID2, $ConfigItemID1, $ConfigItemID3]
    },
    {
        Name     => 'Sort: Field DeplStateIDs',
        Sort     => [
            {
                Field => 'DeplStateIDs'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ConfigItemID1, $ConfigItemID2, $ConfigItemID3] : [$ConfigItemID3, $ConfigItemID1, $ConfigItemID2]
    },
    {
        Name     => 'Sort: Field DeplStateIDs / Direction ascending',
        Sort     => [
            {
                Field     => 'DeplStateIDs',
                Direction => 'ascending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ConfigItemID1, $ConfigItemID2, $ConfigItemID3] : [$ConfigItemID3, $ConfigItemID1, $ConfigItemID2]
    },
    {
        Name     => 'Sort: Field DeplStateIDs / Direction descending',
        Sort     => [
            {
                Field     => 'DeplStateIDs',
                Direction => 'descending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ConfigItemID3,$ConfigItemID2,$ConfigItemID1] : [$ConfigItemID2, $ConfigItemID1, $ConfigItemID3]
    },
    {
        Name     => 'Sort: Field DeplState',
        Sort     => [
            {
                Field => 'DeplState'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ConfigItemID1, $ConfigItemID2, $ConfigItemID3] : [$ConfigItemID3, $ConfigItemID1, $ConfigItemID2]
    },
    {
        Name     => 'Sort: Field DeplState / Direction ascending',
        Sort     => [
            {
                Field     => 'DeplState',
                Direction => 'ascending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ConfigItemID1, $ConfigItemID2, $ConfigItemID3] : [$ConfigItemID3, $ConfigItemID1, $ConfigItemID2]
    },
    {
        Name     => 'Sort: Field DeplState / Direction descending',
        Sort     => [
            {
                Field     => 'DeplState',
                Direction => 'descending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ConfigItemID3,$ConfigItemID2,$ConfigItemID1] : [$ConfigItemID2, $ConfigItemID1, $ConfigItemID3]
    },
    {
        Name     => 'Sort: Field DeplState / Language de',
        Sort     => [
            {
                Field => 'DeplState'
            }
        ],
        Language => 'de',
        Expected => $OrderByNull eq 'LAST' ? [$ConfigItemID2,$ConfigItemID1,$ConfigItemID3] : [$ConfigItemID3,$ConfigItemID2,$ConfigItemID1]
    },
    {
        Name     => 'Sort: Field DeplState / Direction ascending / Language de',
        Sort     => [
            {
                Field     => 'DeplState',
                Direction => 'ascending'
            }
        ],
        Language => 'de',
        Expected => $OrderByNull eq 'LAST' ? [$ConfigItemID2,$ConfigItemID1,$ConfigItemID3] : [$ConfigItemID3,$ConfigItemID2,$ConfigItemID1]
    },
    {
        Name     => 'Sort: Field DeplState / Direction descending / Language de',
        Sort     => [
            {
                Field     => 'DeplState',
                Direction => 'descending'
            }
        ],
        Language => 'de',
        Expected => $OrderByNull eq 'LAST' ? [$ConfigItemID3,$ConfigItemID1,$ConfigItemID2] : [$ConfigItemID1,$ConfigItemID2,$ConfigItemID3]
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
