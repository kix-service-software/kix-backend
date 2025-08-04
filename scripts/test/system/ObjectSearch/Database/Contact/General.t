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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Contact::General';

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
        Title => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        Firstname => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        Lastname => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        Phone => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        Fax => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        Mobile => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        Street => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        City => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        Zip => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        Country => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        Comment => {
            IsSelectable   => 1,
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
            Field    => 'Title',
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
            Field    => 'Title',
            Operator => undef,
            Value    => 'test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'Title',
            Operator => 'Test',
            Value    => 'test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field Title / Operator EQ',
        Search       => {
            Field    => 'Title',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.title) = \'test\'' : 'c.title = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Title / Operator NE',
        Search       => {
            Field    => 'Title',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(c.title) != \'test\' OR c.title IS NULL)' : '(c.title != \'test\' OR c.title IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Title / Operator IN',
        Search       => {
            Field    => 'Title',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.title) IN (\'test\')' : 'c.title IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Title / Operator !IN',
        Search       => {
            Field    => 'Title',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.title) NOT IN (\'test\')' : 'c.title NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Title / Operator STARTSWITH',
        Search       => {
            Field    => 'Title',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.title) LIKE \'test%\'' : 'c.title LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Title / Operator ENDSWITH',
        Search       => {
            Field    => 'Title',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.title) LIKE \'%test\'' : 'c.title LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Title / Operator CONTAINS',
        Search       => {
            Field    => 'Title',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.title) LIKE \'%test%\'' : 'c.title LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Title / Operator LIKE',
        Search       => {
            Field    => 'Title',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.title) LIKE \'test\'' : 'c.title LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Firstname / Operator EQ',
        Search       => {
            Field    => 'Firstname',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.firstname) = \'test\'' : 'c.firstname = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Firstname / Operator NE',
        Search       => {
            Field    => 'Firstname',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(c.firstname) != \'test\' OR c.firstname IS NULL)' : '(c.firstname != \'test\' OR c.firstname IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Firstname / Operator IN',
        Search       => {
            Field    => 'Firstname',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.firstname) IN (\'test\')' : 'c.firstname IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Firstname / Operator !IN',
        Search       => {
            Field    => 'Firstname',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.firstname) NOT IN (\'test\')' : 'c.firstname NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Firstname / Operator STARTSWITH',
        Search       => {
            Field    => 'Firstname',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.firstname) LIKE \'test%\'' : 'c.firstname LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Firstname / Operator ENDSWITH',
        Search       => {
            Field    => 'Firstname',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.firstname) LIKE \'%test\'' : 'c.firstname LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Firstname / Operator CONTAINS',
        Search       => {
            Field    => 'Firstname',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.firstname) LIKE \'%test%\'' : 'c.firstname LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Firstname / Operator LIKE',
        Search       => {
            Field    => 'Firstname',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.firstname) LIKE \'test\'' : 'c.firstname LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Lastname / Operator EQ',
        Search       => {
            Field    => 'Lastname',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.lastname) = \'test\'' : 'c.lastname = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Lastname / Operator NE',
        Search       => {
            Field    => 'Lastname',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(c.lastname) != \'test\' OR c.lastname IS NULL)' : '(c.lastname != \'test\' OR c.lastname IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Lastname / Operator IN',
        Search       => {
            Field    => 'Lastname',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.lastname) IN (\'test\')' : 'c.lastname IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Lastname / Operator !IN',
        Search       => {
            Field    => 'Lastname',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.lastname) NOT IN (\'test\')' : 'c.lastname NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Lastname / Operator STARTSWITH',
        Search       => {
            Field    => 'Lastname',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.lastname) LIKE \'test%\'' : 'c.lastname LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Lastname / Operator ENDSWITH',
        Search       => {
            Field    => 'Lastname',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.lastname) LIKE \'%test\'' : 'c.lastname LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Lastname / Operator CONTAINS',
        Search       => {
            Field    => 'Lastname',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.lastname) LIKE \'%test%\'' : 'c.lastname LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Lastname / Operator LIKE',
        Search       => {
            Field    => 'Lastname',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.lastname) LIKE \'test\'' : 'c.lastname LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Phone / Operator EQ',
        Search       => {
            Field    => 'Phone',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.phone) = \'test\'' : 'c.phone = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Phone / Operator NE',
        Search       => {
            Field    => 'Phone',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(c.phone) != \'test\' OR c.phone IS NULL)' : '(c.phone != \'test\' OR c.phone IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Phone / Operator IN',
        Search       => {
            Field    => 'Phone',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.phone) IN (\'test\')' : 'c.phone IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Phone / Operator !IN',
        Search       => {
            Field    => 'Phone',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.phone) NOT IN (\'test\')' : 'c.phone NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Phone / Operator STARTSWITH',
        Search       => {
            Field    => 'Phone',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.phone) LIKE \'test%\'' : 'c.phone LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Phone / Operator ENDSWITH',
        Search       => {
            Field    => 'Phone',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.phone) LIKE \'%test\'' : 'c.phone LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Phone / Operator CONTAINS',
        Search       => {
            Field    => 'Phone',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.phone) LIKE \'%test%\'' : 'c.phone LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Phone / Operator LIKE',
        Search       => {
            Field    => 'Phone',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.phone) LIKE \'test\'' : 'c.phone LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Fax / Operator EQ',
        Search       => {
            Field    => 'Fax',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.fax) = \'test\'' : 'c.fax = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Fax / Operator NE',
        Search       => {
            Field    => 'Fax',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(c.fax) != \'test\' OR c.fax IS NULL)' : '(c.fax != \'test\' OR c.fax IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Fax / Operator IN',
        Search       => {
            Field    => 'Fax',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.fax) IN (\'test\')' : 'c.fax IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Fax / Operator !IN',
        Search       => {
            Field    => 'Fax',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.fax) NOT IN (\'test\')' : 'c.fax NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Fax / Operator STARTSWITH',
        Search       => {
            Field    => 'Fax',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.fax) LIKE \'test%\'' : 'c.fax LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Fax / Operator ENDSWITH',
        Search       => {
            Field    => 'Fax',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.fax) LIKE \'%test\'' : 'c.fax LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Fax / Operator CONTAINS',
        Search       => {
            Field    => 'Fax',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.fax) LIKE \'%test%\'' : 'c.fax LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Fax / Operator LIKE',
        Search       => {
            Field    => 'Fax',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.fax) LIKE \'test\'' : 'c.fax LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Mobile / Operator EQ',
        Search       => {
            Field    => 'Mobile',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.mobile) = \'test\'' : 'c.mobile = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Mobile / Operator NE',
        Search       => {
            Field    => 'Mobile',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(c.mobile) != \'test\' OR c.mobile IS NULL)' : '(c.mobile != \'test\' OR c.mobile IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Mobile / Operator IN',
        Search       => {
            Field    => 'Mobile',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.mobile) IN (\'test\')' : 'c.mobile IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Mobile / Operator !IN',
        Search       => {
            Field    => 'Mobile',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.mobile) NOT IN (\'test\')' : 'c.mobile NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Mobile / Operator STARTSWITH',
        Search       => {
            Field    => 'Mobile',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.mobile) LIKE \'test%\'' : 'c.mobile LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Mobile / Operator ENDSWITH',
        Search       => {
            Field    => 'Mobile',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.mobile) LIKE \'%test\'' : 'c.mobile LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Mobile / Operator CONTAINS',
        Search       => {
            Field    => 'Mobile',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.mobile) LIKE \'%test%\'' : 'c.mobile LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Mobile / Operator LIKE',
        Search       => {
            Field    => 'Mobile',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(c.mobile) LIKE \'test\'' : 'c.mobile LIKE \'test\''
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
                $CaseSensitive ? 'LOWER(c.street) = \'test\'' : 'c.street = \'test\''
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
                $CaseSensitive ? '(LOWER(c.street) != \'test\' OR c.street IS NULL)' : '(c.street != \'test\' OR c.street IS NULL)'
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
                $CaseSensitive ? 'LOWER(c.street) IN (\'test\')' : 'c.street IN (\'test\')'
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
                $CaseSensitive ? 'LOWER(c.street) NOT IN (\'test\')' : 'c.street NOT IN (\'test\')'
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
                $CaseSensitive ? 'LOWER(c.street) LIKE \'test%\'' : 'c.street LIKE \'test%\''
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
                $CaseSensitive ? 'LOWER(c.street) LIKE \'%test\'' : 'c.street LIKE \'%test\''
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
                $CaseSensitive ? 'LOWER(c.street) LIKE \'%test%\'' : 'c.street LIKE \'%test%\''
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
                $CaseSensitive ? 'LOWER(c.street) LIKE \'test\'' : 'c.street LIKE \'test\''
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
                $CaseSensitive ? 'LOWER(c.city) = \'test\'' : 'c.city = \'test\''
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
                $CaseSensitive ? '(LOWER(c.city) != \'test\' OR c.city IS NULL)' : '(c.city != \'test\' OR c.city IS NULL)'
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
                $CaseSensitive ? 'LOWER(c.city) IN (\'test\')' : 'c.city IN (\'test\')'
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
                $CaseSensitive ? 'LOWER(c.city) NOT IN (\'test\')' : 'c.city NOT IN (\'test\')'
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
                $CaseSensitive ? 'LOWER(c.city) LIKE \'test%\'' : 'c.city LIKE \'test%\''
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
                $CaseSensitive ? 'LOWER(c.city) LIKE \'%test\'' : 'c.city LIKE \'%test\''
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
                $CaseSensitive ? 'LOWER(c.city) LIKE \'%test%\'' : 'c.city LIKE \'%test%\''
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
                $CaseSensitive ? 'LOWER(c.city) LIKE \'test\'' : 'c.city LIKE \'test\''
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
                $CaseSensitive ? 'LOWER(c.zip) = \'test\'' : 'c.zip = \'test\''
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
                $CaseSensitive ? '(LOWER(c.zip) != \'test\' OR c.zip IS NULL)' : '(c.zip != \'test\' OR c.zip IS NULL)'
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
                $CaseSensitive ? 'LOWER(c.zip) IN (\'test\')' : 'c.zip IN (\'test\')'
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
                $CaseSensitive ? 'LOWER(c.zip) NOT IN (\'test\')' : 'c.zip NOT IN (\'test\')'
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
                $CaseSensitive ? 'LOWER(c.zip) LIKE \'test%\'' : 'c.zip LIKE \'test%\''
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
                $CaseSensitive ? 'LOWER(c.zip) LIKE \'%test\'' : 'c.zip LIKE \'%test\''
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
                $CaseSensitive ? 'LOWER(c.zip) LIKE \'%test%\'' : 'c.zip LIKE \'%test%\''
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
                $CaseSensitive ? 'LOWER(c.zip) LIKE \'test\'' : 'c.zip LIKE \'test\''
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
                $CaseSensitive ? 'LOWER(c.country) = \'test\'' : 'c.country = \'test\''
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
                $CaseSensitive ? '(LOWER(c.country) != \'test\' OR c.country IS NULL)' : '(c.country != \'test\' OR c.country IS NULL)'
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
                $CaseSensitive ? 'LOWER(c.country) IN (\'test\')' : 'c.country IN (\'test\')'
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
                $CaseSensitive ? 'LOWER(c.country) NOT IN (\'test\')' : 'c.country NOT IN (\'test\')'
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
                $CaseSensitive ? 'LOWER(c.country) LIKE \'test%\'' : 'c.country LIKE \'test%\''
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
                $CaseSensitive ? 'LOWER(c.country) LIKE \'%test\'' : 'c.country LIKE \'%test\''
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
                $CaseSensitive ? 'LOWER(c.country) LIKE \'%test%\'' : 'c.country LIKE \'%test%\''
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
                $CaseSensitive ? 'LOWER(c.country) LIKE \'test\'' : 'c.country LIKE \'test\''
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
                $CaseSensitive ? 'LOWER(c.comments) = \'test\'' : 'c.comments = \'test\''
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
                $CaseSensitive ? '(LOWER(c.comments) != \'test\' OR c.comments IS NULL)' : '(c.comments != \'test\' OR c.comments IS NULL)'
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
                $CaseSensitive ? 'LOWER(c.comments) IN (\'test\')' : 'c.comments IN (\'test\')'
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
                $CaseSensitive ? 'LOWER(c.comments) NOT IN (\'test\')' : 'c.comments NOT IN (\'test\')'
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
                $CaseSensitive ? 'LOWER(c.comments) LIKE \'test%\'' : 'c.comments LIKE \'test%\''
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
                $CaseSensitive ? 'LOWER(c.comments) LIKE \'%test\'' : 'c.comments LIKE \'%test\''
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
                $CaseSensitive ? 'LOWER(c.comments) LIKE \'%test%\'' : 'c.comments LIKE \'%test%\''
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
                $CaseSensitive ? 'LOWER(c.comments) LIKE \'test\'' : 'c.comments LIKE \'test\''
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
        Name      => 'Sort: Attribute "Title"',
        Attribute => 'Title',
        Expected  => {
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select' => [
                'LOWER(c.title) AS SortAttr0'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Firstname"',
        Attribute => 'Firstname',
        Expected  => {
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select' => [
                'LOWER(c.firstname) AS SortAttr0'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Lastname"',
        Attribute => 'Lastname',
        Expected  => {
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select' => [
                'LOWER(c.lastname) AS SortAttr0'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Phone"',
        Attribute => 'Phone',
        Expected  => {
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select' => [
                'LOWER(COALESCE(c.phone,\'\')) AS SortAttr0'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Fax"',
        Attribute => 'Fax',
        Expected  => {
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select' => [
                'LOWER(COALESCE(c.fax,\'\')) AS SortAttr0'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Mobile"',
        Attribute => 'Mobile',
        Expected  => {
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select' => [
                'LOWER(COALESCE(c.mobile,\'\')) AS SortAttr0'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Street"',
        Attribute => 'Street',
        Expected  => {
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select' => [
                'LOWER(COALESCE(c.street,\'\')) AS SortAttr0'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "City"',
        Attribute => 'City',
        Expected  => {
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select' => [
                'LOWER(COALESCE(c.city,\'\')) AS SortAttr0'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Zip"',
        Attribute => 'Zip',
        Expected  => {
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select' => [
                'LOWER(COALESCE(c.zip,\'\')) AS SortAttr0'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Country"',
        Attribute => 'Country',
        Expected  => {
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select' => [
                'LOWER(COALESCE(c.country,\'\')) AS SortAttr0'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Comment"',
        Attribute => 'Comment',
        Expected  => {
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select' => [
                'LOWER(COALESCE(c.comments,\'\')) AS SortAttr0'
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

## prepare faq params ##
my @TestData = (
    {
        Title     => 'Herr',
        Firstname => 'Alf',
        Lastname  => 'Test',
        Phone     => '01258 2597 575',
        Fax       => '2568 5475411',
        Mobile    => undef,
        Street    => 'Musterweg 25',
        Zip       => '02358',
        City      => 'Musterstadt',
        Country   => 'Musterland',
        Comment   => q{}
    },
    {
        Title     => 'Mr.',
        Firstname => 'Bert',
        Lastname  => 'Test',
        Phone     => undef,
        Fax       => undef,
        Mobile    => '015688764825',
        Street    => 'Example St. 505',
        Zip       => '56884',
        City      => 'Example Town',
        Country   => 'Example',
        Comment   => 'Bert the towns men'
    },
    {
        Title     => 'Dr.',
        Firstname => 'Herta',
        Lastname  => 'Engel',
        Phone     => '012582597575',
        Fax       => undef,
        Mobile    => '01758 65035868',
        Street    => undef,
        Zip       => undef,
        City      => undef,
        Country   => undef,
    },
    {
        Title     => undef,
        Firstname => 'Theo',
        Lastname  => 'Test',
        Phone     => undef,
        Fax       => '25685475411',
        Mobile    => undef,
        Street    => 'Musterway 205',
        Zip       => '02589',
        City      => 'Musterstadt',
        Country   => 'Musterland',
        Comment   => 'Theo the towns men'
    }
);

## prepare test contacts ##
# first contact
my $ContactID1 = $Kernel::OM->Get('Contact')->ContactAdd(
    %{$TestData[0]},
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $ContactID1,
    'Created first contact'
);
# second contact
my $ContactID2 = $Kernel::OM->Get('Contact')->ContactAdd(
    %{$TestData[1]},
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $ContactID2,
    'Created second contact'
);
# third contact
my $ContactID3 = $Kernel::OM->Get('Contact')->ContactAdd(
    %{$TestData[2]},
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $ContactID3,
    'Created third contact'
);
# forth contact
my $ContactID4 = $Kernel::OM->Get('Contact')->ContactAdd(
    %{$TestData[3]},
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $ContactID4,
    'Created forth contact'
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => "Search: Field Title / Operator EQ / Value \$TestData[0]->{Title}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'EQ',
                    Value    => $TestData[0]->{Title}
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Title / Operator NE / Value \$TestData[0]->{Title}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'NE',
                    Value    => $TestData[0]->{Title}
                }
            ]
        },
        Expected => ['1',$ContactID2,$ContactID3,$ContactID4]
    },
    {
        Name     => "Search: Field Title / Operator IN / Value \$TestData[0]->{Title}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'IN',
                    Value    => $TestData[0]->{Title}
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Title / Operator !IN / Value \$TestData[0]->{Title}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => '!IN',
                    Value    => $TestData[0]->{Title}
                }
            ]
        },
        Expected => [$ContactID2,$ContactID3]
    },
    {
        Name     => "Search: Field Title / Operator STARTSWITH / Value \$TestData[1]->{Title}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'STARTSWITH',
                    Value    => $TestData[1]->{Title}
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field Title / Operator STARTSWITH / Value substr(\$TestData[1]->{Title},0,2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'STARTSWITH',
                    Value    => substr($TestData[1]->{Title},0,2)
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field Title / Operator ENDSWITH / Value \$TestData[2]->{Title}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'ENDSWITH',
                    Value    => $TestData[2]->{Title}
                }
            ]
        },
        Expected => [$ContactID3]
    },
    {
        Name     => "Search: Field Title / Operator ENDSWITH / Value substr(\$TestData[2]->{Title},-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'ENDSWITH',
                    Value    => substr($TestData[2]->{Title},-2)
                }
            ]
        },
        Expected => [$ContactID2,$ContactID3]
    },
    {
        Name     => "Search: Field Title / Operator CONTAINS / Value \$TestData[0]->{Title}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'CONTAINS',
                    Value    => $TestData[0]->{Title}
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Title / Operator CONTAINS / Value substr(\$TestData[0]->{Title},1,-1)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'CONTAINS',
                    Value    => substr($TestData[0]->{Title},1,-1)
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Title / Operator LIKE / Value \$TestData[0]->{Title}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'LIKE',
                    Value    => $TestData[0]->{Title}
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Title / Operator LIKE / Value *substr(\$TestData[0]->{Title},2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Title',
                    Operator => 'LIKE',
                    Value    => q{*} . substr($TestData[0]->{Title},2)
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Firstname / Operator EQ / Value \$TestData[0]->{Firstname}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Firstname',
                    Operator => 'EQ',
                    Value    => $TestData[0]->{Firstname}
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Firstname / Operator NE / Value \$TestData[0]->{Firstname}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Firstname',
                    Operator => 'NE',
                    Value    => $TestData[0]->{Firstname}
                }
            ]
        },
        Expected => ['1',$ContactID2,$ContactID3,$ContactID4]
    },
    {
        Name     => "Search: Field Firstname / Operator IN / Value \$TestData[0]->{Firstname}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Firstname',
                    Operator => 'IN',
                    Value    => $TestData[0]->{Firstname}
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Firstname / Operator !IN / Value \$TestData[0]->{Firstname}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Firstname',
                    Operator => '!IN',
                    Value    => $TestData[0]->{Firstname}
                }
            ]
        },
        Expected => ['1',$ContactID2,$ContactID3,$ContactID4]
    },
    {
        Name     => "Search: Field Firstname / Operator STARTSWITH / Value \$TestData[1]->{Firstname}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Firstname',
                    Operator => 'STARTSWITH',
                    Value    => $TestData[1]->{Firstname}
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field Firstname / Operator STARTSWITH / Value substr(\$TestData[1]->{Firstname},0,5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Firstname',
                    Operator => 'STARTSWITH',
                    Value    => substr($TestData[1]->{Firstname},0,5)
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field Firstname / Operator ENDSWITH / Value \$TestData[2]->{Firstname}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Firstname',
                    Operator => 'ENDSWITH',
                    Value    => $TestData[2]->{Firstname}
                }
            ]
        },
        Expected => [$ContactID3]
    },
    {
        Name     => "Search: Field Firstname / Operator ENDSWITH / Value substr(\$TestData[2]->{Firstname},-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Firstname',
                    Operator => 'ENDSWITH',
                    Value    => substr($TestData[2]->{Firstname},-2)
                }
            ]
        },
        Expected => [$ContactID3]
    },
    {
        Name     => "Search: Field Firstname / Operator CONTAINS / Value \$TestData[0]->{Firstname}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Firstname',
                    Operator => 'CONTAINS',
                    Value    => $TestData[0]->{Firstname}
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Firstname / Operator CONTAINS / Value substr(\$TestData[0]->{Firstname},3,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Firstname',
                    Operator => 'CONTAINS',
                    Value    => substr($TestData[0]->{Firstname},3,-2)
                }
            ]
        },
        Expected => ['1',$ContactID1,$ContactID2,$ContactID3,$ContactID4]
    },
    {
        Name     => "Search: Field Firstname / Operator LIKE / Value \$TestData[0]->{Firstname}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Firstname',
                    Operator => 'LIKE',
                    Value    => $TestData[0]->{Firstname}
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Firstname / Operator LIKE / Value *substr(\$TestData[0]->{Firstname},5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Firstname',
                    Operator => 'LIKE',
                    Value    => q{*} . substr($TestData[0]->{Firstname},5)
                }
            ]
        },
        Expected => ['1',$ContactID1,$ContactID2,$ContactID3,$ContactID4]
    },
    {
        Name     => "Search: Field Phone / Operator EQ / Value \$TestData[0]->{Phone}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Phone',
                    Operator => 'EQ',
                    Value    => $TestData[0]->{Phone}
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Phone / Operator NE / Value \$TestData[0]->{Phone}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Phone',
                    Operator => 'NE',
                    Value    => $TestData[0]->{Phone}
                }
            ]
        },
        Expected => ['1',$ContactID2,$ContactID3,$ContactID4]
    },
    {
        Name     => "Search: Field Phone / Operator IN / Value \$TestData[0]->{Phone}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Phone',
                    Operator => 'IN',
                    Value    => $TestData[0]->{Phone}
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Phone / Operator !IN / Value \$TestData[0]->{Phone}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Phone',
                    Operator => '!IN',
                    Value    => $TestData[0]->{Phone}
                }
            ]
        },
        Expected => [$ContactID3]
    },
    {
        Name     => "Search: Field Phone / Operator STARTSWITH / Value \$TestData[2]->{Phone}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Phone',
                    Operator => 'STARTSWITH',
                    Value    => $TestData[2]->{Phone}
                }
            ]
        },
        Expected => [$ContactID3]
    },
    {
        Name     => "Search: Field Phone / Operator STARTSWITH / Value substr(\$TestData[2]->{Phone},0,2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Phone',
                    Operator => 'STARTSWITH',
                    Value    => substr($TestData[2]->{Phone},0,2)
                }
            ]
        },
        Expected => [$ContactID1,$ContactID3]
    },
    {
        Name     => "Search: Field Phone / Operator ENDSWITH / Value \$TestData[2]->{Phone}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Phone',
                    Operator => 'ENDSWITH',
                    Value    => $TestData[2]->{Phone}
                }
            ]
        },
        Expected => [$ContactID3]
    },
    {
        Name     => "Search: Field Phone / Operator ENDSWITH / Value substr(\$TestData[2]->{Phone},-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Phone',
                    Operator => 'ENDSWITH',
                    Value    => substr($TestData[2]->{Phone},-2)
                }
            ]
        },
        Expected => [$ContactID1,$ContactID3]
    },
    {
        Name     => "Search: Field Phone / Operator CONTAINS / Value \$TestData[0]->{Phone}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Phone',
                    Operator => 'CONTAINS',
                    Value    => $TestData[0]->{Phone}
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Phone / Operator CONTAINS / Value substr(\$TestData[0]->{Phone},2,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Phone',
                    Operator => 'CONTAINS',
                    Value    => substr($TestData[0]->{Phone},2,-2)
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Phone / Operator LIKE / Value \$TestData[0]->{Phone}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Phone',
                    Operator => 'LIKE',
                    Value    => $TestData[0]->{Phone}
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Phone / Operator LIKE / Value *substr(\$TestData[0]->{Phone},5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Phone',
                    Operator => 'LIKE',
                    Value    => q{*} . substr($TestData[0]->{Phone},5)
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Lastname / Operator EQ / Value \$TestData[0]->{Lastname}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Lastname',
                    Operator => 'EQ',
                    Value    => $TestData[0]->{Lastname}
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2,$ContactID4]
    },
    {
        Name     => "Search: Field Lastname / Operator NE / Value \$TestData[0]->{Lastname}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Lastname',
                    Operator => 'NE',
                    Value    => $TestData[0]->{Lastname}
                }
            ]
        },
        Expected => ['1',$ContactID3]
    },
    {
        Name     => "Search: Field Lastname / Operator IN / Value \$TestData[0]->{Lastname}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Lastname',
                    Operator => 'IN',
                    Value    => $TestData[0]->{Lastname}
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2,$ContactID4]
    },
    {
        Name     => "Search: Field Lastname / Operator !IN / Value \$TestData[0]->{Lastname}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Lastname',
                    Operator => '!IN',
                    Value    => $TestData[0]->{Lastname}
                }
            ]
        },
        Expected => ['1',$ContactID3]
    },
    {
        Name     => "Search: Field Lastname / Operator STARTSWITH / Value \$TestData[1]->{Lastname}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Lastname',
                    Operator => 'STARTSWITH',
                    Value    => $TestData[1]->{Lastname}
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2,$ContactID4]
    },
    {
        Name     => "Search: Field Lastname / Operator STARTSWITH / Value substr(\$TestData[1]->{Lastname},0,2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Lastname',
                    Operator => 'STARTSWITH',
                    Value    => substr($TestData[1]->{Lastname},0,2)
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2,$ContactID4]
    },
    {
        Name     => "Search: Field Lastname / Operator ENDSWITH / Value \$TestData[2]->{Lastname}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Lastname',
                    Operator => 'ENDSWITH',
                    Value    => $TestData[2]->{Lastname}
                }
            ]
        },
        Expected => [$ContactID3]
    },
    {
        Name     => "Search: Field Lastname / Operator ENDSWITH / Value substr(\$TestData[2]->{Lastname},-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Lastname',
                    Operator => 'ENDSWITH',
                    Value    => substr($TestData[2]->{Lastname},-2)
                }
            ]
        },
        Expected => [$ContactID3]
    },
    {
        Name     => "Search: Field Lastname / Operator CONTAINS / Value \$TestData[0]->{Lastname}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Lastname',
                    Operator => 'CONTAINS',
                    Value    => $TestData[0]->{Lastname}
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2,$ContactID4]
    },
    {
        Name     => "Search: Field Lastname / Operator CONTAINS / Value substr(\$TestData[0]->{Lastname},1,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Lastname',
                    Operator => 'CONTAINS',
                    Value    => substr($TestData[0]->{Lastname},2,-2)
                }
            ]
        },
        Expected => ['1',$ContactID1,$ContactID2,$ContactID3,$ContactID4]
    },
    {
        Name     => "Search: Field Lastname / Operator LIKE / Value \$TestData[0]->{Lastname}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Lastname',
                    Operator => 'LIKE',
                    Value    => $TestData[0]->{Lastname}
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2,$ContactID4]
    },
    {
        Name     => "Search: Field Lastname / Operator LIKE / Value *substr(\$TestData[0]->{Lastname},2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Lastname',
                    Operator => 'LIKE',
                    Value    => q{*} . substr($TestData[0]->{Lastname},2)
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2,$ContactID4]
    },
    {
        Name     => "Search: Field Fax / Operator EQ / Value \$TestData[0]->{Fax}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fax',
                    Operator => 'EQ',
                    Value    => $TestData[0]->{Fax}
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Fax / Operator NE / Value \$TestData[0]->{Fax}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fax',
                    Operator => 'NE',
                    Value    => $TestData[0]->{Fax}
                }
            ]
        },
        Expected => ['1',$ContactID2,$ContactID3,$ContactID4]
    },
    {
        Name     => "Search: Field Fax / Operator IN / Value \$TestData[0]->{Fax}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fax',
                    Operator => 'IN',
                    Value    => $TestData[0]->{Fax}
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Fax / Operator !IN / Value \$TestData[0]->{Fax}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fax',
                    Operator => '!IN',
                    Value    => $TestData[0]->{Fax}
                }
            ]
        },
        Expected => [$ContactID4]
    },
    {
        Name     => "Search: Field Fax / Operator STARTSWITH / Value \$TestData[3]->{Fax}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fax',
                    Operator => 'STARTSWITH',
                    Value    => $TestData[3]->{Fax}
                }
            ]
        },
        Expected => [$ContactID4]
    },
    {
        Name     => "Search: Field Fax / Operator STARTSWITH / Value substr(\$TestData[3]->{Fax},0,4)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fax',
                    Operator => 'STARTSWITH',
                    Value    => substr($TestData[3]->{Fax},0,4)
                }
            ]
        },
        Expected => [$ContactID1,$ContactID4]
    },
    {
        Name     => "Search: Field Fax / Operator ENDSWITH / Value \$TestData[3]->{Fax}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fax',
                    Operator => 'ENDSWITH',
                    Value    => $TestData[3]->{Fax}
                }
            ]
        },
        Expected => [$ContactID4]
    },
    {
        Name     => "Search: Field Fax / Operator ENDSWITH / Value substr(\$TestData[3]->{Fax},-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fax',
                    Operator => 'ENDSWITH',
                    Value    => substr($TestData[3]->{Fax},-5)
                }
            ]
        },
        Expected => [$ContactID1,$ContactID4]
    },
    {
        Name     => "Search: Field Fax / Operator CONTAINS / Value \$TestData[0]->{Fax}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fax',
                    Operator => 'CONTAINS',
                    Value    => $TestData[0]->{Fax}
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Fax / Operator CONTAINS / Value substr(\$TestData[0]->{Fax},5,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fax',
                    Operator => 'CONTAINS',
                    Value    => substr($TestData[0]->{Fax},5,-5)
                }
            ]
        },
        Expected => [$ContactID1,$ContactID4]
    },
    {
        Name     => "Search: Field Fax / Operator LIKE / Value \$TestData[0]->{Fax}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fax',
                    Operator => 'LIKE',
                    Value    => $TestData[0]->{Fax}
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Fax / Operator LIKE / Value *substr(\$TestData[0]->{Fax},5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fax',
                    Operator => 'LIKE',
                    Value    => q{*} . substr($TestData[0]->{Fax},5)
                }
            ]
        },
        Expected => [$ContactID1,$ContactID4]
    },
    {
        Name     => "Search: Field Mobile / Operator EQ / Value \$TestData[1]->{Mobile}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Mobile',
                    Operator => 'EQ',
                    Value    => $TestData[1]->{Mobile}
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field Mobile / Operator NE / Value \$TestData[1]->{Mobile}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Mobile',
                    Operator => 'NE',
                    Value    => $TestData[1]->{Mobile}
                }
            ]
        },
        Expected => ['1',$ContactID1,$ContactID3,$ContactID4]
    },
    {
        Name     => "Search: Field Mobile / Operator IN / Value \$TestData[1]->{Mobile}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Mobile',
                    Operator => 'IN',
                    Value    => $TestData[1]->{Mobile}
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field Mobile / Operator !IN / Value \$TestData[1]->{Mobile}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Mobile',
                    Operator => '!IN',
                    Value    => $TestData[1]->{Mobile}
                }
            ]
        },
        Expected => [$ContactID3]
    },
    {
        Name     => "Search: Field Mobile / Operator STARTSWITH / Value \$TestData[2]->{Mobile}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Mobile',
                    Operator => 'STARTSWITH',
                    Value    => $TestData[2]->{Mobile}
                }
            ]
        },
        Expected => [$ContactID3]
    },
    {
        Name     => "Search: Field Mobile / Operator STARTSWITH / Value substr(\$TestData[2]->{Mobile},0,5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Mobile',
                    Operator => 'STARTSWITH',
                    Value    => substr($TestData[2]->{Mobile},0,5)
                }
            ]
        },
        Expected => [$ContactID3]
    },
    {
        Name     => "Search: Field Mobile / Operator ENDSWITH / Value \$TestData[2]->{Mobile}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Mobile',
                    Operator => 'ENDSWITH',
                    Value    => $TestData[2]->{Mobile}
                }
            ]
        },
        Expected => [$ContactID3]
    },
    {
        Name     => "Search: Field Mobile / Operator ENDSWITH / Value substr(\$TestData[2]->{Mobile},-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Mobile',
                    Operator => 'ENDSWITH',
                    Value    => substr($TestData[2]->{Mobile},-5)
                }
            ]
        },
        Expected => [$ContactID3]
    },
    {
        Name     => "Search: Field Mobile / Operator CONTAINS / Value \$TestData[1]->{Mobile}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Mobile',
                    Operator => 'CONTAINS',
                    Value    => $TestData[1]->{Mobile}
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field Mobile / Operator CONTAINS / Value substr(\$TestData[1]->{Mobile},5,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Mobile',
                    Operator => 'CONTAINS',
                    Value    => substr($TestData[1]->{Mobile},5,-5)
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field Mobile / Operator LIKE / Value \$TestData[1]->{Mobile}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Mobile',
                    Operator => 'LIKE',
                    Value    => $TestData[1]->{Mobile}
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field Mobile / Operator LIKE / Value *substr(\$TestData[1]->{Mobile},5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Mobile',
                    Operator => 'LIKE',
                    Value    => q{*} . substr($TestData[1]->{Mobile},5)
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field Street / Operator EQ / Value \$TestData[0]->{Street}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Street',
                    Operator => 'EQ',
                    Value    => $TestData[0]->{Street}
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Street / Operator NE / Value \$TestData[0]->{Street}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Street',
                    Operator => 'NE',
                    Value    => $TestData[0]->{Street}
                }
            ]
        },
        Expected => ['1',$ContactID2,$ContactID3,$ContactID4]
    },
    {
        Name     => "Search: Field Street / Operator IN / Value \$TestData[0]->{Street}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Street',
                    Operator => 'IN',
                    Value    => $TestData[0]->{Street}
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Street / Operator !IN / Value \$TestData[0]->{Street}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Street',
                    Operator => '!IN',
                    Value    => $TestData[0]->{Street}
                }
            ]
        },
        Expected => [$ContactID2,$ContactID4]
    },
    {
        Name     => "Search: Field Street / Operator STARTSWITH / Value \$TestData[3]->{Street}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Street',
                    Operator => 'STARTSWITH',
                    Value    => $TestData[3]->{Street}
                }
            ]
        },
        Expected => [$ContactID4]
    },
    {
        Name     => "Search: Field Street / Operator STARTSWITH / Value substr(\$TestData[3]->{Street},0,5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Street',
                    Operator => 'STARTSWITH',
                    Value    => substr($TestData[3]->{Street},0,5)
                }
            ]
        },
        Expected => [$ContactID1,$ContactID4]
    },
    {
        Name     => "Search: Field Street / Operator ENDSWITH / Value \$TestData[1]->{Street}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Street',
                    Operator => 'ENDSWITH',
                    Value    => $TestData[1]->{Street}
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field Street / Operator ENDSWITH / Value substr(\$TestData[1]->{Street},-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Street',
                    Operator => 'ENDSWITH',
                    Value    => substr($TestData[1]->{Street},-5)
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field Street / Operator CONTAINS / Value \$TestData[0]->{Street}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Street',
                    Operator => 'CONTAINS',
                    Value    => $TestData[0]->{Street}
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Street / Operator CONTAINS / Value substr(\$TestData[0]->{Street},5,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Street',
                    Operator => 'CONTAINS',
                    Value    => substr($TestData[0]->{Street},5,-5)
                }
            ]
        },
        Expected => [$ContactID1,$ContactID4]
    },
    {
        Name     => "Search: Field Street / Operator LIKE / Value \$TestData[0]->{Street}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Street',
                    Operator => 'LIKE',
                    Value    => $TestData[0]->{Street}
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Street / Operator LIKE / Value *substr(\$TestData[0]->{Street},5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Street',
                    Operator => 'LIKE',
                    Value    => q{*} . substr($TestData[0]->{Street},5)
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Zip / Operator EQ / Value \$TestData[0]->{Zip}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Zip',
                    Operator => 'EQ',
                    Value    => $TestData[0]->{Zip}
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Zip / Operator NE / Value \$TestData[0]->{Zip}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Zip',
                    Operator => 'NE',
                    Value    => $TestData[0]->{Zip}
                }
            ]
        },
        Expected => ['1',$ContactID2,$ContactID3,$ContactID4]
    },
    {
        Name     => "Search: Field Zip / Operator IN / Value \$TestData[0]->{Zip}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Zip',
                    Operator => 'IN',
                    Value    => $TestData[0]->{Zip}
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Zip / Operator !IN / Value \$TestData[0]->{Zip}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Zip',
                    Operator => '!IN',
                    Value    => $TestData[0]->{Zip}
                }
            ]
        },
        Expected => [$ContactID2,$ContactID4]
    },
    {
        Name     => "Search: Field Zip / Operator STARTSWITH / Value \$TestData[1]->{Zip}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Zip',
                    Operator => 'STARTSWITH',
                    Value    => $TestData[1]->{Zip}
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field Zip / Operator STARTSWITH / Value substr(\$TestData[1]->{Zip},0,3)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Zip',
                    Operator => 'STARTSWITH',
                    Value    => substr($TestData[1]->{Zip},0,3)
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field Zip / Operator ENDSWITH / Value \$TestData[3]->{Zip}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Zip',
                    Operator => 'ENDSWITH',
                    Value    => $TestData[3]->{Zip}
                }
            ]
        },
        Expected => [$ContactID4]
    },
    {
        Name     => "Search: Field Zip / Operator ENDSWITH / Value substr(\$TestData[3]->{Zip},-3)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Zip',
                    Operator => 'ENDSWITH',
                    Value    => substr($TestData[3]->{Zip},-3)
                }
            ]
        },
        Expected => [$ContactID4]
    },
    {
        Name     => "Search: Field Zip / Operator CONTAINS / Value \$TestData[0]->{Zip}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Zip',
                    Operator => 'CONTAINS',
                    Value    => $TestData[0]->{Zip}
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Zip / Operator CONTAINS / Value substr(\$TestData[0]->{Zip},1,-1)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Zip',
                    Operator => 'CONTAINS',
                    Value    => substr($TestData[0]->{Zip},1,-1)
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Zip / Operator LIKE / Value \$TestData[0]->{Zip}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Zip',
                    Operator => 'LIKE',
                    Value    => $TestData[0]->{Zip}
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Zip / Operator LIKE / Value *substr(\$TestData[0]->{Zip},3)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Zip',
                    Operator => 'LIKE',
                    Value    => q{*} . substr($TestData[0]->{Zip},3)
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field City / Operator EQ / Value \$TestData[0]->{City}",
        Search   => {
            'AND' => [
                {
                    Field    => 'City',
                    Operator => 'EQ',
                    Value    => $TestData[0]->{City}
                }
            ]
        },
        Expected => [$ContactID1,$ContactID4]
    },
    {
        Name     => "Search: Field City / Operator NE / Value \$TestData[0]->{City}",
        Search   => {
            'AND' => [
                {
                    Field    => 'City',
                    Operator => 'NE',
                    Value    => $TestData[0]->{City}
                }
            ]
        },
        Expected => ['1',$ContactID2,$ContactID3]
    },
    {
        Name     => "Search: Field City / Operator IN / Value \$TestData[0]->{City}",
        Search   => {
            'AND' => [
                {
                    Field    => 'City',
                    Operator => 'IN',
                    Value    => $TestData[0]->{City}
                }
            ]
        },
        Expected => [$ContactID1,$ContactID4]
    },
    {
        Name     => "Search: Field City / Operator !IN / Value \$TestData[0]->{City}",
        Search   => {
            'AND' => [
                {
                    Field    => 'City',
                    Operator => '!IN',
                    Value    => $TestData[0]->{City}
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field City / Operator STARTSWITH / Value \$TestData[1]->{City}",
        Search   => {
            'AND' => [
                {
                    Field    => 'City',
                    Operator => 'STARTSWITH',
                    Value    => $TestData[1]->{City}
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field City / Operator STARTSWITH / Value substr(\$TestData[1]->{City},0,5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'City',
                    Operator => 'STARTSWITH',
                    Value    => substr($TestData[1]->{City},0,5)
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field City / Operator ENDSWITH / Value \$TestData[3]->{City}",
        Search   => {
            'AND' => [
                {
                    Field    => 'City',
                    Operator => 'ENDSWITH',
                    Value    => $TestData[3]->{City}
                }
            ]
        },
        Expected => [$ContactID1,$ContactID4]
    },
    {
        Name     => "Search: Field City / Operator ENDSWITH / Value substr(\$TestData[3]->{City},-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'City',
                    Operator => 'ENDSWITH',
                    Value    => substr($TestData[3]->{City},-5)
                }
            ]
        },
        Expected => [$ContactID1,$ContactID4]
    },
    {
        Name     => "Search: Field City / Operator CONTAINS / Value \$TestData[0]->{City}",
        Search   => {
            'AND' => [
                {
                    Field    => 'City',
                    Operator => 'CONTAINS',
                    Value    => $TestData[0]->{City}
                }
            ]
        },
        Expected => [$ContactID1,$ContactID4]
    },
    {
        Name     => "Search: Field City / Operator CONTAINS / Value substr(\$TestData[0]->{City},5,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'City',
                    Operator => 'CONTAINS',
                    Value    => substr($TestData[0]->{City},5,-5)
                }
            ]
        },
        Expected => [$ContactID1,$ContactID4]
    },
    {
        Name     => "Search: Field City / Operator LIKE / Value \$TestData[0]->{City}",
        Search   => {
            'AND' => [
                {
                    Field    => 'City',
                    Operator => 'LIKE',
                    Value    => $TestData[0]->{City}
                }
            ]
        },
        Expected => [$ContactID1,$ContactID4]
    },
    {
        Name     => "Search: Field City / Operator LIKE / Value *substr(\$TestData[0]->{City},5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'City',
                    Operator => 'LIKE',
                    Value    => q{*} . substr($TestData[0]->{City},5)
                }
            ]
        },
        Expected => [$ContactID1,$ContactID4]
    },
    {
        Name     => "Search: Field Country / Operator EQ / Value \$TestData[0]->{Country}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Country',
                    Operator => 'EQ',
                    Value    => $TestData[0]->{Country}
                }
            ]
        },
        Expected => [$ContactID1,$ContactID4]
    },
    {
        Name     => "Search: Field Country / Operator NE / Value \$TestData[0]->{Country}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Country',
                    Operator => 'NE',
                    Value    => $TestData[0]->{Country}
                }
            ]
        },
        Expected => ['1',$ContactID2,$ContactID3]
    },
    {
        Name     => "Search: Field Country / Operator IN / Value \$TestData[0]->{Country}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Country',
                    Operator => 'IN',
                    Value    => $TestData[0]->{Country}
                }
            ]
        },
        Expected => [$ContactID1,$ContactID4]
    },
    {
        Name     => "Search: Field Country / Operator !IN / Value \$TestData[0]->{Country}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Country',
                    Operator => '!IN',
                    Value    => $TestData[0]->{Country}
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field Country / Operator STARTSWITH / Value \$TestData[1]->{Country}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Country',
                    Operator => 'STARTSWITH',
                    Value    => $TestData[1]->{Country}
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field Country / Operator STARTSWITH / Value substr(\$TestData[1]->{Country},0,5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Country',
                    Operator => 'STARTSWITH',
                    Value    => substr($TestData[1]->{Country},0,5)
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field Country / Operator ENDSWITH / Value \$TestData[3]->{Country}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Country',
                    Operator => 'ENDSWITH',
                    Value    => $TestData[3]->{Country}
                }
            ]
        },
        Expected => [$ContactID1,$ContactID4]
    },
    {
        Name     => "Search: Field Country / Operator ENDSWITH / Value substr(\$TestData[3]->{Country},-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Country',
                    Operator => 'ENDSWITH',
                    Value    => substr($TestData[3]->{Country},-5)
                }
            ]
        },
        Expected => [$ContactID1,$ContactID4]
    },
    {
        Name     => "Search: Field Country / Operator CONTAINS / Value \$TestData[0]->{Country}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Country',
                    Operator => 'CONTAINS',
                    Value    => $TestData[0]->{Country}
                }
            ]
        },
        Expected => [$ContactID1,$ContactID4]
    },
    {
        Name     => "Search: Field Country / Operator CONTAINS / Value substr(\$TestData[0]->{Country},5,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Country',
                    Operator => 'CONTAINS',
                    Value    => substr($TestData[0]->{Country},5,-5)
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2,$ContactID4]
    },
    {
        Name     => "Search: Field Country / Operator LIKE / Value \$TestData[0]->{Country}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Country',
                    Operator => 'LIKE',
                    Value    => $TestData[0]->{Country}
                }
            ]
        },
        Expected => [$ContactID1,$ContactID4]
    },
    {
        Name     => "Search: Field Country / Operator LIKE / Value *substr(\$TestData[0]->{Country},5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Country',
                    Operator => 'LIKE',
                    Value    => q{*} . substr($TestData[0]->{Country},5)
                }
            ]
        },
        Expected => [$ContactID1,$ContactID4]
    },
    {
        Name     => "Search: Field Comment / Operator EQ / Value \$TestData[1]->{Comment}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'EQ',
                    Value    => $TestData[1]->{Comment}
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field Comment / Operator NE / Value \$TestData[1]->{Comment}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'NE',
                    Value    => $TestData[1]->{Comment}
                }
            ]
        },
        Expected => ['1',$ContactID1,$ContactID3,$ContactID4]
    },
    {
        Name     => "Search: Field Comment / Operator IN / Value \$TestData[1]->{Comment}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'IN',
                    Value    => $TestData[1]->{Comment}
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field Comment / Operator !IN / Value \$TestData[1]->{Comment}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => '!IN',
                    Value    => $TestData[1]->{Comment}
                }
            ]
        },
        Expected => [$ContactID1,$ContactID4]
    },
    {
        Name     => "Search: Field Comment / Operator STARTSWITH / Value \$TestData[3]->{Comment}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'STARTSWITH',
                    Value    => $TestData[3]->{Comment}
                }
            ]
        },
        Expected => [$ContactID4]
    },
    {
        Name     => "Search: Field Comment / Operator STARTSWITH / Value substr(\$TestData[3]->{Comment},0,5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'STARTSWITH',
                    Value    => substr($TestData[3]->{Comment},0,5)
                }
            ]
        },
        Expected => [$ContactID4]
    },
    {
        Name     => "Search: Field Comment / Operator ENDSWITH / Value \$TestData[3]->{Comment}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'ENDSWITH',
                    Value    => $TestData[3]->{Comment}
                }
            ]
        },
        Expected => [$ContactID4]
    },
    {
        Name     => "Search: Field Comment / Operator ENDSWITH / Value substr(\$TestData[3]->{Comment},-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'ENDSWITH',
                    Value    => substr($TestData[3]->{Comment},-5)
                }
            ]
        },
        Expected => [$ContactID2,$ContactID4]
    },
    {
        Name     => "Search: Field Comment / Operator CONTAINS / Value \$TestData[1]->{Comment}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'CONTAINS',
                    Value    => $TestData[1]->{Comment}
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field Comment / Operator CONTAINS / Value substr(\$TestData[1]->{Comment},5,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'CONTAINS',
                    Value    => substr($TestData[1]->{Comment},5,-5)
                }
            ]
        },
        Expected => [$ContactID2,$ContactID4]
    },
    {
        Name     => "Search: Field Comment / Operator LIKE / Value \$TestData[1]->{Comment}",
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'LIKE',
                    Value    => $TestData[1]->{Comment}
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field Comment / Operator LIKE / Value *substr(\$TestData[1]->{Comment},5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'LIKE',
                    Value    => q{*} . substr($TestData[1]->{Comment},5)
                }
            ]
        },
        Expected => [$ContactID2,$ContactID4]
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Contact',
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

