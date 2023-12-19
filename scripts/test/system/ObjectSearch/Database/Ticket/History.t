# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
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
        ChangeTime        => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','LT','LTE','GT','GTE'],
            ValueType    => 'DATETIME'
        },
        CloseTime         => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','LT','LTE','GT','GTE'],
            ValueType    => 'DATETIME'
        },
        CreatedPriorityID => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType    => 'NUMERIC'
        },
        CreatedQueueID    => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType    => 'NUMERIC'
        },
        CreatedStateID    => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType    => 'NUMERIC'
        },
        CreatedTypeID     => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType    => 'NUMERIC'
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
            ]
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
            ]
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
            ]
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
            ]
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
            ]
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
            ]
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
            ]
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
            ]
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
            ]
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
            ]
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
    ContactID      => 1,
    OwnerID        => 1,
    ResponsibleID  => 1,
    UserID         => 1
);
$Self->True(
    $TicketID1,
    'Created first ticket'
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
    ContactID      => 1,
    OwnerID        => 1,
    ResponsibleID  => 1,
    UserID         => 1
);
$Self->True(
    $TicketID2,
    'Created second ticket'
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
