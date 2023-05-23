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

use vars (qw($Self));

# get needed objects
my $ConfigObject = $Kernel::OM->Get('Config');
my $ConfigItemObject     = $Kernel::OM->Get('ITSMConfigItem');
my $GeneralCatalogObject = $Kernel::OM->Get('GeneralCatalog');
my $TemplateGeneratorObject = $Kernel::OM->Get('TemplateGenerator');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# given object tests
my @Tests = (
    {
        Name => 'KIX_ASSET_Name',
        Data => {
            ConfigItem => {
                Name   => 'some Name'
            }
        },
        Text   => 'Name: <KIX_ASSET_Name>',
        Result => 'Name: some Name',
    },
    {
        Name => 'KIX_ASSET_CurDeplState',
        Data => {
            ConfigItem => {
                CurDeplStateID => 2,
                CurDeplState => 'Production'
            }
        },
        Text   => '<KIX_ASSET_CurDeplStateID> - <KIX_ASSET_CurDeplState>',
        Result => '2 - Production',
    },
    {
        Name => 'KIX_ASSET_ RootElement',
        Data => {
            Version => {
                XMLData => [
                    undef,
                    {
                        TagKey  => '[1]',
                        Version => [
                            undef,
                            {
                                SomeAttribute => [
                                    undef,
                                    {
                                        Content => 'SomeValue',
                                        TagKey  => '[1]{\'Version\'}[1]{\'SomeAttribute\'}[1]'
                                    },
                                    {
                                        Content => 'SomeValue2',
                                        TagKey  => '[1]{\'Version\'}[1]{\'SomeAttribute\'}[2]'
                                    }
                                ],
                                TagKey => '[1]{\'Version\'}[1]'
                            }
                        ]
                    }
                ],
                XMLDefinition => [
                    {
                        CountMax => 2,
                        Key      => 'SomeAttribute',
                        Name     => 'Some attribute',
                        Input    => {
                            Type => 'Text'
                        }
                    }
                ]
            }
        },
        Text   => 'RootValue: <KIX_ASSET_SomeAttribute> ## <KIX_ASSET_SomeAttribute_0> ## <KIX_ASSET_SomeAttribute_0_Key> ## <KIX_ASSET_SomeAttribute_0_Value> ## <KIX_ASSET_SomeAttribute_1_Value>',
        Result => 'RootValue: SomeValue, SomeValue2 ## SomeValue ## SomeValue ## SomeValue ## SomeValue2',
    },
    {
        Name => 'KIX_ASSET_ SubElement',
        Data => {
            Version => {
                XMLData => [
                    undef,
                    {
                        TagKey  => '[1]',
                        Version => [
                            undef,
                            {
                                SomeAttribute => [
                                    undef,
                                    {
                                        Content => 'SomeValue1',
                                        SubAttribute => [
                                            undef,
                                            {
                                                Content => 'SomeValue1-1',
                                                TagKey  => '[1]{\'Version\'}[1]{\'SomeAttribute\'}[1]{\'SomeSubAttribute\'}[1]'

                                            }
                                        ],
                                        TagKey  => '[1]{\'Version\'}[1]{\'SomeAttribute\'}[1]'
                                    },
                                    {
                                        Content => 'SomeValue2',
                                        SubAttribute => [
                                            undef,
                                            {
                                                Content => 'SomeValue2-1',
                                                TagKey  => '[1]{\'Version\'}[1]{\'SomeAttribute\'}[2]{\'SomeSubAttribute\'}[1]'

                                            },
                                            {
                                                Content => 'SomeValue2-2',
                                                TagKey  => '[1]{\'Version\'}[1]{\'SomeAttribute\'}[2]{\'SomeSubAttribute\'}[2]'
                                            }
                                        ],
                                        OtherSubAttribute => [
                                            undef,
                                            {
                                                Content => 'OtherValue2-1',
                                                TagKey  => '[1]{\'Version\'}[1]{\'SomeAttribute\'}[2]{\'SomeSubAttribute\'}[1]'

                                            },
                                        ],
                                        TagKey  => '[1]{\'Version\'}[1]{\'SomeAttribute\'}[2]'
                                    }
                                ],
                                TagKey => '[1]{\'Version\'}[1]'
                            }
                        ]
                    }
                ],
                XMLDefinition => [
                    {
                        CountMax => 2,
                        Key   => 'SomeAttribute',
                        Name  => 'Some attribute',
                        Input => {
                            Type => 'Text'
                        },
                        Sub => [
                            {
                                CountMax => 3,
                                Key   => 'SubAttribute',
                                Name  => 'Sub attribute',
                                Input => {
                                    Type => 'Text'
                                }
                            },
                            {
                                CountMax => 3,
                                Key   => 'OtherSubAttribute',
                                Name  => 'Other sub attribute',
                                Input => {
                                    Type => 'Text'
                                }
                            }
                        ]
                    }
                ]
            }
        },
        Text   => 'RootValue: <KIX_ASSET_SomeAttribute> ## <KIX_ASSET_SomeAttribute_1_SubAttribute_1> ## <KIX_ASSET_SomeAttribute_1_OtherSubAttribute_0>',
        Result => 'RootValue: SomeValue1, SomeValue2 ## SomeValue2-2 ## OtherValue2-1',
    },
);

