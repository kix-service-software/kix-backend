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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Certificate::General';

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
        Subject => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Issuer => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Email => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Fingerprint => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN']
        },
        CType => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN']
        },
        Type => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN']
        },
        Modulus => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN']
        },
        Hash => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN']
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
            Field    => 'Subject',
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
            Field    => 'Subject',
            Operator => undef,
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'Subject',
            Operator => 'Test',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field Subject / Operator EQ',
        Search       => {
            Field    => 'Subject',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Subject\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) = \'test\'' : 'vfsp0.preferences_value = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Subject / Operator EQ / Value empty string',
        Search       => {
            Field    => 'Subject',
            Operator => 'EQ',
            Value    => q{}
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Subject\''
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(vfsp0.preferences_value) = \'\' OR vfsp0.preferences_value IS NULL)' : '(vfsp0.preferences_value = \'\' OR vfsp0.preferences_value IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Subject / Operator NE',
        Search       => {
            Field    => 'Subject',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Subject\''
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(vfsp0.preferences_value) != \'test\' OR vfsp0.preferences_value IS NULL)' : '(vfsp0.preferences_value != \'test\' OR vfsp0.preferences_value IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Subject / Operator NE / Value empty string',
        Search       => {
            Field    => 'Subject',
            Operator => 'NE',
            Value    => q{}
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Subject\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) != \'\'' : 'vfsp0.preferences_value != \'\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Subject / Operator IN',
        Search       => {
            Field    => 'Subject',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Subject\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) IN (\'test\')' : 'vfsp0.preferences_value IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Subject / Operator !IN',
        Search       => {
            Field    => 'Subject',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Subject\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) NOT IN (\'test\')' : 'vfsp0.preferences_value NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Subject / Operator STARTSWITH',
        Search       => {
            Field    => 'Subject',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Subject\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) LIKE \'test%\'' : 'vfsp0.preferences_value LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Subject / Operator ENDSWITH',
        Search       => {
            Field    => 'Subject',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Subject\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) LIKE \'%test\'' : 'vfsp0.preferences_value LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Subject / Operator CONTAINS',
        Search       => {
            Field    => 'Subject',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Subject\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) LIKE \'%test%\'' : 'vfsp0.preferences_value LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Subject / Operator LIKE',
        Search       => {
            Field    => 'Subject',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Subject\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) LIKE \'test\'' : 'vfsp0.preferences_value LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Issuer / Operator EQ',
        Search       => {
            Field    => 'Issuer',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Issuer\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) = \'test\'' : 'vfsp0.preferences_value = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Issuer / Operator EQ / Value empty string',
        Search       => {
            Field    => 'Issuer',
            Operator => 'EQ',
            Value    => q{}
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Issuer\''
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(vfsp0.preferences_value) = \'\' OR vfsp0.preferences_value IS NULL)' : '(vfsp0.preferences_value = \'\' OR vfsp0.preferences_value IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Issuer / Operator NE',
        Search       => {
            Field    => 'Issuer',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Issuer\''
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(vfsp0.preferences_value) != \'test\' OR vfsp0.preferences_value IS NULL)' : '(vfsp0.preferences_value != \'test\' OR vfsp0.preferences_value IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Issuer / Operator NE / Value empty string',
        Search       => {
            Field    => 'Issuer',
            Operator => 'NE',
            Value    => q{}
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Issuer\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) != \'\'' : 'vfsp0.preferences_value != \'\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Issuer / Operator IN',
        Search       => {
            Field    => 'Issuer',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Issuer\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) IN (\'test\')' : 'vfsp0.preferences_value IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Issuer / Operator !IN',
        Search       => {
            Field    => 'Issuer',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Issuer\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) NOT IN (\'test\')' : 'vfsp0.preferences_value NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Issuer / Operator STARTSWITH',
        Search       => {
            Field    => 'Issuer',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Issuer\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) LIKE \'test%\'' : 'vfsp0.preferences_value LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Issuer / Operator ENDSWITH',
        Search       => {
            Field    => 'Issuer',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Issuer\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) LIKE \'%test\'' : 'vfsp0.preferences_value LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Issuer / Operator CONTAINS',
        Search       => {
            Field    => 'Issuer',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Issuer\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) LIKE \'%test%\'' : 'vfsp0.preferences_value LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Issuer / Operator LIKE',
        Search       => {
            Field    => 'Issuer',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Issuer\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) LIKE \'test\'' : 'vfsp0.preferences_value LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email / Operator EQ',
        Search       => {
            Field    => 'Email',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Email\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) = \'test\'' : 'vfsp0.preferences_value = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email / Operator EQ / Value empty string',
        Search       => {
            Field    => 'Email',
            Operator => 'EQ',
            Value    => q{}
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Email\''
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(vfsp0.preferences_value) = \'\' OR vfsp0.preferences_value IS NULL)' : '(vfsp0.preferences_value = \'\' OR vfsp0.preferences_value IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email / Operator NE',
        Search       => {
            Field    => 'Email',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Email\''
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(vfsp0.preferences_value) != \'test\' OR vfsp0.preferences_value IS NULL)' : '(vfsp0.preferences_value != \'test\' OR vfsp0.preferences_value IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email / Operator NE / Value empty string',
        Search       => {
            Field    => 'Email',
            Operator => 'NE',
            Value    => q{}
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Email\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) != \'\'' : 'vfsp0.preferences_value != \'\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email / Operator IN',
        Search       => {
            Field    => 'Email',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Email\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) IN (\'test\')' : 'vfsp0.preferences_value IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email / Operator !IN',
        Search       => {
            Field    => 'Email',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Email\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) NOT IN (\'test\')' : 'vfsp0.preferences_value NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email / Operator STARTSWITH',
        Search       => {
            Field    => 'Email',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Email\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) LIKE \'test%\'' : 'vfsp0.preferences_value LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email / Operator ENDSWITH',
        Search       => {
            Field    => 'Email',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Email\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) LIKE \'%test\'' : 'vfsp0.preferences_value LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email / Operator CONTAINS',
        Search       => {
            Field    => 'Email',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Email\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) LIKE \'%test%\'' : 'vfsp0.preferences_value LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Email / Operator LIKE',
        Search       => {
            Field    => 'Email',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Email\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) LIKE \'test\'' : 'vfsp0.preferences_value LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CType / Operator EQ',
        Search       => {
            Field    => 'CType',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'CType\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) = \'test\'' : 'vfsp0.preferences_value = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CType / Operator EQ / Value empty string',
        Search       => {
            Field    => 'CType',
            Operator => 'EQ',
            Value    => q{}
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'CType\''
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(vfsp0.preferences_value) = \'\' OR vfsp0.preferences_value IS NULL)' : '(vfsp0.preferences_value = \'\' OR vfsp0.preferences_value IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CType / Operator NE',
        Search       => {
            Field    => 'CType',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'CType\''
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(vfsp0.preferences_value) != \'test\' OR vfsp0.preferences_value IS NULL)' : '(vfsp0.preferences_value != \'test\' OR vfsp0.preferences_value IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CType / Operator NE / Value empty string',
        Search       => {
            Field    => 'CType',
            Operator => 'NE',
            Value    => q{}
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'CType\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) != \'\'' : 'vfsp0.preferences_value != \'\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CType / Operator IN',
        Search       => {
            Field    => 'CType',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'CType\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) IN (\'test\')' : 'vfsp0.preferences_value IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CType / Operator !IN',
        Search       => {
            Field    => 'CType',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'CType\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) NOT IN (\'test\')' : 'vfsp0.preferences_value NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Type / Operator EQ',
        Search       => {
            Field    => 'Type',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Type\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) = \'test\'' : 'vfsp0.preferences_value = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Type / Operator EQ / Value empty string',
        Search       => {
            Field    => 'Type',
            Operator => 'EQ',
            Value    => q{}
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Type\''
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(vfsp0.preferences_value) = \'\' OR vfsp0.preferences_value IS NULL)' : '(vfsp0.preferences_value = \'\' OR vfsp0.preferences_value IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Type / Operator NE',
        Search       => {
            Field    => 'Type',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Type\''
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(vfsp0.preferences_value) != \'test\' OR vfsp0.preferences_value IS NULL)' : '(vfsp0.preferences_value != \'test\' OR vfsp0.preferences_value IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Type / Operator NE / Value empty string',
        Search       => {
            Field    => 'Type',
            Operator => 'NE',
            Value    => q{}
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Type\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) != \'\'' : 'vfsp0.preferences_value != \'\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Type / Operator IN',
        Search       => {
            Field    => 'Type',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Type\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) IN (\'test\')' : 'vfsp0.preferences_value IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Type / Operator !IN',
        Search       => {
            Field    => 'Type',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Type\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) NOT IN (\'test\')' : 'vfsp0.preferences_value NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Fingerprint / Operator EQ',
        Search       => {
            Field    => 'Fingerprint',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Fingerprint\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) = \'test\'' : 'vfsp0.preferences_value = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Fingerprint / Operator EQ / Value empty string',
        Search       => {
            Field    => 'Fingerprint',
            Operator => 'EQ',
            Value    => q{}
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Fingerprint\''
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(vfsp0.preferences_value) = \'\' OR vfsp0.preferences_value IS NULL)' : '(vfsp0.preferences_value = \'\' OR vfsp0.preferences_value IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Fingerprint / Operator NE',
        Search       => {
            Field    => 'Fingerprint',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Fingerprint\''
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(vfsp0.preferences_value) != \'test\' OR vfsp0.preferences_value IS NULL)' : '(vfsp0.preferences_value != \'test\' OR vfsp0.preferences_value IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Fingerprint / Operator NE / Value empty string',
        Search       => {
            Field    => 'Fingerprint',
            Operator => 'NE',
            Value    => q{}
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Fingerprint\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) != \'\'' : 'vfsp0.preferences_value != \'\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Fingerprint / Operator IN',
        Search       => {
            Field    => 'Fingerprint',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Fingerprint\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) IN (\'test\')' : 'vfsp0.preferences_value IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Fingerprint / Operator !IN',
        Search       => {
            Field    => 'Fingerprint',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Fingerprint\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) NOT IN (\'test\')' : 'vfsp0.preferences_value NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Modulus / Operator EQ',
        Search       => {
            Field    => 'Modulus',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Modulus\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) = \'test\'' : 'vfsp0.preferences_value = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Modulus / Operator EQ / Value empty string',
        Search       => {
            Field    => 'Modulus',
            Operator => 'EQ',
            Value    => q{}
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Modulus\''
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(vfsp0.preferences_value) = \'\' OR vfsp0.preferences_value IS NULL)' : '(vfsp0.preferences_value = \'\' OR vfsp0.preferences_value IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Modulus / Operator NE',
        Search       => {
            Field    => 'Modulus',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Modulus\''
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(vfsp0.preferences_value) != \'test\' OR vfsp0.preferences_value IS NULL)' : '(vfsp0.preferences_value != \'test\' OR vfsp0.preferences_value IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Modulus / Operator NE / Value empty string',
        Search       => {
            Field    => 'Modulus',
            Operator => 'NE',
            Value    => q{}
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Modulus\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) != \'\'' : 'vfsp0.preferences_value != \'\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Modulus / Operator IN',
        Search       => {
            Field    => 'Modulus',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Modulus\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) IN (\'test\')' : 'vfsp0.preferences_value IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Modulus / Operator !IN',
        Search       => {
            Field    => 'Modulus',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Modulus\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) NOT IN (\'test\')' : 'vfsp0.preferences_value NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Hash / Operator EQ',
        Search       => {
            Field    => 'Hash',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Hash\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) = \'test\'' : 'vfsp0.preferences_value = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Hash / Operator EQ / Value empty string',
        Search       => {
            Field    => 'Hash',
            Operator => 'EQ',
            Value    => q{}
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Hash\''
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(vfsp0.preferences_value) = \'\' OR vfsp0.preferences_value IS NULL)' : '(vfsp0.preferences_value = \'\' OR vfsp0.preferences_value IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Hash / Operator NE',
        Search       => {
            Field    => 'Hash',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Hash\''
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(vfsp0.preferences_value) != \'test\' OR vfsp0.preferences_value IS NULL)' : '(vfsp0.preferences_value != \'test\' OR vfsp0.preferences_value IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Hash / Operator NE / Value empty string',
        Search       => {
            Field    => 'Hash',
            Operator => 'NE',
            Value    => q{}
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Hash\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) != \'\'' : 'vfsp0.preferences_value != \'\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Hash / Operator IN',
        Search       => {
            Field    => 'Hash',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Hash\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) IN (\'test\')' : 'vfsp0.preferences_value IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Hash / Operator !IN',
        Search       => {
            Field    => 'Hash',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Hash\''
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(vfsp0.preferences_value) NOT IN (\'test\')' : 'vfsp0.preferences_value NOT IN (\'test\')'
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
        Name      => 'Sort: Attribute "Subject"',
        Attribute => 'Subject',
        Expected  => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Subject\''
            ],
            'OrderBy' => [
                'csubject'
            ],
            'Select' => [
                'vfsp0.preferences_value AS csubject'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Issuer"',
        Attribute => 'Issuer',
        Expected  => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Issuer\''
            ],
            'OrderBy' => [
                'cissuer'
            ],
            'Select' => [
                'vfsp0.preferences_value AS cissuer'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Email"',
        Attribute => 'Email',
        Expected  => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Email\''
            ],
            'OrderBy' => [
                'cemail'
            ],
            'Select' => [
                'vfsp0.preferences_value AS cemail'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "CType"',
        Attribute => 'CType',
        Expected  => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'CType\''
            ],
            'OrderBy' => [
                'cctype'
            ],
            'Select' => [
                'vfsp0.preferences_value AS cctype'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Type"',
        Attribute => 'Type',
        Expected  => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Type\''
            ],
            'OrderBy' => [
                'ctype'
            ],
            'Select' => [
                'vfsp0.preferences_value AS ctype'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Fingerprint"',
        Attribute => 'Fingerprint',
        Expected  => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Fingerprint\''
            ],
            'OrderBy' => [
                'cfingerprint'
            ],
            'Select' => [
                'vfsp0.preferences_value AS cfingerprint'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Modulus"',
        Attribute => 'Modulus',
        Expected  => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Modulus\''
            ],
            'OrderBy' => [
                'cmodulus'
            ],
            'Select' => [
                'vfsp0.preferences_value AS cmodulus'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Hash"',
        Attribute => 'Hash',
        Expected  => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'Hash\''
            ],
            'OrderBy' => [
                'chash'
            ],
            'Select' => [
                'vfsp0.preferences_value AS chash'
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

my $HomeDir = $Kernel::OM->Get('Config')->Get('Home');
my @List;
my @Files = (
    {
        Filename    => 'ExampleCA.pem',
        Filesize    => 2_800,
        ContentType => 'application/x-x509-ca-cert',
        CType       => 'SMIME',
        Type        => 'Cert',
        Name        => 'Type .PEM | application/x-x509-ca-cert / Certificate'
    },
    {
        Filename    => 'ExampleKey.pem',
        Filesize    => 1_704,
        ContentType => 'application/x-x509-ca-cert',
        CType       => 'SMIME',
        Type        => 'Private',
        Name        => 'Type .PEM | application/x-x509-ca-cert / Private Key',
        Passphrase  => 'start123'
    },
    {
        Filename    => 'Example.crt',
        Filesize    => 1_310,
        ContentType => 'application/pkix-cert',
        CType       => 'SMIME',
        Type        => 'Cert',
        Name        => 'Type .CRT | application/pkix-cert / Certificate'
    },
    {
        Filename    => 'Example.csr',
        Filesize    => 1_009,
        ContentType => 'application/pkcs10',
        CType       => 'SMIME',
        Type        => 'Cert',
        Name        => 'Type .CSR | application/pkcs10 / Certificate'
    },
    {
        Filename    => 'Example.key',
        Filesize    => 1_751,
        ContentType => 'application/x-iwork-keynote-sffkey',
        CType       => 'SMIME',
        Type        => 'Private',
        Name        => 'Type .KEY | application/x-iwork-keynote-sffkey / Private Key',
        Passphrase  => 'start123'
    }
);

for my $File ( @Files ) {
    my $Content = $Kernel::OM->Get('Main')->FileRead(
        Directory => $HomeDir . '/scripts/test/system/sample/Certificate/Certificates',
        Filename  => $File->{Filename},
        Mode      => 'binmode'
    );

    $Self->True(
        $Content,
        'Read: ' . $File->{Name}
    );

    my $ID = $Kernel::OM->Get('Certificate')->CertificateCreate(
        File => {
            Filename    => $File->{Filename},
            Filesize    => $File->{Filesize},
            ContentType => $File->{ContentType},
            Content     => MIME::Base64::encode_base64( ${$Content} ),
        },
        CType      => $File->{CType},
        Type       => $File->{Type},
        Passphrase => $File->{Passphrase}
    );

    $Self->True(
        $ID,
        'Create: ' . $File->{Name}
    );

    next if !$ID;

    my $Certificate = $Kernel::OM->Get('Certificate')->CertificateGet(
        ID => $ID
    );

    $Self->True(
        IsHashRefWithData($Certificate),
        'Get: ' . $File->{Name}
    );

    next if !$Certificate;

    push (
        @List,
        $Certificate
    );
}

my $CertID1 = $List[0]->{FileID};
my $CertID2 = $List[1]->{FileID};
my $CertID3 = $List[2]->{FileID};
my $CertID4 = $List[3]->{FileID};
my $CertID5 = $List[4]->{FileID};

my $Subject1 = $List[0]->{Subject};
my $Subject2 = $List[2]->{Subject};
my $Subject3 = $List[3]->{Subject};

my $Issuer1 = $List[0]->{Issuer};
my $Issuer2 = $List[2]->{Issuer};
my $Issuer3 = $List[4]->{Issuer};

my $Email1 = $List[0]->{Email};
my $Email2 = $List[2]->{Email};
my $Email3 = $List[4]->{Email};

my $Fingerprint1 = $List[1]->{Fingerprint};
my $Fingerprint2 = $List[2]->{Fingerprint};
my $Fingerprint3 = $List[3]->{Fingerprint};

my $Modulus1 = $List[1]->{Modulus};
my $Modulus2 = $List[3]->{Modulus};
my $Modulus3 = $List[4]->{Modulus};

my $Hash1 = $List[0]->{Hash};
my $Hash2 = $List[2]->{Hash};
my $Hash3 = $List[4]->{Hash};

my $Type1 = $List[0]->{Type};
my $Type2 = $List[1]->{Type};

my $CType1 = $List[0]->{CType};
my $CType2 = 'PGP';

# discard contact object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Certificate'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field Subject / Operator EQ / Value $Subject1',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'EQ',
                    Value    => $Subject1
                }
            ]
        },
        Expected => [$CertID1,$CertID2]
    },
    {
        Name     => 'Search: Field Subject / Operator EQ / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'EQ',
                    Value    => q{}
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field Subject / Operator NE / Value $Subject1',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'NE',
                    Value    => $Subject1
                }
            ]
        },
        Expected => [$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => 'Search: Field Subject / Operator NE / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'NE',
                    Value    => q{}
                }
            ]
        },

        Expected => [$CertID1,$CertID2,$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => 'Search: Field Subject / Operator IN / Value [$Subject2,$Subject3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'IN',
                    Value    => [$Subject2,$Subject3]
                }
            ]
        },
        Expected => [$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => 'Search: Field Subject / Operator !IN / Value [$Subject2,$Subject3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => '!IN',
                    Value    => [$Subject2,$Subject3]
                }
            ]
        },
        Expected => [$CertID1,$CertID2]
    },
    {
        Name     => 'Search: Field Subject / Operator STARTSWITH / Value $Subject1',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'STARTSWITH',
                    Value    => $Subject1
                }
            ]
        },
        Expected => [$CertID1,$CertID2]
    },
    {
        Name     => 'Search: Field Subject / Operator STARTSWITH / Value substr($Subject1,0,4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'STARTSWITH',
                    Value    => substr($Subject1,0,4)
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => 'Search: Field Subject / Operator ENDSWITH / Value $Subject1',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'ENDSWITH',
                    Value    => $Subject1
                }
            ]
        },
        Expected => [$CertID1,$CertID2]
    },
    {
        Name     => 'Search: Field Subject / Operator ENDSWITH / Value substr($Subject2,-5)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'ENDSWITH',
                    Value    => substr($Subject2,-5)
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => 'Search: Field Subject / Operator CONTAINS / Value $Subject2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'CONTAINS',
                    Value    => $Subject2
                }
            ]
        },
        Expected => [$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => 'Search: Field Subject / Operator CONTAINS / Value substr($Subject2,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'CONTAINS',
                    Value    => substr($Subject2,2,-2)
                }
            ]
        },
        Expected => [$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => 'Search: Field Subject / Operator LIKE / Value $Subject3',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'LIKE',
                    Value    => $Subject3
                }
            ]
        },
        Expected => [$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => 'Search: Field Issuer / Operator EQ / Value $Issuer2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Issuer',
                    Operator => 'EQ',
                    Value    => $Issuer2
                }
            ]
        },
        Expected => [$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field Issuer / Operator EQ / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Issuer',
                    Operator => 'EQ',
                    Value    => q{}
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field Issuer / Operator NE / Value $Issuer2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Issuer',
                    Operator => 'NE',
                    Value    => $Issuer2
                }
            ]
        },
        Expected => [$CertID1,$CertID2]
    },
    {
        Name     => 'Search: Field Issuer / Operator NE / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Issuer',
                    Operator => 'NE',
                    Value    => q{}
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field Issuer / Operator IN / Value [$Issuer1,$Issuer3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Issuer',
                    Operator => 'IN',
                    Value    => [$Issuer1,$Issuer3]
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field Issuer / Operator !IN / Value [$Issuer1,$Issuer3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Issuer',
                    Operator => '!IN',
                    Value    => [$Issuer1,$Issuer3]
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field Issuer / Operator STARTSWITH / Value $Issuer2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Issuer',
                    Operator => 'STARTSWITH',
                    Value    => $Issuer2
                }
            ]
        },
        Expected => [$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field Issuer / Operator STARTSWITH / Value substr($Issuer2,0,4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Issuer',
                    Operator => 'STARTSWITH',
                    Value    => substr($Issuer2,0,4)
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field Issuer / Operator ENDSWITH / Value $Issuer2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Issuer',
                    Operator => 'ENDSWITH',
                    Value    => $Issuer2
                }
            ]
        },
        Expected => [$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field Issuer / Operator ENDSWITH / Value substr($Issuer2,-5)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Issuer',
                    Operator => 'ENDSWITH',
                    Value    => substr($Issuer2,-5)
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field Issuer / Operator CONTAINS / Value $Issuer2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Issuer',
                    Operator => 'CONTAINS',
                    Value    => $Issuer2
                }
            ]
        },
        Expected => [$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field Issuer / Operator CONTAINS / Value substr($Issuer2,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Issuer',
                    Operator => 'CONTAINS',
                    Value    => substr($Issuer2,2,-2)
                }
            ]
        },
        Expected => [$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field Issuer / Operator LIKE / Value $Issuer2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Issuer',
                    Operator => 'LIKE',
                    Value    => $Issuer2
                }
            ]
        },
        Expected => [$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field Email / Operator EQ / Value $Email2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Email',
                    Operator => 'EQ',
                    Value    => $Email2
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field Email / Operator EQ / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Email',
                    Operator => 'EQ',
                    Value    => q{}
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field Email / Operator NE / Value $Email2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Email',
                    Operator => 'NE',
                    Value    => $Email2
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field Email / Operator NE / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Email',
                    Operator => 'NE',
                    Value    => q{}
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field Email / Operator IN / Value [$Email1,$Email3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Email',
                    Operator => 'IN',
                    Value    => [$Email1,$Email3]
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field Email / Operator !IN / Value [$Email1,$Email3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Email',
                    Operator => '!IN',
                    Value    => [$Email1,$Email3]
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field Email / Operator STARTSWITH / Value $Email2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Email',
                    Operator => 'STARTSWITH',
                    Value    => $Email2
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field Email / Operator STARTSWITH / Value substr($Email2,0,4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Email',
                    Operator => 'STARTSWITH',
                    Value    => substr($Email2,0,4)
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field Email / Operator ENDSWITH / Value $Email2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Email',
                    Operator => 'ENDSWITH',
                    Value    => $Email2
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field Email / Operator ENDSWITH / Value substr($Email2,-5)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Email',
                    Operator => 'ENDSWITH',
                    Value    => substr($Email2,-5)
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field Email / Operator CONTAINS / Value $Email2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Email',
                    Operator => 'CONTAINS',
                    Value    => $Email2
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field Email / Operator CONTAINS / Value substr($Email2,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Email',
                    Operator => 'CONTAINS',
                    Value    => substr($Email2,2,-2)
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field Email / Operator LIKE / Value $Email2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Email',
                    Operator => 'LIKE',
                    Value    => $Email2
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field CType / Operator EQ / Value $CType1',
        Search   => {
            'AND' => [
                {
                    Field    => 'CType',
                    Operator => 'EQ',
                    Value    => $CType1
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => 'Search: Field CType / Operator EQ / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'CType',
                    Operator => 'EQ',
                    Value    => q{}
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field CType / Operator NE / Value $CType1',
        Search   => {
            'AND' => [
                {
                    Field    => 'CType',
                    Operator => 'NE',
                    Value    => $CType1
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field CType / Operator NE / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'CType',
                    Operator => 'NE',
                    Value    => q{}
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => 'Search: Field CType / Operator IN / Value [$CType1,$CType2]',
        Search   => {
            'AND' => [
                {
                    Field    => 'CType',
                    Operator => 'IN',
                    Value    => [$CType1,$CType2]
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => 'Search: Field CType / Operator !IN / Value [$CType1,$CType2]',
        Search   => {
            'AND' => [
                {
                    Field    => 'CType',
                    Operator => '!IN',
                    Value    => [$CType1,$CType2]
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field Type / Operator EQ / Value $Type1',
        Search   => {
            'AND' => [
                {
                    Field    => 'Type',
                    Operator => 'EQ',
                    Value    => $Type1
                }
            ]
        },
        Expected => [$CertID1,$CertID3,$CertID4]
    },
    {
        Name     => 'Search: Field Type / Operator EQ / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Type',
                    Operator => 'EQ',
                    Value    => q{}
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field Type / Operator NE / Value $Type2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Type',
                    Operator => 'NE',
                    Value    => $Type2
                }
            ]
        },
        Expected => [$CertID1,$CertID3,$CertID4]
    },
    {
        Name     => 'Search: Field Type / Operator NE / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Type',
                    Operator => 'NE',
                    Value    => q{}
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => 'Search: Field Type / Operator IN / Value [$Type1,$Type2]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Type',
                    Operator => 'IN',
                    Value    => [$Type1,$Type2]
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => 'Search: Field Type / Operator !IN / Value [$Type1,$Type2]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Type',
                    Operator => '!IN',
                    Value    => [$Type1,$Type2]
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field Fingerprint / Operator EQ / Value $Fingerprint2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Fingerprint',
                    Operator => 'EQ',
                    Value    => $Fingerprint2
                }
            ]
        },
        Expected => [$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field Fingerprint / Operator EQ / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Fingerprint',
                    Operator => 'EQ',
                    Value    => q{}
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field Fingerprint / Operator NE / Value $Fingerprint2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Fingerprint',
                    Operator => 'NE',
                    Value    => $Fingerprint2
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID4]
    },
    {
        Name     => 'Search: Field Fingerprint / Operator NE / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Fingerprint',
                    Operator => 'NE',
                    Value    => q{}
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => 'Search: Field Fingerprint / Operator IN / Value [$Fingerprint1,$Fingerprint3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Fingerprint',
                    Operator => 'IN',
                    Value    => [$Fingerprint1,$Fingerprint3]
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID4]
    },
    {
        Name     => 'Search: Field Fingerprint / Operator !IN / Value [$Fingerprint1,$Fingerprint3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Fingerprint',
                    Operator => '!IN',
                    Value    => [$Fingerprint1,$Fingerprint3]
                }
            ]
        },
        Expected => [$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field Modulus / Operator EQ / Value $Modulus2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Modulus',
                    Operator => 'EQ',
                    Value    => $Modulus2
                }
            ]
        },
        Expected => [$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => 'Search: Field Modulus / Operator EQ / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Modulus',
                    Operator => 'EQ',
                    Value    => q{}
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field Modulus / Operator NE / Value $Modulus2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Modulus',
                    Operator => 'NE',
                    Value    => $Modulus2
                }
            ]
        },
        Expected => [$CertID1,$CertID2]
    },
    {
        Name     => 'Search: Field Modulus / Operator NE / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Modulus',
                    Operator => 'NE',
                    Value    => q{}
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => 'Search: Field Modulus / Operator IN / Value [$Modulus1,$Modulus3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Modulus',
                    Operator => 'IN',
                    Value    => [$Modulus1,$Modulus3]
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => 'Search: Field Modulus / Operator !IN / Value [$Modulus1,$Modulus3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Modulus',
                    Operator => '!IN',
                    Value    => [$Modulus1,$Modulus3]
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field Hash / Operator EQ / Value $Hash2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Hash',
                    Operator => 'EQ',
                    Value    => $Hash2
                }
            ]
        },
        Expected => [$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field Hash / Operator EQ / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Hash',
                    Operator => 'EQ',
                    Value    => q{}
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field Hash / Operator NE / Value $Hash2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Hash',
                    Operator => 'NE',
                    Value    => $Hash2
                }
            ]
        },
        Expected => [$CertID1,$CertID2]
    },
    {
        Name     => 'Search: Field Hash / Operator NE / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Hash',
                    Operator => 'NE',
                    Value    => q{}
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field Hash / Operator IN / Value [$Hash1,$Hash3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Hash',
                    Operator => 'IN',
                    Value    => [$Hash1,$Hash3]
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field Hash / Operator !IN / Value [$Hash1,$Hash3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Hash',
                    Operator => '!IN',
                    Value    => [$Hash1,$Hash3]
                }
            ]
        },
        Expected => []
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Certificate',
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
        Name     => 'Sort: Field Subject',
        Sort     => [
            {
                Field => 'Subject'
            }
        ],
        Expected => [$CertID3,$CertID4,$CertID5,$CertID1,$CertID2]
    },
    {
        Name     => 'Sort: Field Subject / Direction ascending',
        Sort     => [
            {
                Field     => 'Subject',
                Direction => 'ascending'
            }
        ],
        Expected => [$CertID3,$CertID4,$CertID5,$CertID1,$CertID2]
    },
    {
        Name     => 'Sort: Field Subject / Direction descending',
        Sort     => [
            {
                Field     => 'Subject',
                Direction => 'descending'
            }
        ],
        Expected => [$CertID1,$CertID2,$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => 'Sort: Field Issuer',
        Sort     => [
            {
                Field => 'Issuer'
            }
        ],
        Expected => [$CertID3,$CertID5,$CertID1,$CertID2]
    },
    {
        Name     => 'Sort: Field Issuer / Direction ascending',
        Sort     => [
            {
                Field     => 'Issuer',
                Direction => 'ascending'
            }
        ],
        Expected => [$CertID3,$CertID5,$CertID1,$CertID2]
    },
    {
        Name     => 'Sort: Field Issuer / Direction descending',
        Sort     => [
            {
                Field     => 'Issuer',
                Direction => 'descending'
            }
        ],
        Expected => [$CertID1,$CertID2,$CertID3,$CertID5]
    },
    {
        Name     => 'Sort: Field Email',
        Sort     => [
            {
                Field => 'Email'
            }
        ],
        Expected => [$CertID1,$CertID2,$CertID3,$CertID5]
    },
    {
        Name     => 'Sort: Field Email / Direction ascending',
        Sort     => [
            {
                Field     => 'Email',
                Direction => 'ascending'
            }
        ],
        Expected => [$CertID1,$CertID2,$CertID3,$CertID5]
    },
    {
        Name     => 'Sort: Field Email / Direction descending',
        Sort     => [
            {
                Field     => 'Email',
                Direction => 'descending'
            }
        ],
        Expected => [$CertID1,$CertID2,$CertID3,$CertID5]
    },
    {
        Name     => 'Sort: Field CType',
        Sort     => [
            {
                Field => 'CType'
            }
        ],
        Expected => [$CertID1,$CertID2,$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => 'Sort: Field CType / Direction ascending',
        Sort     => [
            {
                Field     => 'CType',
                Direction => 'ascending'
            }
        ],
        Expected => [$CertID1,$CertID2,$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => 'Sort: Field CType / Direction descending',
        Sort     => [
            {
                Field     => 'CType',
                Direction => 'descending'
            }
        ],
        Expected => [$CertID1,$CertID2,$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => 'Sort: Field Type',
        Sort     => [
            {
                Field => 'Type'
            }
        ],
        Expected => [$CertID1,$CertID3,$CertID4,$CertID2,$CertID5]
    },
    {
        Name     => 'Sort: Field Type / Direction ascending',
        Sort     => [
            {
                Field     => 'Type',
                Direction => 'ascending'
            }
        ],
        Expected => [$CertID1,$CertID3,$CertID4,$CertID2,$CertID5]
    },
    {
        Name     => 'Sort: Field Type / Direction descending',
        Sort     => [
            {
                Field     => 'Type',
                Direction => 'descending'
            }
        ],
        Expected => [$CertID2,$CertID5,$CertID1,$CertID3,$CertID4]
    },
    {
        Name     => 'Sort: Field Fingerprint',
        Sort     => [
            {
                Field => 'Fingerprint'
            }
        ],
        Expected => [$CertID1, $CertID2,$CertID3,$CertID5,$CertID4]
    },
    {
        Name     => 'Sort: Field Fingerprint / Direction ascending',
        Sort     => [
            {
                Field     => 'Fingerprint',
                Direction => 'ascending'
            }
        ],
        Expected => [$CertID1, $CertID2,$CertID3,$CertID5,$CertID4]
    },
    {
        Name     => 'Sort: Field Fingerprint / Direction descending',
        Sort     => [
            {
                Field     => 'Fingerprint',
                Direction => 'descending'
            }
        ],
        Expected => [$CertID4,$CertID3,$CertID5,$CertID1,$CertID2]
    },
    {
        Name     => 'Sort: Field Modulus',
        Sort     => [
            {
                Field => 'Modulus'
            }
        ],
        Expected => [$CertID1,$CertID2,$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => 'Sort: Field Modulus / Direction ascending',
        Sort     => [
            {
                Field     => 'Modulus',
                Direction => 'ascending'
            }
        ],
        Expected => [$CertID1,$CertID2,$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => 'Sort: Field Modulus / Direction descending',
        Sort     => [
            {
                Field     => 'Modulus',
                Direction => 'descending'
            }
        ],
        Expected => [$CertID3,$CertID4,$CertID5,$CertID1,$CertID2]
    },
    {
        Name     => 'Sort: Field Hash',
        Sort     => [
            {
                Field => 'Hash'
            }
        ],
        Expected => [$CertID1,$CertID2,$CertID3,$CertID5]
    },
    {
        Name     => 'Sort: Field Hash / Direction ascending',
        Sort     => [
            {
                Field     => 'Hash',
                Direction => 'ascending'
            }
        ],
        Expected => [$CertID1,$CertID2,$CertID3,$CertID5]
    },
    {
        Name     => 'Sort: Field Hash / Direction descending',
        Sort     => [
            {
                Field     => 'Hash',
                Direction => 'descending'
            }
        ],
        Expected => [$CertID3,$CertID5,$CertID1,$CertID2]
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Certificate',
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

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
