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

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::ConfigItem::Assigned';

# require module
return if ( !$Kernel::OM->Get('Main')->Require( $AttributeModule ) );

# create backend object
my $AttributeObject = $AttributeModule->new( %{ $Self } );
$Self->Is(
    ref( $AttributeObject ),
    $AttributeModule,
    'Attribute object has correct module ref'
);

# check supported methods
for my $Method ( qw(GetSupportedAttributes Search Sort) ) {
    $Self->True(
        $AttributeObject->can($Method),
        'Attribute object can "' . $Method . '"'
    );
}

# check GetSupportedAttributes
my $AttributeList = $AttributeObject->GetSupportedAttributes();
$Self->IsDeeply(
    $AttributeList,
    {
        AssignedContact => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','IN'],
            ValueType    => 'NUMERIC'
        },
        AssignedOrganisation => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','IN'],
            ValueType    => 'NUMERIC'
        }
    },
    'GetSupportedAttributes provides expected data'
);

# begin transaction on database
$Helper->BeginWork();

# create customer user
my $CustomerContactID = $Helper->TestContactCreate();
$Self->True(
    $CustomerContactID,
    'TestContactCreate',
);
my %CustomerContact = $Kernel::OM->Get('Contact')->ContactGet(
    ID     => $CustomerContactID,
    UserID => 1
);
my $AdditionalOrganisationID = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => $Helper->GetRandomID(),
    Name    => $Helper->GetRandomID(),
    UserID  => 1
);
$Self->True(
    $AdditionalOrganisationID,
    'Created additional organisation'
);
my $ContactUpdateSuccess = $Kernel::OM->Get('Contact')->ContactUpdate(
    %CustomerContact,
    ID              => $CustomerContactID,
    OrganisationIDs => [
        $CustomerContact{PrimaryOrganisationID},
        $AdditionalOrganisationID
    ],
    UserID          => 1
);
$Self->True(
    $ContactUpdateSuccess,
    'Added additional organisation to contact'
);

# add class for unit test
my $Class   = 'UnitTest';
my $ClassID = $Kernel::OM->Get('GeneralCatalog')->ItemAdd(
    Class   => 'ITSM::ConfigItem::Class',
    Name    => $Class,
    ValidID => 1,
    UserID  => 1,
);
my $DefinitionID = $Kernel::OM->Get('ITSMConfigItem')->DefinitionAdd(
    ClassID    => $ClassID,
    Definition => <<'END',
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
    UserID     => 1
);

# prepare depl state mapping
my $DeplStateRef = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class => 'ITSM::ConfigItem::DeploymentState',
    Name  => 'Production',
);

# prepare inci state mapping
my $InciStateRef = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class => 'ITSM::Core::IncidentState',
    Name  => 'Operational',
);