for my $Test (@Tests) {
    my $Result = $TemplateGeneratorObject->_Replace(
        Text        => $Test->{Text},
        Data        => $Test->{Data},
        UserID      => 1,
        Translate   => 0
    );
    $Self->Is(
        $Result,
        $Test->{Result},
        "$Test->{Name} - _Replace()",
    );
}

# test by id (config item data from database)
my $YesNoList = $GeneralCatalogObject->ItemList(
    Class => 'ITSM::ConfigItem::YesNo',
);
my %YesNoListReverse = reverse %{$YesNoList};
my %Data = (
    User => 'TestUser',
    Organisation => 'TestOrga',
    Contact => {
        Firstname => 'Test',
        Lastname => 'Contact',
        Email => 'test@contact.com'
    },
    MaintenanceDates => [
        '2023-05-01',
        '2023-06-01',
        '2023-07-01'
    ],
    MaintenanceDatesEnglish => [
        '05/01/2023',
        '06/01/2023',
        '07/01/2023'
    ],
    MaintenanceDatesGerman => [
        '01.05.2023'
    ],
    MaintenanceDateTimes => [
        '2023-05-01 12:31:00'
    ],
    MaintenanceDateTimesEnglish => [
        '05/01/2023, 0:31 PM'
    ],
    MaintenanceDateTimesGerman => [
        '01.05.2023, 12:31'
    ],
    Comment => 'SomeComment\nsome more',
    RelevantAsset => {
        Name   => 'Reference Asset',
        Number => '00000000000000001'
    },
    Attachment => 'someFileName.txt'
);
my $IDs = _AddConfigItem();

