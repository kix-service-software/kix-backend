# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/
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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Role::Permission';

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
    $AttributeList,
    {
        'Permissions.Target' => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN'],
        },
        'Permissions.Type' => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN'],
        },
        'Permissions.TypeID' => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType      => 'NUMERIC'
        },
        'Permissions.Value' => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType      => 'NUMERIC'
        }
    },
    'GetSupportedAttributes provides expected data'
);

# Quoting single quote character
my $QuoteSingle = $Kernel::OM->Get('DB')->GetDatabaseFunction('QuoteSingle');

# Quoting semicolon character
my $QuoteSemicolon = $Kernel::OM->Get('DB')->GetDatabaseFunction('QuoteSemicolon');

# check if database is casesensitive
my $CaseSensitive = $Kernel::OM->Get('DB')->GetDatabaseFunction('CaseSensitive');

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
            Field    => 'Votes',
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
            Field    => 'Votes',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'Votes',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field Permissions.Target / Operator EQ',
        Search       => {
            Field    => 'Permissions.Target',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'IsRelative' => undef,
            'Join' => [
                'LEFT JOIN role_permission rp0 ON rp0.role_id = r.id',
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(rp0.target) = \'test\'' : 'rp0.target = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Permissions.Target / Operator NE',
        Search       => {
            Field    => 'Permissions.Target',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'IsRelative' => undef,
            'Join' => [
                'LEFT JOIN role_permission rp0 ON rp0.role_id = r.id',
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(rp0.target) != \'test\'' : 'rp0.target != \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Permissions.Target / Operator IN',
        Search       => {
            Field    => 'Permissions.Target',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'IsRelative' => undef,
            'Join' => [
                'LEFT JOIN role_permission rp0 ON rp0.role_id = r.id',
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(rp0.target) IN (\'test\')' : 'rp0.target IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Permissions.Target / Operator !IN',
        Search       => {
            Field    => 'Permissions.Target',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'IsRelative' => undef,
            'Join' => [
                'LEFT JOIN role_permission rp0 ON rp0.role_id = r.id',
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(rp0.target) NOT IN (\'test\')' : 'rp0.target NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Permissions.Target / Operator STARTSWITH',
        Search       => {
            Field    => 'Permissions.Target',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'IsRelative' => undef,
            'Join' => [
                'LEFT JOIN role_permission rp0 ON rp0.role_id = r.id',
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(rp0.target) LIKE \'test%\'' : 'rp0.target LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Permissions.Target / Operator ENDSWITH',
        Search       => {
            Field    => 'Permissions.Target',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'IsRelative' => undef,
            'Join' => [
                'LEFT JOIN role_permission rp0 ON rp0.role_id = r.id',
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(rp0.target) LIKE \'%test\'' : 'rp0.target LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Permissions.Target / Operator CONTAINS',
        Search       => {
            Field    => 'Permissions.Target',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'IsRelative' => undef,
            'Join' => [
                'LEFT JOIN role_permission rp0 ON rp0.role_id = r.id',
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(rp0.target) LIKE \'%test%\'' : 'rp0.target LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Permissions.Target / Operator LIKE',
        Search       => {
            Field    => 'Permissions.Target',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'IsRelative' => undef,
            'Join' => [
                'LEFT JOIN role_permission rp0 ON rp0.role_id = r.id',
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(rp0.target) LIKE \'test\'' : 'rp0.target LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Permissions.Type / Operator EQ',
        Search       => {
            Field    => 'Permissions.Type',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'IsRelative' => undef,
            'Join' => [
                'LEFT JOIN role_permission rp0 ON rp0.role_id = r.id',
                'LEFT JOIN permission_type pt0 ON rp0.type_id = pt0.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(pt0.name) = \'test\'' : 'pt0.name = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Permissions.Type / Operator NE',
        Search       => {
            Field    => 'Permissions.Type',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'IsRelative' => undef,
            'Join' => [
                'LEFT JOIN role_permission rp0 ON rp0.role_id = r.id',
                'LEFT JOIN permission_type pt0 ON rp0.type_id = pt0.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(pt0.name) != \'test\'' : 'pt0.name != \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Permissions.Type / Operator IN',
        Search       => {
            Field    => 'Permissions.Type',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'IsRelative' => undef,
            'Join' => [
                'LEFT JOIN role_permission rp0 ON rp0.role_id = r.id',
                'LEFT JOIN permission_type pt0 ON rp0.type_id = pt0.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(pt0.name) IN (\'test\')' : 'pt0.name IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Permissions.Type / Operator !IN',
        Search       => {
            Field    => 'Permissions.Type',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'IsRelative' => undef,
            'Join' => [
                'LEFT JOIN role_permission rp0 ON rp0.role_id = r.id',
                'LEFT JOIN permission_type pt0 ON rp0.type_id = pt0.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(pt0.name) NOT IN (\'test\')' : 'pt0.name NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Permissions.Type / Operator STARTSWITH',
        Search       => {
            Field    => 'Permissions.Type',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'IsRelative' => undef,
            'Join' => [
                'LEFT JOIN role_permission rp0 ON rp0.role_id = r.id',
                'LEFT JOIN permission_type pt0 ON rp0.type_id = pt0.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(pt0.name) LIKE \'test%\'' : 'pt0.name LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Permissions.Type / Operator ENDSWITH',
        Search       => {
            Field    => 'Permissions.Type',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'IsRelative' => undef,
            'Join' => [
                'LEFT JOIN role_permission rp0 ON rp0.role_id = r.id',
                'LEFT JOIN permission_type pt0 ON rp0.type_id = pt0.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(pt0.name) LIKE \'%test\'' : 'pt0.name LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Permissions.Type / Operator CONTAINS',
        Search       => {
            Field    => 'Permissions.Type',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'IsRelative' => undef,
            'Join' => [
                'LEFT JOIN role_permission rp0 ON rp0.role_id = r.id',
                'LEFT JOIN permission_type pt0 ON rp0.type_id = pt0.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(pt0.name) LIKE \'%test%\'' : 'pt0.name LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Permissions.Type / Operator LIKE',
        Search       => {
            Field    => 'Permissions.Type',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'IsRelative' => undef,
            'Join' => [
                'LEFT JOIN role_permission rp0 ON rp0.role_id = r.id',
                'LEFT JOIN permission_type pt0 ON rp0.type_id = pt0.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(pt0.name) LIKE \'test\'' : 'pt0.name LIKE \'test\''
            ]
        }
    },
);
for my $Test ( @SearchTests ) {
    my $Result = $AttributeObject->Search(
        Search       => $Test->{Search},
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
        Name      => 'Sort: Attribute "Permissions.Target"',
        Attribute => 'Permissions.Target',
        Expected  => {
            'Join' => [
                'LEFT JOIN role_permission rp0 ON rp0.role_id = r.id',
            ],
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select' => [
                'rp0.target AS SortAttr0'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Permissions.Type"',
        Attribute => 'Permissions.Type',
        Expected  => {
            'Join' => [
                'LEFT JOIN role_permission rp0 ON rp0.role_id = r.id',
                'LEFT JOIN permission_type pt0 ON rp0.type_id = pt0.id'
            ],
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select' => [
                'pt0.name AS SortAttr0'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Permissions.TypeID"',
        Attribute => 'Permissions.TypeID',
        Expected  => {
            'Join' => [
                'LEFT JOIN role_permission rp0 ON rp0.role_id = r.id',
            ],
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select' => [
                'rp0.type_id AS SortAttr0'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Permissions.Value"',
        Attribute => 'Permissions.Value',
        Expected  => {
            'Join' => [
                'LEFT JOIN role_permission rp0 ON rp0.role_id = r.id',
            ],
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select' => [
                'rp0.value AS SortAttr0'
            ]
        }
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

# remove existing roles and permissions to have a base for the following tests
foreach my $What ( qw(role_permission role_user roles) ) {
    my $Success = $Kernel::OM->Get('DB')->Prepare(
        SQL  => "DELETE FROM $What",
    );
    $Self->True(
        $Success,
        "Preparing DB table $What"
    );
}

# cleanup whole cache
$Kernel::OM->Get('Cache')->CleanUp();

## prepare test roles ##
# first role
my $RoleID1 = $Kernel::OM->Get('Role')->RoleAdd(
    Name         => 'Role1',
    UsageContext => Kernel::System::Role->USAGE_CONTEXT->{AGENT},
    ValidID      => 1,
    UserID       => 1,
);
$Self->True(
    $RoleID1,
    'Created first role'
);
# second role
my $RoleID2 = $Kernel::OM->Get('Role')->RoleAdd(
    Name         => 'Role2',
    UsageContext => Kernel::System::Role->USAGE_CONTEXT->{CUSTOMER},
    ValidID      => 1,
    UserID       => 1,
);
$Self->True(
    $RoleID1,
    'Created second role'
);
# third role
my $RoleID3 = $Kernel::OM->Get('Role')->RoleAdd(
    Name         => 'Role3',
    UsageContext => Kernel::System::Role->USAGE_CONTEXT->{CUSTOMER} + Kernel::System::Role->USAGE_CONTEXT->{AGENT},
    ValidID      => 1,
    UserID       => 1,
);
$Self->True(
    $RoleID1,
    'Created third role'
);
# fourth role
my $RoleID4 = $Kernel::OM->Get('Role')->RoleAdd(
    Name         => 'Role4',
    UsageContext => Kernel::System::Role->USAGE_CONTEXT->{CUSTOMER} + Kernel::System::Role->USAGE_CONTEXT->{AGENT},
    ValidID      => 1,
    UserID       => 1,
);
$Self->True(
    $RoleID1,
    'Created fourth role'
);

## prepare test permissions ##
my @Permissions = (
    {
        RoleID     => $RoleID1,
        TypeID     => 1,
        Target     => '/tickets',
        Value      => 0x000F,
    },
    {
        RoleID     => $RoleID1,
        TypeID     => 1,
        Target     => '/timer',
        Value      => 0x0008,
    },
    {
        RoleID     => $RoleID2,
        TypeID     => 2,
        Target     => '/tickets/*/articles{Dummy.test EQ 1}',
        Value      => 0x0001,
    },
    {
        RoleID     => $RoleID3,
        TypeID     => 3,
        Target     => '/timer{Dummy.[test]}',
        Value      => 0x0002,
    },
    {
        RoleID     => $RoleID4,
        TypeID     => 4,
        Target     => '1',
        Value      => 0x000F,
    },
);

my @PermissionIDs;

for my $Data ( @Permissions ) {
    my $PermissionID = $Kernel::OM->Get('Role')->PermissionAdd(
        %{$Data},
        UserID => 1,
    );
    $Self->True(
        $PermissionID,
        "Created permission for RoleID $Data->{RoleID} with TypeID $Data->{TypeID}, Target $Data->{Target} and Value $Data->{Value}"
    );

    # save ID for later
    push @PermissionIDs, $PermissionID
}

# test Search
my @IntegrationSearchTests = (
    {
        Name     => "Search: Field Permissions.Target / Operator EQ / Value '/tickets'",
        Search   => {
            'AND' => [
                {
                    Field    => 'Permissions.Target',
                    Operator => 'EQ',
                    Value    => '/tickets'
                }
            ]
        },
        Expected => [$RoleID1]
    },
    {
        Name     => "Search: Field Permissions.Target / Operator EQ / Value '/timer{Dummy.[test]}'",
        Search   => {
            'AND' => [
                {
                    Field    => 'Permissions.Target',
                    Operator => 'EQ',
                    Value    => '/timer{Dummy.[test]}'
                }
            ]
        },
        Expected => [$RoleID3]
    },
    {
        Name     => "Search: Field Permissions.Target / Operator NE / Value '/tickets",
        Search   => {
            'AND' => [
                {
                    Field    => 'Permissions.Target',
                    Operator => 'NE',
                    Value    => '/tickets'
                }
            ]
        },
        Expected => [$RoleID1,$RoleID2,$RoleID3,$RoleID4]
    },
    {
        Name     => "Search: Field Permissions.Target / Operator STARTSWITH / Value '/tickets",
        Search   => {
            'AND' => [
                {
                    Field    => 'Permissions.Target',
                    Operator => 'STARTSWITH',
                    Value    => '/tickets'
                }
            ]
        },
        Expected => [$RoleID1,$RoleID2]
    },
    {
        Name     => "Search: Field Permissions.Target / Operator ENDSWITH / Value 'tickets",
        Search   => {
            'AND' => [
                {
                    Field    => 'Permissions.Target',
                    Operator => 'ENDSWITH',
                    Value    => 'tickets'
                }
            ]
        },
        Expected => [$RoleID1]
    },
    {
        Name     => "Search: Field Permissions.Target / Operator CONTAINS / Value 'tickets",
        Search   => {
            'AND' => [
                {
                    Field    => 'Permissions.Target',
                    Operator => 'CONTAINS',
                    Value    => 'tickets'
                }
            ]
        },
        Expected => [$RoleID1,$RoleID2]
    },
    {
        Name     => "Search: Field Permissions.Target / Operator LIKE / Value '*ti*",
        Search   => {
            'AND' => [
                {
                    Field    => 'Permissions.Target',
                    Operator => 'LIKE',
                    Value    => '*ti*'
                }
            ]
        },
        Expected => [$RoleID1,$RoleID2,$RoleID3]
    },
    {
        Name     => "Search: Field Permissions.Target / Operator IN / Value ['/tickets','/timer']",
        Search   => {
            'AND' => [
                {
                    Field    => 'Permissions.Target',
                    Operator => 'IN',
                    Value    => ['/tickets','/timer']
                }
            ]
        },
        Expected => [$RoleID1]
    },
    {
        Name     => "Search: Field Permissions.Target / Operator !IN / Value ['/tickets','/timer']",
        Search   => {
            'AND' => [
                {
                    Field    => 'Permissions.Target',
                    Operator => '!IN',
                    Value    => ['/tickets','/timer']
                }
            ]
        },
        Expected => [$RoleID2,$RoleID3,$RoleID4]
    },
    {
        Name     => "Search: Field Permissions.Type / Operator EQ / Value 'Resource'",
        Search   => {
            'AND' => [
                {
                    Field    => 'Permissions.Type',
                    Operator => 'EQ',
                    Value    => 'Resource'
                }
            ]
        },
        Expected => [$RoleID1]
    },
    {
        Name     => "Search: Field Permissions.Type / Operator EQ / Value 'Property'",
        Search   => {
            'AND' => [
                {
                    Field    => 'Permissions.Type',
                    Operator => 'EQ',
                    Value    => 'Property'
                }
            ]
        },
        Expected => [$RoleID3]
    },
    {
        Name     => "Search: Field Permissions.Type / Operator NE / Value 'Resource'",
        Search   => {
            'AND' => [
                {
                    Field    => 'Permissions.Type',
                    Operator => 'NE',
                    Value    => 'Resource'
                }
            ]
        },
        Expected => [$RoleID2,$RoleID3,$RoleID4]
    },
    {
        Name     => "Search: Field Permissions.Type / Operator STARTSWITH / Value 'Base::'",
        Search   => {
            'AND' => [
                {
                    Field    => 'Permissions.Type',
                    Operator => 'STARTSWITH',
                    Value    => 'Base::'
                }
            ]
        },
        Expected => [$RoleID4]
    },
    {
        Name     => "Search: Field Permissions.Type / Operator ENDSWITH / Value 'Ticket'",
        Search   => {
            'AND' => [
                {
                    Field    => 'Permissions.Type',
                    Operator => 'ENDSWITH',
                    Value    => 'Ticket'
                }
            ]
        },
        Expected => [$RoleID4]
    },
    {
        Name     => "Search: Field Permissions.Type / Operator CONTAINS / Value '::",
        Search   => {
            'AND' => [
                {
                    Field    => 'Permissions.Type',
                    Operator => 'CONTAINS',
                    Value    => '::'
                }
            ]
        },
        Expected => [$RoleID4]
    },
    {
        Name     => "Search: Field Permissions.Type / Operator LIKE / Value '*::*",
        Search   => {
            'AND' => [
                {
                    Field    => 'Permissions.Type',
                    Operator => 'LIKE',
                    Value    => '*::*'
                }
            ]
        },
        Expected => [$RoleID4]
    },
    {
        Name     => "Search: Field Permissions.TypeID / Operator LT / Value 3",
        Search   => {
            'AND' => [
                {
                    Field    => 'Permissions.TypeID',
                    Operator => 'LT',
                    Value    => 3
                }
            ]
        },
        Expected => [$RoleID1,$RoleID2]
    },
    {
        Name     => "Search: Field Permissions.TypeID / Operator LTE / Value 2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Permissions.TypeID',
                    Operator => 'LTE',
                    Value    => 2
                }
            ]
        },
        Expected => [$RoleID1,$RoleID2]
    },
    {
        Name     => "Search: Field Permissions.TypeID / Operator GT / Value 3",
        Search   => {
            'AND' => [
                {
                    Field    => 'Permissions.TypeID',
                    Operator => 'GT',
                    Value    => 3
                }
            ]
        },
        Expected => [$RoleID4]
    },
    {
        Name     => "Search: Field Permissions.TypeID / Operator GTE / Value 2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Permissions.TypeID',
                    Operator => 'GTE',
                    Value    => 2
                }
            ]
        },
        Expected => [$RoleID2,$RoleID3,$RoleID4]
    },
    {
        Name     => "Search: Field Permissions.Value / Operator EQ / Value 0x000F",
        Search   => {
            'AND' => [
                {
                    Field    => 'Permissions.Value',
                    Operator => 'EQ',
                    Value    => 0x000F
                }
            ]
        },
        Expected => [$RoleID1,$RoleID4]
    },
    {
        Name     => "Search: Field Permissions.Value / Operator NE / Value 0x000F",
        Search   => {
            'AND' => [
                {
                    Field    => 'Permissions.Value',
                    Operator => 'NE',
                    Value    => 0x000F
                }
            ]
        },
        Expected => [$RoleID1,$RoleID2,$RoleID3]
    },
    {
        Name     => "Search: Field Permissions.Value / Operator LT / Value 0x0008",
        Search   => {
            'AND' => [
                {
                    Field    => 'Permissions.Value',
                    Operator => 'LT',
                    Value    => 0x0008
                }
            ]
        },
        Expected => [$RoleID2,$RoleID3]
    },
    {
        Name     => "Search: Field Permissions.Value / Operator LTE / Value 0x0008",
        Search   => {
            'AND' => [
                {
                    Field    => 'Permissions.Value',
                    Operator => 'LTE',
                    Value    => 0x0008
                }
            ]
        },
        Expected => [$RoleID1,$RoleID2,$RoleID3]
    },
    {
        Name     => "Search: Field Permissions.Value / Operator GT / Value 0x0008",
        Search   => {
            'AND' => [
                {
                    Field    => 'Permissions.Value',
                    Operator => 'GT',
                    Value    => 0x0008
                }
            ]
        },
        Expected => [$RoleID1,$RoleID4]
    },
    {
        Name     => "Search: Field Permissions.Value / Operator GTE / Value 0x0002",
        Search   => {
            'AND' => [
                {
                    Field    => 'Permissions.Value',
                    Operator => 'GTE',
                    Value    => 0x0002
                }
            ]
        },
        Expected => [$RoleID1,$RoleID3,$RoleID4]
    },

);

for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Role',
        Result     => 'ARRAY',
        Search     => $Test->{Search},
        UserType   => 'Agent',
        UserID     => 1
    );
    $Self->IsDeeply(
        \@Result,
        $Test->{Expected},
        $Test->{Name}
    );
}

# test Sort
my @IntegrationSortTests = (
    {
        Name     => 'Sort: Field Permissions.Target',
        Sort     => [
            {
                Field => 'Permissions.Target'
            }
        ],
        Language => 'en',
        Expected => [$RoleID1,$RoleID2,$RoleID3,$RoleID4]
    },
    {
        Name     => 'Sort: Field Permissions.Target / Direction ascending',
        Sort     => [
            {
                Field     => 'Permissions.Target',
                Direction => 'ascending'
            }
        ],
        Language => 'en',
        Expected => [$RoleID1,$RoleID2,$RoleID3,$RoleID4]
    },
    {
        Name     => 'Sort: Field Permissions.Target / Direction descending',
        Sort     => [
            {
                Field     => 'Permissions.Target',
                Direction => 'descending'
            }
        ],
        Language => 'en',
        Expected => [$RoleID4,$RoleID3,$RoleID1,$RoleID2]
    },
    {
        Name     => 'Sort: Field Permissions.Type',
        Sort     => [
            {
                Field => 'Permissions.Type'
            }
        ],
        Language => 'en',
        Expected => [$RoleID4, $RoleID2, $RoleID3, $RoleID1]
    },
    {
        Name     => 'Sort: Field Permissions.Type / Direction ascending',
        Sort     => [
            {
                Field => 'Permissions.Type',
                Direction => 'ascending'
            }
        ],
        Language => 'en',
        Expected => [$RoleID4, $RoleID2, $RoleID3, $RoleID1]
    },
    {
        Name     => 'Sort: Field Permissions.Type / Direction descending',
        Sort     => [
            {
                Field => 'Permissions.Type',
                Direction => 'descending'
            }
        ],
        Language => 'en',
        Expected => [$RoleID1, $RoleID3, $RoleID2, $RoleID4]
    },
    {
        Name     => 'Sort: Field Permissions.TypeID',
        Sort     => [
            {
                Field => 'Permissions.TypeID'
            }
        ],
        Language => 'en',
        Expected => [$RoleID1, $RoleID2, $RoleID3, $RoleID4]
    },
    {
        Name     => 'Sort: Field Permissions.TypeID / Direction ascending',
        Sort     => [
            {
                Field => 'Permissions.TypeID',
                Direction => 'ascending'
            }
        ],
        Language => 'en',
        Expected => [$RoleID1, $RoleID2, $RoleID3, $RoleID4]
    },
    {
        Name     => 'Sort: Field Permissions.TypeID / Direction descending',
        Sort     => [
            {
                Field => 'Permissions.TypeID',
                Direction => 'descending'
            }
        ],
        Language => 'en',
        Expected => [$RoleID4, $RoleID3, $RoleID2, $RoleID1]
    },
    {
        Name     => 'Sort: Field Value',
        Sort     => [
            {
                Field => 'Permissions.Value'
            }
        ],
        Language => 'en',
        Expected => [$RoleID2, $RoleID3, $RoleID1, $RoleID4]
    },
    {
        Name     => 'Sort: Field Permissions.Value / Direction ascending',
        Sort     => [
            {
                Field => 'Permissions.Value',
                Direction => 'ascending'
            }
        ],
        Language => 'en',
        Expected => [$RoleID2, $RoleID3, $RoleID1, $RoleID4]
    },
    {
        Name     => 'Sort: Field Permissions.Value / Direction descending',
        Sort     => [
            {
                Field => 'Permissions.Value',
                Direction => 'descending'
            }
        ],
        Language => 'en',
        Expected => [$RoleID1, $RoleID4, $RoleID3, $RoleID2]
    },
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Role',
        Result     => 'ARRAY',
        Sort       => $Test->{Sort},
        Language   => $Test->{Language},
        UserType   => 'Agent',
        UserID     => 1,
    );
    $Self->IsDeeply(
        \@Result,
        $Test->{Expected},
        $Test->{Name}
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
