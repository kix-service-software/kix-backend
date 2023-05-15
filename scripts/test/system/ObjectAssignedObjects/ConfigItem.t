# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
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

# get needed objects for rollback
my $UserObject           = $Kernel::OM->Get('User'); # without, config changes are ignored!!

# get actual needed objects
my $ConfigObject         = $Kernel::OM->Get('Config');
my $ConfigItemObject     = $Kernel::OM->Get('ITSMConfigItem');
my $GeneralCatalogObject = $Kernel::OM->Get('GeneralCatalog');
my $ContactObject        = $Kernel::OM->Get('Contact');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

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

# prepare test data
my %TestData = _PrepareData();

_CheckConfig();

_DoNegativeTests();

sub _PrepareData {

    # create customer user
    my $CustomerContactID = $Helper->TestContactCreate();
    $Self->True(
        $CustomerContactID,
        'CustomerContactCreate',
    );
    my %CustomerContact = $ContactObject->ContactGet(ID => $CustomerContactID);
    my %CustomerUser    = $UserObject->GetUserData(UserID => $CustomerContact{AssignedUserID});
    if (IsHashRefWithData(\%CustomerUser)) {
        $CustomerContact{User} = \%CustomerUser;
    } else {
        $Self->True(
            0, 'CustomerContactCreate - UserGet',
        );
    }

    # create classes
    my $ClassAName = 'Class A';
    my $Class_A_ID = $GeneralCatalogObject->ItemAdd(
        Class    => 'ITSM::ConfigItem::Class',
        Name     => $ClassAName,
        Comment  => '',
        ValidID  => 1,
        UserID   => 1
    );
    $Self->True(
        $Class_A_ID,
        'Create class A',
    );
    my $Class_A_Def_ID = $ConfigItemObject->DefinitionAdd(
        ClassID    => $Class_A_ID,
        UserID     => 1,
        Definition =>
"[
    {
        Key              => 'SectionOwner',
        Name             => 'Owner Information',
        CustomerVisible  => 0,
        Input            => {
            Type => 'Dummy'
        },
        Sub => [
            {
                Key              => 'OwnerOrganisation',
                Name             => 'Assigned Organisation',
                Searchable       => 1,
                CustomerVisible  => 0,
                Input            => {
                    Type => 'Organisation'
                }
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
                CountMax     => 25,
                CountDefault => 1
            }
        ]
    }
]"
    );
    my $ClassBName = 'Class B';
    my $Class_B_ID = $GeneralCatalogObject->ItemAdd(
        Class    => 'ITSM::ConfigItem::Class',
        Name     => $ClassBName,
        Comment  => '',
        ValidID  => 1,
        UserID   => 1
    );
    $Self->True(
        $Class_B_ID,
        'Create class B',
    );
    my $Class_B_Def_ID = $ConfigItemObject->DefinitionAdd(
        ClassID    => $Class_B_ID,
        UserID     => 1,
        Definition =>
"[
    {
        Key              => 'OwnerContact',
        Name             => 'Assigned Contact',
        Searchable       => 1,
        CustomerVisible  => 0,
        Input            => {
            Type => 'Contact',
        }
    }
]"
    );

    # create config items
    # ci with contact and orga (class A)
    my $ContactOrgaCIID = $ConfigItemObject->ConfigItemAdd(
        Number  => '00000000000000001',
        ClassID => $Class_A_ID,
        UserID  => 1,
    );
    $Self->True(
        $ContactOrgaCIID,
        'Create config item (contact/orga)',
    );
    if ($ContactOrgaCIID) {
        my $ContactOrgaVersionID = $ConfigItemObject->VersionAdd(
            ConfigItemID => $ContactOrgaCIID,
            Name         => 'ContactOrgaCI - 1st version',
            DefinitionID => $Class_A_Def_ID,
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
                                            Content => $CustomerContact{PrimaryOrganisationID},
                                        }
                                    ],
                                    OwnerContact => [
                                        undef,
                                        {
                                            Content => $CustomerContactID,
                                        },
                                        {
                                            Content => 1,
                                        }
                                    ]
                                }
                            ]
                        }
                    ]
                }
            ]
        );
        $Self->True(
            $ContactOrgaVersionID,
            'Create version (contact/orga)',
        );
    }

    # ci with just orga (class A)
    my $OrgaCIID = $ConfigItemObject->ConfigItemAdd(
        Number  => '00000000000000002',
        ClassID => $Class_A_ID,
        UserID  => 1,
    );
    $Self->True(
        $OrgaCIID,
        'Create config item (orga)',
    );
    if ($OrgaCIID) {
        my $OrgaVersionID = $ConfigItemObject->VersionAdd(
            ConfigItemID => $OrgaCIID,
            Name         => 'OrgaCI - 1st version',
            DefinitionID => $Class_A_Def_ID,
            DeplStateID  => $DeplStateListReverse{Repair},
            InciStateID  => $InciStateListReverse{Incident},
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
                                            Content => $CustomerContact{PrimaryOrganisationID},
                                        }
                                    ]
                                }
                            ]
                        }
                    ]
                }
            ]
        );
        $Self->True(
            $OrgaVersionID,
            'Create version (orga)',
        );
    }

    # ci with just contact (class B)
    my $ContactCIID = $ConfigItemObject->ConfigItemAdd(
        Number  => '00000000000000003',
        ClassID => $Class_B_ID,
        UserID  => 1,
    );
    $Self->True(
        $ContactCIID,
        'Create config item (contact)',
    );
    if ($ContactCIID) {
        my $ContactVersionID = $ConfigItemObject->VersionAdd(
            ConfigItemID => $ContactCIID,
            Name         => 'ContactCI - 1st version',
            DefinitionID => $Class_B_Def_ID,
            DeplStateID  => $DeplStateListReverse{Production},
            InciStateID  => $InciStateListReverse{Operational},
            UserID       => 1,
            XMLData      => [
                undef,
                {
                    Version => [
                        undef,
                        {
                            OwnerContact => [
                                undef,
                                {
                                    Content => $CustomerContactID,
                                }
                            ]
                        }
                    ]
                }
            ]
        );
        $Self->True(
            $ContactVersionID,
            'Create version (contact)',
        );
    }

    return (
        ClassAName      => $ClassAName,
        ClassBName      => $ClassBName,
        Class_B_Def_ID  => $Class_B_Def_ID,
        ContactOrgaCIID => $ContactOrgaCIID,
        OrgaCIID        => $OrgaCIID,
        ContactCIID     => $ContactCIID,
        CustomerContact => \%CustomerContact
    );
}

