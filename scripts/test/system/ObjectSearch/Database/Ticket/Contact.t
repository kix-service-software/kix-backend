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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Ticket::Contact';

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
        ContactID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','GT','GTE','LT','LTE'],
            ValueType    => 'NUMERIC'
        },
        Contact => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        }
    },
    'GetSupportedAttributes provides expected data'
);

# Quoting ESCAPE character backslash
my $QuoteBack = $Kernel::OM->Get('DB')->GetDatabaseFunction('QuoteBack');
my $Escape = "\\";
if ( $QuoteBack ) {
    $Escape =~ s/\\/$QuoteBack\\/g;
}

# Quoting single quote character
my $QuoteSingle = $Kernel::OM->Get('DB')->GetDatabaseFunction('QuoteSingle');

# Quoting semicolon character
my $QuoteSemicolon = $Kernel::OM->Get('DB')->GetDatabaseFunction('QuoteSemicolon');

# check if database is casesensitive
my $CaseSensitive = $Kernel::OM->Get('DB')->GetDatabaseFunction('CaseSensitive');

# get handling of order by null
my $OrderByNull = $Kernel::OM->Get('DB')->GetDatabaseFunction('OrderByNull') || '';

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
            Field    => 'ContactID',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'ContactID',
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
            Field    => 'ContactID',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'ContactID',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field ContactID / Operator EQ',
        Search       => {
            Field    => 'ContactID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.contact_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ContactID / Operator EQ / Value zero',
        Search       => {
            Field    => 'ContactID',
            Operator => 'EQ',
            Value    => '0'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                '(st.contact_id = 0 OR st.contact_id IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ContactID / Operator NE',
        Search       => {
            Field    => 'ContactID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                '(st.contact_id <> 1 OR st.contact_id IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ContactID / Operator NE / Value zero',
        Search       => {
            Field    => 'ContactID',
            Operator => 'NE',
            Value    => '0'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.contact_id <> 0'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ContactID / Operator IN',
        Search       => {
            Field    => 'ContactID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.contact_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ContactID / Operator !IN',
        Search       => {
            Field    => 'ContactID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.contact_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ContactID / Operator LT',
        Search       => {
            Field    => 'ContactID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.contact_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ContactID / Operator GT',
        Search       => {
            Field    => 'ContactID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.contact_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ContactID / Operator LTE',
        Search       => {
            Field    => 'ContactID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.contact_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ContactID / Operator GTE',
        Search       => {
            Field    => 'ContactID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.contact_id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Contact / Operator EQ',
        Search       => {
            Field    => 'Contact',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN contact tcon ON tcon.id = st.contact_id'
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(tcon.lastname) = \'test\' OR LOWER(tcon.firstname) = \'test\')' : '(tcon.lastname = \'test\' OR tcon.firstname = \'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Contact / Operator EQ / Value empty',
        Search       => {
            Field    => 'Contact',
            Operator => 'EQ',
            Value    => q{}
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN contact tcon ON tcon.id = st.contact_id'
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(tcon.lastname) = \'\' OR tcon.lastname IS NULL OR LOWER(tcon.firstname) = \'\' OR tcon.firstname IS NULL)' : '(tcon.lastname = \'\' OR tcon.lastname IS NULL OR tcon.firstname = \'\' OR tcon.firstname IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Contact / Operator NE',
        Search       => {
            Field    => 'Contact',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN contact tcon ON tcon.id = st.contact_id'
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(tcon.lastname) != \'test\' OR tcon.lastname IS NULL OR LOWER(tcon.firstname) != \'test\' OR tcon.firstname IS NULL)' : '(tcon.lastname != \'test\' OR tcon.lastname IS NULL OR tcon.firstname != \'test\' OR tcon.firstname IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Contact / Operator NE / Value empty',
        Search       => {
            Field    => 'Contact',
            Operator => 'NE',
            Value    => q{}
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN contact tcon ON tcon.id = st.contact_id'
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(tcon.lastname) != \'\' OR LOWER(tcon.firstname) != \'\')' : '(tcon.lastname != \'\' OR tcon.firstname != \'\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Contact / Operator IN',
        Search       => {
            Field    => 'Contact',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN contact tcon ON tcon.id = st.contact_id'
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(tcon.lastname) IN (\'test\') OR LOWER(tcon.firstname) IN (\'test\'))' : '(tcon.lastname IN (\'test\') OR tcon.firstname IN (\'test\'))'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Contact / Operator !IN',
        Search       => {
            Field    => 'Contact',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN contact tcon ON tcon.id = st.contact_id'
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(tcon.lastname) NOT IN (\'test\') OR LOWER(tcon.firstname) NOT IN (\'test\'))' : '(tcon.lastname NOT IN (\'test\') OR tcon.firstname NOT IN (\'test\'))'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Contact / Operator STARTSWITH',
        Search       => {
            Field    => 'Contact',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN contact tcon ON tcon.id = st.contact_id'
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(tcon.lastname) LIKE \'test%\' OR LOWER(tcon.firstname) LIKE \'test%\')' : '(tcon.lastname LIKE \'test%\' OR tcon.firstname LIKE \'test%\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Contact / Operator ENDSWITH',
        Search       => {
            Field    => 'Contact',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN contact tcon ON tcon.id = st.contact_id'
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(tcon.lastname) LIKE \'%test\' OR LOWER(tcon.firstname) LIKE \'%test\')' : '(tcon.lastname LIKE \'%test\' OR tcon.firstname LIKE \'%test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Contact / Operator CONTAINS',
        Search       => {
            Field    => 'Contact',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN contact tcon ON tcon.id = st.contact_id'
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(tcon.lastname) LIKE \'%test%\' OR LOWER(tcon.firstname) LIKE \'%test%\')' : '(tcon.lastname LIKE \'%test%\' OR tcon.firstname LIKE \'%test%\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Contact / Operator LIKE',
        Search       => {
            Field    => 'Contact',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN contact tcon ON tcon.id = st.contact_id'
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(tcon.lastname) LIKE \'test\' OR LOWER(tcon.firstname) LIKE \'test\')' : '(tcon.lastname LIKE \'test\' OR tcon.firstname LIKE \'test\')'
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
        Name      => 'Sort: Attribute "ContactID"',
        Attribute => 'ContactID',
        Expected  => {
            'Join'    => [],
            'OrderBy' => [
                'st.contact_id'
            ],
            'Select'  => [
                'st.contact_id'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Contact"',
        Attribute => 'Contact',
        Expected  => {
            'Join'    => [
                'LEFT OUTER JOIN contact tcon ON tcon.id = st.contact_id'
            ],
            'OrderBy' => [
                'LOWER(tcon.lastname)', 'LOWER(tcon.firstname)'
            ],
            'Select'  => [
                'tcon.lastname', 'tcon.firstname'
            ]
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

## prepare contact mapping
my $ContactName1      = 'Test003';
my $ContactName2      = 'Unit1';
my $ContactName3      = 'test2';

my $ContactLastname1  = 'Test1';
my $ContactLastname2  = 'test2';
my $ContactLastname3  = 'Unit1';
my $ContactFirstname1 = 'Unit001';
my $ContactFirstname2 = 'test002';
my $ContactFirstname3 = 'Test003';
my $ContactID1 =  $Kernel::OM->Get('Contact')->ContactAdd(
    Lastname  => $ContactLastname1,
    Firstname => $ContactFirstname1,
    ValidID   => 1,
    UserID    => 1
);
$Self->True(
    $ContactID1,
    'Created first contact'
);
my $ContactID2 =  $Kernel::OM->Get('Contact')->ContactAdd(
    Lastname  => $ContactLastname2,
    Firstname => $ContactFirstname2,
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $ContactID2,
    'Created second contact'
);
my $ContactID3 =  $Kernel::OM->Get('Contact')->ContactAdd(
    Lastname  => $ContactLastname3,
    Firstname => $ContactFirstname3,
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $ContactID3,
    'Created third contact'
);

# discard contact object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Contact'],
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
    ContactID      => $ContactID1,
    OrganisationID => undef,
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
    ContactID      => $ContactID2,
    OrganisationID => undef,
    OwnerID        => 1,
    ResponsibleID  => 1,
    UserID         => 1
);
$Self->True(
    $TicketID2,
    'Created second ticket'
);
# third ticket
my $TicketID3 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => 1,
    Lock           => 'unlock',
    PriorityID     => 1,
    StateID        => 1,
    TypeID         => 1,
    ContactID      => $ContactID3,
    OrganisationID => undef,
    OwnerID        => 1,
    ResponsibleID  => 1,
    UserID         => 1
);
$Self->True(
    $TicketID3,
    'Created third ticket'
);
# fourth ticket
my $TicketID4 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => 1,
    Lock           => 'unlock',
    PriorityID     => 1,
    StateID        => 1,
    TypeID         => 1,
    ContactID      => undef,
    OrganisationID => undef,
    OwnerID        => 1,
    ResponsibleID  => 1,
    UserID         => 1
);
$Self->True(
    $TicketID4,
    'Created fourth ticket'
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Ticket'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field ContactID / Operator EQ / Value $ContactID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ContactID',
                    Operator => 'EQ',
                    Value    => $ContactID2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field ContactID / Operator NE / Value $ContactID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ContactID',
                    Operator => 'NE',
                    Value    => $ContactID2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3,$TicketID4]
    },
    {
        Name     => 'Search: Field ContactID / Operator IN / Value [$ContactID1,$ContactID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ContactID',
                    Operator => 'IN',
                    Value    => [$ContactID1,$ContactID3]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID3]
    },
    {
        Name     => 'Search: Field ContactID / Operator !IN / Value [$ContactID1,$ContactID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ContactID',
                    Operator => '!IN',
                    Value    => [$ContactID1,$ContactID3]
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field ContactID / Operator LT / Value $ContactID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ContactID',
                    Operator => 'LT',
                    Value    => $ContactID2
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: Field ContactID / Operator GT / Value $ContactID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ContactID',
                    Operator => 'GT',
                    Value    => $ContactID2
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field ContactID / Operator LTE / Value $ContactID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ContactID',
                    Operator => 'LTE',
                    Value    => $ContactID2
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2]
    },
    {
        Name     => 'Search: Field ContactID / Operator GTE / Value $ContactID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ContactID',
                    Operator => 'GTE',
                    Value    => $ContactID2
                }
            ]
        },
        Expected => [$TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field Contact / Operator EQ / Value $ContactName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Contact',
                    Operator => 'EQ',
                    Value    => $ContactName2
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field Contact / Operator NE / Value $ContactName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Contact',
                    Operator => 'NE',
                    Value    => $ContactName2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2,$TicketID3,$TicketID4]
    },
    {
        Name     => 'Search: Field Contact / Operator IN / Value [$ContactName1,$ContactName3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Contact',
                    Operator => 'IN',
                    Value    => [$ContactName1,$ContactName3]
                }
            ]
        },
        Expected => [$TicketID2, $TicketID3]
    },
    {
        Name     => 'Search: Field Contact / Operator !IN / Value [$ContactName1,$ContactName3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Contact',
                    Operator => '!IN',
                    Value    => [$ContactName1,$ContactName3]
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => 'Search: Field Contact / Operator STARTSWITH / Value $ContactName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Contact',
                    Operator => 'STARTSWITH',
                    Value    => $ContactName2
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field Contact / Operator STARTSWITH / Value substr($ContactName2,0,4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Contact',
                    Operator => 'STARTSWITH',
                    Value    => substr($ContactName2,0,4)
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field Contact / Operator ENDSWITH / Value $ContactName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Contact',
                    Operator => 'ENDSWITH',
                    Value    => $ContactName2
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field Contact / Operator ENDSWITH / Value substr($ContactName2,-5)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Contact',
                    Operator => 'ENDSWITH',
                    Value    => substr($ContactName2,-5)
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field Contact / Operator CONTAINS / Value $ContactName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Contact',
                    Operator => 'CONTAINS',
                    Value    => $ContactName2
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field Contact / Operator CONTAINS / Value substr($ContactName3,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Contact',
                    Operator => 'CONTAINS',
                    Value    => substr($ContactName3,2,-2)
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => 'Search: Field Contact / Operator LIKE / Value $ContactName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Contact',
                    Operator => 'LIKE',
                    Value    => $ContactName2
                }
            ]
        },
        Expected => [$TicketID3]
    },
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
        Name     => 'Sort: Field ContactID',
        Sort     => [
            {
                Field => 'ContactID'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$TicketID1,$TicketID2,$TicketID3,$TicketID4] : [$TicketID4,$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => 'Sort: Field ContactID / Direction ascending',
        Sort     => [
            {
                Field     => 'ContactID',
                Direction => 'ascending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$TicketID1,$TicketID2,$TicketID3,$TicketID4] : [$TicketID4,$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => 'Sort: Field ContactID / Direction descending',
        Sort     => [
            {
                Field     => 'ContactID',
                Direction => 'descending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$TicketID4,$TicketID3,$TicketID2,$TicketID1] : [$TicketID3,$TicketID2,$TicketID1,$TicketID4]
    },
    {
        Name     => 'Sort: Field Contact',
        Sort     => [
            {
                Field => 'Contact'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$TicketID1,$TicketID2,$TicketID3,$TicketID4] : [$TicketID4,$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => 'Sort: Field Contact / Direction ascending',
        Sort     => [
            {
                Field     => 'Contact',
                Direction => 'ascending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$TicketID1,$TicketID2,$TicketID3,$TicketID4] : [$TicketID4,$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => 'Sort: Field Contact / Direction descending',
        Sort     => [
            {
                Field     => 'Contact',
                Direction => 'descending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$TicketID4,$TicketID3,$TicketID2,$TicketID1] : [$TicketID3,$TicketID2,$TicketID1,$TicketID4]
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
