# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
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
my $TimeObject    = $Kernel::OM->Get('Time');

# get actual needed objects
my $ConfigObject       = $Kernel::OM->Get('Config');
my $ContactObject      = $Kernel::OM->Get('Contact');
my $DynamicFieldObject = $Kernel::OM->Get('DynamicField');
my $DFBackendObject    = $Kernel::OM->Get('DynamicField::Backend');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# prepare test data
my %TestData = _PrepareData();
my $ContactIDs = [
    $TestData{CustomerContact}->{ID},
    $TestData{OrgaContactID},
    $TestData{ContextContactID}
];

_CheckByOrgaIDs();

_CheckByContext();

_CheckByCity();

_CheckByDynamicField();

_DoNegativeTests();

# rollback transaction on database
$Helper->Rollback();

sub _PrepareData {

    # create customer orga
    my $CustomerOrga = 'CustomerOrga' . $Helper->GetRandomID();
    my $CustomerOrgaID = $Kernel::OM->Get('Organisation')->OrganisationAdd(
        Number  => $CustomerOrga,
        Name    => $CustomerOrga,
        ValidID => 1,
        UserID  => 1,
    );
    $Self->True(
        $CustomerOrgaID,
        'CustomerOrgaCreate',
    );

    # create customer user
    my $CustomerContact = 'CustomerContact' . $Helper->GetRandomID();
    my $CustomerContactCity = 'CustomerContactCity';
    my $CustomerContactID = $Kernel::OM->Get('Contact')->ContactAdd(
        Firstname             => $CustomerContact,
        Lastname              => $CustomerContact,
        PrimaryOrganisationID => $CustomerOrgaID,
        OrganisationIDs       => [ $CustomerOrgaID ],
        City                  => $CustomerContactCity,
        ValidID               => 1,
        UserID                => 1,
    );
    $Self->True(
        $CustomerContactID,
        'CustomerContactCreate',
    );
    my %CustomerContact = $ContactObject->ContactGet(ID => $CustomerContactID);
    if (!IsHashRefWithData(\%CustomerContact)) {
        $Self->True(
            0, 'CustomerContactCreate - ContactGet',
        );
    } else {
        # remember relevant organisation id
        $CustomerContact{RelevantOrganisationID} = $CustomerOrgaID
    }

    # create other contacts
    my $OrgaContactID = $Kernel::OM->Get('Contact')->ContactAdd(
        Firstname             => $CustomerContact . 'OrgaTest',
        Lastname              => $CustomerContact . 'OrgaTest',
        PrimaryOrganisationID => $CustomerOrgaID,
        OrganisationIDs       => [ $CustomerOrgaID ],
        City                  => $CustomerContactCity,
        ValidID               => 1,
        UserID                => 1,
    );
    $Self->True(
        $OrgaContactID,
        'OrgaContactCreate',
    );

    my $ContextContactUserID = $Kernel::OM->Get('User')->UserAdd(
        UserLogin    => $CustomerContact . 'ContextTest',
        UserPw       => $CustomerContact . 'ContextTest',
        ValidID      => 1,
        ChangeUserID => 1,
        IsCustomer   => 1,
    );
    $Self->True(
        $ContextContactUserID,
        'ContextContactUserCreate',
    );
    my $ContextContactID = $Kernel::OM->Get('Contact')->ContactAdd(
        Firstname             => $CustomerContact . 'ContextTest',
        Lastname              => $CustomerContact . 'ContextTest',
        PrimaryOrganisationID => undef,
        OrganisationIDs       => [],
        City                  => $CustomerContactCity,
        AssignedUserID        => $ContextContactUserID,
        ValidID               => 1,
        UserID                => 1,
    );
    $Self->True(
        $OrgaContactID,
        'OrgaContactCreate',
    );

    my $DFName  = 'CustomerAssignedContactsSelection';
    my $DFValue = 'Key';
    my $SelectionDynamicFieldID = $DynamicFieldObject->DynamicFieldAdd(
        Name            => $DFName,
        Label           => $DFName,
        InternalField   => 1,
        FieldType       => 'Multiselect',
        ObjectType      => 'Contact',
        Config          => {
            PossibleValues => {
                $DFValue =>  'Value',
                'Key2'   =>  'Value2'
            }
        },
        CustomerVisible => 1,
        ValidID         => 1,
        UserID          => 1,
    );
    $Self->True(
        $SelectionDynamicFieldID,
        'Create SelectionDynamicField',
    );
    my $SelectionDynamicField = $DynamicFieldObject->DynamicFieldGet(
        ID => $SelectionDynamicFieldID,
    );
    $Self->True(
        IsHashRefWithData($SelectionDynamicField) || 0,
        'Get SelectionDynamicField',
    );
    if (IsHashRefWithData($SelectionDynamicField)) {
        my $Success = $DFBackendObject->ValueSet(
            DynamicFieldConfig => $SelectionDynamicField,
            ObjectID           => $ContextContactID,
            Value              => [$DFValue],
            UserID             => 1,
        );
    }

    return (
        CustomerContact  => \%CustomerContact,
        OrgaContactID    => $OrgaContactID,
        ContextContactID => $ContextContactID,
        City             => $CustomerContactCity,
        DFName           => $DFName,
        DFValue          => $DFValue
    );
}

