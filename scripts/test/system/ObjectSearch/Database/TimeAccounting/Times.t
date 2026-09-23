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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::TimeAccounting::Times';

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
        CreateTime => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType      => 'DATETIME'
        },
        ChangeTime => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType      => 'DATETIME'
        },
        StartTime => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType      => 'DATE'
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
            Field    => 'CreateTime',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'CreateTime',
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
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Field invalid',
        Search       => {
            Field    => 'Test',
            Operator => 'EQ',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator undef',
        Search       => {
            Field    => 'CreateTime',
            Operator => undef,
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'CreateTime',
            Operator => 'Test',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field CreateTime / Operator EQ / absolute value',
        Search       => {
            Field    => 'CreateTime',
            Operator => 'EQ',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'ta.create_time = \'2014-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreateTime / Operator EQ / relative value',
        Search       => {
            Field    => 'CreateTime',
            Operator => 'EQ',
            Value    => '+1h'
        },
        Expected     => {
            'Where' => [
                'ta.create_time = \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field CreateTime / Operator NE / absolute value',
        Search       => {
            Field    => 'CreateTime',
            Operator => 'NE',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'ta.create_time != \'2014-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreateTime / Operator NE / relative value',
        Search       => {
            Field    => 'CreateTime',
            Operator => 'NE',
            Value    => '+1h'
        },
        Expected     => {
            'Where' => [
                'ta.create_time != \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field CreateTime / Operator LT / absolute value',
        Search       => {
            Field    => 'CreateTime',
            Operator => 'LT',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'ta.create_time < \'2014-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreateTime / Operator LT / relative value',
        Search       => {
            Field    => 'CreateTime',
            Operator => 'LT',
            Value    => '+1h'
        },
        Expected     => {
            'Where' => [
                'ta.create_time < \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field CreateTime / Operator GT / absolute value',
        Search       => {
            Field    => 'CreateTime',
            Operator => 'GT',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'ta.create_time > \'2014-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreateTime / Operator GT / relative value',
        Search       => {
            Field    => 'CreateTime',
            Operator => 'GT',
            Value    => '+1h'
        },
        Expected     => {
            'Where' => [
                'ta.create_time > \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field CreateTime / Operator LTE / absolute value',
        Search       => {
            Field    => 'CreateTime',
            Operator => 'LTE',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'ta.create_time <= \'2014-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreateTime / Operator LTE / relative value',
        Search       => {
            Field    => 'CreateTime',
            Operator => 'LTE',
            Value    => '+1h'
        },
        Expected     => {
            'Where' => [
                'ta.create_time <= \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field CreateTime / Operator GTE / absolute value',
        Search       => {
            Field    => 'CreateTime',
            Operator => 'GTE',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'ta.create_time >= \'2014-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreateTime / Operator GTE / relative value',
        Search       => {
            Field    => 'CreateTime',
            Operator => 'GTE',
            Value    => '+1h'
        },
        Expected     => {
            'Where' => [
                'ta.create_time >= \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeTime / Operator EQ / absolute value',
        Search       => {
            Field    => 'ChangeTime',
            Operator => 'EQ',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'ta.change_time = \'2014-01-01 12:00:00\''
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
            'Where' => [
                'ta.change_time = \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeTime / Operator NE / absolute value',
        Search       => {
            Field    => 'ChangeTime',
            Operator => 'NE',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'ta.change_time != \'2014-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeTime / Operator NE / relative value',
        Search       => {
            Field    => 'ChangeTime',
            Operator => 'NE',
            Value    => '+1h'
        },
        Expected     => {
            'Where' => [
                'ta.change_time != \'2014-01-01 13:00:00\''
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
            'Where' => [
                'ta.change_time < \'2014-01-01 12:00:00\''
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
            'Where' => [
                'ta.change_time < \'2014-01-01 13:00:00\''
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
            'Where' => [
                'ta.change_time > \'2014-01-01 12:00:00\''
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
            'Where' => [
                'ta.change_time > \'2014-01-01 13:00:00\''
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
            'Where' => [
                'ta.change_time <= \'2014-01-01 12:00:00\''
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
            'Where' => [
                'ta.change_time <= \'2014-01-01 13:00:00\''
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
            'Where' => [
                'ta.change_time >= \'2014-01-01 12:00:00\''
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
            'Where' => [
                'ta.change_time >= \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field StartTime / Operator EQ / absolute value',
        Search       => {
            Field    => 'StartTime',
            Operator => 'EQ',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'ta.start_time = \'2014-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StartTime / Operator EQ / relative value',
        Search       => {
            Field    => 'StartTime',
            Operator => 'EQ',
            Value    => '+1h'
        },
        Expected     => {
            'Where' => [
                'ta.start_time = \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field StartTime / Operator NE / absolute value',
        Search       => {
            Field    => 'StartTime',
            Operator => 'NE',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'ta.start_time != \'2014-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StartTime / Operator NE / relative value',
        Search       => {
            Field    => 'StartTime',
            Operator => 'NE',
            Value    => '+1h'
        },
        Expected     => {
            'Where' => [
                'ta.start_time != \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field StartTime / Operator LT / absolute value',
        Search       => {
            Field    => 'StartTime',
            Operator => 'LT',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'ta.start_time < \'2014-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StartTime / Operator LT / relative value',
        Search       => {
            Field    => 'StartTime',
            Operator => 'LT',
            Value    => '+1h'
        },
        Expected     => {
            'Where' => [
                'ta.start_time < \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field StartTime / Operator GT / absolute value',
        Search       => {
            Field    => 'StartTime',
            Operator => 'GT',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'ta.start_time > \'2014-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StartTime / Operator GT / relative value',
        Search       => {
            Field    => 'StartTime',
            Operator => 'GT',
            Value    => '+1h'
        },
        Expected     => {
            'Where' => [
                'ta.start_time > \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field StartTime / Operator LTE / absolute value',
        Search       => {
            Field    => 'StartTime',
            Operator => 'LTE',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'ta.start_time <= \'2014-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StartTime / Operator LTE / relative value',
        Search       => {
            Field    => 'StartTime',
            Operator => 'LTE',
            Value    => '+1h'
        },
        Expected     => {
            'Where' => [
                'ta.start_time <= \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field StartTime / Operator GTE / absolute value',
        Search       => {
            Field    => 'StartTime',
            Operator => 'GTE',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'ta.start_time >= \'2014-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StartTime / Operator GTE / relative value',
        Search       => {
            Field    => 'StartTime',
            Operator => 'GTE',
            Value    => '+1h'
        },
        Expected     => {
            'Where' => [
                'ta.start_time >= \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
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
        Name      => 'Sort: Attribute "CreateTime"',
        Attribute => 'CreateTime',
        Expected  => {
            Select        => [ 'ta.create_time AS SortAttr0' ],
            OrderBy       => [ 'SortAttr0' ]
        }
    },
    {
        Name      => 'Sort: Attribute "ChangeTime"',
        Attribute => 'ChangeTime',
        Expected  => {
            Select  => [ 'ta.change_time AS SortAttr0' ],
            OrderBy => [ 'SortAttr0' ]
        }
    },
    {
        Name      => 'Sort: Attribute "StartTime"',
        Attribute => 'StartTime',
        Expected  => {
            Select  => [ 'ta.start_time AS SortAttr0' ],
            OrderBy => [ 'SortAttr0' ]
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

## prepare test ticket ##
my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title    => 'UnitTest',
    OwnerID  => 1,
    Queue    => 'Junk',
    Priority => '3 normal',
    UserID   => 1,
    State    => 'new',
    Lock     => 'unlock'
);
$Self->True(
    $TicketID,
    'ticket created'
);

## prepare test time accountings ##
# first time accounting
my $SystemTime1 = $Kernel::OM->Get('Time')->SystemTime();
my $TimeAccountingID1 = $Kernel::OM->Get('TimeAccounting')->TimeAccountingCreate(
    TicketID           => $TicketID,
    StartTime          => $Kernel::OM->Get('Time')->CurrentTimestamp(),
    TimeUnit           => 1,
    IsInvoiced         => 0,
    UserID             => 1,
    UserType           => 'Agent',
    ExecutingContactID => 1,
);
$Self->True(
    $TimeAccountingID1,
    'first time accounting created'
);
# second time accounting
$Helper->FixedTimeAddSeconds(60);
my $SystemTime2 = $Kernel::OM->Get('Time')->SystemTime();
my $TimeAccountingID2 = $Kernel::OM->Get('TimeAccounting')->TimeAccountingCreate(
    TicketID           => $TicketID,
    StartTime          => $Kernel::OM->Get('Time')->CurrentTimestamp(),
    TimeUnit           => 1,
    IsInvoiced         => 0,
    UserID             => 1,
    UserType           => 'Agent',
    ExecutingContactID => 1,
);
$Self->True(
    $TimeAccountingID2,
    'second time accounting created'
);
# third time accounting
$Helper->FixedTimeAddSeconds(60);
my $SystemTime3 = $Kernel::OM->Get('Time')->SystemTime();
my $TimeAccountingID3 = $Kernel::OM->Get('TimeAccounting')->TimeAccountingCreate(
    TicketID           => $TicketID,
    StartTime          => $Kernel::OM->Get('Time')->CurrentTimestamp(),
    TimeUnit           => 1,
    IsInvoiced         => 0,
    UserID             => 1,
    UserType           => 'Agent',
    ExecutingContactID => 1,
);
$Self->True(
    $TimeAccountingID3,
    'third time accounting created'
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['TimeAccounting'],
);

$Kernel::OM->ObjectsDiscard(
    Objects => ['Ticket'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field CreateTime / Operator EQ / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateTime',
                    Operator => 'EQ',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$TimeAccountingID2]
    },
    {
        Name     => 'Search: Field CreateTime / Operator EQ / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateTime',
                    Operator => 'EQ',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$TimeAccountingID2]
    },
    {
        Name     => 'Search: Field CreateTime / Operator NE / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateTime',
                    Operator => 'NE',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$TimeAccountingID1,$TimeAccountingID3]
    },
    {
        Name     => 'Search: Field CreateTime / Operator NE / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateTime',
                    Operator => 'NE',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$TimeAccountingID1,$TimeAccountingID3]
    },
    {
        Name     => 'Search: Field CreateTime / Operator LT / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateTime',
                    Operator => 'LT',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$TimeAccountingID1]
    },
    {
        Name     => 'Search: Field CreateTime / Operator LT / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateTime',
                    Operator => 'LT',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$TimeAccountingID1]
    },
    {
        Name     => 'Search: Field CreateTime / Operator GT / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateTime',
                    Operator => 'GT',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$TimeAccountingID3]
    },
    {
        Name     => 'Search: Field CreateTime / Operator GT / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateTime',
                    Operator => 'GT',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$TimeAccountingID3]
    },
    {
        Name     => 'Search: Field CreateTime / Operator LTE / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateTime',
                    Operator => 'LTE',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$TimeAccountingID1,$TimeAccountingID2]
    },
    {
        Name     => 'Search: Field CreateTime / Operator LTE / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateTime',
                    Operator => 'LTE',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$TimeAccountingID1,$TimeAccountingID2]
    },
    {
        Name     => 'Search: Field CreateTime / Operator GTE / Value2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateTime',
                    Operator => 'GTE',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$TimeAccountingID2,$TimeAccountingID3]
    },
    {
        Name     => 'Search: Field CreateTime / Operator GTE / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateTime',
                    Operator => 'GTE',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$TimeAccountingID2,$TimeAccountingID3]
    },
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
        Expected => [$TimeAccountingID2]
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
        Expected => [$TimeAccountingID2]
    },
    {
        Name     => 'Search: Field ChangeTime / Operator NE / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeTime',
                    Operator => 'NE',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$TimeAccountingID1,$TimeAccountingID3]
    },
    {
        Name     => 'Search: Field ChangeTime / Operator NE / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeTime',
                    Operator => 'NE',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$TimeAccountingID1,$TimeAccountingID3]
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
        Expected => [$TimeAccountingID1]
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
        Expected => [$TimeAccountingID1]
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
        Expected => [$TimeAccountingID3]
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
        Expected => [$TimeAccountingID3]
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
        Expected => [$TimeAccountingID1,$TimeAccountingID2]
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
        Expected => [$TimeAccountingID1,$TimeAccountingID2]
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
        Expected => [$TimeAccountingID2,$TimeAccountingID3]
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
        Expected => [$TimeAccountingID2,$TimeAccountingID3]
    },
    {
        Name     => 'Search: Field StartTime / Operator EQ / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'StartTime',
                    Operator => 'EQ',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$TimeAccountingID2]
    },
    {
        Name     => 'Search: Field StartTime / Operator EQ / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'StartTime',
                    Operator => 'EQ',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$TimeAccountingID2]
    },
    {
        Name     => 'Search: Field StartTime / Operator NE / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'StartTime',
                    Operator => 'NE',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$TimeAccountingID1,$TimeAccountingID3]
    },
    {
        Name     => 'Search: Field StartTime / Operator NE / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'StartTime',
                    Operator => 'NE',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$TimeAccountingID1,$TimeAccountingID3]
    },
    {
        Name     => 'Search: Field StartTime / Operator LT / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'StartTime',
                    Operator => 'LT',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$TimeAccountingID1]
    },
    {
        Name     => 'Search: Field StartTime / Operator LT / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'StartTime',
                    Operator => 'LT',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$TimeAccountingID1]
    },
    {
        Name     => 'Search: Field StartTime / Operator GT / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'StartTime',
                    Operator => 'GT',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$TimeAccountingID3]
    },
    {
        Name     => 'Search: Field StartTime / Operator GT / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'StartTime',
                    Operator => 'GT',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$TimeAccountingID3]
    },
    {
        Name     => 'Search: Field StartTime / Operator LTE / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'StartTime',
                    Operator => 'LTE',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$TimeAccountingID1,$TimeAccountingID2]
    },
    {
        Name     => 'Search: Field StartTime / Operator LTE / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'StartTime',
                    Operator => 'LTE',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$TimeAccountingID1,$TimeAccountingID2]
    },
    {
        Name     => 'Search: Field StartTime / Operator GTE / Value2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'StartTime',
                    Operator => 'GTE',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$TimeAccountingID2,$TimeAccountingID3]
    },
    {
        Name     => 'Search: Field StartTime / Operator GTE / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'StartTime',
                    Operator => 'GTE',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$TimeAccountingID2,$TimeAccountingID3]
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'TimeAccounting',
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
        Name     => 'Sort: Field CreateTime',
        Sort     => [
            {
                Field => 'CreateTime'
            }
        ],
        Expected => [$TimeAccountingID1,$TimeAccountingID2,$TimeAccountingID3]
    },
    {
        Name     => 'Sort: Field CreateTime / Direction ascending',
        Sort     => [
            {
                Field     => 'CreateTime',
                Direction => 'ascending'
            }
        ],
        Expected => [$TimeAccountingID1,$TimeAccountingID2,$TimeAccountingID3]
    },
    {
        Name     => 'Sort: Field CreateTime / Direction descending',
        Sort     => [
            {
                Field     => 'CreateTime',
                Direction => 'descending'
            }
        ],
        Expected => [$TimeAccountingID3,$TimeAccountingID2,$TimeAccountingID1]
    },
    {
        Name     => 'Sort: Field ChangeTime',
        Sort     => [
            {
                Field => 'ChangeTime'
            }
        ],
        Expected => [$TimeAccountingID1,$TimeAccountingID2,$TimeAccountingID3]
    },
    {
        Name     => 'Sort: Field ChangeTime / Direction ascending',
        Sort     => [
            {
                Field     => 'ChangeTime',
                Direction => 'ascending'
            }
        ],
        Expected => [$TimeAccountingID1,$TimeAccountingID2,$TimeAccountingID3]
    },
    {
        Name     => 'Sort: Field ChangeTime / Direction descending',
        Sort     => [
            {
                Field     => 'ChangeTime',
                Direction => 'descending'
            }
        ],
        Expected => [$TimeAccountingID3,$TimeAccountingID2,$TimeAccountingID1]
    },
    {
        Name     => 'Sort: Field StartTime',
        Sort     => [
            {
                Field => 'StartTime'
            }
        ],
        Expected => [$TimeAccountingID1,$TimeAccountingID2,$TimeAccountingID3]
    },
    {
        Name     => 'Sort: Field StartTime / Direction ascending',
        Sort     => [
            {
                Field     => 'StartTime',
                Direction => 'ascending'
            }
        ],
        Expected => [$TimeAccountingID1,$TimeAccountingID2,$TimeAccountingID3]
    },
    {
        Name     => 'Sort: Field StartTime / Direction descending',
        Sort     => [
            {
                Field     => 'StartTime',
                Direction => 'descending'
            }
        ],
        Expected => [$TimeAccountingID3,$TimeAccountingID2,$TimeAccountingID1]
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'TimeAccounting',
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

my $TimeStamp = $Kernel::OM->Get('Time')->CurrentTimestamp();
$Self->Is(
    $TimeStamp,
    '2014-01-01 12:02:00',
    'Timestamp before first relative search'
);
my @FirstResult = $ObjectSearch->Search(
    ObjectType => 'TimeAccounting',
    Result     => 'ARRAY',
    Search     => {
        'AND' => [
            {
                Field    => 'ChangeTime',
                Operator => 'LTE',
                Value    => '-1m'
            }
        ]
    },
    UserType   => 'Agent',
    UserID     => 1,
);
$Self->IsDeeply(
    \@FirstResult,
    [$TimeAccountingID1,$TimeAccountingID2],
    'Result of first relative search'
);
$Helper->FixedTimeAddSeconds(60);
$TimeStamp = $Kernel::OM->Get('Time')->CurrentTimestamp();
$Self->Is(
    $TimeStamp,
    '2014-01-01 12:03:00',
    'Timestamp before second relative search'
);
my @SecondResult = $ObjectSearch->Search(
    ObjectType => 'TimeAccounting',
    Result     => 'ARRAY',
    Search     => {
        'AND' => [
            {
                Field    => 'ChangeTime',
                Operator => 'LTE',
                Value    => '-1m'
            }
        ]
    },
    UserType   => 'Agent',
    UserID     => 1,
);
$Self->IsDeeply(
    \@SecondResult,
    [$TimeAccountingID1,$TimeAccountingID2,$TimeAccountingID3],
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