# check Sort
my @IntegrationSortTests = (
    {
        Name     => 'Sort: Field Title',
        Sort     => [
            {
                Field => 'Title'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ContactID3, $ContactID1, $ContactID2,'1',$ContactID4] : ['1',$ContactID4,$ContactID3, $ContactID1, $ContactID2]
    },
    {
        Name     => 'Sort: Field Title / Direction ascending',
        Sort     => [
            {
                Field     => 'Title',
                Direction => 'ascending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? [$ContactID3, $ContactID1, $ContactID2,'1',$ContactID4] : ['1',$ContactID4,$ContactID3, $ContactID1, $ContactID2]
    },
    {
        Name     => 'Sort: Field Title / Direction descending',
        Sort     => [
            {
                Field     => 'Title',
                Direction => 'descending'
            }
        ],
        Expected => $OrderByNull eq 'LAST' ? ['1',$ContactID4,$ContactID2, $ContactID1, $ContactID3] : [$ContactID2, $ContactID1, $ContactID3,'1',$ContactID4]
    },
    {
        Name     => 'Sort: Field Firstname',
        Sort     => [
            {
                Field => 'Firstname'
            }
        ],
        Expected => [$ContactID1,$ContactID2, $ContactID3,'1',$ContactID4]
    },
    {
        Name     => 'Sort: Field Firstname / Direction ascending',
        Sort     => [
            {
                Field     => 'Firstname',
                Direction => 'ascending'
            }
        ],
        Expected => [$ContactID1,$ContactID2, $ContactID3,'1',$ContactID4]
    },
    {
        Name     => 'Sort: Field Firstname / Direction descending',
        Sort     => [
            {
                Field     => 'Firstname',
                Direction => 'descending'
            }
        ],
        Expected => [$ContactID4,'1',$ContactID3, $ContactID2, $ContactID1]
    },
    {
        Name     => 'Sort: Field Phone',
        Sort     => [
            {
                Field => 'Phone'
            }
        ],
        Expected => ['1',$ContactID2,$ContactID4, $ContactID1, $ContactID3]
    },
    {
        Name     => 'Sort: Field Phone / Direction ascending',
        Sort     => [
            {
                Field     => 'Phone',
                Direction => 'ascending'
            }
        ],
        Expected => ['1',$ContactID2,$ContactID4, $ContactID1, $ContactID3]
    },
    {
        Name     => 'Sort: Field Phone / Direction descending',
        Sort     => [
            {
                Field     => 'Phone',
                Direction => 'descending'
            }
        ],
        Expected => [$ContactID3,$ContactID1,'1', $ContactID2, $ContactID4]
    },
    {
        Name     => 'Sort: Field Lastname',
        Sort     => [
            {
                Field => 'Lastname'
            }
        ],
        Expected => ['1',$ContactID3,$ContactID1, $ContactID2, $ContactID4]
    },
    {
        Name     => 'Sort: Field Lastname / Direction ascending',
        Sort     => [
            {
                Field     => 'Lastname',
                Direction => 'ascending'
            }
        ],
        Expected => ['1',$ContactID3,$ContactID1, $ContactID2, $ContactID4]
    },
    {
        Name     => 'Sort: Field Lastname / Direction descending',
        Sort     => [
            {
                Field     => 'Lastname',
                Direction => 'descending'
            }
        ],
        Expected => [$ContactID1,$ContactID2, $ContactID4, $ContactID3,'1']
    },
    {
        Name     => 'Sort: Field Fax',
        Sort     => [
            {
                Field => 'Fax'
            }
        ],
        Expected => ['1',$ContactID2,$ContactID3, $ContactID1, $ContactID4]
    },
    {
        Name     => 'Sort: Field Fax / Direction ascending',
        Sort     => [
            {
                Field     => 'Fax',
                Direction => 'ascending'
            }
        ],
        Expected => ['1',$ContactID2,$ContactID3, $ContactID1, $ContactID4]
    },
    {
        Name     => 'Sort: Field Fax / Direction descending',
        Sort     => [
            {
                Field     => 'Fax',
                Direction => 'descending'
            }
        ],
        Expected => [$ContactID4,$ContactID1,'1',$ContactID2, $ContactID3]
    },
    {
        Name     => 'Sort: Field Mobile',
        Sort     => [
            {
                Field => 'Mobile'
            }
        ],
        Expected => ['1',$ContactID1,$ContactID4, $ContactID2, $ContactID3]
    },
    {
        Name     => 'Sort: Field Mobile / Direction ascending',
        Sort     => [
            {
                Field     => 'Mobile',
                Direction => 'ascending'
            }
        ],
        Expected => ['1',$ContactID1,$ContactID4, $ContactID2, $ContactID3]
    },
    {
        Name     => 'Sort: Field Mobile / Direction descending',
        Sort     => [
            {
                Field     => 'Mobile',
                Direction => 'descending'
            }
        ],
        Expected => [$ContactID3,$ContactID2,'1',$ContactID1, $ContactID4]
    },
    {
        Name     => 'Sort: Field Street',
        Sort     => [
            {
                Field => 'Street'
            }
        ],
        Expected => ['1',$ContactID3,$ContactID2, $ContactID4, $ContactID1]
    },
    {
        Name     => 'Sort: Field Street / Direction ascending',
        Sort     => [
            {
                Field     => 'Street',
                Direction => 'ascending'
            }
        ],
        Expected => ['1',$ContactID3,$ContactID2, $ContactID4, $ContactID1]
    },
    {
        Name     => 'Sort: Field Street / Direction descending',
        Sort     => [
            {
                Field     => 'Street',
                Direction => 'descending'
            }
        ],
        Expected => [$ContactID1,$ContactID4, $ContactID2,'1',$ContactID3]
    },
    {
        Name     => 'Sort: Field Zip',
        Sort     => [
            {
                Field => 'Zip'
            }
        ],
        Expected => ['1',$ContactID3,$ContactID1, $ContactID4, $ContactID2]
    },
    {
        Name     => 'Sort: Field Zip / Direction ascending',
        Sort     => [
            {
                Field     => 'Zip',
                Direction => 'ascending'
            }
        ],
        Expected => ['1',$ContactID3,$ContactID1, $ContactID4, $ContactID2]
    },
    {
        Name     => 'Sort: Field Zip / Direction descending',
        Sort     => [
            {
                Field     => 'Zip',
                Direction => 'descending'
            }
        ],
        Expected => [$ContactID2,$ContactID4, $ContactID1,'1',$ContactID3]
    },
    {
        Name     => 'Sort: Field City',
        Sort     => [
            {
                Field => 'City'
            }
        ],
        Expected => ['1',$ContactID3,$ContactID2, $ContactID1, $ContactID4]
    },
    {
        Name     => 'Sort: Field City / Direction ascending',
        Sort     => [
            {
                Field     => 'City',
                Direction => 'ascending'
            }
        ],
        Expected => ['1',$ContactID3,$ContactID2, $ContactID1, $ContactID4]
    },
    {
        Name     => 'Sort: Field City / Direction descending',
        Sort     => [
            {
                Field     => 'City',
                Direction => 'descending'
            }
        ],
        Expected => [$ContactID1,$ContactID4,$ContactID2,'1',$ContactID3]
    },
    {
        Name     => 'Sort: Field Country',
        Sort     => [
            {
                Field => 'Country'
            }
        ],
        Expected => ['1',$ContactID3,$ContactID2, $ContactID1, $ContactID4]
    },
    {
        Name     => 'Sort: Field Country / Direction ascending',
        Sort     => [
            {
                Field     => 'Country',
                Direction => 'ascending'
            }
        ],
        Expected => ['1',$ContactID3,$ContactID2, $ContactID1, $ContactID4]
    },
    {
        Name     => 'Sort: Field Country / Direction descending',
        Sort     => [
            {
                Field     => 'Country',
                Direction => 'descending'
            }
        ],
        Expected => [$ContactID1,$ContactID4, $ContactID2,'1',$ContactID3]
    },
    {
        Name     => 'Sort: Field Comment',
        Sort     => [
            {
                Field => 'Comment'
            }
        ],
        Expected => ['1',$ContactID1,$ContactID3, $ContactID2, $ContactID4]
    },
    {
        Name     => 'Sort: Field Comment / Direction ascending',
        Sort     => [
            {
                Field     => 'Comment',
                Direction => 'ascending'
            }
        ],
        Expected => ['1',$ContactID1,$ContactID3, $ContactID2, $ContactID4]
    },
    {
        Name     => 'Sort: Field Comment / Direction descending',
        Sort     => [
            {
                Field     => 'Comment',
                Direction => 'descending'
            }
        ],
        Expected => [$ContactID4,$ContactID2,'1',$ContactID1,$ContactID3]
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Contact',
        Result     => 'ARRAY',
        Sort       => $Test->{Sort},
        Language   => 'en',
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