sub _CheckByOrgaIDs {
    _SetConfig(
        'OrgaIDs check',
        <<"END",
{
    "Contact": {
        "Contact": {
            "OrganisationIDs": {
                "SearchAttributes": [
                    "RelevantOrganisationID"
                ]
            }
        }
    }
}
END
        1
    );

    my $ContactIDList = $ContactObject->GetAssignedContactsForObject(
        ObjectType   => 'Contact',
        Object       => $TestData{CustomerContact},
        UserID       => 1,
        Silent       => 1
    );

    # only contacts which are created by this test
    my @RelevantResult = $Kernel::OM->Get('Main')->GetCombinedList(
        ListA => $ContactIDs,
        ListB => $ContactIDList,
        Union => 0
    );
    $Self->IsDeeply(
        \@RelevantResult,
        [
            $TestData{CustomerContact}->{ID},
            $TestData{OrgaContactID}
        ],
        'List contains correct contacts (OrgaIDs check)',
        1
    );

    return 1;
}

sub _CheckByContext {
    _SetConfig(
        'Context check',
        <<"END",
{
    "Contact": {
        "Contact": {
            "IsCustomer": {
                "SearchStatic": [
                    "1"
                ]
            }
        }
    }
}
END
        1
    );

    my $ContactIDList = $ContactObject->GetAssignedContactsForObject(
        ObjectType   => 'Contact',
        Object       => $TestData{CustomerContact},
        UserID       => 1,
        Silent       => 1
    );

    # only contacts which are created by this test
    my @RelevantResult = $Kernel::OM->Get('Main')->GetCombinedList(
        ListA => $ContactIDs,
        ListB => $ContactIDList,
        Union => 0
    );
    $Self->IsDeeply(
        \@RelevantResult,
        [
            $TestData{ContextContactID}
        ],
        'List contains correct contacts (Context check)',
        1
    );

    return 1;
}

sub _CheckByCity {
    _SetConfig(
        'City check',
        <<"END"
{
    "Contact": {
        "Contact": {
            "City": {
                "SearchStatic": [
                    "$TestData{City}"
                ]
            }
        }
    }
}
END
    );

    my $ContactIDList = $ContactObject->GetAssignedContactsForObject(
        ObjectType   => 'Contact',
        Object       => $TestData{CustomerContact},
        UserID       => 1,
        Silent       => 1
    );

    # only contacts which are created by this test
    my @RelevantResult = $Kernel::OM->Get('Main')->GetCombinedList(
        ListA => $ContactIDs,
        ListB => $ContactIDList,
        Union => 0
    );
    $Self->IsDeeply(
        \@RelevantResult,
        [
            $TestData{CustomerContact}->{ID},
            $TestData{OrgaContactID},
            $TestData{ContextContactID}
        ],
        'List contains correct contacts (City check)',
        1
    );

    return 1;
}

sub _CheckByDynamicField {
    _SetConfig(
        'DF check',
        <<"END"
{
    "Contact": {
        "Contact": {
            "DynamicField_$TestData{DFName}": {
                "SearchStatic": [
                    "$TestData{DFValue}"
                ]
            }
        }
    }
}
END
    );

    my $ContactIDList = $ContactObject->GetAssignedContactsForObject(
        ObjectType   => 'Contact',
        Object       => $TestData{CustomerContact},
        UserID       => 1,
        Silent       => 1
    );

    # only contacts which are created by this test
    my @RelevantResult = $Kernel::OM->Get('Main')->GetCombinedList(
        ListA => $ContactIDs,
        ListB => $ContactIDList,
        Union => 0
    );
    $Self->IsDeeply(
        \@RelevantResult,
        [
            $TestData{ContextContactID}
        ],
        'List contains correct contacts (DF check)',
        1
    );

    return 1;
}

