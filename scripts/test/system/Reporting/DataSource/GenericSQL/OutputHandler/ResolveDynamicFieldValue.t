# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);
use vars (qw($Self));

# get ReportDefinition object
my $ReportingObject = $Kernel::OM->Get('Reporting');
my $DynamicFieldObject = $Kernel::OM->Get('DynamicField');
my $PivotObject = $ReportingObject->_LoadDataSourceBackend(Name => 'GenericSQL')->_LoadOutputHandlerBackend(Name => 'ResolveDynamicFieldValue');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# create dynamic field
my $DynamicFieldID = $DynamicFieldObject->DynamicFieldAdd(
    Name       => 'test',
    Label      => 'test',
    FieldType  => 'Multiselect',
    ObjectType => 'Ticket',
    Config     => {
        CountDefault       => 1,
        CountMin           => 1,
        CountMax           => 1,
        ItemSeparator      => '',
        DefaultValue       => 0,
        PossibleValues     => {
            0 => 'solved',
            1 => 'solved (work around)',
            2 => 'not solved (not reproducible)',
            3 => 'not solved (too expensive)',
            4 => 'solved by caller',
            5 => 'cancelled by caller'
        },
        TranslatableValues => 1
    },
    ValidID    => 1,
    UserID     => 1,
);

$Self->True(
    $DynamicFieldID,
    'DynamicFieldAdd()',
);

my @ConfigTests = (
    {
        Test   => 'no config',
        Config => undef,
        Expect => undef,
        Silent => 1,
    },
    {
        Test   => 'empty config',
        Config => {},
        Expect => undef,
        Silent => 1,
    },
    {
        Test   => 'invalid Config - missing FieldNames attribute',
        Config => {
            Columns => ['col1','col2'],
        },
        Expect => undef,
        Silent => 1,
    },
    {
        Test   => 'invalid Config - missing Columns atribute',
        Config => {
            FieldNames => ['test','test'],
        },
        Expect => undef,
        Silent => 1,
    },
    {
        Test   => 'invalid Config - Columns and FieldNames are different',
        Config => {
            Columns => ['col1','col2'],
            FieldNames => ['test'],
        },
        Expect => undef,
        Silent => 1,
    },
    {
        Test   => 'valid Config',
        Config => {
            Columns => ['col1','col2'],
            FieldNames => ['test', 'test'],
        },
        Expect => 1,
    },
);

foreach my $Test ( @ConfigTests ) {
    # wrong config
    my $Result = $PivotObject->ValidateConfig(
        Config => $Test->{Config},
        Silent => $Test->{Silent},
    );

    if ( $Test->{Expect} ) {
        $Self->True(
            $Result,
            'ValidateConfig() - '.$Test->{Test},
        );
    }
    else {
        $Self->False(
            $Result,
            'ValidateConfig() - '.$Test->{Test},
        );
    }
}

my @DataTests = (
    {
        Test   => 'simple test',
        Config => {
            Columns => ['col1', 'col4'],
            FieldNames => ['test', 'test'],
        },
        Data   => {
            Columns => ['col1','col2','col3','col4'],
            Data => [
                {
                    col1 => 1,
                    col2 => 'column2',
                    col3 => 'just a test',
                    col4 => 2
                },
                {
                    col1 => 0,
                    col2 => 'column2',
                    col3 => 'just a test',
                    col4 => 3
                },
                {
                    col1 => 4,
                    col2 => 'column2',
                    col3 => 'just a test',
                    col4 => 5
                },
            ]
        },
        Expect => {
            Columns => ['col1', 'col2', 'col3', 'col4'],
            Data    => [
                {
                    col1 => 'solved (work around)',
                    col2 => 'column2',
                    col3 => 'just a test',
                    col4 => 'not solved (not reproducible)'
                },
                {
                    col1 => 'solved',
                    col2 => 'column2',
                    col3 => 'just a test',
                    col4 => 'not solved (too expensive)'
                },
                {
                    col1 => 'solved by caller',
                    col2 => 'column2',
                    col3 => 'just a test',
                    col4 => 'cancelled by caller'
                },
            ]
        }
    },
    {
        Test   => 'simple test with wrong value',
        Config => {
            Columns => ['col1', 'col4'],
            FieldNames => ['test', 'test'],
        },
        Data   => {
            Columns => ['col1','col2','col3','col4'],
            Data => [
                {
                    col1 => 1,
                    col2 => 'column2',
                    col3 => 'just a test',
                    col4 => 99
                },
            ]
        },
        Expect => {
            Columns => ['col1', 'col2', 'col3', 'col4'],
            Data    => [
                {
                    col1 => 'solved (work around)',
                    col2 => 'column2',
                    col3 => 'just a test',
                    col4 => 99
                },
            ]
        }
    },
);

foreach my $Test ( @DataTests ) {
    my $Result = $PivotObject->Run(
        Config => $Test->{Config},
        Data   => $Test->{Data},
    );

    $Self->IsDeeply(
        $Result,
        $Test->{Expect},
        'Run() - '.$Test->{Test},
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
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
