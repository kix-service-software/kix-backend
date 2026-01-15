# --
# Modified version of the work: Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/ 
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

my $CommandObject = $Kernel::OM->Get('Console::Command::Admin::ITSM::Configitem::Delete');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# silence console output
local *STDOUT;
local *STDERR;
open STDOUT, '>>', "/dev/null";
open STDERR, '>>', "/dev/null";

my $ExitCode = $CommandObject->Execute();

$Self->Is(
    $ExitCode,
    1,
    "Admin::ITSM::Configitem::Delete exit code without options",
);

# check command with option --all and argument --accept n ( cancel deleting all config item)
$ExitCode = $CommandObject->Execute( '--all', 'n' );
$Self->Is(
    $ExitCode,
    0,
    "Option '--all' n",
);

# check command with class options (invalid class)
my $RandomClass = 'TestClass' . $Helper->GetRandomID();
$ExitCode = $CommandObject->Execute( '--class', $RandomClass );
$Self->Is(
    $ExitCode,
    1,
    "Option 'class' (but class $RandomClass doesn't exist) ",
);

# add test general catalog item
my $ClassID = $Kernel::OM->Get('GeneralCatalog')->ItemAdd(
    Class   => 'ITSM::ConfigItem::Class',
    Name    => $RandomClass,
    ValidID => 1,
    Comment => 'Comment',
    UserID  => 1,
);
$Self->True(
    $ClassID,
    "Test class created",
);

# get 'Planned' deployment state IDs
my $PlannedDeplStateDataRef = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class => 'ITSM::ConfigItem::DeploymentState',
    Name  => 'Planned',
);
my $PlannedDeplStateID = $PlannedDeplStateDataRef->{ItemID};
$Self->True(
    $PlannedDeplStateID,
    "General catalog item for depl state 'Planned' exists",
);

# get 'Production' deployment state IDs
my $ProductionDeplStateDataRef = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class => 'ITSM::ConfigItem::DeploymentState',
    Name  => 'Production',
);
my $ProductionDeplStateID = $ProductionDeplStateDataRef->{ItemID};
$Self->True(
    $ProductionDeplStateID,
    "General catalog item for depl state 'Production' exists",
);

