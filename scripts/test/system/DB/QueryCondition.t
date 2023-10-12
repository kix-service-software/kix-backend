# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get needed objects
my $DBObject  = $Kernel::OM->Get('DB');
my $XMLObject = $Kernel::OM->Get('XML');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# ------------------------------------------------------------ #
# QueryCondition tests
# ------------------------------------------------------------ #
my $XML = '
<TableCreate Name="test_condition">
    <Column Name="name_a" Required="true" Size="60" Type="VARCHAR"/>
    <Column Name="name_b" Required="true" Size="60" Type="VARCHAR"/>
</TableCreate>
';
my @XMLARRAY = $XMLObject->XMLParse( String => $XML );
my @SQL = $DBObject->SQLProcessor( Database => \@XMLARRAY );
$Self->True(
    $SQL[0],
    '#8 SQLProcessor() CREATE TABLE',
);

for my $SQL (@SQL) {
    $Self->True(
        $DBObject->Do( SQL => $SQL ) || 0,
        "#8 Do() CREATE TABLE ($SQL)",
    );
}

my %Fill = (
    Some01 => 'John Smith',
    Some02 => 'John Meier',
    Some03 => 'Franz Smith',
    Some04 => 'Franz Ferdinand Smith',
    Some05 => 'customer_id_with_underscores',
    Some06 => 'customer&id&with&ampersands',
    Some07 => 'Test (with) (brackets)',
    Some08 => 'Test (with) (brackets) and & and |',
    Some09 => 'Test for franz!gans merged with exclamation mark',
    Some10 => 'customer & id with ampersand & spaces',
    Some11 => 'Test with single quotes \'test\'',
);
for my $Key ( sort keys %Fill ) {
    my $SQL = "INSERT INTO test_condition (name_a, name_b) VALUES (?, ?)";
    my $Do  = $DBObject->Do(
        SQL  => $SQL,
        Bind => [
            \$Key,
            \$Fill{$Key},
        ],
    );
    $Self->True(
        $Do,
        "#8 Do() INSERT ($SQL)",
    );
}
my @Queries = (
    {
        Query  => 'franz ferdinand',
        Result => {
            Some01 => 0,
            Some02 => 0,
            Some03 => 0,
            Some04 => 1,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => 'john+smith',
        Result => {
            Some01 => 1,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => 'john+smith+ ',
        Result => {
            Some01 => 1,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => 'john+smith+',
        Result => {
            Some01 => 1,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '+john+smith',
        Result => {
            Some01 => 1,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '(john+smith)',
        Result => {
            Some01 => 1,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '(john+smith)+',
        Result => {
            Some01 => 1,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '(john&&smith)',
        Result => {
            Some01 => 1,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '(john && smith)',
        Result => {
            Some01 => 1,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '(john && smi*h)',
        Result => {
            Some01 => 1,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '(john && smi**h)',
        Result => {
            Some01 => 1,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '(john||smith)',
        Result => {
            Some01 => 1,
            Some02 => 1,
            Some03 => 1,
            Some04 => 1,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '(john || smith)',
        Result => {
            Some01 => 1,
            Some02 => 1,
            Some03 => 1,
            Some04 => 1,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '(smith || john)',
        Result => {
            Some01 => 1,
            Some02 => 1,
            Some03 => 1,
            Some04 => 1,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '(john AND smith)',
        Result => {
            Some01 => 1,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '(john AND smith)',
        Result => {
            Some01 => 1,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '(john AND)',
        Result => {
            Some01 => 1,
            Some02 => 1,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '(franz+)',
        Result => {
            Some01 => 0,
            Some02 => 0,
            Some03 => 1,
            Some04 => 1,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 1,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '((john+smith) OR meier)',
        Result => {
            Some01 => 1,
            Some02 => 1,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '((john1+smith1) OR meier)',
        Result => {
            Some01 => 0,
            Some02 => 1,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => 'fritz',
        Result => {
            Some01 => 0,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '!fritz',
        Result => {
            Some01 => 1,
            Some02 => 1,
            Some03 => 1,
            Some04 => 1,
            Some05 => 1,
            Some06 => 1,
            Some07 => 1,
            Some08 => 1,
            Some09 => 1,
            Some10 => 1,
            Some11 => 1,
        },
    },
    {
        Query  => '!franz',
        Result => {
            Some01 => 1,
            Some02 => 1,
            Some03 => 0,
            Some04 => 0,
            Some05 => 1,
            Some06 => 1,
            Some07 => 1,
            Some08 => 1,
            Some09 => 0,
            Some10 => 1,
            Some11 => 1,
        },
    },
    {
        Query  => 'franz!gans',
        Result => {
            Some01 => 0,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 1,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '!franz*',
        Result => {
            Some01 => 1,
            Some02 => 1,
            Some03 => 0,
            Some04 => 0,
            Some05 => 1,
            Some06 => 1,
            Some07 => 1,
            Some08 => 1,
            Some09 => 0,
            Some10 => 1,
            Some11 => 1,
        },
    },
    {
        Query  => '!*franz*',
        Result => {
            Some01 => 1,
            Some02 => 1,
            Some03 => 0,
            Some04 => 0,
            Some05 => 1,
            Some06 => 1,
            Some07 => 1,
            Some08 => 1,
            Some09 => 0,
            Some10 => 1,
            Some11 => 1,
        },
    },
    {
        Query  => '*!*franz*',
        Result => {
            Some01 => 1,
            Some02 => 1,
            Some03 => 0,
            Some04 => 0,
            Some05 => 1,
            Some06 => 1,
            Some07 => 1,
            Some08 => 1,
            Some09 => 0,
            Some10 => 1,
            Some11 => 1,
        },
    },
    {
        Query  => '*!franz*',
        Result => {
            Some01 => 1,
            Some02 => 1,
            Some03 => 0,
            Some04 => 0,
            Some05 => 1,
            Some06 => 1,
            Some07 => 1,
            Some08 => 1,
            Some09 => 0,
            Some10 => 1,
            Some11 => 1,
        },
    },
    {
        Query  => '(!fritz+!bob)',
        Result => {
            Some01 => 1,
            Some02 => 1,
            Some03 => 1,
            Some04 => 1,
            Some05 => 1,
            Some06 => 1,
            Some07 => 1,
            Some08 => 1,
            Some09 => 1,
            Some10 => 1,
            Some11 => 1,
        },
    },
    {
        Query  => '((!fritz+!bob)+i)',
        Result => {
            Some01 => 1,
            Some02 => 1,
            Some03 => 1,
            Some04 => 1,
            Some05 => 1,
            Some06 => 1,
            Some07 => 1,
            Some08 => 1,
            Some09 => 1,
            Some10 => 1,
            Some11 => 1,
        },
    },
    {
        Query  => '((john+smith) OR (meier+john))',
        Result => {
            Some01 => 1,
            Some02 => 1,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '((john+smith)OR(meier+john))',
        Result => {
            Some01 => 1,
            Some02 => 1,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '((john+smith)  OR     ( meier+ john))',
        Result => {
            Some01 => 1,
            Some02 => 1,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '((john+smith)  OR     (meier+ john))',
        Result => {
            Some01 => 1,
            Some02 => 1,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '(("john smith")  OR     (meier+ john))',
        Result => {
            Some01 => 1,
            Some02 => 1,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '"john smith"',
        Result => {
            Some01 => 1,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '( "john smith" )',
        Result => {
            Some01 => 1,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '"smith john"',
        Result => {
            Some01 => 0,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '(("john NOTHING smith")  OR     (meier+ john))',
        Result => {
            Some01 => 0,
            Some02 => 1,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '((smith+john)|| (meier+john))',
        Result => {
            Some01 => 1,
            Some02 => 1,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '((john+smith)||  (meier+john))',
        Result => {
            Some01 => 1,
            Some02 => 1,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '*',
        Result => {
            Some01 => 1,
            Some02 => 1,
            Some03 => 1,
            Some04 => 1,
            Some05 => 1,
            Some06 => 1,
            Some07 => 1,
            Some08 => 1,
            Some09 => 1,
            Some10 => 1,
            Some11 => 1,
        },
    },
    {
        Query  => 'Franz Ferdinand',
        Result => {
            Some01 => 0,
            Some02 => 0,
            Some03 => 0,
            Some04 => 1,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => 'ferdinand',
        Result => {
            Some01 => 0,
            Some02 => 0,
            Some03 => 0,
            Some04 => 1,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => 'franz ferdinand smith',
        Result => {
            Some01 => 0,
            Some02 => 0,
            Some03 => 0,
            Some04 => 1,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => 'smith',
        Result => {
            Some01 => 1,
            Some02 => 0,
            Some03 => 1,
            Some04 => 1,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => 'smith ()',
        Result => {
            Some01 => 1,
            Some02 => 0,
            Some03 => 1,
            Some04 => 1,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => 'customer_id_with_underscores',
        Result => {
            Some01 => 0,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 1,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => 'customer_*',
        Result => {
            Some01 => 0,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 1,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '*_*',
        Result => {
            Some01 => 0,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 1,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '_',
        Result => {
            Some01 => 0,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 1,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '!_',
        Result => {
            Some01 => 1,
            Some02 => 1,
            Some03 => 1,
            Some04 => 1,
            Some05 => 0,
            Some06 => 1,
            Some07 => 1,
            Some08 => 1,
            Some09 => 1,
            Some10 => 1,
            Some11 => 1,
        },
    },
    {
        Query  => 'customer&id&with&ampersands',
        Result => {
            Some01 => 0,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 1,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => 'customer&*',
        Result => {
            Some01 => 0,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 1,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '*&*',
        Result => {
            Some01 => 0,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 1,
            Some07 => 0,
            Some08 => 1,
            Some09 => 0,
            Some10 => 1,
            Some11 => 0,
        },
    },
    {
        Query  => '&',
        Result => {
            Some01 => 0,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 1,
            Some07 => 0,
            Some08 => 1,
            Some09 => 0,
            Some10 => 1,
            Some11 => 0,
        },
    },
    {
        Query  => '!&',
        Result => {
            Some01 => 1,
            Some02 => 1,
            Some03 => 1,
            Some04 => 1,
            Some05 => 1,
            Some06 => 0,
            Some07 => 1,
            Some08 => 0,
            Some09 => 1,
            Some10 => 0,
            Some11 => 1,
        },
    },
    {
        Query  => '\(with\)',
        Result => {
            Some01 => 0,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 1,
            Some08 => 1,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => 'Test AND ( \(with\) OR \(brackets\) )',
        Result => {
            Some01 => 0,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 1,
            Some08 => 1,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => 'Test AND ( \(with\) OR \(brackets\) ) AND \|',
        Result => {
            Some01 => 0,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 1,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query => $DBObject->QueryStringEscape(
            QueryString => 'customer & id with ampersand & spaces',
        ),
        Result => {
            Some01 => 0,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 1,
            Some11 => 0,
        },
    },
    {
        Query  => 'customer & id with ampersand & spaces',
        Result => {
            Some01 => 0,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 1,
            Some11 => 0,
        },
    },
    {
        Query  => 'Test with single quotes \'test\'',
        Result => {
            Some01 => 0,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 1,
        },
    },
    {
        Query  => '\'test\'',
        Result => {
            Some01 => 0,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 1,
        },
    },
);

# select's
for my $Query (@Queries) {

    my $Condition = $DBObject->QueryCondition(
        Key          => 'name_b',
        Value        => $Query->{Query},
        SearchPrefix => '*',
        SearchSuffix => '*',
    );
    $DBObject->Prepare(
        SQL => 'SELECT name_a FROM test_condition WHERE ' . $Condition,
    );

    my %Result;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Result{ $Row[0] } = 1;
    }

    for my $Check ( sort keys %{ $Query->{Result} } ) {
        $Self->Is(
            $Result{$Check} || 0,
            $Query->{Result}->{$Check} || 0,
            "#8 Do() SQL SELECT $Query->{Query} / $Check",
        );
    }
}
@Queries = (
    {
        Query  => 'john+smith',
        Result => {
            Some01 => 1,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '(john && smi*h)',
        Result => {
            Some01 => 1,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '(john && smi**h*)',
        Result => {
            Some01 => 1,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '(john+smith+some)',
        Result => {
            Some01 => 1,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '(john+smith+!some)',
        Result => {
            Some01 => 0,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '(john+smith+(!some01||!some02))',
        Result => {
            Some01 => 1,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '(john+smith+(!some01||some))',
        Result => {
            Some01 => 1,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '(!smith+some02)',
        Result => {
            Some01 => 0,
            Some02 => 1,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => 'smith AND some02 OR some01',
        Result => {
            Some01 => 1,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '(john+(!max||!hans))',
        Result => {
            Some01 => 1,
            Some02 => 1,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '(john+(!max&&!hans))',
        Result => {
            Some01 => 1,
            Some02 => 1,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '((max||hans)&&!kkk)',
        Result => {
            Some01 => 0,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
    {
        Query  => '*',
        Result => {
            Some01 => 1,
            Some02 => 1,
            Some03 => 1,
            Some04 => 1,
            Some05 => 1,
            Some06 => 1,
            Some07 => 1,
            Some08 => 1,
            Some09 => 1,
            Some10 => 1,
            Some11 => 1,
        },
    },
    {
        Query  => 'InvalidQuery\\',
        Result => {
            Some01 => 0,
            Some02 => 0,
            Some03 => 0,
            Some04 => 0,
            Some05 => 0,
            Some06 => 0,
            Some07 => 0,
            Some08 => 0,
            Some09 => 0,
            Some10 => 0,
            Some11 => 0,
        },
    },
);

# select's
for my $Query (@Queries) {

    # Without BindMode
    my $Condition = $DBObject->QueryCondition(
        Key          => [ 'name_a', 'name_b', 'name_a', 'name_a' ],
        Value        => $Query->{Query},
        SearchPrefix => '*',
        SearchSuffix => '*',
    );
    $DBObject->Prepare(
        SQL => 'SELECT name_a FROM test_condition WHERE ' . $Condition,
    );
    my %Result;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Result{ $Row[0] } = 1;
    }
    for my $Check ( sort keys %{ $Query->{Result} } ) {
        $Self->Is(
            $Result{$Check} || 0,
            $Query->{Result}->{$Check} || 0,
            "#8 Do() SQL SELECT $Query->{Query} / $Check (BindMode 0)",
        );
    }

    # With BindMode
    my %Search = $DBObject->QueryCondition(
        Key          => [ 'name_a', 'name_b', 'name_a', 'name_a' ],
        Value        => $Query->{Query},
        SearchPrefix => '*',
        SearchSuffix => '*',
        BindMode     => 1,
    );
    $DBObject->Prepare(
        SQL  => 'SELECT name_a FROM test_condition WHERE ' . $Search{SQL},
        Bind => $Search{Values},
    );
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Result{ $Row[0] } = 1;
    }
    for my $Check ( sort keys %{ $Query->{Result} } ) {
        $Self->Is(
            $Result{$Check} || 0,
            $Query->{Result}->{$Check} || 0,
            "#8 Do() SQL SELECT $Query->{Query} / $Check (BindMode 1)",
        );
    }
}

# extended test
%Fill = (
    Some00 => '00 kix',
    Some01 => '01 kix',
);
for my $Key ( sort keys %Fill ) {
    my $SQL = "INSERT INTO test_condition (name_a, name_b) VALUES ('$Key', '$Fill{$Key}')";
    my $Do  = $DBObject->Do(
        SQL => $SQL,
    );
    $Self->True(
        $Do,
        "#8 Do() INSERT ($SQL)",
    );
}
@Queries = (
    {
        Query  => '00 kix',
        Result => {
            Some00 => 1,
            Some01 => 0,
        },
    },
    {
        Query  => '01 kix',
        Result => {
            Some00 => 0,
            Some01 => 1,
        },
    },
);
for my $Query (@Queries) {
    my $Condition = $DBObject->QueryCondition(
        Key          => [ 'name_a', 'name_b', 'name_a', 'name_a' ],
        Value        => $Query->{Query},
        SearchPrefix => '*',
        SearchSuffix => '*',
        Extended     => 1,
    );
    $DBObject->Prepare(
        SQL => 'SELECT name_a FROM test_condition WHERE ' . $Condition,
    );
    my %Result;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Result{ $Row[0] } = 1;
    }
    for my $Check ( sort keys %{ $Query->{Result} } ) {
        $Self->Is(
            $Result{$Check} || 0,
            $Query->{Result}->{$Check} || 0,
            "#8 Do() SQL SELECT $Query->{Query} / $Check",
        );
    }
}

# Query condition cleanup test - Checks if '* *' is converted correctly to '*'
{
    my $Condition = $DBObject->QueryCondition(
        Key   => 'name_a',
        Value => '* *',
    );
    $DBObject->Prepare(
        SQL => 'SELECT name_a FROM test_condition WHERE ' . $Condition,
    );
    my @Result;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @Result, $Row[0];
    }
    $Self->True(
        scalar @Result,
        "#8 QueryCondition cleanup test - Convert '* *' to '*'",
    );
}

# cleanup
$XML      = '<TableDrop Name="test_condition"/>';
@XMLARRAY = $XMLObject->XMLParse( String => $XML );
@SQL      = $DBObject->SQLProcessor( Database => \@XMLARRAY );
$Self->True(
    $SQL[0],
    '#8 SQLProcessor() DROP TABLE',
);

for my $SQL (@SQL) {
    $Self->True(
        $DBObject->Do( SQL => $SQL ) || 0,
        "#8 Do() DROP TABLE ($SQL)",
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