sub _DoNegativeTests {

    # negative (object value, without object) ---------------------------
    _SetConfig(
        'negative (object dependent config without object)',
        <<"END"
{
    "Contact": {
        "Contact": {
            "ContactID": {
                "SearchAttributes": [
                    "ContactID"
                ]
            }
        }
    }
}
END
    );
    my $ContactIDList = $ContactObject->GetAssignedContactsForObject(
        ObjectType => 'Contact',
        UserID     => 1,
        Silent     => 1
    );
    $Self->Is(
        scalar(@{$ContactIDList}),
        0,
        'list should be empty (missing object)',
    );

    # negative (unknown attribute) ---------------------------
    _SetConfig(
        'negative (unknown attribute)',
        <<"END"
{
    "Contact": {
        "Contact": {
            "UnknownID": {
                "SearchStatic": [
                    5
                ]
            }
        }
    }
}
END
    );
    $ContactIDList = $ContactObject->GetAssignedContactsForObject(
        ObjectType   => 'Contact',
        Object       => $TestData{CustomerContact},
        UserID       => 1,
        Silent       => 1
    );
    $Self->Is(
        scalar(@{$ContactIDList}),
        0,
        'list should be empty (unknown attribute)',
    );

    # negative (missing objecttype config) ---------------------------
    _SetConfig(
        'negative (missing objecttype config',
        <<"END"
{
    "Organisation": {
        "Contact": {
            "ContactID": {
                "SearchAttributes": [
                    "ContactID"
                ]
            }
        }
    }
}
END
    );
    $ContactIDList = $ContactObject->GetAssignedContactsForObject(
        ObjectType   => 'Contact',
        Object       => $TestData{CustomerContact},
        UserID       => 1,
        Silent       => 1
    );
    $Self->Is(
        scalar(@{$ContactIDList}),
        0,
        'list should be empty (missing objecttype config)',
    );

    # negative (missing contact config) ---------------------------
    _SetConfig(
        'negative (missing contact config)',
        <<"END"
{
    "Contact": {
        "SomeOtherObject": {
            "ContactID": {
                "SearchAttributes": [
                    "ContactID"
                ]
            }
        }
    }
}
END
    );
    $ContactIDList = $ContactObject->GetAssignedContactsForObject(
        ObjectType   => 'Contact',
        Object       => $TestData{CustomerContact},
        UserID       => 1,
        Silent       => 1
    );
    $Self->Is(
        scalar(@{$ContactIDList}),
        0,
        'list should be empty (missing contact config)',
    );

    # negative (empty contact config) ---------------------------
    _SetConfig(
        'negative (empty contact config)',
        <<"END"
{
    "Contact": {
        "Contact": {}
    }
}
END
    );
    $ContactIDList = $ContactObject->GetAssignedContactsForObject(
        ObjectType   => 'Contact',
        Object       => $TestData{CustomerContact},
        UserID       => 1,
        Silent       => 1
    );
    $Self->Is(
        scalar(@{$ContactIDList}),
        0,
        'list should be empty (empty contact config)',
    );

    # negative (empty attribute) ---------------------------
    _SetConfig(
        'negative (empty attribute)',
        <<"END"
{
    "Contact": {
        "Contact": {
            "ContactID": {}
        }
    }
}
END
    );
    $ContactIDList = $ContactObject->GetAssignedContactsForObject(
        ObjectType   => 'Contact',
        Object       => $TestData{CustomerContact},
        UserID       => 1,
        Silent       => 1
    );
    $Self->Is(
        scalar(@{$ContactIDList}),
        0,
        'list should be empty (empty attribute)',
    );

    # negative (empty value) ---------------------------
    _SetConfig(
        'negative (empty value)',
        <<"END"
{
    "Contact": {
        "Contact": {
            "ContactID": {
                "SearchStatic": []
            }
        }
    }
}
END
    );
    $ContactIDList = $ContactObject->GetAssignedContactsForObject(
        ObjectType   => 'Contact',
        Object       => $TestData{CustomerContact},
        UserID       => 1,
        Silent       => 1
    );
    $Self->Is(
        scalar(@{$ContactIDList}),
        0,
        'list should be empty (empty value)',
    );

    # negative (empty config) ---------------------------
    _SetConfig(
        'negative (empty config)',
        q{}
    );
    $ContactIDList = $ContactObject->GetAssignedContactsForObject(
        ObjectType   => 'Contact',
        Object       => $TestData{CustomerContact},
        UserID       => 1,
        Silent       => 1
    );
    $Self->Is(
        scalar(@{$ContactIDList}),
        0,
        'list should be empty (empty config)',
    );

    # negative (invalid config, missing " and unnecessary ,) ---------------------------
    _SetConfig(
        'negative (invalid config)',
        <<"END"
{
    "Contact": {
        "Contact": {
            "ContactID": {
                SearchStatic: [
                    $TestData{OrgaContactID}
                ]
            },
        },
    }
}
END
    );
    $ContactIDList = $ContactObject->GetAssignedContactsForObject(
        ObjectType   => 'Contact',
        Object       => $TestData{CustomerContact},
        UserID       => 1,
        Silent       => 1
    );
    $Self->Is(
        scalar(@{$ContactIDList}),
        0,
        'list should be empty (invalid config)',
    );

    return 1;
}

sub _SetConfig {
    my ($Name, $Config, $DoCheck) = @_;

    $ConfigObject->Set(
        Key   => 'AssignedObjectsMapping',
        Value => $Config,
    );

    # check config
    if ($DoCheck) {
        my $MappingString = $ConfigObject->Get('AssignedObjectsMapping');
        $Self->True(
            IsStringWithData($MappingString) || 0,
            "AssignedObjectsMapping - get config string ($Name)",
        );

        my $NewConfig = 0;
        if ($MappingString && $MappingString eq $Config) {
            $NewConfig = 1;
        }
        $Self->True(
            $NewConfig,
            "AssignedObjectsMapping - mapping is new value",
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
