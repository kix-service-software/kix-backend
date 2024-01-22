# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
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
use File::Path qw(rmtree);

# get needed objects
my $CommandObject      = $Kernel::OM->Get('Console::Command::Admin::ITSM::ImportExport::Import');
my $ImportExportObject = $Kernel::OM->Get('ImportExport');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# silence console output
local *STDOUT;
local *STDERR;
open STDOUT, '>>', "/dev/null";
open STDERR, '>>', "/dev/null";

# test command without --template-number option
my $ExitCode = $CommandObject->Execute();

$Self->Is(
    $ExitCode,
    1,
    "No --template-number  - exit code",
);

# add test template
my $TemplateID = $ImportExportObject->TemplateAdd(
    Object  => 'ITSMConfigItem',
    Format  => 'CSV',
    Name    => 'Template' . $Helper->GetRandomID(),
    ValidID => 1,
    Comment => 'Comment',
    UserID  => 1,
);

$Self->True(
    $TemplateID,
    "Import/Export template is created - $TemplateID",
);

# get 'Hardware' catalog class ID
my $ConfigItemDataRef = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class => 'ITSM::ConfigItem::Class',
    Name  => 'Hardware',
);
my $HardwareConfigItemID = $ConfigItemDataRef->{ItemID};

# get object data for test template
my %TemplateRef = (
    'ClassID'  => $HardwareConfigItemID,
    'CountMax' => 10,
);
my $Success = $ImportExportObject->ObjectDataSave(
    TemplateID => $TemplateID,
    ObjectData => \%TemplateRef,
    UserID     => 1,
);

$Self->True(
    $Success,
    "ObjectData for test template is added",
);

# add the format data of the test template
my %FormatData = (
    Charset              => 'UTF-8',
    ColumnSeparator      => 'Comma',
    IncludeColumnHeaders => 1,
);
$Success = $ImportExportObject->FormatDataSave(
    TemplateID => $TemplateID,
    FormatData => \%FormatData,
    UserID     => 1,
);

$Self->True(
    $Success,
    "FormatData for test template is added",
);

# save the search data of a template
my %SearchData = (
    Name => 'TestConfigItem*',
);
$Success = $ImportExportObject->SearchDataSave(
    TemplateID => $TemplateID,
    SearchData => \%SearchData,
    UserID     => 1,
);

# add mapping data for test template
for my $ObjectDataValue (qw( Name DeplState InciState )) {

    my $MappingID = $ImportExportObject->MappingAdd(
        TemplateID => $TemplateID,
        UserID     => 1,
    );

    my %MappingObjectData = ( Key => $ObjectDataValue );
    my $InnerSuccess = $ImportExportObject->MappingObjectDataSave(
        MappingID         => $MappingID,
        MappingObjectData => \%MappingObjectData,
        UserID            => 1,
    );

    $Self->True(
        $InnerSuccess,
        "ObjectData for test template is mapped - $ObjectDataValue",
    );
}

# make directory for export file
my $SourcePath  = $Kernel::OM->Get('Config')->Get('Home')
    . "/scripts/test/system/sample/ImportExport/TemplateExport.csv";

# test command with wrong template number
$ExitCode = $CommandObject->Execute( '--template-number', $Helper->GetRandomID(), $SourcePath );

$Self->Is(
    $ExitCode,
    1,
    "Command with wrong template number - exit code",
);

# test command without Source argument
$ExitCode = $CommandObject->Execute( '--template-number', $TemplateID );

$Self->Is(
    $ExitCode,
    1,
    "No Source argument - exit code",
);

# test command with --template-number option and Source argument
$ExitCode = $CommandObject->Execute( '--template-number', $TemplateID, $SourcePath );

$Self->Is(
    $ExitCode,
    0,
    "Option - --template-number option and Source argument",
);

# get config item IDs
my @ConfigItemIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'ConfigItem',
    Result     => 'ARRAY',
    Search     => {
        AND => [
            {
                Field    => 'Name',
                Operator => 'STARTSWITH',
                Type     => 'STRING',
                Value    => 'TestConfigItem'
            }
        ]
    },
    UserID     => 1,
    UserType   => 'Agent'
);
my $NumConfigItemImported = scalar @ConfigItemIDs;

# check if the config items are imported
$Self->True(
    $NumConfigItemImported,
    "There are $NumConfigItemImported imported config items",
);

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
