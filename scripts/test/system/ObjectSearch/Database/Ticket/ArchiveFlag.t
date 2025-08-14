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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Ticket::ArchiveFlag';

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

# make sure config 'Ticket::ArchiveSystem' is inactive
$Kernel::OM->Get('Config')->Set(
    Key   => 'Ticket::ArchiveSystem',
    Value => 0
);

# check GetSupportedAttributes
my $InactiveAttributeList = $AttributeObject->GetSupportedAttributes();
$Self->IsDeeply(
    $InactiveAttributeList,
    {},
    'GetSupportedAttributes provides expected data when "Ticket::ArchiveSystem" is inactive'
);

# make sure config 'Ticket::ArchiveSystem' is active
$Kernel::OM->Get('Config')->Set(
    Key   => 'Ticket::ArchiveSystem',
    Value => 1
);

# check GetSupportedAttributes
my $ActiveAttributeList = $AttributeObject->GetSupportedAttributes();
$Self->IsDeeply(
    $ActiveAttributeList,
    {
        Archived => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN'],
            ValueType      => 'NUMERIC'
        }
    },
    'GetSupportedAttributes provides expected data when "Ticket::ArchiveSystem" is active'
);

# check AttributePrepare
my @AttributePrepareTests = (
    {
        Name      => 'AttributePrepare: empty parameter',
        Parameter => {},
        Expected  => {
            Column => 'st.archive_flag',
        }
    },
    {
        Name      => 'AttributePrepare: PrepareType "Select"',
        Parameter => {
            PrepareType => 'Select'
        },
        Expected  => {
            Column => 'st.archive_flag',
        }
    },
    {
        Name      => 'AttributePrepare: PrepareType "Condition"',
        Parameter => {
            PrepareType => 'Condition'
        },
        Expected  => {
            Column       => 'st.archive_flag',
            ConditionDef => {
                ValueType => 'NUMERIC'
            }
        }
    },
    {
        Name      => 'AttributePrepare: PrepareType "Sort"',
        Parameter => {
            PrepareType => 'Sort'
        },
        Expected  => {
            Column => 'st.archive_flag',
        }
    },
    {
        Name      => 'AttributePrepare: PrepareType "Fulltext"',
        Parameter => {
            PrepareType => 'Fulltext'
        },
        Expected  => {
            Column => 'st.archive_flag',
        }
    },
);
for my $Test ( @AttributePrepareTests ) {
    my $Result = $AttributeObject->AttributePrepare(
        %{ $Test->{Parameter} },
        Silent => defined( $Test->{Expected} ) ? 0 : 1
    );
    $Self->IsDeeply(
        $Result,
        $Test->{Expected},
        $Test->{Name}
    );
}

# check Select
my @SelectTests = (
    {
        Name      => 'Select: Attribute undef',
        Parameter => {
            Attribute => undef
        },
        Expected  => undef
    },
    {
        Name      => 'Select: Attribute invalid',
        Parameter => {
            Attribute => 'Test'
        },
        Expected  => undef
    },
    {
        Name      => 'Select: Attribute Archived',
        Parameter => {
            Attribute => 'Archived'
        },
        Expected  => {
            Select => ['st.archive_flag AS "Archived"']
        }
    }
);
for my $Test ( @SelectTests ) {
    my $Result = $AttributeObject->Select(
        %{ $Test->{Parameter} },
        Silent => defined( $Test->{Expected} ) ? 0 : 1
    );
    $Self->IsDeeply(
        $Result,
        $Test->{Expected},
        $Test->{Name}
    );
}