## prepare test assets ##
# first asset
my $ConfigItemID1 = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
    ClassID => $ClassID,
    UserID  => 1,
);
$Self->True(
    $ConfigItemID1,
    'Created first asset'
);
my $VersionID1 = $Kernel::OM->Get('ITSMConfigItem')->VersionAdd(
    ConfigItemID => $ConfigItemID1,
    Name         => $Helper->GetRandomID(),
    DefinitionID => 1,
    DeplStateID  => $DeplStateRef->{ItemID},
    InciStateID  => $InciStateRef->{ItemID},
    XMLData      => [
        undef,
        {
            Version => [
                undef,
                {
                    SectionOwner => [
                        undef,
                        {
                            OwnerContact => [
                                undef,
                                {
                                    Content => $CustomerContact{ID}
                                }
                            ]
                        }
                    ]
                }
            ]
        }
    ],
    UserID       => 1,
);
$Self->True(
    $VersionID1,
    'Created version for first asset'
);
# second asset
my $ConfigItemID2 = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
    ClassID => $ClassID,
    UserID  => 1,
);
$Self->True(
    $ConfigItemID2,
    'Created second asset'
);
my $VersionID2 = $Kernel::OM->Get('ITSMConfigItem')->VersionAdd(
    ConfigItemID => $ConfigItemID2,
    Name         => $Helper->GetRandomID(),
    DefinitionID => 1,
    DeplStateID  => $DeplStateRef->{ItemID},
    InciStateID  => $InciStateRef->{ItemID},
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
                                    Content => $CustomerContact{PrimaryOrganisationID}
                                }
                            ]
                        }
                    ]
                }
            ]
        }
    ],
    UserID       => 1,
);
$Self->True(
    $VersionID2,
    'Created version for second asset'
);
# third asset
my $ConfigItemID3 = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
    ClassID => $ClassID,
    UserID  => 1,
);
$Self->True(
    $ConfigItemID3,
    'Created third asset'
);
my $VersionID3 = $Kernel::OM->Get('ITSMConfigItem')->VersionAdd(
    ConfigItemID => $ConfigItemID3,
    Name         => $Helper->GetRandomID(),
    DefinitionID => 1,
    DeplStateID  => $DeplStateRef->{ItemID},
    InciStateID  => $InciStateRef->{ItemID},
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
                                    Content => $AdditionalOrganisationID
                                }
                            ]
                        }
                    ]
                }
            ]
        }
    ],
    UserID       => 1,
);
$Self->True(
    $VersionID3,
    'Created version for third asset'
);

# discard config item object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['ITSMConfigItem'],
);

$Kernel::OM->Get('Config')->Set(
    Key   => 'AssignedConfigItemsMapping',
    Value => <<"END"
{
    "Contact": {
        "$Class": {
            "SectionOwner::OwnerContact": {
                "SearchAttributes": [
                    "ID"
                ]
            },
            "SectionOwner::OwnerOrganisation": {
                "SearchAttributes": [
                    "RelevantOrganisationID"
                ]
            }
        }
    },
    "Organisation": {
        "$Class": {
            "SectionOwner::OwnerOrganisation": {
                "SearchAttributes": [
                    "ID"
                ]
            }
        }
    }
}
END
);

