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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Ticket::Watcher';

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
        WatcherUserID => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','IN','!IN','NE','GT','GTE','LT','LTE'],
            ValueType    => 'Integer'
        }
    },
    'GetSupportedAttributes provides expected data'
);

# check Search
my @SearchTests = (
    {
        Name         => 'Search: undef search',
        Search       => undef,
        BoolOperator => 'AND',
        Expected     => undef
    },
    {
        Name         => 'Search: Value undef',
        Search       => {
            Field    => 'WatcherUserID',
            Operator => 'EQ',
            Value    => undef

        },
        BoolOperator => 'AND',
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'WatcherUserID',
            Operator => 'EQ',
            Value    => 'Test'
        },
        BoolOperator => 'AND',
        Expected     => undef
    },
    {
        Name         => 'Search: Field undef',
        Search       => {
            Field    => undef,
            Operator => 'EQ',
            Value    => '1'
        },
        BoolOperator => 'AND',
        Expected     => undef
    },
    {
        Name         => 'Search: Field invalid',
        Search       => {
            Field    => 'Test',
            Operator => 'EQ',
            Value    => '1'
        },
        BoolOperator => 'AND',
        Expected     => undef
    },
    {
        Name         => 'Search: Operator undef',
        Search       => {
            Field    => 'WatcherUserID',
            Operator => undef,
            Value    => '1'
        },
        BoolOperator => 'AND',
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'WatcherUserID',
            Operator => 'Test',
            Value    => '1'
        },
        BoolOperator => 'AND',
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Operator EQ / BoolOperator AND',
        Search       => {
            Field    => 'WatcherUserID',
            Operator => 'EQ',
            Value    => '1'
        },
        BoolOperator => 'AND',
        Expected     => {
            'Join' => [
                'INNER JOIN watcher tw ON st.id = tw.object_id AND tw.object = \'Ticket\''
            ],
            'Where' => [
                'tw.user_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Operator NE / BoolOperator AND',
        Search       => {
            Field    => 'WatcherUserID',
            Operator => 'NE',
            Value    => '1'
        },
        BoolOperator => 'AND',
        Expected     => {
            'Join' => [
                'INNER JOIN watcher tw ON st.id = tw.object_id AND tw.object = \'Ticket\''
            ],
            'Where' => [
                'tw.user_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Operator LT / BoolOperator AND',
        Search       => {
            Field    => 'WatcherUserID',
            Operator => 'LT',
            Value    => '1'
        },
        BoolOperator => 'AND',
        Expected     => {
            'Join' => [
                'INNER JOIN watcher tw ON st.id = tw.object_id AND tw.object = \'Ticket\''
            ],
            'Where' => [
                'tw.user_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Operator GT / BoolOperator AND',
        Search       => {
            Field    => 'WatcherUserID',
            Operator => 'GT',
            Value    => '1'
        },
        BoolOperator => 'AND',
        Expected     => {
            'Join' => [
                'INNER JOIN watcher tw ON st.id = tw.object_id AND tw.object = \'Ticket\''
            ],
            'Where' => [
                'tw.user_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Operator LTE / BoolOperator AND',
        Search       => {
            Field    => 'WatcherUserID',
            Operator => 'LTE',
            Value    => '1'
        },
        BoolOperator => 'AND',
        Expected     => {
            'Join' => [
                'INNER JOIN watcher tw ON st.id = tw.object_id AND tw.object = \'Ticket\''
            ],
            'Where' => [
                'tw.user_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Operator GTE / BoolOperator AND',
        Search       => {
            Field    => 'WatcherUserID',
            Operator => 'GTE',
            Value    => '1'
        },
        BoolOperator => 'AND',
        Expected     => {
            'Join' => [
                'INNER JOIN watcher tw ON st.id = tw.object_id AND tw.object = \'Ticket\''
            ],
            'Where' => [
                'tw.user_id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Operator IN / BoolOperator AND',
        Search       => {
            Field    => 'WatcherUserID',
            Operator => 'IN',
            Value    => ['1']
        },
        BoolOperator => 'AND',
        Expected     => {
            'Join' => [
                'INNER JOIN watcher tw ON st.id = tw.object_id AND tw.object = \'Ticket\''
            ],
            'Where' => [
                'tw.user_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Operator !IN / BoolOperator AND',
        Search       => {
            Field    => 'WatcherUserID',
            Operator => '!IN',
            Value    => ['1']
        },
        BoolOperator => 'AND',
        Expected     => {
            'Join' => [
                'INNER JOIN watcher tw ON st.id = tw.object_id AND tw.object = \'Ticket\''
            ],
            'Where' => [
                'tw.user_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Operator EQ / BoolOperator OR',
        Search       => {
            Field    => 'WatcherUserID',
            Operator => 'EQ',
            Value    => '1'
        },
        BoolOperator => 'OR',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN watcher tw_left ON st.id = tw_left.object_id AND tw_left.object = \'Ticket\'',
                'RIGHT OUTER JOIN watcher tw_right ON st.id = tw_right.object_id AND tw_right.object = \'Ticket\''
            ],
            'Where' => [
                'tw_left.user_id = 1',
                'tw_right.user_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Operator NE / BoolOperator OR',
        Search       => {
            Field    => 'WatcherUserID',
            Operator => 'NE',
            Value    => '1'
        },
        BoolOperator => 'OR',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN watcher tw_left ON st.id = tw_left.object_id AND tw_left.object = \'Ticket\'',
                'RIGHT OUTER JOIN watcher tw_right ON st.id = tw_right.object_id AND tw_right.object = \'Ticket\''
            ],
            'Where' => [
                'tw_left.user_id <> 1',
                'tw_right.user_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Operator LT / BoolOperator OR',
        Search       => {
            Field    => 'WatcherUserID',
            Operator => 'LT',
            Value    => '1'
        },
        BoolOperator => 'OR',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN watcher tw_left ON st.id = tw_left.object_id AND tw_left.object = \'Ticket\'',
                'RIGHT OUTER JOIN watcher tw_right ON st.id = tw_right.object_id AND tw_right.object = \'Ticket\''
            ],
            'Where' => [
                'tw_left.user_id < 1',
                'tw_right.user_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Operator GT / BoolOperator OR',
        Search       => {
            Field    => 'WatcherUserID',
            Operator => 'GT',
            Value    => '1'
        },
        BoolOperator => 'OR',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN watcher tw_left ON st.id = tw_left.object_id AND tw_left.object = \'Ticket\'',
                'RIGHT OUTER JOIN watcher tw_right ON st.id = tw_right.object_id AND tw_right.object = \'Ticket\''
            ],
            'Where' => [
                'tw_left.user_id > 1',
                'tw_right.user_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Operator LTE / BoolOperator OR',
        Search       => {
            Field    => 'WatcherUserID',
            Operator => 'LTE',
            Value    => '1'
        },
        BoolOperator => 'OR',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN watcher tw_left ON st.id = tw_left.object_id AND tw_left.object = \'Ticket\'',
                'RIGHT OUTER JOIN watcher tw_right ON st.id = tw_right.object_id AND tw_right.object = \'Ticket\''
            ],
            'Where' => [
                'tw_left.user_id <= 1',
                'tw_right.user_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Operator GTE / BoolOperator OR',
        Search       => {
            Field    => 'WatcherUserID',
            Operator => 'GTE',
            Value    => '1'
        },
        BoolOperator => 'OR',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN watcher tw_left ON st.id = tw_left.object_id AND tw_left.object = \'Ticket\'',
                'RIGHT OUTER JOIN watcher tw_right ON st.id = tw_right.object_id AND tw_right.object = \'Ticket\''
            ],
            'Where' => [
                'tw_left.user_id >= 1',
                'tw_right.user_id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Operator IN / BoolOperator OR',
        Search       => {
            Field    => 'WatcherUserID',
            Operator => 'IN',
            Value    => ['1']
        },
        BoolOperator => 'OR',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN watcher tw_left ON st.id = tw_left.object_id AND tw_left.object = \'Ticket\'',
                'RIGHT OUTER JOIN watcher tw_right ON st.id = tw_right.object_id AND tw_right.object = \'Ticket\''
            ],
            'Where' => [
                'tw_left.user_id IN (1)',
                'tw_right.user_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Operator !IN / BoolOperator OR',
        Search       => {
            Field    => 'WatcherUserID',
            Operator => '!IN',
            Value    => ['1']
        },
        BoolOperator => 'OR',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN watcher tw_left ON st.id = tw_left.object_id AND tw_left.object = \'Ticket\'',
                'RIGHT OUTER JOIN watcher tw_right ON st.id = tw_right.object_id AND tw_right.object = \'Ticket\''
            ],
            'Where' => [
                'tw_left.user_id NOT IN (1)',
                'tw_right.user_id NOT IN (1)'
            ]
        }
    }
);
for my $Test ( @SearchTests ) {
    my $Result = $AttributeObject->Search(
        Search       => $Test->{Search},
        BoolOperator => $Test->{BoolOperator},
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
        Name      => 'Sort: Attribute "WatcherUserID" is not sortable',
        Attribute => 'WatcherUserID',
        Expected  => undef
    }
);
for my $Test ( @SortTests ) {
    my $Result = $AttributeObject->Sort(
        Attribute => $Test->{Attribute},
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

## prepare test users ##
# first user
my $TestUserLogin1 = $Helper->TestUserCreate();
my $TestUserID1    = $Kernel::OM->Get('User')->UserLookup(
    UserLogin => $TestUserLogin1
);
$Self->True(
    $TestUserID1,
    'Created first user'
);
# second user
my $TestUserLogin2 = $Helper->TestUserCreate();
my $TestUserID2    = $Kernel::OM->Get('User')->UserLookup(
    UserLogin => $TestUserLogin2
);
$Self->True(
    $TestUserID2,
    'Created second user'
);
# third user
my $TestUserLogin3 = $Helper->TestUserCreate();
my $TestUserID3    = $Kernel::OM->Get('User')->UserLookup(
    UserLogin => $TestUserLogin3
);
$Self->True(
    $TestUserID3,
    'Created third user'
);

## prepare test tickets ##
# first ticket
my $TicketID1 = $Kernel::OM->Get('Ticket')->TicketCreate(
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
my $WatcherAdd1 = $Kernel::OM->Get('Watcher')->WatcherAdd(
    Object      => 'Ticket',
    ObjectID    => $TicketID1,
    WatchUserID => $TestUserID1,
    UserID      => 1,
);
$Self->True(
    $WatcherAdd1,
    'Watcher added for first ticket'
);
# second ticket
my $TicketID2 = $Kernel::OM->Get('Ticket')->TicketCreate(
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
my $WatcherAdd2 = $Kernel::OM->Get('Watcher')->WatcherAdd(
    Object      => 'Ticket',
    ObjectID    => $TicketID2,
    WatchUserID => $TestUserID2,
    UserID      => 1,
);
$Self->True(
    $WatcherAdd2,
    'Watcher added for second ticket'
);
# third ticket
my $TicketID3 = $Kernel::OM->Get('Ticket')->TicketCreate(
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
my $WatcherAdd3 = $Kernel::OM->Get('Watcher')->WatcherAdd(
    Object      => 'Ticket',
    ObjectID    => $TicketID3,
    WatchUserID => $TestUserID3,
    UserID      => 1,
);
$Self->True(
    $WatcherAdd3,
    'Watcher added for third ticket'
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field WatcherUserID / Operator EQ / Value $TestUserID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'WatcherUserID',
                    Operator => 'EQ',
                    Value    => $TestUserID2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field WatcherUserID / Operator NE / Value $TestUserID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'WatcherUserID',
                    Operator => 'NE',
                    Value    => $TestUserID2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field WatcherUserID / Operator LT / Value $TestUserID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'WatcherUserID',
                    Operator => 'LT',
                    Value    => $TestUserID2
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: Field WatcherUserID / Operator GT / Value $TestUserID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'WatcherUserID',
                    Operator => 'GT',
                    Value    => $TestUserID2
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field WatcherUserID / Operator LTE / Value $TestUserID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'WatcherUserID',
                    Operator => 'LTE',
                    Value    => $TestUserID2
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2]
    },
    {
        Name     => 'Search: Field WatcherUserID / Operator GTE / Value $TestUserID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'WatcherUserID',
                    Operator => 'GTE',
                    Value    => $TestUserID2
                }
            ]
        },
        Expected => [$TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field WatcherUserID / Operator IN / Value [$TestUserID1,$TestUserID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'WatcherUserID',
                    Operator => 'IN',
                    Value    => [$TestUserID1,$TestUserID3]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID3]
    },
    {
        Name     => 'Search: Field WatcherUserID / Operator !IN / Value [$TestUserID1,$TestUserID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'WatcherUserID',
                    Operator => '!IN',
                    Value    => [$TestUserID1,$TestUserID3]
                }
            ]
        },
        Expected => [$TicketID2]
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
