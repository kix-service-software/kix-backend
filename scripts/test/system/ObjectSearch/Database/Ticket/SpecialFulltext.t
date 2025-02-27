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

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Ticket::SpecialFulltext';

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
        'Attribute object can "' . $Method . q{"}
    );
}

# check GetSupportedAttributes
my $AttributeList = $AttributeObject->GetSupportedAttributes();
$Self->IsDeeply(
    $AttributeList, {
        OwnerFulltext => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        ResponsibleFulltext => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        OrganisationFulltext => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        }
    },
    'GetSupportedAttributes provides expected data'
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
            Field    => 'Name',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Field undef',
        Search       => {
            Field    => undef,
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Field invalid',
        Search       => {
            Field    => 'Test',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator undef',
        Search       => {
            Field    => 'Name',
            Operator => undef,
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'Name',
            Operator => 'Test',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field OwnerFulltext / Operator STARTSWITH',
        Search       => {
            Field    => 'OwnerFulltext',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Search' => {
                'OR' => [
                    {
                        'Field'    => 'Owner',
                        'Operator' => 'STARTSWITH',
                        'Value'    => 'Test'
                    },
                    {
                        'Field'    => 'OwnerName',
                        'Operator' => 'STARTSWITH',
                        'Value'    => 'Test'
                    }
                ]
            }
        }
    },
    {
        Name         => 'Search: valid search / Field OwnerFulltext / Operator ENDSWITH',
        Search       => {
            Field    => 'OwnerFulltext',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Search' => {
                'OR' => [
                    {
                        'Field'    => 'Owner',
                        'Operator' => 'ENDSWITH',
                        'Value'    => 'Test'
                    },
                    {
                        'Field'    => 'OwnerName',
                        'Operator' => 'ENDSWITH',
                        'Value'    => 'Test'
                    }
                ]
            }
        }
    },
    {
        Name         => 'Search: valid search / Field OwnerFulltext / Operator CONTAINS',
        Search       => {
            Field    => 'OwnerFulltext',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Search' => {
                'OR' => [
                    {
                        'Field'    => 'Owner',
                        'Operator' => 'CONTAINS',
                        'Value'    => 'Test'
                    },
                    {
                        'Field'    => 'OwnerName',
                        'Operator' => 'CONTAINS',
                        'Value'    => 'Test'
                    }
                ]
            }
        }
    },
    {
        Name         => 'Search: valid search / Field OwnerFulltext / Operator LIKE',
        Search       => {
            Field    => 'OwnerFulltext',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Search' => {
                'OR' => [
                    {
                        'Field'    => 'Owner',
                        'Operator' => 'LIKE',
                        'Value'    => 'Test'
                    },
                    {
                        'Field'    => 'OwnerName',
                        'Operator' => 'LIKE',
                        'Value'    => 'Test'
                    }
                ]
            }
        }
    },
    {
        Name         => 'Search: valid search / Field ResponsibleFulltext / Operator STARTSWITH',
        Search       => {
            Field    => 'ResponsibleFulltext',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Search' => {
                'OR' => [
                    {
                        'Field'    => 'Responsible',
                        'Operator' => 'STARTSWITH',
                        'Value'    => 'Test'
                    },
                    {
                        'Field'    => 'ResponsibleName',
                        'Operator' => 'STARTSWITH',
                        'Value'    => 'Test'
                    }
                ]
            }
        }
    },
    {
        Name         => 'Search: valid search / Field ResponsibleFulltext / Operator ENDSWITH',
        Search       => {
            Field    => 'ResponsibleFulltext',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Search' => {
                'OR' => [
                    {
                        'Field'    => 'Responsible',
                        'Operator' => 'ENDSWITH',
                        'Value'    => 'Test'
                    },
                    {
                        'Field'    => 'ResponsibleName',
                        'Operator' => 'ENDSWITH',
                        'Value'    => 'Test'
                    }
                ]
            }
        }
    },
    {
        Name         => 'Search: valid search / Field ResponsibleFulltext / Operator CONTAINS',
        Search       => {
            Field    => 'ResponsibleFulltext',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Search' => {
                'OR' => [
                    {
                        'Field'    => 'Responsible',
                        'Operator' => 'CONTAINS',
                        'Value'    => 'Test'
                    },
                    {
                        'Field'    => 'ResponsibleName',
                        'Operator' => 'CONTAINS',
                        'Value'    => 'Test'
                    }
                ]
            }
        }
    },
    {
        Name         => 'Search: valid search / Field ResponsibleFulltext / Operator LIKE',
        Search       => {
            Field    => 'ResponsibleFulltext',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Search' => {
                'OR' => [
                    {
                        'Field'    => 'Responsible',
                        'Operator' => 'LIKE',
                        'Value'    => 'Test'
                    },
                    {
                        'Field'    => 'ResponsibleName',
                        'Operator' => 'LIKE',
                        'Value'    => 'Test'
                    }
                ]
            }
        }
    },
    {
        Name         => 'Search: valid search / Field OrganisationFulltext / Operator STARTSWITH',
        Search       => {
            Field    => 'OrganisationFulltext',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Search' => {
                'OR' => [
                    {
                        'Field'    => 'Organisation',
                        'Operator' => 'STARTSWITH',
                        'Value'    => 'Test'
                    },
                    {
                        'Field'    => 'OrganisationNumber',
                        'Operator' => 'STARTSWITH',
                        'Value'    => 'Test'
                    }
                ]
            }
        }
    },
    {
        Name         => 'Search: valid search / Field OrganisationFulltext / Operator ENDSWITH',
        Search       => {
            Field    => 'OrganisationFulltext',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Search' => {
                'OR' => [
                    {
                        'Field'    => 'Organisation',
                        'Operator' => 'ENDSWITH',
                        'Value'    => 'Test'
                    },
                    {
                        'Field'    => 'OrganisationNumber',
                        'Operator' => 'ENDSWITH',
                        'Value'    => 'Test'
                    }
                ]
            }
        }
    },
    {
        Name         => 'Search: valid search / Field OrganisationFulltext / Operator CONTAINS',
        Search       => {
            Field    => 'OrganisationFulltext',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Search' => {
                'OR' => [
                    {
                        'Field'    => 'Organisation',
                        'Operator' => 'CONTAINS',
                        'Value'    => 'Test'
                    },
                    {
                        'Field'    => 'OrganisationNumber',
                        'Operator' => 'CONTAINS',
                        'Value'    => 'Test'
                    }
                ]
            }
        }
    },
    {
        Name         => 'Search: valid search / Field OrganisationFulltext / Operator LIKE',
        Search       => {
            Field    => 'OrganisationFulltext',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Search' => {
                'OR' => [
                    {
                        'Field'    => 'Organisation',
                        'Operator' => 'LIKE',
                        'Value'    => 'Test'
                    },
                    {
                        'Field'    => 'OrganisationNumber',
                        'Operator' => 'LIKE',
                        'Value'    => 'Test'
                    }
                ]
            }
        }
    }
);
for my $Test ( @SearchTests ) {
    my $Result = $AttributeObject->Search(
        Search       => $Test->{Search},
        BoolOperator => 'AND',
        UserID       => 1,
        UserType     => 'Agent',
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
        Name      => 'Sort: Attribute "OwnerFulltext"',
        Attribute => 'OwnerFulltext',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "ResponsibleFulltext"',
        Attribute => 'ResponsibleFulltext',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "OrganisationFulltext"',
        Attribute => 'OrganisationFulltext',
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

# begin transaction on database
$Helper->BeginWork();

## prepare test organisation ##
my $OrgaName1 = 'Test001';
my $OrgaName2 = 'test002';
my $OrgaName3 = 'Test003';
my $OrgaNumber1 = 'Unit001';
my $OrgaNumber2 = 'unit002';
my $OrgaNumber3 = 'Unit003';

# first organisation
my $OrganisationID1 = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => $OrgaNumber1,
    Name    => $OrgaName1,
    UserID  => 1
);
$Self->True(
    $OrganisationID1,
    'Created first organisation'
);
# second organisation
my $OrganisationID2 = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => $OrgaNumber2,
    Name    => $OrgaName2,
    UserID  => 1
);
$Self->True(
    $OrganisationID2,
    'Created second organisation'
);
# third organisation
my $OrganisationID3 = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => $OrgaNumber3,
    Name    => $OrgaName3,
    UserID  => 1
);
$Self->True(
    $OrganisationID3,
    'Created third organisation'
);