# check Search
my @SearchTests = (
    {
        Name         => 'Search: undef search',
        Search       => undef,
        Expected     => undef
    },
    {
        Name         => 'Search: Value undef',
        Search       => {
            Field    => 'AssignedContact',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'AssignedContact',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Field undef',
        Search       => {
            Field    => undef,
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Field invalid',
        Search       => {
            Field    => 'Test',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator undef',
        Search       => {
            Field    => 'AssignedContact',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'AssignedContact',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field AssignedContact / Operator EQ / Contact without asset',
        Search       => {
            Field    => 'AssignedContact',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                '1=0'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AssignedContact / Operator EQ / Contact with asset',
        Search       => {
            Field    => 'AssignedContact',
            Operator => 'EQ',
            Value    => $CustomerContact{ID}
        },
        Expected     => {
            'Where' => [
                "ci.id IN ($ConfigItemID1,$ConfigItemID2)"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AssignedContact / Operator EQ / Contact with asset and mismatching AssignedOrganisation',
        Search       => {
            Field    => 'AssignedContact',
            Operator => 'EQ',
            Value    => $CustomerContact{ID}
        },
        Flags        => {
            AssignedOrganisation => '1'
        },
        Expected     => {
            'Where' => [
                "ci.id IN ($ConfigItemID1)"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AssignedContact / Operator EQ / Contact with asset and matching AssignedOrganisation',
        Search       => {
            Field    => 'AssignedContact',
            Operator => 'EQ',
            Value    => $CustomerContact{ID}
        },
        Flags        => {
            AssignedOrganisation => $AdditionalOrganisationID
        },
        Expected     => {
            'Where' => [
                "ci.id IN ($ConfigItemID1,$ConfigItemID3)"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AssignedContact / Operator IN / Contact without asset',
        Search       => {
            Field    => 'AssignedContact',
            Operator => 'IN',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                '1=0'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AssignedContact / Operator IN / Contact with asset',
        Search       => {
            Field    => 'AssignedContact',
            Operator => 'IN',
            Value    => $CustomerContact{ID}
        },
        Expected     => {
            'Where' => [
                "ci.id IN ($ConfigItemID1,$ConfigItemID2)"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AssignedContact / Operator IN / Contact with asset and mismatching AssignedOrganisation',
        Search       => {
            Field    => 'AssignedContact',
            Operator => 'IN',
            Value    => $CustomerContact{ID}
        },
        Flags        => {
            AssignedOrganisation => '1'
        },
        Expected     => {
            'Where' => [
                "ci.id IN ($ConfigItemID1)"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AssignedContact / Operator IN / Contact with asset and matching AssignedOrganisation',
        Search       => {
            Field    => 'AssignedContact',
            Operator => 'IN',
            Value    => $CustomerContact{ID}
        },
        Flags        => {
            AssignedOrganisation => $AdditionalOrganisationID
        },
        Expected     => {
            'Where' => [
                "ci.id IN ($ConfigItemID1,$ConfigItemID3)"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AssignedOrganisation / Operator EQ / Organisation without asset',
        Search       => {
            Field    => 'AssignedOrganisation',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                '1=0'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AssignedOrganisation / Operator EQ / Organisation with asset',
        Search       => {
            Field    => 'AssignedOrganisation',
            Operator => 'EQ',
            Value    => $CustomerContact{PrimaryOrganisationID}
        },
        Expected     => {
            'Where' => [
                "ci.id IN ($ConfigItemID2)"
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AssignedOrganisation / Operator IN / Organisation without asset',
        Search       => {
            Field    => 'AssignedOrganisation',
            Operator => 'IN',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                '1=0'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AssignedOrganisation / Operator IN / Organisation with asset',
        Search       => {
            Field    => 'AssignedOrganisation',
            Operator => 'IN',
            Value    => $CustomerContact{PrimaryOrganisationID}
        },
        Expected     => {
            'Where' => [
                "ci.id IN ($ConfigItemID2)"
            ]
        }
    }
);
for my $Test ( @SearchTests ) {
    my $Result = $AttributeObject->Search(
        Search       => $Test->{Search},
        Flags        => $Test->{Flags},
        BoolOperator => 'AND',
        UserID       => 1,
        Silent       => defined( $Test->{Expected} ) ? 0 : 1
    );
    $Self->IsDeeply(
        $Result,
        $Test->{Expected},
        $Test->{Name}
    );
}

# check Sort
my @SortTests = (
    {
        Name      => 'Sort: Attribute undef',
        Attribute => undef,
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute invalid',
        Attribute => 'Test',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "AssignedContact"',
        Attribute => 'AssignedContact',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "AssignedOrganisation"',
        Attribute => 'AssignedOrganisation',
        Expected  => undef
    }
);
for my $Test ( @SortTests ) {
    my $Result = $AttributeObject->Sort(
        Attribute => $Test->{Attribute},
        Language  => 'en',
        Silent    => defined( $Test->{Expected} ) ? 0 : 1
    );
    $Self->IsDeeply(
        $Result,
        $Test->{Expected},
        $Test->{Name}
    );
}

### Integration Test ###
# discard current object search object
$Kernel::OM->ObjectsDiscard(
    Objects => ['ObjectSearch'],
);

# make sure config 'ObjectSearch::Backend' is set to Module 'ObjectSearch::Database'
$Kernel::OM->Get('Config')->Set(
    Key   => 'ObjectSearch::Backend',
    Value => {
        Module => 'ObjectSearch::Database',
    }
);

# get objectsearch object
my $ObjectSearch = $Kernel::OM->Get('ObjectSearch');

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field AssignedContact / Operator EQ / Value 1 (without asset)',
        Search   => {
            'AND' => [
                {
                    Field    => 'AssignedContact',
                    Operator => 'EQ',
                    Value    => '1'
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field AssignedContact / Operator EQ / Value $CustomerContact{ID} (with asset)',
        Search   => {
            'AND' => [
                {
                    Field    => 'AssignedContact',
                    Operator => 'EQ',
                    Value    => $CustomerContact{ID}
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field AssignedContact & AssignedOrganisation / Operator EQ / Value $CustomerContact{ID} & 1 (with asset, mismatching organisation)',
        Search   => {
            'AND' => [
                {
                    Field    => 'AssignedContact',
                    Operator => 'EQ',
                    Value    => $CustomerContact{ID}
                },
                {
                    Field    => 'AssignedOrganisation',
                    Operator => 'EQ',
                    Value    => '1'
                }
            ]
        },
        Expected => [$ConfigItemID1]
    },
    {
        Name     => 'Search: Field AssignedContact & AssignedOrganisation / Operator EQ / Value $CustomerContact{ID} & $AdditionalOrganisationID (with asset, matching organisation)',
        Search   => {
            'AND' => [
                {
                    Field    => 'AssignedContact',
                    Operator => 'EQ',
                    Value    => $CustomerContact{ID}
                },
                {
                    Field    => 'AssignedOrganisation',
                    Operator => 'EQ',
                    Value    => $AdditionalOrganisationID
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID3]
    },
    {
        Name     => 'Search: Field AssignedContact / Operator IN / Value 1 (without asset)',
        Search   => {
            'AND' => [
                {
                    Field    => 'AssignedContact',
                    Operator => 'IN',
                    Value    => '1'
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field AssignedContact / Operator IN / Value $CustomerContact{ID} (with asset)',
        Search   => {
            'AND' => [
                {
                    Field    => 'AssignedContact',
                    Operator => 'IN',
                    Value    => $CustomerContact{ID}
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field AssignedContact & AssignedOrganisation / Operator IN / Value $CustomerContact{ID} & 1 (with asset, mismatching organisation)',
        Search   => {
            'AND' => [
                {
                    Field    => 'AssignedContact',
                    Operator => 'IN',
                    Value    => $CustomerContact{ID}
                },
                {
                    Field    => 'AssignedOrganisation',
                    Operator => 'IN',
                    Value    => '1'
                }
            ]
        },
        Expected => [$ConfigItemID1]
    },
    {
        Name     => 'Search: Field AssignedContact & AssignedOrganisation / Operator IN / Value $CustomerContact{ID} & $AdditionalOrganisationID (with asset, matching organisation)',
        Search   => {
            'AND' => [
                {
                    Field    => 'AssignedContact',
                    Operator => 'IN',
                    Value    => $CustomerContact{ID}
                },
                {
                    Field    => 'AssignedOrganisation',
                    Operator => 'IN',
                    Value    => $AdditionalOrganisationID
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID3]
    },
    {
        Name     => 'Search: Field AssignedOrganisation / Operator EQ / Value 1 (without asset)',
        Search   => {
            'AND' => [
                {
                    Field    => 'AssignedOrganisation',
                    Operator => 'EQ',
                    Value    => '1'
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field AssignedOrganisation / Operator EQ / Value $CustomerContact{PrimaryOrganisationID} (with asset)',
        Search   => {
            'AND' => [
                {
                    Field    => 'AssignedOrganisation',
                    Operator => 'EQ',
                    Value    => $CustomerContact{PrimaryOrganisationID}
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field AssignedOrganisation / Operator IN / Value 1 (without asset)',
        Search   => {
            'AND' => [
                {
                    Field    => 'AssignedOrganisation',
                    Operator => 'IN',
                    Value    => '1'
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field AssignedOrganisation / Operator IN / Value $CustomerContact{PrimaryOrganisationID} (with asset)',
        Search   => {
            'AND' => [
                {
                    Field    => 'AssignedOrganisation',
                    Operator => 'IN',
                    Value    => $CustomerContact{PrimaryOrganisationID}
                }
            ]
        },
        Expected => [$ConfigItemID2]
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'ConfigItem',
        Result     => 'ARRAY',
        Search     => $Test->{Search},
        UserType   => 'Agent',
        UserID     => 1,
    );
    $Self->IsDeeply(
        \@Result,
        $Test->{Expected},
        $Test->{Name}
    );
}

# test Sort
# attributes of this backend are not sortable

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
