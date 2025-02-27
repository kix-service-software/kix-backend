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

use Kernel::System::VariableCheck qw(:all);
use vars (qw($Self));

# get ReportDefinition object
my $ReportingObject = $Kernel::OM->Get('Reporting');
my $DynamicFieldObject = $Kernel::OM->Get('DynamicField');
my $PivotObject = $ReportingObject->_LoadDataSourceBackend(Name => 'GenericSQL')->_LoadOutputHandlerBackend(Name => 'Translate');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

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
        Test   => 'invalid Config - unknown Language',
        Config => {
            Language => 'cn',
        },
        Expect => undef,
        Silent => 1,
    },
    {
        Test   => 'valid Config without Language',
        Config => {
            Columns => ['col1','col2'],
        },
        Expect => 1
    },
    {
        Test   => 'valid Config with Language',
        Config => {
            Columns  => ['col1','col2'],
            Language => 'de'
        },
        Expect => 1
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
        Test   => 'simple test without Language',
        Config => {
            Columns => ['col1', 'col4'],
        },
        Data   => {
            Columns => ['col1','col2','col3','col4'],
            Data => [
                {
                    col1 => 'open',
                    col2 => 'column2',
                    col3 => 'just a test',
                    col4 => 'closed'
                },
            ]
        },
        Expect => {
            Columns => ['col1', 'col2', 'col3', 'col4'],
            Data    => [
                {
                    col1 => 'offen',
                    col2 => 'column2',
                    col3 => 'just a test',
                    col4 => 'geschlossen'
                },
            ]
        }
    },
    {
        Test   => 'simple test with Language',
        Config => {
            Columns => ['col1', 'col4'],
            Language => 'de'
        },
        Data   => {
            Columns => ['col1','col2','col3','col4'],
            Data => [
                {
                    col1 => 'open',
                    col2 => 'column2',
                    col3 => 'just a test',
                    col4 => 'closed'
                },
            ]
        },
        Expect => {
            Columns => ['col1', 'col2', 'col3', 'col4'],
            Data    => [
                {
                    col1 => 'offen',
                    col2 => 'column2',
                    col3 => 'just a test',
                    col4 => 'geschlossen'
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

1;




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
