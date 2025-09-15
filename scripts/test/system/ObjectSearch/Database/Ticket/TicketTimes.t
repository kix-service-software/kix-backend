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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Ticket::TicketTimes';

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
        Age            => {
            IsSelectable   => 0,
            IsSearchable   => 0,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => []
        },
        CreateTime     => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType      => 'DATETIME'
        },
        PendingTime    => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType      => 'DATETIME'
        },
        LastChangeTime => {
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
            Field    => 'CreateTime',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'CreateTime',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Field "Age" not searchable',
        Search       => {
            Field    => 'Age',
            Operator => 'EQ',
            Value    => '1'
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
                'st.create_time_unix = ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '2014-01-01 12:00:00')
            ],
            'IsRelative' => undef
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
                'st.create_time_unix = ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '+1h')
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
                'st.create_time_unix <> ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '2014-01-01 12:00:00')
            ],
            'IsRelative' => undef
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
                'st.create_time_unix <> ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '+1h')
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
                'st.create_time_unix < ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '2014-01-01 12:00:00')
            ],
            'IsRelative' => undef
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
                'st.create_time_unix < ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '+1h')
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
                'st.create_time_unix > ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '2014-01-01 12:00:00')
            ],
            'IsRelative' => undef
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
                'st.create_time_unix > ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '+1h')
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
                'st.create_time_unix <= ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '2014-01-01 12:00:00')
            ],
            'IsRelative' => undef
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
                'st.create_time_unix <= ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '+1h')
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
                'st.create_time_unix >= ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '2014-01-01 12:00:00')
            ],
            'IsRelative' => undef
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
                'st.create_time_unix >= ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '+1h')
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field PendingTime / Operator EQ / absolute value',
        Search       => {
            Field    => 'PendingTime',
            Operator => 'EQ',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'st.until_time = ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '2014-01-01 12:00:00')
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => 'Search: valid search / Field PendingTime / Operator EQ / relative value',
        Search       => {
            Field    => 'PendingTime',
            Operator => 'EQ',
            Value    => '+1h'
        },
        Expected     => {
            'Where' => [
                'st.until_time = ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '+1h')
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field PendingTime / Operator NE / absolute value',
        Search       => {
            Field    => 'PendingTime',
            Operator => 'NE',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'st.until_time <> ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '2014-01-01 12:00:00')
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => 'Search: valid search / Field PendingTime / Operator NE / relative value',
        Search       => {
            Field    => 'PendingTime',
            Operator => 'NE',
            Value    => '+1h'
        },
        Expected     => {
            'Where' => [
                'st.until_time <> ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '+1h')
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field PendingTime / Operator LT / absolute value',
        Search       => {
            Field    => 'PendingTime',
            Operator => 'LT',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'st.until_time < ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '2014-01-01 12:00:00')
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => 'Search: valid search / Field PendingTime / Operator LT / relative value',
        Search       => {
            Field    => 'PendingTime',
            Operator => 'LT',
            Value    => '+1h'
        },
        Expected     => {
            'Where' => [
                'st.until_time < ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '+1h')
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field PendingTime / Operator GT / absolute value',
        Search       => {
            Field    => 'PendingTime',
            Operator => 'GT',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'st.until_time > ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '2014-01-01 12:00:00')
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => 'Search: valid search / Field PendingTime / Operator GT / relative value',
        Search       => {
            Field    => 'PendingTime',
            Operator => 'GT',
            Value    => '+1h'
        },
        Expected     => {
            'Where' => [
                'st.until_time > ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '+1h')
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field PendingTime / Operator LTE / absolute value',
        Search       => {
            Field    => 'PendingTime',
            Operator => 'LTE',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'st.until_time <= ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '2014-01-01 12:00:00')
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => 'Search: valid search / Field PendingTime / Operator LTE / relative value',
        Search       => {
            Field    => 'PendingTime',
            Operator => 'LTE',
            Value    => '+1h'
        },
        Expected     => {
            'Where' => [
                'st.until_time <= ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '+1h')
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field PendingTime / Operator GTE / absolute value',
        Search       => {
            Field    => 'PendingTime',
            Operator => 'GTE',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'st.until_time >= ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '2014-01-01 12:00:00')
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => 'Search: valid search / Field PendingTime / Operator GTE / relative value',
        Search       => {
            Field    => 'PendingTime',
            Operator => 'GTE',
            Value    => '+1h'
        },
        Expected     => {
            'Where' => [
                'st.until_time >= ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '+1h')
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field LastChangeTime / Operator EQ / absolute value',
        Search       => {
            Field    => 'LastChangeTime',
            Operator => 'EQ',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'st.change_time = \'2014-01-01 12:00:00\''
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => 'Search: valid search / Field LastChangeTime / Operator EQ / relative value',
        Search       => {
            Field    => 'LastChangeTime',
            Operator => 'EQ',
            Value    => '+1h'
        },
        Expected     => {
            'Where' => [
                'st.change_time = \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field LastChangeTime / Operator NE / absolute value',
        Search       => {
            Field    => 'LastChangeTime',
            Operator => 'NE',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'st.change_time != \'2014-01-01 12:00:00\''
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => 'Search: valid search / Field LastChangeTime / Operator NE / relative value',
        Search       => {
            Field    => 'LastChangeTime',
            Operator => 'NE',
            Value    => '+1h'
        },
        Expected     => {
            'Where' => [
                'st.change_time != \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field LastChangeTime / Operator LT / absolute value',
        Search       => {
            Field    => 'LastChangeTime',
            Operator => 'LT',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'st.change_time < \'2014-01-01 12:00:00\''
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => 'Search: valid search / Field LastChangeTime / Operator LT / relative value',
        Search       => {
            Field    => 'LastChangeTime',
            Operator => 'LT',
            Value    => '+1h'
        },
        Expected     => {
            'Where' => [
                'st.change_time < \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field LastChangeTime / Operator GT / absolute value',
        Search       => {
            Field    => 'LastChangeTime',
            Operator => 'GT',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'st.change_time > \'2014-01-01 12:00:00\''
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => 'Search: valid search / Field LastChangeTime / Operator GT / relative value',
        Search       => {
            Field    => 'LastChangeTime',
            Operator => 'GT',
            Value    => '+1h'
        },
        Expected     => {
            'Where' => [
                'st.change_time > \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field LastChangeTime / Operator LTE / absolute value',
        Search       => {
            Field    => 'LastChangeTime',
            Operator => 'LTE',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'st.change_time <= \'2014-01-01 12:00:00\''
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => 'Search: valid search / Field LastChangeTime / Operator LTE / relative value',
        Search       => {
            Field    => 'LastChangeTime',
            Operator => 'LTE',
            Value    => '+1h'
        },
        Expected     => {
            'Where' => [
                'st.change_time <= \'2014-01-01 13:00:00\''
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field LastChangeTime / Operator GTE / absolute value',
        Search       => {
            Field    => 'LastChangeTime',
            Operator => 'GTE',
            Value    => '2014-01-01 12:00:00'
        },
        Expected     => {
            'Where' => [
                'st.change_time >= \'2014-01-01 12:00:00\''
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => 'Search: valid search / Field LastChangeTime / Operator GTE / relative value',
        Search       => {
            Field    => 'LastChangeTime',
            Operator => 'GTE',
            Value    => '+1h'
        },
        Expected     => {
            'Where' => [
                'st.change_time >= \'2014-01-01 13:00:00\''
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
        Name      => 'Sort: Attribute "Age"',
        Attribute => 'Age',
        Expected  => {
            Select        => [ 'st.create_time_unix AS SortAttr0' ],
            OrderBy       => [ 'SortAttr0' ],
            OrderBySwitch => 1
        }
    },
    {
        Name      => 'Sort: Attribute "CreateTime"',
        Attribute => 'CreateTime',
        Expected  => {
            Select        => [ 'st.create_time_unix AS SortAttr0' ],
            OrderBy       => [ 'SortAttr0' ]
        }
    },
    {
        Name      => 'Sort: Attribute "PendingTime"',
        Attribute => 'PendingTime',
        Expected  => {
            Select        => [ 'st.until_time AS SortAttr0' ],
            OrderBy       => [ 'SortAttr0' ]
        }
    },
    {
        Name      => 'Sort: Attribute "LastChangeTime"',
        Attribute => 'LastChangeTime',
        Expected  => {
            Select        => [ 'st.change_time AS SortAttr0' ],
            OrderBy       => [ 'SortAttr0' ]
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

## prepare test tickets ##
# first ticket
my $SystemTime1 = $Kernel::OM->Get('Time')->SystemTime();
my $TicketID1   = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => 1,
    Lock           => 'unlock',
    PriorityID     => 1,
    StateID        => 1,
    TypeID         => 1,
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
my $TicketPendingTimeSet1 = $Kernel::OM->Get('Ticket')->TicketPendingTimeSet(
    Diff     => 10,
    TicketID => $TicketID1,
    UserID   => 1,
);
$Self->True(
    $TicketPendingTimeSet1,
    'Pending time set for first ticket'
);
# second ticket
$Helper->FixedTimeAddSeconds(60);
my $SystemTime2 = $Kernel::OM->Get('Time')->SystemTime();
my $TicketID2   = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => 1,
    Lock           => 'unlock',
    PriorityID     => 1,
    StateID        => 1,
    TypeID         => 1,
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
my $TicketPendingTimeSet2 = $Kernel::OM->Get('Ticket')->TicketPendingTimeSet(
    Diff     => 10,
    TicketID => $TicketID2,
    UserID   => 1,
);
$Self->True(
    $TicketPendingTimeSet2,
    'Pending time set for second ticket'
);
# third ticket
$Helper->FixedTimeAddSeconds(60);
my $SystemTime3 = $Kernel::OM->Get('Time')->SystemTime();
my $TicketID3   = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => 1,
    Lock           => 'unlock',
    PriorityID     => 1,
    StateID        => 1,
    TypeID         => 1,
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
my $TicketPendingTimeSet3 = $Kernel::OM->Get('Ticket')->TicketPendingTimeSet(
    Diff     => 10,
    TicketID => $TicketID3,
    UserID   => 1,
);
$Self->True(
    $TicketPendingTimeSet3,
    'Pending time set for third ticket'
);

# discard ticket object to process events
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
        Expected => [$TicketID2]
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
        Expected => [$TicketID2]
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
        Expected => [$TicketID1,$TicketID3]
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
        Expected => [$TicketID1,$TicketID3]
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
        Expected => [$TicketID1]
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
        Expected => [$TicketID1]
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
        Expected => [$TicketID3]
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
        Expected => [$TicketID3]
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
        Expected => [$TicketID1, $TicketID2]
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
        Expected => [$TicketID1, $TicketID2]
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
        Expected => [$TicketID2, $TicketID3]
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
        Expected => [$TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field PendingTime / Operator EQ / Value 2014-01-01 12:11:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'PendingTime',
                    Operator => 'EQ',
                    Value    => '2014-01-01 12:11:00'
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field PendingTime / Operator EQ / Value +9m',
        Search   => {
            'AND' => [
                {
                    Field    => 'PendingTime',
                    Operator => 'EQ',
                    Value    => '+9m'
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field PendingTime / Operator NE / Value 2014-01-01 12:11:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'PendingTime',
                    Operator => 'NE',
                    Value    => '2014-01-01 12:11:00'
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field PendingTime / Operator NE / Value +9m',
        Search   => {
            'AND' => [
                {
                    Field    => 'PendingTime',
                    Operator => 'NE',
                    Value    => '+9m'
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field PendingTime / Operator LT / Value 2014-01-01 12:11:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'PendingTime',
                    Operator => 'LT',
                    Value    => '2014-01-01 12:11:00'
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: Field PendingTime / Operator LT / Value +9m',
        Search   => {
            'AND' => [
                {
                    Field    => 'PendingTime',
                    Operator => 'LT',
                    Value    => '+9m'
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: Field PendingTime / Operator GT / Value 2014-01-01 12:11:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'PendingTime',
                    Operator => 'GT',
                    Value    => '2014-01-01 12:11:00'
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field PendingTime / Operator GT / Value +9m',
        Search   => {
            'AND' => [
                {
                    Field    => 'PendingTime',
                    Operator => 'GT',
                    Value    => '+9m'
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field PendingTime / Operator LTE / Value 2014-01-01 12:11:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'PendingTime',
                    Operator => 'LTE',
                    Value    => '2014-01-01 12:11:00'
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2]
    },
    {
        Name     => 'Search: Field PendingTime / Operator LTE / Value +9m',
        Search   => {
            'AND' => [
                {
                    Field    => 'PendingTime',
                    Operator => 'LTE',
                    Value    => '+9m'
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2]
    },
    {
        Name     => 'Search: Field PendingTime / Operator GTE / Value2014-01-01 12:11:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'PendingTime',
                    Operator => 'GTE',
                    Value    => '2014-01-01 12:11:00'
                }
            ]
        },
        Expected => [$TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field PendingTime / Operator GTE / Value +9m',
        Search   => {
            'AND' => [
                {
                    Field    => 'PendingTime',
                    Operator => 'GTE',
                    Value    => '+9m'
                }
            ]
        },
        Expected => [$TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field LastChangeTime / Operator EQ / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'LastChangeTime',
                    Operator => 'EQ',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field LastChangeTime / Operator EQ / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'LastChangeTime',
                    Operator => 'EQ',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field LastChangeTime / Operator NE / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'LastChangeTime',
                    Operator => 'NE',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field LastChangeTime / Operator NE / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'LastChangeTime',
                    Operator => 'NE',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field LastChangeTime / Operator LT / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'LastChangeTime',
                    Operator => 'LT',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: Field LastChangeTime / Operator LT / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'LastChangeTime',
                    Operator => 'LT',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: Field LastChangeTime / Operator GT / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'LastChangeTime',
                    Operator => 'GT',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field LastChangeTime / Operator GT / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'LastChangeTime',
                    Operator => 'GT',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field LastChangeTime / Operator LTE / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'LastChangeTime',
                    Operator => 'LTE',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2]
    },
    {
        Name     => 'Search: Field LastChangeTime / Operator LTE / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'LastChangeTime',
                    Operator => 'LTE',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2]
    },
    {
        Name     => 'Search: Field LastChangeTime / Operator GTE / Value2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'LastChangeTime',
                    Operator => 'GTE',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        Expected => [$TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field LastChangeTime / Operator GTE / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'LastChangeTime',
                    Operator => 'GTE',
                    Value    => '-1m'
                }
            ]
        },
        Expected => [$TicketID2, $TicketID3]
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
my @IntegrationSortTests = (
    {
        Name     => 'Sort: Field Age',
        Sort     => [
            {
                Field => 'Age'
            }
        ],
        Expected => [$TicketID3, $TicketID2, $TicketID1]
    },
    {
        Name     => 'Sort: Field Age / Direction ascending',
        Sort     => [
            {
                Field     => 'Age',
                Direction => 'ascending'
            }
        ],
        Expected => [$TicketID3, $TicketID2, $TicketID1]
    },
    {
        Name     => 'Sort: Field Age / Direction descending',
        Sort     => [
            {
                Field     => 'Age',
                Direction => 'descending'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field CreateTime',
        Sort     => [
            {
                Field => 'CreateTime'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field CreateTime / Direction ascending',
        Sort     => [
            {
                Field     => 'CreateTime',
                Direction => 'ascending'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field CreateTime / Direction descending',
        Sort     => [
            {
                Field     => 'CreateTime',
                Direction => 'descending'
            }
        ],
        Expected => [$TicketID3, $TicketID2, $TicketID1]
    },
    {
        Name     => 'Sort: Field PendingTime',
        Sort     => [
            {
                Field => 'PendingTime'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field PendingTime / Direction ascending',
        Sort     => [
            {
                Field     => 'PendingTime',
                Direction => 'ascending'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field PendingTime / Direction descending',
        Sort     => [
            {
                Field     => 'PendingTime',
                Direction => 'descending'
            }
        ],
        Expected => [$TicketID3, $TicketID2, $TicketID1]
    },
    {
        Name     => 'Sort: Field LastChangeTime',
        Sort     => [
            {
                Field => 'LastChangeTime'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field LastChangeTime / Direction ascending',
        Sort     => [
            {
                Field     => 'LastChangeTime',
                Direction => 'ascending'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field LastChangeTime / Direction descending',
        Sort     => [
            {
                Field     => 'LastChangeTime',
                Direction => 'descending'
            }
        ],
        Expected => [$TicketID3, $TicketID2, $TicketID1]
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Ticket',
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
    ObjectType => 'Ticket',
    Result     => 'ARRAY',
    Search     => {
        'AND' => [
            {
                Field    => 'LastChangeTime',
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
    [$TicketID1,$TicketID2],
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
    ObjectType => 'Ticket',
    Result     => 'ARRAY',
    Search     => {
        'AND' => [
            {
                Field    => 'LastChangeTime',
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
    [$TicketID1,$TicketID2,$TicketID3],
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