if ($IDs->[0]) {

    my $VersionData = $ConfigItemObject->VersionGet(
        ConfigItemID => $IDs->[0],
        XMLDataGet   => 1
    );
    $Self->True(
        IsHashRefWithData($VersionData) ? 1 : 0,
        'version get',
    );
    if ( IsHashRefWithData($VersionData) ) {
        my $ContactValue = $ConfigItemObject->GetAttributeValuesByKey(
            KeyName       => 'OwnerContact',
            XMLData       => $VersionData->{XMLData}->[1]->{Version}->[1],
            XMLDefinition => $VersionData->{XMLDefinition}
        );
        my $RefAssetValue = $ConfigItemObject->GetAttributeValuesByKey(
            KeyName       => 'RelevantAsset',
            XMLData       => $VersionData->{XMLData}->[1]->{Version}->[1],
            XMLDefinition => $VersionData->{XMLDefinition}
        );

        my @Tests = (
            {
                Name   => 'KIX_ASSET_Name',
                Text   => 'Name: <KIX_ASSET_Name>',
                Result => 'Name: ReplaceCI'
            },
            {
                Name   => 'KIX_ASSET_CurDeplState',
                Text   => 'DeplState: <KIX_ASSET_CurDeplState>',
                Result => 'DeplState: Production'
            },
            {
                Name   => 'KIX_ASSET_ Orga attribute',
                Text   => 'Orga: <KIX_ASSET_SectionOwner_0_OwnerOrganisation_0> ## <KIX_ASSET_SectionOwner_0_OwnerOrganisation_0_Key>',
                Result => "Orga: $Data{Organisation} ## $IDs->[2]"
            },
            {
                Name   => 'KIX_ASSET_ Contact attribute',
                Text   => 'Contact: <KIX_ASSET_SectionOwner_0_OwnerContact_0> ## <KIX_ASSET_SectionOwner_0_OwnerContact_0_Key>',
                Result => "Contact: $ContactValue->[0] ## $IDs->[3]"
            },
            {
                Name   => 'KIX_ASSET_ GeneralCatalog attribute',
                Text   => 'GeneralCatalog: <KIX_ASSET_SectionMaintenance_0_NoMaintenance_0_Value> ## <KIX_ASSET_SectionMaintenance_0_NoMaintenance_0_Key>',
                Result => "GeneralCatalog: Yes ## $YesNoListReverse{Yes}"
            },
            {
                Name   => 'KIX_ASSET_ GeneralCatalog attribute (Keys)',
                Text => '<KIX_ASSET_SectionMaintenance_1_NoMaintenance_Keys>',
                ResultList => "$YesNoListReverse{Yes}, $YesNoListReverse{No}"
            },
            {
                Name   => 'KIX_ASSET_ GeneralCatalog attribute (Values)',
                Text => '<KIX_ASSET_SectionMaintenance_1_NoMaintenance_Values>',
                ResultList => 'Yes, No'
            },
            {
                Name   => 'KIX_ASSET_ Date attribute',
                Text   => 'Date: <KIX_ASSET_SectionMaintenance_0_MaintenanceDates_0> ## <KIX_ASSET_SectionMaintenance_0_MaintenanceDates_1> ## <KIX_ASSET_SectionMaintenance_0_MaintenanceDates>',
                Result => "Date: $Data{MaintenanceDatesEnglish}->[0] ## $Data{MaintenanceDatesEnglish}->[1] ## $Data{MaintenanceDatesEnglish}->[0], $Data{MaintenanceDatesEnglish}->[1], $Data{MaintenanceDatesEnglish}->[2]"
            },
            {
                Name   => 'KIX_ASSET_ Date attribute',
                Text   => 'Date: <KIX_ASSET_SectionMaintenance_1_MaintenanceDates_0> ## <KIX_ASSET_SectionMaintenance_1_MaintenanceDates_1>',
                Result => "Date: $Data{MaintenanceDatesEnglish}->[2] ## -"
            },
            {
                Name       => 'KIX_ASSET_ Date attribute (Values)',
                Text       => '<KIX_ASSET_SectionMaintenance_0_MaintenanceDates>',
                ResultList => join(', ', @{$Data{MaintenanceDatesEnglish}})
            },
            {
                Name   => 'KIX_ASSET_ DateTime attribute',
                Text   => 'DateTime: <KIX_ASSET_SectionMaintenance_0_MaintenanceDateTimes_0>',
                Result => "DateTime: $Data{MaintenanceDateTimesEnglish}->[0]"
            },
            {
                Name   => 'KIX_ASSET_ ConfigItemRef attribute',
                Text   => 'ConfigItemRef: <KIX_ASSET_RelevantAsset_0> ## <KIX_ASSET_RelevantAsset_0_Key>',
                Result => "ConfigItemRef: $RefAssetValue->[0] ## $IDs->[4]"
            },
            {
                Name   => 'KIX_ASSET_ TextArea attribute',
                Text   => 'TextArea: <KIX_ASSET_Comment>',
                Result => "TextArea: $Data{Comment}"
            },
            {
                Name   => 'KIX_ASSET_ Attachment attribute',
                Text   => 'Attachment: <KIX_ASSET_Attachment_0_Key> ## <KIX_ASSET_Attachment>',
                Result => "Attachment: $IDs->[5] ## $Data{Attachment}"
            },
            # negative test
            {
                Name   => 'KIX_ASSET_ unknown attribute',
                Text   => 'Unknown: <KIX_ASSET_Unknown_0_Key>',
                Result => "Unknown: -"
            },
            # translation test
            {
                Name   => 'KIX_ASSET_ Date attribute',
                Text   => 'Date: <KIX_ASSET_SectionMaintenance_0_MaintenanceDates_0> ## <KIX_ASSET_SectionMaintenance_0_MaintenanceDates_0_Key>',
                Result => "Date: $Data{MaintenanceDatesGerman}->[0] ## $Data{MaintenanceDates}->[0]",
                Translation => 1
            },
            {
                Name   => 'KIX_ASSET_ GeneralCatalog attribute',
                Text   => '<KIX_ASSET_SectionMaintenance_1_NoMaintenance_0_Value>',
                Result => 'Ja',
                Translation => 1
            },
            {
                Name   => 'KIX_ASSET_ Date attribute',
                Text   => 'Datum: <KIX_ASSET_SectionMaintenance_0_MaintenanceDates_0>',
                Result => "Datum: $Data{MaintenanceDatesGerman}->[0]",
                Translation => 1
            },
            {
                Name   => 'KIX_ASSET_ DateTime attribute',
                Text   => 'DateTime: <KIX_ASSET_SectionMaintenance_0_MaintenanceDateTimes_0>',
                Result => "DateTime: $Data{MaintenanceDateTimesGerman}->[0]",
                Translation => 1
            },
        );

        for my $Test (@Tests) {
            my $Result = $TemplateGeneratorObject->ReplacePlaceHolder(
                Text       => $Test->{Text},
                ObjectType => 'ITSMConfigItem',
                ObjectID   => $IDs->[0],
                UserID     => 1,
                Language   => $Test->{Translation} ? 'de' : 'en',
            );
            if ($Test->{Result}) {
                $Self->Is(
                    $Result,
                    $Test->{Result},
                    "$Test->{Name} (by ID) - _Replace()",
                );
            } elsif ($Test->{ResultList}) {
                $Self->IsDeeply(
                    $Result,
                    $Test->{ResultList},
                    '$Test->{Name} (by ID - List) - _Replace()',
                );
            }
        }
    }
}

