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

use vars (qw($Self));

# get needed objects
my $ConfigObject = $Kernel::OM->Get('Config');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my $YesNoList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
    Class => 'ITSM::ConfigItem::YesNo',
);
my %YesNoListReverse = reverse %{$YesNoList};
my %Data = (
    Asset_1_Name   => 'Asset One',
    Asset_1_Serial => '001-001-001',
    Asset_1_Note   => 'Note of\nAsset One',

    Asset_2_Name   => 'Asset Two',
    Asset_2_Serial => '002-002-002',
    Asset_2_Note   => 'Note of\nAsset Two',

    Asset_1_Date        => '2023-05-01',
    Asset_1_DateEnglish => '05/01/2023',
    Asset_1_DateGerman  => '01.05.2023',

    Asset_1_YesNo        => [$YesNoListReverse{Yes}, $YesNoListReverse{No}],
    Asset_1_YesEnglish   => 'Yes',
    Asset_1_YesGerman    => 'Ja',
    Asset_1_YesNoEnglish => 'Yes, No',
    Asset_1_YesNoGerman  => 'Ja, Nein',
);

my $AssetIDs = _AddConfigItems();
if (scalar @{$AssetIDs}) {
    my $TicketID = _AddTicket();

    if ($TicketID) {

        my @Tests = (
            {
                Name   => 'KIX_TICKET_DynamicField_AssetRef_Object_0_Name',
                Text   => 'Name: <KIX_TICKET_DynamicField_AssetRef_Object_0_Name>',
                Result => "Name: $Data{Asset_1_Name}"
            },
            {
                Name   => 'Object_0_Name and other placeholder',
                Text   => '<KIX_TICKET_DynamicField_AssetRef_Object_0_Name> (<KIX_TICKET_DynamicField_AssetRef_ObjectValue_0>)',
                Result => "$Data{Asset_1_Name} ($AssetIDs->[0])"
            },
            {
                Name   => 'KIX_TICKET_DynamicField_AssetRef_Object_1_Name',
                Text   => 'Name: <KIX_TICKET_DynamicField_AssetRef_Object_1_Name>',
                Result => "Name: $Data{Asset_2_Name}"
            },
            {
                Name   => 'KIX_TICKET_DynamicField_AssetRef_Object_0_SerialNumber_0',
                Text   => 'SerialNumber: <KIX_TICKET_DynamicField_AssetRef_Object_0_SerialNumber_0>',
                Result => "SerialNumber: $Data{Asset_1_Serial}"
            },
            {
                Name   => 'KIX_TICKET_DynamicField_AssetRef_Object_0_SerialNumber',
                Text   => 'SerialNumber: <KIX_TICKET_DynamicField_AssetRef_Object_0_SerialNumber>',
                Result => "SerialNumber: $Data{Asset_1_Serial}"
            },
            {
                Name   => 'KIX_TICKET_DynamicField_AssetRef_Object_1_SerialNumber_0',
                Text   => 'SerialNumber: <KIX_TICKET_DynamicField_AssetRef_Object_1_SerialNumber_0>',
                Result => "SerialNumber: $Data{Asset_2_Serial}"
            },
            {
                Name   => 'KIX_TICKET_DynamicField_AssetRef_Object_1_SerialNumber',
                Text   => 'SerialNumber: <KIX_TICKET_DynamicField_AssetRef_Object_1_SerialNumber>',
                Result => "SerialNumber: $Data{Asset_2_Serial}"
            },
            {
                Name   => 'KIX_TICKET_DynamicField_AssetRef_Object_0_SerialNumber_0_SubNote',
                Text   => 'Note: <KIX_TICKET_DynamicField_AssetRef_Object_0_SerialNumber_0_SubNote>',
                Result => "Note: $Data{Asset_1_Note}"
            },
            {
                Name   => 'KIX_TICKET_DynamicField_AssetRef_Object_1_SerialNumber_0_SubNote',
                Text   => 'Note: <KIX_TICKET_DynamicField_AssetRef_Object_1_SerialNumber_0_SubNote>',
                Result => "Note: $Data{Asset_2_Note}"
            },
            {
                Name   => 'multi object placeholder',
                Text   => 'Note: <KIX_TICKET_DynamicField_AssetRef_Object_0_SerialNumber_0_SubNote> # <KIX_TICKET_DynamicField_AssetRef_Object_1_SerialNumber_0_SubNote>',
                Result => "Note: $Data{Asset_1_Note} # $Data{Asset_2_Note}"
            },
            # negative tests
            {
                Name   => 'KIX_TICKET_DynamicField_AssetRef_Object_0_SerialNumber_5_SubNote (unknow counter)',
                Text   => 'SerialNumber: <KIX_TICKET_DynamicField_AssetRef_Object_0_SerialNumber_5_SubNote>',
                Result => "SerialNumber: -"
            },
            {
                Name   => 'KIX_TICKET_DynamicField_AssetRef_Object_Name (missing object index)',
                Text   => 'Name: <KIX_TICKET_DynamicField_AssetRef_Object_Name>',
                Result => "Name: -"
            },
            {
                Name   => 'KIX_TICKET_DynamicField_AssetRef_Object_5_Name (unknown object index)',
                Text   => 'Name: <KIX_TICKET_DynamicField_AssetRef_Object_5_Name>',
                Result => "Name: -"
            },
            # translation test
            {
                Name   => 'KIX_TICKET_DynamicField_AssetRef_Object_0_SomeDate_0_Key',
                Text   => 'Date: <KIX_TICKET_DynamicField_AssetRef_Object_0_SomeDate_0_Key>',
                Result => "Date: $Data{Asset_1_Date}"
            },
            {
                Name   => 'KIX_TICKET_DynamicField_AssetRef_Object_0_SomeDate_0 - english',
                Text   => 'Date: <KIX_TICKET_DynamicField_AssetRef_Object_0_SomeDate_0>',
                Result => "Date: $Data{Asset_1_DateEnglish}"
            },
            {
                Name   => 'KIX_TICKET_DynamicField_AssetRef_Object_0_SomeDate_0 - german',
                Text   => 'Datum: <KIX_TICKET_DynamicField_AssetRef_Object_0_SomeDate_0>',
                Result => "Datum: $Data{Asset_1_DateGerman}",
                German => 1
            },
            {
                Name   => 'KIX_TICKET_DynamicField_AssetRef_Object_0_SomeDate_0! - no translation',
                Text   => 'Date: <KIX_TICKET_DynamicField_AssetRef_Object_0_SomeDate_0!>',
                Result => "Date: $Data{Asset_1_Date}",
                German => 1
            },
            {
                Name   => 'KIX_TICKET_DynamicField_AssetRef_Object_0_SomeDate_0! - no translation without surrounding text', # make sure it is not dependent on additional text
                Text   => '<KIX_TICKET_DynamicField_AssetRef_Object_0_SomeDate_0!>',
                Result => $Data{Asset_1_Date},
                German => 1
            },
            {
                Name   => 'KIX_TICKET_DynamicField_AssetRef_Object_0_YesNo_0 - english',
                Text   => 'Yes: <KIX_TICKET_DynamicField_AssetRef_Object_0_YesNo_0>',
                Result => "Yes: $Data{Asset_1_YesEnglish}",
            },
            {
                Name   => 'KIX_TICKET_DynamicField_AssetRef_Object_0_YesNo_0 - german',
                Text   => 'Ja: <KIX_TICKET_DynamicField_AssetRef_Object_0_YesNo_0>',
                Result => "Ja: $Data{Asset_1_YesGerman}",
                German => 1
            },
            {
                Name   => 'KIX_TICKET_DynamicField_AssetRef_Object_0_YesNo_0! - no translation',
                Text   => 'Yes: <KIX_TICKET_DynamicField_AssetRef_Object_0_YesNo_0!>',
                Result => "Yes: $Data{Asset_1_YesEnglish}",
                German => 1
            },
            {
                Name   => 'KIX_TICKET_DynamicField_AssetRef_Object_0_YesNo_0! - no translation without surrounding text',
                Text   => '<KIX_TICKET_DynamicField_AssetRef_Object_0_YesNo_0!>',
                Result => $Data{Asset_1_YesEnglish},
                German => 1
            },
            {
                Name   => 'KIX_TICKET_DynamicField_AssetRef_Object_0_YesNo - german',
                Text   => 'JaNein: <KIX_TICKET_DynamicField_AssetRef_Object_0_YesNo>',
                Result => "JaNein: $Data{Asset_1_YesNoGerman}",
                German => 1
            },
            {
                Name   => 'KIX_TICKET_DynamicField_AssetRef_Object_0_YesNo! - no translation', # get string
                Text   => 'YesNo: <KIX_TICKET_DynamicField_AssetRef_Object_0_YesNo!>',
                Result => "YesNo: " . join(q{,},@{$Data{Asset_1_YesNo}}),
                German => 1
            },
            {
                Name   => 'KIX_TICKET_DynamicField_AssetRef_Object_0_YesNo! - no translation without surounding text', # get "object value"
                Text   => '<KIX_TICKET_DynamicField_AssetRef_Object_0_YesNo!>',
                Result => $Data{Asset_1_YesNo},
                German => 1
            },
            {
                Name   => 'KIX_TICKET_DynamicField_AssetRef_Object_0_YesNo_ObjectValue',
                Text   => '<KIX_TICKET_DynamicField_AssetRef_Object_0_YesNo_ObjectValue>',
                Result => $Data{Asset_1_YesNo},
                German => 1
            }
        );

        for my $Test (@Tests) {
            my $Result = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
                Text        => $Test->{Text},
                ObjectType  => 'Ticket',
                ObjectID    => $TicketID,
                UserID      => 1,
                Language    => $Test->{German} ? 'de' : 'en'
            );

            if ( IsStringWithData($Test->{Result}) ) {
                $Self->Is(
                    $Result,
                    $Test->{Result},
                    "$Test->{Name} - _Replace()",
                );
            }
            else {
                $Self->IsDeeply(
                    $Result,
                    $Test->{Result},
                    "$Test->{Name} - _Replace()",
                );
            }
        }
    }
}

