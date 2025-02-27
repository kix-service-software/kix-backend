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

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# get current counts of report definitions before testing
my %BaseList = $ReportingObject->ReportDefinitionList(
    UserID => 1,
);
my $BaseCount = scalar keys %BaseList;
my %BaseValidList = $ReportingObject->ReportDefinitionList(
    Valid  => 1,
    UserID => 1,
);
my $BaseValidCount = scalar keys %BaseValidList;
my %BaseTypeList = $ReportingObject->ReportDefinitionList(
    Type   => 'GenericSQL',
    Valid  => 1,
    UserID => 1,
);
my $BaseTypeCount = scalar keys %BaseTypeList;

# create test definition
my $ReportDefinitionName  = 'definition-'.$Helper->GetRandomID();

my $ReportDefinitionID1 = $ReportingObject->ReportDefinitionAdd(
    Name       => $ReportDefinitionName.'-GenericSQL',
    DataSource => 'GenericSQL',
    ValidID    => 1,
    UserID     => 1,
);

$Self->True(
    $ReportDefinitionID1,
    'ReportDefinitionAdd() for new definition ' . $ReportDefinitionName.'-GenericSQL',
);

my $ReportDefinitionID2 = $ReportingObject->ReportDefinitionAdd(
    Name       => $ReportDefinitionName.'-invalid-GenericSQL',
    DataSource => 'GenericSQL',
    IsPeriodic => 1,
    MaxReports => 5,
    ValidID    => 2,
    UserID     => 1,
);

$Self->True(
    $ReportDefinitionID2,
    'ReportDefinitionAdd() for new definition ' . $ReportDefinitionName.'-invalid-GenericSQL',
);

# same name
my $Success = $ReportingObject->ReportDefinitionAdd(
    Name       => $ReportDefinitionName.'-GenericSQL',
    DataSource => 'GenericSQL',
    ValidID    => 2,
    UserID     => 1,
    Silent     => 1,
);

$Self->False(
    $Success,
    'ReportDefinitionAdd() with same name',
);

my %DefinitionList = $ReportingObject->ReportDefinitionList(
    UserID => 1,
);

$Self->Is(
    scalar keys %DefinitionList,
    $BaseCount+2,
    'ReportDefinitionList() - without restrictions',
);

%DefinitionList = $ReportingObject->ReportDefinitionList(
    Valid  => 1,
    UserID => 1,
);

$Self->Is(
    scalar keys %DefinitionList,
    $BaseValidCount+1,
    'ReportDefinitionList() - only valid',
);

%DefinitionList = $ReportingObject->ReportDefinitionList(
    Type   => 'GenericSQL',
    Valid  => 1,
    UserID => 1,
);

$Self->Is(
    scalar keys %DefinitionList,
    $BaseTypeCount+1,
    'ReportDefinitionList() - only type "GenericSQL"',
);

$Self->Is(
    (sort values %DefinitionList)[-1],
    $ReportDefinitionName.'-GenericSQL',
    'ReportDefinitionList() - only type "GenericSQL"',
);

my %Definition = $ReportingObject->ReportDefinitionGet(
    ID => $ReportDefinitionID2
);

$Self->True(
    IsHashRefWithData(\%Definition),
    'ReportDefinitionGet()',
);

$Self->Is(
    $Definition{Name},
    $ReportDefinitionName.'-invalid-GenericSQL',
    'ReportDefinitionGet()',
);

$Self->Is(
    $Definition{IsPeriodic},
    1,
    'ReportDefinitionGet() - IsPeriodic has correct value',
);

$Self->Is(
    $Definition{MaxReports},
    5,
    'ReportDefinitionGet() - MaxReports has correct value',
);

$Success = $ReportingObject->ReportDefinitionUpdate(
    ID => $ReportDefinitionID2,
    %Definition,
    IsPeriodic => undef,
    MaxReports => 0,
    ValidID    => 1,
    UserID     => 1,
);

$Self->True(
    $Success,
    'ReportDefinitionUpdate() - set to valid',
);

%DefinitionList = $ReportingObject->ReportDefinitionList(
    Valid  => 1,
    UserID => 1,
);

$Self->Is(
    scalar keys %DefinitionList,
    $BaseValidCount+2,
    'ReportDefinitionList() - only valid after update',
);

# get after update
%Definition = $ReportingObject->ReportDefinitionGet(
    ID => $ReportDefinitionID2
);

$Self->True(
    IsHashRefWithData(\%Definition),
    'ReportDefinitionGet() - after update to valid',
);

$Self->Is(
    $Definition{ValidID},
    1,
    'ReportDefinitionGet() - ValidID has correct value',
);

$Self->Is(
    $Definition{IsPeriodic},
    0,
    'ReportDefinitionGet() - IsPeriodic has correct value',
);

$Self->Is(
    $Definition{MaxReports},
    0,
    'ReportDefinitionGet() - MaxReports has correct value',
);

# update to the same name like definition 1
$Success = $ReportingObject->ReportDefinitionUpdate(
    %Definition,
    ID     => $ReportDefinitionID2,
    Name   => $ReportDefinitionName.'-GenericSQL',
    UserID => 1,
    Silent => 1,
);

$Self->False(
    $Success,
    'ReportDefinitionUpdate() - rename to existing name',
);