my @ConfigItemNumbers;
for my $AssetCount ( 1 .. 10 ) {
    # create ConfigItem number
    my $ConfigItemNumber = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemNumberCreate(
        ClassID => $ClassID,
    );

    # add test ConfigItem
    my $ConfigItemID = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
        Number  => $ConfigItemNumber,
        ClassID => $ClassID,
        UserID  => 1,
    );
    $Self->True(
        $ConfigItemID,
        "Asset $ConfigItemID created",
    );
    push( @ConfigItemNumbers, $ConfigItemNumber );

    VERSION:
    for my $VersionCount ( 1 .. 50 ) {
        my $VersionID = $Kernel::OM->Get('ITSMConfigItem')->VersionAdd(
            Name         => 'TestConfigItem-' . $AssetCount . '-' . $VersionCount,
            DefinitionID => 1,
            DeplStateID  => $AssetCount > 5 ? $ProductionDeplStateID : $PlannedDeplStateID,     # 5 assets with 'Planned' and 5 with 'Production'
            InciStateID  => 1,
            UserID       => 1,
            ConfigItemID => $ConfigItemID,
        );
        $Self->True(
            $VersionID,
            " Version $VersionCount created",
        );

        # discard config item object to process events
        $Kernel::OM->ObjectsDiscard( Objects => ['ITSMConfigItem'] );

        # change the date into past for the first 10 versions
        next VERSION if ( $VersionCount > 10 );

        # insert new version
        my $Success = $Kernel::OM->Get('DB')->Do(
            SQL => 'UPDATE configitem_version
                SET create_time = \'2010-01-01 00:00:00\'
                WHERE id = ?',
            Bind => [
                \$VersionID,
            ],
        );
    }

    # get the list of versions of this config item
    my $VersionList = $Kernel::OM->Get('ITSMConfigItem')->VersionList(
        ConfigItemID => $ConfigItemID,
    );
    $Self->Is(
        scalar @{$VersionList},
        50,
        'Initial version count',
    );

    # prepare tests
    my @VersionTests = (
        {
            Options => [ '--all-older-than-days-versions', 1 ],
            Count   => 40
        },
        {
            Options => [ '--all-but-keep-last-versions', 30 ],
            Count   => 30
        },
        {
            Options => [ '--all-old-versions' ],
            Count   => 1
        }
    );

    # only for first asset
    if ( $AssetCount == 1 ) {
        # check failed execution with missing asset selection option
        for my $Test ( @VersionTests ) {
            $ExitCode = $CommandObject->Execute( @{ $Test->{Options} } );
            $Self->Is(
                $ExitCode,
                1,
                'Exit code: Options "' . join( ' ', @{ $Test->{Options} } ) . '"',
            );

            $VersionList = $Kernel::OM->Get('ITSMConfigItem')->VersionList(
                ConfigItemID => $ConfigItemID,
            );
            $Self->Is(
                scalar @{$VersionList},
                50,
                'Version count: Options "' . join( ' ', @{ $Test->{Options} } ) . '"',
            );
        }

        # check failed execution with deployment-state but without class
        $ExitCode = $CommandObject->Execute( '--all', '--deployment-state', 'Planned' );
        $Self->Is(
            $ExitCode,
            1,
            'Exit code: Options "--all --deployment-state Planned"',
        );

        $VersionList = $Kernel::OM->Get('ITSMConfigItem')->VersionList(
            ConfigItemID => $ConfigItemID,
        );
        $Self->Is(
            scalar @{$VersionList},
            50,
            'Version count: Options "--all --deployment-state Planned"',
        );
    }

    my @AssetSelectionOptions;
    if ( $AssetCount > 8 ) {
        @AssetSelectionOptions = ( '--all' );
    }
    elsif ( $AssetCount > 6 ) {
        @AssetSelectionOptions = ( '--class', $RandomClass );
    }
    elsif ( $AssetCount > 4 ) {
        @AssetSelectionOptions = ( '--class', $RandomClass, '--deployment-state', $AssetCount > 5 ? 'Production' : 'Planned' );
    }
    else {
        @AssetSelectionOptions = ( '--asset-number', $ConfigItemNumber );
    }

    for my $Test ( @VersionTests ) {
        my @Options = (
            @AssetSelectionOptions,  @{ $Test->{Options} }
        );

        $ExitCode = $CommandObject->Execute( @Options );
        $Self->Is(
            $ExitCode,
            0,
            'Exit code: Options "' . join( ' ', @Options ) . '"',
        );

        # discard config item object to process events
        $Kernel::OM->ObjectsDiscard( Objects => ['ITSMConfigItem'] );

        $VersionList = $Kernel::OM->Get('ITSMConfigItem')->VersionList(
            ConfigItemID => $ConfigItemID,
        );
        $Self->Is(
            scalar @{$VersionList},
            $Test->{Count},
            'Version count: Options "' . join( ' ', @Options ) . '"',
        );
    }
}


my $AssetCount = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'ConfigItem',
    Search     => {
        AND => [
            {
                Field    => 'ClassID',
                Operator => 'IN',
                Type     => 'NUMERIC',
                Value    => [ $ClassID ]
            }
        ]
    },
    UserID   => 1,
    UserType => 'Agent',
    Result   => 'COUNT',
);
$Self->Is(
    $AssetCount,
    10,
    'Initial asset count',
);

# prepare tests
my @AssetTests = (
    {
        Options => [ '--asset-number', $ConfigItemNumbers[0], '--asset-number', $ConfigItemNumbers[1] ],
        Count   => 8
    },
    {
        Options => [ '--class', $RandomClass, '--deployment-state', 'Planned', 'y' ],
        Count   => 5
    },
    {
        Options => [ '--all', 'y' ],
        Count   => 0
    }
);

for my $Test ( @AssetTests ) {
    $ExitCode = $CommandObject->Execute( @{ $Test->{Options} } );
    $Self->Is(
        $ExitCode,
        0,
        'Exit code: Options "' . join( ' ', @{ $Test->{Options} } ) . '"',
    );

    # discard config item object to process events
    $Kernel::OM->ObjectsDiscard( Objects => ['ITSMConfigItem'] );

    $AssetCount = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'ConfigItem',
        Search     => {
            AND => [
                {
                    Field    => 'ClassID',
                    Operator => 'IN',
                    Type     => 'NUMERIC',
                    Value    => [ $ClassID ]
                }
            ]
        },
        UserID   => 1,
        UserType => 'Agent',
        Result   => 'COUNT',
    );
    $Self->Is(
        $AssetCount,
        $Test->{Count},
        'Asset count: Options "' . join( ' ', @{ $Test->{Options} } ) . '"',
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


