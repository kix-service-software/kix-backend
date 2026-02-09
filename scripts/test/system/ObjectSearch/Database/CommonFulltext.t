# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/
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

my $CommonFulltextModule = 'Kernel::System::ObjectSearch::Database::CommonFulltext';

# require module
return if ( !$Kernel::OM->Get('Main')->Require( $CommonFulltextModule ) );

# create backend object
my $CommonFulltextObject = $CommonFulltextModule->new( %{ $Self } );
$Self->Is(
    ref( $CommonFulltextObject ),
    $CommonFulltextModule,
    'CommonFulltext object has correct module ref'
);

# check supported methods
for my $Method (
    qw(
        GetSupportedAttributes FulltextSearch
        _CheckSearchParams _ValidateValueType
        _FulltextCondition _FulltextValueCleanUp _FulltextColumnSQL
    )
) {
    $Self->True(
        $CommonFulltextObject->can($Method),
        'CommonFulltext object can "' . $Method . '"'
    );
}

## check internal functions ##
my @LargeArray = (0) x 1000;

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

# check FulltextSearch and _GetFulltextCondition
my @GetOperationTests = (
    {
        Name      => 'FulltextSearch: Column undef',
        Parameter => {
            Columns => undef,
            UserID  => 1,
            Search  => {
                Field    => 'Fulltext',
                Operator => 'LIKE',
                Value    => 'Test'
            }
        },
        Expected  => undef
    },
    {
        Name      => 'FulltextSearch: Column empty',
        Parameter => {
            Columns => '',
            Search  => {
                Field    => 'Fulltext',
                Operator => 'LIKE',
                Value    => 'Test'
            }
        },
        Expected  => undef
    },
    {
        Name      => 'FulltextSearch: Search undef',
        Parameter => {
            Columns => ['test'],
            UserID  => 1,
            Search  => undef
        },
        Expected  => undef
    },
    {
        Name      => 'FulltextSearch: Search empty',
        Parameter => {
            Columns => ['test'],
            UserID  => 1,
            Search  => {}
        },
        Expected  => undef
    },
    {
        Name      => 'FulltextSearch: Search Operator undef',
        Parameter => {
            Columns => ['test'],
            UserID  => 1,
            Search  => {
                Field    => 'Fulltext',
                Operator => undef,
                Value    => 'Test'
            }
        },
        Expected  => undef
    },
    {
        Name      => 'FulltextSearch: Search Operator empty',
        Parameter => {
            Columns => ['test'],
            UserID  => 1,
            Search  => {
                Field    => 'Fulltext',
                Operator => '',
                Value    => 'Test'
            }
        },
        Expected  => undef
    },
    {
        Name      => 'FulltextSearch: Search Operator invalid',
        Parameter => {
            Columns => ['test'],
            UserID  => 1,
            Search  => {
                Field    => 'Fulltext',
                Operator => 'Invalid',
                Value    => 'Test'
            }
        },
        Expected  => undef
    },
    {
        Name      => 'FulltextSearch: Search Value undef',
        Parameter => {
            Columns => ['test'],
            UserID  => 1,
            Search  => {
                Field    => 'Fulltext',
                Operator => 'LIKE',
                Value    => undef
            }
        },
        Expected  => undef
    },
    {
        Name      => 'FulltextSearch: UserID undef',
        Parameter => {
            Columns => ['test'],
            UserID  => undef,
            Search  => {
                Field     => 'Fulltext',
                Operator  => 'LIKE',
                Value     => 'Test',
                ValueType => 'NUMERIC'
            }
        },
        Expected  => undef
    },
    {
        Name      => 'FulltextSearch: UserID empty',
        Parameter => {
            Columns => ['test'],
            UserID  => '',
            Search  => {
                Field     => 'Fulltext',
                Operator  => 'LIKE',
                Value     => 'Test',
                ValueType => 'NUMERIC'
            }
        },
        Expected  => undef
    },
    {
        Name      => 'FulltextSearch: single column / text value',
        Parameter => {
            Columns => ['test'],
            UserID  => 1,
            Search  => {
                Field    => 'Fulltext',
                Operator => 'LIKE',
                Value    => 'Test'
            }
        },
        Expected  => {
            'Join'  => undef,
            'Where' => [
                $CaseSensitive
                    ? '(LOWER(test) LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
                    : '(test LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
            ]
        }
    },
    {
        Name      => 'FulltextSearch: single column / text spaced value',
        Parameter => {
            Columns   => ['test'],
            UserID  => 1,
            Search  => {
                Field    => 'Fulltext',
                Operator => 'LIKE',
                Value    => 'Test 1',
            }
        },
        Expected  => {
            'Join'  => undef,
            'Where' => [
                $CaseSensitive
                    ? '(LOWER(test) LIKE \'%test%\' ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE \'%1%\' ESCAPE \'' . $Escape . '\') '
                    : '(test LIKE \'%test%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%1%\' ESCAPE \'' . $Escape . '\') '
            ]
        }
    },
    {
        Name      => 'FulltextSearch: single column / text value / SQL Injection',
        Parameter => {
            Columns   => ['test'],
            UserID  => 1,
            Search  => {
                Field    => 'Fulltext',
                Operator => 'LIKE',
                Value    => '\';SELECT * FROM mail_account;SELECT st.id FROM ticket WHERE title = \'test'
            }
        },
        Expected  => {
            'Join' => undef,
            'Where' => [
                $CaseSensitive
                    ? '(LOWER(test) LIKE \'%\'\';select%\' ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE \'%%%\' ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE \'%from%\' ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE \'%mail\\_account;select%\' ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE \'%st.id%\' ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE \'%from%\' ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE \'%ticket%\' ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE \'%where%\' ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE \'%title%\' ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE \'%=%\' ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE \'%\'\'test%\' ESCAPE \'' . $Escape . '\') '
                    : '(test LIKE \'%\'\';select%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%%%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%from%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%mail\\_account;select%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%st.id%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%from%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%ticket%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%where%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%title%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%=%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%\'\'test%\' ESCAPE \'' . $Escape . '\') '
            ]
        }
    },
    {
        Name      => 'FulltextSearch: column array / text value ',
        Parameter => {
            Columns => ['test1','test2'],
            UserID  => 1,
            Search  => {
                Field    => 'Fulltext',
                Operator => 'LIKE',
                Value   => 'Test'
            }
        },
        Expected  => {
            'Join'  => undef,
            'Where' => [
                $CaseSensitive
                    ? '(LOWER(test1) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(test2) LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
                    : '(test1 LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR test2 LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
            ]
        }
    },
    {
        Name      => 'FulltextSearch: column array / text spaced value ',
        Parameter => {
            Columns => ['test1','test2'],
            UserID  => 1,
            Search  => {
                Field    => 'Fulltext',
                Operator => 'LIKE',
                Value   => 'Test 1'
            }
        },
        Expected  => {
            'Join' => undef,
            'Where' => [
                $CaseSensitive
                    ? '(LOWER(test1) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(test2) LIKE \'%test%\' ESCAPE \'' . $Escape . '\')  AND (LOWER(test1) LIKE \'%1%\' ESCAPE \'' . $Escape . '\' OR LOWER(test2) LIKE \'%1%\' ESCAPE \'' . $Escape . '\') '
                    : '(test1 LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR test2 LIKE \'%test%\' ESCAPE \'' . $Escape . '\')  AND (test1 LIKE \'%1%\' ESCAPE \'' . $Escape . '\' OR test2 LIKE \'%1%\' ESCAPE \'' . $Escape . '\') '
            ]
        }
    },
    {
        Name      => '_FulltextCondition: Columns undef',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => undef,
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected  => undef
    },
    {
        Name      => '_FulltextCondition: Columns empty',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => '',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected  => undef
    },
    {
        Name      => '_FulltextCondition: Value undef',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => undef
        },
        Expected  => undef
    },
    {
        Name      => '_FulltextCondition: Columns undef and StaticColumns undef',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns       => undef,
            StaticColumns => undef,
            Operator      => 'LIKE',
            Value         => 'Test'
        },
        Expected  => undef
    },
    {
        Name      => '_FulltextCondition: Columns empty and StaticColumns undef',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns       => '',
            StaticColumns => undef,
            Operator      => 'LIKE',
            Value         => 'Test'
        },
        Expected  => undef
    },
    {
        Name      => '_FulltextCondition: no Columns and StaticColumns undef',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns => undef,
            Operator      => 'LIKE',
            Value         => 'Test'
        },
        Expected  => undef
    },
    {
        Name      => '_FulltextCondition: no Columns and StaticColumns empty and IsStaticSearch',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => undef,
            Value          => 'Test',
            IsStaticSearch => 1
        },
        Expected  => undef
    },
    {
        Name      => '_FulltextCondition: single column/ simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => 'UnitTest'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column/ quoted simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => '"UnitTest"'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column/ double quoted and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => '"Unit"+Test'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE \'%test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column/ double quoted and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => '"Unit" Test'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE \'%test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column/ "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => '"Unit+Test"'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%unit+test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit+test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column/ space in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => '"Unit Test"'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%unit test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column/ double quoted and "|" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => '"Unit"|Test'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE \'%test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column/ "|" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => '"Unit|Test"'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%unit|test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit|test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column/ double quoted and "|" and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => '"Unit"|Test+Baa'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE \'%test%\' ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE \'%baa%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%baa%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column/ double quoted and "|" and "+" and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => 'Foo "Unit"|Test+Baa'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%foo%\' ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE \'%test%\' ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE \'%baa%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%foo%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%baa%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column/ space, "|", "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => '"Foo Unit|Test+Baa"'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%foo unit|test+baa%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%foo unit|test+baa%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column/ not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => '"UnitTest'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column/ "|" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => 'Unit|"Test'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE \'%test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column/ "+" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => 'Unit+"Test'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE \'%test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column/ space and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => 'Unit "Test'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE \'%test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column/ wildcard text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => 'Unit*Test'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%unit%test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column/ wildcard in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => '"Unit*Test"'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%unit*test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit*test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single columns / ###1### and + and double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => '"Test"+###1###',
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%test%\' ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE \'%###1###%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%test%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%###1###%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns/ simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => 'UnitTest'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns/ quoted simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => '"UnitTest"'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns/ double quoted and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => '"Unit"+Test'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE \'%test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns/ double quoted and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => '"Unit" Test'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE \'%test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns/ "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => '"Unit+Test"'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%unit+test%\' ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE \'%unit+test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit+test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit+test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns/ space in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => '"Unit Test"'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%unit test%\' ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE \'%unit test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns/ double quoted and "|" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => '"Unit"|Test'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE \'%test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns/ "|" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => '"Unit|Test"'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%unit|test%\' ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE \'%unit|test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit|test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit|test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns/ double quoted and "|" and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => '"Unit"|Test+Baa'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE \'%test%\' ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE \'%baa%\' ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE \'%baa%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%test%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%baa%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%baa%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns/ double quoted and "|" and "+" and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => 'Foo "Unit"|Test+Baa'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%foo%\' ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE \'%foo%\' ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE \'%test%\' ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE \'%baa%\' ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE \'%baa%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%foo%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%foo%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%test%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%baa%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%baa%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns/ space, "|", "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => '"Foo Unit|Test+Baa"'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%foo unit|test+baa%\' ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE \'%foo unit|test+baa%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%foo unit|test+baa%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%foo unit|test+baa%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns/ not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => '"UnitTest'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns/ "|" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => 'Unit|"Test'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE \'%test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns/ "+" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => 'Unit+"Test'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE \'%test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns/ space and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => 'Unit "Test'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE \'%test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns/ wildcard text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => 'Unit*Test'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%unit%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE \'%unit%test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit%test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns/ wildcard in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => '"Unit*Test"'
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%unit*test%\' ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE \'%unit*test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit*test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit*test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / ###1### and + and double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => '"Test"+###1###',
        },
        Expected  => $CaseSensitive ? '(LOWER(test) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE \'%test%\' ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE \'%###1###%\' ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE \'%###1###%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%test%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%###1###%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%###1###%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column/ simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Value          => 'UnitTest',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column/ quoted simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Value          => '"UnitTest"',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column/ double quoted and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Value          => '"Unit"+Test',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column/ double quoted and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Value          => '"Unit" Test',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column/ "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Value          => '"Unit+Test"',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%unit+test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit+test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column/ space in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Value          => '"Unit Test"',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%unit test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column/ double quoted and "|" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Value          => '"Unit"|Test',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column/ "|" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Value          => '"Unit|Test"',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%unit|test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit|test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column/ double quoted and "|" and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Value          => '"Unit"|Test+Baa',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%baa%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%baa%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column/ double quoted and "|" and "+" and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Value          => 'Foo "Unit"|Test+Baa',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%foo%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%baa%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%foo%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%baa%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column/ space, "|", "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Value          => '"Foo Unit|Test+Baa"',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%foo unit|test+baa%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%foo unit|test+baa%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column/ not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Value          => '"UnitTest',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column/ "|" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Value          => 'Unit|"Test',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column/ "+" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Value          => 'Unit+"Test',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column/ space and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Value          => 'Unit "Test',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column/ wildcard text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Value          => 'Unit*Test',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%unit%test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column/ wildcard in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Value          => '"Unit*Test"',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%unit*test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit*test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static StaticColumns / ###1### and + and double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Value          => '"Test"+###1###',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%test%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%###1###%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%test%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%###1###%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns / simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Value          => 'UnitTest',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns / quoted simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Value          => '"UnitTest"',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns / double quoted and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Value          => '"Unit"+Test',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns / double quoted and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Value          => '"Unit" Test',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns / "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Value          => '"Unit+Test"',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%unit+test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit+test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit+test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit+test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns / space in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Value          => '"Unit Test"',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%unit test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns / double quoted and "|" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Value          => '"Unit"|Test',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns / "|" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Value          => '"Unit|Test"',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%unit|test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit|test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit|test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit|test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns / double quoted and "|" and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Value          => '"Unit"|Test+Baa',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%test%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%baa%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%baa%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%test%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%baa%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%baa%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns / double quoted and "|" and "+" and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Value          => 'Foo "Unit"|Test+Baa',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%foo%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%foo%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%test%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%baa%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%baa%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%foo%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%foo%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%test%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%baa%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%baa%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns / space, "|", "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Value          => '"Foo Unit|Test+Baa"',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%foo unit|test+baa%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%foo unit|test+baa%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%foo unit|test+baa%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%foo unit|test+baa%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns / not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Value          => '"UnitTest',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unittest%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns / "|" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Value          => 'Unit|"Test',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  OR (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns / "+" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Value          => 'Unit+"Test',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns / space and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Value          => 'Unit "Test',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns / wildcard text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Value          => 'Unit*Test',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%unit%test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit%test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit%test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit%test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns / wildcard in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Value          => '"Unit*Test"',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%unit*test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit*test%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%unit*test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%unit*test%\' ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns / ###1### and + and double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Value          => '"Test"+###1###',
            IsStaticSearch => 1
        },
        Expected  => $CaseSensitive ? '(test LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%test%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%###1###%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%###1###%\' ESCAPE \'' . $Escape . '\') ' : '(test LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%test%\' ESCAPE \'' . $Escape . '\')  AND (test LIKE \'%###1###%\' ESCAPE \'' . $Escape . '\' OR Foo LIKE \'%###1###%\' ESCAPE \'' . $Escape . '\') '
    }
);
for my $Test ( @GetOperationTests ) {
    my $Method = $Test->{Method} || 'FulltextSearch';

    my $Result = $CommonFulltextObject->$Method(
        %{ $Test->{Parameter} },
        Silent => defined( $Test->{Expected} ) ? 0 : 1
    );
    if ( $Method eq 'FulltextSearch' ) {
        $Self->IsDeeply (
            $Result,
            $Test->{Expected},
            $Test->{Name}
        );
    }
    else {
        $Self->Is(
            $Result,
            $Test->{Expected},
            $Test->{Name}
        );
    }
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
