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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Contact::OrganisationID';

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
        OrganisationID => {
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN'],
            ValueType      => 'NUMERIC'
        },
        OrganisationIDs => {
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN'],
            ValueType      => 'NUMERIC'
        },
        Organisation => {
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        OrganisationNumber => {
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        PrimaryOrganisationID => {
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN'],
            ValueType      => 'NUMERIC'
        },
        PrimaryOrganisation => {
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        PrimaryOrganisationNumber => {
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
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
            Field    => 'OrganisationID',
            Operator => 'LIKE',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Field undef',
        Search       => {
            Field    => undef,
            Operator => 'LIKE',
            Value    => 'test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Field invalid',
        Search       => {
            Field    => 'Test',
            Operator => 'LIKE',
            Value    => 'test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator undef',
        Search       => {
            Field    => 'OrganisationID',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'OrganisationID',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field OrganisationID / Operator EQ',
        Search       => {
            Field    => 'OrganisationID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation co ON co.contact_id = c.id'
            ],
            'Where' => [
                'co.org_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field OrganisationID / Operator NE',
        Search       => {
            Field    => 'OrganisationID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation co ON co.contact_id = c.id'
            ],
            'Where' => [
                'co.org_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field OrganisationID / Operator IN',
        Search       => {
            Field    => 'OrganisationID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation co ON co.contact_id = c.id'
            ],
            'Where' => [
                'co.org_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field OrganisationID / Operator !IN',
        Search       => {
            Field    => 'OrganisationID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation co ON co.contact_id = c.id'
            ],
            'Where' => [
                'co.org_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field OrganisationIDs / Operator EQ',
        Search       => {
            Field    => 'OrganisationIDs',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation co ON co.contact_id = c.id'
            ],
            'Where' => [
                'co.org_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field OrganisationIDs / Operator NE',
        Search       => {
            Field    => 'OrganisationIDs',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation co ON co.contact_id = c.id'
            ],
            'Where' => [
                'co.org_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field OrganisationIDs / Operator IN',
        Search       => {
            Field    => 'OrganisationIDs',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation co ON co.contact_id = c.id'
            ],
            'Where' => [
                'co.org_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field OrganisationIDs / Operator !IN',
        Search       => {
            Field    => 'OrganisationIDs',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation co ON co.contact_id = c.id'
            ],
            'Where' => [
                'co.org_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field PrimaryOrganisationID / Operator EQ',
        Search       => {
            Field    => 'PrimaryOrganisationID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation cpo ON cpo.contact_id = c.id',
                'AND cpo.is_primary = 1'
            ],
            'Where' => [
                'cpo.org_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field PrimaryOrganisationID / Operator NE',
        Search       => {
            Field    => 'PrimaryOrganisationID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation cpo ON cpo.contact_id = c.id',
                'AND cpo.is_primary = 1'
            ],
            'Where' => [
                'cpo.org_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field PrimaryOrganisationID / Operator IN',
        Search       => {
            Field    => 'PrimaryOrganisationID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation cpo ON cpo.contact_id = c.id',
                'AND cpo.is_primary = 1'
            ],
            'Where' => [
                'cpo.org_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field PrimaryOrganisationID / Operator !IN',
        Search       => {
            Field    => 'PrimaryOrganisationID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation cpo ON cpo.contact_id = c.id',
                'AND cpo.is_primary = 1'
            ],
            'Where' => [
                'cpo.org_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Organisation / Operator EQ',
        Search       => {
            Field    => 'Organisation',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation co ON co.contact_id = c.id',
                'INNER JOIN organisation o ON co.org_id = o.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(o.name) = \'test\'' : 'o.name = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Organisation / Operator NE',
        Search       => {
            Field    => 'Organisation',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation co ON co.contact_id = c.id',
                'INNER JOIN organisation o ON co.org_id = o.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(o.name) != \'test\'' : 'o.name != \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Organisation / Operator IN',
        Search       => {
            Field    => 'Organisation',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation co ON co.contact_id = c.id',
                'INNER JOIN organisation o ON co.org_id = o.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(o.name) IN (\'test\')' : 'o.name IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Organisation / Operator !IN',
        Search       => {
            Field    => 'Organisation',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation co ON co.contact_id = c.id',
                'INNER JOIN organisation o ON co.org_id = o.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(o.name) NOT IN (\'test\')' : 'o.name NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Organisation / Operator STARTSWITH',
        Search       => {
            Field    => 'Organisation',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation co ON co.contact_id = c.id',
                'INNER JOIN organisation o ON co.org_id = o.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(o.name) LIKE \'test%\'' : 'o.name LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Organisation / Operator ENDSWITH',
        Search       => {
            Field    => 'Organisation',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation co ON co.contact_id = c.id',
                'INNER JOIN organisation o ON co.org_id = o.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(o.name) LIKE \'%test\'' : 'o.name LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Organisation / Operator CONTAINS',
        Search       => {
            Field    => 'Organisation',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation co ON co.contact_id = c.id',
                'INNER JOIN organisation o ON co.org_id = o.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(o.name) LIKE \'%test%\'' : 'o.name LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Organisation / Operator LIKE',
        Search       => {
            Field    => 'Organisation',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation co ON co.contact_id = c.id',
                'INNER JOIN organisation o ON co.org_id = o.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(o.name) LIKE \'test\'' : 'o.name LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field OrganisationNumber / Operator EQ',
        Search       => {
            Field    => 'OrganisationNumber',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation co ON co.contact_id = c.id',
                'INNER JOIN organisation o ON co.org_id = o.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(o.number) = \'test\'' : 'o.number = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field OrganisationNumber / Operator NE',
        Search       => {
            Field    => 'OrganisationNumber',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation co ON co.contact_id = c.id',
                'INNER JOIN organisation o ON co.org_id = o.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(o.number) != \'test\'' : 'o.number != \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field OrganisationNumber / Operator IN',
        Search       => {
            Field    => 'OrganisationNumber',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation co ON co.contact_id = c.id',
                'INNER JOIN organisation o ON co.org_id = o.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(o.number) IN (\'test\')' : 'o.number IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field OrganisationNumber / Operator !IN',
        Search       => {
            Field    => 'OrganisationNumber',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation co ON co.contact_id = c.id',
                'INNER JOIN organisation o ON co.org_id = o.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(o.number) NOT IN (\'test\')' : 'o.number NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field OrganisationNumber / Operator STARTSWITH',
        Search       => {
            Field    => 'OrganisationNumber',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation co ON co.contact_id = c.id',
                'INNER JOIN organisation o ON co.org_id = o.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(o.number) LIKE \'test%\'' : 'o.number LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field OrganisationNumber / Operator ENDSWITH',
        Search       => {
            Field    => 'OrganisationNumber',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation co ON co.contact_id = c.id',
                'INNER JOIN organisation o ON co.org_id = o.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(o.number) LIKE \'%test\'' : 'o.number LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field OrganisationNumber / Operator CONTAINS',
        Search       => {
            Field    => 'OrganisationNumber',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation co ON co.contact_id = c.id',
                'INNER JOIN organisation o ON co.org_id = o.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(o.number) LIKE \'%test%\'' : 'o.number LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field OrganisationNumber / Operator LIKE',
        Search       => {
            Field    => 'OrganisationNumber',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation co ON co.contact_id = c.id',
                'INNER JOIN organisation o ON co.org_id = o.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(o.number) LIKE \'test\'' : 'o.number LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field PrimaryOrganisation / Operator EQ',
        Search       => {
            Field    => 'PrimaryOrganisation',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation cpo ON cpo.contact_id = c.id',
                'AND cpo.is_primary = 1',
                'INNER JOIN organisation po ON cpo.org_id = po.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(po.name) = \'test\'' : 'po.name = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field PrimaryOrganisation / Operator NE',
        Search       => {
            Field    => 'PrimaryOrganisation',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation cpo ON cpo.contact_id = c.id',
                'AND cpo.is_primary = 1',
                'INNER JOIN organisation po ON cpo.org_id = po.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(po.name) != \'test\'' : 'po.name != \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field PrimaryOrganisation / Operator IN',
        Search       => {
            Field    => 'PrimaryOrganisation',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation cpo ON cpo.contact_id = c.id',
                'AND cpo.is_primary = 1',
                'INNER JOIN organisation po ON cpo.org_id = po.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(po.name) IN (\'test\')' : 'po.name IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field PrimaryOrganisation / Operator !IN',
        Search       => {
            Field    => 'PrimaryOrganisation',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation cpo ON cpo.contact_id = c.id',
                'AND cpo.is_primary = 1',
                'INNER JOIN organisation po ON cpo.org_id = po.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(po.name) NOT IN (\'test\')' : 'po.name NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field PrimaryOrganisation / Operator STARTSWITH',
        Search       => {
            Field    => 'PrimaryOrganisation',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation cpo ON cpo.contact_id = c.id',
                'AND cpo.is_primary = 1',
                'INNER JOIN organisation po ON cpo.org_id = po.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(po.name) LIKE \'test%\'' : 'po.name LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field PrimaryOrganisation / Operator ENDSWITH',
        Search       => {
            Field    => 'PrimaryOrganisation',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation cpo ON cpo.contact_id = c.id',
                'AND cpo.is_primary = 1',
                'INNER JOIN organisation po ON cpo.org_id = po.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(po.name) LIKE \'%test\'' : 'po.name LIKE \'%test\''
            ]

        }
    },
    {
        Name         => 'Search: valid search / Field PrimaryOrganisation / Operator CONTAINS',
        Search       => {
            Field    => 'PrimaryOrganisation',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation cpo ON cpo.contact_id = c.id',
                'AND cpo.is_primary = 1',
                'INNER JOIN organisation po ON cpo.org_id = po.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(po.name) LIKE \'%test%\'' : 'po.name LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field PrimaryOrganisation / Operator LIKE',
        Search       => {
            Field    => 'PrimaryOrganisation',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation cpo ON cpo.contact_id = c.id',
                'AND cpo.is_primary = 1',
                'INNER JOIN organisation po ON cpo.org_id = po.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(po.name) LIKE \'test\'' : 'po.name LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field PrimaryOrganisationNumber / Operator EQ',
        Search       => {
            Field    => 'PrimaryOrganisationNumber',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation cpo ON cpo.contact_id = c.id',
                'AND cpo.is_primary = 1',
                'INNER JOIN organisation po ON cpo.org_id = po.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(po.number) = \'test\'' : 'po.number = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field PrimaryOrganisationNumber / Operator NE',
        Search       => {
            Field    => 'PrimaryOrganisationNumber',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation cpo ON cpo.contact_id = c.id',
                'AND cpo.is_primary = 1',
                'INNER JOIN organisation po ON cpo.org_id = po.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(po.number) != \'test\'' : 'po.number != \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field PrimaryOrganisationNumber / Operator IN',
        Search       => {
            Field    => 'PrimaryOrganisationNumber',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation cpo ON cpo.contact_id = c.id',
                'AND cpo.is_primary = 1',
                'INNER JOIN organisation po ON cpo.org_id = po.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(po.number) IN (\'test\')' : 'po.number IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field PrimaryOrganisationNumber / Operator !IN',
        Search       => {
            Field    => 'PrimaryOrganisationNumber',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation cpo ON cpo.contact_id = c.id',
                'AND cpo.is_primary = 1',
                'INNER JOIN organisation po ON cpo.org_id = po.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(po.number) NOT IN (\'test\')' : 'po.number NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field PrimaryOrganisationNumber / Operator STARTSWITH',
        Search       => {
            Field    => 'PrimaryOrganisationNumber',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation cpo ON cpo.contact_id = c.id',
                'AND cpo.is_primary = 1',
                'INNER JOIN organisation po ON cpo.org_id = po.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(po.number) LIKE \'test%\'' : 'po.number LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field PrimaryOrganisationNumber / Operator ENDSWITH',
        Search       => {
            Field    => 'PrimaryOrganisationNumber',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation cpo ON cpo.contact_id = c.id',
                'AND cpo.is_primary = 1',
                'INNER JOIN organisation po ON cpo.org_id = po.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(po.number) LIKE \'%test\'' : 'po.number LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field PrimaryOrganisationNumber / Operator CONTAINS',
        Search       => {
            Field    => 'PrimaryOrganisationNumber',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation cpo ON cpo.contact_id = c.id',
                'AND cpo.is_primary = 1',
                'INNER JOIN organisation po ON cpo.org_id = po.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(po.number) LIKE \'%test%\'' : 'po.number LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field PrimaryOrganisationNumber / Operator LIKE',
        Search       => {
            Field    => 'PrimaryOrganisationNumber',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN contact_organisation cpo ON cpo.contact_id = c.id',
                'AND cpo.is_primary = 1',
                'INNER JOIN organisation po ON cpo.org_id = po.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(po.number) LIKE \'test\'' : 'po.number LIKE \'test\''
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
            'Join' => [
                'LEFT JOIN contact_organisation co ON co.contact_id = c.id'
            ],
            'OrderBy' => [
                'co.org_id'
            ],
            'Select' => [
                'co.org_id'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "OrganisationIDs"',
        Attribute => 'OrganisationIDs',
        Expected  => {
            'Join' => [
                'LEFT JOIN contact_organisation co ON co.contact_id = c.id'
            ],
            'OrderBy' => [
                'co.org_id'
            ],
            'Select' => [
                'co.org_id'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Organisation"',
        Attribute => 'Organisation',
        Expected  => {
            'Join' => [
                'LEFT JOIN contact_organisation co ON co.contact_id = c.id',
                'INNER JOIN organisation o ON co.org_id = o.id'
            ],
            'OrderBy' => [
                'o.name'
            ],
            'Select' => [
                'o.name'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "OrganisationNumber"',
        Attribute => 'OrganisationNumber',
        Expected  => {
            'Join' => [
                'LEFT JOIN contact_organisation co ON co.contact_id = c.id',
                'INNER JOIN organisation o ON co.org_id = o.id'
            ],
            'OrderBy' => [
                'o.number'
            ],
            'Select' => [
                'o.number'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "PrimaryOrganisationID"',
        Attribute => 'PrimaryOrganisationID',
        Expected  => {
            'Join' => [
                'LEFT JOIN contact_organisation cpo ON cpo.contact_id = c.id',
                'AND cpo.is_primary = 1'
            ],
            'OrderBy' => [
                'cpo.org_id'
            ],
            'Select' => [
                'cpo.org_id'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "PrimaryOrganisation"',
        Attribute => 'PrimaryOrganisation',
        Expected  => {
           'Join' => [
                'LEFT JOIN contact_organisation cpo ON cpo.contact_id = c.id',
                'AND cpo.is_primary = 1',
                'INNER JOIN organisation po ON cpo.org_id = po.id'
            ],
            'OrderBy' => [
                'po.name'
            ],
            'Select' => [
                'po.name'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "PrimaryOrganisationNumber"',
        Attribute => 'PrimaryOrganisationNumber',
        Expected  => {
            'Join' => [
                'LEFT JOIN contact_organisation cpo ON cpo.contact_id = c.id',
                'AND cpo.is_primary = 1',
                'INNER JOIN organisation po ON cpo.org_id = po.id'
            ],
            'OrderBy' => [
                'po.number'
            ],
            'Select' => [
                'po.number'
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

## prepare test organisation ##
my @OrgaData = (
    {
        Number => '10203040',
        Name   => 'UT Unit Test',
    },
    {
        Number => '10204050',
        Name   => 'UT United Towns',
    },
    {
        Number => '20305090',
        Name   => 'Service Software',
    }
);

# first organisation
my $OrganisationID1 = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    %{$OrgaData[0]},
    UserID => 1,
);
$Self->True(
    $OrganisationID1,
    'Created first organisation'
);
# second organisation
my $OrganisationID2 = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    %{$OrgaData[1]},
    UserID => 1
);
$Self->True(
    $OrganisationID2,
    'Created second organisation'
);
# third organisation
my $OrganisationID3 = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    %{$OrgaData[2]},
    UserID => 1
);
$Self->True(
    $OrganisationID3,
    'Created third organisation'
);

## prepare test contacts ##
# first contact
my $ContactID1 = $Kernel::OM->Get('Contact')->ContactAdd(
    Firstname             => $Helper->GetRandomID(),
    Lastname              => $Helper->GetRandomID(),
    PrimaryOrganisationID => $OrganisationID1,
    OrganisationIDs       => [
        $OrganisationID1,
        $OrganisationID3
    ],
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $ContactID1,
    'Created first contact'
);
# second contact
my $ContactID2 = $Kernel::OM->Get('Contact')->ContactAdd(
    Firstname             => $Helper->GetRandomID(),
    Lastname              => $Helper->GetRandomID(),
    PrimaryOrganisationID => $OrganisationID2,
    OrganisationIDs       => [
        $OrganisationID2,
        $OrganisationID1
    ],
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $ContactID2,
    'Created second contact'
);
# third contact
my $ContactID3 = $Kernel::OM->Get('Contact')->ContactAdd(
    Firstname             => $Helper->GetRandomID(),
    Lastname              => $Helper->GetRandomID(),
    OrganisationIDs       => [
        $OrganisationID3
    ],
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $ContactID3,
    'Created third contact'
);

# discard object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => [
        'Organisation',
        'Contact'
    ],
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
        Expected => [$ContactID2]
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
        Expected => ['1',$ContactID1,$ContactID2,$ContactID3]
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
        Expected => [$ContactID1,$ContactID2,$ContactID3]
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
        Expected => ['1',$ContactID2]
    },
    {
        Name     => "Search: Field OrganisationIDs / Operator EQ / Value \$OrganisationID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationIDs',
                    Operator => 'EQ',
                    Value    => $OrganisationID2
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field OrganisationIDs / Operator NE / Value \$OrganisationID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationIDs',
                    Operator => 'NE',
                    Value    => $OrganisationID2
                }
            ]
        },
        Expected => ['1',$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => "Search: Field OrganisationIDs / Operator IN / Value [\$OrganisationID1,\$OrganisationID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationIDs',
                    Operator => 'IN',
                    Value    => [$OrganisationID1,$OrganisationID3]
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => "Search: Field OrganisationIDs / Operator !IN / Value [\$OrganisationID1,\$OrganisationID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationIDs',
                    Operator => '!IN',
                    Value    => [$OrganisationID1,$OrganisationID3]
                }
            ]
        },
        Expected => ['1',$ContactID2]
    },
    {
        Name     => "Search: Field PrimaryOrganisationID / Operator EQ / Value \$OrganisationID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'PrimaryOrganisationID',
                    Operator => 'EQ',
                    Value    => $OrganisationID2
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field PrimaryOrganisationID / Operator NE / Value \$OrganisationID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'PrimaryOrganisationID',
                    Operator => 'NE',
                    Value    => $OrganisationID2
                }
            ]
        },
        Expected => ['1',$ContactID1,$ContactID3]
    },
    {
        Name     => "Search: Field PrimaryOrganisationID / Operator IN / Value [\$OrganisationID1,\$OrganisationID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'PrimaryOrganisationID',
                    Operator => 'IN',
                    Value    => [$OrganisationID1,$OrganisationID3]
                }
            ]
        },
        Expected => [$ContactID1,$ContactID3]
    },
    {
        Name     => "Search: Field PrimaryOrganisationID / Operator !IN / Value [\$OrganisationID1,\$OrganisationID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'PrimaryOrganisationID',
                    Operator => '!IN',
                    Value    => [$OrganisationID1,$OrganisationID3]
                }
            ]
        },
        Expected => ['1',$ContactID2]
    },
    {
        Name     => "Search: Field Organisation / Operator EQ / Value \$OrgaData[0]->{Name}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Organisation',
                    Operator => 'EQ',
                    Value    => $OrgaData[0]->{Name}
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2]
    },
    {
        Name     => "Search: Field Organisation / Operator NE / Value \$OrgaData[0]->{Name}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Organisation',
                    Operator => 'NE',
                    Value    => $OrgaData[0]->{Name}
                }
            ]
        },
        Expected => ['1',$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => "Search: Field Organisation / Operator IN / Value \$OrgaData[0]->{Name}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Organisation',
                    Operator => 'IN',
                    Value    => $OrgaData[0]->{Name}
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2]
    },
    {
        Name     => "Search: Field Organisation / Operator !IN / Value \$OrgaData[0]->{Name}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Organisation',
                    Operator => '!IN',
                    Value    => $OrgaData[0]->{Name}
                }
            ]
        },
        Expected => ['1',$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => "Search: Field Organisation / Operator STARTSWITH / Value \$OrgaData[2]->{Name}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Organisation',
                    Operator => 'STARTSWITH',
                    Value    => $OrgaData[2]->{Name}
                }
            ]
        },
        Expected => [$ContactID1,$ContactID3]
    },
    {
        Name     => "Search: Field Organisation / Operator STARTSWITH / Value substr(\$OrgaData[2]->{Name},0,5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Organisation',
                    Operator => 'STARTSWITH',
                    Value    => substr($OrgaData[2]->{Name},0,5)
                }
            ]
        },
        Expected => [$ContactID1,$ContactID3]
    },
    {
        Name     => "Search: Field Organisation / Operator ENDSWITH / Value \$OrgaData[2]->{Name}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Organisation',
                    Operator => 'ENDSWITH',
                    Value    => $OrgaData[2]->{Name}
                }
            ]
        },
        Expected => [$ContactID1,$ContactID3]
    },
    {
        Name     => "Search: Field Organisation / Operator ENDSWITH / Value substr(\$OrgaData[2]->{Name},-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Organisation',
                    Operator => 'ENDSWITH',
                    Value    => substr($OrgaData[2]->{Name},-5)
                }
            ]
        },
        Expected => [$ContactID1,$ContactID3]
    },
    {
        Name     => "Search: Field Organisation / Operator CONTAINS / Value \$OrgaData[0]->{Name}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Organisation',
                    Operator => 'CONTAINS',
                    Value    => $OrgaData[0]->{Name}
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2]
    },
    {
        Name     => "Search: Field Organisation / Operator CONTAINS / Value substr(\$OrgaData[0]->{Name},5,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Organisation',
                    Operator => 'CONTAINS',
                    Value    => substr($OrgaData[0]->{Name},5,-5)
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2]
    },
    {
        Name     => "Search: Field Organisation / Operator LIKE / Value \$OrgaData[0]->{Name}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Organisation',
                    Operator => 'LIKE',
                    Value    => $OrgaData[0]->{Name}
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2]
    },
    {
        Name     => "Search: Field Organisation / Operator LIKE / Value *substr(\$OrgaData[0]->{Name},5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Organisation',
                    Operator => 'LIKE',
                    Value    => q{*} . substr($OrgaData[0]->{Name},5)
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2]
    },
    {
        Name     => "Search: Field OrganisationNumber / Operator EQ / Value \$OrgaData[0]->{Number}",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationNumber',
                    Operator => 'EQ',
                    Value    => $OrgaData[0]->{Number}
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2]
    },
    {
        Name     => "Search: Field OrganisationNumber / Operator NE / Value \$OrgaData[0]->{Number}",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationNumber',
                    Operator => 'NE',
                    Value    => $OrgaData[0]->{Number}
                }
            ]
        },
        Expected => ['1',$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => "Search: Field OrganisationNumber / Operator IN / Value \$OrgaData[1]->{Number}",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationNumber',
                    Operator => 'IN',
                    Value    => $OrgaData[1]->{Number}
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field OrganisationNumber / Operator !IN / Value \$OrgaData[1]->{Number}",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationNumber',
                    Operator => '!IN',
                    Value    => $OrgaData[1]->{Number}
                }
            ]
        },
        Expected => ['1',$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => "Search: Field OrganisationNumber / Operator STARTSWITH / Value \$OrgaData[2]->{Number}",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationNumber',
                    Operator => 'STARTSWITH',
                    Value    => $OrgaData[2]->{Number}
                }
            ]
        },
        Expected => [$ContactID1,$ContactID3]
    },
    {
        Name     => "Search: Field OrganisationNumber / Operator STARTSWITH / Value substr(\$OrgaData[2]->{Number},0,2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationNumber',
                    Operator => 'STARTSWITH',
                    Value    => substr($OrgaData[2]->{Number},0,2)
                }
            ]
        },
        Expected => [$ContactID1,$ContactID3]
    },
    {
        Name     => "Search: Field OrganisationNumber / Operator ENDSWITH / Value \$OrgaData[2]->{Number}",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationNumber',
                    Operator => 'ENDSWITH',
                    Value    => $OrgaData[2]->{Number}
                }
            ]
        },
        Expected => [$ContactID1,$ContactID3]
    },
    {
        Name     => "Search: Field OrganisationNumber / Operator ENDSWITH / Value substr(\$OrgaData[2]->{Number},-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationNumber',
                    Operator => 'ENDSWITH',
                    Value    => substr($OrgaData[2]->{Number},-2)
                }
            ]
        },
        Expected => [$ContactID1,$ContactID3]
    },
    {
        Name     => "Search: Field OrganisationNumber / Operator CONTAINS / Value \$OrgaData[0]->{Number}",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationNumber',
                    Operator => 'CONTAINS',
                    Value    => $OrgaData[0]->{Number}
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2]
    },
    {
        Name     => "Search: Field OrganisationNumber / Operator CONTAINS / Value substr(\$OrgaData[0]->{Number},2,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationNumber',
                    Operator => 'CONTAINS',
                    Value    => substr($OrgaData[0]->{Number},2,-2)
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => "Search: Field OrganisationNumber / Operator LIKE / Value \$OrgaData[0]->{Number}",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationNumber',
                    Operator => 'LIKE',
                    Value    => $OrgaData[0]->{Number}
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2]
    },
    {
        Name     => "Search: Field PrimaryOrganisation / Operator EQ / Value \$OrgaData[0]->{Name}",
        Search   => {
            'AND' => [
                {
                    Field    => 'PrimaryOrganisation',
                    Operator => 'EQ',
                    Value    => $OrgaData[0]->{Name}
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field PrimaryOrganisation / Operator NE / Value \$OrgaData[0]->{Name}",
        Search   => {
            'AND' => [
                {
                    Field    => 'PrimaryOrganisation',
                    Operator => 'NE',
                    Value    => $OrgaData[0]->{Name}
                }
            ]
        },
        Expected => ['1',$ContactID2,$ContactID3]
    },
    {
        Name     => "Search: Field PrimaryOrganisation / Operator IN / Value \$OrgaData[1]->{Name}",
        Search   => {
            'AND' => [
                {
                    Field    => 'PrimaryOrganisation',
                    Operator => 'IN',
                    Value    => $OrgaData[1]->{Name}
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field PrimaryOrganisation / Operator !IN / Value \$OrgaData[1]->{Name}",
        Search   => {
            'AND' => [
                {
                    Field    => 'PrimaryOrganisation',
                    Operator => '!IN',
                    Value    => $OrgaData[1]->{Name}
                }
            ]
        },
        Expected => ['1',$ContactID1,$ContactID3]
    },
    {
        Name     => "Search: Field PrimaryOrganisation / Operator STARTSWITH / Value \$OrgaData[2]->{Name}",
        Search   => {
            'AND' => [
                {
                    Field    => 'PrimaryOrganisation',
                    Operator => 'STARTSWITH',
                    Value    => $OrgaData[2]->{Name}
                }
            ]
        },
        Expected => [$ContactID3]
    },
    {
        Name     => "Search: Field PrimaryOrganisation / Operator STARTSWITH / Value substr(\$OrgaData[2]->{Name},0,2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'PrimaryOrganisation',
                    Operator => 'STARTSWITH',
                    Value    => substr($OrgaData[2]->{Name},0,2)
                }
            ]
        },
        Expected => [$ContactID3]
    },
    {
        Name     => "Search: Field PrimaryOrganisation / Operator ENDSWITH / Value \$OrgaData[2]->{Name}",
        Search   => {
            'AND' => [
                {
                    Field    => 'PrimaryOrganisation',
                    Operator => 'ENDSWITH',
                    Value    => $OrgaData[2]->{Name}
                }
            ]
        },
        Expected => [$ContactID3]
    },
    {
        Name     => "Search: Field PrimaryOrganisation / Operator ENDSWITH / Value substr(\$OrgaData[2]->{Name},-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'PrimaryOrganisation',
                    Operator => 'ENDSWITH',
                    Value    => substr($OrgaData[2]->{Name},-5)
                }
            ]
        },
        Expected => [$ContactID3]
    },
    {
        Name     => "Search: Field PrimaryOrganisation / Operator CONTAINS / Value \$OrgaData[0]->{Name}",
        Search   => {
            'AND' => [
                {
                    Field    => 'PrimaryOrganisation',
                    Operator => 'CONTAINS',
                    Value    => $OrgaData[0]->{Name}
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field PrimaryOrganisation / Operator CONTAINS / Value substr(\$OrgaData[0]->{Name},2,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'PrimaryOrganisation',
                    Operator => 'CONTAINS',
                    Value    => substr($OrgaData[0]->{Name},2,-2)
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field PrimaryOrganisation / Operator LIKE / Value \$OrgaData[0]->{Name}",
        Search   => {
            'AND' => [
                {
                    Field    => 'PrimaryOrganisation',
                    Operator => 'LIKE',
                    Value    => $OrgaData[0]->{Name}
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field PrimaryOrganisation / Operator LIKE / Value *substr(\$OrgaData[0]->{Name},2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'PrimaryOrganisation',
                    Operator => 'LIKE',
                    Value    => q{*} . substr($OrgaData[0]->{Name},2)
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field OrganisationNumber / Operator LIKE / Value *substr(\$OrgaData[0]->{Number},2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationNumber',
                    Operator => 'LIKE',
                    Value    => q{*} . substr($OrgaData[0]->{Number},2)
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2]
    },
    {
        Name     => "Search: Field PrimaryOrganisationNumber / Operator EQ / Value \$OrgaData[0]->{Number}",
        Search   => {
            'AND' => [
                {
                    Field    => 'PrimaryOrganisationNumber',
                    Operator => 'EQ',
                    Value    => $OrgaData[0]->{Number}
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field PrimaryOrganisationNumber / Operator NE / Value \$OrgaData[0]->{Number}",
        Search   => {
            'AND' => [
                {
                    Field    => 'PrimaryOrganisationNumber',
                    Operator => 'NE',
                    Value    => $OrgaData[0]->{Number}
                }
            ]
        },
        Expected => ['1',$ContactID2,$ContactID3]
    },
    {
        Name     => "Search: Field PrimaryOrganisationNumber / Operator IN / Value \$OrgaData[0]->{Number}",
        Search   => {
            'AND' => [
                {
                    Field    => 'PrimaryOrganisationNumber',
                    Operator => 'IN',
                    Value    => $OrgaData[0]->{Number}
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field PrimaryOrganisationNumber / Operator !IN / Value \$OrgaData[0]->{Number}",
        Search   => {
            'AND' => [
                {
                    Field    => 'PrimaryOrganisationNumber',
                    Operator => '!IN',
                    Value    => $OrgaData[0]->{Number}
                }
            ]
        },
        Expected => ['1',$ContactID2,$ContactID3]
    },
    {
        Name     => "Search: Field PrimaryOrganisationNumber / Operator STARTSWITH / Value \$OrgaData[2]->{Number}",
        Search   => {
            'AND' => [
                {
                    Field    => 'PrimaryOrganisationNumber',
                    Operator => 'STARTSWITH',
                    Value    => $OrgaData[2]->{Number}
                }
            ]
        },
        Expected => [$ContactID3]
    },
    {
        Name     => "Search: Field PrimaryOrganisationNumber / Operator STARTSWITH / Value substr(\$OrgaData[2]->{Number},0,2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'PrimaryOrganisationNumber',
                    Operator => 'STARTSWITH',
                    Value    => substr($OrgaData[2]->{Number},0,2)
                }
            ]
        },
        Expected => [$ContactID3]
    },
    {
        Name     => "Search: Field PrimaryOrganisationNumber / Operator ENDSWITH / Value \$OrgaData[2]->{Number}",
        Search   => {
            'AND' => [
                {
                    Field    => 'PrimaryOrganisationNumber',
                    Operator => 'ENDSWITH',
                    Value    => $OrgaData[2]->{Number}
                }
            ]
        },
        Expected => [$ContactID3]
    },
    {
        Name     => "Search: Field PrimaryOrganisationNumber / Operator ENDSWITH / Value substr(\$OrgaData[2]->{Number},-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'PrimaryOrganisationNumber',
                    Operator => 'ENDSWITH',
                    Value    => substr($OrgaData[2]->{Number},-2)
                }
            ]
        },
        Expected => [$ContactID3]
    },
    {
        Name     => "Search: Field PrimaryOrganisationNumber / Operator CONTAINS / Value \$OrgaData[0]->{Number}",
        Search   => {
            'AND' => [
                {
                    Field    => 'PrimaryOrganisationNumber',
                    Operator => 'CONTAINS',
                    Value    => $OrgaData[0]->{Number}
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field PrimaryOrganisationNumber / Operator CONTAINS / Value substr(\$OrgaData[0]->{Number},2,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'PrimaryOrganisationNumber',
                    Operator => 'CONTAINS',
                    Value    => substr($OrgaData[0]->{Number},2,-2)
                }
            ]
        },
        Expected => [$ContactID1,$ContactID3]
    },
    {
        Name     => "Search: Field PrimaryOrganisationNumber / Operator LIKE / Value \$OrgaData[0]->{Number}",
        Search   => {
            'AND' => [
                {
                    Field    => 'PrimaryOrganisationNumber',
                    Operator => 'LIKE',
                    Value    => $OrgaData[0]->{Number}
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field PrimaryOrganisationNumber / Operator LIKE / Value *substr(\$OrgaData[0]->{Number},2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'PrimaryOrganisationNumber',
                    Operator => 'LIKE',
                    Value    => q{*} . substr($OrgaData[0]->{Number},2)
                }
            ]
        },
        Expected => [$ContactID1]
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
        Name     => 'Sort: Field OrganisationID',
        Sort     => [
            {
                Field => 'OrganisationID'
            }
        ],
        Expected => ['1',$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => 'Sort: Field OrganisationID / Direction ascending',
        Sort     => [
            {
                Field     => 'OrganisationID',
                Direction => 'ascending'
            }
        ],
        Expected => ['1',$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => 'Sort: Field OrganisationID / Direction descending',
        Sort     => [
            {
                Field     => 'OrganisationID',
                Direction => 'descending'
            }
        ],
        Expected => [$ContactID1,$ContactID3,$ContactID2,'1']
    },
    {
        Name     => 'Sort: Field OrganisationIDs',
        Sort     => [
            {
                Field => 'OrganisationIDs'
            }
        ],
        Expected => ['1',$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => 'Sort: Field OrganisationIDs / Direction ascending',
        Sort     => [
            {
                Field     => 'OrganisationIDs',
                Direction => 'ascending'
            }
        ],
        Expected => ['1',$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => 'Sort: Field OrganisationIDs / Direction descending',
        Sort     => [
            {
                Field     => 'OrganisationIDs',
                Direction => 'descending'
            }
        ],
        Expected => [$ContactID1,$ContactID3,$ContactID2,'1']
    },
    {
        Name     => 'Sort: Field Organisation',
        Sort     => [
            {
                Field => 'Organisation'
            }
        ],
        Expected => ['1',$ContactID1,$ContactID3,$ContactID2]
    },
    {
        Name     => 'Sort: Field Organisation / Direction ascending',
        Sort     => [
            {
                Field     => 'Organisation',
                Direction => 'ascending'
            }
        ],
        Expected => ['1',$ContactID1,$ContactID3,$ContactID2]
    },
    {
        Name     => 'Sort: Field Organisation / Direction descending',
        Sort     => [
            {
                Field     => 'Organisation',
                Direction => 'descending'
            }
        ],
        Expected => [$ContactID2,$ContactID1,$ContactID3,'1']
    },
    {
        Name     => 'Sort: Field OrganisationNumber',
        Sort     => [
            {
                Field => 'OrganisationNumber'
            }
        ],
        Expected => [$ContactID1,$ContactID2,$ContactID3,'1']
    },
    {
        Name     => 'Sort: Field OrganisationNumber / Direction ascending',
        Sort     => [
            {
                Field     => 'OrganisationNumber',
                Direction => 'ascending'
            }
        ],
        Expected => [$ContactID1,$ContactID2,$ContactID3,'1']
    },
    {
        Name     => 'Sort: Field OrganisationNumber / Direction descending',
        Sort     => [
            {
                Field     => 'OrganisationNumber',
                Direction => 'descending'
            }
        ],
        Expected => ['1',$ContactID1,$ContactID3,$ContactID2]
    },
    {
        Name     => 'Sort: Field PrimaryOrganisationID',
        Sort     => [
            {
                Field => 'PrimaryOrganisationID'
            }
        ],
        Expected => ['1',$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => 'Sort: Field PrimaryOrganisationID / Direction ascending',
        Sort     => [
            {
                Field     => 'PrimaryOrganisationID',
                Direction => 'ascending'
            }
        ],
        Expected => ['1',$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => 'Sort: Field PrimaryOrganisationID / Direction descending',
        Sort     => [
            {
                Field     => 'PrimaryOrganisationID',
                Direction => 'descending'
            }
        ],
        Expected => [$ContactID3,$ContactID2,$ContactID1,'1']
    },
    {
        Name     => 'Sort: Field PrimaryOrganisation',
        Sort     => [
            {
                Field => 'PrimaryOrganisation'
            }
        ],
        Expected => ['1',$ContactID3,$ContactID1,$ContactID2]
    },
    {
        Name     => 'Sort: Field PrimaryOrganisation / Direction ascending',
        Sort     => [
            {
                Field     => 'PrimaryOrganisation',
                Direction => 'ascending'
            }
        ],
        Expected => ['1',$ContactID3,$ContactID1,$ContactID2]
    },
    {
        Name     => 'Sort: Field PrimaryOrganisation / Direction descending',
        Sort     => [
            {
                Field     => 'PrimaryOrganisation',
                Direction => 'descending'
            }
        ],
        Expected => [$ContactID2,$ContactID1,$ContactID3,'1']
    },
    {
        Name     => 'Sort: Field PrimaryOrganisationNumber',
        Sort     => [
            {
                Field => 'PrimaryOrganisationNumber'
            }
        ],
        Expected => [$ContactID1,$ContactID2,$ContactID3,'1']
    },
    {
        Name     => 'Sort: Field PrimaryOrganisationNumber / Direction ascending',
        Sort     => [
            {
                Field     => 'PrimaryOrganisationNumber',
                Direction => 'ascending'
            }
        ],
        Expected => [$ContactID1,$ContactID2,$ContactID3,'1']
    },
    {
        Name     => 'Sort: Field PrimaryOrganisationNumber / Direction descending',
        Sort     => [
            {
                Field     => 'PrimaryOrganisationNumber',
                Direction => 'descending'
            }
        ],
        Expected => ['1',$ContactID3,$ContactID2,$ContactID1]
    },
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
