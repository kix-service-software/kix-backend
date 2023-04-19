# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;

use vars qw($Self);
use Kernel::System::VariableCheck qw(:all);

use Kernel::System::PostMaster;

# get needed objects for rollback
my $QueueObject = $Kernel::OM->Get('Queue');
my $StateObject = $Kernel::OM->Get('State');
my $TimeObject  = $Kernel::OM->Get('Time');
my $TypeObject  = $Kernel::OM->Get('Type');
my $ContactObject      = $Kernel::OM->Get('Contact');
my $UserObject         = $Kernel::OM->Get('User');

# get actual needed objects
my $ConfigObject       = $Kernel::OM->Get('Config');
my $TicketObject       = $Kernel::OM->Get('Ticket');
my $DynamicFieldObject = $Kernel::OM->Get('DynamicField');
my $MainObject         = $Kernel::OM->Get('Main');
my $ConfigItemObject   = $Kernel::OM->Get('ITSMConfigItem');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my @CreatedDynamicFieldIDs;
my @UpdatedDynamicFields;
my %NeededDynamicfields = (
    AffectedAsset  => 1,
    SysMonXAlias   => 1,
    SysMonXAddress => 1,
    SysMonXHost    => 1,
    SysMonXService => 1,
    SysMonXState   => 1
);

# prepare config items and dynamic fields
my $HostConfigItemID;
my $ServiceConfigItemID;
_PrepareData();

