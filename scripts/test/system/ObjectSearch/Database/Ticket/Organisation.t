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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Ticket::Organisation';

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
        OrganisationID => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','GT','GTE','LT','LTE'],
            ValueType      => 'NUMERIC'
        },
        Organisation => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        OrganisationNumber => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
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
        Name         => "Search: undef search",
        Search       => undef,
        Expected     => undef
    },
    {
        Name         => "Search: Value undef",
        Search       => {
            Field    => 'OrganisationID',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => "Search: Value invalid",
        Search       => {
            Field    => 'OrganisationID',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => "Search: Field undef",
        Search       => {
            Field    => undef,
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => "Search: Field invalid",
        Search       => {
            Field    => 'Test',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => "Search: Operator undef",
        Search       => {
            Field    => 'OrganisationID',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => "Search: Operator invalid",
        Search       => {
            Field    => 'OrganisationID',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => "Search: valid search / Field OrganisationID / Operator EQ",
        Search       => {
            Field    => 'OrganisationID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.organisation_id = 1'
            ]
        }
    },
    {
        Name         => "Search: valid search / Field OrganisationID / Operator EQ / Value zero",
        Search       => {
            Field    => 'OrganisationID',
            Operator => 'EQ',
            Value    => '0'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                '(st.organisation_id = 0 OR st.organisation_id IS NULL)'
            ]
        }
    },
    {
        Name         => "Search: valid search / Field OrganisationID / Operator NE",
        Search       => {
            Field    => 'OrganisationID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                '(st.organisation_id <> 1 OR st.organisation_id IS NULL)'
            ]
        }
    },
    {
        Name         => "Search: valid search / Field OrganisationID / Operator NE / Value zero",
        Search       => {
            Field    => 'OrganisationID',
            Operator => 'NE',
            Value    => '0'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.organisation_id <> 0'
            ]
        }
    },
    {
        Name         => "Search: valid search / Field OrganisationID / Operator IN",
        Search       => {
            Field    => 'OrganisationID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.organisation_id IN (1)'
            ]
        }
    },
    {
        Name         => "Search: valid search / Field OrganisationID / Operator !IN",
        Search       => {
            Field    => 'OrganisationID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.organisation_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => "Search: valid search / Field OrganisationID / Operator LT",
        Search       => {
            Field    => 'OrganisationID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.organisation_id < 1'
            ]
        }
    },
    {
        Name         => "Search: valid search / Field OrganisationID / Operator GT",
        Search       => {
            Field    => 'OrganisationID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.organisation_id > 1'
            ]
        }
    },
    {
        Name         => "Search: valid search / Field OrganisationID / Operator LTE",
        Search       => {
            Field    => 'OrganisationID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.organisation_id <= 1'
            ]
        }
    },
    {
        Name         => "Search: valid search / Field OrganisationID / Operator GTE",
        Search       => {
            Field    => 'OrganisationID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'st.organisation_id >= 1'
            ]
        }
    },
    {
        Name         => "Search: valid search / Field Organisation / Operator EQ",
        Search       => {
            Field    => 'Organisation',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN organisation torg ON torg.id = st.organisation_id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(torg.name) = \'test\'' : 'torg.name = \'test\''
            ]
        }
    },
    {
        Name         => "Search: valid search / Field Organisation / Operator EQ / Value empty string",
        Search       => {
            Field    => 'Organisation',
            Operator => 'EQ',
            Value    => q{}
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN organisation torg ON torg.id = st.organisation_id'
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(torg.name) = \'\' OR torg.name IS NULL)' : '(torg.name = \'\' OR torg.name IS NULL)'
            ]
        }
    },
    {
        Name         => "Search: valid search / Field Organisation / Operator NE",
        Search       => {
            Field    => 'Organisation',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN organisation torg ON torg.id = st.organisation_id'
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(torg.name) != \'test\' OR torg.name IS NULL)' : '(torg.name != \'test\' OR torg.name IS NULL)'
            ]
        }
    },
    {
        Name         => "Search: valid search / Field Organisation / Operator NE / Value empty string",
        Search       => {
            Field    => 'Organisation',
            Operator => 'NE',
            Value    => q{}
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN organisation torg ON torg.id = st.organisation_id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(torg.name) != \'\'' : 'torg.name != \'\''
            ]
        }
    },
    {
        Name         => "Search: valid search / Field Organisation / Operator IN",
        Search       => {
            Field    => 'Organisation',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN organisation torg ON torg.id = st.organisation_id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(torg.name) IN (\'test\')' : 'torg.name IN (\'test\')'
            ]
        }
    },
    {
        Name         => "Search: valid search / Field Organisation / Operator !IN",
        Search       => {
            Field    => 'Organisation',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN organisation torg ON torg.id = st.organisation_id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(torg.name) NOT IN (\'test\')' : 'torg.name NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => "Search: valid search / Field Organisation / Operator STARTSWITH",
        Search       => {
            Field    => 'Organisation',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN organisation torg ON torg.id = st.organisation_id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(torg.name) LIKE \'test%\'' : 'torg.name LIKE \'test%\''
            ]
        }
    },
    {
        Name         => "Search: valid search / Field Organisation / Operator ENDSWITH",
        Search       => {
            Field    => 'Organisation',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN organisation torg ON torg.id = st.organisation_id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(torg.name) LIKE \'%test\'' : 'torg.name LIKE \'%test\''
            ]
        }
    },
    {
        Name         => "Search: valid search / Field Organisation / Operator CONTAINS",
        Search       => {
            Field    => 'Organisation',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN organisation torg ON torg.id = st.organisation_id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(torg.name) LIKE \'%test%\'' : 'torg.name LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => "Search: valid search / Field Organisation / Operator LIKE",
        Search       => {
            Field    => 'Organisation',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN organisation torg ON torg.id = st.organisation_id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(torg.name) LIKE \'test\'' : 'torg.name LIKE \'test\''
            ]
        }
    },
    {
        Name         => "Search: valid search / Field OrganisationNumber / Operator EQ",
        Search       => {
            Field    => 'OrganisationNumber',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN organisation torg ON torg.id = st.organisation_id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(torg.number) = \'test\'' : 'torg.number = \'test\''
            ]
        }
    },
    {
        Name         => "Search: valid search / Field OrganisationNumber / Operator EQ / Value empty string",
        Search       => {
            Field    => 'OrganisationNumber',
            Operator => 'EQ',
            Value    => q{}
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN organisation torg ON torg.id = st.organisation_id'
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(torg.number) = \'\' OR torg.number IS NULL)' : '(torg.number = \'\' OR torg.number IS NULL)'
            ]
        }
    },
    {
        Name         => "Search: valid search / Field OrganisationNumber / Operator NE",
        Search       => {
            Field    => 'OrganisationNumber',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN organisation torg ON torg.id = st.organisation_id'
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(torg.number) != \'test\' OR torg.number IS NULL)' : '(torg.number != \'test\' OR torg.number IS NULL)'
            ]
        }
    },
    {
        Name         => "Search: valid search / Field OrganisationNumber / Operator NE / Value empty string",
        Search       => {
            Field    => 'OrganisationNumber',
            Operator => 'NE',
            Value    => q{}
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN organisation torg ON torg.id = st.organisation_id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(torg.number) != \'\'' : 'torg.number != \'\''
            ]
        }
    },
    {
        Name         => "Search: valid search / Field OrganisationNumber / Operator IN",
        Search       => {
            Field    => 'OrganisationNumber',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN organisation torg ON torg.id = st.organisation_id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(torg.number) IN (\'test\')' : 'torg.number IN (\'test\')'
            ]
        }
    },
    {
        Name         => "Search: valid search / Field OrganisationNumber / Operator !IN",
        Search       => {
            Field    => 'OrganisationNumber',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN organisation torg ON torg.id = st.organisation_id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(torg.number) NOT IN (\'test\')' : 'torg.number NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => "Search: valid search / Field OrganisationNumber / Operator STARTSWITH",
        Search       => {
            Field    => 'OrganisationNumber',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN organisation torg ON torg.id = st.organisation_id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(torg.number) LIKE \'test%\'' : 'torg.number LIKE \'test%\''
            ]
        }
    },
    {
        Name         => "Search: valid search / Field OrganisationNumber / Operator ENDSWITH",
        Search       => {
            Field    => 'OrganisationNumber',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN organisation torg ON torg.id = st.organisation_id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(torg.number) LIKE \'%test\'' : 'torg.number LIKE \'%test\''
            ]
        }
    },
    {
        Name         => "Search: valid search / Field OrganisationNumber / Operator CONTAINS",
        Search       => {
            Field    => 'OrganisationNumber',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN organisation torg ON torg.id = st.organisation_id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(torg.number) LIKE \'%test%\'' : 'torg.number LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => "Search: valid search / Field OrganisationNumber / Operator LIKE",
        Search       => {
            Field    => 'OrganisationNumber',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN organisation torg ON torg.id = st.organisation_id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(torg.number) LIKE \'test\'' : 'torg.number LIKE \'test\''
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
        Name      => 'Sort: Attribute "OrganisationID"',
        Attribute => 'OrganisationID',
        Expected  => {
            'Join'    => [],
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select'  => [
                'st.organisation_id AS SortAttr0'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Organisation"',
        Attribute => 'Organisation',
        Expected  => {
            'Join'    => [
                'LEFT OUTER JOIN organisation torg ON torg.id = st.organisation_id'
            ],
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select'  => [
                'LOWER(torg.name) AS SortAttr0'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "OrganisationNumber"',
        Attribute => 'OrganisationNumber',
        Expected  => {
            'Join'    => [
                'LEFT OUTER JOIN organisation torg ON torg.id = st.organisation_id'
            ],
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select'  => [
                'LOWER(torg.number) AS SortAttr0'
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

## prepare organisation mapping
my $OrganisationName1   = 'Test001';
my $OrganisationName2   = 'test002';
my $OrganisationName3   = 'Test003';
my $OrganisationNumber1 = 'Test001';
my $OrganisationNumber2 = 'test002';
my $OrganisationNumber3 = 'Test003';
my $OrganisationID1 =  $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => $OrganisationNumber1,
    Name    => $OrganisationName1,
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $OrganisationID1,
    'Created first organisation'
);
my $OrganisationID2 =  $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => $OrganisationNumber2,
    Name    => $OrganisationName2,
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $OrganisationID2,
    'Created second organisation'
);
my $OrganisationID3 =  $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => $OrganisationNumber3,
    Name    => $OrganisationName3,
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $OrganisationID3,
    'Created third organisation'
);

# discard organisation object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Organisation'],
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
    OrganisationID => $OrganisationID1,
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
    OrganisationID => $OrganisationID2,
    ContactID      => 1,
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
    OrganisationID => $OrganisationID3,
    ContactID      => 1,
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
    OrganisationID => undef,
    ContactID      => undef,
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
        Name     => "Search: Field OrganisationID / Operator EQ / Value \$OrganisationID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationID',
                    Operator => 'EQ',
                    Value    => $OrganisationID2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OrganisationID / Operator NE / Value \$OrganisationID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationID',
                    Operator => 'NE',
                    Value    => $OrganisationID2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3,$TicketID4]
    },
    {
        Name     => "Search: Field OrganisationID / Operator IN / Value [\$OrganisationID1,\$OrganisationID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationID',
                    Operator => 'IN',
                    Value    => [$OrganisationID1,$OrganisationID3]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID3]
    },
    {
        Name     => "Search: Field OrganisationID / Operator !IN / Value [\$OrganisationID1,\$OrganisationID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationID',
                    Operator => '!IN',
                    Value    => [$OrganisationID1,$OrganisationID3]
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OrganisationID / Operator LT / Value \$OrganisationID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationID',
                    Operator => 'LT',
                    Value    => $OrganisationID2
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => "Search: Field OrganisationID / Operator GT / Value \$OrganisationID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationID',
                    Operator => 'GT',
                    Value    => $OrganisationID2
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => "Search: Field OrganisationID / Operator LTE / Value \$OrganisationID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationID',
                    Operator => 'LTE',
                    Value    => $OrganisationID2
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2]
    },
    {
        Name     => "Search: Field OrganisationID / Operator GTE / Value \$OrganisationID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationID',
                    Operator => 'GTE',
                    Value    => $OrganisationID2
                }
            ]
        },
        Expected => [$TicketID2, $TicketID3]
    },
    {
        Name     => "Search: Field Organisation / Operator EQ / Value \$OrganisationName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Organisation',
                    Operator => 'EQ',
                    Value    => $OrganisationName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field Organisation / Operator NE / Value \$OrganisationName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Organisation',
                    Operator => 'NE',
                    Value    => $OrganisationName2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3,$TicketID4]
    },
    {
        Name     => "Search: Field Organisation / Operator IN / Value [\$OrganisationName1,\$OrganisationName3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Organisation',
                    Operator => 'IN',
                    Value    => [$OrganisationName1,$OrganisationName3]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID3]
    },
    {
        Name     => "Search: Field Organisation / Operator !IN / Value [\$OrganisationName1,\$OrganisationName3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Organisation',
                    Operator => '!IN',
                    Value    => [$OrganisationName1,$OrganisationName3]
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field Organisation / Operator STARTSWITH / Value \$OrganisationName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Organisation',
                    Operator => 'STARTSWITH',
                    Value    => $OrganisationName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field Organisation / Operator STARTSWITH / Value substr(\$OrganisationName2,0,4)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Organisation',
                    Operator => 'STARTSWITH',
                    Value    => substr($OrganisationName2,0,4)
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => "Search: Field Organisation / Operator ENDSWITH / Value \$OrganisationName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Organisation',
                    Operator => 'ENDSWITH',
                    Value    => $OrganisationName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field Organisation / Operator ENDSWITH / Value substr(\$OrganisationName2,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Organisation',
                    Operator => 'ENDSWITH',
                    Value    => substr($OrganisationName2,-5)
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field Organisation / Operator CONTAINS / Value \$OrganisationName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Organisation',
                    Operator => 'CONTAINS',
                    Value    => $OrganisationName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field Organisation / Operator CONTAINS / Value substr(\$OrganisationName3,2,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Organisation',
                    Operator => 'CONTAINS',
                    Value    => substr($OrganisationName3,2,-2)
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => "Search: Field Organisation / Operator LIKE / Value \$OrganisationName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Organisation',
                    Operator => 'LIKE',
                    Value    => $OrganisationName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OrganisationNumber / Operator EQ / Value \$OrganisationNumber2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationNumber',
                    Operator => 'EQ',
                    Value    => $OrganisationNumber2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OrganisationNumber / Operator NE / Value \$OrganisationNumber2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationNumber',
                    Operator => 'NE',
                    Value    => $OrganisationNumber2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3,$TicketID4]
    },
    {
        Name     => "Search: Field OrganisationNumber / Operator IN / Value [\$OrganisationNumber1,\$OrganisationNumber3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationNumber',
                    Operator => 'IN',
                    Value    => [$OrganisationNumber1,$OrganisationNumber3]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID3]
    },
    {
        Name     => "Search: Field OrganisationNumber / Operator !IN / Value [\$OrganisationNumber1,\$OrganisationNumber3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationNumber',
                    Operator => '!IN',
                    Value    => [$OrganisationNumber1,$OrganisationNumber3]
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OrganisationNumber / Operator STARTSWITH / Value \$OrganisationNumber2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationNumber',
                    Operator => 'STARTSWITH',
                    Value    => $OrganisationNumber2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OrganisationNumber / Operator STARTSWITH / Value substr(\$OrganisationNumber2,0,4)",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationNumber',
                    Operator => 'STARTSWITH',
                    Value    => substr($OrganisationNumber2,0,4)
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => "Search: Field OrganisationNumber / Operator ENDSWITH / Value \$OrganisationNumber2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationNumber',
                    Operator => 'ENDSWITH',
                    Value    => $OrganisationNumber2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OrganisationNumber / Operator ENDSWITH / Value substr(\$OrganisationNumber2,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationNumber',
                    Operator => 'ENDSWITH',
                    Value    => substr($OrganisationNumber2,-5)
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OrganisationNumber / Operator CONTAINS / Value \$OrganisationNumber2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationNumber',
                    Operator => 'CONTAINS',
                    Value    => $OrganisationNumber2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OrganisationNumber / Operator CONTAINS / Value substr(\$OrganisationNumber3,2,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationNumber',
                    Operator => 'CONTAINS',
                    Value    => substr($OrganisationNumber3,2,-2)
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => "Search: Field OrganisationNumber / Operator LIKE / Value \$OrganisationNumber2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationNumber',
                    Operator => 'LIKE',
                    Value    => $OrganisationNumber2
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
my @IntegrationSortTests = (
    {
        Name     => 'Sort: Field OrganisationID',
        Sort     => [
            {
                Field => 'OrganisationID'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$TicketID1,$TicketID2,$TicketID3,$TicketID4] : [$TicketID4,$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => 'Sort: Field OrganisationID / Direction ascending',
        Sort     => [
            {
                Field     => 'OrganisationID',
                Direction => 'ascending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$TicketID1,$TicketID2,$TicketID3,$TicketID4] : [$TicketID4,$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => 'Sort: Field OrganisationID / Direction descending',
        Sort     => [
            {
                Field     => 'OrganisationID',
                Direction => 'descending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$TicketID4,$TicketID3,$TicketID2,$TicketID1] : [$TicketID3,$TicketID2,$TicketID1,$TicketID4]
    },
    {
        Name     => 'Sort: Field Organisation',
        Sort     => [
            {
                Field => 'Organisation'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$TicketID1,$TicketID2,$TicketID3,$TicketID4] : [$TicketID4,$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => 'Sort: Field Organisation / Direction ascending',
        Sort     => [
            {
                Field     => 'Organisation',
                Direction => 'ascending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$TicketID1,$TicketID2,$TicketID3,$TicketID4] : [$TicketID4,$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => 'Sort: Field Organisation / Direction descending',
        Sort     => [
            {
                Field     => 'Organisation',
                Direction => 'descending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$TicketID4,$TicketID3,$TicketID2,$TicketID1] : [$TicketID3,$TicketID2,$TicketID1,$TicketID4]
    },
    {
        Name     => 'Sort: Field OrganisationNumber',
        Sort     => [
            {
                Field => 'OrganisationNumber'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$TicketID1,$TicketID2,$TicketID3,$TicketID4] : [$TicketID4,$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => 'Sort: Field OrganisationNumber / Direction ascending',
        Sort     => [
            {
                Field     => 'OrganisationNumber',
                Direction => 'ascending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$TicketID1,$TicketID2,$TicketID3,$TicketID4] : [$TicketID4,$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => 'Sort: Field OrganisationNumber / Direction descending',
        Sort     => [
            {
                Field     => 'OrganisationNumber',
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
