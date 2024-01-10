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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Ticket::TicketFlag';

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
        'TicketFlag.Seen' => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE']
        }
    },
    'GetSupportedAttributes provides expected data'
);

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
            Field    => 'TicketFlag.Seen',
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
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Field invalid',
        Search       => {
            Field    => 'Test',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator undef',
        Search       => {
            Field    => 'TicketFlag.Seen',
            Operator => undef,
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'TicketFlag.Seen',
            Operator => 'Test',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field TicketFlag.Seen / Operator EQ',
        Search       => {
            Field    => 'TicketFlag.Seen',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN ticket_flag tf_left0 ON tf_left0.ticket_id = st.id AND tf_left0.ticket_key = \'Seen\' AND tf_left0.create_by = 1'
            ],
            'Where' => [
                'tf_left0.ticket_value = \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TicketFlag.Seen / Operator EQ / empty string',
        Search       => {
            Field    => 'TicketFlag.Seen',
            Operator => 'EQ',
            Value    => ''
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN ticket_flag tf_left0 ON tf_left0.ticket_id = st.id AND tf_left0.ticket_key = \'Seen\' AND tf_left0.create_by = 1'
            ],
            'Where' => [
                '(tf_left0.ticket_value = \'\' OR tf_left0.ticket_value IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TicketFlag.Seen / Operator NE',
        Search       => {
            Field    => 'TicketFlag.Seen',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN ticket_flag tf_left0 ON tf_left0.ticket_id = st.id AND tf_left0.ticket_key = \'Seen\' AND tf_left0.create_by = 1'
            ],
            'Where' => [
                '(tf_left0.ticket_value != \'Test\' OR tf_left0.ticket_value IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TicketFlag.Seen / Operator NE / empty string',
        Search       => {
            Field    => 'TicketFlag.Seen',
            Operator => 'NE',
            Value    => ''
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN ticket_flag tf_left0 ON tf_left0.ticket_id = st.id AND tf_left0.ticket_key = \'Seen\' AND tf_left0.create_by = 1'
            ],
            'Where' => [
                'tf_left0.ticket_value != \'\''
            ]
        }
    }
);
for my $Test ( @SearchTests ) {
    my $Result = $AttributeObject->Search(
        Search       => $Test->{Search},
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
        Name      => 'Sort: Attribute "TicketFlag.Seen"',
        Attribute => 'TicketFlag.Seen',
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
my $TicketFlagSet2 = $Kernel::OM->Get('Ticket')->TicketFlagSet(
    TicketID => $TicketID2,
    Key      => 'Seen',
    Value    => 1,
    UserID   => 1,
);
$Self->True(
    $TicketFlagSet2,
    'Set flag Seen for second ticket'
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

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Ticket'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field TicketFlag.Seen / Operator EQ / Value 1',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketFlag.Seen',
                    Operator => 'EQ',
                    Value    => '1'
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field TicketFlag.Seen / Operator EQ / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketFlag.Seen',
                    Operator => 'EQ',
                    Value    => ''
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field TicketFlag.Seen / Operator EQ / Value zero',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketFlag.Seen',
                    Operator => 'EQ',
                    Value    => '0'
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field TicketFlag.Seen / Operator NE / Value 1',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketFlag.Seen',
                    Operator => 'NE',
                    Value    => '1'
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field TicketFlag.Seen / Operator NE / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketFlag.Seen',
                    Operator => 'NE',
                    Value    => ''
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field TicketFlag.Seen / Operator NE / Value zero',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketFlag.Seen',
                    Operator => 'NE',
                    Value    => '0'
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
