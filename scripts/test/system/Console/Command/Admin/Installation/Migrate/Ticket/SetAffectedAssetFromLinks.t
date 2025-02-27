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

use vars (qw($Self));

use Kernel::System::VariableCheck qw(:all);

# get command object
my $CommandObject = $Kernel::OM->Get('Console::Command::Admin::Installation::Migrate::Ticket::SetAffectedAssetFromLinks');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# silence console output
local *STDOUT;
local *STDERR;
open STDOUT, '>>', "/dev/null";
open STDERR, '>>', "/dev/null";


my $DynamicFieldConfig = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
    Name   => 'AffectedAsset',
    UserID => 1
);

$Self->True(
    IsHashRefWithData($DynamicFieldConfig),
    'Get dynamic field "AffectedAsset"'
);

# check command without any options
my $ExitCode = $CommandObject->Execute();

$Self->Is(
    $ExitCode,
    0,
    "Execute: Run without tickets and assets.",
);
my $OverMax = $DynamicFieldConfig->{Config}->{CountMax} + 5;

my @TestData = (
    {
        Create => {
            Ticket => 1,
        },
        Name     => 'Create 1 Ticket / Link 0 Asset / Linked 0',
        Expected => 0
    },
    {
        Create => {
            Ticket => 1,
            Assets => 2
        },
        Name     => 'Create 1 Ticket / Link 2 Asset / Linked 2',
        Expected => 2
    },
    {
        Create => {
            Ticket       => 1,
            Assets       => 8
        },
        Include => {
            Assets => 2
        },
        Name     => 'Create 1 Ticket + 2 AffectedAssets / Link 8 Asset / Linked 10',
        Expected => 10
    },
    {
        Create => {
            Ticket => 1,
            Assets => 15
        },
        Name     => 'Create 1 Ticket / Link 15 Asset / Linked 15',
        Expected => 15
    },
    {
        Create => {
            Ticket => 1,
            Assets => $OverMax
        },
        Name     => "Create 1 Ticket / Link $OverMax Asset (over Default $DynamicFieldConfig->{Config}->{CountMax}) / Linked $OverMax",
        Expected => $OverMax
    }
);

for my $Test ( @TestData ) {
    my $TicketID;
    if ( $Test->{Create}->{Ticket} ) {
        $TicketID = _CreateTicket();

        if ( $Test->{Include}->{Assets} ) {
            _CreateAssets(
                ObjectID => $TicketID,
                AddTo    => 'DynamicField',
                Count    => $Test->{Include}->{Assets}
            );
        }
    }

    if ( $Test->{Create}->{Assets} ) {
        _CreateAssets(
            ObjectID => $TicketID,
            AddTo    => 'Ticket',
            Count    => $Test->{Create}->{Assets}
        );
    }

    # cleanup ticket cache for objectsearch
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => 'ObjectSearch_Ticket'
    );

    # check command without any options
    $ExitCode = $CommandObject->Execute();

    $Self->Is(
        $ExitCode,
        0,
        "Execute: $Test->{Name}"
    );

    my $DynamicFieldValue = $Kernel::OM->Get('DynamicField::Backend')->ValueGet(
        DynamicFieldConfig => $DynamicFieldConfig,
        ObjectID           => $TicketID
    );

    $Self->Is(
        scalar(@{$DynamicFieldValue}),
        $Test->{Expected},
        "Result: $Test->{Name}"
    );
}

sub _CreateTicket {
    my ( %Param ) = @_;

    # create ticket
    my $ID = $Kernel::OM->Get('Ticket')->TicketCreate(
        Title          => $Helper->GetRandomID(),
        QueueID        => 1,
        Lock           => 'unlock',
        PriorityID     => 1,
        StateID        => 1,
        TypeID         => 1,
        OrganisationID => 1,
        ContactID      => 1,
        OwnerID        => 1,
        ResponsibleID  => 1,
        UserID         => 1
    );
    $Self->True(
        $ID,
        'Created ticket'
    );

    # discard ticket object to process events
    $Kernel::OM->ObjectsDiscard(
        Objects => ['Ticket'],
    );

    return $ID;
}

sub _CreateAssets {
    my ( %Param ) = @_;

    ## prepare test assets ##
    # prepare class mapping
    my $ClassRef = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
        Class         => 'ITSM::ConfigItem::Class',
        Name          => 'Computer',
        NoPreferences => 1
    );

    # prepare depl state mapping
    my $DeplStateRef = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
        Class => 'ITSM::ConfigItem::DeploymentState',
        Name  => 'Production',
    );

    # prepare inci state mapping
    my $ItemDataRef = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
        Class         => 'ITSM::Core::IncidentState',
        Name          => 'Operational',
        NoPreferences => 1
    );

    my @ConfigItemIDs;
    for my $Index ( 1 .. $Param{Count} ) {

        # create asset
        my $ConfigItemID = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
            ClassID => $ClassRef->{ItemID},
            UserID  => 1,
        );
        $Self->True(
            $ConfigItemID,
            "Created #$Index asset"
        );
        my $VersionID = $Kernel::OM->Get('ITSMConfigItem')->VersionAdd(
            ConfigItemID => $ConfigItemID,
            Name         => $Helper->GetRandomID(),
            DefinitionID => 1,
            DeplStateID  => $DeplStateRef->{ItemID},
            InciStateID  => $ItemDataRef->{ItemID},
            UserID       => 1,
        );
        $Self->True(
            $VersionID,
            "Created version for #$Index asset"
        );

        push(
            @ConfigItemIDs,
            $ConfigItemID
        );
    }

    if ( $Param{AddTo} eq 'DynamicField' ) {
        $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
            DynamicFieldConfig => $DynamicFieldConfig,
            ObjectID           => $Param{ObjectID},
            Value              => \@ConfigItemIDs,
            UserID             => 1
        );
    }

    if ( $Param{AddTo} eq 'Ticket' ) {
        for my $ID ( @ConfigItemIDs ) {
            my $LinkID = $Kernel::OM->Get('LinkObject')->LinkAdd(
                SourceObject => 'Ticket',
                SourceKey    => $Param{ObjectID},
                TargetObject => 'ConfigItem',
                TargetKey    => $ID,
                Type         => 'Normal',
                UserID       => 1,
            );

            $Self->True(
                $LinkID,
                "Linked ($LinkID) asset to ticket"
            );
        }
    }

    # discard ITSMConfigItem object to process events
    $Kernel::OM->ObjectsDiscard(
        Objects => ['ITSMConfigItem','LinkObject','DynamicField::Backend'],
    );

    return 1;
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