# rollback transaction on database
$Helper->Rollback();

sub _AddConfigItems {

    # get deployment state list
    my $DeplStateList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class => 'ITSM::ConfigItem::DeploymentState',
    );
    my %DeplStateListReverse = reverse %{$DeplStateList};

    # get incident state list
    my $InciStateList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class => 'ITSM::Core::IncidentState',
    );
    my %InciStateListReverse = reverse %{$InciStateList};

    # create class
    my $ClassName = 'Replace' . $Helper->GetRandomID();
    my $ClassID = $Kernel::OM->Get('GeneralCatalog')->ItemAdd(
        Class    => 'ITSM::ConfigItem::Class',
        Name     => $ClassName,
        Comment  => q{},
        ValidID  => 1,
        UserID   => 1
    );
    $Self->True(
        $ClassID,
        '_AddConfigItems - create class',
    );
    my $ClassDefID = $Kernel::OM->Get('ITSMConfigItem')->DefinitionAdd(
        ClassID    => $ClassID,
        UserID     => 1,
        Definition => <<'END'
[
    {
        Key   => 'SerialNumber',
        Name  => 'Serial Number',
        Input => {
            Type => 'Text'
        },
        CountMax => 1,
        Sub => [
            {
                Key   => 'SubNote',
                Name  => 'Sub Note',
                Input => {
                    Type => 'TextArea'
                },
                CountMax => 2
            }
        ]
    },
    {
        Key   => 'SomeDate',
        Name  => 'Some Date',
        Input => {
            Type => 'Date',
            YearPeriodFuture => 10,
            YearPeriodPast => 20
        },
        CountMax => 1
    },
    {
        Key   => 'YesNo',
        Name  => 'Yes And No',
        Input => {
            Type        => 'GeneralCatalog',
            Class       => 'ITSM::ConfigItem::YesNo',
            Translation => 1,
        },
        CountMax => 2
    }
]
END

    );
    $Self->True(
        $ClassDefID,
        '_AddConfigItems - create class definition',
    );

    $Kernel::OM->ObjectsDiscard(
        Objects => [
            'GeneralCatalog',
            'ITSMConfigItem'
        ]
    );

    # reference config item
    my $AssetOneID = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
        Number  => $Helper->GetRandomNumber(),
        ClassID => $ClassID,
        UserID  => 1
    );
    $Self->True(
        $AssetOneID,
        '_AddConfigItems - create first asset',
    );
    if ($AssetOneID) {
        my $AssetOneVersionID = $Kernel::OM->Get('ITSMConfigItem')->VersionAdd(
            ConfigItemID => $AssetOneID,
            Name         => $Data{Asset_1_Name},
            DefinitionID => $ClassDefID,
            DeplStateID  => $DeplStateListReverse{Production},
            InciStateID  => $InciStateListReverse{Operational},
            UserID       => 1,
            XMLData      => [
                undef,
                {
                    Version => [
                        undef,
                        {
                            SerialNumber => [
                                undef,
                                {
                                    SubNote => [
                                        undef,
                                        {
                                            Content => $Data{Asset_1_Note},
                                        }
                                    ],
                                    Content => $Data{Asset_1_Serial}
                                }
                            ],
                            SomeDate => [
                                undef,
                                {
                                    Content => $Data{Asset_1_Date}
                                }
                            ],
                            YesNo => [
                                undef,
                                {
                                    Content => $YesNoListReverse{Yes}
                                },
                                {
                                    Content => $YesNoListReverse{No}
                                }
                            ]
                        }
                    ]
                }
            ]
        );
        $Self->True(
            $AssetOneVersionID,
            '_AddConfigItems - create version for first asset'
        );
    }

    $Kernel::OM->ObjectsDiscard(
        Objects => [
            'ITSMConfigItem'
        ]
    );

    my $AssetTwoID = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
        Number  => $Helper->GetRandomNumber(),
        ClassID => $ClassID,
        UserID  => 1
    );
    $Self->True(
        $AssetTwoID,
        '_AddConfigItems - create second asset',
    );
    if ($AssetTwoID) {
        my $AssetTwoVersionID = $Kernel::OM->Get('ITSMConfigItem')->VersionAdd(
            ConfigItemID => $AssetTwoID,
            Name         => $Data{Asset_2_Name},
            DefinitionID => $ClassDefID,
            DeplStateID  => $DeplStateListReverse{Production},
            InciStateID  => $InciStateListReverse{Operational},
            UserID       => 1,
            XMLData      => [
                undef,
                {
                    Version => [
                        undef,
                        {
                            SerialNumber => [
                                undef,
                                {
                                    SubNote => [
                                        undef,
                                        {
                                            Content => $Data{Asset_2_Note},
                                        }
                                    ],
                                    Content => $Data{Asset_2_Serial}
                                }
                            ]
                        }
                    ]
                }
            ]
        );
        $Self->True(
            $AssetTwoVersionID,
            '_AddConfigItems - create version for second asset'
        );
    }

    $Kernel::OM->ObjectsDiscard(
        Objects => [
            'ITSMConfigItem'
        ]
    );

    return [$AssetOneID, $AssetTwoID];
}

