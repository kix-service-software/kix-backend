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

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

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

# prepare test data
my %TestData = _PrepareData();

_CheckConfig();

_DoNegativeTests();

# rollback transaction on database
$Helper->Rollback();

sub _PrepareData {

    # create customer user
    my $CustomerContactID = $Helper->TestContactCreate();
    $Self->True(
        $CustomerContactID,
        'CustomerContactCreate',
    );
    my %CustomerContact = $Kernel::OM->Get('Contact')->ContactGet(ID => $CustomerContactID, UserID => 1);
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
    my $Class_A_ID = $Kernel::OM->Get('GeneralCatalog')->ItemAdd(
        Class    => 'ITSM::ConfigItem::Class',
        Name     => $ClassAName,
        Comment  => q{},
        ValidID  => 1,
        UserID   => 1
    );
    $Self->True(
        $Class_A_ID,
        'Create class A',
    );
    my $Class_A_Def_ID = $Kernel::OM->Get('ITSMConfigItem')->DefinitionAdd(
        ClassID    => $Class_A_ID,
        UserID     => 1,
        UsertType  => 'Agent',
        Definition => <<'END'
[
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
]
END
    );

    $Kernel::OM->ObjectsDiscard(
        Objects => [
            'GeneralCatalog',
            'ITSMConfigItem'
        ]
    );

    my $ClassBName = 'Class B';
    my $Class_B_ID = $Kernel::OM->Get('GeneralCatalog')->ItemAdd(
        Class    => 'ITSM::ConfigItem::Class',
        Name     => $ClassBName,
        Comment  => q{},
        ValidID  => 1,
        UserID   => 1
    );
    $Self->True(
        $Class_B_ID,
        'Create class B',
    );
    my $Class_B_Def_ID = $Kernel::OM->Get('ITSMConfigItem')->DefinitionAdd(
        ClassID    => $Class_B_ID,
        UserID     => 1,
        UsertType  => 'Agent',
        Definition => <<'END'
[
    {
        Key              => 'OwnerContact',
        Name             => 'Assigned Contact',
        Searchable       => 1,
        CustomerVisible  => 0,
        Input            => {
            Type => 'Contact',
        }
    }
]
END
    );

    $Kernel::OM->ObjectsDiscard(
        Objects => [
            'GeneralCatalog',
            'ITSMConfigItem'
        ]
    );

    # create config items
    # ci with contact and orga (class A)
    my $ContactOrgaCIID = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
        Number  => $Helper->GetRandomNumber(),
        ClassID => $Class_A_ID,
        UserID  => 1,
    );
    $Self->True(
        $ContactOrgaCIID,
        'Create config item (contact/orga)',
    );
    if ($ContactOrgaCIID) {
        my $ContactOrgaVersionID = $Kernel::OM->Get('ITSMConfigItem')->VersionAdd(
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

    $Kernel::OM->ObjectsDiscard(
        Objects => [
            'ITSMConfigItem'
        ]
    );
    # ci with just orga (class A)
    my $OrgaCIID = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
        Number  => $Helper->GetRandomNumber(),
        ClassID => $Class_A_ID,
        UserID  => 1,
    );
    $Self->True(
        $OrgaCIID,
        'Create config item (orga)',
    );
    if ($OrgaCIID) {
        my $OrgaVersionID = $Kernel::OM->Get('ITSMConfigItem')->VersionAdd(
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

    $Kernel::OM->ObjectsDiscard(
        Objects => [
            'ITSMConfigItem'
        ]
    );

    # ci with just contact (class B)
    my $ContactCIID = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
        Number  => $Helper->GetRandomNumber(),
        ClassID => $Class_B_ID,
        UserID  => 1,
    );
    $Self->True(
        $ContactCIID,
        'Create config item (contact)',
    );
    if ($ContactCIID) {
        my $ContactVersionID = $Kernel::OM->Get('ITSMConfigItem')->VersionAdd(
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

    $Kernel::OM->ObjectsDiscard(
        Objects => [
            'ITSMConfigItem'
        ]
    );

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
        <<"END",
{
    "Contact": {
        "$TestData{ClassAName}": {
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
}
END
        1
    );
    my @ContactOrgaCIIDList = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'ConfigItem',
        Result     => 'ARRAY',
        Search     => {
            OR => [
                {
                    Field    => 'AssignedContact'.
                    Operator => 'EQ',
                    Type     => 'NUMERIC',
                    Value    => $TestData{CustomerContact}->{ID}
                },
                {
                    Field    => 'AssignedOrganisation'.
                    Operator => 'EQ',
                    Type     => 'NUMERIC',
                    Value    => $TestData{CustomerContact}->{RelevantOrganisationID}
                        || $TestData{CustomerContact}->{PrimaryOrganisationID}
                }
            ]
        },
        UserID     => 1,
        UsertType  => 'Agent'
    );
    $Self->Is(
        scalar(@ContactOrgaCIIDList),
        2,
        'Article list should contain 2 article [contact/orga]',
    );
    $Self->ContainedIn(
        $TestData{ContactOrgaCIID},
        \@ContactOrgaCIIDList,
        'List should contain CI with matching contact and orga [contact/orga]',
    );
    $Self->ContainedIn(
        $TestData{OrgaCIID},
        \@ContactOrgaCIIDList,
        'List should contain CI with matching orga [contact/orga]',
    );
    $Self->NotContainedIn(
        $TestData{ContactCIID},
        \@ContactOrgaCIIDList,
        'List should NOT contain a CI of other class [contact/orga]',
    );

    # only contact for both classes
    _SetConfig(
        'contact for both classes',
        <<"END"
{
    "Contact": {
        "$TestData{ClassAName}": {
            "SectionOwner::OwnerContact": {
                "SearchAttributes": [
                    "ID"
                ]
            }
        },
        "$TestData{ClassBName}": {
            "OwnerContact": {
                "SearchAttributes": [
                    "ID"
                ]
            }
        }
    }
}
END
    );
    my @ContactCIIDList = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'ConfigItem',
        Result     => 'ARRAY',
        Search     => {
            OR => [
                {
                    Field    => 'AssignedContact'.
                    Operator => 'EQ',
                    Type     => 'NUMERIC',
                    Value    => $TestData{CustomerContact}->{ID}
                },
                {
                    Field    => 'AssignedOrganisation'.
                    Operator => 'EQ',
                    Type     => 'NUMERIC',
                    Value    => $TestData{CustomerContact}->{RelevantOrganisationID}
                        || $TestData{CustomerContact}->{PrimaryOrganisationID}
                }
            ]
        },
        UserID     => 1,
        UsertType  => 'Agent'
    );
    $Self->Is(
        scalar(@ContactCIIDList),
        2,
        'Article list should contain 2 article [contact]',
    );
    $Self->ContainedIn(
        $TestData{ContactOrgaCIID},
        \@ContactCIIDList,
        'List should contain CI with matching contact and orga [contact]',
    );
    $Self->ContainedIn(
        $TestData{ContactCIID},
        \@ContactCIIDList,
        'List should contain a CI of other class with matching contact [contact]',
    );
    $Self->NotContainedIn(
        $TestData{OrgaCIID},
        \@ContactCIIDList,
        'List should NOT contain CI with orga [contact]',
    );

    # add second version to "ContactCI" (only accept matches in current version)
    my $VersionID = $Kernel::OM->Get('ITSMConfigItem')->VersionAdd(
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

    $Kernel::OM->ObjectsDiscard(
        Objects => [
            'ITSMConfigItem'
        ]
    );

    $Self->True(
        $VersionID,
        'Create version (contact - 2nd version)',
    );
    @ContactCIIDList = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'ConfigItem',
        Result     => 'ARRAY',
        Search     => {
            OR => [
                {
                    Field    => 'AssignedContact'.
                    Operator => 'EQ',
                    Type     => 'NUMERIC',
                    Value    => $TestData{CustomerContact}->{ID}
                },
                {
                    Field    => 'AssignedOrganisation'.
                    Operator => 'EQ',
                    Type     => 'NUMERIC',
                    Value    => $TestData{CustomerContact}->{RelevantOrganisationID}
                        || $TestData{CustomerContact}->{PrimaryOrganisationID}
                }
            ]
        },
        UserID     => 1,
        UsertType  => 'Agent'
    );
    $Self->Is(
        scalar(@ContactCIIDList),
        1,
        'Article list should contain 2 article [contact v2]',
    );
    $Self->ContainedIn(
        $TestData{ContactOrgaCIID},
        \@ContactCIIDList,
        'List should contain CI with matching contact and orga [contact v2]',
    );
    $Self->NotContainedIn(
        $TestData{ContactCIID},
        \@ContactCIIDList,
        'List should NOT contain a CI of other class with matching contact (current version should not match) [contact v2]',
    );
    $Self->NotContainedIn(
        $TestData{OrgaCIID},
        \@ContactCIIDList,
        'List should NOT contain CI with orga [contact v2]',
    );

    # only contact for both classes - static (without object)
    _SetConfig(
        'contact for both classes - static',
        <<"END"
{
    "Contact": {
        "$TestData{ClassAName}": {
            "SectionOwner::OwnerContact": {
                "SearchStatic": [
                    1
                ]
            }
        },
        "$TestData{ClassBName}": {
            "OwnerContact": {
                "SearchStatic": [
                    1
                ]
            }
        }
    }
}
END
    );
    @ContactCIIDList = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'ConfigItem',
        Result     => 'ARRAY',
        Search     => {
            OR => [
                {
                    Field    => 'AssignedContact'.
                    Operator => 'EQ',
                    Type     => 'NUMERIC',
                    Value    => q{}
                }
            ]
        },
        UserID     => 1,
        UsertType  => 'Agent'
    );
    $Self->Is(
        scalar(@ContactCIIDList),
        2,
        'Article list should contain 2 article [contact static]',
    );
    $Self->ContainedIn(
        $TestData{ContactOrgaCIID},
        \@ContactCIIDList,
        'List should contain CI with matching contact and orga [contact static]',
    );
    $Self->ContainedIn(
        $TestData{ContactCIID},
        \@ContactCIIDList,
        'List should contain a CI of other class with matching contact [contact static]',
    );
    $Self->NotContainedIn(
        $TestData{OrgaCIID},
        \@ContactCIIDList,
        'List should NOT contain CI with orga [contact static]',
    );
}

sub _DoNegativeTests {

    # negative (unknown attribute) ---------------------------
    _SetConfig(
        'unknown attribute',
        <<"END"
{
    "Contact": {
        "$TestData{ClassAName}": {
            "UnknownAttribute": {
                "SearchStatic": [
                    1
                ]
            }
        }
    }
}
END
    );
    my @CIIDList = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'ConfigItem',
        Result     => 'ARRAY',
        Search     => {
            OR => [
                {
                    Field    => 'AssignedContact'.
                    Operator => 'EQ',
                    Type     => 'NUMERIC',
                    Value    => q{}
                }
            ]
        },
        UserID     => 1,
        UsertType  => 'Agent'
    );
    $Self->Is(
        scalar(@CIIDList),
        0,
        'Article list should be empty [unknown attribute]',
    );

    # negative (known attribute but wrong class / wrong structure) ---------------------------
    _SetConfig(
        'known attribute but wrong class / wrong structure',
        <<"END"
{
    "Contact": {
        "$TestData{ClassBName}": {
            "SectionOwner::OwnerContact": {
                "SearchStatic": [
                    1
                ]
            }
        }
    }
}
END
    );
    @CIIDList = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'ConfigItem',
        Result     => 'ARRAY',
        Search     => {
            OR => [
                {
                    Field    => 'AssignedContact'.
                    Operator => 'EQ',
                    Type     => 'NUMERIC',
                    Value    => q{}
                }
            ]
        },
        UserID     => 1,
        UsertType  => 'Agent'
    );
    $Self->Is(
        scalar(@CIIDList),
        0,
        'Article list should be empty [known attribute but wrong class / wrong structure]',
    );

    # negative (known attribute but unknown class) ---------------------------
    _SetConfig(
        'known attribute but unknown class',
        <<"END"
{
    "Contact": {
        "UnkownClass": {
            "SectionOwner::OwnerContact": {
                "SearchStatic": [
                    1
                ]
            }
        }
    }
}
END
    );
    @CIIDList = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'ConfigItem',
        Result     => 'ARRAY',
        Search     => {
            OR => [
                {
                    Field    => 'AssignedContact'.
                    Operator => 'EQ',
                    Type     => 'NUMERIC',
                    Value    => q{}
                }
            ]
        },
        UserID     => 1,
        UsertType  => 'Agent'
    );
    $Self->Is(
        scalar(@CIIDList),
        0,
        'Article list should be empty [known attribute but unknwon class]',
    );

    # negative (missing object type) ---------------------------
    _SetConfig(
        'missing object type',
        <<"END"
{
    "SomeOtherObject": {
        "$TestData{ClassAName}": {
            "SectionOwner::OwnerContact": {
                "SearchStatic": [
                    1
                ]
            }
        }
    }
}
END
    );
    @CIIDList = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'ConfigItem',
        Result     => 'ARRAY',
        Search     => {
            OR => [
                {
                    Field    => 'AssignedContact'.
                    Operator => 'EQ',
                    Type     => 'NUMERIC',
                    Value    => q{}
                }
            ]
        },
        UserID     => 1,
        UsertType  => 'Agent'
    );
    $Self->Is(
        scalar(@CIIDList),
        0,
        'Article list should be empty [missing object type]',
    );

    # negative (empty object type config) ---------------------------
    _SetConfig(
        'empty object type config',
        <<"END"
{
    "Contact": {}
}
END
    );
    @CIIDList = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'ConfigItem',
        Result     => 'ARRAY',
        Search     => {
            OR => [
                {
                    Field    => 'AssignedContact'.
                    Operator => 'EQ',
                    Type     => 'NUMERIC',
                    Value    => q{}
                }
            ]
        },
        UserID     => 1,
        UsertType  => 'Agent'
    );
    $Self->Is(
        scalar(@CIIDList),
        0,
        'Article list should be empty [empty object type config]',
    );

    # negative (empty class config) ---------------------------
    _SetConfig(
        'empty class config',
        <<"END"
{
    "Contact": {
        "$TestData{ClassAName}": {}
    }
}
END
    );
    @CIIDList = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'ConfigItem',
        Result     => 'ARRAY',
        Search     => {
            OR => [
                {
                    Field    => 'AssignedContact'.
                    Operator => 'EQ',
                    Type     => 'NUMERIC',
                    Value    => q{}
                }
            ]
        },
        UserID     => 1,
        UsertType  => 'Agent'
    );
    $Self->Is(
        scalar(@CIIDList),
        0,
        'Article list should be empty [empty class config]',
    );

    # negative (empty attribute) ---------------------------
    _SetConfig(
        'empty attribute',
        <<"END"
{
    "Contact": {
        "$TestData{ClassAName}": {
            "SectionOwner::OwnerContact": {}
        }
    }
}
END
    );
    @CIIDList = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'ConfigItem',
        Result     => 'ARRAY',
        Search     => {
            OR => [
                {
                    Field    => 'AssignedContact'.
                    Operator => 'EQ',
                    Type     => 'NUMERIC',
                    Value    => q{}
                }
            ]
        },
        UserID     => 1,
        UsertType  => 'Agent'
    );
    $Self->Is(
        scalar(@CIIDList),
        0,
        'Article list should be empty [empty attribute]',
    );

    # negative (empty value) ---------------------------
    _SetConfig(
        'empty value',
        <<"END"
{
    "Contact": {
        "$TestData{ClassAName}": {
            "SectionOwner::OwnerContact": {
                "SearchStatic": []
            }
        }
    }
}
END
    );
    @CIIDList = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'ConfigItem',
        Result     => 'ARRAY',
        Search     => {
            OR => [
                {
                    Field    => 'AssignedContact'.
                    Operator => 'EQ',
                    Type     => 'NUMERIC',
                    Value    => q{}
                }
            ]
        },
        UserID     => 1,
        UsertType  => 'Agent'
    );
    $Self->Is(
        scalar(@CIIDList),
        0,
        'Article list should be empty [empty value]',
    );

    # negative (empty config) ---------------------------
    _SetConfig(
        'empty class config',
        q{}
    );
    @CIIDList = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'ConfigItem',
        Result     => 'ARRAY',
        Search     => {
            OR => [
                {
                    Field    => 'AssignedContact'.
                    Operator => 'EQ',
                    Type     => 'NUMERIC',
                    Value    => q{}
                }
            ]
        },
        UserID     => 1,
        UsertType  => 'Agent'
    );
    $Self->Is(
        scalar(@CIIDList),
        0,
        'Article list should be empty [empty config]',
    );

    # negative (invalid config, missing " and unnecessary ,) ---------------------------
    _SetConfig(
        'invalid config',
        <<"END"
{
    "Contact": {
        "$TestData{ClassAName}": {
            "SectionOwner::OwnerContact": {
                SearchStatic: [
                    1
                ]
            }
        },
    }
}
END
    );
    @CIIDList = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'ConfigItem',
        Result     => 'ARRAY',
        Search     => {
            OR => [
                {
                    Field    => 'AssignedContact'.
                    Operator => 'EQ',
                    Type     => 'NUMERIC',
                    Value    => q{}
                }
            ]
        },
        UserID     => 1,
        UsertType  => 'Agent'
    );
    $Self->Is(
        scalar(@CIIDList),
        0,
        'Article list should be empty [invalid config]',
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
    return 1;
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
