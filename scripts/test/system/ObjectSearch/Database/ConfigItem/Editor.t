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

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::ConfigItem::Editor';

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
    $AttributeList, {
        CreateByID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType    => 'NUMERIC'
        },
        CreateBy => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        ChangeByID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType    => 'NUMERIC'
        },
        ChangeBy => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
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
            Field    => 'CreateByID',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'CreateByID',
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
            Field    => 'CreateByID',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'CreateByID',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field CreateByID / Operator EQ',
        Search       => {
            Field    => 'CreateByID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.create_by = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreateByID / Operator NE',
        Search       => {
            Field    => 'CreateByID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.create_by <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreateByID / Operator IN',
        Search       => {
            Field    => 'CreateByID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.create_by IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreateByID / Operator !IN',
        Search       => {
            Field    => 'CreateByID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.create_by NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreateByID / Operator LT',
        Search       => {
            Field    => 'CreateByID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.create_by < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreateByID / Operator GT',
        Search       => {
            Field    => 'CreateByID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.create_by > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreateByID / Operator LTE',
        Search       => {
            Field    => 'CreateByID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.create_by <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreateByID / Operator GTE',
        Search       => {
            Field    => 'CreateByID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.create_by >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreateBy / Operator EQ',
        Search       => {
            Field    => 'CreateBy',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join'  => [
                'INNER JOIN users cicru ON cicru.id = ci.create_by'
            ],
            'Where' => [
                'LOWER(cicru.login) = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreateBy / Operator NE',
        Search       => {
            Field    => 'CreateBy',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join'  => [
                'INNER JOIN users cicru ON cicru.id = ci.create_by'
            ],
            'Where' => [
                'LOWER(cicru.login) != \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreateBy / Operator IN',
        Search       => {
            Field    => 'CreateBy',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join'  => [
                'INNER JOIN users cicru ON cicru.id = ci.create_by'
            ],
            'Where' => [
                'LOWER(cicru.login) IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreateBy / Operator !IN',
        Search       => {
            Field    => 'CreateBy',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join'  => [
                'INNER JOIN users cicru ON cicru.id = ci.create_by'
            ],
            'Where' => [
                'LOWER(cicru.login) NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreateBy / Operator STARTSWITH',
        Search       => {
            Field    => 'CreateBy',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join'  => [
                'INNER JOIN users cicru ON cicru.id = ci.create_by'
            ],
            'Where' => [
                'LOWER(cicru.login) LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreateBy / Operator ENDSWITH',
        Search       => {
            Field    => 'CreateBy',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join'  => [
                'INNER JOIN users cicru ON cicru.id = ci.create_by'
            ],
            'Where' => [
                'LOWER(cicru.login) LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreateBy / Operator CONTAINS',
        Search       => {
            Field    => 'CreateBy',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Join'  => [
                'INNER JOIN users cicru ON cicru.id = ci.create_by'
            ],
            'Where' => [
                'LOWER(cicru.login) LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreateBy / Operator LIKE',
        Search       => {
            Field    => 'CreateBy',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join'  => [
                'INNER JOIN users cicru ON cicru.id = ci.create_by'
            ],
            'Where' => [
                'LOWER(cicru.login) LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeByID / Operator EQ',
        Search       => {
            Field    => 'ChangeByID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.change_by = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeByID / Operator NE',
        Search       => {
            Field    => 'ChangeByID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.change_by <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeByID / Operator IN',
        Search       => {
            Field    => 'ChangeByID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.change_by IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeByID / Operator !IN',
        Search       => {
            Field    => 'ChangeByID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.change_by NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeByID / Operator LT',
        Search       => {
            Field    => 'ChangeByID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.change_by < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeByID / Operator GT',
        Search       => {
            Field    => 'ChangeByID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.change_by > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeByID / Operator LTE',
        Search       => {
            Field    => 'ChangeByID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.change_by <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeByID / Operator GTE',
        Search       => {
            Field    => 'ChangeByID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.change_by >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeBy / Operator EQ',
        Search       => {
            Field    => 'ChangeBy',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join'  => [
                'INNER JOIN users cichu ON cichu.id = ci.change_by'
            ],
            'Where' => [
                'LOWER(cichu.login) = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeBy / Operator NE',
        Search       => {
            Field    => 'ChangeBy',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join'  => [
                'INNER JOIN users cichu ON cichu.id = ci.change_by'
            ],
            'Where' => [
                'LOWER(cichu.login) != \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeBy / Operator IN',
        Search       => {
            Field    => 'ChangeBy',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join'  => [
                'INNER JOIN users cichu ON cichu.id = ci.change_by'
            ],
            'Where' => [
                'LOWER(cichu.login) IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeBy / Operator !IN',
        Search       => {
            Field    => 'ChangeBy',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join'  => [
                'INNER JOIN users cichu ON cichu.id = ci.change_by'
            ],
            'Where' => [
                'LOWER(cichu.login) NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeBy / Operator STARTSWITH',
        Search       => {
            Field    => 'ChangeBy',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join'  => [
                'INNER JOIN users cichu ON cichu.id = ci.change_by'
            ],
            'Where' => [
                'LOWER(cichu.login) LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeBy / Operator ENDSWITH',
        Search       => {
            Field    => 'ChangeBy',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join'  => [
                'INNER JOIN users cichu ON cichu.id = ci.change_by'
            ],
            'Where' => [
                'LOWER(cichu.login) LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeBy / Operator CONTAINS',
        Search       => {
            Field    => 'ChangeBy',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Join'  => [
                'INNER JOIN users cichu ON cichu.id = ci.change_by'
            ],
            'Where' => [
                'LOWER(cichu.login) LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeBy / Operator LIKE',
        Search       => {
            Field    => 'ChangeBy',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join'  => [
                'INNER JOIN users cichu ON cichu.id = ci.change_by'
            ],
            'Where' => [
                'LOWER(cichu.login) LIKE \'test\''
            ]
        }
    }
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
        Name      => 'Sort: Attribute "CreateByID"',
        Attribute => 'CreateByID',
        Expected  => {
            'Join'    => [],
            'OrderBy' => [
                'ci.create_by'
            ],
            'Select'  => [
                'ci.create_by'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "CreateBy"',
        Attribute => 'CreateBy',
        Expected  => {
            'Join' => [
                'INNER JOIN users cicru ON cicru.id = ci.create_by',
                'LEFT OUTER JOIN contact cicruc ON cicruc.user_id = cicru.id'
            ],
            'OrderBy' => [
                'LOWER(cicruc.lastname)',
                'LOWER(cicruc.firstname)',
                'LOWER(cicru.login)'
            ],
            'Select' => [
                'cicruc.lastname',
                'cicruc.firstname',
                'cicru.login'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "ChangeByID"',
        Attribute => 'ChangeByID',
        Expected  => {
            'Join'    => [],
            'OrderBy' => [
                'ci.change_by'
            ],
            'Select'  => [
                'ci.change_by'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "ChangeBy"',
        Attribute => 'ChangeBy',
        Expected  => {
            'Join' => [
                'INNER JOIN users cichu ON cichu.id = ci.change_by',
                'LEFT OUTER JOIN contact cichuc ON cichuc.user_id = cichu.id'
            ],
            'OrderBy' => [
                'LOWER(cichuc.lastname)',
                'LOWER(cichuc.firstname)',
                'LOWER(cichu.login)'
            ],
            'Select' => [
                'cichuc.lastname',
                'cichuc.firstname',
                'cichu.login'
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

## prepare user mapping
my $RoleID = $Kernel::OM->Get('Role')->RoleLookup(
    Role => 'Ticket Agent'
);
my $UserLogin1 = 'Test001';
my $UserLogin2 = 'test002';
my $UserLogin3 = 'Test003';
my $ContactFirstName1 = 'Alf';
my $ContactFirstName2 = 'Bert';
my $ContactLastName1  = 'test';
my $ContactLastName2  = 'Test';
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
    AssignedUserID        => $UserID2,
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

# discard contact object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Contact'],
);

# discard user object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['User'],
);

# prepare class mapping
my $ClassRef = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class         => 'ITSM::ConfigItem::Class',
    Name          => 'Building',
    NoPreferences => 1
);

## prepare test assets ##
# first asset
my $ConfigItemID1 = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
    ClassID => $ClassRef->{ItemID},
    UserID  => $UserID1,
);
$Self->True(
    $ConfigItemID1,
    'Created first asset'
);
# second asset
my $ConfigItemID2 = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
    ClassID => $ClassRef->{ItemID},
    UserID  => $UserID2,
);
$Self->True(
    $ConfigItemID2,
    'Created second asset'
);
# third asset
my $ConfigItemID3 = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
    ClassID => $ClassRef->{ItemID},
    UserID  => $UserID3,
);
$Self->True(
    $ConfigItemID3,
    'Created third asset'
);

# discard config item object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['ITSMConfigItem'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field CreateByID / Operator EQ / Value $UserID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateByID',
                    Operator => 'EQ',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field CreateByID / Operator NE / Value $UserID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateByID',
                    Operator => 'NE',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID3]
    },
    {
        Name     => 'Search: Field CreateByID / Operator IN / Value [$UserID1,$UserID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateByID',
                    Operator => 'IN',
                    Value    => [$UserID1,$UserID3]
                }
            ]
        },
        Expected => [$ConfigItemID1, $ConfigItemID3]
    },
    {
        Name     => 'Search: Field CreateByID / Operator !IN / Value [$UserID1,$UserID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateByID',
                    Operator => '!IN',
                    Value    => [$UserID1,$UserID3]
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field CreateByID / Operator LT / Value $UserID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateByID',
                    Operator => 'LT',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$ConfigItemID1]
    },
    {
        Name     => 'Search: Field CreateByID / Operator GT / Value $UserID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateByID',
                    Operator => 'GT',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$ConfigItemID3]
    },
    {
        Name     => 'Search: Field CreateByID / Operator LTE / Value $UserID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateByID',
                    Operator => 'LTE',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$ConfigItemID1, $ConfigItemID2]
    },
    {
        Name     => 'Search: Field CreateByID / Operator GTE / Value $UserID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateByID',
                    Operator => 'GTE',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$ConfigItemID2, $ConfigItemID3]
    },
    {
        Name     => 'Search: Field CreateBy / Operator EQ / Value $UserLogin2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateBy',
                    Operator => 'EQ',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field CreateBy / Operator NE / Value $UserLogin2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateBy',
                    Operator => 'NE',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID3]
    },
    {
        Name     => 'Search: Field CreateBy / Operator IN / Value [$UserLogin1,$UserLogin3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateBy',
                    Operator => 'IN',
                    Value    => [$UserLogin1,$UserLogin3]
                }
            ]
        },
        Expected => [$ConfigItemID1, $ConfigItemID3]
    },
    {
        Name     => 'Search: Field CreateBy / Operator !IN / Value [$UserLogin1,$UserLogin3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateBy',
                    Operator => '!IN',
                    Value    => [$UserLogin1,$UserLogin3]
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field CreateBy / Operator STARTSWITH / Value $UserLogin2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateBy',
                    Operator => 'STARTSWITH',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field CreateBy / Operator ENDSWITH / Value $UserLogin2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateBy',
                    Operator => 'ENDSWITH',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field CreateBy / Operator CONTAINS / Value $UserLogin2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateBy',
                    Operator => 'CONTAINS',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field CreateBy / Operator LIKE / Value $UserLogin2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateBy',
                    Operator => 'LIKE',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field ChangeByID / Operator EQ / Value $UserID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeByID',
                    Operator => 'EQ',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field ChangeByID / Operator NE / Value $UserID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeByID',
                    Operator => 'NE',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID3]
    },
    {
        Name     => 'Search: Field ChangeByID / Operator IN / Value [$UserID1,$UserID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeByID',
                    Operator => 'IN',
                    Value    => [$UserID1,$UserID3]
                }
            ]
        },
        Expected => [$ConfigItemID1, $ConfigItemID3]
    },
    {
        Name     => 'Search: Field ChangeByID / Operator !IN / Value [$UserID1,$UserID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeByID',
                    Operator => '!IN',
                    Value    => [$UserID1,$UserID3]
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field ChangeByID / Operator LT / Value $UserID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeByID',
                    Operator => 'LT',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$ConfigItemID1]
    },
    {
        Name     => 'Search: Field ChangeByID / Operator GT / Value $UserID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeByID',
                    Operator => 'GT',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$ConfigItemID3]
    },
    {
        Name     => 'Search: Field ChangeByID / Operator LTE / Value $UserID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeByID',
                    Operator => 'LTE',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$ConfigItemID1, $ConfigItemID2]
    },
    {
        Name     => 'Search: Field ChangeByID / Operator GTE / Value $UserID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeByID',
                    Operator => 'GTE',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$ConfigItemID2, $ConfigItemID3]
    },
    {
        Name     => 'Search: Field ChangeBy / Operator EQ / Value $UserLogin2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeBy',
                    Operator => 'EQ',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field ChangeBy / Operator NE / Value $UserLogin2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeBy',
                    Operator => 'NE',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID3]
    },
    {
        Name     => 'Search: Field ChangeBy / Operator IN / Value [$UserLogin1,$UserLogin3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeBy',
                    Operator => 'IN',
                    Value    => [$UserLogin1,$UserLogin3]
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID3]
    },
    {
        Name     => 'Search: Field ChangeBy / Operator !IN / Value [$UserLogin1,$UserLogin3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeBy',
                    Operator => '!IN',
                    Value    => [$UserLogin1,$UserLogin3]
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field ChangeBy / Operator STARTSWITH / Value $UserLogin2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeBy',
                    Operator => 'STARTSWITH',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field ChangeBy / Operator STARTSWITH / Value substr($UserLogin2,0,2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeBy',
                    Operator => 'STARTSWITH',
                    Value    => substr($UserLogin2,0,2)
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => 'Search: Field ChangeBy / Operator ENDSWITH / Value $UserLogin2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeBy',
                    Operator => 'ENDSWITH',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field ChangeBy / Operator ENDSWITH / Value substr($UserLogin2,-3)',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeBy',
                    Operator => 'ENDSWITH',
                    Value    => substr($UserLogin2,-3)
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field ChangeBy / Operator CONTAINS / Value $UserLogin2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeBy',
                    Operator => 'CONTAINS',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field ChangeBy / Operator CONTAINS / Value substr($UserLogin2,1,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeBy',
                    Operator => 'CONTAINS',
                    Value    => substr($UserLogin2,1,-2)
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => 'Search: Field ChangeBy / Operator LIKE / Value $UserLogin2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeBy',
                    Operator => 'LIKE',
                    Value    => $UserLogin2
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
my @IntegrationSortTests = (
    {
        Name     => 'Sort: Field CreateByID',
        Sort     => [
            {
                Field => 'CreateByID'
            }
        ],
        Expected => [$ConfigItemID1, $ConfigItemID2, $ConfigItemID3]
    },
    {
        Name     => 'Sort: Field CreateByID / Direction ascending',
        Sort     => [
            {
                Field     => 'CreateByID',
                Direction => 'ascending'
            }
        ],
        Expected => [$ConfigItemID1, $ConfigItemID2, $ConfigItemID3]
    },
    {
        Name     => 'Sort: Field CreateByID / Direction descending',
        Sort     => [
            {
                Field     => 'CreateByID',
                Direction => 'descending'
            }
        ],
        Expected => [$ConfigItemID3, $ConfigItemID2, $ConfigItemID1]
    },
    {
        Name     => 'Sort: Field CreateBy',
        Sort     => [
            {
                Field => 'CreateBy'
            }
        ],
        Expected => [$ConfigItemID1, $ConfigItemID2, $ConfigItemID3]
    },
    {
        Name     => 'Sort: Field CreateBy / Direction ascending',
        Sort     => [
            {
                Field     => 'CreateBy',
                Direction => 'ascending'
            }
        ],
        Expected => [$ConfigItemID1, $ConfigItemID2, $ConfigItemID3]
    },
    {
        Name     => 'Sort: Field CreateBy / Direction descending',
        Sort     => [
            {
                Field     => 'CreateBy',
                Direction => 'descending'
            }
        ],
        Expected => [$ConfigItemID3, $ConfigItemID2, $ConfigItemID1]
    },
    {
        Name     => 'Sort: Field ChangeByID',
        Sort     => [
            {
                Field => 'ChangeByID'
            }
        ],
        Expected => [$ConfigItemID1, $ConfigItemID2, $ConfigItemID3]
    },
    {
        Name     => 'Sort: Field ChangeByID / Direction ascending',
        Sort     => [
            {
                Field     => 'ChangeByID',
                Direction => 'ascending'
            }
        ],
        Expected => [$ConfigItemID1, $ConfigItemID2, $ConfigItemID3]
    },
    {
        Name     => 'Sort: Field ChangeByID / Direction descending',
        Sort     => [
            {
                Field     => 'ChangeByID',
                Direction => 'descending'
            }
        ],
        Expected => [$ConfigItemID3, $ConfigItemID2, $ConfigItemID1]
    },
    {
        Name     => 'Sort: Field ChangeBy',
        Sort     => [
            {
                Field => 'ChangeBy'
            }
        ],
        Expected => [$ConfigItemID1, $ConfigItemID2, $ConfigItemID3]
    },
    {
        Name     => 'Sort: Field ChangeBy / Direction ascending',
        Sort     => [
            {
                Field     => 'ChangeBy',
                Direction => 'ascending'
            }
        ],
        Expected => [$ConfigItemID1, $ConfigItemID2, $ConfigItemID3]
    },
    {
        Name     => 'Sort: Field ChangeBy / Direction descending',
        Sort     => [
            {
                Field     => 'ChangeBy',
                Direction => 'descending'
            }
        ],
        Expected => [$ConfigItemID3, $ConfigItemID2, $ConfigItemID1]
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'ConfigItem',
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
