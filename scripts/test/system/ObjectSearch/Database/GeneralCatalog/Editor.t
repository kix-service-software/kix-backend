# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::GeneralCatalog::Editor';

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
        CreateByID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType    => 'NUMERIC'
        },
        CreateBy => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType    => 'NUMERIC'
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
            Operators    => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType    => 'NUMERIC'
        }
    },
    'GetSupportedAttributes provides expected data'
);

# get handling of order by null
my $OrderByNull = $Kernel::OM->Get('DB')->GetDatabaseFunction('OrderByNull') || '';

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
            'Where' => [
                'gc.create_by = 1'
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
            'Where' => [
                'gc.create_by <> 1'
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
            'Where' => [
                'gc.create_by IN (1)'
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
            'Where' => [
                'gc.create_by NOT IN (1)'
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
            'Where' => [
                'gc.create_by < 1'
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
            'Where' => [
                'gc.create_by > 1'
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
            'Where' => [
                'gc.create_by <= 1'
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
            'Where' => [
                'gc.create_by >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreateBy / Operator EQ',
        Search       => {
            Field    => 'CreateBy',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'gc.create_by = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreateBy / Operator NE',
        Search       => {
            Field    => 'CreateBy',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'gc.create_by <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreateBy / Operator IN',
        Search       => {
            Field    => 'CreateBy',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'gc.create_by IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreateBy / Operator !IN',
        Search       => {
            Field    => 'CreateBy',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'gc.create_by NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreateBy / Operator LT',
        Search       => {
            Field    => 'CreateBy',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'gc.create_by < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreateBy / Operator LTE',
        Search       => {
            Field    => 'CreateBy',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'gc.create_by <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreateBy / Operator GT',
        Search       => {
            Field    => 'CreateBy',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'gc.create_by > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreateBy / Operator GTE',
        Search       => {
            Field    => 'CreateBy',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'gc.create_by >= 1'
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
            'Where' => [
                'gc.change_by = 1'
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
            'Where' => [
                'gc.change_by <> 1'
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
            'Where' => [
                'gc.change_by IN (1)'
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
            'Where' => [
                'gc.change_by NOT IN (1)'
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
            'Where' => [
                'gc.change_by < 1'
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
            'Where' => [
                'gc.change_by > 1'
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
            'Where' => [
                'gc.change_by <= 1'
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
            'Where' => [
                'gc.change_by >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeBy / Operator EQ',
        Search       => {
            Field    => 'ChangeBy',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'gc.change_by = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeBy / Operator NE',
        Search       => {
            Field    => 'ChangeBy',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'gc.change_by <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeBy / Operator IN',
        Search       => {
            Field    => 'ChangeBy',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'gc.change_by IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeBy / Operator !IN',
        Search       => {
            Field    => 'ChangeBy',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'gc.change_by NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeBy / Operator LT',
        Search       => {
            Field    => 'ChangeBy',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'gc.change_by < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeBy / Operator LTE',
        Search       => {
            Field    => 'ChangeBy',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'gc.change_by <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeBy / Operator GT',
        Search       => {
            Field    => 'ChangeBy',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'gc.change_by > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ChangeBy / Operator GTE',
        Search       => {
            Field    => 'ChangeBy',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'gc.change_by >= 1'
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
            'Select'  => ['gc.create_by'],
            'OrderBy' => ['gc.create_by']
        }
    },
    {
        Name      => 'Sort: Attribute "CreateBy"',
        Attribute => 'CreateBy',
        Expected  => {
            'Join' => [
                'INNER JOIN users gccru ON gccru.id = gc.create_by',
                'LEFT OUTER JOIN contact gccruc ON gccruc.user_id = gccru.id'
            ],
            'OrderBy' => [
                'LOWER(gccruc.lastname)',
                'LOWER(gccruc.firstname)',
                'LOWER(gccru.login)'
            ],
            'Select' => [
                'gccruc.lastname',
                'gccruc.firstname',
                'gccru.login'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "ChangeByID"',
        Attribute => 'ChangeByID',
        Expected  => {
            'Join'    => [],
            'Select'  => ['gc.change_by'],
            'OrderBy' => ['gc.change_by']
        }
    },
    {
        Name      => 'Sort: Attribute "ChangeBy"',
        Attribute => 'ChangeBy',
        Expected  => {
            'Join' => [
                'INNER JOIN users gcchu ON gcchu.id = gc.change_by',
                'LEFT OUTER JOIN contact gcchuc ON gcchuc.user_id = gcchu.id'
            ],
            'OrderBy' => [
                'LOWER(gcchuc.lastname)',
                'LOWER(gcchuc.firstname)',
                'LOWER(gcchu.login)'
            ],
            'Select' => [
                'gcchuc.lastname',
                'gcchuc.firstname',
                'gcchu.login'
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
    Role => 'item Maintainer'
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
    UserID                => $UserID1,
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
    UserID                => $UserID2
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

# discard contact,user object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => [
        'Contact',
        'User'
    ],
);

## prepare test general catalog items ##
# first item
my $ItemID1 = $Kernel::OM->Get('GeneralCatalog')->ItemAdd(
    Class   => 'Unit::Test::Type',
    Name    => 'Foo',
    ValidID => 1,
    UserID  => $UserID1
);
$Self->True(
    $ItemID1,
    'Created first item'
);
# second item
my $ItemID2 = $Kernel::OM->Get('GeneralCatalog')->ItemAdd(
    Class   => 'Unit::Test::Type',
    Name    => 'Baa',
    ValidID => 1,
    UserID  => $UserID2
);
$Self->True(
    $ItemID2,
    'Created second item'
);
# third item
my $ItemID3 = $Kernel::OM->Get('GeneralCatalog')->ItemAdd(
    Class   => 'Unit::Test::Type',
    Name    => 'Test',
    ValidID => 1,
    UserID  => $UserID3
);
$Self->True(
    $ItemID3,
    'Created third item'
);

# discard config item object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['GeneralCatalog'],
);

# prepare result lists
my @ItemIDs = $ObjectSearch->Search(
    ObjectType => 'GeneralCatalog',
    Result     => 'ARRAY',
    UserType   => 'Agent',
    UserID     => 1,
);

$Self->True(
    scalar( @ItemIDs ),
    'ItemID: GET / All Items'
);

# List for NE
my @TmpList = @ItemIDs;
splice(@TmpList, -2,1);  # remove ItemID2
my @List1 = @TmpList;

# List for !IN
@TmpList = @ItemIDs;
splice(@TmpList, -1,1);  # remove ItemID3
splice(@TmpList, -2,1);  # remove ItemID1
my @List2 = @TmpList;

# List for LT
@TmpList = @ItemIDs;
splice(@TmpList, -2); # remove all beyond ItemID2 and include ItemID2
my @List3 = @TmpList;

# List for LTE
@TmpList = @ItemIDs;
splice(@TmpList, -1); # remove all beyond ItemID2 and include ItemID2
my @List4 = @TmpList;

# List for GT
@TmpList = @ItemIDs;
splice(@TmpList, 0,-1); # remove all before ItemID2 and include ItemID2
my @List5 = @TmpList;

# List for GTE
@TmpList = @ItemIDs;
splice(@TmpList, 0, -2); # remove all before ItemID2
my @List6 = @TmpList;


# test Search
my @IntegrationSearchTests = (
    {
        Name     => "Search: Field CreateByID / Operator EQ / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateByID',
                    Operator => 'EQ',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$ItemID2]
    },
    {
        Name     => "Search: Field CreateByID / Operator NE / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateByID',
                    Operator => 'NE',
                    Value    => $UserID2
                }
            ]
        },
        Expected => \@List1
    },
    {
        Name     => "Search: Field CreateByID / Operator IN / Value [\$UserID1,\$UserID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateByID',
                    Operator => 'IN',
                    Value    => [$UserID1,$UserID3]
                }
            ]
        },
        Expected => [$ItemID1, $ItemID3]
    },
    {
        Name     => "Search: Field CreateByID / Operator !IN / Value [\$UserID1,\$UserID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateByID',
                    Operator => '!IN',
                    Value    => [$UserID1,$UserID3]
                }
            ]
        },
        Expected => \@List2
    },
    {
        Name     => "Search: Field CreateByID / Operator LT / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateByID',
                    Operator => 'LT',
                    Value    => $UserID2
                }
            ]
        },
        Expected => \@List3
    },
    {
        Name     => "Search: Field CreateByID / Operator GT / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateByID',
                    Operator => 'GT',
                    Value    => $UserID2
                }
            ]
        },
        Expected => \@List5
    },
    {
        Name     => "Search: Field CreateByID / Operator LTE / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateByID',
                    Operator => 'LTE',
                    Value    => $UserID2
                }
            ]
        },
        Expected => \@List4
    },
    {
        Name     => "Search: Field CreateByID / Operator GTE / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateByID',
                    Operator => 'GTE',
                    Value    => $UserID2
                }
            ]
        },
        Expected => \@List6
    },
    {
        Name     => "Search: Field CreateBy / Operator EQ / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateBy',
                    Operator => 'EQ',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$ItemID2]
    },
    {
        Name     => "Search: Field CreateBy / Operator NE / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateBy',
                    Operator => 'NE',
                    Value    => $UserID2
                }
            ]
        },
        Expected => \@List1
    },
    {
        Name     => "Search: Field CreateBy / Operator IN / Value [\$UserID1,\$UserID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateBy',
                    Operator => 'IN',
                    Value    => [$UserID1,$UserID3]
                }
            ]
        },
        Expected => [$ItemID1, $ItemID3]
    },
    {
        Name     => "Search: Field CreateBy / Operator !IN / Value [\$UserID1,\$UserID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateBy',
                    Operator => '!IN',
                    Value    => [$UserID1,$UserID3]
                }
            ]
        },
        Expected => \@List2
    },
    {
        Name     => "Search: Field CreateBy / Operator LT / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateBy',
                    Operator => 'LT',
                    Value    => $UserID2
                }
            ]
        },
        Expected => \@List3
    },
    {
        Name     => "Search: Field CreateBy / Operator GT / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateBy',
                    Operator => 'GT',
                    Value    => $UserID2
                }
            ]
        },
        Expected => \@List5
    },
    {
        Name     => "Search: Field CreateBy / Operator LTE / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateBy',
                    Operator => 'LTE',
                    Value    => $UserID2
                }
            ]
        },
        Expected => \@List4
    },
    {
        Name     => "Search: Field CreateBy / Operator GTE / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'CreateBy',
                    Operator => 'GTE',
                    Value    => $UserID2
                }
            ]
        },
        Expected => \@List6
    },
    {
        Name     => "Search: Field ChangeByID / Operator EQ / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeByID',
                    Operator => 'EQ',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$ItemID2]
    },
    {
        Name     => "Search: Field ChangeByID / Operator NE / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeByID',
                    Operator => 'NE',
                    Value    => $UserID2
                }
            ]
        },
        Expected => \@List1
    },
    {
        Name     => "Search: Field ChangeByID / Operator IN / Value [\$UserID1,\$UserID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeByID',
                    Operator => 'IN',
                    Value    => [$UserID1,$UserID3]
                }
            ]
        },
        Expected => [$ItemID1, $ItemID3]
    },
    {
        Name     => "Search: Field ChangeByID / Operator !IN / Value [\$UserID1,\$UserID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeByID',
                    Operator => '!IN',
                    Value    => [$UserID1,$UserID3]
                }
            ]
        },
        Expected => \@List2
    },
    {
        Name     => "Search: Field ChangeByID / Operator LT / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeByID',
                    Operator => 'LT',
                    Value    => $UserID2
                }
            ]
        },
        Expected => \@List3
    },
    {
        Name     => "Search: Field ChangeByID / Operator GT / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeByID',
                    Operator => 'GT',
                    Value    => $UserID2
                }
            ]
        },
        Expected => \@List5
    },
    {
        Name     => "Search: Field ChangeByID / Operator LTE / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeByID',
                    Operator => 'LTE',
                    Value    => $UserID2
                }
            ]
        },
        Expected => \@List4
    },
    {
        Name     => "Search: Field ChangeByID / Operator GTE / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeByID',
                    Operator => 'GTE',
                    Value    => $UserID2
                }
            ]
        },
        Expected => \@List6
    },
    {
        Name     => "Search: Field ChangeBy / Operator EQ / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeBy',
                    Operator => 'EQ',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$ItemID2]
    },
    {
        Name     => "Search: Field ChangeBy / Operator NE / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeBy',
                    Operator => 'NE',
                    Value    => $UserID2
                }
            ]
        },
        Expected => \@List1
    },
    {
        Name     => "Search: Field ChangeBy / Operator IN / Value [\$UserID1,\$UserID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeBy',
                    Operator => 'IN',
                    Value    => [$UserID1,$UserID3]
                }
            ]
        },
        Expected => [$ItemID1,$ItemID3]
    },
    {
        Name     => "Search: Field ChangeBy / Operator !IN / Value [\$UserID1,\$UserID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeBy',
                    Operator => '!IN',
                    Value    => [$UserID1,$UserID3]
                }
            ]
        },
        Expected => \@List2
    },
    {
        Name     => "Search: Field ChangeBy / Operator LT / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeBy',
                    Operator => 'LT',
                    Value    => $UserID2
                }
            ]
        },
        Expected => \@List3
    },
    {
        Name     => "Search: Field ChangeBy / Operator GT / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeBy',
                    Operator => 'GT',
                    Value    => $UserID2
                }
            ]
        },
        Expected => \@List5
    },
    {
        Name     => "Search: Field ChangeBy / Operator LTE / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeBy',
                    Operator => 'LTE',
                    Value    => $UserID2
                }
            ]
        },
        Expected => \@List4
    },
    {
        Name     => "Search: Field ChangeBy / Operator GTE / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ChangeBy',
                    Operator => 'GTE',
                    Value    => $UserID2
                }
            ]
        },
        Expected => \@List6
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'GeneralCatalog',
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
        Expected => \@ItemIDs
    },
    {
        Name     => 'Sort: Field CreateByID / Direction ascending',
        Sort     => [
            {
                Field     => 'CreateByID',
                Direction => 'ascending'
            }
        ],
        Expected => \@ItemIDs
    },
    {
        Name     => 'Sort: Field CreateByID / Direction descending',
        Sort     => [
            {
                Field     => 'CreateByID',
                Direction => 'descending'
            }
        ],
        Limit    => 3,
        Expected => [$ItemID3, $ItemID2, $ItemID1]
    },
    {
        Name     => 'Sort: Field CreateBy',
        Sort     => [
            {
                Field => 'CreateBy'
            }
        ],
        Expected => \@ItemIDs
    },
    {
        Name     => 'Sort: Field CreateBy / Direction ascending',
        Sort     => [
            {
                Field     => 'CreateBy',
                Direction => 'ascending'
            }
        ],
        Expected => \@ItemIDs
    },
    {
        Name     => 'Sort: Field CreateBy / Direction descending',
        Sort     => [
            {
                Field     => 'CreateBy',
                Direction => 'descending'
            }
        ],
        Limit    => 3,
        Expected => [$ItemID3, $ItemID2, $ItemID1]
    },
    {
        Name     => 'Sort: Field ChangeByID',
        Sort     => [
            {
                Field => 'ChangeByID'
            }
        ],
        Expected => \@ItemIDs
    },
    {
        Name     => 'Sort: Field ChangeByID / Direction ascending',
        Sort     => [
            {
                Field     => 'ChangeByID',
                Direction => 'ascending'
            }
        ],
        Expected => \@ItemIDs
    },
    {
        Name     => 'Sort: Field ChangeByID / Direction descending',
        Sort     => [
            {
                Field     => 'ChangeByID',
                Direction => 'descending'
            }
        ],
        Limit    => 3,
        Expected => [$ItemID3, $ItemID2, $ItemID1]
    },
    {
        Name     => 'Sort: Field ChangeBy',
        Sort     => [
            {
                Field => 'ChangeBy'
            }
        ],
        Expected => \@ItemIDs
    },
    {
        Name     => 'Sort: Field ChangeBy / Direction ascending',
        Sort     => [
            {
                Field     => 'ChangeBy',
                Direction => 'ascending'
            }
        ],
        Expected => \@ItemIDs
    },
    {
        Name     => 'Sort: Field ChangeBy / Direction descending',
        Sort     => [
            {
                Field     => 'ChangeBy',
                Direction => 'descending'
            }
        ],
        Limit    => 3,
        Expected => [$ItemID3, $ItemID2, $ItemID1]
    }
);
if ( $OrderByNull eq 'LAST' ) {
    for my $Test ( @IntegrationSortTests ) {
        my @Result = $ObjectSearch->Search(
            ObjectType => 'GeneralCatalog',
            Result     => 'ARRAY',
            Sort       => $Test->{Sort},
            Language   => $Test->{Language},
            UserType   => 'Agent',
            UserID     => 1,
            Limit      => $Test->{Limit}
        );
        $Self->IsDeeply(
            \@Result,
            $Test->{Expected},
            $Test->{Name}
        );
    }
}
else {
    $Self->True(
        1,
        '## TODO ## Check Sort for OrderByNull FIRST'
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
