# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
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
    )
) {
    $Self->True(
        $CommonAttributeObject->can($Method),
        'CommonAttribute object can "' . $Method . '"'
    );
}

## check internal functions ##
my @LargeArray = (0) x 1000;
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
        Expected  => 'CAST(test AS VARCHAR) LIKE \'1%\''
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
        Expected  => '(CAST(test AS VARCHAR) LIKE \'1%\' OR CAST(test AS VARCHAR) LIKE \'2%\')'
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
        Expected  => 'CAST(test AS VARCHAR) LIKE \'%1\''
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
        Expected  => '(CAST(test AS VARCHAR) LIKE \'%1\' OR CAST(test AS VARCHAR) LIKE \'%2\')'
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
        Expected  => 'CAST(test AS VARCHAR) LIKE \'%1%\''
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
        Expected  => '(CAST(test AS VARCHAR) LIKE \'%1%\' OR CAST(test AS VARCHAR) LIKE \'%2%\')'
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
        Expected  => 'CAST(test AS VARCHAR) LIKE \'1\''
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
        Expected  => '(CAST(test AS VARCHAR) LIKE \'1\' OR CAST(test AS VARCHAR) LIKE \'2\')'
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
    }
);
for my $Test ( @GetOperationTests ) {
    my $Result = $CommonAttributeObject->_GetCondition(
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
