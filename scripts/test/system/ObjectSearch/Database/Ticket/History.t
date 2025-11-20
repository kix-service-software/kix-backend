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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Ticket::History';

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
        ChangeTime        => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 0,
            Operators      => ['EQ','LT','LTE','GT','GTE'],
            ValueType      => 'DATETIME'
        },
        CloseTime         => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 0,
            Operators      => ['EQ','LT','LTE','GT','GTE'],
            ValueType      => 'DATETIME'
        },
        CreatedPriorityID => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType      => 'NUMERIC'
        },
        CreatedQueueID    => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType      => 'NUMERIC'
        },
        CreatedStateID    => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType      => 'NUMERIC'
        },
        CreatedTypeID     => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType      => 'NUMERIC'
        },
        HistoricOwnerID => {
            IsFulltextable => 0,
            IsSearchable   => 1,
            IsSelectable   => 0,
            IsSortable     => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType      => 'NUMERIC'
        },
        HistoricPriorityID => {
            IsFulltextable => 0,
            IsSearchable   => 1,
            IsSelectable   => 0,
            IsSortable     => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType     => 'NUMERIC'
        },
        HistoricQueueID => {
            IsFulltextable => 0,
            IsSearchable   => 1,
            IsSelectable   => 0,
            IsSortable     => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType      => 'NUMERIC'
        },
        HistoricStateID => {
            IsFulltextable => 0,
            IsSearchable   => 1,
            IsSelectable   => 0,
            IsSortable     => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType      => 'NUMERIC'
        },
        HistoricTypeID => {
            IsFulltextable => 0,
            IsSearchable   => 1,
            IsSelectable   => 0,
            IsSortable     => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType      => 'NUMERIC'
        }
    },
    'GetSupportedAttributes provides expected data'
);

