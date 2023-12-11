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
        Archived => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN'],
            ValueType    => 'Integer'
        }
    },
    'GetSupportedAttributes provides expected data'
);

# make sure config 'Ticket::ArchiveSystem' is active
$Kernel::OM->Get('Config')->Set(
    Key   => 'Ticket::ArchiveSystem',
    Value => 1
);

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
            Value    => 'y'
        },
        Expected => undef
    },
    {
        Name     => 'Search: Field invalid',
        Search   => {
            Field    => 'Test',
            Operator => 'EQ',
            Value    => 'y'
        },
        Expected => undef
    },
    {
        Name     => 'Search: Operator undef',
        Search   => {
            Field    => 'Archived',
            Operator => undef,
            Value    => 'y'
        },
        Expected => undef
    },
    {
        Name     => 'Search: Operator invalid',
        Search   => {
            Field    => 'Archived',
            Operator => 'Test',
            Value    => 'y'
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
        Name     => 'Search: valid search / Operator EQ / Value flag "y"',
        Search   => {
            Field    => 'Archived',
            Operator => 'EQ',
            Value    => 'y'
        },
        Expected => {
            Where => ['st.archive_flag = 1']
        }
    },
    {
        Name     => 'Search: valid search / Operator EQ / Value flag "n"',
        Search   => {
            Field    => 'Archived',
            Operator => 'EQ',
            Value    => 'n'
        },
        Expected => {
            Where => ['st.archive_flag = 0']
        }
    },
    {
        Name     => 'Search: valid search / Operator EQ / Value flag "Y"',
        Search   => {
            Field    => 'Archived',
            Operator => 'EQ',
            Value    => 'Y'
        },
        Expected => {
            Where => ['st.archive_flag = 1']
        }
    },
    {
        Name     => 'Search: valid search / Operator EQ / Value flag "N"',
        Search   => {
            Field    => 'Archived',
            Operator => 'EQ',
            Value    => 'N'
        },
        Expected => {
            Where => ['st.archive_flag = 0']
        }
    },
    {
        Name     => 'Search: valid search / Operator EQ / Value array 1',
        Search   => {
            Field    => 'Archived',
            Operator => 'EQ',
            Value    => [1]
        },
        Expected => {
            Where => ['st.archive_flag = 1']
        }
    },
    {
        Name     => 'Search: valid search / Operator EQ / Value array 0',
        Search   => {
            Field    => 'Archived',
            Operator => 'EQ',
            Value    => [0]
        },
        Expected => {
            Where => ['st.archive_flag = 0']
        }
    },
    {
        Name     => 'Search: valid search / Operator EQ / Value array 1 and 0',
        Search   => {
            Field    => 'Archived',
            Operator => 'EQ',
            Value    => [1,0]
        },
        Expected => {
            Where => ['st.archive_flag IN (0,1)']
        }
    },
    {
        Name     => 'Search: valid search / Operator EQ / Value array flag "y"',
        Search   => {
            Field    => 'Archived',
            Operator => 'EQ',
            Value    => ['y']
        },
        Expected => {
            Where => ['st.archive_flag = 1']
        }
    },
    {
        Name     => 'Search: valid search / Operator EQ / Value array flag "n"',
        Search   => {
            Field    => 'Archived',
            Operator => 'EQ',
            Value    => ['n']
        },
        Expected => {
            Where => ['st.archive_flag = 0']
        }
    },
    {
        Name     => 'Search: valid search / Operator EQ / Value array flag "y" and "n"',
        Search   => {
            Field    => 'Archived',
            Operator => 'EQ',
            Value    => ['y','n']
        },
        Expected => {
            Where => ['st.archive_flag IN (0,1)']
        }
    },
    {
        Name     => 'Search: valid search / Operator EQ / Value array flag "Y"',
        Search   => {
            Field    => 'Archived',
            Operator => 'EQ',
            Value    => ['Y']
        },
        Expected => {
            Where => ['st.archive_flag = 1']
        }
    },
    {
        Name     => 'Search: valid search / Operator EQ / Value array flag "N"',
        Search   => {
            Field    => 'Archived',
            Operator => 'EQ',
            Value    => ['N']
        },
        Expected => {
            Where => ['st.archive_flag = 0']
        }
    },
    {
        Name     => 'Search: valid search / Operator EQ / Value array flag "Y" and "N"',
        Search   => {
            Field    => 'Archived',
            Operator => 'EQ',
            Value    => ['Y','N']
        },
        Expected => {
            Where => ['st.archive_flag IN (0,1)']
        }
    },
    {
        Name     => 'Search: valid search / Operator EQ / Value array 1 and flag "n"',
        Search   => {
            Field    => 'Archived',
            Operator => 'EQ',
            Value    => [1,'n']
        },
        Expected => {
            Where => ['st.archive_flag IN (0,1)']
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
        Name     => 'Search: valid search / Operator NE / Value flag "y"',
        Search   => {
            Field    => 'Archived',
            Operator => 'NE',
            Value    => 'y'
        },
        Expected => {
            Where => ['st.archive_flag <> 1']
        }
    },
    {
        Name     => 'Search: valid search / Operator NE / Value flag "n"',
        Search   => {
            Field    => 'Archived',
            Operator => 'NE',
            Value    => 'n'
        },
        Expected => {
            Where => ['st.archive_flag <> 0']
        }
    },
    {
        Name     => 'Search: valid search / Operator NE / Value flag "Y"',
        Search   => {
            Field    => 'Archived',
            Operator => 'NE',
            Value    => 'Y'
        },
        Expected => {
            Where => ['st.archive_flag <> 1']
        }
    },
    {
        Name     => 'Search: valid search / Operator NE / Value flag "N"',
        Search   => {
            Field    => 'Archived',
            Operator => 'NE',
            Value    => 'N'
        },
        Expected => {
            Where => ['st.archive_flag <> 0']
        }
    },
    {
        Name     => 'Search: valid search / Operator NE / Value array 1',
        Search   => {
            Field    => 'Archived',
            Operator => 'NE',
            Value    => [1]
        },
        Expected => {
            Where => ['st.archive_flag <> 1']
        }
    },
    {
        Name     => 'Search: valid search / Operator NE / Value array 0',
        Search   => {
            Field    => 'Archived',
            Operator => 'NE',
            Value    => [0]
        },
        Expected => {
            Where => ['st.archive_flag <> 0']
        }
    },
    {
        Name     => 'Search: valid search / Operator NE / Value array 1 and 0',
        Search   => {
            Field    => 'Archived',
            Operator => 'NE',
            Value    => [1,0]
        },
        Expected => {
            Where => ['st.archive_flag NOT IN (0,1)']
        }
    },
    {
        Name     => 'Search: valid search / Operator NE / Value array flag "y"',
        Search   => {
            Field    => 'Archived',
            Operator => 'NE',
            Value    => ['y']
        },
        Expected => {
            Where => ['st.archive_flag <> 1']
        }
    },
    {
        Name     => 'Search: valid search / Operator NE / Value array flag "n"',
        Search   => {
            Field    => 'Archived',
            Operator => 'NE',
            Value    => ['n']
        },
        Expected => {
            Where => ['st.archive_flag <> 0']
        }
    },
    {
        Name     => 'Search: valid search / Operator NE / Value array flag "y" and "n"',
        Search   => {
            Field    => 'Archived',
            Operator => 'NE',
            Value    => ['y','n']
        },
        Expected => {
            Where => ['st.archive_flag NOT IN (0,1)']
        }
    },
    {
        Name     => 'Search: valid search / Operator NE / Value array flag "Y"',
        Search   => {
            Field    => 'Archived',
            Operator => 'NE',
            Value    => ['Y']
        },
        Expected => {
            Where => ['st.archive_flag <> 1']
        }
    },
    {
        Name     => 'Search: valid search / Operator NE / Value array flag "N"',
        Search   => {
            Field    => 'Archived',
            Operator => 'NE',
            Value    => ['N']
        },
        Expected => {
            Where => ['st.archive_flag <> 0']
        }
    },
    {
        Name     => 'Search: valid search / Operator NE / Value array flag "Y" and "N"',
        Search   => {
            Field    => 'Archived',
            Operator => 'NE',
            Value    => ['Y','N']
        },
        Expected => {
            Where => ['st.archive_flag NOT IN (0,1)']
        }
    },
    {
        Name     => 'Search: valid search / Operator NE / Value array 1 and flag "n"',
        Search   => {
            Field    => 'Archived',
            Operator => 'NE',
            Value    => [1,'n']
        },
        Expected => {
            Where => ['st.archive_flag NOT IN (0,1)']
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
            Where => ['st.archive_flag IN (0,1)']
        }
    },
    {
        Name     => 'Search: valid search / Operator IN / Value array flag "y"',
        Search   => {
            Field    => 'Archived',
            Operator => 'IN',
            Value    => ['y']
        },
        Expected => {
            Where => ['st.archive_flag IN (1)']
        }
    },
    {
        Name     => 'Search: valid search / Operator IN / Value array flag "n"',
        Search   => {
            Field    => 'Archived',
            Operator => 'IN',
            Value    => ['n']
        },
        Expected => {
            Where => ['st.archive_flag IN (0)']
        }
    },
    {
        Name     => 'Search: valid search / Operator IN / Value array flag "y" and "n"',
        Search   => {
            Field    => 'Archived',
            Operator => 'IN',
            Value    => ['y','n']
        },
        Expected => {
            Where => ['st.archive_flag IN (0,1)']
        }
    },
    {
        Name     => 'Search: valid search / Operator IN / Value array flag "Y"',
        Search   => {
            Field    => 'Archived',
            Operator => 'IN',
            Value    => ['Y']
        },
        Expected => {
            Where => ['st.archive_flag IN (1)']
        }
    },
    {
        Name     => 'Search: valid search / Operator IN / Value array flag "N"',
        Search   => {
            Field    => 'Archived',
            Operator => 'IN',
            Value    => ['N']
        },
        Expected => {
            Where => ['st.archive_flag IN (0)']
        }
    },
    {
        Name     => 'Search: valid search / Operator IN / Value array flag "Y" and "N"',
        Search   => {
            Field    => 'Archived',
            Operator => 'IN',
            Value    => ['Y','N']
        },
        Expected => {
            Where => ['st.archive_flag IN (0,1)']
        }
    },
    {
        Name     => 'Search: valid search / Operator IN / Value array 1 and flag "n"',
        Search   => {
            Field    => 'Archived',
            Operator => 'IN',
            Value    => [1,'n']
        },
        Expected => {
            Where => ['st.archive_flag IN (0,1)']
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
            Where => ['st.archive_flag NOT IN (0,1)']
        }
    },
    {
        Name     => 'Search: valid search / Operator !IN / Value array flag "y"',
        Search   => {
            Field    => 'Archived',
            Operator => '!IN',
            Value    => ['y']
        },
        Expected => {
            Where => ['st.archive_flag NOT IN (1)']
        }
    },
    {
        Name     => 'Search: valid search / Operator !IN / Value array flag "n"',
        Search   => {
            Field    => 'Archived',
            Operator => '!IN',
            Value    => ['n']
        },
        Expected => {
            Where => ['st.archive_flag NOT IN (0)']
        }
    },
    {
        Name     => 'Search: valid search / Operator !IN / Value array flag "y" and "n"',
        Search   => {
            Field    => 'Archived',
            Operator => '!IN',
            Value    => ['y','n']
        },
        Expected => {
            Where => ['st.archive_flag NOT IN (0,1)']
        }
    },
    {
        Name     => 'Search: valid search / Operator !IN / Value array flag "Y"',
        Search   => {
            Field    => 'Archived',
            Operator => '!IN',
            Value    => ['Y']
        },
        Expected => {
            Where => ['st.archive_flag NOT IN (1)']
        }
    },
    {
        Name     => 'Search: valid search / Operator !IN / Value array flag "N"',
        Search   => {
            Field    => 'Archived',
            Operator => '!IN',
            Value    => ['N']
        },
        Expected => {
            Where => ['st.archive_flag NOT IN (0)']
        }
    },
    {
        Name     => 'Search: valid search / Operator !IN / Value array flag "Y" and "N"',
        Search   => {
            Field    => 'Archived',
            Operator => '!IN',
            Value    => ['Y','N']
        },
        Expected => {
            Where => ['st.archive_flag NOT IN (0,1)']
        }
    },
    {
        Name     => 'Search: valid search / Operator !IN / Value array 1 and flag "N"',
        Search   => {
            Field    => 'Archived',
            Operator => '!IN',
            Value    => [1,'n']
        },
        Expected => {
            Where => ['st.archive_flag NOT IN (0,1)']
        }
    },
);
for my $Test ( @SearchTests ) {
    my $Result = $AttributeObject->Search(
        Search       => $Test->{Search},
        BoolOperator => 'AND',
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
            Select  => [ 'st.archive_flag' ],
            OrderBy => [ 'st.archive_flag' ]
        }
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

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field Archived / Operator EQ / Value "y"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Archived',
                    Operator => 'EQ',
                    Value    => 'y'
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: Field Archived / Operator NE / Value "y"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Archived',
                    Operator => 'NE',
                    Value    => 'y'
                }
            ]
        },
        Expected => [$TicketID2,$TicketID3]
    },
    {
        Name     => 'Search: Field Archived / Operator IN / Value "y"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Archived',
                    Operator => 'IN',
                    Value    => 'y'
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: Field Archived / Operator !IN / Value "y"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Archived',
                    Operator => '!IN',
                    Value    => 'y'
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
    BoolOperator => 'AND'
);
$Self->IsDeeply(
    $InactiveSearchResult,
    {},
    'Search: "Ticket::ArchiveSystem" inactive'
);

# check sort
my $InactiveSortResult = $AttributeObject->Sort(
    Attribute => 'Archived'
);
$Self->IsDeeply(
    $InactiveSortResult,
    {},
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
