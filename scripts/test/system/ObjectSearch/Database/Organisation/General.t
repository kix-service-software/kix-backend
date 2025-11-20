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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Organisation::General';

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
        Name => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Number => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Street => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EMPTY','EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        City => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EMPTY','EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Zip => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EMPTY','EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Country => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EMPTY','EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Url => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EMPTY','EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Comment => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EMPTY','EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
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
            Field    => 'Name',
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
            Field    => 'Name',
            Operator => undef,
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'Name',
            Operator => 'Test',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field Name / Operator EQ',
        Search       => {
            Field    => 'Name',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.name) = \'test\'' : 'o.name = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator EQ / Value empty string',
        Search       => {
            Field    => 'Name',
            Operator => 'EQ',
            Value    => ''
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.name) = \'\'' : 'o.name = \'\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator NE',
        Search       => {
            Field    => 'Name',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.name) != \'test\'' : 'o.name != \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator NE / Value empty string',
        Search       => {
            Field    => 'Name',
            Operator => 'NE',
            Value    => ''
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.name) != \'\'' : 'o.name != \'\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator IN',
        Search       => {
            Field    => 'Name',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.name) IN (\'test\')' : 'o.name IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator !IN',
        Search       => {
            Field    => 'Name',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.name) NOT IN (\'test\')' : 'o.name NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator STARTSWITH',
        Search       => {
            Field    => 'Name',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.name) LIKE \'test%\'' : 'o.name LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator ENDSWITH',
        Search       => {
            Field    => 'Name',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.name) LIKE \'%test\'' : 'o.name LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator CONTAINS',
        Search       => {
            Field    => 'Name',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.name) LIKE \'%test%\'' : 'o.name LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator LIKE',
        Search       => {
            Field    => 'Name',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.name) LIKE \'test\'' : 'o.name LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Number / Operator EQ',
        Search       => {
            Field    => 'Number',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.number) = \'test\'' : 'o.number = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Number / Operator EQ / Value empty string',
        Search       => {
            Field    => 'Number',
            Operator => 'EQ',
            Value    => ''
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.number) = \'\'' : 'o.number = \'\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Number / Operator NE',
        Search       => {
            Field    => 'Number',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.number) != \'test\'' : 'o.number != \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Number / Operator NE / Value empty string',
        Search       => {
            Field    => 'Number',
            Operator => 'NE',
            Value    => ''
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.number) != \'\'' : 'o.number != \'\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Number / Operator IN',
        Search       => {
            Field    => 'Number',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.number) IN (\'test\')' : 'o.number IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Number / Operator !IN',
        Search       => {
            Field    => 'Number',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.number) NOT IN (\'test\')' : 'o.number NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Number / Operator STARTSWITH',
        Search       => {
            Field    => 'Number',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.number) LIKE \'test%\'' : 'o.number LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Number / Operator ENDSWITH',
        Search       => {
            Field    => 'Number',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.number) LIKE \'%test\'' : 'o.number LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Number / Operator CONTAINS',
        Search       => {
            Field    => 'Number',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.number) LIKE \'%test%\'' : 'o.number LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Number / Operator LIKE',
        Search       => {
            Field    => 'Number',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.number) LIKE \'test\'' : 'o.number LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Street / Operator EQ',
        Search       => {
            Field    => 'Street',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.street) = \'test\'' : 'o.street = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Street / Operator EQ / Value empty string',
        Search       => {
            Field    => 'Street',
            Operator => 'EQ',
            Value    => ''
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(o.street) = \'\' OR o.street IS NULL)' : '(o.street = \'\' OR o.street IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Street / Operator NE',
        Search       => {
            Field    => 'Street',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(o.street) != \'test\' OR o.street IS NULL)' : '(o.street != \'test\' OR o.street IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Street / Operator NE / Value empty string',
        Search       => {
            Field    => 'Street',
            Operator => 'NE',
            Value    => ''
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.street) != \'\'' : 'o.street != \'\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Street / Operator IN',
        Search       => {
            Field    => 'Street',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.street) IN (\'test\')' : 'o.street IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Street / Operator !IN',
        Search       => {
            Field    => 'Street',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.street) NOT IN (\'test\')' : 'o.street NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Street / Operator STARTSWITH',
        Search       => {
            Field    => 'Street',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.street) LIKE \'test%\'' : 'o.street LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Street / Operator ENDSWITH',
        Search       => {
            Field    => 'Street',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.street) LIKE \'%test\'' : 'o.street LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Street / Operator CONTAINS',
        Search       => {
            Field    => 'Street',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.street) LIKE \'%test%\'' : 'o.street LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Street / Operator LIKE',
        Search       => {
            Field    => 'Street',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.street) LIKE \'test\'' : 'o.street LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Street / Operator EMPTY / Value 1',
        Search       => {
            Field    => 'Street',
            Operator => 'EMPTY',
            Value    => 1
        },
        Expected     => {
            'Where' => [
                "(o.street = '' OR o.street IS NULL)"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Street / Operator EMPTY / Value 0',
        Search       => {
            Field    => 'Street',
            Operator => 'EMPTY',
            Value    => 0
        },
        Expected     => {
            'Where' => [
                "(o.street != '' AND o.street IS NOT NULL)"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field City / Operator EQ',
        Search       => {
            Field    => 'City',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.city) = \'test\'' : 'o.city = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field City / Operator EQ / Value empty string',
        Search       => {
            Field    => 'City',
            Operator => 'EQ',
            Value    => ''
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(o.city) = \'\' OR o.city IS NULL)' : '(o.city = \'\' OR o.city IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field City / Operator NE',
        Search       => {
            Field    => 'City',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(o.city) != \'test\' OR o.city IS NULL)' : '(o.city != \'test\' OR o.city IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field City / Operator NE / Value empty string',
        Search       => {
            Field    => 'City',
            Operator => 'NE',
            Value    => ''
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.city) != \'\'' : 'o.city != \'\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field City / Operator IN',
        Search       => {
            Field    => 'City',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.city) IN (\'test\')' : 'o.city IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field City / Operator !IN',
        Search       => {
            Field    => 'City',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.city) NOT IN (\'test\')' : 'o.city NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field City / Operator STARTSWITH',
        Search       => {
            Field    => 'City',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.city) LIKE \'test%\'' : 'o.city LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field City / Operator ENDSWITH',
        Search       => {
            Field    => 'City',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.city) LIKE \'%test\'' : 'o.city LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field City / Operator CONTAINS',
        Search       => {
            Field    => 'City',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.city) LIKE \'%test%\'' : 'o.city LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field City / Operator LIKE',
        Search       => {
            Field    => 'City',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.city) LIKE \'test\'' : 'o.city LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field City / Operator EMPTY / Value 1',
        Search       => {
            Field    => 'City',
            Operator => 'EMPTY',
            Value    => 1
        },
        Expected     => {
            'Where' => [
                "(o.city = '' OR o.city IS NULL)"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field City / Operator EMPTY / Value 0',
        Search       => {
            Field    => 'City',
            Operator => 'EMPTY',
            Value    => 0
        },
        Expected     => {
            'Where' => [
                "(o.city != '' AND o.city IS NOT NULL)"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Zip / Operator EQ',
        Search       => {
            Field    => 'Zip',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.zip) = \'test\'' : 'o.zip = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Zip / Operator EQ / Value empty string',
        Search       => {
            Field    => 'Zip',
            Operator => 'EQ',
            Value    => ''
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(o.zip) = \'\' OR o.zip IS NULL)' : '(o.zip = \'\' OR o.zip IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Zip / Operator NE',
        Search       => {
            Field    => 'Zip',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(o.zip) != \'test\' OR o.zip IS NULL)' : '(o.zip != \'test\' OR o.zip IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Zip / Operator NE / Value empty string',
        Search       => {
            Field    => 'Zip',
            Operator => 'NE',
            Value    => ''
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.zip) != \'\'' : 'o.zip != \'\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Zip / Operator IN',
        Search       => {
            Field    => 'Zip',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.zip) IN (\'test\')' : 'o.zip IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Zip / Operator !IN',
        Search       => {
            Field    => 'Zip',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.zip) NOT IN (\'test\')' : 'o.zip NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Zip / Operator STARTSWITH',
        Search       => {
            Field    => 'Zip',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.zip) LIKE \'test%\'' : 'o.zip LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Zip / Operator ENDSWITH',
        Search       => {
            Field    => 'Zip',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.zip) LIKE \'%test\'' : 'o.zip LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Zip / Operator CONTAINS',
        Search       => {
            Field    => 'Zip',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.zip) LIKE \'%test%\'' : 'o.zip LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Zip / Operator LIKE',
        Search       => {
            Field    => 'Zip',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.zip) LIKE \'test\'' : 'o.zip LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Zip / Operator EMPTY / Value 1',
        Search       => {
            Field    => 'Zip',
            Operator => 'EMPTY',
            Value    => 1
        },
        Expected     => {
            'Where' => [
                "(o.zip = '' OR o.zip IS NULL)"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Zip / Operator EMPTY / Value 0',
        Search       => {
            Field    => 'Zip',
            Operator => 'EMPTY',
            Value    => 0
        },
        Expected     => {
            'Where' => [
                "(o.zip != '' AND o.zip IS NOT NULL)"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Country / Operator EQ',
        Search       => {
            Field    => 'Country',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.country) = \'test\'' : 'o.country = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Country / Operator EQ / Value empty string',
        Search       => {
            Field    => 'Country',
            Operator => 'EQ',
            Value    => ''
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(o.country) = \'\' OR o.country IS NULL)' : '(o.country = \'\' OR o.country IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Country / Operator NE',
        Search       => {
            Field    => 'Country',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(o.country) != \'test\' OR o.country IS NULL)' : '(o.country != \'test\' OR o.country IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Country / Operator NE / Value empty string',
        Search       => {
            Field    => 'Country',
            Operator => 'NE',
            Value    => ''
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.country) != \'\'' : 'o.country != \'\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Country / Operator IN',
        Search       => {
            Field    => 'Country',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.country) IN (\'test\')' : 'o.country IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Country / Operator !IN',
        Search       => {
            Field    => 'Country',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.country) NOT IN (\'test\')' : 'o.country NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Country / Operator STARTSWITH',
        Search       => {
            Field    => 'Country',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.country) LIKE \'test%\'' : 'o.country LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Country / Operator ENDSWITH',
        Search       => {
            Field    => 'Country',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.country) LIKE \'%test\'' : 'o.country LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Country / Operator CONTAINS',
        Search       => {
            Field    => 'Country',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.country) LIKE \'%test%\'' : 'o.country LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Country / Operator LIKE',
        Search       => {
            Field    => 'Country',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.country) LIKE \'test\'' : 'o.country LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Country / Operator EMPTY / Value 1',
        Search       => {
            Field    => 'Country',
            Operator => 'EMPTY',
            Value    => 1
        },
        Expected     => {
            'Where' => [
                "(o.country = '' OR o.country IS NULL)"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Country / Operator EMPTY / Value 0',
        Search       => {
            Field    => 'Country',
            Operator => 'EMPTY',
            Value    => 0
        },
        Expected     => {
            'Where' => [
                "(o.country != '' AND o.country IS NOT NULL)"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Url / Operator EQ',
        Search       => {
            Field    => 'Url',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.url) = \'test\'' : 'o.url = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Url / Operator EQ / Value empty string',
        Search       => {
            Field    => 'Url',
            Operator => 'EQ',
            Value    => ''
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(o.url) = \'\' OR o.url IS NULL)' : '(o.url = \'\' OR o.url IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Url / Operator NE',
        Search       => {
            Field    => 'Url',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(o.url) != \'test\' OR o.url IS NULL)' : '(o.url != \'test\' OR o.url IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Url / Operator NE / Value empty string',
        Search       => {
            Field    => 'Url',
            Operator => 'NE',
            Value    => ''
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.url) != \'\'' : 'o.url != \'\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Url / Operator IN',
        Search       => {
            Field    => 'Url',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.url) IN (\'test\')' : 'o.url IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Url / Operator !IN',
        Search       => {
            Field    => 'Url',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.url) NOT IN (\'test\')' : 'o.url NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Url / Operator STARTSWITH',
        Search       => {
            Field    => 'Url',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.url) LIKE \'test%\'' : 'o.url LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Url / Operator ENDSWITH',
        Search       => {
            Field    => 'Url',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.url) LIKE \'%test\'' : 'o.url LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Url / Operator CONTAINS',
        Search       => {
            Field    => 'Url',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.url) LIKE \'%test%\'' : 'o.url LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Url / Operator LIKE',
        Search       => {
            Field    => 'Url',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.url) LIKE \'test\'' : 'o.url LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Url / Operator EMPTY / Value 1',
        Search       => {
            Field    => 'Url',
            Operator => 'EMPTY',
            Value    => 1
        },
        Expected     => {
            'Where' => [
                "(o.url = '' OR o.url IS NULL)"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Url / Operator EMPTY / Value 0',
        Search       => {
            Field    => 'Url',
            Operator => 'EMPTY',
            Value    => 0
        },
        Expected     => {
            'Where' => [
                "(o.url != '' AND o.url IS NOT NULL)"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Comment / Operator EQ',
        Search       => {
            Field    => 'Comment',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.comments) = \'test\'' : 'o.comments = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Comment / Operator EQ / Value empty string',
        Search       => {
            Field    => 'Comment',
            Operator => 'EQ',
            Value    => ''
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(o.comments) = \'\' OR o.comments IS NULL)' : '(o.comments = \'\' OR o.comments IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Comment / Operator NE',
        Search       => {
            Field    => 'Comment',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(o.comments) != \'test\' OR o.comments IS NULL)' : '(o.comments != \'test\' OR o.comments IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Comment / Operator NE / Value empty string',
        Search       => {
            Field    => 'Comment',
            Operator => 'NE',
            Value    => ''
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.comments) != \'\'' : 'o.comments != \'\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Comment / Operator IN',
        Search       => {
            Field    => 'Comment',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.comments) IN (\'test\')' : 'o.comments IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Comment / Operator !IN',
        Search       => {
            Field    => 'Comment',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.comments) NOT IN (\'test\')' : 'o.comments NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Comment / Operator STARTSWITH',
        Search       => {
            Field    => 'Comment',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.comments) LIKE \'test%\'' : 'o.comments LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Comment / Operator ENDSWITH',
        Search       => {
            Field    => 'Comment',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.comments) LIKE \'%test\'' : 'o.comments LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Comment / Operator CONTAINS',
        Search       => {
            Field    => 'Comment',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.comments) LIKE \'%test%\'' : 'o.comments LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Comment / Operator LIKE',
        Search       => {
            Field    => 'Comment',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(o.comments) LIKE \'test\'' : 'o.comments LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Comment / Operator EMPTY / Value 1',
        Search       => {
            Field    => 'Comment',
            Operator => 'EMPTY',
            Value    => 1
        },
        Expected     => {
            'Where' => [
                "(o.comments = '' OR o.comments IS NULL)"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Comment / Operator EMPTY / Value 0',
        Search       => {
            Field    => 'Comment',
            Operator => 'EMPTY',
            Value    => 0
        },
        Expected     => {
            'Where' => [
                "(o.comments != '' AND o.comments IS NOT NULL)"
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
        Name      => 'Sort: Attribute "Name"',
        Attribute => 'Name',
        Expected  => {
            'Select'  => ['o.name'],
            'OrderBy' => ['LOWER(o.name)']
        }
    },
    {
        Name      => 'Sort: Attribute "Number"',
        Attribute => 'Number',
        Expected  => {
            'Select'  => ['o.number'],
            'OrderBy' => ['LOWER(o.number)']
        }
    },
    {
        Name      => 'Sort: Attribute "Street"',
        Attribute => 'Street',
        Expected  => {
            'Select'  => ['LOWER(COALESCE(o.street,\'\')) AS SortStreet'],
            'OrderBy' => ['SortStreet']
        }
    },
    {
        Name      => 'Sort: Attribute "City"',
        Attribute => 'City',
        Expected  => {
            'Select'  => ['LOWER(COALESCE(o.city,\'\')) AS SortCity'],
            'OrderBy' => ['SortCity']
        }
    },
    {
        Name      => 'Sort: Attribute "Zip"',
        Attribute => 'Zip',
        Expected  => {
            'Select'  => ['LOWER(COALESCE(o.zip,\'\')) AS SortZip'],
            'OrderBy' => ['SortZip']
        }
    },
    {
        Name      => 'Sort: Attribute "Country"',
        Attribute => 'Country',
        Expected  => {
            'Select'  => ['LOWER(COALESCE(o.country,\'\')) AS SortCountry'],
            'OrderBy' => ['SortCountry']
        }
    },
    {
        Name      => 'Sort: Attribute "Url"',
        Attribute => 'Url',
        Expected  => {
            'Select'  => ['LOWER(COALESCE(o.url,\'\')) AS SortUrl'],
            'OrderBy' => ['SortUrl']
        }
    },
    {
        Name      => 'Sort: Attribute "Comment"',
        Attribute => 'Comment',
        Expected  => {
            'Select'  => ['LOWER(COALESCE(o.comments,\'\')) AS SortComment'],
            'OrderBy' => ['SortComment']
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
my $TestData1 = 'Test001';
my $TestData2 = 'test002';
my $TestData3 = 'Test003';
my $TestData4 = 'Test004';

# first organisation
my $OrganisationID1 = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => $TestData1,
    Name    => $TestData1,
    Street  => $TestData1,
    Zip     => $TestData1,
    City    => $TestData1,
    Country => $TestData1,
    Url     => $TestData1,
    Comment => $TestData1,
    UserID  => 1
);
$Self->True(
    $OrganisationID1,
    'Created first organisation'
);
# second organisation
my $OrganisationID2 = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => $TestData2,
    Name    => $TestData2,
    Street  => $TestData2,
    Zip     => $TestData2,
    City    => $TestData2,
    Country => $TestData2,
    Url     => $TestData2,
    Comment => $TestData2,
    UserID  => 1
);
$Self->True(
    $OrganisationID2,
    'Created second organisation'
);
# third organisation
my $OrganisationID3 = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => $TestData3,
    Name    => $TestData3,
    Street  => $TestData3,
    Zip     => $TestData3,
    City    => $TestData3,
    Country => $TestData3,
    Url     => $TestData3,
    Comment => $TestData3,
    UserID  => 1
);
$Self->True(
    $OrganisationID3,
    'Created third organisation'
);
# fourth organisation
my $OrganisationID4 = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => $TestData4,
    Name    => $TestData4,
    UserID  => 1
);
$Self->True(
    $OrganisationID4,
    'Created fourth organisation without optional parameter'
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Organisation'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field Name / Operator EQ / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'EQ',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Name / Operator EQ / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'EQ',
                    Value    => ''
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field Name / Operator NE / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'NE',
                    Value    => $TestData2
                }
            ]
        },
        Expected => ['1',$OrganisationID1,$OrganisationID3,$OrganisationID4]
    },
    {
        Name     => 'Search: Field Name / Operator NE / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'NE',
                    Value    => ''
                }
            ]
        },
        Expected => ['1',$OrganisationID1,$OrganisationID2,$OrganisationID3,$OrganisationID4]
    },
    {
        Name     => 'Search: Field Name / Operator IN / Value [$TestData1,$TestData3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'IN',
                    Value    => [$TestData1,$TestData3]
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID3]
    },
    {
        Name     => 'Search: Field Name / Operator !IN / Value [$TestData1,$TestData3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => '!IN',
                    Value    => [$TestData1,$TestData3]
                }
            ]
        },
        Expected => ['1',$OrganisationID2,$OrganisationID4]
    },
    {
        Name     => 'Search: Field Name / Operator STARTSWITH / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'STARTSWITH',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Name / Operator STARTSWITH / Value substr($TestData2,0,4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'STARTSWITH',
                    Value    => substr($TestData2,0,4)
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3,$OrganisationID4]
    },
    {
        Name     => 'Search: Field Name / Operator ENDSWITH / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'ENDSWITH',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Name / Operator ENDSWITH / Value substr($TestData2,-5)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'ENDSWITH',
                    Value    => substr($TestData2,-5)
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Name / Operator CONTAINS / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'CONTAINS',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Name / Operator CONTAINS / Value substr($TestData2,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'CONTAINS',
                    Value    => substr($TestData2,2,-2)
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3,$OrganisationID4]
    },
    {
        Name     => 'Search: Field Name / Operator LIKE / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'LIKE',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Number / Operator EQ / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'EQ',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Number / Operator EQ / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'EQ',
                    Value    => ''
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field Number / Operator NE / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'NE',
                    Value    => $TestData2
                }
            ]
        },
        Expected => ['1',$OrganisationID1,$OrganisationID3,$OrganisationID4]
    },
    {
        Name     => 'Search: Field Number / Operator NE / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'NE',
                    Value    => ''
                }
            ]
        },
        Expected => ['1',$OrganisationID1,$OrganisationID2,$OrganisationID3,$OrganisationID4]
    },
    {
        Name     => 'Search: Field Number / Operator IN / Value [$TestData1,$TestData3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'IN',
                    Value    => [$TestData1,$TestData3]
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID3]
    },
    {
        Name     => 'Search: Field Number / Operator !IN / Value [$TestData1,$TestData3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => '!IN',
                    Value    => [$TestData1,$TestData3]
                }
            ]
        },
        Expected => ['1',$OrganisationID2,$OrganisationID4]
    },
    {
        Name     => 'Search: Field Number / Operator STARTSWITH / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'STARTSWITH',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Number / Operator STARTSWITH / Value substr($TestData2,0,4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'STARTSWITH',
                    Value    => substr($TestData2,0,4)
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3,$OrganisationID4]
    },
    {
        Name     => 'Search: Field Number / Operator ENDSWITH / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'ENDSWITH',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Number / Operator ENDSWITH / Value substr($TestData2,-5)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'ENDSWITH',
                    Value    => substr($TestData2,-5)
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Number / Operator CONTAINS / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'CONTAINS',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Number / Operator CONTAINS / Value substr($TestData2,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'CONTAINS',
                    Value    => substr($TestData2,2,-2)
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3,$OrganisationID4]
    },
    {
        Name     => 'Search: Field Number / Operator LIKE / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'LIKE',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Street / Operator EQ / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Street',
                    Operator => 'EQ',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Street / Operator EQ / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Street',
                    Operator => 'EQ',
                    Value    => ''
                }
            ]
        },
        Expected => ['1',$OrganisationID4]
    },
    {
        Name     => 'Search: Field Street / Operator NE / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Street',
                    Operator => 'NE',
                    Value    => $TestData2
                }
            ]
        },
        Expected => ['1',$OrganisationID1,$OrganisationID3,$OrganisationID4]
    },
    {
        Name     => 'Search: Field Street / Operator NE / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Street',
                    Operator => 'NE',
                    Value    => ''
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Search: Field Street / Operator IN / Value [$TestData1,$TestData3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Street',
                    Operator => 'IN',
                    Value    => [$TestData1,$TestData3]
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID3]
    },
    {
        Name     => 'Search: Field Street / Operator !IN / Value [$TestData1,$TestData3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Street',
                    Operator => '!IN',
                    Value    => [$TestData1,$TestData3]
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Street / Operator STARTSWITH / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Street',
                    Operator => 'STARTSWITH',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Street / Operator STARTSWITH / Value substr($TestData2,0,4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Street',
                    Operator => 'STARTSWITH',
                    Value    => substr($TestData2,0,4)
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Search: Field Street / Operator ENDSWITH / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Street',
                    Operator => 'ENDSWITH',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Street / Operator ENDSWITH / Value substr($TestData2,-5)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Street',
                    Operator => 'ENDSWITH',
                    Value    => substr($TestData2,-5)
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Street / Operator CONTAINS / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Street',
                    Operator => 'CONTAINS',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Street / Operator CONTAINS / Value substr($TestData2,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Street',
                    Operator => 'CONTAINS',
                    Value    => substr($TestData2,2,-2)
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Search: Field Street / Operator LIKE / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Street',
                    Operator => 'LIKE',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Street / Operator EMPTY / Value 1',
        Search   => {
            'AND' => [
                {
                    Field    => 'Street',
                    Operator => 'EMPTY',
                    Value    => 1
                }
            ]
        },
        Expected => ['1',$OrganisationID4]
    },
    {
        Name     => 'Search: Field Street / Operator EMPTY / Value 0',
        Search   => {
            'AND' => [
                {
                    Field    => 'Street',
                    Operator => 'EMPTY',
                    Value    => 0
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Search: Field City / Operator EQ / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'City',
                    Operator => 'EQ',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field City / Operator EQ / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'City',
                    Operator => 'EQ',
                    Value    => ''
                }
            ]
        },
        Expected => ['1',$OrganisationID4]
    },
    {
        Name     => 'Search: Field City / Operator NE / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'City',
                    Operator => 'NE',
                    Value    => $TestData2
                }
            ]
        },
        Expected => ['1',$OrganisationID1,$OrganisationID3,$OrganisationID4]
    },
    {
        Name     => 'Search: Field City / Operator NE / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'City',
                    Operator => 'NE',
                    Value    => ''
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Search: Field City / Operator IN / Value [$TestData1,$TestData3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'City',
                    Operator => 'IN',
                    Value    => [$TestData1,$TestData3]
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID3]
    },
    {
        Name     => 'Search: Field City / Operator !IN / Value [$TestData1,$TestData3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'City',
                    Operator => '!IN',
                    Value    => [$TestData1,$TestData3]
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field City / Operator STARTSWITH / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'City',
                    Operator => 'STARTSWITH',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field City / Operator STARTSWITH / Value substr($TestData2,0,4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'City',
                    Operator => 'STARTSWITH',
                    Value    => substr($TestData2,0,4)
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Search: Field City / Operator ENDSWITH / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'City',
                    Operator => 'ENDSWITH',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field City / Operator ENDSWITH / Value substr($TestData2,-5)',
        Search   => {
            'AND' => [
                {
                    Field    => 'City',
                    Operator => 'ENDSWITH',
                    Value    => substr($TestData2,-5)
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field City / Operator CONTAINS / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'City',
                    Operator => 'CONTAINS',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field City / Operator CONTAINS / Value substr($TestData2,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'City',
                    Operator => 'CONTAINS',
                    Value    => substr($TestData2,2,-2)
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Search: Field City / Operator LIKE / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'City',
                    Operator => 'LIKE',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field City / Operator EMPTY / Value 1',
        Search   => {
            'AND' => [
                {
                    Field    => 'City',
                    Operator => 'EMPTY',
                    Value    => 1
                }
            ]
        },
        Expected => ['1',$OrganisationID4]
    },
    {
        Name     => 'Search: Field City / Operator EMPTY / Value 0',
        Search   => {
            'AND' => [
                {
                    Field    => 'City',
                    Operator => 'EMPTY',
                    Value    => 0
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Search: Field Zip / Operator EQ / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Zip',
                    Operator => 'EQ',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Zip / Operator EQ / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Zip',
                    Operator => 'EQ',
                    Value    => ''
                }
            ]
        },
        Expected => ['1',$OrganisationID4]
    },
    {
        Name     => 'Search: Field Zip / Operator NE / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Zip',
                    Operator => 'NE',
                    Value    => $TestData2
                }
            ]
        },
        Expected => ['1',$OrganisationID1,$OrganisationID3,$OrganisationID4]
    },
    {
        Name     => 'Search: Field Zip / Operator NE / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Zip',
                    Operator => 'NE',
                    Value    => ''
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Search: Field Zip / Operator IN / Value [$TestData1,$TestData3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Zip',
                    Operator => 'IN',
                    Value    => [$TestData1,$TestData3]
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID3]
    },
    {
        Name     => 'Search: Field Zip / Operator !IN / Value [$TestData1,$TestData3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Zip',
                    Operator => '!IN',
                    Value    => [$TestData1,$TestData3]
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Zip / Operator STARTSWITH / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Zip',
                    Operator => 'STARTSWITH',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Zip / Operator STARTSWITH / Value substr($TestData2,0,4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Zip',
                    Operator => 'STARTSWITH',
                    Value    => substr($TestData2,0,4)
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Search: Field Zip / Operator ENDSWITH / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Zip',
                    Operator => 'ENDSWITH',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Zip / Operator ENDSWITH / Value substr($TestData2,-5)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Zip',
                    Operator => 'ENDSWITH',
                    Value    => substr($TestData2,-5)
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Zip / Operator CONTAINS / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Zip',
                    Operator => 'CONTAINS',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Zip / Operator CONTAINS / Value substr($TestData2,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Zip',
                    Operator => 'CONTAINS',
                    Value    => substr($TestData2,2,-2)
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Search: Field Zip / Operator LIKE / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Zip',
                    Operator => 'LIKE',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Zip / Operator EMPTY / Value 1',
        Search   => {
            'AND' => [
                {
                    Field    => 'Zip',
                    Operator => 'EMPTY',
                    Value    => 1
                }
            ]
        },
        Expected => ['1',$OrganisationID4]
    },
    {
        Name     => 'Search: Field Zip / Operator EMPTY / Value 0',
        Search   => {
            'AND' => [
                {
                    Field    => 'Zip',
                    Operator => 'EMPTY',
                    Value    => 0
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Search: Field Country / Operator EQ / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Country',
                    Operator => 'EQ',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Country / Operator EQ / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Country',
                    Operator => 'EQ',
                    Value    => ''
                }
            ]
        },
        Expected => ['1',$OrganisationID4]
    },
    {
        Name     => 'Search: Field Country / Operator NE / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Country',
                    Operator => 'NE',
                    Value    => $TestData2
                }
            ]
        },
        Expected => ['1',$OrganisationID1,$OrganisationID3,$OrganisationID4]
    },
    {
        Name     => 'Search: Field Country / Operator NE / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Country',
                    Operator => 'NE',
                    Value    => ''
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Search: Field Country / Operator IN / Value [$TestData1,$TestData3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Country',
                    Operator => 'IN',
                    Value    => [$TestData1,$TestData3]
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID3]
    },
    {
        Name     => 'Search: Field Country / Operator !IN / Value [$TestData1,$TestData3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Country',
                    Operator => '!IN',
                    Value    => [$TestData1,$TestData3]
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Country / Operator STARTSWITH / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Country',
                    Operator => 'STARTSWITH',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Country / Operator STARTSWITH / Value substr($TestData2,0,4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Country',
                    Operator => 'STARTSWITH',
                    Value    => substr($TestData2,0,4)
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Search: Field Country / Operator ENDSWITH / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Country',
                    Operator => 'ENDSWITH',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Country / Operator ENDSWITH / Value substr($TestData2,-5)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Country',
                    Operator => 'ENDSWITH',
                    Value    => substr($TestData2,-5)
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Country / Operator CONTAINS / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Country',
                    Operator => 'CONTAINS',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Country / Operator CONTAINS / Value substr($TestData2,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Country',
                    Operator => 'CONTAINS',
                    Value    => substr($TestData2,2,-2)
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Search: Field Country / Operator LIKE / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Country',
                    Operator => 'LIKE',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Country / Operator EMPTY / Value 1',
        Search   => {
            'AND' => [
                {
                    Field    => 'Country',
                    Operator => 'EMPTY',
                    Value    => 1
                }
            ]
        },
        Expected => ['1',$OrganisationID4]
    },
    {
        Name     => 'Search: Field Country / Operator EMPTY / Value 0',
        Search   => {
            'AND' => [
                {
                    Field    => 'Country',
                    Operator => 'EMPTY',
                    Value    => 0
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Search: Field Url / Operator EQ / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Url',
                    Operator => 'EQ',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Url / Operator EQ / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Url',
                    Operator => 'EQ',
                    Value    => ''
                }
            ]
        },
        Expected => ['1',$OrganisationID4]
    },
    {
        Name     => 'Search: Field Url / Operator NE / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Url',
                    Operator => 'NE',
                    Value    => $TestData2
                }
            ]
        },
        Expected => ['1',$OrganisationID1,$OrganisationID3,$OrganisationID4]
    },
    {
        Name     => 'Search: Field Url / Operator NE / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Url',
                    Operator => 'NE',
                    Value    => ''
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Search: Field Url / Operator IN / Value [$TestData1,$TestData3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Url',
                    Operator => 'IN',
                    Value    => [$TestData1,$TestData3]
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID3]
    },
    {
        Name     => 'Search: Field Url / Operator !IN / Value [$TestData1,$TestData3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Url',
                    Operator => '!IN',
                    Value    => [$TestData1,$TestData3]
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Url / Operator STARTSWITH / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Url',
                    Operator => 'STARTSWITH',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Url / Operator STARTSWITH / Value substr($TestData2,0,4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Url',
                    Operator => 'STARTSWITH',
                    Value    => substr($TestData2,0,4)
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Search: Field Url / Operator ENDSWITH / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Url',
                    Operator => 'ENDSWITH',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Url / Operator ENDSWITH / Value substr($TestData2,-5)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Url',
                    Operator => 'ENDSWITH',
                    Value    => substr($TestData2,-5)
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Url / Operator CONTAINS / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Url',
                    Operator => 'CONTAINS',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Url / Operator CONTAINS / Value substr($TestData2,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Url',
                    Operator => 'CONTAINS',
                    Value    => substr($TestData2,2,-2)
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Search: Field Url / Operator LIKE / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Url',
                    Operator => 'LIKE',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Url / Operator EMPTY / Value 1',
        Search   => {
            'AND' => [
                {
                    Field    => 'Url',
                    Operator => 'EMPTY',
                    Value    => 1
                }
            ]
        },
        Expected => ['1',$OrganisationID4]
    },
    {
        Name     => 'Search: Field Url / Operator EMPTY / Value 0',
        Search   => {
            'AND' => [
                {
                    Field    => 'Url',
                    Operator => 'EMPTY',
                    Value    => 0
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Search: Field Comment / Operator EQ / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'EQ',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Comment / Operator EQ / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'EQ',
                    Value    => ''
                }
            ]
        },
        Expected => ['1',$OrganisationID4]
    },
    {
        Name     => 'Search: Field Comment / Operator NE / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'NE',
                    Value    => $TestData2
                }
            ]
        },
        Expected => ['1',$OrganisationID1,$OrganisationID3,$OrganisationID4]
    },
    {
        Name     => 'Search: Field Comment / Operator NE / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'NE',
                    Value    => ''
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Search: Field Comment / Operator IN / Value [$TestData1,$TestData3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'IN',
                    Value    => [$TestData1,$TestData3]
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID3]
    },
    {
        Name     => 'Search: Field Comment / Operator !IN / Value [$TestData1,$TestData3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => '!IN',
                    Value    => [$TestData1,$TestData3]
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Comment / Operator STARTSWITH / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'STARTSWITH',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Comment / Operator STARTSWITH / Value substr($TestData2,0,4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'STARTSWITH',
                    Value    => substr($TestData2,0,4)
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Search: Field Comment / Operator ENDSWITH / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'ENDSWITH',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Comment / Operator ENDSWITH / Value substr($TestData2,-5)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'ENDSWITH',
                    Value    => substr($TestData2,-5)
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Comment / Operator CONTAINS / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'CONTAINS',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Comment / Operator CONTAINS / Value substr($TestData2,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'CONTAINS',
                    Value    => substr($TestData2,2,-2)
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Search: Field Comment / Operator LIKE / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'LIKE',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Comment / Operator EMPTY / Value 1',
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'EMPTY',
                    Value    => 1
                }
            ]
        },
        Expected => ['1',$OrganisationID4]
    },
    {
        Name     => 'Search: Field Comment / Operator EMPTY / Value 0',
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'EMPTY',
                    Value    => 0
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3]
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Organisation',
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
        Name     => 'Sort: Field Name',
        Sort     => [
            {
                Field => 'Name'
            }
        ],
        Expected => ['1',$OrganisationID1,$OrganisationID2,$OrganisationID3,$OrganisationID4]
    },
    {
        Name     => 'Sort: Field Name / Direction ascending',
        Sort     => [
            {
                Field     => 'Name',
                Direction => 'ascending'
            }
        ],
        Expected => ['1',$OrganisationID1,$OrganisationID2,$OrganisationID3,$OrganisationID4]
    },
    {
        Name     => 'Sort: Field Name / Direction descending',
        Sort     => [
            {
                Field     => 'Name',
                Direction => 'descending'
            }
        ],
        Expected => [$OrganisationID4,$OrganisationID3,$OrganisationID2,$OrganisationID1,'1']
    },
    {
        Name     => 'Sort: Field Number',
        Sort     => [
            {
                Field => 'Number'
            }
        ],
        Expected => ['1',$OrganisationID1,$OrganisationID2,$OrganisationID3,$OrganisationID4]
    },
    {
        Name     => 'Sort: Field Number / Direction ascending',
        Sort     => [
            {
                Field     => 'Number',
                Direction => 'ascending'
            }
        ],
        Expected => ['1',$OrganisationID1,$OrganisationID2,$OrganisationID3,$OrganisationID4]
    },
    {
        Name     => 'Sort: Field Number / Direction descending',
        Sort     => [
            {
                Field     => 'Number',
                Direction => 'descending'
            }
        ],
        Expected => [$OrganisationID4,$OrganisationID3,$OrganisationID2,$OrganisationID1,'1']
    },
    {
        Name     => 'Sort: Field Street',
        Sort     => [
            {
                Field => 'Street'
            }
        ],
        Expected => ['1',$OrganisationID4,$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Sort: Field Street / Direction ascending',
        Sort     => [
            {
                Field     => 'Street',
                Direction => 'ascending'
            }
        ],
        Expected => ['1',$OrganisationID4,$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Sort: Field Street / Direction descending',
        Sort     => [
            {
                Field     => 'Street',
                Direction => 'descending'
            }
        ],
        Expected => [$OrganisationID3,$OrganisationID2,$OrganisationID1,'1',$OrganisationID4]
    },
    {
        Name     => 'Sort: Field City',
        Sort     => [
            {
                Field => 'City'
            }
        ],
        Expected => ['1',$OrganisationID4,$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Sort: Field City / Direction ascending',
        Sort     => [
            {
                Field     => 'City',
                Direction => 'ascending'
            }
        ],
        Expected => ['1',$OrganisationID4,$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Sort: Field City / Direction descending',
        Sort     => [
            {
                Field     => 'City',
                Direction => 'descending'
            }
        ],
        Expected => [$OrganisationID3,$OrganisationID2,$OrganisationID1,'1',$OrganisationID4]
    },
    {
        Name     => 'Sort: Field Zip',
        Sort     => [
            {
                Field => 'Zip'
            }
        ],
        Expected => ['1',$OrganisationID4,$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Sort: Field Zip / Direction ascending',
        Sort     => [
            {
                Field     => 'Zip',
                Direction => 'ascending'
            }
        ],
        Expected => ['1',$OrganisationID4,$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Sort: Field Zip / Direction descending',
        Sort     => [
            {
                Field     => 'Zip',
                Direction => 'descending'
            }
        ],
        Expected => [$OrganisationID3,$OrganisationID2,$OrganisationID1,'1',$OrganisationID4]
    },
    {
        Name     => 'Sort: Field Country',
        Sort     => [
            {
                Field => 'Country'
            }
        ],
        Expected => ['1',$OrganisationID4,$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Sort: Field Country / Direction ascending',
        Sort     => [
            {
                Field     => 'Country',
                Direction => 'ascending'
            }
        ],
        Expected => ['1',$OrganisationID4,$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Sort: Field Country / Direction descending',
        Sort     => [
            {
                Field     => 'Country',
                Direction => 'descending'
            }
        ],
        Expected => [$OrganisationID3,$OrganisationID2,$OrganisationID1,'1',$OrganisationID4]
    },
    {
        Name     => 'Sort: Field Url',
        Sort     => [
            {
                Field => 'Url'
            }
        ],
        Expected => ['1',$OrganisationID4,$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Sort: Field Url / Direction ascending',
        Sort     => [
            {
                Field     => 'Url',
                Direction => 'ascending'
            }
        ],
        Expected => ['1',$OrganisationID4,$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Sort: Field Url / Direction descending',
        Sort     => [
            {
                Field     => 'Url',
                Direction => 'descending'
            }
        ],
        Expected => [$OrganisationID3,$OrganisationID2,$OrganisationID1,'1',$OrganisationID4]
    },
    {
        Name     => 'Sort: Field Comment',
        Sort     => [
            {
                Field => 'Comment'
            }
        ],
        Expected => ['1',$OrganisationID4,$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Sort: Field Comment / Direction ascending',
        Sort     => [
            {
                Field     => 'Comment',
                Direction => 'ascending'
            }
        ],
        Expected => ['1',$OrganisationID4,$OrganisationID1,$OrganisationID2,$OrganisationID3]
    },
    {
        Name     => 'Sort: Field Comment / Direction descending',
        Sort     => [
            {
                Field     => 'Comment',
                Direction => 'descending'
            }
        ],
        Expected => [$OrganisationID3,$OrganisationID2,$OrganisationID1,'1',$OrganisationID4]
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Organisation',
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
