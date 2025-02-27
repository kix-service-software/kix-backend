# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::FAQArticle::Field';

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
        Field1 => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Field2 => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Field3 => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Field4 => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Field5 => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Field6 => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['STARTSWITH','ENDSWITH','CONTAINS','LIKE']
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
            Field    => 'Field1',
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
            Field    => 'Field1',
            Operator => undef,
            Value    => 'test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'Field1',
            Operator => 'Test',
            Value    => 'test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field Field1 / Operator STARTSWITH',
        Search       => {
            Field    => 'Field1',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_field1) LIKE \'test%\'' : 'f.f_field1 LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field1 / Operator STARTSWITH / with line break',
        Search       => {
            Field    => 'Field1',
            Operator => 'STARTSWITH',
            Value    => "Test\nTest"
        },
        Expected     => {
              'Where' => [
                ( $CaseSensitive ? "(LOWER(f.f_field1) LIKE 'test<br/>\n" : "(f.f_field1 LIKE 'test<br/>\n" )
                . ( $CaseSensitive ? "test%' OR LOWER(f.f_field1) LIKE 'test\n" : "test%' OR f.f_field1 LIKE 'test\n" )
                . "test%')"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field1 / Operator ENDSWITH',
        Search       => {
            Field    => 'Field1',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_field1) LIKE \'%test\'' : 'f.f_field1 LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field1 / Operator ENDSWITH / with line break',
        Search       => {
            Field    => 'Field1',
            Operator => 'ENDSWITH',
            Value    => "Test\nTest"
        },
        Expected     => {
            'Where' => [
                ( $CaseSensitive ? "(LOWER(f.f_field1) LIKE '\%test<br/>\n" : "(f.f_field1 LIKE '\%test<br/>\n" )
                . ( $CaseSensitive ? "test' OR LOWER(f.f_field1) LIKE '\%test\n" : "test' OR f.f_field1 LIKE '\%test\n" )
                . "test')"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field1 / Operator CONTAINS',
        Search       => {
            Field    => 'Field1',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_field1) LIKE \'%test%\'' : 'f.f_field1 LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field1 / Operator CONTAINS / with line break',
        Search       => {
            Field    => 'Field1',
            Operator => 'CONTAINS',
            Value    => "Test\nTest"
        },
        Expected     => {
            'Where' => [
                ( $CaseSensitive ? "(LOWER(f.f_field1) LIKE '\%test<br/>\n" : "(f.f_field1 LIKE '\%test<br/>\n" )
                . ( $CaseSensitive ? "test%' OR LOWER(f.f_field1) LIKE '\%test\n" : "test%' OR f.f_field1 LIKE '\%test\n" )
                . "test%')"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field1 / Operator LIKE',
        Search       => {
            Field    => 'Field1',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_field1) LIKE \'test\'' : 'f.f_field1 LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field1 / Operator LIKE / with line break',
        Search       => {
            Field    => 'Field1',
            Operator => 'LIKE',
            Value    => "Test\nTest"
        },
        Expected     => {
            'Where' => [
                ( $CaseSensitive ? "(LOWER(f.f_field1) LIKE 'test<br/>\n" : "(f.f_field1 LIKE 'test<br/>\n" )
                . ( $CaseSensitive ? "test' OR LOWER(f.f_field1) LIKE 'test\n" : "test' OR f.f_field1 LIKE 'test\n" )
                . "test')"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field2 / Operator STARTSWITH',
        Search       => {
            Field    => 'Field2',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_field2) LIKE \'test%\'' : 'f.f_field2 LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field2 / Operator STARTSWITH / with line break',
        Search       => {
            Field    => 'Field2',
            Operator => 'STARTSWITH',
            Value    => "Test\nTest"
        },
        Expected     => {
              'Where' => [
                ( $CaseSensitive ? "(LOWER(f.f_field2) LIKE 'test<br/>\n" : "(f.f_field2 LIKE 'test<br/>\n" )
                . ( $CaseSensitive ? "test%' OR LOWER(f.f_field2) LIKE 'test\n" : "test%' OR f.f_field2 LIKE 'test\n" )
                . "test%')"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field2 / Operator ENDSWITH',
        Search       => {
            Field    => 'Field2',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_field2) LIKE \'%test\'' : 'f.f_field2 LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field2 / Operator ENDSWITH / with line break',
        Search       => {
            Field    => 'Field2',
            Operator => 'ENDSWITH',
            Value    => "Test\nTest"
        },
        Expected     => {
            'Where' => [
                ( $CaseSensitive ? "(LOWER(f.f_field2) LIKE '\%test<br/>\n" : "(f.f_field2 LIKE '\%test<br/>\n" )
                . ( $CaseSensitive ? "test' OR LOWER(f.f_field2) LIKE '\%test\n" : "test' OR f.f_field2 LIKE '\%test\n" )
                . "test')"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field2 / Operator CONTAINS',
        Search       => {
            Field    => 'Field2',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_field2) LIKE \'%test%\'' : 'f.f_field2 LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field2 / Operator CONTAINS / with line break',
        Search       => {
            Field    => 'Field2',
            Operator => 'CONTAINS',
            Value    => "Test\nTest"
        },
        Expected     => {
            'Where' => [
                ( $CaseSensitive ? "(LOWER(f.f_field2) LIKE '\%test<br/>\n" : "(f.f_field2 LIKE '\%test<br/>\n" )
                . ( $CaseSensitive ? "test%' OR LOWER(f.f_field2) LIKE '\%test\n" : "test%' OR f.f_field2 LIKE '\%test\n" )
                . "test%')"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field2 / Operator LIKE',
        Search       => {
            Field    => 'Field2',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_field2) LIKE \'test\'' : 'f.f_field2 LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field2 / Operator LIKE / with line break',
        Search       => {
            Field    => 'Field2',
            Operator => 'LIKE',
            Value    => "Test\nTest"
        },
        Expected     => {
            'Where' => [
                ( $CaseSensitive ? "(LOWER(f.f_field2) LIKE 'test<br/>\n" : "(f.f_field2 LIKE 'test<br/>\n" )
                . ( $CaseSensitive ? "test' OR LOWER(f.f_field2) LIKE 'test\n" : "test' OR f.f_field2 LIKE 'test\n" )
                . "test')"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field3 / Operator STARTSWITH',
        Search       => {
            Field    => 'Field3',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_field3) LIKE \'test%\'' : 'f.f_field3 LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field3 / Operator STARTSWITH / with line break',
        Search       => {
            Field    => 'Field3',
            Operator => 'STARTSWITH',
            Value    => "Test\nTest"
        },
        Expected     => {
              'Where' => [
                ( $CaseSensitive ? "(LOWER(f.f_field3) LIKE 'test<br/>\n" : "(f.f_field3 LIKE 'test<br/>\n" )
                . ( $CaseSensitive ? "test%' OR LOWER(f.f_field3) LIKE 'test\n" : "test%' OR f.f_field3 LIKE 'test\n" )
                . "test%')"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field3 / Operator ENDSWITH',
        Search       => {
            Field    => 'Field3',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_field3) LIKE \'%test\'' : 'f.f_field3 LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field3 / Operator ENDSWITH / with line break',
        Search       => {
            Field    => 'Field3',
            Operator => 'ENDSWITH',
            Value    => "Test\nTest"
        },
        Expected     => {
            'Where' => [
                ( $CaseSensitive ? "(LOWER(f.f_field3) LIKE '\%test<br/>\n" : "(f.f_field3 LIKE '\%test<br/>\n" )
                . ( $CaseSensitive ? "test' OR LOWER(f.f_field3) LIKE '\%test\n" : "test' OR f.f_field3 LIKE '\%test\n" )
                . "test')"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field3 / Operator CONTAINS',
        Search       => {
            Field    => 'Field3',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_field3) LIKE \'%test%\'' : 'f.f_field3 LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field3 / Operator CONTAINS / with line break',
        Search       => {
            Field    => 'Field3',
            Operator => 'CONTAINS',
            Value    => "Test\nTest"
        },
        Expected     => {
            'Where' => [
                ( $CaseSensitive ? "(LOWER(f.f_field3) LIKE '\%test<br/>\n" : "(f.f_field3 LIKE '\%test<br/>\n" )
                . ( $CaseSensitive ? "test%' OR LOWER(f.f_field3) LIKE '\%test\n" : "test%' OR f.f_field3 LIKE '\%test\n" )
                . "test%')"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field3 / Operator LIKE',
        Search       => {
            Field    => 'Field3',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_field3) LIKE \'test\'' : 'f.f_field3 LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field3 / Operator LIKE / with line break',
        Search       => {
            Field    => 'Field3',
            Operator => 'LIKE',
            Value    => "Test\nTest"
        },
        Expected     => {
            'Where' => [
                ( $CaseSensitive ? "(LOWER(f.f_field3) LIKE 'test<br/>\n" : "(f.f_field3 LIKE 'test<br/>\n" )
                . ( $CaseSensitive ? "test' OR LOWER(f.f_field3) LIKE 'test\n" : "test' OR f.f_field3 LIKE 'test\n" )
                . "test')"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field4 / Operator STARTSWITH',
        Search       => {
            Field    => 'Field4',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_field4) LIKE \'test%\'' : 'f.f_field4 LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field4 / Operator STARTSWITH / with line break',
        Search       => {
            Field    => 'Field4',
            Operator => 'STARTSWITH',
            Value    => "Test\nTest"
        },
        Expected     => {
              'Where' => [
                ( $CaseSensitive ? "(LOWER(f.f_field4) LIKE 'test<br/>\n" : "(f.f_field4 LIKE 'test<br/>\n" )
                . ( $CaseSensitive ? "test%' OR LOWER(f.f_field4) LIKE 'test\n" : "test%' OR f.f_field4 LIKE 'test\n" )
                . "test%')"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field4 / Operator ENDSWITH',
        Search       => {
            Field    => 'Field4',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_field4) LIKE \'%test\'' : 'f.f_field4 LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field4 / Operator ENDSWITH / with line break',
        Search       => {
            Field    => 'Field4',
            Operator => 'ENDSWITH',
            Value    => "Test\nTest"
        },
        Expected     => {
            'Where' => [
                ( $CaseSensitive ? "(LOWER(f.f_field4) LIKE '\%test<br/>\n" : "(f.f_field4 LIKE '\%test<br/>\n" )
                . ( $CaseSensitive ? "test' OR LOWER(f.f_field4) LIKE '\%test\n" : "test' OR f.f_field4 LIKE '\%test\n" )
                . "test')"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field4 / Operator CONTAINS',
        Search       => {
            Field    => 'Field4',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_field4) LIKE \'%test%\'' : 'f.f_field4 LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field4 / Operator CONTAINS / with line break',
        Search       => {
            Field    => 'Field4',
            Operator => 'CONTAINS',
            Value    => "Test\nTest"
        },
        Expected     => {
            'Where' => [
                ( $CaseSensitive ? "(LOWER(f.f_field4) LIKE '\%test<br/>\n" : "(f.f_field4 LIKE '\%test<br/>\n" )
                . ( $CaseSensitive ? "test%' OR LOWER(f.f_field4) LIKE '\%test\n" : "test%' OR f.f_field4 LIKE '\%test\n" )
                . "test%')"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field4 / Operator LIKE',
        Search       => {
            Field    => 'Field4',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_field4) LIKE \'test\'' : 'f.f_field4 LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field4 / Operator LIKE / with line break',
        Search       => {
            Field    => 'Field4',
            Operator => 'LIKE',
            Value    => "Test\nTest"
        },
        Expected     => {
            'Where' => [
                ( $CaseSensitive ? "(LOWER(f.f_field4) LIKE 'test<br/>\n" : "(f.f_field4 LIKE 'test<br/>\n" )
                . ( $CaseSensitive ? "test' OR LOWER(f.f_field4) LIKE 'test\n" : "test' OR f.f_field4 LIKE 'test\n" )
                . "test')"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field5 / Operator STARTSWITH',
        Search       => {
            Field    => 'Field5',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_field5) LIKE \'test%\'' : 'f.f_field5 LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field5 / Operator STARTSWITH / with line break',
        Search       => {
            Field    => 'Field5',
            Operator => 'STARTSWITH',
            Value    => "Test\nTest"
        },
        Expected     => {
              'Where' => [
                ( $CaseSensitive ? "(LOWER(f.f_field5) LIKE 'test<br/>\n" : "(f.f_field5 LIKE 'test<br/>\n" )
                . ( $CaseSensitive ? "test%' OR LOWER(f.f_field5) LIKE 'test\n" : "test%' OR f.f_field5 LIKE 'test\n" )
                . "test%')"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field5 / Operator ENDSWITH',
        Search       => {
            Field    => 'Field5',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_field5) LIKE \'%test\'' : 'f.f_field5 LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field5 / Operator ENDSWITH / with line break',
        Search       => {
            Field    => 'Field5',
            Operator => 'ENDSWITH',
            Value    => "Test\nTest"
        },
        Expected     => {
            'Where' => [
                ( $CaseSensitive ? "(LOWER(f.f_field5) LIKE '\%test<br/>\n" : "(f.f_field5 LIKE '\%test<br/>\n" )
                . ( $CaseSensitive ? "test' OR LOWER(f.f_field5) LIKE '\%test\n" : "test' OR f.f_field5 LIKE '\%test\n" )
                . "test')"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field5 / Operator CONTAINS',
        Search       => {
            Field    => 'Field5',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_field5) LIKE \'%test%\'' : 'f.f_field5 LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field5 / Operator CONTAINS / with line break',
        Search       => {
            Field    => 'Field5',
            Operator => 'CONTAINS',
            Value    => "Test\nTest"
        },
        Expected     => {
            'Where' => [
                ( $CaseSensitive ? "(LOWER(f.f_field5) LIKE '\%test<br/>\n" : "(f.f_field5 LIKE '\%test<br/>\n" )
                . ( $CaseSensitive ? "test%' OR LOWER(f.f_field5) LIKE '\%test\n" : "test%' OR f.f_field5 LIKE '\%test\n" )
                . "test%')"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field5 / Operator LIKE',
        Search       => {
            Field    => 'Field5',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_field5) LIKE \'test\'' : 'f.f_field5 LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field5 / Operator LIKE / with line break',
        Search       => {
            Field    => 'Field5',
            Operator => 'LIKE',
            Value    => "Test\nTest"
        },
        Expected     => {
            'Where' => [
                ( $CaseSensitive ? "(LOWER(f.f_field5) LIKE 'test<br/>\n" : "(f.f_field5 LIKE 'test<br/>\n" )
                . ( $CaseSensitive ? "test' OR LOWER(f.f_field5) LIKE 'test\n" : "test' OR f.f_field5 LIKE 'test\n" )
                . "test')"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field6 / Operator STARTSWITH',
        Search       => {
            Field    => 'Field6',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_field6) LIKE \'test%\'' : 'f.f_field6 LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field6 / Operator STARTSWITH / with line break',
        Search       => {
            Field    => 'Field6',
            Operator => 'STARTSWITH',
            Value    => "Test\nTest"
        },
        Expected     => {
              'Where' => [
                ( $CaseSensitive ? "(LOWER(f.f_field6) LIKE 'test<br/>\n" : "(f.f_field6 LIKE 'test<br/>\n" )
                . ( $CaseSensitive ? "test%' OR LOWER(f.f_field6) LIKE 'test\n" : "test%' OR f.f_field6 LIKE 'test\n" )
                . "test%')"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field6 / Operator ENDSWITH',
        Search       => {
            Field    => 'Field6',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_field6) LIKE \'%test\'' : 'f.f_field6 LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field6 / Operator ENDSWITH / with line break',
        Search       => {
            Field    => 'Field6',
            Operator => 'ENDSWITH',
            Value    => "Test\nTest"
        },
        Expected     => {
            'Where' => [
                ( $CaseSensitive ? "(LOWER(f.f_field6) LIKE '\%test<br/>\n" : "(f.f_field6 LIKE '\%test<br/>\n" )
                . ( $CaseSensitive ? "test' OR LOWER(f.f_field6) LIKE '\%test\n" : "test' OR f.f_field6 LIKE '\%test\n" )
                . "test')"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field6 / Operator CONTAINS',
        Search       => {
            Field    => 'Field6',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_field6) LIKE \'%test%\'' : 'f.f_field6 LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field6 / Operator CONTAINS / with line break',
        Search       => {
            Field    => 'Field6',
            Operator => 'CONTAINS',
            Value    => "Test\nTest"
        },
        Expected     => {
            'Where' => [
                ( $CaseSensitive ? "(LOWER(f.f_field6) LIKE '\%test<br/>\n" : "(f.f_field6 LIKE '\%test<br/>\n" )
                . ( $CaseSensitive ? "test%' OR LOWER(f.f_field6) LIKE '\%test\n" : "test%' OR f.f_field6 LIKE '\%test\n" )
                . "test%')"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field6 / Operator LIKE',
        Search       => {
            Field    => 'Field6',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(f.f_field6) LIKE \'test\'' : 'f.f_field6 LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Field6 / Operator LIKE / with line break',
        Search       => {
            Field    => 'Field6',
            Operator => 'LIKE',
            Value    => "Test\nTest"
        },
        Expected     => {
            'Where' => [
                ( $CaseSensitive ? "(LOWER(f.f_field6) LIKE 'test<br/>\n" : "(f.f_field6 LIKE 'test<br/>\n" )
                . ( $CaseSensitive ? "test' OR LOWER(f.f_field6) LIKE 'test\n" : "test' OR f.f_field6 LIKE 'test\n" )
                . "test')"
            ]
        }
    },
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
        Name      => 'Sort: Attribute "Field1"',
        Attribute => 'Field1',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "Field2"',
        Attribute => 'Field2',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "Field3"',
        Attribute => 'Field3',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "Field4"',
        Attribute => 'Field4',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "Field5"',
        Attribute => 'Field5',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "Field6"',
        Attribute => 'Field6',
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

## prepare faq fields ##
my $Field1   = 'Nam liber tempor cum soluta nobis eleifend option congue nihil imperdiet doming id quod mazim placerat facer possim assum.';
my $Field2   = "Duis autem vel eum iriure dolor in hendrerit in vulputate velit esse molestie consequat,\n vel illum dolore eu feugiat nulla facilisis.";
my $Field3   = 'At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet.';
my $Field4   = 'Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua.';
my $Field5   = 'Ut wisi enim ad minim veniam, quis nostrud exerci tation ullamcorper suscipit lobortis nisl ut aliquip ex ea commodo consequat.';
my $Field6   = 'Consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua.';

## prepare test faq articles ##
# first faq article
my $FAQArticleID1 = $Kernel::OM->Get('FAQ')->FAQAdd(
    Title       => $Helper->GetRandomID(),
    CategoryID  => 1,
    Visibility  => 'internal',
    Language    => 'en',
    ValidID     => 1,
    ContentType => 'text/plain',
    UserID      => 1,
    Field1      => $Field1,
    Field4      => $Field4
);
$Self->True(
    $FAQArticleID1,
    'Created first faq article'
);
# second faq article
my $FAQArticleID2 = $Kernel::OM->Get('FAQ')->FAQAdd(
    Title       => $Helper->GetRandomID(),
    CategoryID  => 1,
    Visibility  => 'internal',
    Language    => 'en',
    ValidID     => 1,
    ContentType => 'text/plain',
    UserID      => 1,
    Field2      => $Field2,
    Field5      => $Field5
);
$Self->True(
    $FAQArticleID1,
    'Created second faq article'
);
# third faq article
my $FAQArticleID3 = $Kernel::OM->Get('FAQ')->FAQAdd(
    Title       => $Helper->GetRandomID(),
    CategoryID  => 1,
    Visibility  => 'internal',
    Language    => 'en',
    ValidID     => 1,
    ContentType => 'text/plain',
    UserID      => 1,
    Field2      => $Field2,
    Field3      => $Field3
);
$Self->True(
    $FAQArticleID1,
    'Created third faq article'
);
# 4th faq article
my $FAQArticleID4 = $Kernel::OM->Get('FAQ')->FAQAdd(
    Title       => $Helper->GetRandomID(),
    CategoryID  => 1,
    Visibility  => 'internal',
    Language    => 'en',
    ValidID     => 1,
    ContentType => 'text/plain',
    UserID      => 1,
    Field4      => $Field4,
    Field6      => $Field6
);
$Self->True(
    $FAQArticleID1,
    'Created 4th faq article'
);
# 5th faq article
my $FAQArticleID5 = $Kernel::OM->Get('FAQ')->FAQAdd(
    Title       => $Helper->GetRandomID(),
    CategoryID  => 1,
    Visibility  => 'internal',
    Language    => 'en',
    ValidID     => 1,
    ContentType => 'text/plain',
    UserID      => 1,
    Field3      => $Field3,
    Field5      => $Field5
);
$Self->True(
    $FAQArticleID1,
    'Created 5th faq article'
);
# 6th faq article
my $FAQArticleID6 = $Kernel::OM->Get('FAQ')->FAQAdd(
    Title       => $Helper->GetRandomID(),
    CategoryID  => 1,
    Visibility  => 'internal',
    Language    => 'en',
    ValidID     => 1,
    ContentType => 'text/plain',
    UserID      => 1,
    Field1      => $Field1,
    Field3      => $Field3,
    Field6      => $Field6
);
$Self->True(
    $FAQArticleID1,
    'Created 6th faq article'
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => "Search: Field Field1 / Operator STARTSWITH / Value \$Field1",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field1',
                    Operator => 'STARTSWITH',
                    Value    => $Field1
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID6]
    },
    {
        Name     => "Search: Field Category / Operator STARTSWITH / Value substr(\$Field1,0,15)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field1',
                    Operator => 'STARTSWITH',
                    Value    => substr($Field1,0,15)
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID6]
    },
    {
        Name     => "Search: Field Field1 / Operator ENDSWITH / Value \$Field1",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field1',
                    Operator => 'ENDSWITH',
                    Value    => $Field1
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID6]
    },
    {
        Name     => "Search: Field Field1 / Operator ENDSWITH / Value substr(\$Field1,-15)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field1',
                    Operator => 'ENDSWITH',
                    Value    => substr($Field1,-15)
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID6]
    },
    {
        Name     => "Search: Field Field1 / Operator CONTAINS / Value \$Field1",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field1',
                    Operator => 'CONTAINS',
                    Value    => $Field1
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID6]
    },
    {
        Name     => "Search: Field Field1 / Operator CONTAINS / Value substr(\$Field1,5,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field1',
                    Operator => 'CONTAINS',
                    Value    => substr($Field1,5,-5)
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID6]
    },
    {
        Name     => "Search: Field Field1 / Operator LIKE / Value \$Field1",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field1',
                    Operator => 'LIKE',
                    Value    => "$Field1"
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID6]
    },
    {
        Name     => "Search: Field Field1 / Operator LIKE / Value \$Field1,0,10)*",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field1',
                    Operator => 'LIKE',
                    Value    => substr($Field1,0,10) . q{*}
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID6]
    },
    {
        Name     => "Search: Field Field2 / Operator STARTSWITH / Value \$Field2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field2',
                    Operator => 'STARTSWITH',
                    Value    => $Field2
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Category / Operator STARTSWITH / Value substr(\$Field2,0,15)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field2',
                    Operator => 'STARTSWITH',
                    Value    => substr($Field2,0,15)
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Field2 / Operator ENDSWITH / Value \$Field2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field2',
                    Operator => 'ENDSWITH',
                    Value    => $Field2
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Field2 / Operator ENDSWITH / Value substr(\$Field2,-15)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field2',
                    Operator => 'ENDSWITH',
                    Value    => substr($Field2,-15)
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Field2 / Operator CONTAINS / Value \$Field2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field2',
                    Operator => 'CONTAINS',
                    Value    => $Field2
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Field2 / Operator CONTAINS / Value substr(\$Field2,5,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field2',
                    Operator => 'CONTAINS',
                    Value    => substr($Field2,5,-5)
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Field2 / Operator LIKE / Value \$Field2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field2',
                    Operator => 'LIKE',
                    Value    => "$Field2"
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Field2 / Operator LIKE / Value \$Field2,0,10)*",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field2',
                    Operator => 'LIKE',
                    Value    => substr($Field2,0,10) . q{*}
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Field3 / Operator STARTSWITH / Value \$Field3",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field3',
                    Operator => 'STARTSWITH',
                    Value    => $Field3
                }
            ]
        },
        Expected => [$FAQArticleID3,$FAQArticleID5,$FAQArticleID6]
    },
    {
        Name     => "Search: Field Category / Operator STARTSWITH / Value substr(\$Field3,0,15)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field3',
                    Operator => 'STARTSWITH',
                    Value    => substr($Field3,0,15)
                }
            ]
        },
        Expected => [$FAQArticleID3,$FAQArticleID5,$FAQArticleID6]
    },
    {
        Name     => "Search: Field Field3 / Operator ENDSWITH / Value \$Field3",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field3',
                    Operator => 'ENDSWITH',
                    Value    => $Field3
                }
            ]
        },
        Expected => [$FAQArticleID3,$FAQArticleID5,$FAQArticleID6]
    },
    {
        Name     => "Search: Field Field3 / Operator ENDSWITH / Value substr(\$Field3,-15)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field3',
                    Operator => 'ENDSWITH',
                    Value    => substr($Field3,-15)
                }
            ]
        },
        Expected => [$FAQArticleID3,$FAQArticleID5,$FAQArticleID6]
    },
    {
        Name     => "Search: Field Field3 / Operator CONTAINS / Value \$Field3",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field3',
                    Operator => 'CONTAINS',
                    Value    => $Field3
                }
            ]
        },
        Expected => [$FAQArticleID3,$FAQArticleID5,$FAQArticleID6]
    },
    {
        Name     => "Search: Field Field3 / Operator CONTAINS / Value substr(\$Field3,5,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field3',
                    Operator => 'CONTAINS',
                    Value    => substr($Field3,5,-5)
                }
            ]
        },
        Expected => [$FAQArticleID3,$FAQArticleID5,$FAQArticleID6]
    },
    {
        Name     => "Search: Field Field3 / Operator LIKE / Value \$Field3",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field3',
                    Operator => 'LIKE',
                    Value    => "$Field3"
                }
            ]
        },
        Expected => [$FAQArticleID3,$FAQArticleID5,$FAQArticleID6]
    },
    {
        Name     => "Search: Field Field3 / Operator LIKE / Value \$Field3,0,10)*",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field3',
                    Operator => 'LIKE',
                    Value    => substr($Field3,0,10) . q{*}
                }
            ]
        },
        Expected => [$FAQArticleID3,$FAQArticleID5,$FAQArticleID6]
    },
    {
        Name     => "Search: Field Field4 / Operator STARTSWITH / Value \$Field4",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field4',
                    Operator => 'STARTSWITH',
                    Value    => $Field4
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID4]
    },
    {
        Name     => "Search: Field Category / Operator STARTSWITH / Value substr(\$Field4,0,15)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field4',
                    Operator => 'STARTSWITH',
                    Value    => substr($Field4,0,15)
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID4]
    },
    {
        Name     => "Search: Field Field4 / Operator ENDSWITH / Value \$Field4",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field4',
                    Operator => 'ENDSWITH',
                    Value    => $Field4
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID4]
    },
    {
        Name     => "Search: Field Field4 / Operator ENDSWITH / Value substr(\$Field4,-15)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field4',
                    Operator => 'ENDSWITH',
                    Value    => substr($Field4,-15)
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID4]
    },
    {
        Name     => "Search: Field Field4 / Operator CONTAINS / Value \$Field4",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field4',
                    Operator => 'CONTAINS',
                    Value    => $Field4
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID4]
    },
    {
        Name     => "Search: Field Field4 / Operator CONTAINS / Value substr(\$Field4,5,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field4',
                    Operator => 'CONTAINS',
                    Value    => substr($Field4,5,-5)
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID4]
    },
    {
        Name     => "Search: Field Field4 / Operator LIKE / Value \$Field4",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field4',
                    Operator => 'LIKE',
                    Value    => "$Field4"
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID4]
    },
    {
        Name     => "Search: Field Field4 / Operator LIKE / Value \$Field4,0,10)*",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field4',
                    Operator => 'LIKE',
                    Value    => substr($Field4,0,10) . q{*}
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID4]
    },
    {
        Name     => "Search: Field Field5 / Operator STARTSWITH / Value \$Field5",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field5',
                    Operator => 'STARTSWITH',
                    Value    => $Field5
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID5]
    },
    {
        Name     => "Search: Field Category / Operator STARTSWITH / Value substr(\$Field5,0,15)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field5',
                    Operator => 'STARTSWITH',
                    Value    => substr($Field5,0,15)
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID5]
    },
    {
        Name     => "Search: Field Field5 / Operator ENDSWITH / Value \$Field5",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field5',
                    Operator => 'ENDSWITH',
                    Value    => $Field5
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID5]
    },
    {
        Name     => "Search: Field Field5 / Operator ENDSWITH / Value substr(\$Field5,-15)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field5',
                    Operator => 'ENDSWITH',
                    Value    => substr($Field5,-15)
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID5]
    },
    {
        Name     => "Search: Field Field5 / Operator CONTAINS / Value \$Field5",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field5',
                    Operator => 'CONTAINS',
                    Value    => $Field5
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID5]
    },
    {
        Name     => "Search: Field Field5 / Operator CONTAINS / Value substr(\$Field5,5,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field5',
                    Operator => 'CONTAINS',
                    Value    => substr($Field5,5,-5)
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID5]
    },
    {
        Name     => "Search: Field Field5 / Operator LIKE / Value \$Field5",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field5',
                    Operator => 'LIKE',
                    Value    => "$Field5"
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID5]
    },
    {
        Name     => "Search: Field Field5 / Operator LIKE / Value \$Field5,0,10)*",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field5',
                    Operator => 'LIKE',
                    Value    => substr($Field5,0,10) . q{*}
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID5]
    },
    {
        Name     => "Search: Field Field6 / Operator STARTSWITH / Value \$Field6",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field6',
                    Operator => 'STARTSWITH',
                    Value    => $Field6
                }
            ]
        },
        Expected => [$FAQArticleID4,$FAQArticleID6]
    },
    {
        Name     => "Search: Field Category / Operator STARTSWITH / Value substr(\$Field6,0,15)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field6',
                    Operator => 'STARTSWITH',
                    Value    => substr($Field6,0,15)
                }
            ]
        },
        Expected => [$FAQArticleID4,$FAQArticleID6]
    },
    {
        Name     => "Search: Field Field6 / Operator ENDSWITH / Value \$Field6",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field6',
                    Operator => 'ENDSWITH',
                    Value    => $Field6
                }
            ]
        },
        Expected => [$FAQArticleID4,$FAQArticleID6]
    },
    {
        Name     => "Search: Field Field6 / Operator ENDSWITH / Value substr(\$Field6,-15)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field6',
                    Operator => 'ENDSWITH',
                    Value    => substr($Field6,-15)
                }
            ]
        },
        Expected => [$FAQArticleID4,$FAQArticleID6]
    },
    {
        Name     => "Search: Field Field6 / Operator CONTAINS / Value \$Field6",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field6',
                    Operator => 'CONTAINS',
                    Value    => $Field6
                }
            ]
        },
        Expected => [$FAQArticleID4,$FAQArticleID6]
    },
    {
        Name     => "Search: Field Field6 / Operator CONTAINS / Value substr(\$Field6,5,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field6',
                    Operator => 'CONTAINS',
                    Value    => substr($Field6,5,-5)
                }
            ]
        },
        Expected => [$FAQArticleID4,$FAQArticleID6]
    },
    {
        Name     => "Search: Field Field6 / Operator LIKE / Value \$Field6",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field6',
                    Operator => 'LIKE',
                    Value    => "$Field6"
                }
            ]
        },
        Expected => [$FAQArticleID4,$FAQArticleID6]
    },
    {
        Name     => "Search: Field Field6 / Operator LIKE / Value \$Field6,0,10)*",
        Search   => {
            'AND' => [
                {
                    Field    => 'Field6',
                    Operator => 'LIKE',
                    Value    => substr($Field6,0,10) . q{*}
                }
            ]
        },
        Expected => [$FAQArticleID4,$FAQArticleID6]
    }
);

for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'FAQArticle',
        Result     => 'ARRAY',
        Search     => $Test->{Search},
        UserType   => 'Agent',
        UserID     => 1
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
