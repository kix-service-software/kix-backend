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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Automation::JobRun::Times';

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
        StartTime => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType      => 'DATETIME'
        },
        EndTime => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType      => 'DATETIME'
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
            Field    => 'StartTime',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'StartTime',
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
            Field    => 'StartTime',
            Operator => undef,
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'StartTime',
            Operator => 'Test',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => undef
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
                'ajr.start_time = \'2014-01-01 12:00:00\''
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
                'ajr.start_time = \'2014-01-01 13:00:00\''
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
                'ajr.start_time != \'2014-01-01 12:00:00\''
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
                'ajr.start_time != \'2014-01-01 13:00:00\''
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
                'ajr.start_time < \'2014-01-01 12:00:00\''
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
                'ajr.start_time < \'2014-01-01 13:00:00\''
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
                'ajr.start_time > \'2014-01-01 12:00:00\''
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
                'ajr.start_time > \'2014-01-01 13:00:00\''
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
                'ajr.start_time <= \'2014-01-01 12:00:00\''
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
                'ajr.start_time <= \'2014-01-01 13:00:00\''
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
                'ajr.start_time >= \'2014-01-01 12:00:00\''
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
                'ajr.start_time >= \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field EndTime / Operator EQ / absolute value',
        Search       => {
            Field    => 'EndTime',
            Operator => 'EQ',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'ajr.end_time = \'2014-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field EndTime / Operator EQ / relative value',
        Search       => {
            Field    => 'EndTime',
            Operator => 'EQ',
            Value    => '+1h'
        },
        Expected     => {
            'Where' => [
                'ajr.end_time = \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field EndTime / Operator NE / absolute value',
        Search       => {
            Field    => 'EndTime',
            Operator => 'NE',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'ajr.end_time != \'2014-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field EndTime / Operator NE / relative value',
        Search       => {
            Field    => 'EndTime',
            Operator => 'NE',
            Value    => '+1h'
        },
        Expected     => {
            'Where' => [
                'ajr.end_time != \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field EndTime / Operator LT / absolute value',
        Search       => {
            Field    => 'EndTime',
            Operator => 'LT',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'ajr.end_time < \'2014-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field EndTime / Operator LT / relative value',
        Search       => {
            Field    => 'EndTime',
            Operator => 'LT',
            Value    => '+1h'
        },
        Expected     => {
            'Where' => [
                'ajr.end_time < \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field EndTime / Operator GT / absolute value',
        Search       => {
            Field    => 'EndTime',
            Operator => 'GT',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'ajr.end_time > \'2014-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field EndTime / Operator GT / relative value',
        Search       => {
            Field    => 'EndTime',
            Operator => 'GT',
            Value    => '+1h'
        },
        Expected     => {
            'Where' => [
                'ajr.end_time > \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field EndTime / Operator LTE / absolute value',
        Search       => {
            Field    => 'EndTime',
            Operator => 'LTE',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'ajr.end_time <= \'2014-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field EndTime / Operator LTE / relative value',
        Search       => {
            Field    => 'EndTime',
            Operator => 'LTE',
            Value    => '+1h'
        },
        Expected     => {
            'Where' => [
                'ajr.end_time <= \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field EndTime / Operator GTE / absolute value',
        Search       => {
            Field    => 'EndTime',
            Operator => 'GTE',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'ajr.end_time >= \'2014-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field EndTime / Operator GTE / relative value',
        Search       => {
            Field    => 'EndTime',
            Operator => 'GTE',
            Value    => '+1h'
        },
        Expected     => {
            'Where' => [
                'ajr.end_time >= \'2014-01-01 13:00:00\''
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
        Name      => 'Sort: Attribute "StartTime"',
        Attribute => 'StartTime',
        Expected  => {
            Select        => [ 'ajr.start_time AS SortAttr0' ],
            OrderBy       => [ 'SortAttr0' ]
        }
    },
    {
        Name      => 'Sort: Attribute "EndTime"',
        Attribute => 'EndTime',
        Expected  => {
            Select  => [ 'ajr.end_time AS SortAttr0' ],
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

# clear job runs
$Kernel::OM->Get('DB')->Do( SQL => 'DELETE FROM automation_log' );
$Kernel::OM->Get('DB')->Do( SQL => 'DELETE FROM job_run' );

## prepare test jobs
my $JobName1 = 'UnitTest1';
my $JobID1   = $Kernel::OM->Get('Automation')->JobAdd(
    Name    => $JobName1,
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
    Silent  => 1,
);
$Self->True(
    $JobID1,
    'Created first job'
);
my $SystemTime1 = $Kernel::OM->Get('Time')->SystemTime();
my $JobRunID1 = $Kernel::OM->Get('Automation')->JobExecute(
    ID     => $JobID1,
    UserID => 1
);
$Self->True(
    $JobRunID1,
    'Job run for first job executed'
);
my $JobName2 = 'UnitTest2';
my $JobID2   = $Kernel::OM->Get('Automation')->JobAdd(
    Name    => $JobName2,
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
    Silent  => 1,
);
$Self->True(
    $JobID2,
    'Created second job'
);
$Helper->FixedTimeAddSeconds(60);
my $SystemTime2 = $Kernel::OM->Get('Time')->SystemTime();
my $JobRunID2 = $Kernel::OM->Get('Automation')->JobExecute(
    ID     => $JobID2,
    UserID => 1
);
$Self->True(
    $JobRunID2,
    'Job run for second job executed'
);
my $JobName3 = 'UnitTest3';
my $JobID3   = $Kernel::OM->Get('Automation')->JobAdd(
    Name    => $JobName3,
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
    Silent  => 1,
);
$Self->True(
    $JobID3,
    'Created third job'
);
$Helper->FixedTimeAddSeconds(60);
my $SystemTime3 = $Kernel::OM->Get('Time')->SystemTime();
my $JobRunID3 = $Kernel::OM->Get('Automation')->JobExecute(
    ID     => $JobID3,
    UserID => 1
);
$Self->True(
    $JobRunID3,
    'Job run for third job executed'
);

# test Search
my @IntegrationSearchTests = (
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
        Expected => [$JobRunID2]
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
        Expected => [$JobRunID2]
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
        Expected => [$JobRunID1,$JobRunID3]
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
        Expected => [$JobRunID1,$JobRunID3]
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
        Expected => [$JobRunID1]
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
        Expected => [$JobRunID1]
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
        Expected => [$JobRunID3]
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
        Expected => [$JobRunID3]
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
        Expected => [$JobRunID1,$JobRunID2]
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
        Expected => [$JobRunID1,$JobRunID2]
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
        Expected => [$JobRunID2,$JobRunID3]
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
        Expected => [$JobRunID2,$JobRunID3]
    },
    {
        Name     => 'Search: Field EndTime / Operator EQ / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'EndTime',
                    Operator => 'EQ',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$JobRunID2]
    },
    {
        Name     => 'Search: Field EndTime / Operator EQ / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'EndTime',
                    Operator => 'EQ',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$JobRunID2]
    },
    {
        Name     => 'Search: Field EndTime / Operator NE / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'EndTime',
                    Operator => 'NE',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$JobRunID1,$JobRunID3]
    },
    {
        Name     => 'Search: Field EndTime / Operator NE / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'EndTime',
                    Operator => 'NE',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$JobRunID1,$JobRunID3]
    },
    {
        Name     => 'Search: Field EndTime / Operator LT / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'EndTime',
                    Operator => 'LT',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$JobRunID1]
    },
    {
        Name     => 'Search: Field EndTime / Operator LT / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'EndTime',
                    Operator => 'LT',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$JobRunID1]
    },
    {
        Name     => 'Search: Field EndTime / Operator GT / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'EndTime',
                    Operator => 'GT',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$JobRunID3]
    },
    {
        Name     => 'Search: Field EndTime / Operator GT / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'EndTime',
                    Operator => 'GT',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$JobRunID3]
    },
    {
        Name     => 'Search: Field EndTime / Operator LTE / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'EndTime',
                    Operator => 'LTE',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$JobRunID1,$JobRunID2]
    },
    {
        Name     => 'Search: Field EndTime / Operator LTE / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'EndTime',
                    Operator => 'LTE',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$JobRunID1,$JobRunID2]
    },
    {
        Name     => 'Search: Field EndTime / Operator GTE / Value2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'EndTime',
                    Operator => 'GTE',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$JobRunID2,$JobRunID3]
    },
    {
        Name     => 'Search: Field EndTime / Operator GTE / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'EndTime',
                    Operator => 'GTE',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$JobRunID2,$JobRunID3]
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Automation_JobRun',
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
        Name     => 'Sort: Field StartTime',
        Sort     => [
            {
                Field => 'StartTime'
            }
        ],
        Expected => [$JobRunID1,$JobRunID2,$JobRunID3]
    },
    {
        Name     => 'Sort: Field StartTime / Direction ascending',
        Sort     => [
            {
                Field     => 'StartTime',
                Direction => 'ascending'
            }
        ],
        Expected => [$JobRunID1,$JobRunID2,$JobRunID3]
    },
    {
        Name     => 'Sort: Field StartTime / Direction descending',
        Sort     => [
            {
                Field     => 'StartTime',
                Direction => 'descending'
            }
        ],
        Expected => [$JobRunID3,$JobRunID2,$JobRunID1]
    },
    {
        Name     => 'Sort: Field EndTime',
        Sort     => [
            {
                Field => 'EndTime'
            }
        ],
        Expected => [$JobRunID1,$JobRunID2,$JobRunID3]
    },
    {
        Name     => 'Sort: Field EndTime / Direction ascending',
        Sort     => [
            {
                Field     => 'EndTime',
                Direction => 'ascending'
            }
        ],
        Expected => [$JobRunID1,$JobRunID2,$JobRunID3]
    },
    {
        Name     => 'Sort: Field EndTime / Direction descending',
        Sort     => [
            {
                Field     => 'EndTime',
                Direction => 'descending'
            }
        ],
        Expected => [$JobRunID3,$JobRunID2,$JobRunID1]
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Automation_JobRun',
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
    ObjectType => 'Automation_JobRun',
    Result     => 'ARRAY',
    Search     => {
        'AND' => [
            {
                Field    => 'EndTime',
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
    [$JobRunID1,$JobRunID2],
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
    ObjectType => 'Automation_JobRun',
    Result     => 'ARRAY',
    Search     => {
        'AND' => [
            {
                Field    => 'EndTime',
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
    [$JobRunID1,$JobRunID2,$JobRunID3],
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