# discard contact object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Organisation'],
);

## prepare test Owner/Responsible User+Contact ##
my $RoleID = $Kernel::OM->Get('Role')->RoleLookup(
    Role => 'Ticket Agent'
);
my $UserLogin1 = 'Test001';
my $UserLogin2 = 'test002';
my $UserLogin3 = 'Test003';
my $ContactFirstName1 = 'Theodor';
my $ContactFirstName2 = 'Bertram';
my $ContactFirstName3 = 'Gabriella';
my $ContactLastName1  = 'Test001';
my $ContactLastName2  = 'test002';
my $ContactLastName3  = 'Test003';

my $UserID1 = $Kernel::OM->Get('User')->UserAdd(
    UserLogin     => $UserLogin1,
    ValidID       => 1,
    ChangeUserID  => 1,
    IsAgent       => 1
);
$Kernel::OM->Get('Role')->RoleUserAdd(
    AssignUserID => $UserID1,
    RoleID       => $RoleID,
    UserID       => 1,
);
$Self->True(
    $UserID1,
    'First user created'
);
my $ContactID1 = $Kernel::OM->Get('Contact')->ContactAdd(
    Firstname             => $ContactFirstName1,
    Lastname              => $ContactLastName1,
    AssignedUserID        => $UserID1,
    PrimaryOrganisationID => $OrganisationID1,
    ValidID               => 1,
    UserID                => 1,
);
$Self->True(
    $ContactID1,
    'Contact for first user created'
);
my $UserID2 = $Kernel::OM->Get('User')->UserAdd(
    UserLogin     => $UserLogin2,
    ValidID       => 1,
    ChangeUserID  => 1,
    IsAgent       => 1
);
$Kernel::OM->Get('Role')->RoleUserAdd(
    AssignUserID => $UserID2,
    RoleID       => $RoleID,
    UserID       => 1,
);
$Self->True(
    $UserID2,
    'Second user created'
);
my $ContactID2 = $Kernel::OM->Get('Contact')->ContactAdd(
    Firstname             => $ContactFirstName2,
    Lastname              => $ContactLastName2,
    AssignedUserID        => $UserID2,,
    PrimaryOrganisationID => $OrganisationID2,
    ValidID               => 1,
    UserID                => 1,
);
$Self->True(
    $ContactID2,
    'Contact for second user created'
);
my $UserID3 = $Kernel::OM->Get('User')->UserAdd(
    UserLogin     => $UserLogin3,
    ValidID       => 1,
    ChangeUserID  => 1,
    IsAgent       => 1
);
$Kernel::OM->Get('Role')->RoleUserAdd(
    AssignUserID => $UserID3,
    RoleID       => $RoleID,
    UserID       => 1,
);
$Self->True(
    $UserID3,
    'Third user created'
);
my $ContactID3 = $Kernel::OM->Get('Contact')->ContactAdd(
    Firstname             => $ContactFirstName3,
    Lastname              => $ContactLastName3,
    AssignedUserID        => $UserID3,,
    PrimaryOrganisationID => $OrganisationID3,
    ValidID               => 1,
    UserID                => 1,
);
$Self->True(
    $ContactID3,
    'Contact for third user created'
);