# first mail - should create new ticket
my $FirstData = _ReadFile(
    File => 'CMDBSysMon_MailA01.box'
);
if (
    IsHashRefWithData($FirstData) &&
    $FirstData->{TicketID} &&
    IsArrayRefWithData( $FirstData->{FileArray} )
) {

    # get some data with regex like default config
    my $Host    = '';
    my $Address = '';
    my $State   = '';
    for my $Line ( @{ $FirstData->{FileArray} } ) {
        if ( $Line =~ /\s*Host:\s+(.*)\s*/ ) {
            $Host = $1;
            next;
        }
        if ( $Line =~ /\s*Address:\s+(.*)\s*/ ) {
            $Address = $1;
            next;
        }
        if ( $Line =~ /\s*State:\s+(\S+)/ ) {
            $State = $1;
            next;
        }
    }

    my %FirstTicket = $TicketObject->TicketGet(
        TicketID      => $FirstData->{TicketID},
        DynamicFields => 1,
    );

    $Self->ContainedIn(
        $Host,
        $FirstTicket{DynamicField_SysMonXHost},
        'Host check',
    );
    $Self->ContainedIn(
        'Host',
        $FirstTicket{DynamicField_SysMonXService},
        'Service check',
    );
    $Self->ContainedIn(
        $Address,
        $FirstTicket{DynamicField_SysMonXAddress},
        'Address check',
    );
    $Self->ContainedIn(
        $State,
        $FirstTicket{DynamicField_SysMonXState},
        'State check',
    );
    # check explicit for DOWN
    $Self->ContainedIn(
        'DOWN',
        $FirstTicket{DynamicField_SysMonXState},
        'State check (DOWN)',
    );
    $Self->ContainedIn(
        $HostConfigItemID,
        $FirstTicket{DynamicField_AffectedAsset},
        'Affected asset check',
    );

    $Self->Is(
        $FirstTicket{State},
        'new',
        'Ticket State check',
    );

    # second mail - should append article to new ticket
    my $SecondData = _ReadFile(
        File             => 'CMDBSysMon_MailA02.box',
        PostMasterResult => 2
    );
    if (
        IsHashRefWithData($SecondData) &&
        $SecondData->{TicketID} &&
        IsArrayRefWithData( $SecondData->{FileArray} )
    ) {
        $Self->Is(
            $SecondData->{TicketID},
            $FirstData->{TicketID},
            'TicketID of second mail belongs to first ticket',
        );

        my @ArticleIndex = $TicketObject->ArticleIndex(
            TicketID        => $SecondData->{TicketID},
            UserID          => 1,
        );
        $Self->Is(
            (scalar @ArticleIndex),
            2,
            'Second mail appended as article',
        );

    }

    # third mail - should append article to new ticket, close it and set 'UP' state
    my $ThirdData = _ReadFile(
        File             => 'CMDBSysMon_MailA03.box',
        PostMasterResult => 2
    );
    if (
        IsHashRefWithData($ThirdData) &&
        $ThirdData->{TicketID} &&
        IsArrayRefWithData( $ThirdData->{FileArray} )
    ) {
        $Self->Is(
            $ThirdData->{TicketID},
            $FirstData->{TicketID},
            'TicketID of third mail belongs to first ticket',
        );

        my @ArticleIndex = $TicketObject->ArticleIndex(
            TicketID        => $ThirdData->{TicketID},
            UserID          => 1,
        );
        $Self->Is(
            (scalar @ArticleIndex),
            3,
            'Third mail appended as article',
        );

        # get some data with regex like default config
        my $Host    = '';
        my $Address = '';
        my $State   = '';
        for my $Line ( @{ $ThirdData->{FileArray} } ) {
            if ( $Line =~ /\s*State:\s+(\S+)/ ) {
                $State = $1;
                next;
            }
        }

        my %Ticket = $TicketObject->TicketGet(
            TicketID      => $ThirdData->{TicketID},
            DynamicFields => 1,
        );

        $Self->ContainedIn(
            $State,
            $Ticket{DynamicField_SysMonXState},
            'State check',
        );
        # check explicit for UP
        $Self->ContainedIn(
            'UP',
            $Ticket{DynamicField_SysMonXState},
            'State check (UP)',
        );

        $Self->Is(
            $Ticket{State},
            'closed',
            'Ticket State check',
        );
    }

    # 4th mail - should be dropped/ignored
    my $FourthData = _ReadFile(
        File             => 'CMDBSysMon_MailA04.box',
        PostMasterResult => 5,
        IgnoreTicket     => 1
    );
    $Self->False(
        $FourthData->{TicketID},
        'No TicketID of 4th mail',
    );

    # 5th mail - new DOWN ticket
    my $FifthData = _ReadFile(
        File             => 'CMDBSysMon_MailB05.box',
        PostMasterResult => 1
    );
    if (
        IsHashRefWithData($FifthData) &&
        $FifthData->{TicketID} &&
        IsArrayRefWithData( $FifthData->{FileArray} )
    ) {
        $Self->IsNot(
            $FifthData->{TicketID},
            $FirstData->{TicketID},
            'TicketID of 5th mail is not equal to first ticket',
        );

        # get some data with regex like default config
        my $Host    = '';
        my $Address = '';
        my $State   = '';
        for my $Line ( @{ $FifthData->{FileArray} } ) {
            if ( $Line =~ /\s*Host:\s+(.*)\s*/ ) {
                $Host = $1;
                next;
            }
            if ( $Line =~ /\s*Address:\s+(.*)\s*/ ) {
                $Address = $1;
                next;
            }
            if ( $Line =~ /\s*State:\s+(\S+)/ ) {
                $State = $1;
                next;
            }
        }

        my %Ticket = $TicketObject->TicketGet(
            TicketID      => $FifthData->{TicketID},
            DynamicFields => 1,
        );

        $Self->ContainedIn(
            $Host,
            $Ticket{DynamicField_SysMonXHost},
            'Host check',
        );
        $Self->ContainedIn(
            'Host',
            $Ticket{DynamicField_SysMonXService},
            'Service check',
        );
        $Self->ContainedIn(
            $Address,
            $Ticket{DynamicField_SysMonXAddress},
            'Address check',
        );
        $Self->ContainedIn(
            $State,
            $Ticket{DynamicField_SysMonXState},
            'State check',
        );
        # check explicit for DOWN
        $Self->ContainedIn(
            'DOWN',
            $Ticket{DynamicField_SysMonXState},
            'State check (DOWN)',
        );
        $Self->ContainedIn(
            $HostConfigItemID,
            $Ticket{DynamicField_AffectedAsset},
            'Affected asset check',
        );

        $Self->Is(
            $Ticket{State},
            'new',
            'Ticket State check',
        );
    }

    # 6th mail - new DOWN ticket, without affected asset
    my $SixthData = _ReadFile(
        File             => 'CMDBSysMon_MailC06.box',
        PostMasterResult => 1
    );
    if (
        IsHashRefWithData($SixthData) &&
        $SixthData->{TicketID} &&
        IsArrayRefWithData( $SixthData->{FileArray} )
    ) {
        $Self->IsNot(
            $SixthData->{TicketID},
            $FirstData->{TicketID},
            'TicketID of 6th mail is not equal to first ticket',
        );
        $Self->IsNot(
            $SixthData->{TicketID},
            $FifthData->{TicketID},
            'TicketID of 6th mail is not equal to ticket of 5th mail',
        );

        # get some data with regex like default config
        my $Host    = '';
        my $Address = '';
        my $State   = '';
        for my $Line ( @{ $SixthData->{FileArray} } ) {
            if ( $Line =~ /\s*Host:\s+(.*)\s*/ ) {
                $Host = $1;
                next;
            }
            if ( $Line =~ /\s*Address:\s+(.*)\s*/ ) {
                $Address = $1;
                next;
            }
            if ( $Line =~ /\s*State:\s+(\S+)/ ) {
                $State = $1;
                next;
            }
        }

        my %Ticket = $TicketObject->TicketGet(
            TicketID      => $SixthData->{TicketID},
            DynamicFields => 1,
        );

        $Self->ContainedIn(
            $Host,
            $Ticket{DynamicField_SysMonXHost},
            'Host check',
        );
        $Self->ContainedIn(
            'Host',
            $Ticket{DynamicField_SysMonXService},
            'Service check',
        );
        $Self->ContainedIn(
            $Address,
            $Ticket{DynamicField_SysMonXAddress},
            'Address check',
        );
        $Self->ContainedIn(
            $State,
            $Ticket{DynamicField_SysMonXState},
            'State check',
        );
        # check explicit for DOWN
        $Self->ContainedIn(
            'DOWN',
            $Ticket{DynamicField_SysMonXState},
            'State check (DOWN)',
        );
        # no affected asset
        $Self->False(
            IsArrayRefWithData($Ticket{DynamicField_AffectedAsset}) || 0,
            'Affected asset check',
        );

        $Self->Is(
            $Ticket{State},
            'new',
            'Ticket State check',
        );
    }

    # 7th mail - new DOWN ticket, with first found affected asset
    my $SeventhData = _ReadFile(
        File             => 'CMDBSysMon_MailD07.box',
        PostMasterResult => 1
    );
    if (
        IsHashRefWithData($SeventhData) &&
        $SeventhData->{TicketID} &&
        IsArrayRefWithData( $SeventhData->{FileArray} )
    ) {
        $Self->IsNot(
            $SeventhData->{TicketID},
            $FirstData->{TicketID},
            'TicketID of 7th mail is not equal to first ticket',
        );
        $Self->IsNot(
            $SeventhData->{TicketID},
            $FifthData->{TicketID},
            'TicketID of 7th mail is not equal to ticket of 5th mail',
        );
        $Self->IsNot(
            $SeventhData->{TicketID},
            $SixthData->{TicketID},
            'TicketID of 7th mail is not equal to ticket of 6th mail',
        );

        # get some data with regex like default config
        my $Host    = '';
        my $Address = '';
        my $State   = '';
        for my $Line ( @{ $SeventhData->{FileArray} } ) {
            if ( $Line =~ /\s*Host:\s+(.*)\s*/ ) {
                $Host = $1;
                next;
            }
            if ( $Line =~ /\s*Address:\s+(.*)\s*/ ) {
                $Address = $1;
                next;
            }
            if ( $Line =~ /\s*State:\s+(\S+)/ ) {
                $State = $1;
                next;
            }
        }

        my %Ticket = $TicketObject->TicketGet(
            TicketID      => $SeventhData->{TicketID},
            DynamicFields => 1,
        );

        $Self->ContainedIn(
            $Host,
            $Ticket{DynamicField_SysMonXHost},
            'Host check',
        );
        $Self->ContainedIn(
            'Host',
            $Ticket{DynamicField_SysMonXService},
            'Service check',
        );
        $Self->ContainedIn(
            $Address,
            $Ticket{DynamicField_SysMonXAddress},
            'Address check',
        );
        $Self->ContainedIn(
            $State,
            $Ticket{DynamicField_SysMonXState},
            'State check',
        );
        # check explicit for DOWN
        $Self->ContainedIn(
            'DOWN',
            $Ticket{DynamicField_SysMonXState},
            'State check (DOWN)',
        );
        # one affected asset
        $Self->True(
            IsArrayRefWithData($Ticket{DynamicField_AffectedAsset}) || 0,
            'Affected asset check (is set?)',
        );

        if (IsArrayRefWithData($Ticket{DynamicField_AffectedAsset}) && $Host) {
            my $ConfigItemIDs = $ConfigItemObject->ConfigItemSearchExtended(
                Name => $Host,
            );
            $Self->True(
                IsArrayRefWithData($ConfigItemIDs) || 0,
                'Affected asset found',
            );

            if (IsArrayRefWithData($ConfigItemIDs)) {
                $Self->Is(
                    (scalar @{$ConfigItemIDs}),
                    3,
                    'Affected asset found (length)',
                );

                # first found should be affected asset
                $Self->ContainedIn(
                    $ConfigItemIDs->[0],
                    $Ticket{DynamicField_AffectedAsset},
                    'Affected asset check',
                );
            }

        }

        $Self->Is(
            $Ticket{State},
            'new',
            'Ticket State check',
        );
    }

    # 8th mail - new DOWN ticket, no config item found for host so use default service from config
    $ConfigObject->Set(
        Key   => 'PostMaster::PreFilterModule',
        Value => {
            # just set DefaultService (second created config item), for other attributes use default
            '0000-SystemMonitoring-Test' => {
                Module         => 'Kernel::System::PostMaster::Filter::SystemMonitoringX',
                DefaultService => 'someService'
            }
        },
    );
    my $PreFilterList = $ConfigObject->Get('PostMaster::PreFilterModule');
    $Self->True(
        IsHashRefWithData($PreFilterList) || 0,
        "PostMaster::PreFilterModule is given",
    );
    $Self->True(
        IsHashRefWithData($PreFilterList->{'0000-SystemMonitoring-Test'}) || 0,
        "Test config is set",
    );
    my $EighthData = _ReadFile(
        File             => 'CMDBSysMon_MailE08.box',
        PostMasterResult => 1
    );
    if (
        IsHashRefWithData($EighthData) &&
        $EighthData->{TicketID} &&
        IsArrayRefWithData( $EighthData->{FileArray} )
    ) {
        $Self->IsNot(
            $EighthData->{TicketID},
            $FirstData->{TicketID},
            'TicketID of 8th mail is not equal to first ticket',
        );
        $Self->IsNot(
            $EighthData->{TicketID},
            $FifthData->{TicketID},
            'TicketID of 8th mail is not equal to ticket of 5th mail',
        );
        $Self->IsNot(
            $EighthData->{TicketID},
            $SixthData->{TicketID},
            'TicketID of 8th mail is not equal to ticket of 6th mail',
        );
        $Self->IsNot(
            $EighthData->{TicketID},
            $SeventhData->{TicketID},
            'TicketID of 8th mail is not equal to ticket of 7th mail',
        );

        # get some data with regex like default config
        my $Host    = '';
        my $Address = '';
        my $State   = '';
        for my $Line ( @{ $EighthData->{FileArray} } ) {
            if ( $Line =~ /\s*Host:\s+(.*)\s*/ ) {
                $Host = $1;
                next;
            }
            if ( $Line =~ /\s*Address:\s+(.*)\s*/ ) {
                $Address = $1;
                next;
            }
            if ( $Line =~ /\s*State:\s+(\S+)/ ) {
                $State = $1;
                next;
            }
        }

        my %Ticket = $TicketObject->TicketGet(
            TicketID      => $EighthData->{TicketID},
            DynamicFields => 1,
        );

        $Self->ContainedIn(
            $Host,
            $Ticket{DynamicField_SysMonXHost},
            'Host check',
        );
        # other default from new config
        $Self->ContainedIn(
            'someService',
            $Ticket{DynamicField_SysMonXService},
            'Service check',
        );
        $Self->ContainedIn(
            $Address,
            $Ticket{DynamicField_SysMonXAddress},
            'Address check',
        );
        $Self->ContainedIn(
            $State,
            $Ticket{DynamicField_SysMonXState},
            'State check',
        );
        # check explicit for DOWN
        $Self->ContainedIn(
            'DOWN',
            $Ticket{DynamicField_SysMonXState},
            'State check (DOWN)',
        );
        # check affected asset
        $Self->ContainedIn(
            $ServiceConfigItemID,
            $Ticket{DynamicField_AffectedAsset},
            'Affected asset check',
        );

        $Self->Is(
            $Ticket{State},
            'new',
            'Ticket State check',
        );
    }

    # delete tickets, to prevent some errors on rollback (config item update)
    $TicketObject->TicketDelete(
        TicketID => $FirstData->{TicketID},
        UserID   => 1,
    );
    $TicketObject->TicketDelete(
        TicketID => $FifthData->{TicketID},
        UserID   => 1,
    );
    $TicketObject->TicketDelete(
        TicketID => $SixthData->{TicketID},
        UserID   => 1,
    );
    $TicketObject->TicketDelete(
        TicketID => $SeventhData->{TicketID},
        UserID   => 1,
    );
    $TicketObject->TicketDelete(
        TicketID => $EighthData->{TicketID},
        UserID   => 1,
    );

}

