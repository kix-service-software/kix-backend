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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Ticket::OwnerResponsible';

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
        OwnerID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','GT','GTE','LT','LTE'],
            ValueType    => 'NUMERIC'
        },
        Owner => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        OwnerName => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        OwnerOutOfOffice => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ'],
            ValueType    => 'NUMERIC'
        },
        ResponsibleID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','GT','GTE','LT','LTE'],
            ValueType    => 'NUMERIC'
        },
        Responsible => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        ResponsibleName => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        ResponsibleOutOfOffice => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ'],
            ValueType    => 'NUMERIC'
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

# set fixed time to have predetermined verifiable results
my $SystemTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
    String => '2014-01-01 12:00:00',
);
$Helper->FixedTimeSet($SystemTime);

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
            Field    => 'OwnerID',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => "Search: Value invalid",
        Search       => {
            Field    => 'OwnerID',
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
            Field    => 'OwnerID',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => "Search: Operator invalid",
        Search       => {
            Field    => 'OwnerID',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => "Search: valid search / Field OwnerID / Operator EQ",
        Search       => {
            Field    => 'OwnerID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join'       => [],
            'Where'      => [
                'st.user_id = 1'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field OwnerID / Operator NE",
        Search       => {
            Field    => 'OwnerID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join'       => [],
            'Where'      => [
                'st.user_id <> 1'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field OwnerID / Operator IN",
        Search       => {
            Field    => 'OwnerID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'       => [],
            'Where'      => [
                'st.user_id IN (1)'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field OwnerID / Operator !IN",
        Search       => {
            Field    => 'OwnerID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'       => [],
            'Where'      => [
                'st.user_id NOT IN (1)'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field OwnerID / Operator LT",
        Search       => {
            Field    => 'OwnerID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Join'       => [],
            'Where'      => [
                'st.user_id < 1'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field OwnerID / Operator GT",
        Search       => {
            Field    => 'OwnerID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Join'       => [],
            'Where'      => [
                'st.user_id > 1'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field OwnerID / Operator LTE",
        Search       => {
            Field    => 'OwnerID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Join'       => [],
            'Where'      => [
                'st.user_id <= 1'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field OwnerID / Operator GTE",
        Search       => {
            Field    => 'OwnerID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Join'       => [],
            'Where'      => [
                'st.user_id >= 1'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field Owner / Operator EQ",
        Search       => {
            Field    => 'Owner',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join'       => [
                'INNER JOIN users tou ON tou.id = st.user_id'
            ],
            'Where'      => [
                'tou.login = \'Test\''
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field Owner / Operator NE",
        Search       => {
            Field    => 'Owner',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join'       => [
                'INNER JOIN users tou ON tou.id = st.user_id'
            ],
            'Where'      => [
                'tou.login != \'Test\''
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field Owner / Operator IN",
        Search       => {
            Field    => 'Owner',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join'       => [
                'INNER JOIN users tou ON tou.id = st.user_id'
            ],
            'Where'      => [
                'tou.login IN (\'Test\')'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field Owner / Operator !IN",
        Search       => {
            Field    => 'Owner',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join'       => [
                'INNER JOIN users tou ON tou.id = st.user_id'
            ],
            'Where'      => [
                'tou.login NOT IN (\'Test\')'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field Owner / Operator STARTSWITH",
        Search       => {
            Field    => 'Owner',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join'       => [
                'INNER JOIN users tou ON tou.id = st.user_id'
            ],
            'Where'      => [
                'tou.login LIKE \'Test%\''
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field Owner / Operator ENDSWITH",
        Search       => {
            Field    => 'Owner',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected         => {
            'Join' => [
                'INNER JOIN users tou ON tou.id = st.user_id'
            ],
            'Where'      => [
                'tou.login LIKE \'%Test\''
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field Owner / Operator CONTAINS",
        Search       => {
            Field    => 'Owner',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Join'       => [
                'INNER JOIN users tou ON tou.id = st.user_id'
            ],
            'Where'      => [
                'tou.login LIKE \'%Test%\''
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field Owner / Operator LIKE",
        Search       => {
            Field    => 'Owner',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join'       => [
                'INNER JOIN users tou ON tou.id = st.user_id'
            ],
            'Where'      => [
                'tou.login LIKE \'Test\''
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field OwnerName / Operator EQ",
        Search       => {
            Field    => 'OwnerName',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join'       => [
                'INNER JOIN users tou ON tou.id = st.user_id',
                'LEFT OUTER JOIN contact touc ON touc.user_id = tou.id'
            ],
            'Where'      => [
                $CaseSensitive ? '(LOWER(touc.lastname) = \'test\' OR LOWER(touc.firstname) = \'test\')' : '(touc.lastname = \'test\' OR touc.firstname = \'test\')'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field OwnerName / Operator NE",
        Search       => {
            Field    => 'OwnerName',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join'       => [
                'INNER JOIN users tou ON tou.id = st.user_id',
                'LEFT OUTER JOIN contact touc ON touc.user_id = tou.id'
            ],
            'Where'      => [
                $CaseSensitive ? '(LOWER(touc.lastname) != \'test\' OR LOWER(touc.firstname) != \'test\')' : '(touc.lastname != \'test\' OR touc.firstname != \'test\')'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field OwnerName / Operator IN",
        Search       => {
            Field    => 'OwnerName',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join'       => [
                'INNER JOIN users tou ON tou.id = st.user_id',
                'LEFT OUTER JOIN contact touc ON touc.user_id = tou.id'
            ],
            'Where'      => [
                $CaseSensitive ? '(LOWER(touc.lastname) IN (\'test\') OR LOWER(touc.firstname) IN (\'test\'))' : '(touc.lastname IN (\'test\') OR touc.firstname IN (\'test\'))'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field OwnerName / Operator !IN",
        Search       => {
            Field    => 'OwnerName',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join'       => [
                'INNER JOIN users tou ON tou.id = st.user_id',
                'LEFT OUTER JOIN contact touc ON touc.user_id = tou.id'
            ],
            'Where'      => [
                $CaseSensitive ? '(LOWER(touc.lastname) NOT IN (\'test\') OR LOWER(touc.firstname) NOT IN (\'test\'))' : '(touc.lastname NOT IN (\'test\') OR touc.firstname NOT IN (\'test\'))'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field OwnerName / Operator STARTSWITH",
        Search       => {
            Field    => 'OwnerName',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join'       => [
                'INNER JOIN users tou ON tou.id = st.user_id',
                'LEFT OUTER JOIN contact touc ON touc.user_id = tou.id'
            ],
            'Where'      => [
                $CaseSensitive ? '(LOWER(touc.lastname) LIKE \'test%\' OR LOWER(touc.firstname) LIKE \'test%\')' : '(touc.lastname LIKE \'test%\' OR touc.firstname LIKE \'test%\')'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field OwnerName / Operator ENDSWITH",
        Search       => {
            Field    => 'OwnerName',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join'       => [
                'INNER JOIN users tou ON tou.id = st.user_id',
                'LEFT OUTER JOIN contact touc ON touc.user_id = tou.id'
            ],
            'Where'      => [
                $CaseSensitive ? '(LOWER(touc.lastname) LIKE \'%test\' OR LOWER(touc.firstname) LIKE \'%test\')' : '(touc.lastname LIKE \'%test\' OR touc.firstname LIKE \'%test\')'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field OwnerName / Operator CONTAINS",
        Search       => {
            Field    => 'OwnerName',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Join'       => [
                'INNER JOIN users tou ON tou.id = st.user_id',
                'LEFT OUTER JOIN contact touc ON touc.user_id = tou.id'
            ],
            'Where'      => [
                $CaseSensitive ? '(LOWER(touc.lastname) LIKE \'%test%\' OR LOWER(touc.firstname) LIKE \'%test%\')' : '(touc.lastname LIKE \'%test%\' OR touc.firstname LIKE \'%test%\')'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field OwnerName / Operator LIKE",
        Search       => {
            Field    => 'OwnerName',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join'       => [
                'INNER JOIN users tou ON tou.id = st.user_id',
                'LEFT OUTER JOIN contact touc ON touc.user_id = tou.id'
            ],
            'Where'      => [
                $CaseSensitive ? '(LOWER(touc.lastname) LIKE \'test\' OR LOWER(touc.firstname) LIKE \'test\')' : '(touc.lastname LIKE \'test\' OR touc.firstname LIKE \'test\')'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => 'Search: valid search / Field OwnerOutOfOffice / Operator EQ / Value 1',
        Search       => {
            Field    => 'OwnerOutOfOffice',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join'       => [
                'LEFT OUTER JOIN user_preferences toupooos ON toupooos.user_id = st.user_id AND toupooos.preferences_key = \'OutOfOfficeStart\'',
                'LEFT OUTER JOIN user_preferences toupoooe ON toupoooe.user_id = st.user_id AND toupoooe.preferences_key = \'OutOfOfficeEnd\''
            ],
            'Where'      => [
                '(toupooos.preferences_value <= \'2014-01-01\' AND toupoooe.preferences_value >= \'2014-01-01\')'
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field OwnerOutOfOffice / Operator EQ / Value 0',
        Search       => {
            Field    => 'OwnerOutOfOffice',
            Operator => 'EQ',
            Value    => '0'
        },
        Expected     => {
            'Join'       => [
                'LEFT OUTER JOIN user_preferences toupooos ON toupooos.user_id = st.user_id AND toupooos.preferences_key = \'OutOfOfficeStart\'',
                'LEFT OUTER JOIN user_preferences toupoooe ON toupoooe.user_id = st.user_id AND toupoooe.preferences_key = \'OutOfOfficeEnd\''
            ],
            'Where'      => [
                '(toupooos.preferences_value > \'2014-01-01\' OR toupoooe.preferences_value < \'2014-01-01\' OR toupooos.preferences_value IS NULL OR toupoooe.preferences_value IS NULL)'
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field OwnerOutOfOffice / Operator EQ / Value [0,1]',
        Search       => {
            Field    => 'OwnerOutOfOffice',
            Operator => 'EQ',
            Value    => ['0','1']
        },
        Expected     => {
            'Join'       => [
                'LEFT OUTER JOIN user_preferences toupooos ON toupooos.user_id = st.user_id AND toupooos.preferences_key = \'OutOfOfficeStart\'',
                'LEFT OUTER JOIN user_preferences toupoooe ON toupoooe.user_id = st.user_id AND toupoooe.preferences_key = \'OutOfOfficeEnd\''
            ],
            'Where'      => [
                '((toupooos.preferences_value > \'2014-01-01\' OR toupoooe.preferences_value < \'2014-01-01\' OR toupooos.preferences_value IS NULL OR toupoooe.preferences_value IS NULL) OR (toupooos.preferences_value <= \'2014-01-01\' AND toupoooe.preferences_value >= \'2014-01-01\'))'
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => "Search: valid search / Field ResponsibleID / Operator EQ",
        Search       => {
            Field    => 'ResponsibleID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join'      => [],
            'Where'     => [
                'st.responsible_user_id = 1'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field ResponsibleID / Operator NE",
        Search       => {
            Field    => 'ResponsibleID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join'       => [],
            'Where'      => [
                'st.responsible_user_id <> 1'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field ResponsibleID / Operator IN",
        Search       => {
            Field    => 'ResponsibleID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'       => [],
            'Where'      => [
                'st.responsible_user_id IN (1)'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field ResponsibleID / Operator !IN",
        Search       => {
            Field    => 'ResponsibleID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'       => [],
            'Where'      => [
                'st.responsible_user_id NOT IN (1)'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field ResponsibleID / Operator LT",
        Search       => {
            Field    => 'ResponsibleID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Join'       => [],
            'Where'      => [
                'st.responsible_user_id < 1'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field ResponsibleID / Operator GT",
        Search       => {
            Field    => 'ResponsibleID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Join'       => [],
            'Where'      => [
                'st.responsible_user_id > 1'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field ResponsibleID / Operator LTE",
        Search       => {
            Field    => 'ResponsibleID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Join'       => [],
            'Where'      => [
                'st.responsible_user_id <= 1'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field ResponsibleID / Operator GTE",
        Search       => {
            Field    => 'ResponsibleID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Join'       => [],
            'Where'      => [
                'st.responsible_user_id >= 1'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field Responsible / Operator EQ",
        Search       => {
            Field    => 'Responsible',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join'       => [
                'INNER JOIN users tru ON tru.id = st.responsible_user_id'
            ],
            'Where'      => [
                'tru.login = \'Test\''
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field Responsible / Operator NE",
        Search       => {
            Field    => 'Responsible',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join'       => [
                'INNER JOIN users tru ON tru.id = st.responsible_user_id'
            ],
            'Where'      => [
                'tru.login != \'Test\''
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field Responsible / Operator IN",
        Search       => {
            Field    => 'Responsible',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join'       => [
                'INNER JOIN users tru ON tru.id = st.responsible_user_id'
            ],
            'Where'      => [
                'tru.login IN (\'Test\')'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field Responsible / Operator !IN",
        Search       => {
            Field    => 'Responsible',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join'       => [
                'INNER JOIN users tru ON tru.id = st.responsible_user_id'
            ],
            'Where'      => [
                'tru.login NOT IN (\'Test\')'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field Responsible / Operator STARTSWITH",
        Search       => {
            Field    => 'Responsible',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join'       => [
                'INNER JOIN users tru ON tru.id = st.responsible_user_id'
            ],
            'Where'      => [
                'tru.login LIKE \'Test%\''
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field Responsible / Operator ENDSWITH",
        Search       => {
            Field    => 'Responsible',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join'       => [
                'INNER JOIN users tru ON tru.id = st.responsible_user_id'
            ],
            'Where'      => [
                'tru.login LIKE \'%Test\''
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field Responsible / Operator CONTAINS",
        Search       => {
            Field    => 'Responsible',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Join'       => [
                'INNER JOIN users tru ON tru.id = st.responsible_user_id'
            ],
            'Where'      => [
                'tru.login LIKE \'%Test%\''
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field Responsible / Operator LIKE",
        Search       => {
            Field    => 'Responsible',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join'       => [
                'INNER JOIN users tru ON tru.id = st.responsible_user_id'
            ],
            'Where'      => [
                'tru.login LIKE \'Test\''
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field ResponsibleName / Operator EQ",
        Search       => {
            Field    => 'ResponsibleName',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join'       => [
                'INNER JOIN users tru ON tru.id = st.responsible_user_id',
                'LEFT OUTER JOIN contact truc ON truc.user_id = tru.id'
            ],
            'Where'      => [
                $CaseSensitive ? '(LOWER(truc.lastname) = \'test\' OR LOWER(truc.firstname) = \'test\')' : '(truc.lastname = \'test\' OR truc.firstname = \'test\')'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field ResponsibleName / Operator NE",
        Search       => {
            Field    => 'ResponsibleName',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join'       => [
                'INNER JOIN users tru ON tru.id = st.responsible_user_id',
                'LEFT OUTER JOIN contact truc ON truc.user_id = tru.id'
            ],
            'Where'      => [
                $CaseSensitive ? '(LOWER(truc.lastname) != \'test\' OR LOWER(truc.firstname) != \'test\')' : '(truc.lastname != \'test\' OR truc.firstname != \'test\')'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field ResponsibleName / Operator IN",
        Search       => {
            Field    => 'ResponsibleName',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join'       => [
                'INNER JOIN users tru ON tru.id = st.responsible_user_id',
                'LEFT OUTER JOIN contact truc ON truc.user_id = tru.id'
            ],
            'Where'      => [
                $CaseSensitive ? '(LOWER(truc.lastname) IN (\'test\') OR LOWER(truc.firstname) IN (\'test\'))' : '(truc.lastname IN (\'test\') OR truc.firstname IN (\'test\'))'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field ResponsibleName / Operator !IN",
        Search       => {
            Field    => 'ResponsibleName',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
             'Join'      => [
                'INNER JOIN users tru ON tru.id = st.responsible_user_id',
                'LEFT OUTER JOIN contact truc ON truc.user_id = tru.id'
            ],
            'Where'      => [
                $CaseSensitive ? '(LOWER(truc.lastname) NOT IN (\'test\') OR LOWER(truc.firstname) NOT IN (\'test\'))' : '(truc.lastname NOT IN (\'test\') OR truc.firstname NOT IN (\'test\'))'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field ResponsibleName / Operator STARTSWITH",
        Search       => {
            Field    => 'ResponsibleName',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join'       => [
                'INNER JOIN users tru ON tru.id = st.responsible_user_id',
                'LEFT OUTER JOIN contact truc ON truc.user_id = tru.id'
            ],
            'Where'      => [
                $CaseSensitive ? '(LOWER(truc.lastname) LIKE \'test%\' OR LOWER(truc.firstname) LIKE \'test%\')' : '(truc.lastname LIKE \'test%\' OR truc.firstname LIKE \'test%\')'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field ResponsibleName / Operator ENDSWITH",
        Search       => {
            Field    => 'ResponsibleName',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join'       => [
                'INNER JOIN users tru ON tru.id = st.responsible_user_id',
                'LEFT OUTER JOIN contact truc ON truc.user_id = tru.id'
            ],
            'Where'      => [
                $CaseSensitive ? '(LOWER(truc.lastname) LIKE \'%test\' OR LOWER(truc.firstname) LIKE \'%test\')' : '(truc.lastname LIKE \'%test\' OR truc.firstname LIKE \'%test\')'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field ResponsibleName / Operator CONTAINS",
        Search       => {
            Field    => 'ResponsibleName',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Join'       => [
                'INNER JOIN users tru ON tru.id = st.responsible_user_id',
                'LEFT OUTER JOIN contact truc ON truc.user_id = tru.id'
            ],
            'Where'      => [
                $CaseSensitive ? '(LOWER(truc.lastname) LIKE \'%test%\' OR LOWER(truc.firstname) LIKE \'%test%\')' : '(truc.lastname LIKE \'%test%\' OR truc.firstname LIKE \'%test%\')'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => "Search: valid search / Field ResponsibleName / Operator LIKE",
        Search       => {
            Field    => 'ResponsibleName',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join'       => [
                'INNER JOIN users tru ON tru.id = st.responsible_user_id',
                'LEFT OUTER JOIN contact truc ON truc.user_id = tru.id'
            ],
            'Where'      => [
                $CaseSensitive ? '(LOWER(truc.lastname) LIKE \'test\' OR LOWER(truc.firstname) LIKE \'test\')' : '(truc.lastname LIKE \'test\' OR truc.firstname LIKE \'test\')'
            ],
            'IsRelative' => undef
        }
    },
    {
        Name         => 'Search: valid search / Field ResponsibleOutOfOffice / Operator EQ / Value 1',
        Search       => {
            Field    => 'ResponsibleOutOfOffice',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join'       => [
                'LEFT OUTER JOIN user_preferences trupooos ON trupooos.user_id = st.user_id AND trupooos.preferences_key = \'OutOfOfficeStart\'',
                'LEFT OUTER JOIN user_preferences trupoooe ON trupoooe.user_id = st.user_id AND trupoooe.preferences_key = \'OutOfOfficeEnd\''
            ],
            'Where'      => [
                '(trupooos.preferences_value <= \'2014-01-01\' AND trupoooe.preferences_value >= \'2014-01-01\')'
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field ResponsibleOutOfOffice / Operator EQ / Value 0',
        Search       => {
            Field    => 'ResponsibleOutOfOffice',
            Operator => 'EQ',
            Value    => '0'
        },
        Expected     => {
            'Join'       => [
                'LEFT OUTER JOIN user_preferences trupooos ON trupooos.user_id = st.user_id AND trupooos.preferences_key = \'OutOfOfficeStart\'',
                'LEFT OUTER JOIN user_preferences trupoooe ON trupoooe.user_id = st.user_id AND trupoooe.preferences_key = \'OutOfOfficeEnd\''
            ],
            'Where'      => [
                '(trupooos.preferences_value > \'2014-01-01\' OR trupoooe.preferences_value < \'2014-01-01\' OR trupooos.preferences_value IS NULL OR trupoooe.preferences_value IS NULL)'
            ],
            'IsRelative' => 1
        }
    },
    {
        Name         => 'Search: valid search / Field ResponsibleOutOfOffice / Operator EQ / Value [0,1]',
        Search       => {
            Field    => 'ResponsibleOutOfOffice',
            Operator => 'EQ',
            Value    => ['0','1']
        },
        Expected     => {
            'Join'       => [
                'LEFT OUTER JOIN user_preferences trupooos ON trupooos.user_id = st.user_id AND trupooos.preferences_key = \'OutOfOfficeStart\'',
                'LEFT OUTER JOIN user_preferences trupoooe ON trupoooe.user_id = st.user_id AND trupoooe.preferences_key = \'OutOfOfficeEnd\''
            ],
            'Where'      => [
                '((trupooos.preferences_value > \'2014-01-01\' OR trupoooe.preferences_value < \'2014-01-01\' OR trupooos.preferences_value IS NULL OR trupoooe.preferences_value IS NULL) OR (trupooos.preferences_value <= \'2014-01-01\' AND trupoooe.preferences_value >= \'2014-01-01\'))'
            ],
            'IsRelative' => 1
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
        Name      => 'Sort: Attribute "OwnerID"',
        Attribute => 'OwnerID',
        Expected  => {
            'Join'    => [],
            'OrderBy' => [
                'st.user_id'
            ],
            'Select'  => [
                'st.user_id'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Owner"',
        Attribute => 'Owner',
        Expected  => {
            'Join' => [
                'INNER JOIN users tou ON tou.id = st.user_id',
                'LEFT OUTER JOIN contact touc ON touc.user_id = tou.id'
            ],
            'OrderBy' => [
                'LOWER(touc.lastname)',
                'LOWER(touc.firstname)',
                'LOWER(tou.login)'
            ],
            'Select' => [
                'touc.lastname',
                'touc.firstname',
                'tou.login'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "OwnerName"',
        Attribute => 'OwnerName',
        Expected  => {
            'Join' => [
                'INNER JOIN users tou ON tou.id = st.user_id',
                'LEFT OUTER JOIN contact touc ON touc.user_id = tou.id'
            ],
            'OrderBy' => [
                'LOWER(touc.lastname)',
                'LOWER(touc.firstname)'
            ],
            'Select' => [
                'touc.lastname',
                'touc.firstname'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "ResponsibleID"',
        Attribute => 'ResponsibleID',
        Expected  => {
            'Join'    => [],
            'OrderBy' => [
                'st.responsible_user_id'
            ],
            'Select'  => [
                'st.responsible_user_id'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Responsible"',
        Attribute => 'Responsible',
        Expected  => {
            'Join' => [
                'INNER JOIN users tru ON tru.id = st.responsible_user_id',
                'LEFT OUTER JOIN contact truc ON truc.user_id = tru.id'
            ],
            'OrderBy' => [
                'LOWER(truc.lastname)',
                'LOWER(truc.firstname)',
                'LOWER(tru.login)'
            ],
            'Select' => [
                'truc.lastname',
                'truc.firstname',
                'tru.login'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "ResponsibleName"',
        Attribute => 'ResponsibleName',
        Expected  => {
            'Join' => [
                'INNER JOIN users tru ON tru.id = st.responsible_user_id',
                'LEFT OUTER JOIN contact truc ON truc.user_id = tru.id'
            ],
            'OrderBy' => [
                'LOWER(truc.lastname)',
                'LOWER(truc.firstname)'
            ],
            'Select' => [
                'truc.lastname',
                'truc.firstname'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "OwnerOutOfOffice" is not sortable',
        Attribute => 'OwnerOutOfOffice',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "ResponsibleOutOfOffice" is not sortable',
        Attribute => 'ResponsibleOutOfOffice',
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

## prepare user mapping
my $RoleID = $Kernel::OM->Get('Role')->RoleLookup(
    Role => 'Ticket Agent'
);
my $UserLogin1 = 'Test001';
my $UserLogin2 = 'test002';
my $UserLogin3 = 'Test003';
my $UserName1 = 'Alf';
my $UserName2 = 'Bert';
my $UserName3 = 'Test';
my $ContactFirstName1 = 'Alf';
my $ContactFirstName2 = 'Bert';
my $ContactLastName1  = 'test';
my $ContactLastName2  = 'Test';
my $UserID1 = $Kernel::OM->Get('User')->UserAdd(
    UserLogin     => $UserLogin1,
    ValidID       => 1,
    ChangeUserID  => 1,
    IsAgent       => 1
);
$Kernel::OM->Get('Role')->RoleUserAdd(
    AssignUserID => $UserID1,
    RoleID       => $RoleID,
    UserID       => 1,
);
$Self->True(
    $UserID1,
    'First user created'
);
my $ContactID1 = $Kernel::OM->Get('Contact')->ContactAdd(
    Firstname             => $ContactFirstName1,
    Lastname              => $ContactLastName1,
    AssignedUserID        => $UserID1,
    ValidID               => 1,
    UserID                => 1,
);
$Self->True(
    $ContactID1,
    'Contact for first user created'
);
my $UserPOOOOS1 = $Kernel::OM->Get('User')->SetPreferences(
    Key    => 'OutOfOfficeStart',
    Value  => '2014-01-01',
    UserID => $UserID1,
);
$Self->True(
    $UserPOOOOS1,
    'OutOfOfficeStart for first user created'
);
my $UserPOOOOE1 = $Kernel::OM->Get('User')->SetPreferences(
    Key    => 'OutOfOfficeEnd',
    Value  => '2014-01-01',
    UserID => $UserID1,
);
$Self->True(
    $UserPOOOOE1,
    'OutOfOfficeEnd for first user created'
);
my $UserID2 = $Kernel::OM->Get('User')->UserAdd(
    UserLogin     => $UserLogin2,
    ValidID       => 1,
    ChangeUserID  => 1,
    IsAgent       => 1
);
$Kernel::OM->Get('Role')->RoleUserAdd(
    AssignUserID => $UserID2,
    RoleID       => $RoleID,
    UserID       => 1,
);
$Self->True(
    $UserID2,
    'Second user created'
);
my $ContactID2 = $Kernel::OM->Get('Contact')->ContactAdd(
    Firstname             => $ContactFirstName2,
    Lastname              => $ContactLastName2,
    AssignedUserID        => $UserID2,
    ValidID               => 1,
    UserID                => 1,
);
$Self->True(
    $ContactID2,
    'Contact for second user created'
);
my $UserPOOOOS2 = $Kernel::OM->Get('User')->SetPreferences(
    Key    => 'OutOfOfficeStart',
    Value  => '2014-01-02',
    UserID => $UserID2,
);
$Self->True(
    $UserPOOOOS2,
    'OutOfOfficeStart for second user created'
);
my $UserPOOOOE2 = $Kernel::OM->Get('User')->SetPreferences(
    Key    => 'OutOfOfficeEnd',
    Value  => '2014-01-02',
    UserID => $UserID2,
);
$Self->True(
    $UserPOOOOE2,
    'OutOfOfficeEnd for second user created'
);
my $UserID3 = $Kernel::OM->Get('User')->UserAdd(
    UserLogin     => $UserLogin3,
    ValidID       => 1,
    ChangeUserID  => 1,
    IsAgent       => 1
);
$Kernel::OM->Get('Role')->RoleUserAdd(
    AssignUserID => $UserID3,
    RoleID       => $RoleID,
    UserID       => 1,
);
$Self->True(
    $UserID3,
    'Third user created'
);

# discard contact object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Contact'],
);

# discard user object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['User'],
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
    OrganisationID => 1,
    ContactID      => 1,
    OwnerID        => $UserID1,
    ResponsibleID  => $UserID1,
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
    OrganisationID => 1,
    ContactID      => 1,
    OwnerID        => $UserID2,
    ResponsibleID  => $UserID2,
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
    OrganisationID => 1,
    ContactID      => 1,
    OwnerID        => $UserID3,
    ResponsibleID  => $UserID3,
    UserID         => 1
);
$Self->True(
    $TicketID3,
    'Created third ticket'
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Ticket'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => "Search: Field OwnerID / Operator EQ / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerID',
                    Operator => 'EQ',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OwnerID / Operator NE / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerID',
                    Operator => 'NE',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => "Search: Field OwnerID / Operator IN / Value [\$UserID1,\$UserID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerID',
                    Operator => 'IN',
                    Value    => [$UserID1,$UserID3]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID3]
    },
    {
        Name     => "Search: Field OwnerID / Operator !IN / Value [\$UserID1,\$UserID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerID',
                    Operator => '!IN',
                    Value    => [$UserID1,$UserID3]
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OwnerID / Operator LT / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerID',
                    Operator => 'LT',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => "Search: Field OwnerID / Operator GT / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerID',
                    Operator => 'GT',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => "Search: Field OwnerID / Operator LTE / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerID',
                    Operator => 'LTE',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2]
    },
    {
        Name     => "Search: Field OwnerID / Operator GTE / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerID',
                    Operator => 'GTE',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$TicketID2, $TicketID3]
    },
    {
        Name     => "Search: Field Owner / Operator EQ / Value \$UserLogin2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Owner',
                    Operator => 'EQ',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field Owner / Operator NE / Value \$UserLogin2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Owner',
                    Operator => 'NE',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => "Search: Field Owner / Operator IN / Value [\$UserLogin1,\$UserLogin3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Owner',
                    Operator => 'IN',
                    Value    => [$UserLogin1,$UserLogin3]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID3]
    },
    {
        Name     => "Search: Field Owner / Operator !IN / Value [\$UserLogin1,\$UserLogin3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Owner',
                    Operator => '!IN',
                    Value    => [$UserLogin1,$UserLogin3]
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field Owner / Operator STARTSWITH / Value \$UserLogin2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Owner',
                    Operator => 'STARTSWITH',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field Owner / Operator STARTSWITH / Value substr(\$UserLogin2,0,4)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Owner',
                    Operator => 'STARTSWITH',
                    Value    => substr($UserLogin2,0,4)
                }
            ]
        },
        Expected => $CaseSensitive ? [$TicketID2] : [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => "Search: Field Owner / Operator ENDSWITH / Value \$UserLogin2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Owner',
                    Operator => 'ENDSWITH',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field Owner / Operator ENDSWITH / Value substr(\$UserLogin2,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Owner',
                    Operator => 'ENDSWITH',
                    Value    => substr($UserLogin2,-5)
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field Owner / Operator CONTAINS / Value \$UserLogin2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Owner',
                    Operator => 'CONTAINS',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field Owner / Operator CONTAINS / Value substr(\$UserLogin2,2,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Owner',
                    Operator => 'CONTAINS',
                    Value    => substr($UserLogin2,2,-2)
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => "Search: Field Owner / Operator LIKE / Value \$UserLogin2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Owner',
                    Operator => 'LIKE',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OwnerName / Operator EQ / Value \$UserName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerName',
                    Operator => 'EQ',
                    Value    => $UserName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OwnerName / Operator NE / Value \$UserName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerName',
                    Operator => 'NE',
                    Value    => $UserName2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => "Search: Field OwnerName / Operator IN / Value [\$UserName1,\$UserName3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerName',
                    Operator => 'IN',
                    Value    => [$UserName1,$UserName3]
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => "Search: Field OwnerName / Operator !IN / Value [\$UserName1,\$UserName3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerName',
                    Operator => '!IN',
                    Value    => [$UserName1,$UserName3]
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OwnerName / Operator STARTSWITH / Value \$UserName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerName',
                    Operator => 'STARTSWITH',
                    Value    => $UserName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OwnerName / Operator STARTSWITH / Value substr(\$UserName2,0,2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerName',
                    Operator => 'STARTSWITH',
                    Value    => substr($UserName2,0,2)
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OwnerName / Operator ENDSWITH / Value \$UserName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerName',
                    Operator => 'ENDSWITH',
                    Value    => $UserName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OwnerName / Operator ENDSWITH / Value substr(\$UserName2,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerName',
                    Operator => 'ENDSWITH',
                    Value    => substr($UserName2,-2)
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OwnerName / Operator CONTAINS / Value \$UserName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerName',
                    Operator => 'CONTAINS',
                    Value    => $UserName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OwnerName / Operator CONTAINS / Value substr(\$UserName3,1,-1)",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerName',
                    Operator => 'CONTAINS',
                    Value    => substr($UserName3,1,-1)
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => "Search: Field OwnerName / Operator LIKE / Value \$UserName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerName',
                    Operator => 'LIKE',
                    Value    => $UserName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field ResponsibleID / Operator EQ / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleID',
                    Operator => 'EQ',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field ResponsibleID / Operator NE / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleID',
                    Operator => 'NE',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => "Search: Field ResponsibleID / Operator IN / Value [\$UserID1,\$UserID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleID',
                    Operator => 'IN',
                    Value    => [$UserID1,$UserID3]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID3]
    },
    {
        Name     => "Search: Field ResponsibleID / Operator !IN / Value [\$UserID1,\$UserID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleID',
                    Operator => '!IN',
                    Value    => [$UserID1,$UserID3]
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field ResponsibleID / Operator LT / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleID',
                    Operator => 'LT',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => "Search: Field ResponsibleID / Operator GT / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleID',
                    Operator => 'GT',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => "Search: Field ResponsibleID / Operator LTE / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleID',
                    Operator => 'LTE',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2]
    },
    {
        Name     => "Search: Field ResponsibleID / Operator GTE / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleID',
                    Operator => 'GTE',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$TicketID2, $TicketID3]
    },
    {
        Name     => "Search: Field Responsible / Operator EQ / Value \$UserLogin2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Responsible',
                    Operator => 'EQ',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field Responsible / Operator NE / Value \$UserLogin2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Responsible',
                    Operator => 'NE',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => "Search: Field Responsible / Operator IN / Value [\$UserLogin1,\$UserLogin3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Responsible',
                    Operator => 'IN',
                    Value    => [$UserLogin1,$UserLogin3]
                }
            ]
        },
        Expected => [$TicketID1, $TicketID3]
    },
    {
        Name     => "Search: Field Responsible / Operator !IN / Value [\$UserLogin1,\$UserLogin3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Responsible',
                    Operator => '!IN',
                    Value    => [$UserLogin1,$UserLogin3]
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field Responsible / Operator STARTSWITH / Value \$UserLogin2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Responsible',
                    Operator => 'STARTSWITH',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field Responsible / Operator STARTSWITH / Value substr(\$UserLogin2,0,4)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Responsible',
                    Operator => 'STARTSWITH',
                    Value    => substr($UserLogin2,0,4)
                }
            ]
        },
        Expected => $CaseSensitive ? [$TicketID2] : [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => "Search: Field Responsible / Operator ENDSWITH / Value \$UserLogin2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Responsible',
                    Operator => 'ENDSWITH',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field Responsible / Operator ENDSWITH / Value substr(\$UserLogin2,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Responsible',
                    Operator => 'ENDSWITH',
                    Value    => substr($UserLogin2,-5)
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field Responsible / Operator CONTAINS / Value \$UserLogin2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Responsible',
                    Operator => 'CONTAINS',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field Responsible / Operator CONTAINS / Value substr(\$UserLogin2,2,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Responsible',
                    Operator => 'CONTAINS',
                    Value    => substr($UserLogin2,2,-2)
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => "Search: Field Responsible / Operator LIKE / Value \$UserLogin2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Responsible',
                    Operator => 'LIKE',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field ResponsibleName / Operator EQ / Value \$UserName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleName',
                    Operator => 'EQ',
                    Value    => $UserName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field ResponsibleName / Operator NE / Value \$UserName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleName',
                    Operator => 'NE',
                    Value    => $UserName2
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => "Search: Field ResponsibleName / Operator IN / Value [\$UserName1,\$UserName3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleName',
                    Operator => 'IN',
                    Value    => [$UserName1,$UserName3]
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => "Search: Field ResponsibleName / Operator !IN / Value [\$UserName1,\$UserName3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleName',
                    Operator => '!IN',
                    Value    => [$UserName1,$UserName3]
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field ResponsibleName / Operator STARTSWITH / Value \$UserName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleName',
                    Operator => 'STARTSWITH',
                    Value    => $UserName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field ResponsibleName / Operator STARTSWITH / Value substr(\$UserName2,0,2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleName',
                    Operator => 'STARTSWITH',
                    Value    => substr($UserName2,0,2)
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field ResponsibleName / Operator ENDSWITH / Value \$UserName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleName',
                    Operator => 'ENDSWITH',
                    Value    => $UserName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field ResponsibleName / Operator ENDSWITH / Value substr(\$UserName2,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleName',
                    Operator => 'ENDSWITH',
                    Value    => substr($UserName2,-2)
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field ResponsibleName / Operator CONTAINS / Value \$UserName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleName',
                    Operator => 'CONTAINS',
                    Value    => $UserName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field ResponsibleName / Operator CONTAINS / Value substr(\$UserName3,1,-1)",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleName',
                    Operator => 'CONTAINS',
                    Value    => substr($UserName3,1,-1)
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => "Search: Field ResponsibleName / Operator LIKE / Value \$UserName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleName',
                    Operator => 'LIKE',
                    Value    => $UserName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field OwnerOutOfOffice / Operator EQ / Value 1',
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerOutOfOffice',
                    Operator => 'EQ',
                    Value    => 1
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: Field OwnerOutOfOffice / Operator EQ / Value 0',
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerOutOfOffice',
                    Operator => 'EQ',
                    Value    => 0
                }
            ]
        },
        Expected => [$TicketID2,$TicketID3]
    },
    {
        Name     => 'Search: Field ResponsibleOutOfOffice / Operator EQ / Value 1',
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleOutOfOffice',
                    Operator => 'EQ',
                    Value    => 1
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: Field ResponsibleOutOfOffice / Operator EQ / Value 0',
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleOutOfOffice',
                    Operator => 'EQ',
                    Value    => 0
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
        Name     => 'Sort: Field OwnerID',
        Sort     => [
            {
                Field => 'OwnerID'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field OwnerID / Direction ascending',
        Sort     => [
            {
                Field     => 'OwnerID',
                Direction => 'ascending'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field OwnerID / Direction descending',
        Sort     => [
            {
                Field     => 'OwnerID',
                Direction => 'descending'
            }
        ],
        Expected => [$TicketID3, $TicketID2, $TicketID1]
    },
    {
        Name     => 'Sort: Field Owner',
        Sort     => [
            {
                Field => 'Owner'
            }
        ],
        Expected => $CaseSensitive ? [$TicketID1,$TicketID2,$TicketID3] : [$TicketID3,$TicketID1,$TicketID2]
    },
    {
        Name     => 'Sort: Field Owner / Direction ascending',
        Sort     => [
            {
                Field     => 'Owner',
                Direction => 'ascending'
            }
        ],
        Expected => $CaseSensitive ? [$TicketID1,$TicketID2,$TicketID3] : [$TicketID3,$TicketID1,$TicketID2]
    },
    {
        Name     => 'Sort: Field Owner / Direction descending',
        Sort     => [
            {
                Field     => 'Owner',
                Direction => 'descending'
            }
        ],
        Expected => $CaseSensitive ? [$TicketID3,$TicketID2,$TicketID1] : [$TicketID2,$TicketID1,$TicketID3]
    },
    {
        Name     => 'Sort: Field OwnerName',
        Sort     => [
            {
                Field => 'OwnerName'
            }
        ],
        Expected => $CaseSensitive ? [$TicketID1,$TicketID2,$TicketID3] : [$TicketID3,$TicketID1,$TicketID2]
    },
    {
        Name     => 'Sort: Field OwnerName / Direction ascending',
        Sort     => [
            {
                Field     => 'OwnerName',
                Direction => 'ascending'
            }
        ],
        Expected => $CaseSensitive ? [$TicketID1,$TicketID2,$TicketID3] : [$TicketID3,$TicketID1,$TicketID2]
    },
    {
        Name     => 'Sort: Field OwnerName / Direction descending',
        Sort     => [
            {
                Field     => 'OwnerName',
                Direction => 'descending'
            }
        ],
        Expected => $CaseSensitive ? [$TicketID3,$TicketID2,$TicketID1] : [$TicketID2,$TicketID1,$TicketID3]
    },
    {
        Name     => 'Sort: Field ResponsibleID',
        Sort     => [
            {
                Field => 'ResponsibleID'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field ResponsibleID / Direction ascending',
        Sort     => [
            {
                Field     => 'ResponsibleID',
                Direction => 'ascending'
            }
        ],
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => 'Sort: Field ResponsibleID / Direction descending',
        Sort     => [
            {
                Field     => 'ResponsibleID',
                Direction => 'descending'
            }
        ],
        Expected => [$TicketID3, $TicketID2, $TicketID1]
    },
    {
        Name     => 'Sort: Field Responsible',
        Sort     => [
            {
                Field => 'Responsible'
            }
        ],
        Expected => $CaseSensitive ? [$TicketID1,$TicketID2,$TicketID3] : [$TicketID3,$TicketID1,$TicketID2]
    },
    {
        Name     => 'Sort: Field Responsible / Direction ascending',
        Sort     => [
            {
                Field     => 'Responsible',
                Direction => 'ascending'
            }
        ],
        Expected => $CaseSensitive ? [$TicketID1,$TicketID2,$TicketID3] : [$TicketID3,$TicketID1,$TicketID2]
    },
    {
        Name     => 'Sort: Field Responsible / Direction descending',
        Sort     => [
            {
                Field     => 'Responsible',
                Direction => 'descending'
            }
        ],
        Expected => $CaseSensitive ? [$TicketID3,$TicketID2,$TicketID1] : [$TicketID2,$TicketID1,$TicketID3]
    },
    {
        Name     => 'Sort: Field ResponsibleName',
        Sort     => [
            {
                Field => 'ResponsibleName'
            }
        ],
        Expected => $CaseSensitive ? [$TicketID1,$TicketID2,$TicketID3] : [$TicketID3,$TicketID1,$TicketID2]
    },
    {
        Name     => 'Sort: Field ResponsibleName / Direction ascending',
        Sort     => [
            {
                Field     => 'ResponsibleName',
                Direction => 'ascending'
            }
        ],
        Expected => $CaseSensitive ? [$TicketID1,$TicketID2,$TicketID3] : [$TicketID3,$TicketID1,$TicketID2]
    },
    {
        Name     => 'Sort: Field ResponsibleName / Direction descending',
        Sort     => [
            {
                Field     => 'ResponsibleName',
                Direction => 'descending'
            }
        ],
        Expected => $CaseSensitive ? [$TicketID3,$TicketID2,$TicketID1] : [$TicketID2,$TicketID1,$TicketID3]
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