# check Search
my @SearchTests = (
    {
        Name     => 'Search: undef search',
        Search   => undef,
        Expected => undef
    },
    {
        Name     => 'Search: Value undef',
        Search   => {
            Field    => 'Archived',
            Operator => 'EQ',
            Value    => undef

        },
        Expected => undef
    },
    {
        Name     => 'Search: Value invalid',
        Search   => {
            Field    => 'Archived',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected => undef
    },
    {
        Name     => 'Search: Value empty',
        Search   => {
            Field    => 'Archived',
            Operator => 'EQ',
            Value    => ''
        },
        Expected => undef
    },
    {
        Name     => 'Search: Value invalid array',
        Search   => {
            Field    => 'Archived',
            Operator => 'EQ',
            Value    => ['Test']
        },
        Expected => undef
    },
    {
        Name     => 'Search: Field undef',
        Search   => {
            Field    => undef,
            Operator => 'EQ',
            Value    => '1'
        },
        Expected => undef
    },
    {
        Name     => 'Search: Field invalid',
        Search   => {
            Field    => 'Test',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected => undef
    },
    {
        Name     => 'Search: Operator undef',
        Search   => {
            Field    => 'Archived',
            Operator => undef,
            Value    => '1'
        },
        Expected => undef
    },
    {
        Name     => 'Search: Operator invalid',
        Search   => {
            Field    => 'Archived',
            Operator => 'Test',
            Value    => '1'
        },
        Expected => undef
    },
    {
        Name     => 'Search: valid search / Operator EQ / Value 1',
        Search   => {
            Field    => 'Archived',
            Operator => 'EQ',
            Value    => 1
        },
        Expected => {
            Where => ['st.archive_flag = 1']
        }
    },
    {
        Name     => 'Search: valid search / Operator EQ / Value 0',
        Search   => {
            Field    => 'Archived',
            Operator => 'EQ',
            Value    => 0
        },
        Expected => {
            Where => ['st.archive_flag = 0']
        }
    },
    {
        Name     => 'Search: valid search / Operator NE / Value 1',
        Search   => {
            Field    => 'Archived',
            Operator => 'NE',
            Value    => 1
        },
        Expected => {
            Where => ['st.archive_flag <> 1']
        }
    },
    {
        Name     => 'Search: valid search / Operator NE / Value 0',
        Search   => {
            Field    => 'Archived',
            Operator => 'NE',
            Value    => 0
        },
        Expected => {
            Where => ['st.archive_flag <> 0']
        }
    },
    {
        Name     => 'Search: valid search / Operator IN / Value array empty',
        Search   => {
            Field    => 'Archived',
            Operator => 'IN',
            Value    => []
        },
        Expected => {
            Where => ['1=0']
        }
    },
    {
        Name     => 'Search: valid search / Operator IN / Value array 1',
        Search   => {
            Field    => 'Archived',
            Operator => 'IN',
            Value    => [1]
        },
        Expected => {
            Where => ['st.archive_flag IN (1)']
        }
    },
    {
        Name     => 'Search: valid search / Operator IN / Value array 0',
        Search   => {
            Field    => 'Archived',
            Operator => 'IN',
            Value    => [0]
        },
        Expected => {
            Where => ['st.archive_flag IN (0)']
        }
    },
    {
        Name     => 'Search: valid search / Operator IN / Value array 1 and 0',
        Search   => {
            Field    => 'Archived',
            Operator => 'IN',
            Value    => [1,0]
        },
        Expected => {
            Where => ['st.archive_flag IN (1,0)']
        }
    },
    {
        Name     => 'Search: valid search / Operator !IN / Value array empty',
        Search   => {
            Field    => 'Archived',
            Operator => '!IN',
            Value    => []
        },
        Expected => {
            Where => ['1=1']
        }
    },
    {
        Name     => 'Search: valid search / Operator !IN / Value array 1',
        Search   => {
            Field    => 'Archived',
            Operator => '!IN',
            Value    => [1]
        },
        Expected => {
            Where => ['st.archive_flag NOT IN (1)']
        }
    },
    {
        Name     => 'Search: valid search / Operator !IN / Value array 0',
        Search   => {
            Field    => 'Archived',
            Operator => '!IN',
            Value    => [0]
        },
        Expected => {
            Where => ['st.archive_flag NOT IN (0)']
        }
    },
    {
        Name     => 'Search: valid search / Operator !IN / Value array 1 and 0',
        Search   => {
            Field    => 'Archived',
            Operator => '!IN',
            Value    => [1,0]
        },
        Expected => {
            Where => ['st.archive_flag NOT IN (1,0)']
        }
    }
);
for my $Test ( @SearchTests ) {
    # make sure config 'Ticket::ArchiveSystem' is active
    $Kernel::OM->Get('Config')->Set(
        Key   => 'Ticket::ArchiveSystem',
        Value => 1
    );
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
        Name      => 'Sort: Attribute "Archived"',
        Attribute => 'Archived',
        Expected  => {
            Select  => [ 'st.archive_flag AS SortAttr0' ],
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

# make sure config 'Ticket::ArchiveSystem' is active for ticket object
$Kernel::OM->Get('Config')->Set(
    Key   => 'Ticket::ArchiveSystem',
    Value => 1
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
my $TicketArchiveFlag1 = $Kernel::OM->Get('Ticket')->TicketArchiveFlagSet(
    ArchiveFlag => 'y',
    TicketID    => $TicketID1,
    UserID      => 1,
);
$Self->True(
    $TicketArchiveFlag1,
    'Archive flag for first ticket'
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
my $TicketArchiveFlag2 = $Kernel::OM->Get('Ticket')->TicketArchiveFlagSet(
    ArchiveFlag => 'n',
    TicketID    => $TicketID2,
    UserID      => 1,
);
$Self->True(
    $TicketArchiveFlag2,
    'Archive flag for first ticket'
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
    'Created third ticket without explicit flag set'
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Ticket'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field Archived / Operator EQ / Value 1',
        Search   => {
            'AND' => [
                {
                    Field    => 'Archived',
                    Operator => 'EQ',
                    Value    => 1
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: Field Archived / Operator NE / Value 1',
        Search   => {
            'AND' => [
                {
                    Field    => 'Archived',
                    Operator => 'NE',
                    Value    => 1
                }
            ]
        },
        Expected => [$TicketID2,$TicketID3]
    },
    {
        Name     => 'Search: Field Archived / Operator IN / Value 1',
        Search   => {
            'AND' => [
                {
                    Field    => 'Archived',
                    Operator => 'IN',
                    Value    => [1]
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: Field Archived / Operator !IN / Value 1',
        Search   => {
            'AND' => [
                {
                    Field    => 'Archived',
                    Operator => '!IN',
                    Value    => [1]
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
my @IntegrationSortTests = (
    {
        Name     => 'Sort: Field Archived',
        Sort     => [
            {
                Field => 'Archived'
            }
        ],
        Expected => [$TicketID2,$TicketID3,$TicketID1]
    },
    {
        Name     => 'Sort: Field Archived / Direction ascending',
        Sort     => [
            {
                Field     => 'Archived',
                Direction => 'ascending'
            }
        ],
        Expected => [$TicketID2,$TicketID3,$TicketID1]
    },
    {
        Name     => 'Sort: Field Archived / Direction descending',
        Sort     => [
            {
                Field     => 'Archived',
                Direction => 'descending'
            }
        ],
        Expected => [$TicketID1,$TicketID2,$TicketID3]
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Ticket',
        Result     => 'ARRAY',
        Sort       => $Test->{Sort},
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

# make sure config 'Ticket::ArchiveSystem' is inactive
$Kernel::OM->Get('Config')->Set(
    Key   => 'Ticket::ArchiveSystem',
    Value => 0
);

# check search
my $InactiveSearchResult = $AttributeObject->Search(
    Search       => {
        Field    => 'Archived',
        Operator => 'EQ',
        Value    => 1
    },
    BoolOperator => 'AND',
    Silent       => 1
);
$Self->IsDeeply(
    $InactiveSearchResult,
    undef,
    'Search: "Ticket::ArchiveSystem" inactive'
);

# check sort
my $InactiveSortResult = $AttributeObject->Sort(
    Attribute => 'Archived',
    Language  => 'en',
    Silent    => 1
);
$Self->IsDeeply(
    $InactiveSortResult,
    undef,
    'Sort: "Ticket::ArchiveSystem" inactive'
);

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
