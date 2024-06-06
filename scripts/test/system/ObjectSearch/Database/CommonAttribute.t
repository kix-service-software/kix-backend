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

my $CommonAttributeModule = 'Kernel::System::ObjectSearch::Database::CommonAttribute';

# require module
return if ( !$Kernel::OM->Get('Main')->Require( $CommonAttributeModule ) );

# create backend object
my $CommonAttributeObject = $CommonAttributeModule->new( %{ $Self } );
$Self->Is(
    ref( $CommonAttributeObject ),
    $CommonAttributeModule,
    'CommonAttribute object has correct module ref'
);

# check supported methods
for my $Method (
    qw(
        GetSupportedAttributes Search Sort
        _GetCondition
        _CheckSearchParams _ValidateValueType _CheckSortParams
        _FulltextCondition _FulltextValueCleanUp _FulltextColumnSQL
    )
) {
    $Self->True(
        $CommonAttributeObject->can($Method),
        'CommonAttribute object can "' . $Method . '"'
    );
}

## check internal functions ##
my @LargeArray = (0) x 1000;

# Quoting ESCAPE character backslash
my $QuoteBack = $Kernel::OM->Get('DB')->{'DB::QuoteBack'};
my $Escape = "\\";
if ( $QuoteBack ) {
    $Escape =~ s/\\/$QuoteBack\\/g;
}

