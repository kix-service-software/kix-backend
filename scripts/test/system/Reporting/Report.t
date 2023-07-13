# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
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

#
# log tests
#

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# create definition
my $DefinitionID = $ReportingObject->ReportDefinitionAdd(
    DataSource => 'GenericSQL',
    Name       => 'Testreport 123',
    Config     => {
        DataSource => {
            SQL => {
                any => 'SELECT id, name, change_time, change_by, create_time, create_by FROM valid'
            }
        },
        OutputFormats => {
            CSV => {
                Columns => ['id', 'name', 'valid_id']
            },
        }
    },
    UserID => 1,
);

$Self->True(
    $DefinitionID,
    'ReportDefinitionAdd()',
);

# create report
my $ReportID = $ReportingObject->ReportCreate(
    DefinitionID => $DefinitionID,
    Config   => {
        OutputFormats => ['CSV']
    },
    UserID => 1,
);

$Self->True(
    $ReportID,
    'ReportCreate()',
);

my @ReportList = $ReportingObject->ReportList(
    DefinitionID => $DefinitionID,
);

$Self->Is(
    scalar @ReportList,
    1,
    'ReportList()',
);

my %ReportData = $ReportingObject->ReportGet(
    ID => $ReportID
);

$Self->True(
    IsHashRefWithData(\%ReportData),
    'ReportGet() - without results',
);

$Self->True(
    !IsArrayRefWithData($ReportData{Results}),
    'ReportGet() - no results in report data',
);

%ReportData = $ReportingObject->ReportGet(
    ID             => $ReportID,
    IncludeResults => 1,
);

$Self->True(
    IsHashRefWithData(\%ReportData),
    'ReportGet() - with results',
);

$Self->True(
    IsArrayRefWithData($ReportData{Results}),
    'ReportGet() - results contained in report data',
);

$Self->Is(
    scalar @{$ReportData{Results}},
    1,
    'ReportGet() - number of results',
);

# create a 2nd report
$ReportID = $ReportingObject->ReportCreate(
    DefinitionID => $DefinitionID,
    Config   => {
        OutputFormats => ['CSV']
    },
    UserID => 1,
);

$Self->True(
    $ReportID,
    'ReportCreate() - 2nd report',
);

@ReportList = $ReportingObject->ReportList(
    DefinitionID => $DefinitionID,
);

$Self->Is(
    scalar @ReportList,
    2,
    'ReportList()',
);

%ReportData = $ReportingObject->ReportGet(
    ID => $ReportID
);

$Self->True(
    IsHashRefWithData(\%ReportData),
    'ReportGet() - without results',
);

$Self->True(
    !IsArrayRefWithData($ReportData{Results}),
    'ReportGet() - no results in report data',
);

%ReportData = $ReportingObject->ReportGet(
    ID             => $ReportID,
    IncludeResults => 1,
);

$Self->True(
    IsHashRefWithData(\%ReportData),
    'ReportGet() - with results',
);

$Self->True(
    IsArrayRefWithData($ReportData{Results}),
    'ReportGet() - results contained in report data',
);

$Self->Is(
    scalar @{$ReportData{Results}},
    1,
    'ReportGet() - number of results',
);

my $Success = $ReportingObject->ReportDelete(
    ID => $ReportID,
);

$Self->True(
    $Success,
    'ReportDelete()',
);

my $Success = $ReportingObject->ReportDelete(
    ID => $ReportID + 1,
);

$Self->False(
    $Success,
    'ReportDelete() - non-existing ID',
);

my $Success = $ReportingObject->ReportDelete(
    ID => $ReportID + 1,
    Silent => 1,
);

$Self->False(
    $Success,
    'ReportDelete() - non-existing ID (silent)',
);

@ReportList = $ReportingObject->ReportList(
    DefinitionID => $DefinitionID,
);

$Self->Is(
    scalar @ReportList,
    1,
    'ReportList()',
);

# create a 3rd report with non-configured output format
$ReportID = $ReportingObject->ReportCreate(
    DefinitionID => $DefinitionID,
    Parameters   => {
        OutputFormats => ['PDF']
    },
    UserID => 1,
);

$Self->False(
    $ReportID,
    'ReportCreate() - 3rd report with non-configured output format',
);

# test parameters
$DefinitionID = $ReportingObject->ReportDefinitionAdd(
    DataSource => 'GenericSQL',
    Name       => 'Testreport with parameter',
    Config     => {
        DataSource => {
            SQL => {
                any => "SELECT id, name, change_time, change_by, create_time, create_by FROM valid WHERE name LIKE '\${Parameters.Name}%'"
            }
        },
        Parameters => [
            {
                Name => "Name",
                DataType => 'STRING',
                Required => 1,
            }
        ],
        OutputFormats => {
            CSV => {
                Columns => ['id', 'name', 'valid_id']
            },
        }
    },
    UserID => 1,
);

$Self->True(
    $DefinitionID,
    'ReportDefinitionAdd()',
);

$ReportID = $ReportingObject->ReportCreate(
    DefinitionID => $DefinitionID,
    Config       => {
        OutputFormats => ['CSV']
    },
    UserID => 1,
);

print STDERR "ReportID: $ReportID\n";

$Self->False(
    $ReportID,
    'ReportCreate() - with required parameter missing',
);

$ReportID = $ReportingObject->ReportCreate(
    DefinitionID => $DefinitionID,
    Config   => {
        Parameters => {
            Name => 'in'
        },
        OutputFormats => ['CSV']
    },
    UserID => 1,
);

$Self->True(
    $ReportID,
    'ReportCreate() - with required parameter',
);

# cleanup is done by RestoreDatabase

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
