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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Contact::Email';

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
        Emails => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN'],
        },
        Email => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN'],
        },
        Email1 => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN'],
        },
        Email2 => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN'],
        },
        Email3 => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN'],
        },
        Email4 => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN'],
        },
        Email5 => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN'],
        },
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
            Field    => 'Emails',
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
            Field    => 'Emails',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'Emails',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field Emails / Operator EQ',
        Search       => {
            Field    => 'Emails',
            Operator => 'EQ',
            Value    => 'unit.test@unittest.com'
        },
        Expected     => {
            'Search' => {
                'OR' => [
                    {
                        'Field'    => 'Email',
                        'Operator' => 'EQ',
                        'Value'    => 'unit.test@unittest.com'
                    },
                    {
                        'Field'    => 'Email1',
                        'Operator' => 'EQ',
                        'Value'    => 'unit.test@unittest.com'
                    },
                    {
                        'Field'    => 'Email2',
                        'Operator' => 'EQ',
                        'Value'    => 'unit.test@unittest.com'
                    },
                    {
                        'Field'    => 'Email3',
                        'Operator' => 'EQ',
                        'Value'    => 'unit.test@unittest.com'
                    },
                    {
                        'Field'    => 'Email4',
                        'Operator' => 'EQ',
                        'Value'    => 'unit.test@unittest.com'
                    },
                    {
                        'Field'    => 'Email5',
                        'Operator' => 'EQ',
                        'Value'    => 'unit.test@unittest.com'
                    }
                ]
            }
        }
    },
    {
        Name         => 'Search: valid search / Field Emails / Operator NE',
        Search       => {
            Field    => 'Emails',
            Operator => 'NE',
            Value    => 'unit.test@unittest.com'
        },
        Expected     => {
            'Search' => {
                'OR' => [
                    {
                        'Field'    => 'Email',
                        'Operator' => 'NE',
                        'Value'    => 'unit.test@unittest.com'
                    },
                    {
                        'Field'    => 'Email1',
                        'Operator' => 'NE',
                        'Value'    => 'unit.test@unittest.com'
                    },
                    {
                        'Field'    => 'Email2',
                        'Operator' => 'NE',
                        'Value'    => 'unit.test@unittest.com'
                    },
                    {
                        'Field'    => 'Email3',
                        'Operator' => 'NE',
                        'Value'    => 'unit.test@unittest.com'
                    },
                    {
                        'Field'    => 'Email4',
                        'Operator' => 'NE',
                        'Value'    => 'unit.test@unittest.com'
                    },
                    {
                        'Field'    => 'Email5',
                        'Operator' => 'NE',
                        'Value'    => 'unit.test@unittest.com'
                    }
                ]
            }
        }
    },
    {
        Name         => 'Search: valid search / Field Emails / Operator IN',
        Search       => {
            Field    => 'Emails',
            Operator => 'IN',
            Value    => ['unit.test@unittest.com']
        },
        Expected     => {
            'Search' => {
                'OR' => [
                    {
                        'Field'    => 'Email',
                        'Operator' => 'IN',
                        'Value'    => ['unit.test@unittest.com']
                    },
                    {
                        'Field'    => 'Email1',
                        'Operator' => 'IN',
                        'Value'    => ['unit.test@unittest.com']
                    },
                    {
                        'Field'    => 'Email2',
                        'Operator' => 'IN',
                        'Value'    => ['unit.test@unittest.com']
                    },
                    {
                        'Field'    => 'Email3',
                        'Operator' => 'IN',
                        'Value'    => ['unit.test@unittest.com']
                    },
                    {
                        'Field'    => 'Email4',
                        'Operator' => 'IN',
                        'Value'    => ['unit.test@unittest.com']
                    },
                    {
                        'Field'    => 'Email5',
                        'Operator' => 'IN',
                        'Value'    => ['unit.test@unittest.com']
                    }
                ]
            }
        }
    },
    {
        Name         => 'Search: valid search / Field Emails / Operator !IN',
        Search       => {
            Field    => 'Emails',
            Operator => '!IN',
            Value    => ['unit.test@unittest.com']
        },
        Expected     => {
            'Search' => {
                'OR' => [
                    {
                        'Field'    => 'Email',
                        'Operator' => '!IN',
                        'Value'    => ['unit.test@unittest.com']
                    },
                    {
                        'Field'    => 'Email1',
                        'Operator' => '!IN',
                        'Value'    => ['unit.test@unittest.com']
                    },
                    {
                        'Field'    => 'Email2',
                        'Operator' => '!IN',
                        'Value'    => ['unit.test@unittest.com']
                    },
                    {
                        'Field'    => 'Email3',
                        'Operator' => '!IN',
                        'Value'    => ['unit.test@unittest.com']
                    },
                    {
                        'Field'    => 'Email4',
                        'Operator' => '!IN',
                        'Value'    => ['unit.test@unittest.com']
                    },
                    {
                        'Field'    => 'Email5',
                        'Operator' => '!IN',
                        'Value'    => ['unit.test@unittest.com']
                    }
                ]
            }
        }
    },
    {
        Name         => 'Search: valid search / Field Emails / Operator STARTSWITH',
        Search       => {
            Field    => 'Emails',
            Operator => 'STARTSWITH',
            Value    => 'unit.test'
        },
        Expected     => {
            'Search' => {
                'OR' => [
                    {
                        'Field'    => 'Email',
                        'Operator' => 'STARTSWITH',
                        'Value'    => 'unit.test'
                    },
                    {
                        'Field'    => 'Email1',
                        'Operator' => 'STARTSWITH',
                        'Value'    => 'unit.test'
                    },
                    {
                        'Field'    => 'Email2',
                        'Operator' => 'STARTSWITH',
                        'Value'    => 'unit.test'
                    },
                    {
                        'Field'    => 'Email3',
                        'Operator' => 'STARTSWITH',
                        'Value'    => 'unit.test'
                    },
                    {
                        'Field'    => 'Email4',
                        'Operator' => 'STARTSWITH',
                        'Value'    => 'unit.test'
                    },
                    {
                        'Field'    => 'Email5',
                        'Operator' => 'STARTSWITH',
                        'Value'    => 'unit.test'
                    }
                ]
            }
        }
    },
    {
        Name         => 'Search: valid search / Field Emails / Operator ENDSWITH',
        Search       => {
            Field    => 'Emails',
            Operator => 'ENDSWITH',
            Value    => 'unittest.com'
        },
        Expected     => {
            'Search' => {
                'OR' => [
                    {
                        'Field'    => 'Email',
                        'Operator' => 'ENDSWITH',
                        'Value'    => 'unittest.com'
                    },
                    {
                        'Field'    => 'Email1',
                        'Operator' => 'ENDSWITH',
                        'Value'    => 'unittest.com'
                    },
                    {
                        'Field'    => 'Email2',
                        'Operator' => 'ENDSWITH',
                        'Value'    => 'unittest.com'
                    },
                    {
                        'Field'    => 'Email3',
                        'Operator' => 'ENDSWITH',
                        'Value'    => 'unittest.com'
                    },
                    {
                        'Field'    => 'Email4',
                        'Operator' => 'ENDSWITH',
                        'Value'    => 'unittest.com'
                    },
                    {
                        'Field'    => 'Email5',
                        'Operator' => 'ENDSWITH',
                        'Value'    => 'unittest.com'
                    }
                ]
            }
        }
    },
    {
        Name         => 'Search: valid search / Field Emails / Operator CONTAINS',
        Search       => {
            Field    => 'Emails',
            Operator => 'CONTAINS',
            Value    => 'test@unit'
        },
        Expected     => {
            'Search' => {
                'OR' => [
                    {
                        'Field'    => 'Email',
                        'Operator' => 'CONTAINS',
                        'Value'    => 'test@unit'
                    },
                    {
                        'Field'    => 'Email1',
                        'Operator' => 'CONTAINS',
                        'Value'    => 'test@unit'
                    },
                    {
                        'Field'    => 'Email2',
                        'Operator' => 'CONTAINS',
                        'Value'    => 'test@unit'
                    },
                    {
                        'Field'    => 'Email3',
                        'Operator' => 'CONTAINS',
                        'Value'    => 'test@unit'
                    },
                    {
                        'Field'    => 'Email4',
                        'Operator' => 'CONTAINS',
                        'Value'    => 'test@unit'
                    },
                    {
                        'Field'    => 'Email5',
                        'Operator' => 'CONTAINS',
                        'Value'    => 'test@unit'
                    }
                ]
            }
        }
    },
    {
        Name         => 'Search: valid search / Field Emails / Operator LIKE',
        Search       => {
            Field    => 'Emails',
            Operator => 'LIKE',
            Value    => '*unit*'
        },
        Expected     => {
            'Search' => {
                'OR' => [
                    {
                        'Field'    => 'Email',
                        'Operator' => 'LIKE',
                        'Value'    => '*unit*'
                    },
                    {
                        'Field'    => 'Email1',
                        'Operator' => 'LIKE',
                        'Value'    => '*unit*'
                    },
                    {
                        'Field'    => 'Email2',
                        'Operator' => 'LIKE',
                        'Value'    => '*unit*'
                    },
                    {
                        'Field'    => 'Email3',
                        'Operator' => 'LIKE',
                        'Value'    => '*unit*'
                    },
                    {
                        'Field'    => 'Email4',
                        'Operator' => 'LIKE',
                        'Value'    => '*unit*'
                    },
                    {
                        'Field'    => 'Email5',
                        'Operator' => 'LIKE',
                        'Value'    => '*unit*'
                    }
                ]
            }
        }
    },
    {
        Name         => 'Search: valid search / Field Email / Operator EQ',
        Search       => {
            Field    => 'Email',
            Operator => 'EQ',
            Value    => 'unit.test@unittest.com'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email) = \'unit.test@unittest.com\'' : 'c.email = \'unit.test@unittest.com\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email / Operator NE',
        Search       => {
            Field    => 'Email',
            Operator => 'NE',
            Value    => 'unit.test@unittest.com'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(c.email) != \'unit.test@unittest.com\' OR c.email IS NULL)' : '(c.email != \'unit.test@unittest.com\' OR c.email IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email / Operator IN',
        Search       => {
            Field    => 'Email',
            Operator => 'IN',
            Value    => ['unit.test@unittest.com']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email) IN (\'unit.test@unittest.com\')' : 'c.email IN (\'unit.test@unittest.com\')'
            ]

        }
    },
    {
        Name         => 'Search: valid search / Field Email / Operator !IN',
        Search       => {
            Field    => 'Email',
            Operator => '!IN',
            Value    => ['unit.test@unittest.com']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email) NOT IN (\'unit.test@unittest.com\')' : 'c.email NOT IN (\'unit.test@unittest.com\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email / Operator STARTSWITH',
        Search       => {
            Field    => 'Email',
            Operator => 'STARTSWITH',
            Value    => 'unit.test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email) LIKE \'unit.test%\'' : 'c.email LIKE \'unit.test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email / Operator ENDSWITH',
        Search       => {
            Field    => 'Email',
            Operator => 'ENDSWITH',
            Value    => 'unittest.com'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email) LIKE \'%unittest.com\'' : 'c.email LIKE \'%unittest.com\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email / Operator CONTAINS',
        Search       => {
            Field    => 'Email',
            Operator => 'CONTAINS',
            Value    => 'test@unit'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email) LIKE \'%test@unit%\'' : 'c.email LIKE \'%test@unit%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email / Operator LIKE',
        Search       => {
            Field    => 'Email',
            Operator => 'LIKE',
            Value    => '*unit*'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email) LIKE \'%unit%\'' : 'c.email LIKE \'%unit%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email1 / Operator EQ',
        Search       => {
            Field    => 'Email1',
            Operator => 'EQ',
            Value    => 'unit.test@unittest.com'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email1) = \'unit.test@unittest.com\'' : 'c.email1 = \'unit.test@unittest.com\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email1 / Operator NE',
        Search       => {
            Field    => 'Email1',
            Operator => 'NE',
            Value    => 'unit.test@unittest.com'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(c.email1) != \'unit.test@unittest.com\' OR c.email1 IS NULL)' : '(c.email1 != \'unit.test@unittest.com\' OR c.email1 IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email1 / Operator IN',
        Search       => {
            Field    => 'Email1',
            Operator => 'IN',
            Value    => ['unit.test@unittest.com']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email1) IN (\'unit.test@unittest.com\')' : 'c.email1 IN (\'unit.test@unittest.com\')'
            ]

        }
    },
    {
        Name         => 'Search: valid search / Field Email1 / Operator !IN',
        Search       => {
            Field    => 'Email1',
            Operator => '!IN',
            Value    => ['unit.test@unittest.com']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email1) NOT IN (\'unit.test@unittest.com\')' : 'c.email1 NOT IN (\'unit.test@unittest.com\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email1 / Operator STARTSWITH',
        Search       => {
            Field    => 'Email1',
            Operator => 'STARTSWITH',
            Value    => 'unit.test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email1) LIKE \'unit.test%\'' : 'c.email1 LIKE \'unit.test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email1 / Operator ENDSWITH',
        Search       => {
            Field    => 'Email1',
            Operator => 'ENDSWITH',
            Value    => 'unittest.com'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email1) LIKE \'%unittest.com\'' : 'c.email1 LIKE \'%unittest.com\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email1 / Operator CONTAINS',
        Search       => {
            Field    => 'Email1',
            Operator => 'CONTAINS',
            Value    => 'test@unit'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email1) LIKE \'%test@unit%\'' : 'c.email1 LIKE \'%test@unit%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email1 / Operator LIKE',
        Search       => {
            Field    => 'Email1',
            Operator => 'LIKE',
            Value    => '*unit*'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email1) LIKE \'%unit%\'' : 'c.email1 LIKE \'%unit%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email2 / Operator EQ',
        Search       => {
            Field    => 'Email2',
            Operator => 'EQ',
            Value    => 'unit.test@unittest.com'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email2) = \'unit.test@unittest.com\'' : 'c.email2 = \'unit.test@unittest.com\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email2 / Operator NE',
        Search       => {
            Field    => 'Email2',
            Operator => 'NE',
            Value    => 'unit.test@unittest.com'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(c.email2) != \'unit.test@unittest.com\' OR c.email2 IS NULL)' : '(c.email2 != \'unit.test@unittest.com\' OR c.email2 IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email2 / Operator IN',
        Search       => {
            Field    => 'Email2',
            Operator => 'IN',
            Value    => ['unit.test@unittest.com']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email2) IN (\'unit.test@unittest.com\')' : 'c.email2 IN (\'unit.test@unittest.com\')'
            ]

        }
    },
    {
        Name         => 'Search: valid search / Field Email2 / Operator !IN',
        Search       => {
            Field    => 'Email2',
            Operator => '!IN',
            Value    => ['unit.test@unittest.com']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email2) NOT IN (\'unit.test@unittest.com\')' : 'c.email2 NOT IN (\'unit.test@unittest.com\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email2 / Operator STARTSWITH',
        Search       => {
            Field    => 'Email2',
            Operator => 'STARTSWITH',
            Value    => 'unit.test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email2) LIKE \'unit.test%\'' : 'c.email2 LIKE \'unit.test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email2 / Operator ENDSWITH',
        Search       => {
            Field    => 'Email2',
            Operator => 'ENDSWITH',
            Value    => 'unittest.com'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email2) LIKE \'%unittest.com\'' : 'c.email2 LIKE \'%unittest.com\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email2 / Operator CONTAINS',
        Search       => {
            Field    => 'Email2',
            Operator => 'CONTAINS',
            Value    => 'test@unit'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email2) LIKE \'%test@unit%\'' : 'c.email2 LIKE \'%test@unit%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email2 / Operator LIKE',
        Search       => {
            Field    => 'Email2',
            Operator => 'LIKE',
            Value    => '*unit*'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email2) LIKE \'%unit%\'' : 'c.email2 LIKE \'%unit%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email3 / Operator EQ',
        Search       => {
            Field    => 'Email3',
            Operator => 'EQ',
            Value    => 'unit.test@unittest.com'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email3) = \'unit.test@unittest.com\'' : 'c.email3 = \'unit.test@unittest.com\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email3 / Operator NE',
        Search       => {
            Field    => 'Email3',
            Operator => 'NE',
            Value    => 'unit.test@unittest.com'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(c.email3) != \'unit.test@unittest.com\' OR c.email3 IS NULL)' : '(c.email3 != \'unit.test@unittest.com\' OR c.email3 IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email3 / Operator IN',
        Search       => {
            Field    => 'Email3',
            Operator => 'IN',
            Value    => ['unit.test@unittest.com']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email3) IN (\'unit.test@unittest.com\')' : 'c.email3 IN (\'unit.test@unittest.com\')'
            ]

        }
    },
    {
        Name         => 'Search: valid search / Field Email3 / Operator !IN',
        Search       => {
            Field    => 'Email3',
            Operator => '!IN',
            Value    => ['unit.test@unittest.com']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email3) NOT IN (\'unit.test@unittest.com\')' : 'c.email3 NOT IN (\'unit.test@unittest.com\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email3 / Operator STARTSWITH',
        Search       => {
            Field    => 'Email3',
            Operator => 'STARTSWITH',
            Value    => 'unit.test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email3) LIKE \'unit.test%\'' : 'c.email3 LIKE \'unit.test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email3 / Operator ENDSWITH',
        Search       => {
            Field    => 'Email3',
            Operator => 'ENDSWITH',
            Value    => 'unittest.com'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email3) LIKE \'%unittest.com\'' : 'c.email3 LIKE \'%unittest.com\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email3 / Operator CONTAINS',
        Search       => {
            Field    => 'Email3',
            Operator => 'CONTAINS',
            Value    => 'test@unit'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email3) LIKE \'%test@unit%\'' : 'c.email3 LIKE \'%test@unit%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email3 / Operator LIKE',
        Search       => {
            Field    => 'Email3',
            Operator => 'LIKE',
            Value    => '*unit*'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email3) LIKE \'%unit%\'' : 'c.email3 LIKE \'%unit%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email4 / Operator EQ',
        Search       => {
            Field    => 'Email4',
            Operator => 'EQ',
            Value    => 'unit.test@unittest.com'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email4) = \'unit.test@unittest.com\'' : 'c.email4 = \'unit.test@unittest.com\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email4 / Operator NE',
        Search       => {
            Field    => 'Email4',
            Operator => 'NE',
            Value    => 'unit.test@unittest.com'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(c.email4) != \'unit.test@unittest.com\' OR c.email4 IS NULL)' : '(c.email4 != \'unit.test@unittest.com\' OR c.email4 IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email4 / Operator IN',
        Search       => {
            Field    => 'Email4',
            Operator => 'IN',
            Value    => ['unit.test@unittest.com']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email4) IN (\'unit.test@unittest.com\')' : 'c.email4 IN (\'unit.test@unittest.com\')'
            ]

        }
    },
    {
        Name         => 'Search: valid search / Field Email4 / Operator !IN',
        Search       => {
            Field    => 'Email4',
            Operator => '!IN',
            Value    => ['unit.test@unittest.com']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email4) NOT IN (\'unit.test@unittest.com\')' : 'c.email4 NOT IN (\'unit.test@unittest.com\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email4 / Operator STARTSWITH',
        Search       => {
            Field    => 'Email4',
            Operator => 'STARTSWITH',
            Value    => 'unit.test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email4) LIKE \'unit.test%\'' : 'c.email4 LIKE \'unit.test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email4 / Operator ENDSWITH',
        Search       => {
            Field    => 'Email4',
            Operator => 'ENDSWITH',
            Value    => 'unittest.com'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email4) LIKE \'%unittest.com\'' : 'c.email4 LIKE \'%unittest.com\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email4 / Operator CONTAINS',
        Search       => {
            Field    => 'Email4',
            Operator => 'CONTAINS',
            Value    => 'test@unit'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email4) LIKE \'%test@unit%\'' : 'c.email4 LIKE \'%test@unit%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email4 / Operator LIKE',
        Search       => {
            Field    => 'Email4',
            Operator => 'LIKE',
            Value    => '*unit*'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email4) LIKE \'%unit%\'' : 'c.email4 LIKE \'%unit%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email5 / Operator EQ',
        Search       => {
            Field    => 'Email5',
            Operator => 'EQ',
            Value    => 'unit.test@unittest.com'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email5) = \'unit.test@unittest.com\'' : 'c.email5 = \'unit.test@unittest.com\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email5 / Operator NE',
        Search       => {
            Field    => 'Email5',
            Operator => 'NE',
            Value    => 'unit.test@unittest.com'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(c.email5) != \'unit.test@unittest.com\' OR c.email5 IS NULL)' : '(c.email5 != \'unit.test@unittest.com\' OR c.email5 IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email5 / Operator IN',
        Search       => {
            Field    => 'Email5',
            Operator => 'IN',
            Value    => ['unit.test@unittest.com']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email5) IN (\'unit.test@unittest.com\')' : 'c.email5 IN (\'unit.test@unittest.com\')'
            ]

        }
    },
    {
        Name         => 'Search: valid search / Field Email5 / Operator !IN',
        Search       => {
            Field    => 'Email5',
            Operator => '!IN',
            Value    => ['unit.test@unittest.com']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email5) NOT IN (\'unit.test@unittest.com\')' : 'c.email5 NOT IN (\'unit.test@unittest.com\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email5 / Operator STARTSWITH',
        Search       => {
            Field    => 'Email5',
            Operator => 'STARTSWITH',
            Value    => 'unit.test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email5) LIKE \'unit.test%\'' : 'c.email5 LIKE \'unit.test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email5 / Operator ENDSWITH',
        Search       => {
            Field    => 'Email5',
            Operator => 'ENDSWITH',
            Value    => 'unittest.com'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email5) LIKE \'%unittest.com\'' : 'c.email5 LIKE \'%unittest.com\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email5 / Operator CONTAINS',
        Search       => {
            Field    => 'Email5',
            Operator => 'CONTAINS',
            Value    => 'test@unit'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email5) LIKE \'%test@unit%\'' : 'c.email5 LIKE \'%test@unit%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email5 / Operator LIKE',
        Search       => {
            Field    => 'Email5',
            Operator => 'LIKE',
            Value    => '*unit*'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.email5) LIKE \'%unit%\'' : 'c.email5 LIKE \'%unit%\''
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
        Name      => 'Sort: Attribute "Email"',
        Attribute => 'Email',
        Expected  => {
            'OrderBy' => ['c.email'],
            'Select'  => []
        }
    },
    {
        Name      => 'Sort: Attribute "Email1"',
        Attribute => 'Email1',
        Expected  => {
            'OrderBy' => ['c.email1'],
            'Select'  => ['c.email1']
        }
    },
    {
        Name      => 'Sort: Attribute "Email2"',
        Attribute => 'Email2',
        Expected  => {
            'OrderBy' => ['c.email2'],
            'Select'  => ['c.email2']
        }
    },
    {
        Name      => 'Sort: Attribute "Email3"',
        Attribute => 'Email3',
        Expected  => {
            'OrderBy' => ['c.email3'],
            'Select'  => ['c.email3']
        }
    },
    {
        Name      => 'Sort: Attribute "Email4"',
        Attribute => 'Email4',
        Expected  => {
            'OrderBy' => ['c.email4'],
            'Select'  => ['c.email4']
        }
    },
    {
        Name      => 'Sort: Attribute "Email5"',
        Attribute => 'Email5',
        Expected  => {
            'OrderBy' => ['c.email5'],
            'Select'  => ['c.email5']
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

## prepare user mapping
my $RoleID = $Kernel::OM->Get('Role')->RoleLookup(
    Role => 'Customer Manager'
);
my @Contacts = (
    {
        Firstname => 'Alf',
        Lastname  => 'Test',
        Email     => 'alf.test101@unittest.com',
        Email1    => 'andrew.engel@subtest.org',
        Email2    => 'leonid.dietrich@subtest.org',
        Email3    => 'alvin.test101@unittest.com',
        Email4    => 'anette.knapp@subtest.org',
        Email5    => 'marioh.hager@subtest.org'
    },
    {
        Firstname => 'Bert',
        Lastname  => 'Test',
        Email     => 'bert.test102@unittest.com',
        Email1    => 'erich.engel@subtest.org',
        Email2    => 'herta.dietrich@subtest.org',
        Email3    => 'gisela.hempel@subtest.org',
        Email4    => 'bert.knapp@subtest.org',
        Email5    => 'theo.test102@unittest.com'
    },
    {
        Firstname => 'Alvin',
        Lastname  => 'Test',
        Email     => 'alvin.test103@unittest.com',
        Email1    => 'judith.engel@subtest.org',
        Email2    => 'juri.dietrich@subtest.org',
        Email3    => 'hildegard.hempel@subtest.org',
        Email4    => 'berni.test103@unittest.com',
        Email5    => 'reinhilde.hager@subtest.org'
    },
    {
        Firstname => 'Berni',
        Lastname  => 'Test',
        Email     => 'berni.test104@unittest.com',
        Email1    => 'carsten.engel@subtest.org',
        Email2    => 'bert.test104@unittest.com',
        Email3    => 'renata.hempel@subtest.org',
        Email4    => 'mathilde.knapp@subtest.org',
        Email5    => 'bastian.hager@subtest.org'
    },
    {
        Firstname => 'Theo',
        Lastname  => 'Test',
        Email     => 'theo.test105@unittest.com',
        Email1    => 'alf.test105@unittest.com',
        Email2    => 'enno.dietrich@subtest.org',
        Email3    => 'heidemarie.hempel@subtest.org',
        Email4    => 'gunnar.knapp@subtest.org',
        Email5    => 'alfred.hager@subtest.org'
    }
);
my @Leads = (
    undef,
    'First',
    'Second',
    'Third',
    'Fourth',
    'Fifth'
);

my @ContactIDs;
my $Count = 0;
for my $Contact ( @Contacts ) {
    $Count++;

    my $UserID = $Kernel::OM->Get('User')->UserAdd(
        UserLogin     => 'Test10' . $Count,
        ValidID       => 1,
        ChangeUserID  => 1,
        IsAgent       => 1
    );
    $Kernel::OM->Get('Role')->RoleUserAdd(
        AssignUserID => $UserID,
        RoleID       => $RoleID,
        UserID       => 1,
    );
    $Self->True(
        $UserID,
        "$Leads[$Count] user created"
    );
    my $ContactID = $Kernel::OM->Get('Contact')->ContactAdd(
        %{$Contact},
        AssignedUserID        => $UserID,
        ValidID               => 1,
        UserID                => 1,
    );
    $Self->True(
        $ContactID,
        'Contact for ' . lc($Leads[$Count]) . ' user created'
    );

    push( @ContactIDs, $ContactID );
}

# discard contact object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Contact'],
);

# discard user object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['User'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => "Search: Field Emails / Operator EQ / Value \$Contacts[0]{Email}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Emails',
                    Operator => 'EQ',
                    Value    => $Contacts[0]{Email}
                }
            ]
        },
        Expected => [$ContactIDs[0]]
    },
    {
        Name     => "Search: Field Emails / Operator NE / Value \$Contacts[0]{Email}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Emails',
                    Operator => 'NE',
                    Value    => $Contacts[0]{Email}
                }
            ]
        },
        Expected => ['1',@ContactIDs]
    },
    {
        Name     => "Search: Field Emails / Operator IN / Value [\$Contacts[1]{Email},\$Contacts[2]{Email}]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Emails',
                    Operator => 'IN',
                    Value    => [$Contacts[1]{Email},$Contacts[2]{Email}]
                }
            ]
        },
        Expected => [$ContactIDs[1],$ContactIDs[2]]
    },
    {
        Name     => "Search: Field Emails / Operator !IN / Value [\$Contacts[1]{Email},\$Contacts[2]{Email}]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Emails',
                    Operator => '!IN',
                    Value    => [$Contacts[1]{Email},$Contacts[2]{Email}]
                }
            ]
        },
        Expected => ['1',@ContactIDs]
    },
    {
        Name     => "Search: Field Emails / Operator STARTSWITH / Value substr(\$Contacts[3]{Email},0,5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Emails',
                    Operator => 'STARTSWITH',
                    Value    => substr($Contacts[3]{Email},0,5)
                }
            ]
        },
        Expected => [$ContactIDs[2],$ContactIDs[3]]
    },
    {
        Name     => "Search: Field Emails / Operator ENDSWITH / Value substr(\$Contacts[4]{Email},-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Emails',
                    Operator => 'ENDSWITH',
                    Value    => substr($Contacts[4]{Email},-5)
                }
            ]
        },
        Expected => [@ContactIDs]
    },
    {
        Name     => "Search: Field Emails / Operator CONTAINS / Value substr(\$Contacts[0]{Email},2,-16)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Emails',
                    Operator => 'CONTAINS',
                    Value    => substr($Contacts[0]{Email},2,-16)
                }
            ]
        },
        Expected => [$ContactIDs[0],$ContactIDs[4]]
    },
    {
        Name     => "Search: Field Emails / Operator LIKE / Value substr(\$Contacts[2]{Email},0,5)*substr(\$Contacts[2]{Email},-12)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Emails',
                    Operator => 'LIKE',
                    Value    => substr($Contacts[2]{Email},0,5)
                        . q{*}
                        . substr($Contacts[2]{Email},-12)
                }
            ]
        },
        Expected => [$ContactIDs[0],$ContactIDs[2]]
    },
    {
        Name     => "Search: Field Email / Operator EQ / Value \$Contacts[0]{Email}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email',
                    Operator => 'EQ',
                    Value    => $Contacts[0]{Email}
                }
            ]
        },
        Expected => [$ContactIDs[0]]
    },
    {
        Name     => "Search: Field Email / Operator NE / Value \$Contacts[0]{Email}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email',
                    Operator => 'NE',
                    Value    => $Contacts[0]{Email}
                }
            ]
        },
        Expected => ['1',$ContactIDs[1],$ContactIDs[2],$ContactIDs[3],$ContactIDs[4]]
    },
    {
        Name     => "Search: Field Email / Operator IN / Value [\$Contacts[1]{Email},\$Contacts[2]{Email}]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email',
                    Operator => 'IN',
                    Value    => [$Contacts[1]{Email},$Contacts[2]{Email}]
                }
            ]
        },
        Expected => [$ContactIDs[1],$ContactIDs[2]]
    },
    {
        Name     => "Search: Field Email / Operator !IN / Value [\$Contacts[1]{Email},\$Contacts[2]{Email}]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email',
                    Operator => '!IN',
                    Value    => [$Contacts[1]{Email},$Contacts[2]{Email}]
                }
            ]
        },
        Expected => ['1',$ContactIDs[0],$ContactIDs[3],$ContactIDs[4]]
    },
    {
        Name     => "Search: Field Email / Operator STARTSWITH / Value substr(\$Contacts[3]{Email},0,5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email',
                    Operator => 'STARTSWITH',
                    Value    => substr($Contacts[3]{Email},0,5)
                }
            ]
        },
        Expected => [$ContactIDs[3]]
    },
    {
        Name     => "Search: Field Email / Operator ENDSWITH / Value substr(\$Contacts[4]{Email},-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email',
                    Operator => 'ENDSWITH',
                    Value    => substr($Contacts[4]{Email},-5)
                }
            ]
        },
        Expected => [@ContactIDs]
    },
    {
        Name     => "Search: Field Email / Operator CONTAINS / Value substr(\$Contacts[0]{Email},2,-16)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email',
                    Operator => 'CONTAINS',
                    Value    => substr($Contacts[0]{Email},2,-16)
                }
            ]
        },
        Expected => [$ContactIDs[0]]
    },
    {
        Name     => "Search: Field Email / Operator LIKE / Value substr(\$Contacts[2]{Email},0,5)*substr(\$Contacts[2]{Email},-12)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email',
                    Operator => 'LIKE',
                    Value    => substr($Contacts[2]{Email},0,5)
                        . q{*}
                        . substr($Contacts[2]{Email},-12)
                }
            ]
        },
        Expected => [$ContactIDs[2]]
    },
    {
        Name     => "Search: Field Email1 / Operator EQ / Value \$Contacts[0]{Email1}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email1',
                    Operator => 'EQ',
                    Value    => $Contacts[0]{Email1}
                }
            ]
        },
        Expected => [$ContactIDs[0]]
    },
    {
        Name     => "Search: Field Email1 / Operator NE / Value \$Contacts[0]{Email1}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email1',
                    Operator => 'NE',
                    Value    => $Contacts[0]{Email1}
                }
            ]
        },
        Expected => ['1',$ContactIDs[1],$ContactIDs[2],$ContactIDs[3],$ContactIDs[4]]
    },
    {
        Name     => "Search: Field Email1 / Operator IN / Value [\$Contacts[1]{Email1},\$Contacts[2]{Email1}]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email1',
                    Operator => 'IN',
                    Value    => [$Contacts[1]{Email1},$Contacts[2]{Email1}]
                }
            ]
        },
        Expected => [$ContactIDs[1],$ContactIDs[2]]
    },
    {
        Name     => "Search: Field Email1 / Operator !IN / Value [\$Contacts[1]{Email1},\$Contacts[2]{Email1}]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email1',
                    Operator => '!IN',
                    Value    => [$Contacts[1]{Email1},$Contacts[2]{Email1}]
                }
            ]
        },
        Expected => [$ContactIDs[0],$ContactIDs[3],$ContactIDs[4]]
    },
    {
        Name     => "Search: Field Email1 / Operator STARTSWITH / Value substr(\$Contacts[3]{Email1},0,5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email1',
                    Operator => 'STARTSWITH',
                    Value    => substr($Contacts[3]{Email1},0,5)
                }
            ]
        },
        Expected => [$ContactIDs[3]]
    },
    {
        Name     => "Search: Field Email1 / Operator ENDSWITH / Value substr(\$Contacts[4]{Email1},-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email1',
                    Operator => 'ENDSWITH',
                    Value    => substr($Contacts[4]{Email1},-5)
                }
            ]
        },
        Expected => [$ContactIDs[4]]
    },
    {
        Name     => "Search: Field Email1 / Operator CONTAINS / Value substr(\$Contacts[0]{Email1},2,-16)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email1',
                    Operator => 'CONTAINS',
                    Value    => substr($Contacts[0]{Email1},2,-16)
                }
            ]
        },
        Expected => [$ContactIDs[0]]
    },
    {
        Name     => "Search: Field Email1 / Operator LIKE / Value substr(\$Contacts[2]{Email1},0,5)*substr(\$Contacts[2]{Email1},-12)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email1',
                    Operator => 'LIKE',
                    Value    => substr($Contacts[2]{Email1},0,5)
                        . q{*}
                        . substr($Contacts[2]{Email1},-12)
                }
            ]
        },
        Expected => [$ContactIDs[2]]
    },
    {
        Name     => "Search: Field Email2 / Operator EQ / Value \$Contacts[0]{Email2}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email2',
                    Operator => 'EQ',
                    Value    => $Contacts[0]{Email2}
                }
            ]
        },
        Expected => [$ContactIDs[0]]
    },
    {
        Name     => "Search: Field Email2 / Operator NE / Value \$Contacts[0]{Email2}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email2',
                    Operator => 'NE',
                    Value    => $Contacts[0]{Email2}
                }
            ]
        },
        Expected => ['1',$ContactIDs[1],$ContactIDs[2],$ContactIDs[3],$ContactIDs[4]]
    },
    {
        Name     => "Search: Field Email2 / Operator IN / Value [\$Contacts[1]{Email2},\$Contacts[2]{Email2}]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email2',
                    Operator => 'IN',
                    Value    => [$Contacts[1]{Email2},$Contacts[2]{Email2}]
                }
            ]
        },
        Expected => [$ContactIDs[1],$ContactIDs[2]]
    },
    {
        Name     => "Search: Field Email2 / Operator !IN / Value [\$Contacts[1]{Email2},\$Contacts[2]{Email2}]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email2',
                    Operator => '!IN',
                    Value    => [$Contacts[1]{Email2},$Contacts[2]{Email2}]
                }
            ]
        },
        Expected => [$ContactIDs[0],$ContactIDs[3],$ContactIDs[4]]
    },
    {
        Name     => "Search: Field Email2 / Operator STARTSWITH / Value substr(\$Contacts[3]{Email2},0,5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email2',
                    Operator => 'STARTSWITH',
                    Value    => substr($Contacts[3]{Email2},0,5)
                }
            ]
        },
        Expected => [$ContactIDs[3]]
    },
    {
        Name     => "Search: Field Email2 / Operator ENDSWITH / Value substr(\$Contacts[4]{Email2},-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email2',
                    Operator => 'ENDSWITH',
                    Value    => substr($Contacts[4]{Email2},-5)
                }
            ]
        },
        Expected => [$ContactIDs[0],$ContactIDs[1],$ContactIDs[2],$ContactIDs[4]]
    },
    {
        Name     => "Search: Field Email2 / Operator CONTAINS / Value substr(\$Contacts[0]{Email2},2,-16)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email2',
                    Operator => 'CONTAINS',
                    Value    => substr($Contacts[0]{Email2},2,-16)
                }
            ]
        },
        Expected => [$ContactIDs[0]]
    },
    {
        Name     => "Search: Field Email2 / Operator LIKE / Value substr(\$Contacts[2]{Email2},0,5)*substr(\$Contacts[2]{Email2},-12)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email2',
                    Operator => 'LIKE',
                    Value    => substr($Contacts[2]{Email2},0,5)
                        . q{*}
                        . substr($Contacts[2]{Email2},-12)
                }
            ]
        },
        Expected => [$ContactIDs[2]]
    },
    {
        Name     => "Search: Field Email3 / Operator EQ / Value \$Contacts[0]{Email3}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email3',
                    Operator => 'EQ',
                    Value    => $Contacts[0]{Email3}
                }
            ]
        },
        Expected => [$ContactIDs[0]]
    },
    {
        Name     => "Search: Field Email3 / Operator NE / Value \$Contacts[0]{Email3}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email3',
                    Operator => 'NE',
                    Value    => $Contacts[0]{Email3}
                }
            ]
        },
        Expected => ['1',$ContactIDs[1],$ContactIDs[2],$ContactIDs[3],$ContactIDs[4]]
    },
    {
        Name     => "Search: Field Email3 / Operator IN / Value [\$Contacts[1]{Email3},\$Contacts[2]{Email3}]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email3',
                    Operator => 'IN',
                    Value    => [$Contacts[1]{Email3},$Contacts[2]{Email3}]
                }
            ]
        },
        Expected => [$ContactIDs[1],$ContactIDs[2]]
    },
    {
        Name     => "Search: Field Email3 / Operator !IN / Value [\$Contacts[1]{Email3},\$Contacts[2]{Email3}]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email3',
                    Operator => '!IN',
                    Value    => [$Contacts[1]{Email3},$Contacts[2]{Email3}]
                }
            ]
        },
        Expected => [$ContactIDs[0],$ContactIDs[3],$ContactIDs[4]]
    },
    {
        Name     => "Search: Field Email3 / Operator STARTSWITH / Value substr(\$Contacts[3]{Email3},0,5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email3',
                    Operator => 'STARTSWITH',
                    Value    => substr($Contacts[3]{Email3},0,5)
                }
            ]
        },
        Expected => [$ContactIDs[3]]
    },
    {
        Name     => "Search: Field Email3 / Operator ENDSWITH / Value substr(\$Contacts[4]{Email3},-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email3',
                    Operator => 'ENDSWITH',
                    Value    => substr($Contacts[4]{Email3},-5)
                }
            ]
        },
        Expected => [$ContactIDs[1],$ContactIDs[2],$ContactIDs[3],$ContactIDs[4]]
    },
    {
        Name     => "Search: Field Email3 / Operator CONTAINS / Value substr(\$Contacts[0]{Email3},2,-16)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email3',
                    Operator => 'CONTAINS',
                    Value    => substr($Contacts[0]{Email3},2,-16)
                }
            ]
        },
        Expected => [$ContactIDs[0]]
    },
    {
        Name     => "Search: Field Email3 / Operator LIKE / Value substr(\$Contacts[2]{Email3},0,5)*substr(\$Contacts[2]{Email3},-12)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email3',
                    Operator => 'LIKE',
                    Value    => substr($Contacts[2]{Email3},0,5)
                        . q{*}
                        . substr($Contacts[2]{Email3},-12)
                }
            ]
        },
        Expected => [$ContactIDs[2]]
    },
    {
        Name     => "Search: Field Email4 / Operator EQ / Value \$Contacts[0]{Email4}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email4',
                    Operator => 'EQ',
                    Value    => $Contacts[0]{Email4}
                }
            ]
        },
        Expected => [$ContactIDs[0]]
    },
    {
        Name     => "Search: Field Email4 / Operator NE / Value \$Contacts[0]{Email4}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email4',
                    Operator => 'NE',
                    Value    => $Contacts[0]{Email4}
                }
            ]
        },
        Expected => ['1',$ContactIDs[1],$ContactIDs[2],$ContactIDs[3],$ContactIDs[4]]
    },
    {
        Name     => "Search: Field Email4 / Operator IN / Value [\$Contacts[1]{Email4},\$Contacts[2]{Email4}]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email4',
                    Operator => 'IN',
                    Value    => [$Contacts[1]{Email4},$Contacts[2]{Email4}]
                }
            ]
        },
        Expected => [$ContactIDs[1],$ContactIDs[2]]
    },
    {
        Name     => "Search: Field Email4 / Operator !IN / Value [\$Contacts[1]{Email4},\$Contacts[2]{Email4}]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email4',
                    Operator => '!IN',
                    Value    => [$Contacts[1]{Email4},$Contacts[2]{Email4}]
                }
            ]
        },
        Expected => [$ContactIDs[0],$ContactIDs[3],$ContactIDs[4]]
    },
    {
        Name     => "Search: Field Email4 / Operator STARTSWITH / Value substr(\$Contacts[3]{Email4},0,5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email4',
                    Operator => 'STARTSWITH',
                    Value    => substr($Contacts[3]{Email4},0,5)
                }
            ]
        },
        Expected => [$ContactIDs[3]]
    },
    {
        Name     => "Search: Field Email4 / Operator ENDSWITH / Value substr(\$Contacts[4]{Email4},-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email4',
                    Operator => 'ENDSWITH',
                    Value    => substr($Contacts[4]{Email4},-5)
                }
            ]
        },
        Expected => [$ContactIDs[0],$ContactIDs[1],$ContactIDs[3],$ContactIDs[4]]
    },
    {
        Name     => "Search: Field Email4 / Operator CONTAINS / Value substr(\$Contacts[0]{Email4},2,-16)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email4',
                    Operator => 'CONTAINS',
                    Value    => substr($Contacts[0]{Email4},2,-16)
                }
            ]
        },
        Expected => [$ContactIDs[0]]
    },
    {
        Name     => "Search: Field Email4 / Operator LIKE / Value substr(\$Contacts[2]{Email4},0,5)*substr(\$Contacts[2]{Email4},-12)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email4',
                    Operator => 'LIKE',
                    Value    => substr($Contacts[2]{Email4},0,5)
                        . q{*}
                        . substr($Contacts[2]{Email4},-12)
                }
            ]
        },
        Expected => [$ContactIDs[2]]
    },
    {
        Name     => "Search: Field Email5 / Operator EQ / Value \$Contacts[0]{Email5}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email5',
                    Operator => 'EQ',
                    Value    => $Contacts[0]{Email5}
                }
            ]
        },
        Expected => [$ContactIDs[0]]
    },
    {
        Name     => "Search: Field Email5 / Operator NE / Value \$Contacts[0]{Email5}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email5',
                    Operator => 'NE',
                    Value    => $Contacts[0]{Email5}
                }
            ]
        },
        Expected => ['1',$ContactIDs[1],$ContactIDs[2],$ContactIDs[3],$ContactIDs[4]]
    },
    {
        Name     => "Search: Field Email5 / Operator IN / Value [\$Contacts[1]{Email5},\$Contacts[2]{Email5}]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email5',
                    Operator => 'IN',
                    Value    => [$Contacts[1]{Email5},$Contacts[2]{Email5}]
                }
            ]
        },
        Expected => [$ContactIDs[1],$ContactIDs[2]]
    },
    {
        Name     => "Search: Field Email5 / Operator !IN / Value [\$Contacts[1]{Email5},\$Contacts[2]{Email5}]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email5',
                    Operator => '!IN',
                    Value    => [$Contacts[1]{Email5},$Contacts[2]{Email5}]
                }
            ]
        },
        Expected => [$ContactIDs[0],$ContactIDs[3],$ContactIDs[4]]
    },
    {
        Name     => "Search: Field Email5 / Operator STARTSWITH / Value substr(\$Contacts[3]{Email5},0,5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email5',
                    Operator => 'STARTSWITH',
                    Value    => substr($Contacts[3]{Email5},0,5)
                }
            ]
        },
        Expected => [$ContactIDs[3]]
    },
    {
        Name     => "Search: Field Email5 / Operator ENDSWITH / Value substr(\$Contacts[4]{Email5},-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email5',
                    Operator => 'ENDSWITH',
                    Value    => substr($Contacts[4]{Email5},-5)
                }
            ]
        },
        Expected => [$ContactIDs[0],$ContactIDs[2],$ContactIDs[3],$ContactIDs[4]]
    },
    {
        Name     => "Search: Field Email5 / Operator CONTAINS / Value substr(\$Contacts[0]{Email5},2,-16)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email5',
                    Operator => 'CONTAINS',
                    Value    => substr($Contacts[0]{Email5},2,-16)
                }
            ]
        },
        Expected => [$ContactIDs[0]]
    },
    {
        Name     => "Search: Field Email5 / Operator LIKE / Value substr(\$Contacts[2]{Email5},0,5)*substr(\$Contacts[2]{Email5},-12)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Email5',
                    Operator => 'LIKE',
                    Value    => substr($Contacts[2]{Email5},0,5)
                        . q{*}
                        . substr($Contacts[2]{Email5},-12)
                }
            ]
        },
        Expected => [$ContactIDs[2]]
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
        Name     => 'Sort: Field Email',
        Sort     => [
            {
                Field => 'Email'
            }
        ],
        Expected => ['1',$ContactIDs[0],$ContactIDs[2],$ContactIDs[3],$ContactIDs[1],$ContactIDs[4]]
    },
    {
        Name     => 'Sort: Field Email / Direction ascending',
        Sort     => [
            {
                Field     => 'Email',
                Direction => 'ascending'
            }
        ],
        Expected => ['1',$ContactIDs[0],$ContactIDs[2],$ContactIDs[3],$ContactIDs[1],$ContactIDs[4]]
    },
    {
        Name     => 'Sort: Field Email / Direction descending',
        Sort     => [
            {
                Field     => 'Email',
                Direction => 'descending'
            }
        ],
        Expected => [$ContactIDs[4],$ContactIDs[1],$ContactIDs[3],$ContactIDs[2],$ContactIDs[0],'1']
    },
    {
        Name     => 'Sort: Field Email1',
        Sort     => [
            {
                Field => 'Email1'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ContactIDs[4],$ContactIDs[0],$ContactIDs[3],$ContactIDs[1],$ContactIDs[2],'1'] : ['1',$ContactIDs[4],$ContactIDs[0],$ContactIDs[3],$ContactIDs[1],$ContactIDs[2]]
    },
    {
        Name     => 'Sort: Field Email1 / Direction ascending',
        Sort     => [
            {
                Field     => 'Email1',
                Direction => 'ascending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ContactIDs[4],$ContactIDs[0],$ContactIDs[3],$ContactIDs[1],$ContactIDs[2],'1'] : ['1',$ContactIDs[4],$ContactIDs[0],$ContactIDs[3],$ContactIDs[1],$ContactIDs[2]]
    },
    {
        Name     => 'Sort: Field Email1 / Direction descending',
        Sort     => [
            {
                Field     => 'Email1',
                Direction => 'descending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? ['1',$ContactIDs[2],$ContactIDs[1],$ContactIDs[3],$ContactIDs[0],$ContactIDs[4]] : [$ContactIDs[2],$ContactIDs[1],$ContactIDs[3],$ContactIDs[0],$ContactIDs[4],'1']
    },
    {
        Name     => 'Sort: Field Email2',
        Sort     => [
            {
                Field => 'Email2'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ContactIDs[3],$ContactIDs[4],$ContactIDs[1],$ContactIDs[2],$ContactIDs[0],'1'] : ['1',$ContactIDs[3],$ContactIDs[4],$ContactIDs[1],$ContactIDs[2],$ContactIDs[0]]
    },
    {
        Name     => 'Sort: Field Email2 / Direction ascending',
        Sort     => [
            {
                Field     => 'Email2',
                Direction => 'ascending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ContactIDs[3],$ContactIDs[4],$ContactIDs[1],$ContactIDs[2],$ContactIDs[0],'1'] : ['1',$ContactIDs[3],$ContactIDs[4],$ContactIDs[1],$ContactIDs[2],$ContactIDs[0]]
    },
    {
        Name     => 'Sort: Field Email2 / Direction descending',
        Sort     => [
            {
                Field     => 'Email2',
                Direction => 'descending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? ['1',$ContactIDs[0],$ContactIDs[2],$ContactIDs[1],$ContactIDs[4],$ContactIDs[3]] : [$ContactIDs[0],$ContactIDs[2],$ContactIDs[1],$ContactIDs[4],$ContactIDs[3],'1']
    },
    {
        Name     => 'Sort: Field Email3',
        Sort     => [
            {
                Field => 'Email3'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ContactIDs[0],$ContactIDs[1],$ContactIDs[4],$ContactIDs[2],$ContactIDs[3],'1'] : ['1',$ContactIDs[0],$ContactIDs[1],$ContactIDs[4],$ContactIDs[2],$ContactIDs[3]]
    },
    {
        Name     => 'Sort: Field Email3 / Direction ascending',
        Sort     => [
            {
                Field     => 'Email3',
                Direction => 'ascending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ContactIDs[0],$ContactIDs[1],$ContactIDs[4],$ContactIDs[2],$ContactIDs[3],'1'] : ['1',$ContactIDs[0],$ContactIDs[1],$ContactIDs[4],$ContactIDs[2],$ContactIDs[3]]
    },
    {
        Name     => 'Sort: Field Email3 / Direction descending',
        Sort     => [
            {
                Field     => 'Email3',
                Direction => 'descending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? ['1',$ContactIDs[3],$ContactIDs[2],$ContactIDs[4],$ContactIDs[1],$ContactIDs[0]] : [$ContactIDs[3],$ContactIDs[2],$ContactIDs[4],$ContactIDs[1],$ContactIDs[0],'1']
    },
    {
        Name     => 'Sort: Field Email4',
        Sort     => [
            {
                Field => 'Email4'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ContactIDs[0],$ContactIDs[2],$ContactIDs[1],$ContactIDs[4],$ContactIDs[3],'1'] : ['1',$ContactIDs[0],$ContactIDs[2],$ContactIDs[1],$ContactIDs[4],$ContactIDs[3]]
    },
    {
        Name     => 'Sort: Field Email4 / Direction ascending',
        Sort     => [
            {
                Field     => 'Email4',
                Direction => 'ascending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ContactIDs[0],$ContactIDs[2],$ContactIDs[1],$ContactIDs[4],$ContactIDs[3],'1'] : ['1',$ContactIDs[0],$ContactIDs[2],$ContactIDs[1],$ContactIDs[4],$ContactIDs[3]]
    },
    {
        Name     => 'Sort: Field Email4 / Direction descending',
        Sort     => [
            {
                Field     => 'Email4',
                Direction => 'descending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? ['1',$ContactIDs[3],$ContactIDs[4],$ContactIDs[1],$ContactIDs[2],$ContactIDs[0]] : [$ContactIDs[3],$ContactIDs[4],$ContactIDs[1],$ContactIDs[2],$ContactIDs[0],'1']
    },
    {
        Name     => 'Sort: Field Email5',
        Sort     => [
            {
                Field => 'Email5'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ContactIDs[4],$ContactIDs[3],$ContactIDs[0],$ContactIDs[2],$ContactIDs[1],'1'] : ['1',$ContactIDs[4],$ContactIDs[3],$ContactIDs[0],$ContactIDs[2],$ContactIDs[1]]
    },
    {
        Name     => 'Sort: Field Email5 / Direction ascending',
        Sort     => [
            {
                Field     => 'Email5',
                Direction => 'ascending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ContactIDs[4],$ContactIDs[3],$ContactIDs[0],$ContactIDs[2],$ContactIDs[1],'1'] : ['1',$ContactIDs[4],$ContactIDs[3],$ContactIDs[0],$ContactIDs[2],$ContactIDs[1]]
    },
    {
        Name     => 'Sort: Field Email5 / Direction descending',
        Sort     => [
            {
                Field     => 'Email5',
                Direction => 'descending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? ['1',$ContactIDs[1],$ContactIDs[2],$ContactIDs[0],$ContactIDs[3],$ContactIDs[4]] : [$ContactIDs[1],$ContactIDs[2],$ContactIDs[0],$ContactIDs[3],$ContactIDs[4],'1']
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