# revert changes to dynamic fields
for my $DynamicField (@UpdatedDynamicFields) {
    my $SuccessUpdate = $DynamicFieldObject->DynamicFieldUpdate(
        Reorder => 0,
        UserID  => 1,
        %{$DynamicField},
    );
    $Self->True(
        $SuccessUpdate,
        "Reverted changes on ValidID for $DynamicField->{Name} field.",
    );
}
for my $DynamicFieldID (@CreatedDynamicFieldIDs) {
    my $FieldDelete = $DynamicFieldObject->DynamicFieldDelete(
        ID     => $DynamicFieldID,
        UserID => 1,
    );
    $Self->True(
        $FieldDelete,
        "Deleted dynamic field with id $DynamicFieldID.",
    );
}

sub _ReadFile {
    my ( %Param ) = @_;

    my $FileArray = $MainObject->FileRead(
        Location => $ConfigObject->Get('Home') . '/scripts/test/system/sample/SystemMonitoringX/' . $Param{File},
        Result => 'ARRAY'
    );
    $Self->True(
        IsArrayRefWithData($FileArray) || 0,
        'File read (' . $Param{File} . ')',
    );
    return {} if (!IsArrayRefWithData($FileArray));

    my $PostMasterObject = Kernel::System::PostMaster->new(
        %{$Self},
        Email => $FileArray
    );

    my @PostMasterResult = $PostMasterObject->Run();
    @PostMasterResult = @{ $PostMasterResult[0] || [] };

    $Self->Is(
        $PostMasterResult[0] || 0,
        ($Param{PostMasterResult} || 1),
        'Postmaster run successfull',
    );
    return {} if (!IsArrayRefWithData(\@PostMasterResult));

    if (!$Param{IgnoreTicket}) {
        $Self->True(
            $PostMasterResult[1] || 0,
            'TicketID (' . ($PostMasterResult[1] || 0) . ')',
        );
    }

    return {
        TicketID  => ($PostMasterResult[1] || 0),
        FileArray => $FileArray
    };
}