# set fixed time to have predetermined verifiable results
my $SystemTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
    String => '2014-01-01 12:00:00',
);
$Helper->FixedTimeSet($SystemTime);

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
            Field    => 'ChangeTime',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'ChangeTime',
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
            Field    => 'ChangeTime',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'ChangeTime',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field ChangeTime / Operator EQ / absolute value',
        Search       => {
            Field    => 'ChangeTime',
            Operator => 'EQ',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.create_time = \'2014-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeTime / Operator EQ / relative value',
        Search       => {
            Field    => 'ChangeTime',
            Operator => 'EQ',
            Value    => '+1h'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.create_time = \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeTime / Operator LT / absolute value',
        Search       => {
            Field    => 'ChangeTime',
            Operator => 'LT',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.create_time < \'2014-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeTime / Operator LT / relative value',
        Search       => {
            Field    => 'ChangeTime',
            Operator => 'LT',
            Value    => '+1h'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.create_time < \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeTime / Operator GT / absolute value',
        Search       => {
            Field    => 'ChangeTime',
            Operator => 'GT',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.create_time > \'2014-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeTime / Operator GT / relative value',
        Search       => {
            Field    => 'ChangeTime',
            Operator => 'GT',
            Value    => '+1h'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.create_time > \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeTime / Operator LTE / absolute value',
        Search       => {
            Field    => 'ChangeTime',
            Operator => 'LTE',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.create_time <= \'2014-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeTime / Operator LTE / relative value',
        Search       => {
            Field    => 'ChangeTime',
            Operator => 'LTE',
            Value    => '+1h'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.create_time <= \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeTime / Operator GTE / absolute value',
        Search       => {
            Field    => 'ChangeTime',
            Operator => 'GTE',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.create_time >= \'2014-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeTime / Operator GTE / relative value',
        Search       => {
            Field    => 'ChangeTime',
            Operator => 'GTE',
            Value    => '+1h'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.create_time >= \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field CloseTime / Operator EQ / absolute value',
        Search       => {
            Field    => 'CloseTime',
            Operator => 'EQ',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN ticket_history thcl ON thcl.ticket_id = st.id',
                'INNER JOIN ticket_state thscl ON thscl.id = thcl.state_id',
                'INNER JOIN ticket_state_type thstcl ON thstcl.id = thscl.type_id AND thstcl.name = \'closed\'',
                'INNER JOIN ticket_history_type thtcl ON thtcl.id = thcl.history_type_id AND thtcl.name IN (\'NewTicket\',\'StateUpdate\')'
            ],
            'Where' => [
                'thcl.create_time = \'2014-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CloseTime / Operator EQ / relative value',
        Search       => {
            Field    => 'CloseTime',
            Operator => 'EQ',
            Value    => '+1h'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN ticket_history thcl ON thcl.ticket_id = st.id',
                'INNER JOIN ticket_state thscl ON thscl.id = thcl.state_id',
                'INNER JOIN ticket_state_type thstcl ON thstcl.id = thscl.type_id AND thstcl.name = \'closed\'',
                'INNER JOIN ticket_history_type thtcl ON thtcl.id = thcl.history_type_id AND thtcl.name IN (\'NewTicket\',\'StateUpdate\')'
            ],
            'Where' => [
                'thcl.create_time = \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field CloseTime / Operator LT / absolute value',
        Search       => {
            Field    => 'CloseTime',
            Operator => 'LT',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN ticket_history thcl ON thcl.ticket_id = st.id',
                'INNER JOIN ticket_state thscl ON thscl.id = thcl.state_id',
                'INNER JOIN ticket_state_type thstcl ON thstcl.id = thscl.type_id AND thstcl.name = \'closed\'',
                'INNER JOIN ticket_history_type thtcl ON thtcl.id = thcl.history_type_id AND thtcl.name IN (\'NewTicket\',\'StateUpdate\')'
            ],
            'Where' => [
                'thcl.create_time < \'2014-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CloseTime / Operator LT / relative value',
        Search       => {
            Field    => 'CloseTime',
            Operator => 'LT',
            Value    => '+1h'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN ticket_history thcl ON thcl.ticket_id = st.id',
                'INNER JOIN ticket_state thscl ON thscl.id = thcl.state_id',
                'INNER JOIN ticket_state_type thstcl ON thstcl.id = thscl.type_id AND thstcl.name = \'closed\'',
                'INNER JOIN ticket_history_type thtcl ON thtcl.id = thcl.history_type_id AND thtcl.name IN (\'NewTicket\',\'StateUpdate\')'
            ],
            'Where' => [
                'thcl.create_time < \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field CloseTime / Operator GT / absolute value',
        Search       => {
            Field    => 'CloseTime',
            Operator => 'GT',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN ticket_history thcl ON thcl.ticket_id = st.id',
                'INNER JOIN ticket_state thscl ON thscl.id = thcl.state_id',
                'INNER JOIN ticket_state_type thstcl ON thstcl.id = thscl.type_id AND thstcl.name = \'closed\'',
                'INNER JOIN ticket_history_type thtcl ON thtcl.id = thcl.history_type_id AND thtcl.name IN (\'NewTicket\',\'StateUpdate\')'
            ],
            'Where' => [
                'thcl.create_time > \'2014-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CloseTime / Operator GT / relative value',
        Search       => {
            Field    => 'CloseTime',
            Operator => 'GT',
            Value    => '+1h'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN ticket_history thcl ON thcl.ticket_id = st.id',
                'INNER JOIN ticket_state thscl ON thscl.id = thcl.state_id',
                'INNER JOIN ticket_state_type thstcl ON thstcl.id = thscl.type_id AND thstcl.name = \'closed\'',
                'INNER JOIN ticket_history_type thtcl ON thtcl.id = thcl.history_type_id AND thtcl.name IN (\'NewTicket\',\'StateUpdate\')'
            ],
            'Where' => [
                'thcl.create_time > \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field CloseTime / Operator LTE / absolute value',
        Search       => {
            Field    => 'CloseTime',
            Operator => 'LTE',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN ticket_history thcl ON thcl.ticket_id = st.id',
                'INNER JOIN ticket_state thscl ON thscl.id = thcl.state_id',
                'INNER JOIN ticket_state_type thstcl ON thstcl.id = thscl.type_id AND thstcl.name = \'closed\'',
                'INNER JOIN ticket_history_type thtcl ON thtcl.id = thcl.history_type_id AND thtcl.name IN (\'NewTicket\',\'StateUpdate\')'
            ],
            'Where' => [
                'thcl.create_time <= \'2014-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CloseTime / Operator LTE / relative value',
        Search       => {
            Field    => 'CloseTime',
            Operator => 'LTE',
            Value    => '+1h'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN ticket_history thcl ON thcl.ticket_id = st.id',
                'INNER JOIN ticket_state thscl ON thscl.id = thcl.state_id',
                'INNER JOIN ticket_state_type thstcl ON thstcl.id = thscl.type_id AND thstcl.name = \'closed\'',
                'INNER JOIN ticket_history_type thtcl ON thtcl.id = thcl.history_type_id AND thtcl.name IN (\'NewTicket\',\'StateUpdate\')'
            ],
            'Where' => [
                'thcl.create_time <= \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field CloseTime / Operator GTE / absolute value',
        Search       => {
            Field    => 'CloseTime',
            Operator => 'GTE',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN ticket_history thcl ON thcl.ticket_id = st.id',
                'INNER JOIN ticket_state thscl ON thscl.id = thcl.state_id',
                'INNER JOIN ticket_state_type thstcl ON thstcl.id = thscl.type_id AND thstcl.name = \'closed\'',
                'INNER JOIN ticket_history_type thtcl ON thtcl.id = thcl.history_type_id AND thtcl.name IN (\'NewTicket\',\'StateUpdate\')'
            ],
            'Where' => [
                'thcl.create_time >= \'2014-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CloseTime / Operator GTE / relative value',
        Search       => {
            Field    => 'CloseTime',
            Operator => 'GTE',
            Value    => '+1h'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN ticket_history thcl ON thcl.ticket_id = st.id',
                'INNER JOIN ticket_state thscl ON thscl.id = thcl.state_id',
                'INNER JOIN ticket_state_type thstcl ON thstcl.id = thscl.type_id AND thstcl.name = \'closed\'',
                'INNER JOIN ticket_history_type thtcl ON thtcl.id = thcl.history_type_id AND thtcl.name IN (\'NewTicket\',\'StateUpdate\')'
            ],
            'Where' => [
                'thcl.create_time >= \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedPriorityID / Operator EQ',
        Search       => {
            Field    => 'CreatedPriorityID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.priority_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedPriorityID / Operator NE',
        Search       => {
            Field    => 'CreatedPriorityID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.priority_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedPriorityID / Operator IN',
        Search       => {
            Field    => 'CreatedPriorityID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.priority_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedPriorityID / Operator !IN',
        Search       => {
            Field    => 'CreatedPriorityID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.priority_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedPriorityID / Operator LT',
        Search       => {
            Field    => 'CreatedPriorityID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.priority_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedPriorityID / Operator GT',
        Search       => {
            Field    => 'CreatedPriorityID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.priority_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedPriorityID / Operator LTE',
        Search       => {
            Field    => 'CreatedPriorityID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.priority_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedPriorityID / Operator GTE',
        Search       => {
            Field    => 'CreatedPriorityID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.priority_id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedQueueID / Operator EQ',
        Search       => {
            Field    => 'CreatedQueueID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.queue_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedQueueID / Operator NE',
        Search       => {
            Field    => 'CreatedQueueID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.queue_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedQueueID / Operator IN',
        Search       => {
            Field    => 'CreatedQueueID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.queue_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedQueueID / Operator !IN',
        Search       => {
            Field    => 'CreatedQueueID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.queue_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedQueueID / Operator LT',
        Search       => {
            Field    => 'CreatedQueueID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.queue_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedQueueID / Operator GT',
        Search       => {
            Field    => 'CreatedQueueID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.queue_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedQueueID / Operator LTE',
        Search       => {
            Field    => 'CreatedQueueID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.queue_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedQueueID / Operator GTE',
        Search       => {
            Field    => 'CreatedQueueID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.queue_id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedStateID / Operator EQ',
        Search       => {
            Field    => 'CreatedStateID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.state_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedStateID / Operator NE',
        Search       => {
            Field    => 'CreatedStateID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.state_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedStateID / Operator IN',
        Search       => {
            Field    => 'CreatedStateID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.state_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedStateID / Operator !IN',
        Search       => {
            Field    => 'CreatedStateID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.state_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedStateID / Operator LT',
        Search       => {
            Field    => 'CreatedStateID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.state_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedStateID / Operator GT',
        Search       => {
            Field    => 'CreatedStateID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.state_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedStateID / Operator LTE',
        Search       => {
            Field    => 'CreatedStateID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.state_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedStateID / Operator GTE',
        Search       => {
            Field    => 'CreatedStateID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.state_id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedTypeID / Operator EQ',
        Search       => {
            Field    => 'CreatedTypeID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.type_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedTypeID / Operator NE',
        Search       => {
            Field    => 'CreatedTypeID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.type_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedTypeID / Operator IN',
        Search       => {
            Field    => 'CreatedTypeID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.type_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedTypeID / Operator !IN',
        Search       => {
            Field    => 'CreatedTypeID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.type_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedTypeID / Operator LT',
        Search       => {
            Field    => 'CreatedTypeID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.type_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedTypeID / Operator GT',
        Search       => {
            Field    => 'CreatedTypeID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.type_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedTypeID / Operator LTE',
        Search       => {
            Field    => 'CreatedTypeID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.type_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedTypeID / Operator GTE',
        Search       => {
            Field    => 'CreatedTypeID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id',
                'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\''
            ],
            'Where' => [
                'thcr.type_id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricOwnerID / Operator EQ',
        Search       => {
            Field    => 'HistoricOwnerID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.owner_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricOwnerID / Operator NE',
        Search       => {
            Field    => 'HistoricOwnerID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.owner_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricOwnerID / Operator IN',
        Search       => {
            Field    => 'HistoricOwnerID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.owner_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricOwnerID / Operator !IN',
        Search       => {
            Field    => 'HistoricOwnerID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.owner_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricOwnerID / Operator LT',
        Search       => {
            Field    => 'HistoricOwnerID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.owner_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricOwnerID / Operator GT',
        Search       => {
            Field    => 'HistoricOwnerID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.owner_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricOwnerID / Operator LTE',
        Search       => {
            Field    => 'HistoricOwnerID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.owner_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricOwnerID / Operator GTE',
        Search       => {
            Field    => 'HistoricOwnerID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.owner_id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricPriorityID / Operator EQ',
        Search       => {
            Field    => 'HistoricPriorityID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.priority_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricPriorityID / Operator NE',
        Search       => {
            Field    => 'HistoricPriorityID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.priority_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricPriorityID / Operator IN',
        Search       => {
            Field    => 'HistoricPriorityID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.priority_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricPriorityID / Operator !IN',
        Search       => {
            Field    => 'HistoricPriorityID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.priority_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricPriorityID / Operator LT',
        Search       => {
            Field    => 'HistoricPriorityID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.priority_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricPriorityID / Operator GT',
        Search       => {
            Field    => 'HistoricPriorityID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.priority_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricPriorityID / Operator LTE',
        Search       => {
            Field    => 'HistoricPriorityID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.priority_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricPriorityID / Operator GTE',
        Search       => {
            Field    => 'HistoricPriorityID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.priority_id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricQueueID / Operator EQ',
        Search       => {
            Field    => 'HistoricQueueID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.queue_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricQueueID / Operator NE',
        Search       => {
            Field    => 'HistoricQueueID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.queue_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricQueueID / Operator IN',
        Search       => {
            Field    => 'HistoricQueueID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.queue_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricQueueID / Operator !IN',
        Search       => {
            Field    => 'HistoricQueueID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.queue_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricQueueID / Operator LT',
        Search       => {
            Field    => 'HistoricQueueID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.queue_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricQueueID / Operator GT',
        Search       => {
            Field    => 'HistoricQueueID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.queue_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricQueueID / Operator LTE',
        Search       => {
            Field    => 'HistoricQueueID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.queue_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricQueueID / Operator GTE',
        Search       => {
            Field    => 'HistoricQueueID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.queue_id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricStateID / Operator EQ',
        Search       => {
            Field    => 'HistoricStateID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.state_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricStateID / Operator NE',
        Search       => {
            Field    => 'HistoricStateID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.state_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricStateID / Operator IN',
        Search       => {
            Field    => 'HistoricStateID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.state_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricStateID / Operator !IN',
        Search       => {
            Field    => 'HistoricStateID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.state_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricStateID / Operator LT',
        Search       => {
            Field    => 'HistoricStateID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.state_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricStateID / Operator GT',
        Search       => {
            Field    => 'HistoricStateID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.state_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricStateID / Operator LTE',
        Search       => {
            Field    => 'HistoricStateID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.state_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricStateID / Operator GTE',
        Search       => {
            Field    => 'HistoricStateID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.state_id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricTypeID / Operator EQ',
        Search       => {
            Field    => 'HistoricTypeID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.type_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricTypeID / Operator NE',
        Search       => {
            Field    => 'HistoricTypeID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.type_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricTypeID / Operator IN',
        Search       => {
            Field    => 'HistoricTypeID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.type_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricTypeID / Operator !IN',
        Search       => {
            Field    => 'HistoricTypeID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.type_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricTypeID / Operator LT',
        Search       => {
            Field    => 'HistoricTypeID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.type_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricTypeID / Operator GT',
        Search       => {
            Field    => 'HistoricTypeID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.type_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricTypeID / Operator LTE',
        Search       => {
            Field    => 'HistoricTypeID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.type_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field HistoricTypeID / Operator GTE',
        Search       => {
            Field    => 'HistoricTypeID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN ticket_history th ON th.ticket_id = st.id'
            ],
            'Where' => [
                'th.type_id >= 1'
            ]
        }
    }
);
for my $Test ( @SearchTests ) {
    my $Result = $AttributeObject->Search(
        Search       => $Test->{Search},
        BoolOperator => $Test->{BoolOperator},
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
        Name      => 'Sort: Attribute "ChangeTime" is not sortable',
        Attribute => 'ChangeTime',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "CloseTime" is not sortable',
        Attribute => 'CloseTime',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "CreatedPriorityID" is not sortable',
        Attribute => 'CreatedPriorityID',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "CreatedQueueID" is not sortable',
        Attribute => 'CreatedQueueID',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "CreatedStateID" is not sortable',
        Attribute => 'CreatedStateID',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "CreatedTypeID" is not sortable',
        Attribute => 'CreatedTypeID',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "HistoricOwnerID" is not sortable',
        Attribute => 'HistoricOwnerID',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "HistoricPriorityID" is not sortable',
        Attribute => 'HistoricPriorityID',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "HistoricQueueID" is not sortable',
        Attribute => 'HistoricQueueID',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "HistoricStateID" is not sortable',
        Attribute => 'HistoricStateID',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "HistoricTypeID" is not sortable',
        Attribute => 'HistoricTypeID',
        Expected  => undef
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

## prepare test contacts  ##
# first contact
my $ContactID1 = $Helper->TestContactCreate();
$Self->True(
    $ContactID1,
    'Created first contact'
);
my %Contact1 = $Kernel::OM->Get('Contact')->ContactGet(
    ID => $ContactID1
);
my $UserID1 = $Contact1{AssignedUserID};

# second contact
my $ContactID2 = $Helper->TestContactCreate();
$Self->True(
    $ContactID2,
    'Created second contact'
);
my %Contact2 = $Kernel::OM->Get('Contact')->ContactGet(
    ID => $ContactID2
);
my $UserID2 = $Contact2{AssignedUserID};

# discard contact object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Contact'],
);

## prepare id mappings
my $PriorityID1 = 1;
my $PriorityID2 = 2;
my $QueueID1    = 1;
my $QueueID2    = 2;
my $StateID1    = 1;
my $StateID2    = 2;
my $TypeID1     = 1;
my $TypeID2     = 2;

## prepare test tickets ##
# first ticket
my $TicketID1 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => $QueueID1,
    Lock           => 'unlock',
    PriorityID     => $PriorityID1,
    StateID        => $StateID1,
    TypeID         => $TypeID1,
    OrganisationID => 1,
    ContactID      => $ContactID1,
    OwnerID        => $UserID1,
    ResponsibleID  => 1,
    UserID         => 1
);
$Self->True(
    $TicketID1,
    'Created first ticket'
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Ticket'],
);

# second ticket
$Helper->FixedTimeAddSeconds(60);
my $TicketID2 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => $QueueID2,
    Lock           => 'unlock',
    PriorityID     => $PriorityID2,
    StateID        => $StateID2,
    TypeID         => $TypeID2,
    OrganisationID => 1,
    ContactID      => $ContactID2,
    OwnerID        => $UserID2,
    ResponsibleID  => 1,
    UserID         => 1
);
$Self->True(
    $TicketID2,
    'Created second ticket'
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Ticket'],
);

$Helper->FixedTimeAddSeconds(60);
my $CloseTicket2 = $Kernel::OM->Get('Ticket')->TicketStateSet(
    State     => 'closed',
    TicketID  => $TicketID2,
    UserID    => 1,
);
$Self->True(
    $CloseTicket2,
    'Closed second ticket'
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Ticket'],
);

# third ticket
$Helper->FixedTimeAddSeconds(60);
my $TicketID3 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => $QueueID1,
    Lock           => 'unlock',
    PriorityID     => $PriorityID2,
    StateID        => $StateID1,
    TypeID         => $TypeID2,
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
        Name     => 'Search: Field ChangeTime / Operator EQ / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeTime',
                    Operator => 'EQ',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field ChangeTime / Operator EQ / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeTime',
                    Operator => 'EQ',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field ChangeTime / Operator LT / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeTime',
                    Operator => 'LT',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: Field ChangeTime / Operator LT / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeTime',
                    Operator => 'LT',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: Field ChangeTime / Operator GT / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeTime',
                    Operator => 'GT',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$TicketID2,$TicketID3]
    },
    {
        Name     => 'Search: Field ChangeTime / Operator GT / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeTime',
                    Operator => 'GT',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field ChangeTime / Operator LTE / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeTime',
                    Operator => 'LTE',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2]
    },
    {
        Name     => 'Search: Field ChangeTime / Operator LTE / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeTime',
                    Operator => 'LTE',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2]
    },
    {
        Name     => 'Search: Field ChangeTime / Operator GTE / Value2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeTime',
                    Operator => 'GTE',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field ChangeTime / Operator GTE / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeTime',
                    Operator => 'GTE',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field CloseTime / Operator EQ / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'CloseTime',
                    Operator => 'EQ',
                    Value    => '2014-01-01 12:02:00'
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field CloseTime / Operator EQ / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'CloseTime',
                    Operator => 'EQ',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field CloseTime / Operator LT / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'CloseTime',
                    Operator => 'LT',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field CloseTime / Operator LT / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'CloseTime',
                    Operator => 'LT',
                    Value    => '-1m'
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field CloseTime / Operator GT / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'CloseTime',
                    Operator => 'GT',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field CloseTime / Operator GT / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'CloseTime',
                    Operator => 'GT',
                    Value    => '-1m'
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field CloseTime / Operator LTE / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'CloseTime',
                    Operator => 'LTE',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field CloseTime / Operator LTE / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'CloseTime',
                    Operator => 'LTE',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field CloseTime / Operator GTE / Value2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'CloseTime',
                    Operator => 'GTE',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field CloseTime / Operator GTE / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'CloseTime',
                    Operator => 'GTE',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field CreatedPriorityID / Operator EQ / Value $PriorityID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedPriorityID',
                    Operator => 'EQ',
                    Value    => $PriorityID2
                }
            ]
        },
        Expected => [$TicketID2,$TicketID3]
    },
    {
        Name     => 'Search: Field CreatedPriorityID / Operator NE / Value $PriorityID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedPriorityID',
                    Operator => 'NE',
                    Value    => $PriorityID2
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: Field CreatedPriorityID / Operator IN / Value [$PriorityID1,$PriorityID2]',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedPriorityID',
                    Operator => 'IN',
                    Value    => [$PriorityID1,$PriorityID2]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field CreatedPriorityID / Operator !IN / Value [$PriorityID1,$PriorityID2]',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedPriorityID',
                    Operator => '!IN',
                    Value    => [$PriorityID1,$PriorityID2]
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field CreatedPriorityID / Operator LT / Value $PriorityID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedPriorityID',
                    Operator => 'LT',
                    Value    => $PriorityID2
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: Field CreatedPriorityID / Operator GT / Value $PriorityID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedPriorityID',
                    Operator => 'GT',
                    Value    => $PriorityID2
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field CreatedPriorityID / Operator LTE / Value $PriorityID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedPriorityID',
                    Operator => 'LTE',
                    Value    => $PriorityID2
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field CreatedPriorityID / Operator GTE / Value $PriorityID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedPriorityID',
                    Operator => 'GTE',
                    Value    => $PriorityID2
                }
            ]
        },
        Expected => [$TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field CreatedQueueID / Operator EQ / Value $QueueID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedQueueID',
                    Operator => 'EQ',
                    Value    => $QueueID2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field CreatedQueueID / Operator NE / Value $QueueID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedQueueID',
                    Operator => 'NE',
                    Value    => $QueueID2
                }
            ]
        },
        Expected => [$TicketID1, $TicketID3]
    },
    {
        Name     => 'Search: Field CreatedQueueID / Operator IN / Value [$QueueID1,$QueueID2]',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedQueueID',
                    Operator => 'IN',
                    Value    => [$QueueID1,$QueueID2]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field CreatedQueueID / Operator !IN / Value [$QueueID1,$QueueID2]',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedQueueID',
                    Operator => '!IN',
                    Value    => [$QueueID1,$QueueID2]
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field CreatedQueueID / Operator LT / Value $QueueID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedQueueID',
                    Operator => 'LT',
                    Value    => $QueueID2
                }
            ]
        },
        Expected => [$TicketID1, $TicketID3]
    },
    {
        Name     => 'Search: Field CreatedQueueID / Operator GT / Value $QueueID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedQueueID',
                    Operator => 'GT',
                    Value    => $QueueID2
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field CreatedQueueID / Operator LTE / Value $QueueID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedQueueID',
                    Operator => 'LTE',
                    Value    => $QueueID2
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field CreatedQueueID / Operator GTE / Value $QueueID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedQueueID',
                    Operator => 'GTE',
                    Value    => $QueueID2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field CreatedStateID / Operator EQ / Value $StateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedStateID',
                    Operator => 'EQ',
                    Value    => $StateID2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field CreatedStateID / Operator NE / Value $StateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedStateID',
                    Operator => 'NE',
                    Value    => $StateID2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field CreatedStateID / Operator IN / Value [$StateID1,$StateID2]',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedStateID',
                    Operator => 'IN',
                    Value    => [$StateID1,$StateID2]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field CreatedStateID / Operator !IN / Value [$StateID1,$StateID2]',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedStateID',
                    Operator => '!IN',
                    Value    => [$StateID1,$StateID2]
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field CreatedStateID / Operator LT / Value $StateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedStateID',
                    Operator => 'LT',
                    Value    => $StateID2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field CreatedStateID / Operator GT / Value $StateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedStateID',
                    Operator => 'GT',
                    Value    => $StateID2
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field CreatedStateID / Operator LTE / Value $StateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedStateID',
                    Operator => 'LTE',
                    Value    => $StateID2
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field CreatedStateID / Operator GTE / Value $StateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedStateID',
                    Operator => 'GTE',
                    Value    => $StateID2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field CreatedTypeID / Operator EQ / Value $TypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedTypeID',
                    Operator => 'EQ',
                    Value    => $TypeID2
                }
            ]
        },
        Expected => [$TicketID2,$TicketID3]
    },
    {
        Name     => 'Search: Field CreatedTypeID / Operator NE / Value $TypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedTypeID',
                    Operator => 'NE',
                    Value    => $TypeID2
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: Field CreatedTypeID / Operator IN / Value [$TypeID1,$TypeID2]',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedTypeID',
                    Operator => 'IN',
                    Value    => [$TypeID1,$TypeID2]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field CreatedTypeID / Operator !IN / Value [$TypeID1,$TypeID2]',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedTypeID',
                    Operator => '!IN',
                    Value    => [$TypeID1,$TypeID2]
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field CreatedTypeID / Operator LT / Value $TypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedTypeID',
                    Operator => 'LT',
                    Value    => $TypeID2
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: Field CreatedTypeID / Operator GT / Value $TypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedTypeID',
                    Operator => 'GT',
                    Value    => $TypeID2
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field CreatedTypeID / Operator LTE / Value $TypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedTypeID',
                    Operator => 'LTE',
                    Value    => $TypeID2
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field CreatedTypeID / Operator GTE / Value $TypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedTypeID',
                    Operator => 'GTE',
                    Value    => $TypeID2
                }
            ]
        },
        Expected => [$TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field HistoricOwnerID / Operator EQ / Value $UserID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricOwnerID',
                    Operator => 'EQ',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field HistoricOwnerID / Operator NE / Value 1',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricOwnerID',
                    Operator => 'NE',
                    Value    => 1
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: Field HistoricOwnerID / Operator IN / Value [$UserID1,$UserID2]',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricOwnerID',
                    Operator => 'IN',
                    Value    => [$UserID1,$UserID2]
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: Field HistoricOwnerID / Operator !IN / Value [1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricOwnerID',
                    Operator => '!IN',
                    Value    => [1]
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: Field HistoricOwnerID / Operator LT / Value $UserID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricOwnerID',
                    Operator => 'LT',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => 'Search: Field HistoricOwnerID / Operator GT / Value $UserID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricOwnerID',
                    Operator => 'GT',
                    Value    => $UserID2
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field HistoricOwnerID / Operator LTE / Value $UserID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricOwnerID',
                    Operator => 'LTE',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field HistoricOwnerID / Operator GTE / Value $UserID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricOwnerID',
                    Operator => 'GTE',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field HistoricPriorityID / Operator EQ / Value $PriorityID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricPriorityID',
                    Operator => 'EQ',
                    Value    => $PriorityID2
                }
            ]
        },
        Expected => [$TicketID2,$TicketID3]
    },
    {
        Name     => 'Search: Field HistoricPriorityID / Operator NE / Value $PriorityID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricPriorityID',
                    Operator => 'NE',
                    Value    => $PriorityID2
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: Field HistoricPriorityID / Operator IN / Value [$PriorityID1,$PriorityID2]',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricPriorityID',
                    Operator => 'IN',
                    Value    => [$PriorityID1,$PriorityID2]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field HistoricPriorityID / Operator !IN / Value [$PriorityID1,$PriorityID2]',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricPriorityID',
                    Operator => '!IN',
                    Value    => [$PriorityID1,$PriorityID2]
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field HistoricPriorityID / Operator LT / Value $PriorityID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricPriorityID',
                    Operator => 'LT',
                    Value    => $PriorityID2
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: Field HistoricPriorityID / Operator GT / Value $PriorityID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricPriorityID',
                    Operator => 'GT',
                    Value    => $PriorityID2
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field HistoricPriorityID / Operator LTE / Value $PriorityID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricPriorityID',
                    Operator => 'LTE',
                    Value    => $PriorityID2
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field HistoricPriorityID / Operator GTE / Value $PriorityID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricPriorityID',
                    Operator => 'GTE',
                    Value    => $PriorityID2
                }
            ]
        },
        Expected => [$TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field HistoricQueueID / Operator EQ / Value $QueueID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricQueueID',
                    Operator => 'EQ',
                    Value    => $QueueID2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field HistoricQueueID / Operator NE / Value $QueueID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricQueueID',
                    Operator => 'NE',
                    Value    => $QueueID2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field HistoricQueueID / Operator IN / Value [$QueueID1,$QueueID2]',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricQueueID',
                    Operator => 'IN',
                    Value    => [$QueueID1,$QueueID2]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field HistoricQueueID / Operator !IN / Value [$QueueID1,$QueueID2]',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricQueueID',
                    Operator => '!IN',
                    Value    => [$QueueID1,$QueueID2]
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field HistoricQueueID / Operator LT / Value $QueueID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricQueueID',
                    Operator => 'LT',
                    Value    => $QueueID2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field HistoricQueueID / Operator GT / Value $QueueID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricQueueID',
                    Operator => 'GT',
                    Value    => $QueueID2
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field HistoricQueueID / Operator LTE / Value $QueueID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricQueueID',
                    Operator => 'LTE',
                    Value    => $QueueID2
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field HistoricQueueID / Operator GTE / Value $QueueID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricQueueID',
                    Operator => 'GTE',
                    Value    => $QueueID2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field HistoricStateID / Operator EQ / Value $StateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricStateID',
                    Operator => 'EQ',
                    Value    => $StateID2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field HistoricStateID / Operator NE / Value $StateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricStateID',
                    Operator => 'NE',
                    Value    => $StateID2
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field HistoricStateID / Operator IN / Value [$StateID1,$StateID2]',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricStateID',
                    Operator => 'IN',
                    Value    => [$StateID1,$StateID2]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field HistoricStateID / Operator !IN / Value [$StateID1,$StateID2]',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricStateID',
                    Operator => '!IN',
                    Value    => [$StateID1,$StateID2]
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field HistoricStateID / Operator LT / Value $StateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricStateID',
                    Operator => 'LT',
                    Value    => $StateID2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field HistoricStateID / Operator GT / Value $StateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricStateID',
                    Operator => 'GT',
                    Value    => $StateID2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field HistoricStateID / Operator LTE / Value $StateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricStateID',
                    Operator => 'LTE',
                    Value    => $StateID2
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field HistoricStateID / Operator GTE / Value $StateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricStateID',
                    Operator => 'GTE',
                    Value    => $StateID2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field HistoricTypeID / Operator EQ / Value $TypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricTypeID',
                    Operator => 'EQ',
                    Value    => $TypeID2
                }
            ]
        },
        Expected => [$TicketID2,$TicketID3]
    },
    {
        Name     => 'Search: Field HistoricTypeID / Operator NE / Value $TypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricTypeID',
                    Operator => 'NE',
                    Value    => $TypeID2
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: Field HistoricTypeID / Operator IN / Value [$TypeID1,$TypeID2]',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricTypeID',
                    Operator => 'IN',
                    Value    => [$TypeID1,$TypeID2]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field HistoricTypeID / Operator !IN / Value [$TypeID1,$TypeID2]',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricTypeID',
                    Operator => '!IN',
                    Value    => [$TypeID1,$TypeID2]
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field HistoricTypeID / Operator LT / Value $TypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricTypeID',
                    Operator => 'LT',
                    Value    => $TypeID2
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: Field HistoricTypeID / Operator GT / Value $TypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricTypeID',
                    Operator => 'GT',
                    Value    => $TypeID2
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field HistoricTypeID / Operator LTE / Value $TypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricTypeID',
                    Operator => 'LTE',
                    Value    => $TypeID2
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field HistoricTypeID / Operator GTE / Value $TypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'HistoricTypeID',
                    Operator => 'GTE',
                    Value    => $TypeID2
                }
            ]
        },
        Expected => [$TicketID2, $TicketID3]
    },
    ## combined search ##
    {
        Name     => 'Search: Field CreatedStateID / Operator EQ / Value $StateID2 AND Field CreatedTypeID / Operator EQ / Value $TypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedStateID',
                    Operator => 'EQ',
                    Value    => $StateID2
                },
                {
                    Field    => 'CreatedTypeID',
                    Operator => 'EQ',
                    Value    => $TypeID2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field CreatedStateID / Operator EQ / Value $StateID2 OR Field CreatedTypeID / Operator EQ / Value $TypeID2',
        Search   => {
            'OR' => [
                {
                    Field    => 'CreatedStateID',
                    Operator => 'EQ',
                    Value    => $StateID2
                },
                {
                    Field    => 'CreatedTypeID',
                    Operator => 'EQ',
                    Value    => $TypeID2
                }
            ]
        },
        Expected => [$TicketID2,$TicketID3]
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
# attributes of this backend are not sortable

my $TimeStamp = $Kernel::OM->Get('Time')->CurrentTimestamp();
$Self->Is(
    $TimeStamp,
    '2014-01-01 12:03:00',
    'Timestamp before first relative search'
);
my @FirstResult = $ObjectSearch->Search(
    ObjectType => 'Ticket',
    Result     => 'ARRAY',
    Search     => {
        'AND' => [
            {
                Field    => 'CloseTime',
                Operator => 'GTE',
                Value    => '-1m'
            }
        ]
    },
    UserType   => 'Agent',
    UserID     => 1,
);
$Self->IsDeeply(
    \@FirstResult,
    [$TicketID2],
    'Result of first relative search'
);
$Helper->FixedTimeAddSeconds(60);
$TimeStamp = $Kernel::OM->Get('Time')->CurrentTimestamp();
$Self->Is(
    $TimeStamp,
    '2014-01-01 12:04:00',
    'Timestamp before second relative search'
);
my @SecondResult = $ObjectSearch->Search(
    ObjectType => 'Ticket',
    Result     => 'ARRAY',
    Search     => {
        'AND' => [
            {
                Field    => 'CloseTime',
                Operator => 'GTE',
                Value    => '-1m'
            }
        ]
    },
    UserType   => 'Agent',
    UserID     => 1,
);
$Self->IsDeeply(
    \@SecondResult,
    [],
    'Result of second relative search'
);

# reset fixed time
$Helper->FixedTimeUnset();

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
