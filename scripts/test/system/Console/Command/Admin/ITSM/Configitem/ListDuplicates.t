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

# get command object
my $CommandObject = $Kernel::OM->Get('Console::Command::Admin::ITSM::Configitem::ListDuplicates');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# silence console output
local *STDOUT;
local *STDERR;
open STDOUT, '>>', "/dev/null";
open STDERR, '>>', "/dev/null";

# check command without any options
my $ExitCode = $CommandObject->Execute();

$Self->Is(
    $ExitCode,
    0,
    "No options - list all config items in productive states",
);

# check command with --class options (invalid class)
my $RandomClass = 'NonExistingClass' . $Helper->GetRandomID();
$ExitCode = $CommandObject->Execute( '--class', $RandomClass );

$Self->Is(
    $ExitCode,
    1,
    "Option 'class' (but class $RandomClass doesn't exist) ",
);

# add test config item
my $GeneralCatalogObject = $Kernel::OM->Get('GeneralCatalog');

# get 'Hardware' catalog class IDs
my $ConfigItemDataRef = $GeneralCatalogObject->ItemGet(
    Class => 'ITSM::ConfigItem::Class',
    Name  => 'Hardware',
);
my $HardwareConfigItemID = $ConfigItemDataRef->{ItemID};

# get 'Production' deployment state IDs
my $ProductionDeplStateDataRef = $GeneralCatalogObject->ItemGet(
    Class => 'ITSM::ConfigItem::DeploymentState',
    Name  => 'Production',
);
my $ProductionDeplStateID = $ProductionDeplStateDataRef->{ItemID};

# get ConfigItem object
my $ConfigItemObject = $Kernel::OM->Get('ITSMConfigItem');

# create ConfigItem number
my $ConfigItemNumber = $ConfigItemObject->ConfigItemNumberCreate(
    Type    => $Kernel::OM->Get('Config')->Get('ITSMConfigItem::NumberGenerator'),
    ClassID => $HardwareConfigItemID,
);

my @ConfigItemID;

# add the new ConfigItem
my $ConfigItemID = $ConfigItemObject->ConfigItemAdd(
    Number  => $ConfigItemNumber,
    ClassID => $HardwareConfigItemID,
    UserID  => 1,
);
push @ConfigItemID, $ConfigItemID;

my $ConfigItemName = 'TestConfigItem' . $Helper->GetRandomID();
my $VersionID      = $ConfigItemObject->VersionAdd(
    Name         => $ConfigItemName,
    DefinitionID => 1,
    DeplStateID  => $ProductionDeplStateID,
    InciStateID  => 1,
    UserID       => 1,
    ConfigItemID => $ConfigItemID,
);

# add the new duplicate ConfigItem
$ConfigItemID = $ConfigItemObject->ConfigItemAdd(
    ClassID => $HardwareConfigItemID,
    UserID  => 1,
);
push @ConfigItemID, $ConfigItemID;

$VersionID = $ConfigItemObject->VersionAdd(
    Name         => $ConfigItemName,
    DefinitionID => 1,
    DeplStateID  => $ProductionDeplStateID,
    InciStateID  => 1,
    UserID       => 1,
    ConfigItemID => $ConfigItemID,
);

# add the new duplicate ConfigItem in Software catalog class
# get 'Software' catalog class IDs
$ConfigItemDataRef = $GeneralCatalogObject->ItemGet(
    Class => 'ITSM::ConfigItem::Class',
    Name  => 'Software',
);
my $SoftwareConfigItemID = $ConfigItemDataRef->{ItemID};

$ConfigItemID = $ConfigItemObject->ConfigItemAdd(
    ClassID => $SoftwareConfigItemID,
    UserID  => 1,
);
push @ConfigItemID, $ConfigItemID;

$VersionID = $ConfigItemObject->VersionAdd(
    Name         => $ConfigItemName,
    DefinitionID => 1,
    DeplStateID  => $ProductionDeplStateID,
    InciStateID  => 1,
    UserID       => 1,
    ConfigItemID => $ConfigItemID,
);

# check command with --class Hardware options
$ExitCode = $CommandObject->Execute( '--class', "Hardware" );

$Self->Is(
    $ExitCode,
    0,
    "Option 'class' (Hardware) ",
);

# check command with --scope options (invalid scope)
my $RandomScope = 'scope' . $Helper->GetRandomID();
$ExitCode = $CommandObject->Execute( '--scope', $RandomScope );

$Self->Is(
    $ExitCode,
    1,
    "Option 'scope' (but provided invalid value for option '--scope' - $RandomScope ) ",
);

# check command with --scope class options
$ExitCode = $CommandObject->Execute( '--scope', 'class' );

$Self->Is(
    $ExitCode,
    0,
    "Option 'scope' (class) ",
);

# check command with --scope global options
$ExitCode = $CommandObject->Execute( '--scope', 'global' );

$Self->Is(
    $ExitCode,
    0,
    "Option 'scope' (global) ",
);

# check command with --all-states options
$ExitCode = $CommandObject->Execute('--all-states');

$Self->Is(
    $ExitCode,
    0,
    "Option 'scope' (all-states) ",
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