# discard contact object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Contact'],
);

# discard user object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['User'],
);

## prepare test tickets ##
# first ticket
my $TicketID1 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => 1,
    Lock           => 'unlock',
    PriorityID     => 1,
    StateID        => 1,
    TypeID         => 1,
    OrganisationID => $OrganisationID1,
    ContactID      => 1,
    OwnerID        => $UserID1,
    ResponsibleID  => $UserID1,
    UserID         => 1
);
$Self->True(
    $TicketID1,
    'Created first ticket'
);
# second ticket
my $TicketID2 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => 1,
    Lock           => 'unlock',
    PriorityID     => 1,
    StateID        => 1,
    TypeID         => 1,
    OrganisationID => $OrganisationID2,
    ContactID      => 1,
    OwnerID        => $UserID2,
    ResponsibleID  => $UserID2,
    UserID         => 1
);
$Self->True(
    $TicketID2,
    'Created second ticket'
);
# third ticket
my $TicketID3 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => 1,
    Lock           => 'unlock',
    PriorityID     => 1,
    StateID        => 1,
    TypeID         => 1,
    OrganisationID => $OrganisationID3,
    ContactID      => 1,
    OwnerID        => $UserID3,
    ResponsibleID  => $UserID3,
    UserID         => 1
);
$Self->True(
    $TicketID3,
    'Created third ticket'
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Ticket'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => "Search: Field OwnerFulltext / Operator STARTSWITH / Value \$UserLogin2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerFulltext',
                    Operator => 'STARTSWITH',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OwnerFulltext / Operator STARTSWITH / Value substr(\$UserLogin3,0,4)",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerFulltext',
                    Operator => 'STARTSWITH',
                    Value    => substr($UserLogin3,0,4)
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => "Search: Field OwnerFulltext / Operator ENDSWITH / Value \$UserLogin2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerFulltext',
                    Operator => 'ENDSWITH',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OwnerFulltext / Operator ENDSWITH / Value substr(\$UserLogin1,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerFulltext',
                    Operator => 'ENDSWITH',
                    Value    => substr($UserLogin1,-5)
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => "Search: Field OwnerFulltext / Operator CONTAINS / Value \$UserLogin2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerFulltext',
                    Operator => 'CONTAINS',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OwnerFulltext / Operator CONTAINS / Value substr(\$UserLogin3,2,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerFulltext',
                    Operator => 'CONTAINS',
                    Value    => substr($UserLogin3,2,-2)
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => "Search: Field OwnerFulltext / Operator LIKE / Value \$UserLogin2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerFulltext',
                    Operator => 'LIKE',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OwnerFulltext / Operator STARTSWITH / Value \$ContactFirstName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerFulltext',
                    Operator => 'STARTSWITH',
                    Value    => $ContactFirstName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OwnerFulltext / Operator STARTSWITH / Value substr(\$ContactFirstName3,0,4)",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerFulltext',
                    Operator => 'STARTSWITH',
                    Value    => substr($ContactFirstName3,0,4)
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => "Search: Field OwnerFulltext / Operator ENDSWITH / Value \$ContactFirstName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerFulltext',
                    Operator => 'ENDSWITH',
                    Value    => $ContactFirstName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OwnerFulltext / Operator ENDSWITH / Value substr(\$ContactFirstName1,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerFulltext',
                    Operator => 'ENDSWITH',
                    Value    => substr($ContactFirstName1,-5)
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => "Search: Field OwnerFulltext / Operator CONTAINS / Value \$ContactFirstName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerFulltext',
                    Operator => 'CONTAINS',
                    Value    => $ContactFirstName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OwnerFulltext / Operator CONTAINS / Value substr(\$ContactFirstName3,2,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerFulltext',
                    Operator => 'CONTAINS',
                    Value    => substr($ContactFirstName3,2,-2)
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => "Search: Field OwnerFulltext / Operator LIKE / Value \$ContactFirstName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerFulltext',
                    Operator => 'LIKE',
                    Value    => $ContactFirstName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OwnerFulltext / Operator STARTSWITH / Value \$ContactLastName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerFulltext',
                    Operator => 'STARTSWITH',
                    Value    => $ContactLastName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OwnerFulltext / Operator STARTSWITH / Value substr(\$ContactLastName3,0,4)",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerFulltext',
                    Operator => 'STARTSWITH',
                    Value    => substr($ContactLastName3,0,4)
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => "Search: Field OwnerFulltext / Operator ENDSWITH / Value \$ContactLastName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerFulltext',
                    Operator => 'ENDSWITH',
                    Value    => $ContactLastName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OwnerFulltext / Operator ENDSWITH / Value substr(\$ContactLastName1,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerFulltext',
                    Operator => 'ENDSWITH',
                    Value    => substr($ContactLastName1,-5)
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => "Search: Field OwnerFulltext / Operator CONTAINS / Value \$ContactLastName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerFulltext',
                    Operator => 'CONTAINS',
                    Value    => $ContactLastName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OwnerFulltext / Operator CONTAINS / Value substr(\$ContactLastName3,2,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerFulltext',
                    Operator => 'CONTAINS',
                    Value    => substr($ContactLastName3,2,-2)
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => "Search: Field OwnerFulltext / Operator LIKE / Value \$ContactLastName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OwnerFulltext',
                    Operator => 'LIKE',
                    Value    => $ContactLastName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field ResponsibleFulltext / Operator STARTSWITH / Value \$UserLogin2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleFulltext',
                    Operator => 'STARTSWITH',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field ResponsibleFulltext / Operator STARTSWITH / Value substr(\$UserLogin3,0,4)",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleFulltext',
                    Operator => 'STARTSWITH',
                    Value    => substr($UserLogin3,0,4)
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => "Search: Field ResponsibleFulltext / Operator ENDSWITH / Value \$UserLogin2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleFulltext',
                    Operator => 'ENDSWITH',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field ResponsibleFulltext / Operator ENDSWITH / Value substr(\$UserLogin1,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleFulltext',
                    Operator => 'ENDSWITH',
                    Value    => substr($UserLogin1,-5)
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => "Search: Field ResponsibleFulltext / Operator CONTAINS / Value \$UserLogin2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleFulltext',
                    Operator => 'CONTAINS',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field ResponsibleFulltext / Operator CONTAINS / Value substr(\$UserLogin3,2,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleFulltext',
                    Operator => 'CONTAINS',
                    Value    => substr($UserLogin3,2,-2)
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => "Search: Field ResponsibleFulltext / Operator LIKE / Value \$UserLogin2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleFulltext',
                    Operator => 'LIKE',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field ResponsibleFulltext / Operator STARTSWITH / Value \$ContactFirstName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleFulltext',
                    Operator => 'STARTSWITH',
                    Value    => $ContactFirstName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field ResponsibleFulltext / Operator STARTSWITH / Value substr(\$ContactFirstName3,0,4)",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleFulltext',
                    Operator => 'STARTSWITH',
                    Value    => substr($ContactFirstName3,0,4)
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => "Search: Field ResponsibleFulltext / Operator ENDSWITH / Value \$ContactFirstName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleFulltext',
                    Operator => 'ENDSWITH',
                    Value    => $ContactFirstName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field ResponsibleFulltext / Operator ENDSWITH / Value substr(\$ContactFirstName1,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleFulltext',
                    Operator => 'ENDSWITH',
                    Value    => substr($ContactFirstName1,-5)
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => "Search: Field ResponsibleFulltext / Operator CONTAINS / Value \$ContactFirstName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleFulltext',
                    Operator => 'CONTAINS',
                    Value    => $ContactFirstName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field ResponsibleFulltext / Operator CONTAINS / Value substr(\$ContactFirstName3,2,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleFulltext',
                    Operator => 'CONTAINS',
                    Value    => substr($ContactFirstName3,2,-2)
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => "Search: Field ResponsibleFulltext / Operator LIKE / Value \$ContactFirstName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleFulltext',
                    Operator => 'LIKE',
                    Value    => $ContactFirstName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field ResponsibleFulltext / Operator STARTSWITH / Value \$ContactLastName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleFulltext',
                    Operator => 'STARTSWITH',
                    Value    => $ContactLastName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field ResponsibleFulltext / Operator STARTSWITH / Value substr(\$ContactLastName3,0,4)",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleFulltext',
                    Operator => 'STARTSWITH',
                    Value    => substr($ContactLastName3,0,4)
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => "Search: Field ResponsibleFulltext / Operator ENDSWITH / Value \$ContactLastName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleFulltext',
                    Operator => 'ENDSWITH',
                    Value    => $ContactLastName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field ResponsibleFulltext / Operator ENDSWITH / Value substr(\$ContactLastName1,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleFulltext',
                    Operator => 'ENDSWITH',
                    Value    => substr($ContactLastName1,-5)
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => "Search: Field ResponsibleFulltext / Operator CONTAINS / Value \$ContactLastName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleFulltext',
                    Operator => 'CONTAINS',
                    Value    => $ContactLastName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field ResponsibleFulltext / Operator CONTAINS / Value substr(\$ContactLastName3,2,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleFulltext',
                    Operator => 'CONTAINS',
                    Value    => substr($ContactLastName3,2,-2)
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => "Search: Field ResponsibleFulltext / Operator LIKE / Value \$ContactLastName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ResponsibleFulltext',
                    Operator => 'LIKE',
                    Value    => $ContactLastName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OrganisationFulltext / Operator STARTSWITH / Value \$OrgaName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationFulltext',
                    Operator => 'STARTSWITH',
                    Value    => $OrgaName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OrganisationFulltext / Operator STARTSWITH / Value substr(\$OrgaName3,0,4)",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationFulltext',
                    Operator => 'STARTSWITH',
                    Value    => substr($OrgaName3,0,4)
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => "Search: Field OrganisationFulltext / Operator ENDSWITH / Value \$OrgaName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationFulltext',
                    Operator => 'ENDSWITH',
                    Value    => $OrgaName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OrganisationFulltext / Operator ENDSWITH / Value substr(\$OrgaName1,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationFulltext',
                    Operator => 'ENDSWITH',
                    Value    => substr($OrgaName1,-5)
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => "Search: Field OrganisationFulltext / Operator CONTAINS / Value \$OrgaName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationFulltext',
                    Operator => 'CONTAINS',
                    Value    => $OrgaName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OrganisationFulltext / Operator CONTAINS / Value substr(\$OrgaName3,2,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationFulltext',
                    Operator => 'CONTAINS',
                    Value    => substr($OrgaName3,2,-2)
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => "Search: Field OrganisationFulltext / Operator LIKE / Value \$OrgaName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationFulltext',
                    Operator => 'LIKE',
                    Value    => $OrgaName2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OrganisationFulltext / Operator STARTSWITH / Value \$OrgaNumber2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationFulltext',
                    Operator => 'STARTSWITH',
                    Value    => $OrgaNumber2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OrganisationFulltext / Operator STARTSWITH / Value substr(\$OrgaNumber3,0,4)",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationFulltext',
                    Operator => 'STARTSWITH',
                    Value    => substr($OrgaNumber3,0,4)
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => "Search: Field OrganisationFulltext / Operator ENDSWITH / Value \$OrgaNumber2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationFulltext',
                    Operator => 'ENDSWITH',
                    Value    => $OrgaNumber2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OrganisationFulltext / Operator ENDSWITH / Value substr(\$OrgaNumber1,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationFulltext',
                    Operator => 'ENDSWITH',
                    Value    => substr($OrgaNumber1,-5)
                }
            ]
        },
        Expected => [$TicketID1]
    },
    {
        Name     => "Search: Field OrganisationFulltext / Operator CONTAINS / Value \$OrgaNumber2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationFulltext',
                    Operator => 'CONTAINS',
                    Value    => $OrgaNumber2
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field OrganisationFulltext / Operator CONTAINS / Value substr(\$OrgaNumber3,2,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationFulltext',
                    Operator => 'CONTAINS',
                    Value    => substr($OrgaNumber3,2,-2)
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => "Search: Field OrganisationFulltext / Operator LIKE / Value \$OrgaNumber2",
        Search   => {
            'AND' => [
                {
                    Field    => 'OrganisationFulltext',
                    Operator => 'LIKE',
                    Value    => $OrgaNumber2
                }
            ]
        },
        Expected => [$TicketID2]
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Ticket',
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