sub _AddTicket {
    my $DFID = $Kernel::OM->Get('DynamicField')->DynamicFieldAdd(
        Name            => 'AssetRef',
        Label           => 'Asset reference',
        FieldType       => 'ITSMConfigItemReference',
        ObjectType      => 'Ticket',
        Config          => {
                CountMin => 0,
                CountMax => 2,
                CountDefault => 0,
                ItemSeparator => q{#},
                DefaultValue => undef,
                DeploymentStates => undef,
                ITSMConfigItemClasses => undef
        },
        ValidID         => 1,
        UserID          => 1
    );
    $Self->True(
        $DFID,
        '_AddTicket - create dynamic field'
    );

    return if (!$DFID);

    my $DynamicFieldConfig = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
        ID => $DFID,
    );
    $Self->True(
        IsHashRefWithData($DynamicFieldConfig),
        '_AddTicket - get dynamic field config'
    );

    return if (!IsHashRefWithData($DynamicFieldConfig));

    my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
        Title    => 'Asset Ref Test',
        OwnerID  => 1,
        Queue    => 'Junk',
        Lock     => 'unlock',
        Priority => '3 normal',
        State    => 'closed',
        UserID   => 1
    );
    $Self->True(
        $TicketID,
        '_AddTicket - create ticket'
    );

    return if (!$TicketID);

    my $Success = $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
        DynamicFieldConfig => $DynamicFieldConfig,
        ObjectID => $TicketID,
        Value    => $AssetIDs,
        UserID => 1
    );

    $Kernel::OM->ObjectsDiscard(
        Objects => [
            'DynamicField',
            'Ticket'
        ]
    );

    return if (!$Success);

    return $TicketID;
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