# check _GetCondition
my @GetOperationTests = (
    {
        Name      => '_GetCondition: Column undef',
        Parameter => {
            Column   => undef,
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected  => undef
    },
    {
        Name      => '_GetCondition: Column empty',
        Parameter => {
            Column   => '',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected  => undef
    },
    {
        Name      => '_GetCondition: Operator undef',
        Parameter => {
            Column   => 'test',
            Operator => undef,
            Value    => 'Test'
        },
        Expected  => undef
    },
    {
        Name      => '_GetCondition: Operator empty',
        Parameter => {
            Column   => 'test',
            Operator => '',
            Value    => 'Test'
        },
        Expected  => undef
    },
    {
        Name      => '_GetCondition: Operator invalid',
        Parameter => {
            Column   => 'test',
            Operator => 'Invalid',
            Value    => 'Test'
        },
        Expected  => undef
    },
    {
        Name      => '_GetCondition: Value undef',
        Parameter => {
            Column   => 'test',
            Operator => 'EQ',
            Value    => undef
        },
        Expected  => undef
    },
    {
        Name      => '_GetCondition: Value invalid for ValueType NUMERIC',
        Parameter => {
            Column    => 'test',
            Operator  => 'EQ',
            Value     => 'Test',
            ValueType => 'NUMERIC'
        },
        Expected  => undef
    },
    {
        Name      => '_GetCondition: single column / Operator EQ / text value',
        Parameter => {
            Column   => 'test',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected  => 'test = \'Test\''
    },
    {
        Name      => '_GetCondition: single column / Operator EQ / numeric value',
        Parameter => {
            Column    => 'test',
            Operator  => 'EQ',
            Value     => '1',
            ValueType => 'NUMERIC'
        },
        Expected  => 'test = 1'
    },
    {
        Name      => '_GetCondition: single column / Operator EQ / text array value',
        Parameter => {
            Column   => 'test',
            Operator => 'EQ',
            Value    => ['Test1','Test2']
        },
        Expected  => '(test = \'Test1\' OR test = \'Test2\')'
    },
    {
        Name      => '_GetCondition: single column / Operator EQ / numeric array value',
        Parameter => {
            Column    => 'test',
            Operator  => 'EQ',
            Value     => ['1','2'],
            ValueType => 'NUMERIC'
        },
        Expected  => '(test = 1 OR test = 2)'
    },
    {
        Name      => '_GetCondition: single column / Operator EQ / empty value',
        Parameter => {
            Column   => 'test',
            Operator => 'EQ',
            Value    => ''
        },
        Expected  => 'test = \'\''
    },
    {
        Name      => '_GetCondition: single column / Operator EQ / empty value with NULLValue',
        Parameter => {
            Column    => 'test',
            Operator  => 'EQ',
            Value     => '',
            NULLValue => 1
        },
        Expected  => '(test = \'\' OR test IS NULL)'
    },
    {
        Name      => '_GetCondition: single column / Operator EQ / empty value with NULLValue and CaseInsensitive',
        Parameter => {
            Column          => 'test',
            Operator        => 'EQ',
            Value           => '',
            NULLValue       => 1,
            CaseInsensitive => 1
        },
        Expected  => '(LOWER(test) = \'\' OR test IS NULL)'
    },
    {
        Name      => '_GetCondition: single column / Operator EQ / numeric zero value',
        Parameter => {
            Column    => 'test',
            Operator  => 'EQ',
            Value     => '0',
            ValueType => 'NUMERIC'
        },
        Expected  => 'test = 0'
    },
    {
        Name      => '_GetCondition: single column / Operator EQ / numeric zero value with NULLValue',
        Parameter => {
            Column    => 'test',
            Operator  => 'EQ',
            Value     => '0',
            ValueType => 'NUMERIC',
            NULLValue => 1
        },
        Expected  => '(test = 0 OR test IS NULL)'
    },
    {
        Name      => '_GetCondition: single column / Operator EQ / text array value with Supplement',
        Parameter => {
            Column     => 'test',
            Operator   => 'EQ',
            Value      => ['Test1','Test2'],
            Supplement => ['try = 1']
        },
        Expected  => '((test = \'Test1\' OR test = \'Test2\') AND try = 1)'
    },
    {
        Name      => '_GetCondition: single column / Operator EQ / text array value with CaseInsensitive',
        Parameter => {
            Column          => 'test',
            Operator        => 'EQ',
            Value           => ['Test1','Test2'],
            CaseInsensitive => 1
        },
        Expected  => '(LOWER(test) = \'test1\' OR LOWER(test) = \'test2\')'
    },
    {
        Name      => '_GetCondition: single column / Operator EQ / text value / SQL Injection',
        Parameter => {
            Column   => 'test',
            Operator => 'EQ',
            Value    => '\';SELECT * FROM mail_account;SELECT st.id FROM ticket WHERE title = \'test'
        },
        Expected  => 'test = \'\'\';SELECT * FROM mail_account;SELECT st.id FROM ticket WHERE title = \'\'test\''
    },
    {
        Name      => '_GetCondition: column array / Operator EQ / text array value with Supplement',
        Parameter => {
            Column     => ['test1','test2'],
            Operator   => 'EQ',
            Value      => ['Test1','Test2'],
            Supplement => ['try = 1']
        },
        Expected  => '((test1 = \'Test1\' OR test1 = \'Test2\' OR test2 = \'Test1\' OR test2 = \'Test2\') AND try = 1)'
    },
    {
        Name      => '_GetCondition: single column / Operator NE / text value',
        Parameter => {
            Column   => 'test',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected  => 'test != \'Test\''
    },
    {
        Name      => '_GetCondition: single column / Operator NE / numeric value',
        Parameter => {
            Column    => 'test',
            Operator  => 'NE',
            Value     => '1',
            ValueType => 'NUMERIC'
        },
        Expected  => 'test <> 1'
    },
    {
        Name      => '_GetCondition: single column / Operator NE / text array value',
        Parameter => {
            Column   => 'test',
            Operator => 'NE',
            Value    => ['Test1','Test2']
        },
        Expected  => '(test != \'Test1\' OR test != \'Test2\')'
    },
    {
        Name      => '_GetCondition: single column / Operator NE / numeric array value',
        Parameter => {
            Column    => 'test',
            Operator  => 'NE',
            Value     => ['1','2'],
            ValueType => 'NUMERIC'
        },
        Expected  => '(test <> 1 OR test <> 2)'
    },
    {
        Name      => '_GetCondition: single column / Operator NE / empty value',
        Parameter => {
            Column   => 'test',
            Operator => 'NE',
            Value    => ''
        },
        Expected  => 'test != \'\''
    },
    {
        Name      => '_GetCondition: single column / Operator NE / text value with NULLValue',
        Parameter => {
            Column    => 'test',
            Operator  => 'NE',
            Value     => 'Test',
            NULLValue => 1
        },
        Expected  => '(test != \'Test\' OR test IS NULL)'
    },
    {
        Name      => '_GetCondition: single column / Operator NE / empty value with NULLValue',
        Parameter => {
            Column    => 'test',
            Operator  => 'NE',
            Value     => '',
            NULLValue => 1
        },
        Expected  => 'test != \'\''
    },
    {
        Name      => '_GetCondition: single column / Operator NE / empty value with NULLValue and CaseInsensitive',
        Parameter => {
            Column          => 'test',
            Operator        => 'NE',
            Value           => '',
            NULLValue       => 1,
            CaseInsensitive => 1
        },
        Expected  => 'LOWER(test) != \'\''
    },
    {
        Name      => '_GetCondition: single column / Operator NE / numeric zero value',
        Parameter => {
            Column    => 'test',
            Operator  => 'NE',
            Value     => '0',
            ValueType => 'NUMERIC'
        },
        Expected  => 'test <> 0'
    },
    {
        Name      => '_GetCondition: single column / Operator NE / numeric zero value with NULLValue',
        Parameter => {
            Column    => 'test',
            Operator  => 'NE',
            Value     => '0',
            ValueType => 'NUMERIC',
            NULLValue => 1
        },
        Expected  => 'test <> 0'
    },
    {
        Name      => '_GetCondition: single column / Operator NE / text array value with Supplement',
        Parameter => {
            Column     => 'test',
            Operator   => 'NE',
            Value      => ['Test1','Test2'],
            Supplement => ['try = 1']
        },
        Expected  => '((test != \'Test1\' OR test != \'Test2\') AND try = 1)'
    },
    {
        Name      => '_GetCondition: single column / Operator NE / text array value with CaseInsensitive',
        Parameter => {
            Column          => 'test',
            Operator        => 'NE',
            Value           => ['Test1','Test2'],
            CaseInsensitive => 1
        },
        Expected  => '(LOWER(test) != \'test1\' OR LOWER(test) != \'test2\')'
    },
    {
        Name      => '_GetCondition: single column / Operator NE / text value / SQL Injection',
        Parameter => {
            Column   => 'test',
            Operator => 'NE',
            Value    => '\';SELECT * FROM mail_account;SELECT st.id FROM ticket WHERE title = \'test'
        },
        Expected  => 'test != \'\'\';SELECT * FROM mail_account;SELECT st.id FROM ticket WHERE title = \'\'test\''
    },
    {
        Name      => '_GetCondition: column array / Operator NE / text array value with Supplement',
        Parameter => {
            Column     => ['test1','test2'],
            Operator   => 'NE',
            Value      => ['Test1','Test2'],
            Supplement => ['try = 1']
        },
        Expected  => '((test1 != \'Test1\' OR test1 != \'Test2\' OR test2 != \'Test1\' OR test2 != \'Test2\') AND try = 1)'
    },
    {
        Name      => '_GetCondition: single column / Operator LT / numeric value',
        Parameter => {
            Column    => 'test',
            Operator  => 'LT',
            Value     => '1',
            ValueType => 'NUMERIC'
        },
        Expected  => 'test < 1'
    },
    {
        Name      => '_GetCondition: single column / Operator LT / numeric array value',
        Parameter => {
            Column    => 'test',
            Operator  => 'LT',
            Value     => ['1','2'],
            ValueType => 'NUMERIC'
        },
        Expected  => '(test < 1 OR test < 2)'
    },
    {
        Name      => '_GetCondition: single column / Operator LT / numeric array value with Supplement',
        Parameter => {
            Column     => 'test',
            Operator   => 'LT',
            Value      => ['1','2'],
            ValueType  => 'NUMERIC',
            Supplement => ['try = 1']
        },
        Expected  => '((test < 1 OR test < 2) AND try = 1)'
    },
    {
        Name      => '_GetCondition: column array / Operator LT / text array value with Supplement',
        Parameter => {
            Column     => ['test1','test2'],
            Operator   => 'LT',
            Value      => ['1','2'],
            ValueType  => 'NUMERIC',
            Supplement => ['try = 1']
        },
        Expected  => '((test1 < 1 OR test1 < 2 OR test2 < 1 OR test2 < 2) AND try = 1)'
    },
    {
        Name      => '_GetCondition: single column / Operator LTE / numeric value',
        Parameter => {
            Column    => 'test',
            Operator  => 'LTE',
            Value     => '1',
            ValueType => 'NUMERIC'
        },
        Expected  => 'test <= 1'
    },
    {
        Name      => '_GetCondition: single column / Operator LTE / numeric array value',
        Parameter => {
            Column    => 'test',
            Operator  => 'LTE',
            Value     => ['1','2'],
            ValueType => 'NUMERIC'
        },
        Expected  => '(test <= 1 OR test <= 2)'
    },
    {
        Name      => '_GetCondition: single column / Operator LTE / numeric array value with Supplement',
        Parameter => {
            Column     => 'test',
            Operator   => 'LTE',
            Value      => ['1','2'],
            ValueType  => 'NUMERIC',
            Supplement => ['try = 1']
        },
        Expected  => '((test <= 1 OR test <= 2) AND try = 1)'
    },
    {
        Name      => '_GetCondition: column array / Operator LTE / text array value with Supplement',
        Parameter => {
            Column     => ['test1','test2'],
            Operator   => 'LTE',
            Value      => ['1','2'],
            ValueType  => 'NUMERIC',
            Supplement => ['try = 1']
        },
        Expected  => '((test1 <= 1 OR test1 <= 2 OR test2 <= 1 OR test2 <= 2) AND try = 1)'
    },
    {
        Name      => '_GetCondition: single column / Operator GT / numeric value',
        Parameter => {
            Column    => 'test',
            Operator  => 'GT',
            Value     => '1',
            ValueType => 'NUMERIC'
        },
        Expected  => 'test > 1'
    },
    {
        Name      => '_GetCondition: single column / Operator GT / numeric array value',
        Parameter => {
            Column    => 'test',
            Operator  => 'GT',
            Value     => ['1','2'],
            ValueType => 'NUMERIC'
        },
        Expected  => '(test > 1 OR test > 2)'
    },
    {
        Name      => '_GetCondition: single column / Operator GT / numeric array value with Supplement',
        Parameter => {
            Column     => 'test',
            Operator   => 'GT',
            Value      => ['1','2'],
            ValueType  => 'NUMERIC',
            Supplement => ['try = 1']
        },
        Expected  => '((test > 1 OR test > 2) AND try = 1)'
    },
    {
        Name      => '_GetCondition: column array / Operator GT / text array value with Supplement',
        Parameter => {
            Column     => ['test1','test2'],
            Operator   => 'GT',
            Value      => ['1','2'],
            ValueType  => 'NUMERIC',
            Supplement => ['try = 1']
        },
        Expected  => '((test1 > 1 OR test1 > 2 OR test2 > 1 OR test2 > 2) AND try = 1)'
    },
    {
        Name      => '_GetCondition: single column / Operator GTE / numeric value',
        Parameter => {
            Column    => 'test',
            Operator  => 'GTE',
            Value     => '1',
            ValueType => 'NUMERIC'
        },
        Expected  => 'test >= 1'
    },
    {
        Name      => '_GetCondition: single column / Operator GTE / numeric array value',
        Parameter => {
            Column    => 'test',
            Operator  => 'GTE',
            Value     => ['1','2'],
            ValueType => 'NUMERIC'
        },
        Expected  => '(test >= 1 OR test >= 2)'
    },
    {
        Name      => '_GetCondition: single column / Operator GTE / numeric array value with Supplement',
        Parameter => {
            Column     => 'test',
            Operator   => 'GTE',
            Value      => ['1','2'],
            ValueType  => 'NUMERIC',
            Supplement => ['try = 1']
        },
        Expected  => '((test >= 1 OR test >= 2) AND try = 1)'
    },
    {
        Name      => '_GetCondition: column array / Operator GTE / text array value with Supplement',
        Parameter => {
            Column     => ['test1','test2'],
            Operator   => 'GTE',
            Value      => ['1','2'],
            ValueType  => 'NUMERIC',
            Supplement => ['try = 1']
        },
        Expected  => '((test1 >= 1 OR test1 >= 2 OR test2 >= 1 OR test2 >= 2) AND try = 1)'
    },
    {
        Name      => '_GetCondition: single column / Operator STARTSWITH / text value',
        Parameter => {
            Column   => 'test',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected  => 'test LIKE \'Test%\''
    },
    {
        Name      => '_GetCondition: single column / Operator STARTSWITH / numeric value',
        Parameter => {
            Column    => 'test',
            Operator  => 'STARTSWITH',
            Value     => '1',
            ValueType => 'NUMERIC'
        },
        Expected  => 'CAST(test AS CHAR(20)) LIKE \'1%\''
    },
    {
        Name      => '_GetCondition: single column / Operator STARTSWITH / text array value',
        Parameter => {
            Column   => 'test',
            Operator => 'STARTSWITH',
            Value    => ['Test1','Test2']
        },
        Expected  => '(test LIKE \'Test1%\' OR test LIKE \'Test2%\')'
    },
    {
        Name      => '_GetCondition: single column / Operator STARTSWITH / numeric array value',
        Parameter => {
            Column    => 'test',
            Operator  => 'STARTSWITH',
            Value     => ['1','2'],
            ValueType => 'NUMERIC'
        },
        Expected  => '(CAST(test AS CHAR(20)) LIKE \'1%\' OR CAST(test AS CHAR(20)) LIKE \'2%\')'
    },
    {
        Name      => '_GetCondition: single column / Operator STARTSWITH / empty value',
        Parameter => {
            Column   => 'test',
            Operator => 'STARTSWITH',
            Value    => ''
        },
        Expected  => 'test LIKE \'%\''
    },
    {
        Name      => '_GetCondition: single column / Operator STARTSWITH / text array value with Supplement',
        Parameter => {
            Column     => 'test',
            Operator   => 'STARTSWITH',
            Value      => ['Test1','Test2'],
            Supplement => ['try = 1']
        },
        Expected  => '((test LIKE \'Test1%\' OR test LIKE \'Test2%\') AND try = 1)'
    },
    {
        Name      => '_GetCondition: single column / Operator STARTSWITH / text array value with CaseInsensitive',
        Parameter => {
            Column          => 'test',
            Operator        => 'STARTSWITH',
            Value           => ['Test1','Test2'],
            CaseInsensitive => 1
        },
        Expected  => '(LOWER(test) LIKE \'test1%\' OR LOWER(test) LIKE \'test2%\')'
    },
    {
        Name      => '_GetCondition: single column / Operator STARTSWITH / text value / SQL Injection',
        Parameter => {
            Column   => 'test',
            Operator => 'STARTSWITH',
            Value    => '\';SELECT * FROM mail_account;SELECT st.id FROM ticket WHERE title = \'test'
        },
        Expected  => 'test LIKE \'\'\';SELECT * FROM mail\\_account;SELECT st.id FROM ticket WHERE title = \'\'test%\''
    },
    {
        Name      => '_GetCondition: column array / Operator STARTSWITH / text array value with Supplement',
        Parameter => {
            Column     => ['test1','test2'],
            Operator   => 'STARTSWITH',
            Value      => ['Test1','Test2'],
            Supplement => ['try = 1']
        },
        Expected  => '((test1 LIKE \'Test1%\' OR test1 LIKE \'Test2%\' OR test2 LIKE \'Test1%\' OR test2 LIKE \'Test2%\') AND try = 1)'
    },
    {
        Name      => '_GetCondition: single column / Operator ENDSWITH / text value',
        Parameter => {
            Column   => 'test',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected  => 'test LIKE \'%Test\''
    },
    {
        Name      => '_GetCondition: single column / Operator ENDSWITH / numeric value',
        Parameter => {
            Column    => 'test',
            Operator  => 'ENDSWITH',
            Value     => '1',
            ValueType => 'NUMERIC'
        },
        Expected  => 'CAST(test AS CHAR(20)) LIKE \'%1\''
    },
    {
        Name      => '_GetCondition: single column / Operator ENDSWITH / text array value',
        Parameter => {
            Column   => 'test',
            Operator => 'ENDSWITH',
            Value    => ['Test1','Test2']
        },
        Expected  => '(test LIKE \'%Test1\' OR test LIKE \'%Test2\')'
    },
    {
        Name      => '_GetCondition: single column / Operator ENDSWITH / numeric array value',
        Parameter => {
            Column    => 'test',
            Operator  => 'ENDSWITH',
            Value     => ['1','2'],
            ValueType => 'NUMERIC'
        },
        Expected  => '(CAST(test AS CHAR(20)) LIKE \'%1\' OR CAST(test AS CHAR(20)) LIKE \'%2\')'
    },
    {
        Name      => '_GetCondition: single column / Operator ENDSWITH / empty value',
        Parameter => {
            Column   => 'test',
            Operator => 'ENDSWITH',
            Value    => ''
        },
        Expected  => 'test LIKE \'%\''
    },
    {
        Name      => '_GetCondition: single column / Operator ENDSWITH / text array value with Supplement',
        Parameter => {
            Column     => 'test',
            Operator   => 'ENDSWITH',
            Value      => ['Test1','Test2'],
            Supplement => ['try = 1']
        },
        Expected  => '((test LIKE \'%Test1\' OR test LIKE \'%Test2\') AND try = 1)'
    },
    {
        Name      => '_GetCondition: single column / Operator ENDSWITH / text array value with CaseInsensitive',
        Parameter => {
            Column          => 'test',
            Operator        => 'ENDSWITH',
            Value           => ['Test1','Test2'],
            CaseInsensitive => 1
        },
        Expected  => '(LOWER(test) LIKE \'%test1\' OR LOWER(test) LIKE \'%test2\')'
    },
    {
        Name      => '_GetCondition: single column / Operator ENDSWITH / text value / SQL Injection',
        Parameter => {
            Column   => 'test',
            Operator => 'ENDSWITH',
            Value    => '\';SELECT * FROM mail_account;SELECT st.id FROM ticket WHERE title = \'test'
        },
        Expected  => 'test LIKE \'%\'\';SELECT * FROM mail\\_account;SELECT st.id FROM ticket WHERE title = \'\'test\''
    },
    {
        Name      => '_GetCondition: column array / Operator ENDSWITH / text array value with Supplement',
        Parameter => {
            Column     => ['test1','test2'],
            Operator   => 'ENDSWITH',
            Value      => ['Test1','Test2'],
            Supplement => ['try = 1']
        },
        Expected  => '((test1 LIKE \'%Test1\' OR test1 LIKE \'%Test2\' OR test2 LIKE \'%Test1\' OR test2 LIKE \'%Test2\') AND try = 1)'
    },
    {
        Name      => '_GetCondition: single column / Operator CONTAINS / text value',
        Parameter => {
            Column   => 'test',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected  => 'test LIKE \'%Test%\''
    },
    {
        Name      => '_GetCondition: single column / Operator CONTAINS / numeric value',
        Parameter => {
            Column    => 'test',
            Operator  => 'CONTAINS',
            Value     => '1',
            ValueType => 'NUMERIC'
        },
        Expected  => 'CAST(test AS CHAR(20)) LIKE \'%1%\''
    },
    {
        Name      => '_GetCondition: single column / Operator CONTAINS / text array value',
        Parameter => {
            Column   => 'test',
            Operator => 'CONTAINS',
            Value    => ['Test1','Test2']
        },
        Expected  => '(test LIKE \'%Test1%\' OR test LIKE \'%Test2%\')'
    },
    {
        Name      => '_GetCondition: single column / Operator CONTAINS / numeric array value',
        Parameter => {
            Column    => 'test',
            Operator  => 'CONTAINS',
            Value     => ['1','2'],
            ValueType => 'NUMERIC'
        },
        Expected  => '(CAST(test AS CHAR(20)) LIKE \'%1%\' OR CAST(test AS CHAR(20)) LIKE \'%2%\')'
    },
    {
        Name      => '_GetCondition: single column / Operator CONTAINS / empty value',
        Parameter => {
            Column   => 'test',
            Operator => 'CONTAINS',
            Value    => ''
        },
        Expected  => 'test LIKE \'%\''
    },
    {
        Name      => '_GetCondition: single column / Operator CONTAINS / text array value with Supplement',
        Parameter => {
            Column     => 'test',
            Operator   => 'CONTAINS',
            Value      => ['Test1','Test2'],
            Supplement => ['try = 1']
        },
        Expected  => '((test LIKE \'%Test1%\' OR test LIKE \'%Test2%\') AND try = 1)'
    },
    {
        Name      => '_GetCondition: single column / Operator CONTAINS / text array value with CaseInsensitive',
        Parameter => {
            Column          => 'test',
            Operator        => 'CONTAINS',
            Value           => ['Test1','Test2'],
            CaseInsensitive => 1
        },
        Expected  => '(LOWER(test) LIKE \'%test1%\' OR LOWER(test) LIKE \'%test2%\')'
    },
    {
        Name      => '_GetCondition: single column / Operator CONTAINS / text value / SQL Injection',
        Parameter => {
            Column   => 'test',
            Operator => 'CONTAINS',
            Value    => '\';SELECT * FROM mail_account;SELECT st.id FROM ticket WHERE title = \'test'
        },
        Expected  => 'test LIKE \'%\'\';SELECT * FROM mail\\_account;SELECT st.id FROM ticket WHERE title = \'\'test%\''
    },
    {
        Name      => '_GetCondition: column array / Operator CONTAINS / text array value with Supplement',
        Parameter => {
            Column     => ['test1','test2'],
            Operator   => 'CONTAINS',
            Value      => ['Test1','Test2'],
            Supplement => ['try = 1']
        },
        Expected  => '((test1 LIKE \'%Test1%\' OR test1 LIKE \'%Test2%\' OR test2 LIKE \'%Test1%\' OR test2 LIKE \'%Test2%\') AND try = 1)'
    },
    {
        Name      => '_GetCondition: single column / Operator LIKE / text value',
        Parameter => {
            Column   => 'test',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected  => 'test LIKE \'Test\''
    },
    {
        Name      => '_GetCondition: single column / Operator LIKE / text value with wildcard',
        Parameter => {
            Column   => 'test',
            Operator => 'LIKE',
            Value    => 'Te*st'
        },
        Expected  => 'test LIKE \'Te%st\''
    },
    {
        Name      => '_GetCondition: single column / Operator LIKE / numeric value',
        Parameter => {
            Column    => 'test',
            Operator  => 'LIKE',
            Value     => '1',
            ValueType => 'NUMERIC'
        },
        Expected  => 'CAST(test AS CHAR(20)) LIKE \'1\''
    },
    {
        Name      => '_GetCondition: single column / Operator LIKE / text array value',
        Parameter => {
            Column   => 'test',
            Operator => 'LIKE',
            Value    => ['Test1','Test2']
        },
        Expected  => '(test LIKE \'Test1\' OR test LIKE \'Test2\')'
    },
    {
        Name      => '_GetCondition: single column / Operator LIKE / numeric array value',
        Parameter => {
            Column    => 'test',
            Operator  => 'LIKE',
            Value     => ['1','2'],
            ValueType => 'NUMERIC'
        },
        Expected  => '(CAST(test AS CHAR(20)) LIKE \'1\' OR CAST(test AS CHAR(20)) LIKE \'2\')'
    },
    {
        Name      => '_GetCondition: single column / Operator LIKE / empty value',
        Parameter => {
            Column   => 'test',
            Operator => 'LIKE',
            Value    => ''
        },
        Expected  => 'test LIKE \'\''
    },
    {
        Name      => '_GetCondition: single column / Operator LIKE / text array value with Supplement',
        Parameter => {
            Column     => 'test',
            Operator   => 'LIKE',
            Value      => ['Test1','Test2'],
            Supplement => ['try = 1']
        },
        Expected  => '((test LIKE \'Test1\' OR test LIKE \'Test2\') AND try = 1)'
    },
    {
        Name      => '_GetCondition: single column / Operator LIKE / text array value with CaseInsensitive',
        Parameter => {
            Column          => 'test',
            Operator        => 'LIKE',
            Value           => ['Test1','Test2'],
            CaseInsensitive => 1
        },
        Expected  => '(LOWER(test) LIKE \'test1\' OR LOWER(test) LIKE \'test2\')'
    },
    {
        Name      => '_GetCondition: single column / Operator LIKE / text value / SQL Injection',
        Parameter => {
            Column   => 'test',
            Operator => 'LIKE',
            Value    => '\';SELECT * FROM mail_account;SELECT st.id FROM ticket WHERE title = \'test'
        },
        Expected  => 'test LIKE \'\'\';SELECT % FROM mail\\_account;SELECT st.id FROM ticket WHERE title = \'\'test\''
    },
    {
        Name      => '_GetCondition: column array / Operator LIKE / text array value with Supplement',
        Parameter => {
            Column     => ['test1','test2'],
            Operator   => 'LIKE',
            Value      => ['Test1','Test2'],
            Supplement => ['try = 1']
        },
        Expected  => '((test1 LIKE \'Test1\' OR test1 LIKE \'Test2\' OR test2 LIKE \'Test1\' OR test2 LIKE \'Test2\') AND try = 1)'
    },
    {
        Name      => '_GetCondition: single column / Operator IN / text value',
        Parameter => {
            Column   => 'test',
            Operator => 'IN',
            Value    => 'Test'
        },
        Expected  => 'test IN (\'Test\')'
    },
    {
        Name      => '_GetCondition: single column / Operator IN / numeric value',
        Parameter => {
            Column    => 'test',
            Operator  => 'IN',
            Value     => '1',
            ValueType => 'NUMERIC'
        },
        Expected  => 'test IN (1)'
    },
    {
        Name      => '_GetCondition: single column / Operator IN / text array value',
        Parameter => {
            Column   => 'test',
            Operator => 'IN',
            Value    => ['Test1','Test2']
        },
        Expected  => 'test IN (\'Test1\',\'Test2\')'
    },
    {
        Name      => '_GetCondition: single column / Operator IN / numeric array value',
        Parameter => {
            Column    => 'test',
            Operator  => 'IN',
            Value     => ['1','2'],
            ValueType => 'NUMERIC'
        },
        Expected  => 'test IN (1,2)'
    },
    {
        Name      => '_GetCondition: single column / Operator IN / empty array value',
        Parameter => {
            Column   => 'test',
            Operator => 'IN',
            Value    => []
        },
        Expected  => '1=0'
    },
    {
        Name      => '_GetCondition: single column / Operator IN / large array value',
        Parameter => {
            Column    => 'test',
            Operator  => 'IN',
            Value     => \@LargeArray,
            ValueType => 'NUMERIC'
        },
        Expected  => '(test IN (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0) OR test IN (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0))'
    },
    {
        Name      => '_GetCondition: single column / Operator IN / text array value with Supplement',
        Parameter => {
            Column     => 'test',
            Operator   => 'IN',
            Value      => ['Test1','Test2'],
            Supplement => ['try = 1']
        },
        Expected  => '(test IN (\'Test1\',\'Test2\') AND try = 1)'
    },
    {
        Name      => '_GetCondition: single column / Operator IN / text array value with CaseInsensitive',
        Parameter => {
            Column          => 'test',
            Operator        => 'IN',
            Value           => ['Test1','Test2'],
            CaseInsensitive => 1
        },
        Expected  => 'LOWER(test) IN (\'test1\',\'test2\')'
    },
    {
        Name      => '_GetCondition: single column / Operator IN / text value / SQL Injection',
        Parameter => {
            Column   => 'test',
            Operator => 'IN',
            Value    => '\';SELECT * FROM mail_account;SELECT st.id FROM ticket WHERE title = \'test'
        },
        Expected  => 'test IN (\'\'\';SELECT * FROM mail_account;SELECT st.id FROM ticket WHERE title = \'\'test\')'
    },
    {
        Name      => '_GetCondition: column array / Operator IN / text array value with Supplement',
        Parameter => {
            Column     => ['test1','test2'],
            Operator   => 'IN',
            Value      => ['Test1','Test2'],
            Supplement => ['try = 1']
        },
        Expected  => '((test1 IN (\'Test1\',\'Test2\') OR test2 IN (\'Test1\',\'Test2\')) AND try = 1)'
    },
    {
        Name      => '_GetCondition: single column / Operator !IN / text value',
        Parameter => {
            Column   => 'test',
            Operator => '!IN',
            Value    => 'Test'
        },
        Expected  => 'test NOT IN (\'Test\')'
    },
    {
        Name      => '_GetCondition: single column / Operator !IN / numeric value',
        Parameter => {
            Column    => 'test',
            Operator  => '!IN',
            Value     => '1',
            ValueType => 'NUMERIC'
        },
        Expected  => 'test NOT IN (1)'
    },
    {
        Name      => '_GetCondition: single column / Operator !IN / text array value',
        Parameter => {
            Column   => 'test',
            Operator => '!IN',
            Value    => ['Test1','Test2']
        },
        Expected  => 'test NOT IN (\'Test1\',\'Test2\')'
    },
    {
        Name      => '_GetCondition: single column / Operator !IN / numeric array value',
        Parameter => {
            Column    => 'test',
            Operator  => '!IN',
            Value     => ['1','2'],
            ValueType => 'NUMERIC'
        },
        Expected  => 'test NOT IN (1,2)'
    },
    {
        Name      => '_GetCondition: single column / Operator !IN / empty array value',
        Parameter => {
            Column   => 'test',
            Operator => '!IN',
            Value    => []
        },
        Expected  => '1=1'
    },
    {
        Name      => '_GetCondition: single column / Operator !IN / large array value',
        Parameter => {
            Column    => 'test',
            Operator  => '!IN',
            Value     => \@LargeArray,
            ValueType => 'NUMERIC'
        },
        Expected  => '(test NOT IN (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0) AND test NOT IN (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0))'
    },
    {
        Name      => '_GetCondition: single column / Operator !IN / text array value with Supplement',
        Parameter => {
            Column     => 'test',
            Operator   => '!IN',
            Value      => ['Test1','Test2'],
            Supplement => ['try = 1']
        },
        Expected  => '(test NOT IN (\'Test1\',\'Test2\') AND try = 1)'
    },
    {
        Name      => '_GetCondition: single column / Operator !IN / text array value with CaseInsensitive',
        Parameter => {
            Column          => 'test',
            Operator        => '!IN',
            Value           => ['Test1','Test2'],
            CaseInsensitive => 1
        },
        Expected  => 'LOWER(test) NOT IN (\'test1\',\'test2\')'
    },
    {
        Name      => '_GetCondition: single column / Operator !IN / text value / SQL Injection',
        Parameter => {
            Column   => 'test',
            Operator => '!IN',
            Value    => '\';SELECT * FROM mail_account;SELECT st.id FROM ticket WHERE title = \'test'
        },
        Expected  => 'test NOT IN (\'\'\';SELECT * FROM mail_account;SELECT st.id FROM ticket WHERE title = \'\'test\')'
    },
    {
        Name      => '_GetCondition: column array / Operator !IN / text array value with Supplement',
        Parameter => {
            Column     => ['test1','test2'],
            Operator   => '!IN',
            Value      => ['Test1','Test2'],
            Supplement => ['try = 1']
        },
        Expected  => '((test1 NOT IN (\'Test1\',\'Test2\') OR test2 NOT IN (\'Test1\',\'Test2\')) AND try = 1)'
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
        Name      => '_FulltextCondition: Operator undef',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => undef,
            Value    => 'Test'
        },
        Expected  => undef
    },
    {
        Name      => '_FulltextCondition: Operator empty',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => '',
            Value    => 'Test'
        },
        Expected  => undef
    },
    {
        Name      => '_FulltextCondition: Operator invalid',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'Invalid',
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
            Operator       => 'LIKE',
            Value          => 'Test',
            IsStaticSearch => 1
        },
        Expected  => undef
    },
    {
        Name      => '_FulltextCondition: single column / Operator CONTAINS / simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'CONTAINS',
            Value    => 'UnitTest'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%UnitTest%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator CONTAINS / quoted simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'CONTAINS',
            Value    => '"UnitTest"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%UnitTest%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator CONTAINS / double quoted and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'CONTAINS',
            Value    => '"Unit"+Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator CONTAINS / double quoted and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'CONTAINS',
            Value    => '"Unit" Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator CONTAINS / "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'CONTAINS',
            Value    => '"Unit+Test"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit+Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator CONTAINS / space in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'CONTAINS',
            Value    => '"Unit Test"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator CONTAINS / double quoted and "|" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'CONTAINS',
            Value    => '"Unit"|Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator CONTAINS / "|" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'CONTAINS',
            Value    => '"Unit|Test"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit|Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator CONTAINS / double quoted and "|" and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'CONTAINS',
            Value    => '"Unit"|Test+Baa'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'%Baa%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator CONTAINS / double quoted and "|" and "+" and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'CONTAINS',
            Value    => 'Foo "Unit"|Test+Baa'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Foo%\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'%Baa%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator CONTAINS / space, "|", "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'CONTAINS',
            Value    => '"Foo Unit|Test+Baa"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Foo Unit|Test+Baa%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator CONTAINS / not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'CONTAINS',
            Value    => '"UnitTest'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%UnitTest%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator CONTAINS / "|" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'CONTAINS',
            Value    => 'Unit|"Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator CONTAINS / "+" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'CONTAINS',
            Value    => 'Unit+"Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator CONTAINS / space and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'CONTAINS',
            Value    => 'Unit "Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator CONTAINS / wildcard text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'CONTAINS',
            Value    => 'Unit*Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit*Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator CONTAINS / wildcard in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'CONTAINS',
            Value    => '"Unit*Test"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit*Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator CONTAINS / simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'CONTAINS',
            Value    => 'UnitTest'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%UnitTest%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%UnitTest%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator CONTAINS / quoted simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'CONTAINS',
            Value    => '"UnitTest"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%UnitTest%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%UnitTest%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator CONTAINS / double quoted and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'CONTAINS',
            Value    => '"Unit"+Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator CONTAINS / double quoted and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'CONTAINS',
            Value    => '"Unit" Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator CONTAINS / "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'CONTAINS',
            Value    => '"Unit+Test"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit+Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Unit+Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator CONTAINS / space in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'CONTAINS',
            Value    => '"Unit Test"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Unit Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator CONTAINS / double quoted and "|" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'CONTAINS',
            Value    => '"Unit"|Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator CONTAINS / "|" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'CONTAINS',
            Value    => '"Unit|Test"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit|Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Unit|Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator CONTAINS / double quoted and "|" and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'CONTAINS',
            Value    => '"Unit"|Test+Baa'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'%Baa%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Baa%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator CONTAINS / double quoted and "|" and "+" and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'CONTAINS',
            Value    => 'Foo "Unit"|Test+Baa'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Foo%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Foo%\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'%Baa%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Baa%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator CONTAINS / space, "|", "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'CONTAINS',
            Value    => '"Foo Unit|Test+Baa"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Foo Unit|Test+Baa%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Foo Unit|Test+Baa%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator CONTAINS / not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'CONTAINS',
            Value    => '"UnitTest'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%UnitTest%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%UnitTest%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator CONTAINS / "|" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'CONTAINS',
            Value    => 'Unit|"Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator CONTAINS / "+" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'CONTAINS',
            Value    => 'Unit+"Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator CONTAINS / space and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'CONTAINS',
            Value    => 'Unit "Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator CONTAINS / wildcard text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'CONTAINS',
            Value    => 'Unit*Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit*Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Unit*Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator CONTAINS / wildcard in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'CONTAINS',
            Value    => '"Unit*Test"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit*Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Unit*Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator STARTSWITH / simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'STARTSWITH',
            Value    => 'UnitTest'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'UnitTest%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator STARTSWITH / quoted simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'STARTSWITH',
            Value    => '"UnitTest"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'UnitTest%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator STARTSWITH / double quoted and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'STARTSWITH',
            Value    => '"Unit"+Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator STARTSWITH / double quoted and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'STARTSWITH',
            Value    => '"Unit" Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator STARTSWITH / "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'STARTSWITH',
            Value    => '"Unit+Test"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'Unit+Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator STARTSWITH / space in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'STARTSWITH',
            Value    => '"Unit Test"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'Unit Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator STARTSWITH / double quoted and "|" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'STARTSWITH',
            Value    => '"Unit"|Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator STARTSWITH / "|" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'STARTSWITH',
            Value    => '"Unit|Test"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'Unit|Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator STARTSWITH / double quoted and "|" and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'STARTSWITH',
            Value    => '"Unit"|Test+Baa'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'Baa%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator STARTSWITH / double quoted and "|" and "+" and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'STARTSWITH',
            Value    => 'Foo "Unit"|Test+Baa'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'Foo%\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'Baa%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator STARTSWITH / space, "|", "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'STARTSWITH',
            Value    => '"Foo Unit|Test+Baa"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'Foo Unit|Test+Baa%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator STARTSWITH / not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'STARTSWITH',
            Value    => '"UnitTest'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'UnitTest%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator STARTSWITH / "|" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'STARTSWITH',
            Value    => 'Unit|"Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator STARTSWITH / "+" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'STARTSWITH',
            Value    => 'Unit+"Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator STARTSWITH / space and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'STARTSWITH',
            Value    => 'Unit "Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator STARTSWITH / wildcard text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'STARTSWITH',
            Value    => 'Unit*Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'Unit*Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator STARTSWITH / wildcard in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'STARTSWITH',
            Value    => '"Unit*Test"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'Unit*Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator STARTSWITH / simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'STARTSWITH',
            Value    => 'UnitTest'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'UnitTest%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'UnitTest%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator STARTSWITH / quoted simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'STARTSWITH',
            Value    => '"UnitTest"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'UnitTest%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'UnitTest%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator STARTSWITH / double quoted and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'STARTSWITH',
            Value    => '"Unit"+Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator STARTSWITH / double quoted and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'STARTSWITH',
            Value    => '"Unit" Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator STARTSWITH / "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'STARTSWITH',
            Value    => '"Unit+Test"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'Unit+Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'Unit+Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator STARTSWITH / space in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'STARTSWITH',
            Value    => '"Unit Test"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'Unit Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'Unit Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator STARTSWITH / double quoted and "|" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'STARTSWITH',
            Value    => '"Unit"|Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator STARTSWITH / "|" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'STARTSWITH',
            Value    => '"Unit|Test"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'Unit|Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'Unit|Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator STARTSWITH / double quoted and "|" and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'STARTSWITH',
            Value    => '"Unit"|Test+Baa'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'Baa%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'Baa%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator STARTSWITH / double quoted and "|" and "+" and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'STARTSWITH',
            Value    => 'Foo "Unit"|Test+Baa'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'Foo%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'Foo%\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'Baa%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'Baa%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator STARTSWITH / space, "|", "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'STARTSWITH',
            Value    => '"Foo Unit|Test+Baa"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'Foo Unit|Test+Baa%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'Foo Unit|Test+Baa%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator STARTSWITH / not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'STARTSWITH',
            Value    => '"UnitTest'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'UnitTest%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'UnitTest%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator STARTSWITH / "|" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'STARTSWITH',
            Value    => 'Unit|"Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator STARTSWITH / "+" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'STARTSWITH',
            Value    => 'Unit+"Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator STARTSWITH / space and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'STARTSWITH',
            Value    => 'Unit "Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator STARTSWITH / wildcard text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'STARTSWITH',
            Value    => 'Unit*Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'Unit*Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'Unit*Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator STARTSWITH / wildcard in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'STARTSWITH',
            Value    => '"Unit*Test"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'Unit*Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'Unit*Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator ENDSWITH / simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'ENDSWITH',
            Value    => 'UnitTest'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%UnitTest\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator ENDSWITH / quoted simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'ENDSWITH',
            Value    => '"UnitTest"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%UnitTest\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator ENDSWITH / double quoted and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'ENDSWITH',
            Value    => '"Unit"+Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator ENDSWITH / double quoted and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'ENDSWITH',
            Value    => '"Unit" Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator ENDSWITH / "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'ENDSWITH',
            Value    => '"Unit+Test"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit+Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator ENDSWITH / space in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'ENDSWITH',
            Value    => '"Unit Test"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator ENDSWITH / double quoted and "|" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'ENDSWITH',
            Value    => '"Unit"|Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator ENDSWITH / "|" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'ENDSWITH',
            Value    => '"Unit|Test"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit|Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator ENDSWITH / double quoted and "|" and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'ENDSWITH',
            Value    => '"Unit"|Test+Baa'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'%Baa\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator ENDSWITH / double quoted and "|" and "+" and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'ENDSWITH',
            Value    => 'Foo "Unit"|Test+Baa'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Foo\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'%Baa\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator ENDSWITH / space, "|", "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'ENDSWITH',
            Value    => '"Foo Unit|Test+Baa"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Foo Unit|Test+Baa\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator ENDSWITH / not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'ENDSWITH',
            Value    => '"UnitTest'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%UnitTest\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator ENDSWITH / "|" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'ENDSWITH',
            Value    => 'Unit|"Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator ENDSWITH / "+" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'ENDSWITH',
            Value    => 'Unit+"Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator ENDSWITH / space and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'ENDSWITH',
            Value    => 'Unit "Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator ENDSWITH / wildcard text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'ENDSWITH',
            Value    => 'Unit*Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit*Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator ENDSWITH / wildcard in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'ENDSWITH',
            Value    => '"Unit*Test"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit*Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator ENDSWITH / simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'ENDSWITH',
            Value    => 'UnitTest'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%UnitTest\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%UnitTest\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator ENDSWITH / quoted simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'ENDSWITH',
            Value    => '"UnitTest"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%UnitTest\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%UnitTest\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator ENDSWITH / double quoted and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'ENDSWITH',
            Value    => '"Unit"+Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator ENDSWITH / double quoted and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'ENDSWITH',
            Value    => '"Unit" Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator ENDSWITH / "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'ENDSWITH',
            Value    => '"Unit+Test"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit+Test\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Unit+Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator ENDSWITH / space in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'ENDSWITH',
            Value    => '"Unit Test"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit Test\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Unit Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator ENDSWITH / double quoted and "|" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'ENDSWITH',
            Value    => '"Unit"|Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator ENDSWITH / "|" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'ENDSWITH',
            Value    => '"Unit|Test"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit|Test\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Unit|Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator ENDSWITH / double quoted and "|" and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'ENDSWITH',
            Value    => '"Unit"|Test+Baa'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'%Baa\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Baa\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator ENDSWITH / double quoted and "|" and "+" and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'ENDSWITH',
            Value    => 'Foo "Unit"|Test+Baa'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Foo\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Foo\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'%Baa\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Baa\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator ENDSWITH / space, "|", "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'ENDSWITH',
            Value    => '"Foo Unit|Test+Baa"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Foo Unit|Test+Baa\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Foo Unit|Test+Baa\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator ENDSWITH / not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'ENDSWITH',
            Value    => '"UnitTest'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%UnitTest\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%UnitTest\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator ENDSWITH / "|" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'ENDSWITH',
            Value    => 'Unit|"Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  OR (LOWER(test) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator ENDSWITH / "+" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'ENDSWITH',
            Value    => 'Unit+"Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator ENDSWITH / space and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'ENDSWITH',
            Value    => 'Unit "Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  AND (LOWER(test) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator ENDSWITH / wildcard text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'ENDSWITH',
            Value    => 'Unit*Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit*Test\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Unit*Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator ENDSWITH / wildcard in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'ENDSWITH',
            Value    => '"Unit*Test"'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'%Unit*Test\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'%Unit*Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator LIKE / simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => 'UnitTest'
        },
        Expected  => '(LOWER(test) = LOWER(\'UnitTest\')) '
    },
    {
        Name      => '_FulltextCondition: single column / Operator LIKE / quoted simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => '"UnitTest"'
        },
        Expected  => '(LOWER(test) = LOWER(\'UnitTest\')) '
    },
    {
        Name      => '_FulltextCondition: single column / Operator LIKE / double quoted and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => '"Unit"+Test'
        },
        Expected  => '(LOWER(test) = LOWER(\'Unit\'))  AND (LOWER(test) = LOWER(\'Test\')) '
    },
    {
        Name      => '_FulltextCondition: single column / Operator LIKE / double quoted and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => '"Unit" Test'
        },
        Expected  => '(LOWER(test) = LOWER(\'Unit\'))  AND (LOWER(test) = LOWER(\'Test\')) '
    },
    {
        Name      => '_FulltextCondition: single column / Operator LIKE / "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => '"Unit+Test"'
        },
        Expected  => '(LOWER(test) = LOWER(\'Unit+Test\')) '
    },
    {
        Name      => '_FulltextCondition: single column / Operator LIKE / space in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => '"Unit Test"'
        },
        Expected  => '(LOWER(test) = LOWER(\'Unit Test\')) '
    },
    {
        Name      => '_FulltextCondition: single column / Operator LIKE / double quoted and "|" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => '"Unit"|Test'
        },
        Expected  => '(LOWER(test) = LOWER(\'Unit\'))  OR (LOWER(test) = LOWER(\'Test\')) '
    },
    {
        Name      => '_FulltextCondition: single column / Operator LIKE / "|" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => '"Unit|Test"'
        },
        Expected  => '(LOWER(test) = LOWER(\'Unit|Test\')) '
    },
    {
        Name      => '_FulltextCondition: single column / Operator LIKE / double quoted and "|" and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => '"Unit"|Test+Baa'
        },
        Expected  => '(LOWER(test) = LOWER(\'Unit\'))  OR (LOWER(test) = LOWER(\'Test\'))  AND (LOWER(test) = LOWER(\'Baa\')) '
    },
    {
        Name      => '_FulltextCondition: single column / Operator LIKE / double quoted and "|" and "+" and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => 'Foo "Unit"|Test+Baa'
        },
        Expected  => '(LOWER(test) = LOWER(\'Foo\'))  AND (LOWER(test) = LOWER(\'Unit\'))  OR (LOWER(test) = LOWER(\'Test\'))  AND (LOWER(test) = LOWER(\'Baa\')) '
    },
    {
        Name      => '_FulltextCondition: single column / Operator LIKE / space, "|", "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => '"Foo Unit|Test+Baa"'
        },
        Expected  => '(LOWER(test) = LOWER(\'Foo Unit|Test+Baa\')) '
    },
    {
        Name      => '_FulltextCondition: single column / Operator LIKE / not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => '"UnitTest'
        },
        Expected  => '(LOWER(test) = LOWER(\'UnitTest\')) '
    },
    {
        Name      => '_FulltextCondition: single column / Operator LIKE / "|" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => 'Unit|"Test'
        },
        Expected  => '(LOWER(test) = LOWER(\'Unit\'))  OR (LOWER(test) = LOWER(\'Test\')) '
    },
    {
        Name      => '_FulltextCondition: single column / Operator LIKE / "+" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => 'Unit+"Test'
        },
        Expected  => '(LOWER(test) = LOWER(\'Unit\'))  AND (LOWER(test) = LOWER(\'Test\')) '
    },
    {
        Name      => '_FulltextCondition: single column / Operator LIKE / space and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => 'Unit "Test'
        },
        Expected  => '(LOWER(test) = LOWER(\'Unit\'))  AND (LOWER(test) = LOWER(\'Test\')) '
    },
    {
        Name      => '_FulltextCondition: single column / Operator LIKE / wildcard text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => 'Unit*Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'Unit%Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single column / Operator LIKE / wildcard in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test'],
            Operator => 'LIKE',
            Value    => '"Unit*Test"'
        },
        Expected  => '(LOWER(test) = LOWER(\'Unit*Test\')) '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator LIKE / simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => 'UnitTest'
        },
        Expected  => '(LOWER(test) = LOWER(\'UnitTest\') OR LOWER(Foo) = LOWER(\'UnitTest\')) '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator LIKE / quoted simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => '"UnitTest"'
        },
        Expected  => '(LOWER(test) = LOWER(\'UnitTest\') OR LOWER(Foo) = LOWER(\'UnitTest\')) '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator LIKE / double quoted and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => '"Unit"+Test'
        },
        Expected  => '(LOWER(test) = LOWER(\'Unit\') OR LOWER(Foo) = LOWER(\'Unit\'))  AND (LOWER(test) = LOWER(\'Test\') OR LOWER(Foo) = LOWER(\'Test\')) '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator LIKE / double quoted and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => '"Unit" Test'
        },
        Expected  => '(LOWER(test) = LOWER(\'Unit\') OR LOWER(Foo) = LOWER(\'Unit\'))  AND (LOWER(test) = LOWER(\'Test\') OR LOWER(Foo) = LOWER(\'Test\')) '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator LIKE / "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => '"Unit+Test"'
        },
        Expected  => '(LOWER(test) = LOWER(\'Unit+Test\') OR LOWER(Foo) = LOWER(\'Unit+Test\')) '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator LIKE / space in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => '"Unit Test"'
        },
        Expected  => '(LOWER(test) = LOWER(\'Unit Test\') OR LOWER(Foo) = LOWER(\'Unit Test\')) '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator LIKE / double quoted and "|" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => '"Unit"|Test'
        },
        Expected  => '(LOWER(test) = LOWER(\'Unit\') OR LOWER(Foo) = LOWER(\'Unit\'))  OR (LOWER(test) = LOWER(\'Test\') OR LOWER(Foo) = LOWER(\'Test\')) '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator LIKE / "|" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => '"Unit|Test"'
        },
        Expected  => '(LOWER(test) = LOWER(\'Unit|Test\') OR LOWER(Foo) = LOWER(\'Unit|Test\')) '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator LIKE / double quoted and "|" and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => '"Unit"|Test+Baa'
        },
        Expected  => '(LOWER(test) = LOWER(\'Unit\') OR LOWER(Foo) = LOWER(\'Unit\'))  OR (LOWER(test) = LOWER(\'Test\') OR LOWER(Foo) = LOWER(\'Test\'))  AND (LOWER(test) = LOWER(\'Baa\') OR LOWER(Foo) = LOWER(\'Baa\')) '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator LIKE / double quoted and "|" and "+" and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => 'Foo "Unit"|Test+Baa'
        },
        Expected  => '(LOWER(test) = LOWER(\'Foo\') OR LOWER(Foo) = LOWER(\'Foo\'))  AND (LOWER(test) = LOWER(\'Unit\') OR LOWER(Foo) = LOWER(\'Unit\'))  OR (LOWER(test) = LOWER(\'Test\') OR LOWER(Foo) = LOWER(\'Test\'))  AND (LOWER(test) = LOWER(\'Baa\') OR LOWER(Foo) = LOWER(\'Baa\')) '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator LIKE / space, "|", "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => '"Foo Unit|Test+Baa"'
        },
        Expected  => '(LOWER(test) = LOWER(\'Foo Unit|Test+Baa\') OR LOWER(Foo) = LOWER(\'Foo Unit|Test+Baa\')) '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator LIKE / not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => '"UnitTest'
        },
        Expected  => '(LOWER(test) = LOWER(\'UnitTest\') OR LOWER(Foo) = LOWER(\'UnitTest\')) '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator LIKE / "|" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => 'Unit|"Test'
        },
        Expected  => '(LOWER(test) = LOWER(\'Unit\') OR LOWER(Foo) = LOWER(\'Unit\'))  OR (LOWER(test) = LOWER(\'Test\') OR LOWER(Foo) = LOWER(\'Test\')) '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator LIKE / "+" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => 'Unit+"Test'
        },
        Expected  => '(LOWER(test) = LOWER(\'Unit\') OR LOWER(Foo) = LOWER(\'Unit\'))  AND (LOWER(test) = LOWER(\'Test\') OR LOWER(Foo) = LOWER(\'Test\')) '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator LIKE / space and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => 'Unit "Test'
        },
        Expected  => '(LOWER(test) = LOWER(\'Unit\') OR LOWER(Foo) = LOWER(\'Unit\'))  AND (LOWER(test) = LOWER(\'Test\') OR LOWER(Foo) = LOWER(\'Test\')) '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator LIKE / wildcard text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => 'Unit*Test'
        },
        Expected  => '(LOWER(test) LIKE LOWER(\'Unit%Test\') ESCAPE \'' . $Escape . '\' OR LOWER(Foo) LIKE LOWER(\'Unit%Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple columns / Operator LIKE / wildcard in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            Columns  => ['test', 'Foo'],
            Operator => 'LIKE',
            Value    => '"Unit*Test"'
        },
        Expected  => '(LOWER(test) = LOWER(\'Unit*Test\') OR LOWER(Foo) = LOWER(\'Unit*Test\')) '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator CONTAINS / simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'CONTAINS',
            Value          => 'UnitTest',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%UnitTest%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator CONTAINS / quoted simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'CONTAINS',
            Value          => '"UnitTest"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%UnitTest%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator CONTAINS / double quoted and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'CONTAINS',
            Value          => '"Unit"+Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator CONTAINS / double quoted and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'CONTAINS',
            Value          => '"Unit" Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator CONTAINS / "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'CONTAINS',
            Value          => '"Unit+Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit+Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator CONTAINS / space in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'CONTAINS',
            Value          => '"Unit Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator CONTAINS / double quoted and "|" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'CONTAINS',
            Value          => '"Unit"|Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  OR (test LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator CONTAINS / "|" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'CONTAINS',
            Value          => '"Unit|Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit|Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator CONTAINS / double quoted and "|" and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'CONTAINS',
            Value          => '"Unit"|Test+Baa',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  OR (test LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'%Baa%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator CONTAINS / double quoted and "|" and "+" and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'CONTAINS',
            Value          => 'Foo "Unit"|Test+Baa',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Foo%\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  OR (test LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'%Baa%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator CONTAINS / space, "|", "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'CONTAINS',
            Value          => '"Foo Unit|Test+Baa"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Foo Unit|Test+Baa%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator CONTAINS / not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'CONTAINS',
            Value          => '"UnitTest',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%UnitTest%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator CONTAINS / "|" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'CONTAINS',
            Value          => 'Unit|"Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  OR (test LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator CONTAINS / "+" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'CONTAINS',
            Value          => 'Unit+"Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator CONTAINS / space and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'CONTAINS',
            Value          => 'Unit "Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator CONTAINS / wildcard text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'CONTAINS',
            Value          => 'Unit*Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit*Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator CONTAINS / wildcard in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'CONTAINS',
            Value          => '"Unit*Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit*Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator CONTAINS / simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'CONTAINS',
            Value          => 'UnitTest',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%UnitTest%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%UnitTest%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator CONTAINS / quoted simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'CONTAINS',
            Value          => '"UnitTest"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%UnitTest%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%UnitTest%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator CONTAINS / double quoted and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'CONTAINS',
            Value          => '"Unit"+Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator CONTAINS / double quoted and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'CONTAINS',
            Value          => '"Unit" Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator CONTAINS / "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'CONTAINS',
            Value          => '"Unit+Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit+Test%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Unit+Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator CONTAINS / space in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'CONTAINS',
            Value          => '"Unit Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit Test%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Unit Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator CONTAINS / double quoted and "|" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'CONTAINS',
            Value          => '"Unit"|Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  OR (test LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator CONTAINS / "|" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'CONTAINS',
            Value          => '"Unit|Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit|Test%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Unit|Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator CONTAINS / double quoted and "|" and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'CONTAINS',
            Value          => '"Unit"|Test+Baa',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  OR (test LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'%Baa%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Baa%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator CONTAINS / double quoted and "|" and "+" and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'CONTAINS',
            Value          => 'Foo "Unit"|Test+Baa',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Foo%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Foo%\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  OR (test LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'%Baa%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Baa%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator CONTAINS / space, "|", "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'CONTAINS',
            Value          => '"Foo Unit|Test+Baa"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Foo Unit|Test+Baa%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Foo Unit|Test+Baa%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator CONTAINS / not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'CONTAINS',
            Value          => '"UnitTest',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%UnitTest%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%UnitTest%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator CONTAINS / "|" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'CONTAINS',
            Value          => 'Unit|"Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  OR (test LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator CONTAINS / "+" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'CONTAINS',
            Value          => 'Unit+"Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator CONTAINS / space and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'CONTAINS',
            Value          => 'Unit "Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Unit%\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator CONTAINS / wildcard text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'CONTAINS',
            Value          => 'Unit*Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit*Test%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Unit*Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator CONTAINS / wildcard in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'CONTAINS',
            Value          => '"Unit*Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit*Test%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Unit*Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator STARTSWITH / simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'STARTSWITH',
            Value          => 'UnitTest',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'UnitTest%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator STARTSWITH / quoted simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'STARTSWITH',
            Value          => '"UnitTest"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'UnitTest%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator STARTSWITH / double quoted and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'STARTSWITH',
            Value          => '"Unit"+Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator STARTSWITH / double quoted and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'STARTSWITH',
            Value          => '"Unit" Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator STARTSWITH / "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'STARTSWITH',
            Value          => '"Unit+Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'Unit+Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator STARTSWITH / space in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'STARTSWITH',
            Value          => '"Unit Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'Unit Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator STARTSWITH / double quoted and "|" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'STARTSWITH',
            Value          => '"Unit"|Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  OR (test LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator STARTSWITH / "|" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'STARTSWITH',
            Value          => '"Unit|Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'Unit|Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator STARTSWITH / double quoted and "|" and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'STARTSWITH',
            Value          => '"Unit"|Test+Baa',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  OR (test LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'Baa%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator STARTSWITH / double quoted and "|" and "+" and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'STARTSWITH',
            Value          => 'Foo "Unit"|Test+Baa',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'Foo%\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  OR (test LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'Baa%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator STARTSWITH / space, "|", "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'STARTSWITH',
            Value          => '"Foo Unit|Test+Baa"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'Foo Unit|Test+Baa%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator STARTSWITH / not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'STARTSWITH',
            Value          => '"UnitTest',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'UnitTest%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator STARTSWITH / "|" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'STARTSWITH',
            Value          => 'Unit|"Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  OR (test LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator STARTSWITH / "+" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'STARTSWITH',
            Value          => 'Unit+"Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator STARTSWITH / space and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'STARTSWITH',
            Value          => 'Unit "Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator STARTSWITH / wildcard text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'STARTSWITH',
            Value          => 'Unit*Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'Unit*Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator STARTSWITH / wildcard in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'STARTSWITH',
            Value          => '"Unit*Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'Unit*Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator STARTSWITH / simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'STARTSWITH',
            Value          => 'UnitTest',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'UnitTest%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'UnitTest%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator STARTSWITH / quoted simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'STARTSWITH',
            Value          => '"UnitTest"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'UnitTest%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'UnitTest%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator STARTSWITH / double quoted and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'STARTSWITH',
            Value          => '"Unit"+Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator STARTSWITH / double quoted and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'STARTSWITH',
            Value          => '"Unit" Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator STARTSWITH / "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'STARTSWITH',
            Value          => '"Unit+Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'Unit+Test%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'Unit+Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator STARTSWITH / space in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'STARTSWITH',
            Value          => '"Unit Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'Unit Test%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'Unit Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator STARTSWITH / double quoted and "|" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'STARTSWITH',
            Value          => '"Unit"|Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  OR (test LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator STARTSWITH / "|" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'STARTSWITH',
            Value          => '"Unit|Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'Unit|Test%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'Unit|Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator STARTSWITH / double quoted and "|" and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'STARTSWITH',
            Value          => '"Unit"|Test+Baa',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  OR (test LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'Baa%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'Baa%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator STARTSWITH / double quoted and "|" and "+" and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'STARTSWITH',
            Value          => 'Foo "Unit"|Test+Baa',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'Foo%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'Foo%\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  OR (test LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'Baa%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'Baa%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator STARTSWITH / space, "|", "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'STARTSWITH',
            Value          => '"Foo Unit|Test+Baa"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'Foo Unit|Test+Baa%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'Foo Unit|Test+Baa%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator STARTSWITH / not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'STARTSWITH',
            Value          => '"UnitTest',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'UnitTest%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'UnitTest%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator STARTSWITH / "|" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'STARTSWITH',
            Value          => 'Unit|"Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  OR (test LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator STARTSWITH / "+" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'STARTSWITH',
            Value          => 'Unit+"Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator STARTSWITH / space and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'STARTSWITH',
            Value          => 'Unit "Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'Unit%\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator STARTSWITH / wildcard text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'STARTSWITH',
            Value          => 'Unit*Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'Unit*Test%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'Unit*Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator STARTSWITH / wildcard in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'STARTSWITH',
            Value          => '"Unit*Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'Unit*Test%\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'Unit*Test%\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator ENDSWITH / simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'ENDSWITH',
            Value          => 'UnitTest',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%UnitTest\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator ENDSWITH / quoted simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'ENDSWITH',
            Value          => '"UnitTest"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%UnitTest\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator ENDSWITH / double quoted and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'ENDSWITH',
            Value          => '"Unit"+Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator ENDSWITH / double quoted and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'ENDSWITH',
            Value          => '"Unit" Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator ENDSWITH / "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'ENDSWITH',
            Value          => '"Unit+Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit+Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator ENDSWITH / space in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'ENDSWITH',
            Value          => '"Unit Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator ENDSWITH / double quoted and "|" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'ENDSWITH',
            Value          => '"Unit"|Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  OR (test LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator ENDSWITH / "|" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'ENDSWITH',
            Value          => '"Unit|Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit|Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator ENDSWITH / double quoted and "|" and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'ENDSWITH',
            Value          => '"Unit"|Test+Baa',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  OR (test LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'%Baa\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator ENDSWITH / double quoted and "|" and "+" and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'ENDSWITH',
            Value          => 'Foo "Unit"|Test+Baa',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Foo\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  OR (test LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'%Baa\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator ENDSWITH / space, "|", "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'ENDSWITH',
            Value          => '"Foo Unit|Test+Baa"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Foo Unit|Test+Baa\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator ENDSWITH / not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'ENDSWITH',
            Value          => '"UnitTest',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%UnitTest\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator ENDSWITH / "|" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'ENDSWITH',
            Value          => 'Unit|"Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  OR (test LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator ENDSWITH / "+" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'ENDSWITH',
            Value          => 'Unit+"Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator ENDSWITH / space and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'ENDSWITH',
            Value          => 'Unit "Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator ENDSWITH / wildcard text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'ENDSWITH',
            Value          => 'Unit*Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit*Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator ENDSWITH / wildcard in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'ENDSWITH',
            Value          => '"Unit*Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit*Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator ENDSWITH / simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'ENDSWITH',
            Value          => 'UnitTest',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%UnitTest\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%UnitTest\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator ENDSWITH / quoted simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'ENDSWITH',
            Value          => '"UnitTest"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%UnitTest\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%UnitTest\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator ENDSWITH / double quoted and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'ENDSWITH',
            Value          => '"Unit"+Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator ENDSWITH / double quoted and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'ENDSWITH',
            Value          => '"Unit" Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator ENDSWITH / "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'ENDSWITH',
            Value          => '"Unit+Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit+Test\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Unit+Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator ENDSWITH / space in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'ENDSWITH',
            Value          => '"Unit Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit Test\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Unit Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator ENDSWITH / double quoted and "|" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'ENDSWITH',
            Value          => '"Unit"|Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  OR (test LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator ENDSWITH / "|" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'ENDSWITH',
            Value          => '"Unit|Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit|Test\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Unit|Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator ENDSWITH / double quoted and "|" and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'ENDSWITH',
            Value          => '"Unit"|Test+Baa',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  OR (test LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'%Baa\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Baa\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator ENDSWITH / double quoted and "|" and "+" and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'ENDSWITH',
            Value          => 'Foo "Unit"|Test+Baa',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Foo\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Foo\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  OR (test LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'%Baa\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Baa\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator ENDSWITH / space, "|", "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'ENDSWITH',
            Value          => '"Foo Unit|Test+Baa"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Foo Unit|Test+Baa\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Foo Unit|Test+Baa\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator ENDSWITH / not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'ENDSWITH',
            Value          => '"UnitTest',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%UnitTest\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%UnitTest\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator ENDSWITH / "|" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'ENDSWITH',
            Value          => 'Unit|"Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  OR (test LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator ENDSWITH / "+" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'ENDSWITH',
            Value          => 'Unit+"Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator ENDSWITH / space and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'ENDSWITH',
            Value          => 'Unit "Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Unit\') ESCAPE \'' . $Escape . '\')  AND (test LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator ENDSWITH / wildcard text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'ENDSWITH',
            Value          => 'Unit*Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit*Test\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Unit*Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator ENDSWITH / wildcard in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'ENDSWITH',
            Value          => '"Unit*Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'%Unit*Test\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'%Unit*Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator LIKE / simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'LIKE',
            Value          => 'UnitTest',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'UnitTest\')) '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator LIKE / quoted simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'LIKE',
            Value          => '"UnitTest"',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'UnitTest\')) '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator LIKE / double quoted and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'LIKE',
            Value          => '"Unit"+Test',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'Unit\'))  AND (test = LOWER(\'Test\')) '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator LIKE / double quoted and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'LIKE',
            Value          => '"Unit" Test',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'Unit\'))  AND (test = LOWER(\'Test\')) '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator LIKE / "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'LIKE',
            Value          => '"Unit+Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'Unit+Test\')) '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator LIKE / space in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'LIKE',
            Value          => '"Unit Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'Unit Test\')) '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator LIKE / double quoted and "|" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'LIKE',
            Value          => '"Unit"|Test',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'Unit\'))  OR (test = LOWER(\'Test\')) '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator LIKE / "|" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'LIKE',
            Value          => '"Unit|Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'Unit|Test\')) '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator LIKE / double quoted and "|" and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'LIKE',
            Value          => '"Unit"|Test+Baa',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'Unit\'))  OR (test = LOWER(\'Test\'))  AND (test = LOWER(\'Baa\')) '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator LIKE / double quoted and "|" and "+" and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'LIKE',
            Value          => 'Foo "Unit"|Test+Baa',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'Foo\'))  AND (test = LOWER(\'Unit\'))  OR (test = LOWER(\'Test\'))  AND (test = LOWER(\'Baa\')) '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator LIKE / space, "|", "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'LIKE',
            Value          => '"Foo Unit|Test+Baa"',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'Foo Unit|Test+Baa\')) '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator LIKE / not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'LIKE',
            Value          => '"UnitTest',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'UnitTest\')) '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator LIKE / "|" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'LIKE',
            Value          => 'Unit|"Test',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'Unit\'))  OR (test = LOWER(\'Test\')) '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator LIKE / "+" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'LIKE',
            Value          => 'Unit+"Test',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'Unit\'))  AND (test = LOWER(\'Test\')) '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator LIKE / space and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'LIKE',
            Value          => 'Unit "Test',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'Unit\'))  AND (test = LOWER(\'Test\')) '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator LIKE / wildcard text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'LIKE',
            Value          => 'Unit*Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'Unit%Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: single static column / Operator LIKE / wildcard in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test'],
            Operator       => 'LIKE',
            Value          => '"Unit*Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'Unit*Test\')) '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator LIKE / simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'LIKE',
            Value          => 'UnitTest',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'UnitTest\') OR Foo = LOWER(\'UnitTest\')) '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator LIKE / quoted simple text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'LIKE',
            Value          => '"UnitTest"',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'UnitTest\') OR Foo = LOWER(\'UnitTest\')) '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator LIKE / double quoted and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'LIKE',
            Value          => '"Unit"+Test',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'Unit\') OR Foo = LOWER(\'Unit\'))  AND (test = LOWER(\'Test\') OR Foo = LOWER(\'Test\')) '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator LIKE / double quoted and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'LIKE',
            Value          => '"Unit" Test',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'Unit\') OR Foo = LOWER(\'Unit\'))  AND (test = LOWER(\'Test\') OR Foo = LOWER(\'Test\')) '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator LIKE / "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'LIKE',
            Value          => '"Unit+Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'Unit+Test\') OR Foo = LOWER(\'Unit+Test\')) '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator LIKE / space in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'LIKE',
            Value          => '"Unit Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'Unit Test\') OR Foo = LOWER(\'Unit Test\')) '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator LIKE / double quoted and "|" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'LIKE',
            Value          => '"Unit"|Test',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'Unit\') OR Foo = LOWER(\'Unit\'))  OR (test = LOWER(\'Test\') OR Foo = LOWER(\'Test\')) '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator LIKE / "|" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'LIKE',
            Value          => '"Unit|Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'Unit|Test\') OR Foo = LOWER(\'Unit|Test\')) '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator LIKE / double quoted and "|" and "+" text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'LIKE',
            Value          => '"Unit"|Test+Baa',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'Unit\') OR Foo = LOWER(\'Unit\'))  OR (test = LOWER(\'Test\') OR Foo = LOWER(\'Test\'))  AND (test = LOWER(\'Baa\') OR Foo = LOWER(\'Baa\')) '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator LIKE / double quoted and "|" and "+" and space text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'LIKE',
            Value          => 'Foo "Unit"|Test+Baa',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'Foo\') OR Foo = LOWER(\'Foo\'))  AND (test = LOWER(\'Unit\') OR Foo = LOWER(\'Unit\'))  OR (test = LOWER(\'Test\') OR Foo = LOWER(\'Test\'))  AND (test = LOWER(\'Baa\') OR Foo = LOWER(\'Baa\')) '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator LIKE / space, "|", "+" in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'LIKE',
            Value          => '"Foo Unit|Test+Baa"',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'Foo Unit|Test+Baa\') OR Foo = LOWER(\'Foo Unit|Test+Baa\')) '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator LIKE / not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'LIKE',
            Value          => '"UnitTest',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'UnitTest\') OR Foo = LOWER(\'UnitTest\')) '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator LIKE / "|" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'LIKE',
            Value          => 'Unit|"Test',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'Unit\') OR Foo = LOWER(\'Unit\'))  OR (test = LOWER(\'Test\') OR Foo = LOWER(\'Test\')) '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator LIKE / "+" and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'LIKE',
            Value          => 'Unit+"Test',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'Unit\') OR Foo = LOWER(\'Unit\'))  AND (test = LOWER(\'Test\') OR Foo = LOWER(\'Test\')) '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator LIKE / space and not closed double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'LIKE',
            Value          => 'Unit "Test',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'Unit\') OR Foo = LOWER(\'Unit\'))  AND (test = LOWER(\'Test\') OR Foo = LOWER(\'Test\')) '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator LIKE / wildcard text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'LIKE',
            Value          => 'Unit*Test',
            IsStaticSearch => 1
        },
        Expected  => '(test LIKE LOWER(\'Unit%Test\') ESCAPE \'' . $Escape . '\' OR Foo LIKE LOWER(\'Unit%Test\') ESCAPE \'' . $Escape . '\') '
    },
    {
        Name      => '_FulltextCondition: multiple static StaticColumns  / Operator LIKE / wildcard in double quoted text value',
        Method    => '_FulltextCondition',
        Parameter => {
            StaticColumns  => ['test', 'Foo'],
            Operator       => 'LIKE',
            Value          => '"Unit*Test"',
            IsStaticSearch => 1
        },
        Expected  => '(test = LOWER(\'Unit*Test\') OR Foo = LOWER(\'Unit*Test\')) '
    }
);
for my $Test ( @GetOperationTests ) {
    my $Method = $Test->{Method} || '_GetCondition';

    my $Result = $CommonAttributeObject->$Method(
        %{ $Test->{Parameter} },
        Silent => defined( $Test->{Expected} ) ? 0 : 1
    );
    $Self->Is(
        $Result,
        $Test->{Expected},
        $Test->{Name}
    );
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