# Cleanup is done by RestoreDatabase.

sub _AddConfigItem {

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

    # create orga/contac/user
    my $TestUserID = $Kernel::OM->Get('User')->UserAdd(
        UserLogin    => $Data{User},
        UserPw       => 'somepass',
        ValidID      => 1,
        ChangeUserID => 1
    );
    my $TestOrgaID = $Kernel::OM->Get('Organisation')->OrganisationAdd(
        Number  => $Data{Organisation},
        Name    => $Data{Organisation},
        ValidID => 1,
        UserID  => 1
    );
    my $TestContactID = $Kernel::OM->Get('Contact')->ContactAdd(
        Firstname             => $Data{Contact}->{Firstname},
        Lastname              => $Data{Contact}->{Lastname},
        PrimaryOrganisationID => $TestOrgaID,
        OrganisationIDs       => [ $TestOrgaID ],
        Email                 => $Data{Contact}->{Email},
        AssignedUserID        => $TestUserID,
        ValidID               => 1,
        UserID                => 1
    );
    $Self->True(
        $TestContactID,
        '_AddConfigItem - contact create',
    );
    my %TestContact = $Kernel::OM->Get('Contact')->ContactGet(ID => $TestContactID, UserID => 1);

    # create class
    my $ClassName = 'ReplaceClass';
    my $ClassID = $GeneralCatalogObject->ItemAdd(
        Class    => 'ITSM::ConfigItem::Class',
        Name     => $ClassName,
        Comment  => '',
        ValidID  => 1,
        UserID   => 1
    );
    $Self->True(
        $ClassID,
        '_AddConfigItem - create class',
    );
    my $ClassDefID = $ConfigItemObject->DefinitionAdd(
        ClassID    => $ClassID,
        UserID     => 1,
        Definition =>
"[
    {
        Key             => 'SectionOwner',
        Name            => 'Owner Information',
        CustomerVisible => 0,
        Input           => {
            Type => 'Dummy'
        },
        CountMax => 1,
        Sub => [
            {
                Key              => 'OwnerOrganisation',
                Name             => 'Assigned Organisation',
                Searchable       => 1,
                CustomerVisible  => 0,
                Input            => {
                    Type => 'Organisation'
                },
                CountMax => 1
            },
            {
                Key              => 'OwnerContact',
                Name             => 'Assigned Contact',
                Searchable       => 1,
                CustomerVisible  => 0,
                Input            => {
                    Type => 'Contact'
                },
                CountMin     => 0,
                CountMax     => 5,
                CountDefault => 1
            }
        ]
    },
    {
        Key      => 'SectionMaintenance',
        Name     => 'Maintenance Information',
        Input => {
            Type => 'Dummy'
        },
        CountMax => 2,
        Sub      => [
            {
                Key   => 'NoMaintenance',
                Name  => 'No Maintenance',
                Input => {
                    Class => 'ITSM::ConfigItem::YesNo',
                    Translation => 0,
                    Type => 'GeneralCatalog'
                },
                CountMax => 2
            },
            {
                Key   => 'MaintenanceDates',
                Name  => 'Maintenance Dates',
                Input => {
                    Type => 'Date',
                    YearPeriodFuture => 10,
                    YearPeriodPast => 20
                },
                CountMax => 5
            },
            {
                Key   => 'MaintenanceDateTimes',
                Name  => 'Maintenance DateTimes',
                Input => {
                    Type => 'DateTime',
                    YearPeriodFuture => 10,
                    YearPeriodPast => 20
                },
                CountMax => 5
            }
        ]
    },
    {
        Key   => 'Comment',
        Name  => 'Comment',
        Input => {
            Type => 'TextArea'
        },
        CountMax => 1
    },
    {
        Key   => 'RelevantAsset',
        Name  => 'Relevant Asset',
        Input => {
            ReferencedCIClassName   => [
                '$ClassName'
            ],
            Type => 'CIClassReference',
            ReferencedCIClassLinkDirection => 'Reverse',
            ReferencedCIClassLinkType      => 'Includes'

        },
        CountMax => 1
    },
    {
        Key   => 'Attachment',
        Name  => 'Attachment',
        Input => {
            Type => 'Attachment'
        },
        CountMax => 1
    }
]"
    );
    $Self->True(
        $ClassID,
        '_AddConfigItem - create class definition',
    );

    # reference config item
    my $RefCIID = $ConfigItemObject->ConfigItemAdd(
        Number  => $Data{RelevantAsset}->{Number},
        ClassID => $ClassID,
        UserID  => 1
    );
    $Self->True(
        $RefCIID,
        '_AddConfigItem - create reference config item',
    );
    if ($RefCIID) {
        # without xml data, not needed
        my $RefCIVersionID = $ConfigItemObject->VersionAdd(
            ConfigItemID => $RefCIID,
            Name         => $Data{RelevantAsset}->{Name},
            DefinitionID => $ClassDefID,
            DeplStateID  => $DeplStateListReverse{Production},
            InciStateID  => $InciStateListReverse{Operational},
            UserID       => 1
        );
        $Self->True(
            $RefCIVersionID,
            '_AddConfigItem - create reference version'
        );
    }

    # "for replace" config item
    my $ReplaceCIID = $ConfigItemObject->ConfigItemAdd(
        Number  => '00000000000000002',
        ClassID => $ClassID,
        UserID  => 1
    );
    $Self->True(
        $ReplaceCIID,
        '_AddConfigItem - create replace config item',
    );
    my $Content = '';
    my $AttachmentID = $ConfigItemObject->AttachmentStorageAdd(
        DataRef         => \$Content,
        Filename        => $Data{Attachment},
        UserID          => 1,
        Preferences     => {
            Datatype => 'text/plain',
        }
    );
    if ($ReplaceCIID) {
        my $ReplaceCIVersionID = $ConfigItemObject->VersionAdd(
            ConfigItemID => $ReplaceCIID,
            Name         => 'ReplaceCI',
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
                            SectionOwner => [
                                undef,
                                {
                                    OwnerOrganisation => [
                                        undef,
                                        {
                                            Content => $TestContact{PrimaryOrganisationID},
                                        }
                                    ],
                                    OwnerContact => [
                                        undef,
                                        {
                                            Content => $TestContactID,
                                        }
                                    ]
                                }
                            ],
                            SectionMaintenance => [
                                undef,
                                {
                                    NoMaintenance => [
                                        undef,
                                        {
                                            Content => $YesNoListReverse{Yes},
                                        }
                                    ],
                                    MaintenanceDates => [
                                        undef,
                                        {
                                            Content => $Data{MaintenanceDates}->[0],
                                        },
                                        {
                                            Content => $Data{MaintenanceDates}->[1],
                                        },
                                        {
                                            Content => $Data{MaintenanceDates}->[2],
                                        }
                                    ],
                                    MaintenanceDateTimes => [
                                        undef,
                                        {
                                            Content => $Data{MaintenanceDateTimes}->[0],
                                        }
                                    ]
                                },
                                {
                                    NoMaintenance => [
                                        undef,
                                        {
                                            Content => $YesNoListReverse{Yes},
                                        },
                                        {
                                            Content => $YesNoListReverse{No},
                                        }
                                    ],
                                    MaintenanceDates => [
                                        undef,
                                        {
                                            Content => $Data{MaintenanceDates}->[2],
                                        }
                                    ]
                                }
                            ],
                            Comment => [
                                undef,
                                {
                                    Content => $Data{Comment},
                                }
                            ],
                            RelevantAsset => [
                                undef,
                                {
                                    Content => $RefCIID,
                                }
                            ],
                            Attachment => [
                                undef,
                                {
                                    Content => $AttachmentID,
                                }
                            ]
                        }
                    ]
                }
            ]
        );
        $Self->True(
            $ReplaceCIVersionID,
            '_AddConfigItem - create replace version'
        );
    }

    return [$ReplaceCIID, $TestUserID, $TestOrgaID, $TestContactID, $RefCIID, $AttachmentID];
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