sub _CheckConfig {

    # contact or orga for class A
    _SetConfig(
        'contact and orga config for class A',
        '{
            "Contact": {
                "'.$TestData{ClassAName}.'": {
                    "SectionOwner::OwnerContact": {
                        "SearchAttributes": [
                            "ID"
                        ]
                    },
                    "SectionOwner::OwnerOrganisation": {
                        "SearchAttributes": [
                            "PrimaryOrganisationID"
                        ]
                    }
                }
            }
        }',
        1
    );
    my $ContactOrgaCIIDList = $ConfigItemObject->GetAssignedConfigItemsForObject(
        ObjectType => 'Contact',
        Object     => $TestData{CustomerContact},
        UserID     => 1
    );
    $Self->Is(
        scalar(@{$ContactOrgaCIIDList}),
        2,
        'Asset list should contain 2 asset [contact/orga]',
    );
    $Self->ContainedIn(
        $TestData{ContactOrgaCIID},
        $ContactOrgaCIIDList,
        'List should contain CI with matching contact and orga [contact/orga]',
    );
    $Self->ContainedIn(
        $TestData{OrgaCIID},
        $ContactOrgaCIIDList,
        'List should contain CI with matching orga [contact/orga]',
    );
    $Self->NotContainedIn(
        $TestData{ContactCIID},
        $ContactOrgaCIIDList,
        'List should NOT contain a CI of other class [contact/orga]',
    );

    # only contact for both classes
    _SetConfig(
        'contact for both classes',
        '{
            "Contact": {
                "'.$TestData{ClassAName}.'": {
                    "SectionOwner::OwnerContact": {
                        "SearchAttributes": [
                            "ID"
                        ]
                    }
                },
                "'.$TestData{ClassBName}.'": {
                    "OwnerContact": {
                        "SearchAttributes": [
                            "ID"
                        ]
                    }
                }
            }
        }'
    );
    my $ContactCIIDList = $ConfigItemObject->GetAssignedConfigItemsForObject(
        ObjectType => 'Contact',
        Object     => $TestData{CustomerContact},
        UserID     => 1
    );
    $Self->Is(
        scalar(@{$ContactCIIDList}),
        2,
        'Asset list should contain 2 asset [contact]',
    );
    $Self->ContainedIn(
        $TestData{ContactOrgaCIID},
        $ContactCIIDList,
        'List should contain CI with matching contact and orga [contact]',
    );
    $Self->ContainedIn(
        $TestData{ContactCIID},
        $ContactCIIDList,
        'List should contain a CI of other class with matching contact [contact]',
    );
    $Self->NotContainedIn(
        $TestData{OrgaCIID},
        $ContactCIIDList,
        'List should NOT contain CI with orga [contact]',
    );

    # add second version to "ContactCI" (only accept matches in current version)
    my $VersionID = $ConfigItemObject->VersionAdd(
        ConfigItemID => $TestData{ContactCIID},
        Name         => 'ContactCI - 2nd version',
        DefinitionID => $TestData{Class_B_Def_ID},
        DeplStateID  => $DeplStateListReverse{Production},
        InciStateID  => $InciStateListReverse{Operational},
        UserID       => 1,
        XMLData      => [
            undef,
            {
                Version => [
                    undef,
                    {
                        OwnerContact => [
                            undef,
                            {
                                Content => 1,  # other contact id - it should not match anymore
                            }
                        ]
                    }
                ]
            }
        ]
    );
    $Self->True(
        $VersionID,
        'Create version (contact - 2nd version)',
    );
    $ContactCIIDList = $ConfigItemObject->GetAssignedConfigItemsForObject(
        ObjectType => 'Contact',
        Object     => $TestData{CustomerContact},
        UserID     => 1
    );
    $Self->Is(
        scalar(@{$ContactCIIDList}),
        1,
        'Asset list should contain 2 asset [contact v2]',
    );
    $Self->ContainedIn(
        $TestData{ContactOrgaCIID},
        $ContactCIIDList,
        'List should contain CI with matching contact and orga [contact v2]',
    );
    $Self->NotContainedIn(
        $TestData{ContactCIID},
        $ContactCIIDList,
        'List should NOT contain a CI of other class with matching contact (current version should not match) [contact v2]',
    );
    $Self->NotContainedIn(
        $TestData{OrgaCIID},
        $ContactCIIDList,
        'List should NOT contain CI with orga [contact v2]',
    );

    # only contact for both classes - static (without object)
    _SetConfig(
        'contact for both classes - static',
        '{
            "Contact": {
                "'.$TestData{ClassAName}.'": {
                    "SectionOwner::OwnerContact": {
                        "SearchStatic": [
                            1
                        ]
                    }
                },
                "'.$TestData{ClassBName}.'": {
                    "OwnerContact": {
                        "SearchStatic": [
                            1
                        ]
                    }
                }
            }
        }'
    );
    $ContactCIIDList = $ConfigItemObject->GetAssignedConfigItemsForObject(
        ObjectType => 'Contact',
        # Object     => $TestData{CustomerContact}, ignore object, should not be required, if static used
        UserID     => 1
    );
    $Self->Is(
        scalar(@{$ContactCIIDList}),
        2,
        'Asset list should contain 2 asset [contact static]',
    );
    $Self->ContainedIn(
        $TestData{ContactOrgaCIID},
        $ContactCIIDList,
        'List should contain CI with matching contact and orga [contact static]',
    );
    $Self->ContainedIn(
        $TestData{ContactCIID},
        $ContactCIIDList,
        'List should contain a CI of other class with matching contact [contact static]',
    );
    $Self->NotContainedIn(
        $TestData{OrgaCIID},
        $ContactCIIDList,
        'List should NOT contain CI with orga [contact static]',
    );

    # check name
    _SetConfig(
        'contact for both classes - static',
        '{
            "Contact": {
                "'.$TestData{ClassAName}.'": {
                    "Name": {
                        "SearchStatic": [
                            "OrgaCI*"
                        ]
                    }
                }
            }
        }'
    );
    $ContactCIIDList = $ConfigItemObject->GetAssignedConfigItemsForObject(
        ObjectType => 'Contact',
        # Object     => $TestData{CustomerContact}, ignore object, should not be required, if static used
        UserID     => 1
    );
    $Self->Is(
        scalar(@{$ContactCIIDList}),
        1,
        'Asset list should contain 1 asset [name static]',
    );
    $Self->ContainedIn(
        $TestData{OrgaCIID},
        $ContactCIIDList,
        'List should contain CI with matching name [name static]',
    );
    $Self->NotContainedIn(
        $TestData{ContactOrgaCIID},
        $ContactCIIDList,
        'List should NOT contain CI with contact and orga [name static]',
    );

    # check name - not as list
    _SetConfig(
        'contact for class A - static name',
        '{
            "Contact": {
                "'.$TestData{ClassAName}.'": {
                    "Name": {
                        "SearchStatic": "ContactOrgaCI*"
                    }
                }
            }
        }'
    );
    $ContactCIIDList = $ConfigItemObject->GetAssignedConfigItemsForObject(
        ObjectType => 'Contact',
        # Object     => $TestData{CustomerContact}, ignore object, should not be required, if static used
        UserID     => 1
    );
    $Self->Is(
        scalar(@{$ContactCIIDList}),
        1,
        'Asset list should contain 1 asset [name static simple]',
    );
    $Self->ContainedIn(
        $TestData{ContactOrgaCIID},
        $ContactCIIDList,
        'List should contain CI with matching name [name static simple]',
    );
    $Self->NotContainedIn(
        $TestData{OrgaCIID},
        $ContactCIIDList,
        'List should NOT contain CI with only orga [name static simple]',
    );

    # check deployment state
    _SetConfig(
        'contact for class A - static deployment state',
        '{
            "Contact": {
                "'.$TestData{ClassAName}.'": {
                    "DeploymentState": {
                        "SearchStatic": [
                            "Repair"
                        ]
                    }
                }
            }
        }'
    );
    $ContactCIIDList = $ConfigItemObject->GetAssignedConfigItemsForObject(
        ObjectType => 'Contact',
        # Object     => $TestData{CustomerContact}, ignore object, should not be required, if static used
        UserID     => 1
    );
    $Self->Is(
        scalar(@{$ContactCIIDList}),
        1,
        'Asset list should contain 1 asset [deployment state static]',
    );
    $Self->ContainedIn(
        $TestData{OrgaCIID},
        $ContactCIIDList,
        'List should contain CI with matching deployment state [deployment state static]',
    );
    $Self->NotContainedIn(
        $TestData{ContactOrgaCIID},
        $ContactCIIDList,
        'List should NOT contain CI with contact and orga [deployment state static]',
    );

    # check incident state
    _SetConfig(
        'contact for class A - static incident state',
        '{
            "Contact": {
                "'.$TestData{ClassAName}.'": {
                    "IncidentState": {
                        "SearchStatic": [
                            "Incident"
                        ]
                    }
                }
            }
        }'
    );
    $ContactCIIDList = $ConfigItemObject->GetAssignedConfigItemsForObject(
        ObjectType => 'Contact',
        # Object     => $TestData{CustomerContact}, ignore object, should not be required, if static used
        UserID     => 1
    );
    $Self->Is(
        scalar(@{$ContactCIIDList}),
        1,
        'Asset list should contain 1 asset [incident state static]',
    );
    $Self->ContainedIn(
        $TestData{OrgaCIID},
        $ContactCIIDList,
        'List should contain CI with matching incident state [incident state static]',
    );
    $Self->NotContainedIn(
        $TestData{ContactOrgaCIID},
        $ContactCIIDList,
        'List should NOT contain CI with contact and orga [incident state static]',
    );
}