$Success = $ReportingObject->ReportDefinitionDelete(
    ID     => $ReportDefinitionID2,
    UserID => 1,
);

$Self->True(
    $Success,
    'ReportDefinitionDelete()',
);

%DefinitionList = $ReportingObject->ReportDefinitionList(
    UserID => 1,
);

$Self->Is(
    scalar keys %DefinitionList,
    $BaseCount+1,
    'ReportDefinitionList() - without restrictions after delete',
);

my @ValidationTests = (
    {
        Test   => 'invalid config - no report type config',
        Config => {
        },
        Expect => undef,
        Silent => 1,
    },
    {
        Test   => 'invalid config - no output formats defined',
        Config => {
            DataSource => {
                SQL => {
                    any => 'SELECT count(*) as Total FROM valid',
                }
            },
        },
        Expect => 1,
    },
    {
        Test   => 'invalid config - invalid output format defined',
        Config => {
            DataSource => {
                SQL => {
                    any => 'SELECT count(*) as Total FROM valid',
                }
            },
            OutputFormats => {
                dummy => {}
            }
        },
        Expect => undef,
        Silent => 1,
    },
    {
        Test   => 'valid config - valid output format defined with empty config',
        Config => {
            DataSource => {
                SQL => {
                    any => 'SELECT count(*) as Total FROM valid',
                }
            },
            OutputFormats => {
                CSV => {}
            }
        },
        Expect => 1,
    },
    {
        Test   => 'valid config - valid output format defined with valid config',
        Config => {
            DataSource => {
                SQL => {
                    any => 'SELECT count(*) as Total FROM valid',
                }
            },
            OutputFormats => {
                CSV => {
                    Columns => ['Total']
                }
            }
        },
        Expect => 1,
    },
    {
        Test   => 'invalid config - parameter used but no parameter config exists',
        Config => {
            DataSource => {
                SQL => {
                    any => 'SELECT count(*) as Total FROM valid WHERE name LIKE \'${Parameters.TestParameter}%\'',
                }
            },
            OutputFormats => {
                CSV => {
                    Columns => ['Total']
                }
            }
        },
        Expect => undef,
        Silent => 1,
    },
    {
        Test   => 'invalid config - parameter used but not defined',
        Config => {
            DataSource => {
                SQL => {
                    any => 'SELECT count(*) as Total FROM valid WHERE name LIKE \'${Parameters.TestParameter}%\'',
                }
            },
            Parameters => [],
            OutputFormats => {
                CSV => {
                    Columns => ['Total']
                }
            }
        },
        Expect => undef,
        Silent => 1,
    },
    {
        Test   => 'invalid config - parameter used but incorrectly defined - config missing',
        Config => {
            DataSource => {
                SQL => {
                    any => 'SELECT count(*) as Total FROM valid WHERE name LIKE \'${Parameters.TestParameter}%\'',
                }
            },
            Parameters => [
                { }
            ],
            OutputFormats => {
                CSV => {
                    Columns => ['Total']
                }
            }
        },
        Expect => undef,
        Silent => 1,
    },
    {
        Test   => 'invalid config - parameter used and incorrectly defined - Name missing',
        Config => {
            DataSource => {
                SQL => {
                    any => 'SELECT count(*) as Total FROM valid WHERE name LIKE \'${Parameters.TestParameter}%\'',
                }
            },
            Parameters => [
                {
                    DataType => 'STRING'
                }
            ],
            OutputFormats => {
                CSV => {
                    Columns => ['Total']
                }
            }
        },
        Expect => undef,
        Silent => 1,
    },
    {
        Test   => 'invalid config - parameter used and incorrectly defined - DataType missing',
        Config => {
            DataSource => {
                SQL => {
                    any => 'SELECT count(*) as Total FROM valid WHERE name LIKE \'${Parameters.TestParameter}%\'',
                }
            },
            Parameters => [
                {
                    Name => 'TestParameter',
                    Label => 'Name Pattern'
                }
            ],
            OutputFormats => {
                CSV => {
                    Columns => ['Total']
                }
            }
        },
        Expect => undef,
        Silent => 1,
    },
    {
        Test   => 'valid config - parameter used and correctly defined',
        Config => {
            DataSource => {
                SQL => {
                    any => 'SELECT count(*) as Total FROM valid WHERE name LIKE \'${Parameters.TestParameter}%\'',
                }
            },
            Parameters => [
                {
                    Name     => 'TestParameter',
                    Label    => 'Name Pattern',
                    DataType => 'STRING'
                }
            ],
            OutputFormats => {
                CSV => {
                    Columns => ['Total']
                }
            }
        },
        Expect => 1,
    },
);

foreach my $Test ( @ValidationTests ) {
    my $Result = $ReportingObject->ReportDefinitionAdd(
        Name       => $Test->{Test}.'-GenericSQL',
        DataSource => 'GenericSQL',
        Config     => $Test->{Config},
        ValidID    => 1,
        UserID     => 1,
        Silent     => $Test->{Silent},
    );

    if ( $Test->{Expect} ) {
        $Self->True(
            $Result,
            'ReportDefinitionAdd() - '.$Test->{Test},
        );
    }
    else {
        $Self->False(
            $Result,
            'ReportDefinitionAdd() - '.$Test->{Test},
        );
    }
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
