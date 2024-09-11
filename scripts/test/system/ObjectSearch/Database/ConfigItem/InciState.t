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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::ConfigItem::InciState';

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
        InciStateID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ', 'NE', 'IN','!IN','GT','GTE','LT','LTE'],
            ValueType    => 'NUMERIC'
        },
        InciStateIDs => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ', 'NE', 'IN','!IN','GT','GTE','LT','LTE'],
            ValueType    => 'NUMERIC'
        },
        InciState => {
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
            Field    => 'InciStateID',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'InciStateID',
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
            Field    => 'InciStateID',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'InciStateID',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field InciStateID / Operator EQ',
        Search       => {
            Field    => 'InciStateID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_inci_state_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciStateID / Operator NE',
        Search       => {
            Field    => 'InciStateID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_inci_state_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciStateID / Operator IN',
        Search       => {
            Field    => 'InciStateID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_inci_state_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciStateID / Operator !IN',
        Search       => {
            Field    => 'InciStateID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_inci_state_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciStateID / Operator LT',
        Search       => {
            Field    => 'InciStateID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_inci_state_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciStateID / Operator GT',
        Search       => {
            Field    => 'InciStateID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_inci_state_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciStateID / Operator LTE',
        Search       => {
            Field    => 'InciStateID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_inci_state_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciStateID / Operator GTE',
        Search       => {
            Field    => 'InciStateID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_inci_state_id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciStateIDs / Operator EQ',
        Search       => {
            Field    => 'InciStateIDs',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_inci_state_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciStateIDs / Operator NE',
        Search       => {
            Field    => 'InciStateIDs',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_inci_state_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciStateIDs / Operator IN',
        Search       => {
            Field    => 'InciStateIDs',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_inci_state_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciStateIDs / Operator !IN',
        Search       => {
            Field    => 'InciStateIDs',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_inci_state_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciStateIDs / Operator LT',
        Search       => {
            Field    => 'InciStateIDs',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_inci_state_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciStateIDs / Operator GT',
        Search       => {
            Field    => 'InciStateIDs',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_inci_state_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciStateIDs / Operator LTE',
        Search       => {
            Field    => 'InciStateIDs',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_inci_state_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciStateIDs / Operator GTE',
        Search       => {
            Field    => 'InciStateIDs',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.cur_inci_state_id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciState / Operator EQ',
        Search       => {
            Field    => 'InciState',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN general_catalog ciis ON ciis.id = ci.cur_inci_state_id AND general_catalog_class = \'ITSM::Core::IncidentState\''
            ],
            'Where' => [
                'ciis.name = \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciState / Operator NE',
        Search       => {
            Field    => 'InciState',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN general_catalog ciis ON ciis.id = ci.cur_inci_state_id AND general_catalog_class = \'ITSM::Core::IncidentState\''
            ],
            'Where' => [
                'ciis.name != \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciState / Operator IN',
        Search       => {
            Field    => 'InciState',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN general_catalog ciis ON ciis.id = ci.cur_inci_state_id AND general_catalog_class = \'ITSM::Core::IncidentState\''
            ],
            'Where' => [
                'ciis.name IN (\'Test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciState / Operator !IN',
        Search       => {
            Field    => 'InciState',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN general_catalog ciis ON ciis.id = ci.cur_inci_state_id AND general_catalog_class = \'ITSM::Core::IncidentState\''
            ],
            'Where' => [
                'ciis.name NOT IN (\'Test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciState / Operator STARTSWITH',
        Search       => {
            Field    => 'InciState',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN general_catalog ciis ON ciis.id = ci.cur_inci_state_id AND general_catalog_class = \'ITSM::Core::IncidentState\''
            ],
            'Where' => [
                'ciis.name LIKE \'Test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciState / Operator ENDSWITH',
        Search       => {
            Field    => 'InciState',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN general_catalog ciis ON ciis.id = ci.cur_inci_state_id AND general_catalog_class = \'ITSM::Core::IncidentState\''
            ],
            'Where' => [
                'ciis.name LIKE \'%Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciState / Operator CONTAINS',
        Search       => {
            Field    => 'InciState',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN general_catalog ciis ON ciis.id = ci.cur_inci_state_id AND general_catalog_class = \'ITSM::Core::IncidentState\''
            ],
            'Where' => [
                'ciis.name LIKE \'%Test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciState / Operator LIKE',
        Search       => {
            Field    => 'InciState',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN general_catalog ciis ON ciis.id = ci.cur_inci_state_id AND general_catalog_class = \'ITSM::Core::IncidentState\''
            ],
            'Where' => [
                'ciis.name LIKE \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciStateID / Operator EQ / PreviousVersionSearch',
        Search       => {
            Field    => 'InciStateID',
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
                'civ.inci_state_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciStateID / Operator NE / PreviousVersionSearch',
        Search       => {
            Field    => 'InciStateID',
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
                'civ.inci_state_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciStateID / Operator IN / PreviousVersionSearch',
        Search       => {
            Field    => 'InciStateID',
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
                'civ.inci_state_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciStateID / Operator !IN / PreviousVersionSearch',
        Search       => {
            Field    => 'InciStateID',
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
                'civ.inci_state_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciStateID / Operator LT / PreviousVersionSearch',
        Search       => {
            Field    => 'InciStateID',
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
                'civ.inci_state_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciStateID / Operator GT / PreviousVersionSearch',
        Search       => {
            Field    => 'InciStateID',
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
                'civ.inci_state_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciStateID / Operator LTE / PreviousVersionSearch',
        Search       => {
            Field    => 'InciStateID',
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
                'civ.inci_state_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciStateID / Operator GTE / PreviousVersionSearch',
        Search       => {
            Field    => 'InciStateID',
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
                'civ.inci_state_id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciStateIDs / Operator EQ / PreviousVersionSearch',
        Search       => {
            Field    => 'InciStateIDs',
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
                'civ.inci_state_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciStateIDs / Operator NE / PreviousVersionSearch',
        Search       => {
            Field    => 'InciStateIDs',
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
                'civ.inci_state_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciStateIDs / Operator IN / PreviousVersionSearch',
        Search       => {
            Field    => 'InciStateIDs',
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
                'civ.inci_state_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciStateIDs / Operator !IN / PreviousVersionSearch',
        Search       => {
            Field    => 'InciStateIDs',
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
                'civ.inci_state_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciStateIDs / Operator LT / PreviousVersionSearch',
        Search       => {
            Field    => 'InciStateIDs',
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
                'civ.inci_state_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciStateIDs / Operator GT / PreviousVersionSearch',
        Search       => {
            Field    => 'InciStateIDs',
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
                'civ.inci_state_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciStateIDs / Operator LTE / PreviousVersionSearch',
        Search       => {
            Field    => 'InciStateIDs',
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
                'civ.inci_state_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciStateIDs / Operator GTE / PreviousVersionSearch',
        Search       => {
            Field    => 'InciStateIDs',
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
                'civ.inci_state_id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciState / Operator EQ / PreviousVersionSearch',
        Search       => {
            Field    => 'InciState',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                'INNER JOIN general_catalog civis ON civis.id = civ.inci_state_id AND general_catalog_class = \'ITSM::Core::IncidentState\''
            ],
            'Where' => [
                'civis.name = \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciState / Operator NE / PreviousVersionSearch',
        Search       => {
            Field    => 'InciState',
            Operator => 'NE',
            Value    => 'Test'
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                'INNER JOIN general_catalog civis ON civis.id = civ.inci_state_id AND general_catalog_class = \'ITSM::Core::IncidentState\''
            ],
            'Where' => [
                'civis.name != \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciState / Operator IN / PreviousVersionSearch',
        Search       => {
            Field    => 'InciState',
            Operator => 'IN',
            Value    => ['Test']
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                'INNER JOIN general_catalog civis ON civis.id = civ.inci_state_id AND general_catalog_class = \'ITSM::Core::IncidentState\''
            ],
            'Where' => [
                'civis.name IN (\'Test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciState / Operator !IN / PreviousVersionSearch',
        Search       => {
            Field    => 'InciState',
            Operator => '!IN',
            Value    => ['Test']
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                'INNER JOIN general_catalog civis ON civis.id = civ.inci_state_id AND general_catalog_class = \'ITSM::Core::IncidentState\''
            ],
            'Where' => [
                'civis.name NOT IN (\'Test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciState / Operator STARTSWITH / PreviousVersionSearch',
        Search       => {
            Field    => 'InciState',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                'INNER JOIN general_catalog civis ON civis.id = civ.inci_state_id AND general_catalog_class = \'ITSM::Core::IncidentState\''
            ],
            'Where' => [
                'civis.name LIKE \'Test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciState / Operator ENDSWITH / PreviousVersionSearch',
        Search       => {
            Field    => 'InciState',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                'INNER JOIN general_catalog civis ON civis.id = civ.inci_state_id AND general_catalog_class = \'ITSM::Core::IncidentState\''
            ],
            'Where' => [
                'civis.name LIKE \'%Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciState / Operator CONTAINS / PreviousVersionSearch',
        Search       => {
            Field    => 'InciState',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                'INNER JOIN general_catalog civis ON civis.id = civ.inci_state_id AND general_catalog_class = \'ITSM::Core::IncidentState\''
            ],
            'Where' => [
                'civis.name LIKE \'%Test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field InciState / Operator LIKE / PreviousVersionSearch',
        Search       => {
            Field    => 'InciState',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Flags        => {
            PreviousVersionSearch => 1
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                'INNER JOIN general_catalog civis ON civis.id = civ.inci_state_id AND general_catalog_class = \'ITSM::Core::IncidentState\''
            ],
            'Where' => [
                'civis.name LIKE \'Test\''
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
        Name      => 'Sort: Attribute "InciStateID"',
        Attribute => 'InciStateID',
        Expected  => {
            'Join'    => [],
            'OrderBy' => [
                'ci.cur_inci_state_id'
            ],
            'Select'  => [
                'ci.cur_inci_state_id'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "InciStateIDs"',
        Attribute => 'InciStateID',
        Expected  => {
            'Join'    => [],
            'OrderBy' => [
                'ci.cur_inci_state_id'
            ],
            'Select'  => [
                'ci.cur_inci_state_id'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "InciState"',
        Attribute => 'InciState',
        Expected  => {
            'Join'    => [
                'LEFT OUTER JOIN general_catalog ciis ON ciis.id = ci.cur_inci_state_id AND general_catalog_class = \'ITSM::Core::IncidentState\'',
                'LEFT OUTER JOIN translation_pattern tlp0 ON tlp0.value = ciis.name',
                'LEFT OUTER JOIN translation_language tl0 ON tl0.pattern_id = tlp0.id AND tl0.language = \'en\''
            ],
            'OrderBy' => [
                'TranslateInciState'
            ],
            'Select'  => [
                'LOWER(COALESCE(tl0.value, ciis.name)) AS TranslateInciState'
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
my $DeplStateRef = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class => 'ITSM::ConfigItem::DeploymentState',
    Name  => 'Production',
);

# prepare inci state mapping
my $ItemDataRef1 = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class         => 'ITSM::Core::IncidentState',
    Name          => 'Incident',
    NoPreferences => 1
);
my $InciStateID1   = $ItemDataRef1->{ItemID};
my $InciStateName1 = $ItemDataRef1->{Name};
$Self->True(
    $InciStateID1,
    'InciState 1 has id'
);
$Self->Is(
    $InciStateName1,
    'Incident',
    'InciState 1 has expected name'
);
$Self->Is(
    $TranslationsDE{ $InciStateName1 },
    'Störung',
    'InciState 1 has expected translation (de)'
);
my $ItemDataRef2 = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class         => 'ITSM::Core::IncidentState',
    Name          => 'Warning',
    NoPreferences => 1
);
my $InciStateID2   = $ItemDataRef2->{ItemID};
my $InciStateName2 = $ItemDataRef2->{Name};
$Self->True(
    $InciStateID2,
    'InciState 2 has id'
);
$Self->Is(
    $InciStateName2,
    'Warning',
    'InciState 2 has expected name'
);
$Self->Is(
    $TranslationsDE{ $InciStateName2 },
    'Warnung',
    'InciState 2 has expected translation (de)'
);
my $ItemDataRef3 = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class         => 'ITSM::Core::IncidentState',
    Name          => 'Operational',
    NoPreferences => 1
);
my $InciStateID3   = $ItemDataRef3->{ItemID};
my $InciStateName3 = $ItemDataRef3->{Name};
$Self->True(
    $InciStateID3,
    'InciState 3 has id'
);
$Self->Is(
    $InciStateName3,
    'Operational',
    'InciState 3 has expected name'
);
$Self->Is(
    $TranslationsDE{ $InciStateName3 },
    'Betriebsbereit',
    'InciState 3 has expected translation (de)'
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
    DeplStateID  => $DeplStateRef->{ItemID},
    InciStateID  => $InciStateID1,
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
    DeplStateID  => $DeplStateRef->{ItemID},
    InciStateID  => $InciStateID2,
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
    DeplStateID  => $DeplStateRef->{ItemID},
    InciStateID  => $InciStateID3,
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
        Name     => 'Search: Field InciStateID / Operator EQ / Value $InciStateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'InciStateID',
                    Operator => 'EQ',
                    Value    => $InciStateID2
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field InciStateID / Operator NE / Value $InciStateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'InciStateID',
                    Operator => 'NE',
                    Value    => $InciStateID2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciStateID / Operator IN / Value [$InciStateID1,$InciStateID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'InciStateID',
                    Operator => 'IN',
                    Value    => [$InciStateID1,$InciStateID3]
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciStateID / Operator !IN / Value [$InciStateID1,$InciStateID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'InciStateID',
                    Operator => '!IN',
                    Value    => [$InciStateID1,$InciStateID3]
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field InciStateID / Operator LT / Value $InciStateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'InciStateID',
                    Operator => 'LT',
                    Value    => $InciStateID2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciStateID / Operator GT / Value $InciStateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'InciStateID',
                    Operator => 'GT',
                    Value    => $InciStateID2
                }
            ]
        },
        Expected => [$ConfigItemID1]
    },
    {
        Name     => 'Search: Field InciStateID / Operator LTE / Value $InciStateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'InciStateID',
                    Operator => 'LTE',
                    Value    => $InciStateID2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciStateID / Operator GTE / Value $InciStateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'InciStateID',
                    Operator => 'GTE',
                    Value    => $InciStateID2
                }
            ]
        },
        Expected => [$ConfigItemID1]
    },
    {
        Name     => 'Search: Field InciStateIDs / Operator EQ / Value $InciStateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'InciStateIDs',
                    Operator => 'EQ',
                    Value    => $InciStateID2
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field InciStateIDs / Operator NE / Value $InciStateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'InciStateIDs',
                    Operator => 'NE',
                    Value    => $InciStateID2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciStateIDs / Operator IN / Value [$InciStateID1,$InciStateID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'InciStateIDs',
                    Operator => 'IN',
                    Value    => [$InciStateID1,$InciStateID3]
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciStateIDs / Operator !IN / Value [$InciStateID1,$InciStateID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'InciStateIDs',
                    Operator => '!IN',
                    Value    => [$InciStateID1,$InciStateID3]
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field InciStateIDs / Operator LT / Value $InciStateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'InciStateIDs',
                    Operator => 'LT',
                    Value    => $InciStateID2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciStateIDs / Operator GT / Value $InciStateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'InciStateIDs',
                    Operator => 'GT',
                    Value    => $InciStateID2
                }
            ]
        },
        Expected => [$ConfigItemID1]
    },
    {
        Name     => 'Search: Field InciStateIDs / Operator LTE / Value $InciStateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'InciStateIDs',
                    Operator => 'LTE',
                    Value    => $InciStateID2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciStateIDs / Operator GTE / Value $InciStateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'InciStateIDs',
                    Operator => 'GTE',
                    Value    => $InciStateID2
                }
            ]
        },
        Expected => [$ConfigItemID1]
    },
    {
        Name     => 'Search: Field InciState / Operator EQ / Value $InciStateName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'InciState',
                    Operator => 'EQ',
                    Value    => $InciStateName2
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field InciState / Operator NE / Value $InciStateName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'InciState',
                    Operator => 'NE',
                    Value    => $InciStateName2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciState / Operator IN / Value [$InciStateName1,$InciStateName3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'InciState',
                    Operator => 'IN',
                    Value    => [$InciStateName1,$InciStateName3]
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciState / Operator !IN / Value [$InciStateName1,$InciStateName3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'InciState',
                    Operator => '!IN',
                    Value    => [$InciStateName1,$InciStateName3]
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field InciState / Operator STARTSWITH / Value $InciStateName3',
        Search   => {
            'AND' => [
                {
                    Field    => 'InciState',
                    Operator => 'STARTSWITH',
                    Value    => $InciStateName3
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciState / Operator STARTSWITH / Value substr($InciStateName3,0,4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'InciState',
                    Operator => 'STARTSWITH',
                    Value    => substr($InciStateName3,0,4)
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciState / Operator ENDSWITH / Value $InciStateName3',
        Search   => {
            'AND' => [
                {
                    Field    => 'InciState',
                    Operator => 'ENDSWITH',
                    Value    => $InciStateName3
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciState / Operator ENDSWITH / Value substr($InciStateName3,-5)',
        Search   => {
            'AND' => [
                {
                    Field    => 'InciState',
                    Operator => 'ENDSWITH',
                    Value    => substr($InciStateName3,-5)
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciState / Operator CONTAINS / Value $InciStateName3',
        Search   => {
            'AND' => [
                {
                    Field    => 'InciState',
                    Operator => 'CONTAINS',
                    Value    => $InciStateName3
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciState / Operator CONTAINS / Value substr($InciStateName3,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'InciState',
                    Operator => 'CONTAINS',
                    Value    => substr($InciStateName3,2,-2)
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciState / Operator LIKE / Value $InciStateName3',
        Search   => {
            'AND' => [
                {
                    Field    => 'InciState',
                    Operator => 'LIKE',
                    Value    => $InciStateName3
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciStateID / Operator EQ / Value $InciStateID2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'InciStateID',
                    Operator => 'EQ',
                    Value    => $InciStateID2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciStateID / Operator NE / Value $InciStateID2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'InciStateID',
                    Operator => 'NE',
                    Value    => $InciStateID2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciStateID / Operator IN / Value [$InciStateID1,$InciStateID3] / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'InciStateID',
                    Operator => 'IN',
                    Value    => [$InciStateID1,$InciStateID3]
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciStateID / Operator !IN / Value [$InciStateID1,$InciStateID3] / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'InciStateID',
                    Operator => '!IN',
                    Value    => [$InciStateID1,$InciStateID3]
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciStateID / Operator LT / Value $InciStateID2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'InciStateID',
                    Operator => 'LT',
                    Value    => $InciStateID2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciStateID / Operator GT / Value $InciStateID2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'InciStateID',
                    Operator => 'GT',
                    Value    => $InciStateID2
                }
            ]
        },
        Expected => [$ConfigItemID1]
    },
    {
        Name     => 'Search: Field InciStateID / Operator LTE / Value $InciStateID2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'InciStateID',
                    Operator => 'LTE',
                    Value    => $InciStateID2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciStateID / Operator GTE / Value $InciStateID2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'InciStateID',
                    Operator => 'GTE',
                    Value    => $InciStateID2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciStateIDs / Operator EQ / Value $InciStateID2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'InciStateIDs',
                    Operator => 'EQ',
                    Value    => $InciStateID2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciStateIDs / Operator NE / Value $InciStateID2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'InciStateIDs',
                    Operator => 'NE',
                    Value    => $InciStateID2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciStateIDs / Operator IN / Value [$InciStateID1,$InciStateID3] / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'InciStateIDs',
                    Operator => 'IN',
                    Value    => [$InciStateID1,$InciStateID3]
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciStateIDs / Operator !IN / Value [$InciStateID1,$InciStateID3] / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'InciStateIDs',
                    Operator => '!IN',
                    Value    => [$InciStateID1,$InciStateID3]
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciStateIDs / Operator LT / Value $InciStateID2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'InciStateIDs',
                    Operator => 'LT',
                    Value    => $InciStateID2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciStateIDs / Operator GT / Value $InciStateID2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'InciStateIDs',
                    Operator => 'GT',
                    Value    => $InciStateID2
                }
            ]
        },
        Expected => [$ConfigItemID1]
    },
    {
        Name     => 'Search: Field InciStateIDs / Operator LTE / Value $InciStateID2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'InciStateIDs',
                    Operator => 'LTE',
                    Value    => $InciStateID2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciStateIDs / Operator GTE / Value $InciStateID2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'InciStateIDs',
                    Operator => 'GTE',
                    Value    => $InciStateID2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciState / Operator EQ / Value $InciStateName2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'InciState',
                    Operator => 'EQ',
                    Value    => $InciStateName2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciState / Operator NE / Value $InciStateName2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'InciState',
                    Operator => 'NE',
                    Value    => $InciStateName2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciState / Operator IN / Value [$InciStateName1,$InciStateName3] / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'InciState',
                    Operator => 'IN',
                    Value    => [$InciStateName1,$InciStateName3]
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciState / Operator !IN / Value [$InciStateName1,$InciStateName3] / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'InciState',
                    Operator => '!IN',
                    Value    => [$InciStateName1,$InciStateName3]
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciState / Operator STARTSWITH / Value $InciStateName3 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'InciState',
                    Operator => 'STARTSWITH',
                    Value    => $InciStateName3
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciState / Operator STARTSWITH / Value substr($InciStateName3,0,4) / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'InciState',
                    Operator => 'STARTSWITH',
                    Value    => substr($InciStateName3,0,4)
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciState / Operator ENDSWITH / Value $InciStateName3 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'InciState',
                    Operator => 'ENDSWITH',
                    Value    => $InciStateName3
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciState / Operator ENDSWITH / Value substr($InciStateName3,-5) / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'InciState',
                    Operator => 'ENDSWITH',
                    Value    => substr($InciStateName3,-5)
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciState / Operator CONTAINS / Value $InciStateName3 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'InciState',
                    Operator => 'CONTAINS',
                    Value    => $InciStateName3
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciState / Operator CONTAINS / Value substr($InciStateName3,2,-2) / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'InciState',
                    Operator => 'CONTAINS',
                    Value    => substr($InciStateName3,2,-2)
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field InciState / Operator LIKE / Value $InciStateName3 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'InciState',
                    Operator => 'LIKE',
                    Value    => $InciStateName3
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
        Name     => 'Sort: Field InciStateID',
        Sort     => [
            {
                Field => 'InciStateID'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ConfigItemID2,$ConfigItemID1,$ConfigItemID3] : [$ConfigItemID3,$ConfigItemID2,$ConfigItemID1]
    },
    {
        Name     => 'Sort: Field InciStateID / Direction ascending',
        Sort     => [
            {
                Field     => 'InciStateID',
                Direction => 'ascending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ConfigItemID2,$ConfigItemID1,$ConfigItemID3] : [$ConfigItemID3,$ConfigItemID2,$ConfigItemID1]
    },
    {
        Name     => 'Sort: Field InciStateID / Direction descending',
        Sort     => [
            {
                Field     => 'InciStateID',
                Direction => 'descending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ConfigItemID3,$ConfigItemID1,$ConfigItemID2] : [$ConfigItemID1,$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => 'Sort: Field InciStateIDs',
        Sort     => [
            {
                Field => 'InciStateIDs'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ConfigItemID2,$ConfigItemID1,$ConfigItemID3] : [$ConfigItemID3,$ConfigItemID2,$ConfigItemID1]
    },
    {
        Name     => 'Sort: Field InciStateIDs / Direction ascending',
        Sort     => [
            {
                Field     => 'InciStateIDs',
                Direction => 'ascending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ConfigItemID2,$ConfigItemID1,$ConfigItemID3] : [$ConfigItemID3,$ConfigItemID2,$ConfigItemID1]
    },
    {
        Name     => 'Sort: Field InciStateIDs / Direction descending',
        Sort     => [
            {
                Field     => 'InciStateIDs',
                Direction => 'descending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ConfigItemID3,$ConfigItemID1,$ConfigItemID2] : [$ConfigItemID1,$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => 'Sort: Field InciState',
        Sort     => [
            {
                Field => 'InciState'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ConfigItemID1, $ConfigItemID2, $ConfigItemID3] : [$ConfigItemID3, $ConfigItemID1, $ConfigItemID2]
    },
    {
        Name     => 'Sort: Field InciState / Direction ascending',
        Sort     => [
            {
                Field     => 'InciState',
                Direction => 'ascending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ConfigItemID1, $ConfigItemID2, $ConfigItemID3] : [$ConfigItemID3, $ConfigItemID1, $ConfigItemID2]
    },
    {
        Name     => 'Sort: Field InciState / Direction descending',
        Sort     => [
            {
                Field     => 'InciState',
                Direction => 'descending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ConfigItemID3,$ConfigItemID2,$ConfigItemID1] : [$ConfigItemID2, $ConfigItemID1, $ConfigItemID3]
    },
    {
        Name     => 'Sort: Field InciState / Language de',
        Sort     => [
            {
                Field => 'InciState'
            }
        ],
        Language => 'de',
        Expected => $OrderByNull eq 'LAST' ? [$ConfigItemID2,$ConfigItemID1,$ConfigItemID3] : [$ConfigItemID3,$ConfigItemID2,$ConfigItemID1]
    },
    {
        Name     => 'Sort: Field InciState / Direction ascending / Language de',
        Sort     => [
            {
                Field     => 'InciState',
                Direction => 'ascending'
            }
        ],
        Language => 'de',
        Expected => $OrderByNull eq 'LAST' ? [$ConfigItemID2,$ConfigItemID1,$ConfigItemID3] : [$ConfigItemID3,$ConfigItemID2,$ConfigItemID1]
    },
    {
        Name     => 'Sort: Field InciState / Direction descending / Language de',
        Sort     => [
            {
                Field     => 'InciState',
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