sub _DoNegativeTests {

    # negative (unknown attribute) ---------------------------
    _SetConfig(
        'unknown attribute',
        '{
            "Contact": {
                "'.$TestData{ClassAName}.'": {
                    "UnknownAttribute": {
                        "SearchStatic": [
                            1
                        ]
                    }
                }
            }
        }'
    );
    my $CIIDList = $ConfigItemObject->GetAssignedConfigItemsForObject(
        ObjectType => 'Contact',
        UserID     => 1
    );
    $Self->Is(
        scalar(@{$CIIDList}),
        0,
        'Asset list should be empty [unknown attribute]',
    );

    # negative (known attribute but wrong class / wrong structure) ---------------------------
    _SetConfig(
        'known attribute but wrong class / wrong structure',
        '{
            "Contact": {
                "'.$TestData{ClassBName}.'": {
                    "SectionOwner::OwnerContact": {
                        "SearchStatic": [
                            1
                        ]
                    }
                }
            }
        }'
    );
    $CIIDList = $ConfigItemObject->GetAssignedConfigItemsForObject(
        ObjectType => 'Contact',
        UserID     => 1
    );
    $Self->Is(
        scalar(@{$CIIDList}),
        0,
        'Asset list should be empty [known attribute but wrong class / wrong structure]',
    );

    # negative (known attribute but unknown class) ---------------------------
    _SetConfig(
        'known attribute but unknown class',
        '{
            "Contact": {
                "UnkownClass": {
                    "SectionOwner::OwnerContact": {
                        "SearchStatic": [
                            1
                        ]
                    }
                }
            }
        }'
    );
    $CIIDList = $ConfigItemObject->GetAssignedConfigItemsForObject(
        ObjectType => 'Contact',
        UserID     => 1
    );
    $Self->Is(
        scalar(@{$CIIDList}),
        0,
        'Asset list should be empty [known attribute but unknwon class]',
    );

    # negative (missing object type) ---------------------------
    _SetConfig(
        'missing object type',
        '{
            "SomeOtherObject": {
                "'.$TestData{ClassAName}.'": {
                    "SectionOwner::OwnerContact": {
                        "SearchStatic": [
                            1
                        ]
                    }
                }
            }
        }'
    );
    $CIIDList = $ConfigItemObject->GetAssignedConfigItemsForObject(
        ObjectType => 'Contact',
        UserID     => 1
    );
    $Self->Is(
        scalar(@{$CIIDList}),
        0,
        'Asset list should be empty [missing object type]',
    );

    # negative (empty object type config) ---------------------------
    _SetConfig(
        'empty object type config',
        '{
            "Contact": {}
        }'
    );
    $CIIDList = $ConfigItemObject->GetAssignedConfigItemsForObject(
        ObjectType => 'Contact',
        UserID     => 1
    );
    $Self->Is(
        scalar(@{$CIIDList}),
        0,
        'Asset list should be empty [empty object type config]',
    );

    # negative (empty class config) ---------------------------
    _SetConfig(
        'empty class config',
        '{
            "Contact": {
                "'.$TestData{ClassAName}.'": {}
            }
        }'
    );
    $CIIDList = $ConfigItemObject->GetAssignedConfigItemsForObject(
        ObjectType => 'Contact',
        UserID     => 1
    );
    $Self->Is(
        scalar(@{$CIIDList}),
        0,
        'Asset list should be empty [empty class config]',
    );

    # negative (empty attribute) ---------------------------
    _SetConfig(
        'empty attribute',
        '{
            "Contact": {
                "'.$TestData{ClassAName}.'": {
                    "SectionOwner::OwnerContact": {}
                }
            }
        }'
    );
    $CIIDList = $ConfigItemObject->GetAssignedConfigItemsForObject(
        ObjectType => 'Contact',
        UserID     => 1
    );
    $Self->Is(
        scalar(@{$CIIDList}),
        0,
        'Asset list should be empty [empty attribute]',
    );

    # negative (empty value) ---------------------------
    _SetConfig(
        'empty value',
        '{
            "Contact": {
                "'.$TestData{ClassAName}.'": {
                    "SectionOwner::OwnerContact": {
                        "SearchStatic": []
                    }
                }
            }
        }'
    );
    $CIIDList = $ConfigItemObject->GetAssignedConfigItemsForObject(
        ObjectType => 'Contact',
        UserID     => 1
    );
    $Self->Is(
        scalar(@{$CIIDList}),
        0,
        'Asset list should be empty [empty value]',
    );

    # negative (empty config) ---------------------------
    _SetConfig(
        'empty class config',
        ''
    );
    $CIIDList = $ConfigItemObject->GetAssignedConfigItemsForObject(
        ObjectType => 'Contact',
        UserID     => 1
    );
    $Self->Is(
        scalar(@{$CIIDList}),
        0,
        'Asset list should be empty [empty config]',
    );

    # negative (invalid config, missing " and unnecessary ,) ---------------------------
    _SetConfig(
        'invalid config',
        '{
            "Contact": {
                "'.$TestData{ClassAName}.'": {
                    "SectionOwner::OwnerContact": {
                        SearchStatic: [
                            1
                        ]
                    }
                },
            }
        }'
    );
    $CIIDList = $ConfigItemObject->GetAssignedConfigItemsForObject(
        ObjectType => 'Contact',
        UserID     => 1
    );
    $Self->Is(
        scalar(@{$CIIDList}),
        0,
        'Asset list should be empty [invalid config]',
    );

    # check unknown deployment state
    _SetConfig(
        'unknown deployment state',
        '{
            "Contact": {
                "'.$TestData{ClassAName}.'": {
                    "DeploymentState": {
                        "SearchStatic": [
                            "Production",
                            "Unknown"
                        ]
                    }
                }
            }
        }'
    );
    $CIIDList = $ConfigItemObject->GetAssignedConfigItemsForObject(
        ObjectType => 'Contact',
        UserID     => 1
    );
    $Self->Is(
        scalar(@{$CIIDList}),
        0,
        'Asset list should be empty [unknown DeploymentState]',
    );
}

sub _SetConfig {
    my ($Name, $Config, $DoCheck) = @_;

    $ConfigObject->Set(
        Key   => 'AssignedConfigItemsMapping',
        Value => $Config,
    );

    # check config
    if ($DoCheck) {
        my $MappingString = $ConfigObject->Get('AssignedConfigItemsMapping');
        $Self->True(
            IsStringWithData($MappingString) || 0,
            "AssignedConfigItemsMapping - get config string ($Name)",
        );

        my $NewConfig = 0;
        if ($MappingString && $MappingString eq $Config) {
            $NewConfig = 1;
        }
        $Self->True(
            $NewConfig,
            "AssignedConfigItemsMapping - mapping is new value",
        );
    }
}

# cleanup is done by RestoreDatabase

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