sub _PrepareData {

    # list available dynamic fields
    my $DynamicFields = $DynamicFieldObject->DynamicFieldList(
        Valid      => 0,
        ResultType => 'HASH',
    );
    $DynamicFields = IsHashRefWithData($DynamicFields) ? $DynamicFields : {};
    $DynamicFields = { reverse %{$DynamicFields} };

    for my $FieldName ( sort keys %NeededDynamicfields ) {
        if ( !$DynamicFields->{$FieldName} ) {

            # create a dynamic field
            my $FieldID = $DynamicFieldObject->DynamicFieldAdd(
                Name       => $FieldName,
                Label      => $FieldName . "_test",
                FieldOrder => 9991,
                FieldType  => 'Text',
                ObjectType => 'Ticket',
                Config     => {
                    DefaultValue => 'a value',
                },
                ValidID => 1,
                UserID  => 1,
            );

            # verify dynamic field creation
            $Self->True(
                $FieldID,
                "DynamicFieldAdd() successful for Field $FieldName",
            );

            push(@CreatedDynamicFieldIDs, $FieldID);
        } else {
            my $DynamicField = $DynamicFieldObject->DynamicFieldGet( ID => $DynamicFields->{$FieldName} );

            if ( $DynamicField->{ValidID} > 1 ) {
                push(@UpdatedDynamicFields, $DynamicField);
                $DynamicField->{ValidID} = 1;
                my $SuccessUpdate = $DynamicFieldObject->DynamicFieldUpdate(
                    %{$DynamicField},
                    Reorder => 0,
                    UserID  => 1,
                    ValidID => 1,
                );

                # verify dynamic field creation
                $Self->True(
                    $SuccessUpdate,
                    "DynamicFieldUpdate() successful update for Field $DynamicField->{Name}",
                );
            }
        }
    }

    my $GeneralCatalogObject = $Kernel::OM->Get('GeneralCatalog');

    # get deployment state list
    my $DeplStateList = $GeneralCatalogObject->ItemList(
        Class => 'ITSM::ConfigItem::DeploymentState',
    );
    my %DeplStateListReverse = reverse %{$DeplStateList};

    # get incident state list
    my $InciStateList = $GeneralCatalogObject->ItemList(
        Class => 'ITSM::Core::IncidentState',
    );
    my %InciStateListReverse = reverse %{$InciStateList};

    # create test class
    my $ClassID = $GeneralCatalogObject->ItemAdd(
        Class    => 'ITSM::ConfigItem::Class',
        Name     => 'SystemMonitoringX test class',
        Comment  => '',
        ValidID  => 1,
        UserID   => 1
    );
    $Self->True(
        $ClassID,
        'Create class',
    );
    my $ClassDefID = $ConfigItemObject->DefinitionAdd(
        ClassID    => $ClassID,
        UserID     => 1,
        Definition =>
"[
    {
        Key              => 'SomeAttribute',
        Name             => 'Some Attribute',
        Searchable       => 1,
        CustomerVisible  => 0,
        Input            => {
            Type => 'Text',
        }
    }
]"
    );

    # create unique "Host" config item
    $HostConfigItemID = $ConfigItemObject->ConfigItemAdd(
        Number  => '00000000000000001',
        ClassID => $ClassID,
        UserID  => 1,
    );
    $Self->True(
        $HostConfigItemID,
        'Create config item "ddsrv007"',
    );
    if ($HostConfigItemID) {
        my $VersionID = $ConfigItemObject->VersionAdd(
            ConfigItemID => $HostConfigItemID,
            Name         => 'ddsrv007',
            DefinitionID => $ClassDefID,
            DeplStateID  => $DeplStateListReverse{Production},
            InciStateID  => $InciStateListReverse{Operational},
            UserID       => 1,
            XMLData      => [undef,
                {
                    Version => [
                        undef,
                        {
                            SomeAttribute => [
                                undef,
                                {
                                    Content => 'ddsrv007',
                                }
                            ]
                        }
                    ]
                }
            ]
        );
        $Self->True(
            $VersionID,
            'Create version of item "ddsrv007"',
        );
    }

    # create "Service" config item
    $ServiceConfigItemID = $ConfigItemObject->ConfigItemAdd(
        Number  => '00000000000000002',
        ClassID => $ClassID,
        UserID  => 1,
    );
    $Self->True(
        $ServiceConfigItemID,
        'Create config item "someService"',
    );
    if ($ServiceConfigItemID) {
        my $VersionID = $ConfigItemObject->VersionAdd(
            ConfigItemID => $ServiceConfigItemID,
            Name         => 'someService',
            DefinitionID => $ClassDefID,
            DeplStateID  => $DeplStateListReverse{Production},
            InciStateID  => $InciStateListReverse{Operational},
            UserID       => 1,
            XMLData      => [undef,
                {
                    Version => [
                        undef,
                        {
                            SomeAttribute => [
                                undef,
                                {
                                    Content => 'someService',
                                }
                            ]
                        }
                    ]
                }
            ]
        );
        $Self->True(
            $VersionID,
            'Create version of item "someService"',
        );
    }

    # create some "Host" config items with same name
    # disable unique name check
    $ConfigObject->Set(
        Key   => 'UniqueCIName::EnableUniquenessCheck',
        Value => 0
    );
    for my $Counter (1..3) {
        my $CIID = $ConfigItemObject->ConfigItemAdd(
            ClassID => $ClassID,
            UserID  => 1,
        );
        $Self->True(
            $CIID,
            'Create config item with same name (' . $Counter . ')',
        );
        if ($CIID) {
            my $VersionID = $ConfigItemObject->VersionAdd(
                ConfigItemID => $CIID,
                Name         => 'ddsrv',
                DefinitionID => $ClassDefID,
                DeplStateID  => $DeplStateListReverse{Production},
                InciStateID  => $InciStateListReverse{Operational},
                UserID       => 1,
                XMLData      => [undef,
                    {
                        Version => [
                            undef,
                            {
                                SomeAttribute => [
                                    undef,
                                    {
                                        Content => 'ddsrv (' . $Counter . ')',
                                    }
                                ]
                            }
                        ]
                    }
                ]
            );
            $Self->True(
                $VersionID,
                'Create version of item with same name (' . $Counter . ')',
            );
        }
    }
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
