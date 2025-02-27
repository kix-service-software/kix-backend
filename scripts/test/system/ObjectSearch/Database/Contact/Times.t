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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Contact::Times';

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
        CreateTime => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType    => 'DATETIME'
        },
        ChangeTime => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType    => 'DATETIME'
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
                'c.create_time = \'2014-01-01 12:00:00\''
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
                'c.create_time = \'2014-01-01 13:00:00\''
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
                'c.create_time != \'2014-01-01 12:00:00\''
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
                'c.create_time != \'2014-01-01 13:00:00\''
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
                'c.create_time < \'2014-01-01 12:00:00\''
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
                'c.create_time < \'2014-01-01 13:00:00\''
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
                'c.create_time > \'2014-01-01 12:00:00\''
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
                'c.create_time > \'2014-01-01 13:00:00\''
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
                'c.create_time <= \'2014-01-01 12:00:00\''
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
                'c.create_time <= \'2014-01-01 13:00:00\''
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
                'c.create_time >= \'2014-01-01 12:00:00\''
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
                'c.create_time >= \'2014-01-01 13:00:00\''
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
                'c.change_time = \'2014-01-01 12:00:00\''
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
                'c.change_time = \'2014-01-01 13:00:00\''
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
                'c.change_time != \'2014-01-01 12:00:00\''
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
                'c.change_time != \'2014-01-01 13:00:00\''
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
                'c.change_time < \'2014-01-01 12:00:00\''
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
                'c.change_time < \'2014-01-01 13:00:00\''
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
                'c.change_time > \'2014-01-01 12:00:00\''
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
                'c.change_time > \'2014-01-01 13:00:00\''
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
                'c.change_time <= \'2014-01-01 12:00:00\''
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
                'c.change_time <= \'2014-01-01 13:00:00\''
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
                'c.change_time >= \'2014-01-01 12:00:00\''
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
                'c.change_time >= \'2014-01-01 13:00:00\''
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
            Select        => [ 'c.create_time' ],
            OrderBy       => [ 'c.create_time' ]
        }
    },
    {
        Name      => 'Sort: Attribute "ChangeTime"',
        Attribute => 'ChangeTime',
        Expected  => {
            Select  => [ 'c.change_time' ],
            OrderBy => [ 'c.change_time' ]
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

## prepare test contacts ##
# first contact
my $SystemTime1 = $Kernel::OM->Get('Time')->SystemTime();
my $ContactID1  = $Kernel::OM->Get('Contact')->ContactAdd(
    Firstname => $Helper->GetRandomID(),
    Lastname  => $Helper->GetRandomID(),
    ValidID   => 1,
    UserID    => 1
);
$Self->True(
    $ContactID1,
    'Created first contact'
);
# second contact
$Helper->FixedTimeAddSeconds(60);
my $SystemTime2 = $Kernel::OM->Get('Time')->SystemTime();
my $ContactID2  = $Kernel::OM->Get('Contact')->ContactAdd(
    Firstname => $Helper->GetRandomID(),
    Lastname  => $Helper->GetRandomID(),
    ValidID   => 1,
    UserID    => 1
);
$Self->True(
    $ContactID2,
    'Created second contact'
);
# third contact
$Helper->FixedTimeAddSeconds(60);
my $SystemTime3 = $Kernel::OM->Get('Time')->SystemTime();
my $ContactID3  = $Kernel::OM->Get('Contact')->ContactAdd(
    Firstname => $Helper->GetRandomID(),
    Lastname  => $Helper->GetRandomID(),
    ValidID   => 1,
    UserID    => 1
);
$Self->True(
    $ContactID3,
    'Created third contact'
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Contact'],
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
        Expected => [$ContactID2]
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
        Expected => [$ContactID2]
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
        Expected => ['1',$ContactID1,$ContactID3]
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
        Expected => ['1',$ContactID1,$ContactID3]
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
        Expected => [$ContactID1]
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
        Expected => [$ContactID1]
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
        Expected => ['1',$ContactID3]
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
        Expected => ['1',$ContactID3]
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
        Expected => [$ContactID1,$ContactID2]
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
        Expected => [$ContactID1,$ContactID2]
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
        Expected => ['1',$ContactID2,$ContactID3]
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
        Expected => ['1',$ContactID2,$ContactID3]
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
        Expected => [$ContactID2]
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
        Expected => [$ContactID2]
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
        Expected => ['1',$ContactID1,$ContactID3]
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
        Expected => ['1',$ContactID1,$ContactID3]
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
        Expected => [$ContactID1]
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
        Expected => [$ContactID1]
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
        Expected => ['1',$ContactID3]
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
        Expected => ['1',$ContactID3]
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
        Expected => [$ContactID1,$ContactID2]
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
        Expected => [$ContactID1,$ContactID2]
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
        Expected => ['1',$ContactID2,$ContactID3]
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
        Expected => ['1',$ContactID2,$ContactID3]
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Contact',
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
        Expected => [$ContactID1,$ContactID2,$ContactID3,'1']
    },
    {
        Name     => 'Sort: Field CreateTime / Direction ascending',
        Sort     => [
            {
                Field     => 'CreateTime',
                Direction => 'ascending'
            }
        ],
        Expected => [$ContactID1,$ContactID2,$ContactID3,'1']
    },
    {
        Name     => 'Sort: Field CreateTime / Direction descending',
        Sort     => [
            {
                Field     => 'CreateTime',
                Direction => 'descending'
            }
        ],
        Expected => ['1',$ContactID3,$ContactID2,$ContactID1]
    },
    {
        Name     => 'Sort: Field ChangeTime',
        Sort     => [
            {
                Field => 'ChangeTime'
            }
        ],
        Expected => [$ContactID1,$ContactID2,$ContactID3,'1']
    },
    {
        Name     => 'Sort: Field ChangeTime / Direction ascending',
        Sort     => [
            {
                Field     => 'ChangeTime',
                Direction => 'ascending'
            }
        ],
        Expected => [$ContactID1,$ContactID2,$ContactID3,'1']
    },
    {
        Name     => 'Sort: Field ChangeTime / Direction descending',
        Sort     => [
            {
                Field     => 'ChangeTime',
                Direction => 'descending'
            }
        ],
        Expected => ['1',$ContactID3,$ContactID2,$ContactID1]
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Contact',
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
    ObjectType => 'Contact',
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
    [$ContactID1,$ContactID2],
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
    ObjectType => 'Contact',
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
    [$ContactID1,$ContactID2,$ContactID3],
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
