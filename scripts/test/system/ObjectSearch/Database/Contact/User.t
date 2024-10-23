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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Contact::User';

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
        UserID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN'],
            ValueType    => 'NUMERIC'
        },
        AssignedUserID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN'],
            ValueType    => 'NUMERIC'
        },
        Login => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        UserLogin => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        }
    },
    'GetSupportedAttributes provides expected data'
);

# Quoting ESCAPE character backslash
my $QuoteBack = $Kernel::OM->Get('DB')->GetDatabaseFunction('QuoteBack');
my $Escape = "\\";
if ( $QuoteBack ) {
    $Escape =~ s/\\/$QuoteBack\\/g;
}

# Quoting single quote character
my $QuoteSingle = $Kernel::OM->Get('DB')->GetDatabaseFunction('QuoteSingle');

# Quoting semicolon character
my $QuoteSemicolon = $Kernel::OM->Get('DB')->GetDatabaseFunction('QuoteSemicolon');

# check if database is casesensitive
my $CaseSensitive = $Kernel::OM->Get('DB')->GetDatabaseFunction('CaseSensitive');

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
            Field    => 'Title',
            Operator => 'LIKE',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Field undef',
        Search       => {
            Field    => undef,
            Operator => 'LIKE',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Field invalid',
        Search       => {
            Field    => 'Test',
            Operator => 'LIKE',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator undef',
        Search       => {
            Field    => 'UserID',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'UserID',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field UserID / Operator EQ',
        Search       => {
            Field    => 'UserID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join' => [],
            'Where' => [
                'c.user_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field UserID / Operator NE',
        Search       => {
            Field    => 'UserID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [],
            'Where' => [
                '(c.user_id <> 1 OR c.user_id IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field UserID / Operator IN',
        Search       => {
            Field    => 'UserID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join' => [],
            'Where' => [
                'c.user_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field UserID / Operator !IN',
        Search       => {
            Field    => 'UserID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join' => [],
            'Where' => [
                'c.user_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AssignedUserID / Operator EQ',
        Search       => {
            Field    => 'AssignedUserID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join' => [],
            'Where' => [
                'c.user_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AssignedUserID / Operator NE',
        Search       => {
            Field    => 'AssignedUserID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [],
            'Where' => [
                '(c.user_id <> 1 OR c.user_id IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AssignedUserID / Operator IN',
        Search       => {
            Field    => 'AssignedUserID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join' => [],
            'Where' => [
                'c.user_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AssignedUserID / Operator !IN',
        Search       => {
            Field    => 'AssignedUserID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join' => [],
            'Where' => [
                'c.user_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Login / Operator EQ',
        Search       => {
            Field    => 'Login',
            Operator => 'EQ',
            Value    => 'testlog'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN users u0 ON c.user_id = u0.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(u0.login) = \'testlog\'' : 'u0.login = \'testlog\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Login / Operator NE',
        Search       => {
            Field    => 'Login',
            Operator => 'NE',
            Value    => 'testlog'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN users u0 ON c.user_id = u0.id'
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(u0.login) != \'testlog\' OR u0.login IS NULL)' : '(u0.login != \'testlog\' OR u0.login IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Login / Operator IN',
        Search       => {
            Field    => 'Login',
            Operator => 'IN',
            Value    => 'testlog'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN users u0 ON c.user_id = u0.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(u0.login) IN (\'testlog\')' : 'u0.login IN (\'testlog\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Login / Operator !IN',
        Search       => {
            Field    => 'Login',
            Operator => 'NE',
            Value    => 'testlog'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN users u0 ON c.user_id = u0.id'
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(u0.login) != \'testlog\' OR u0.login IS NULL)' : '(u0.login != \'testlog\' OR u0.login IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Login / Operator STARTSWITRH',
        Search       => {
            Field    => 'Login',
            Operator => 'STARTSWITH',
            Value    => 'testlog'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN users u0 ON c.user_id = u0.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(u0.login) LIKE \'testlog%\'' : 'u0.login LIKE \'testlog%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Login / Operator ENDSWITH',
        Search       => {
            Field    => 'Login',
            Operator => 'ENDSWITH',
            Value    => 'testlog'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN users u0 ON c.user_id = u0.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(u0.login) LIKE \'%testlog\'' : 'u0.login LIKE \'%testlog\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Login / Operator CONTAINS',
        Search       => {
            Field    => 'Login',
            Operator => 'CONTAINS',
            Value    => 'testlog'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN users u0 ON c.user_id = u0.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(u0.login) LIKE \'%testlog%\'' : 'u0.login LIKE \'%testlog%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Login / Operator LIKE',
        Search       => {
            Field    => 'Login',
            Operator => 'LIKE',
            Value    => 'testlog'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN users u0 ON c.user_id = u0.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(u0.login) LIKE \'testlog\'' : 'u0.login LIKE \'testlog\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field UserLogin / Operator EQ',
        Search       => {
            Field    => 'UserLogin',
            Operator => 'EQ',
            Value    => 'testlog'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN users u0 ON c.user_id = u0.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(u0.login) = \'testlog\'' : 'u0.login = \'testlog\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field UserLogin / Operator NE',
        Search       => {
            Field    => 'UserLogin',
            Operator => 'NE',
            Value    => 'testlog'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN users u0 ON c.user_id = u0.id'
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(u0.login) != \'testlog\' OR u0.login IS NULL)' : '(u0.login != \'testlog\' OR u0.login IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field UserLogin / Operator IN',
        Search       => {
            Field    => 'UserLogin',
            Operator => 'IN',
            Value    => 'testlog'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN users u0 ON c.user_id = u0.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(u0.login) IN (\'testlog\')' : 'u0.login IN (\'testlog\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field UserLogin / Operator !IN',
        Search       => {
            Field    => 'UserLogin',
            Operator => 'NE',
            Value    => 'testlog'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN users u0 ON c.user_id = u0.id'
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(u0.login) != \'testlog\' OR u0.login IS NULL)' : '(u0.login != \'testlog\' OR u0.login IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field UserLogin / Operator STARTSWITRH',
        Search       => {
            Field    => 'UserLogin',
            Operator => 'STARTSWITH',
            Value    => 'testlog'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN users u0 ON c.user_id = u0.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(u0.login) LIKE \'testlog%\'' : 'u0.login LIKE \'testlog%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field UserLogin / Operator ENDSWITH',
        Search       => {
            Field    => 'UserLogin',
            Operator => 'ENDSWITH',
            Value    => 'testlog'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN users u0 ON c.user_id = u0.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(u0.login) LIKE \'%testlog\'' : 'u0.login LIKE \'%testlog\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field UserLogin / Operator CONTAINS',
        Search       => {
            Field    => 'UserLogin',
            Operator => 'CONTAINS',
            Value    => 'testlog'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN users u0 ON c.user_id = u0.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(u0.login) LIKE \'%testlog%\'' : 'u0.login LIKE \'%testlog%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field UserLogin / Operator LIKE',
        Search       => {
            Field    => 'UserLogin',
            Operator => 'LIKE',
            Value    => 'testlog'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN users u0 ON c.user_id = u0.id'
            ],
            'Where' => [
                $CaseSensitive ? 'LOWER(u0.login) LIKE \'testlog\'' : 'u0.login LIKE \'testlog\''
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
        Name      => 'Sort: Attribute "UserID"',
        Attribute => 'UserID',
        Expected  => {
            'Join' => [],
            'OrderBy' => [
                'c.user_id'
            ],
            'Select' => [
                'c.user_id'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "AssignedUserID"',
        Attribute => 'AssignedUserID',
        Expected  => {
            'Join' => [],
            'OrderBy' => [
                'c.user_id'
            ],
            'Select' => [
                'c.user_id'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Login"',
        Attribute => 'Login',
        Expected  => {
            'Join' => [
                'LEFT JOIN users u0 ON c.user_id = u0.id'
            ],
            'OrderBy' => [
                'u0.login'
            ],
            'Select' => [
                'u0.login'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "UserLogin"',
        Attribute => 'UserLogin',
        Expected  => {
            'Join' => [
                'LEFT JOIN users u0 ON c.user_id = u0.id'
            ],
            'OrderBy' => [
                'u0.login'
            ],
            'Select' => [
                'u0.login'
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
    Role => 'Customer Manager'
);
my $UserLogin1 = 'Test101';
my $UserLogin2 = 'test102';
my $UserLogin3 = 'Test103';
my $UserID1 = $Kernel::OM->Get('User')->UserAdd(
    UserLogin     => $UserLogin1,
    ValidID       => 1,
    ChangeUserID  => 1,
    UserID       => 1
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
    Firstname             => $Helper->GetRandomID(),
    Lastname              => $Helper->GetRandomID(),
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
    AssignedUserID    => 1
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
    Firstname             => $Helper->GetRandomID(),
    Lastname              => $Helper->GetRandomID(),
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
    AssignedUserID    => 1,
    UserID       => 1
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
    Firstname             => $Helper->GetRandomID(),
    Lastname              => $Helper->GetRandomID(),
    AssignedUserID        => $UserID3,
    ValidID               => 1,
    UserID                => $UserID3
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

# test Search
my @IntegrationSearchTests = (
    {
        Name     => "Search: Field UserID / Operator EQ / Value \$UserID1",
        Search   => {
            'AND' => [
                {
                    Field    => 'UserID',
                    Operator => 'EQ',
                    Value    => $UserID1
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field UserID / Operator NE / Value \$UserID1",
        Search   => {
            'AND' => [
                {
                    Field    => 'UserID',
                    Operator => 'NE',
                    Value    => $UserID1
                }
            ]
        },
        Expected => ['1',$ContactID2,$ContactID3]
    },
    {
        Name     => "Search: Field UserID / Operator IN / Value [\$UserID1,\$UserID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'UserID',
                    Operator => 'IN',
                    Value    => [$UserID1,$UserID3]
                }
            ]
        },
        Expected => [$ContactID1,$ContactID3]
    },
    {
        Name     => "Search: Field UserID / Operator !IN / Value [\$UserID1,\$UserID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'UserID',
                    Operator => '!IN',
                    Value    => [$UserID1,$UserID3]
                }
            ]
        },
        Expected => ['1',$ContactID2]
    },
    {
        Name     => "Search: Field AssignedUserID / Operator EQ / Value \$UserID1",
        Search   => {
            'AND' => [
                {
                    Field    => 'AssignedUserID',
                    Operator => 'EQ',
                    Value    => $UserID1
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field AssignedUserID / Operator NE / Value \$UserID1",
        Search   => {
            'AND' => [
                {
                    Field    => 'AssignedUserID',
                    Operator => 'NE',
                    Value    => $UserID1
                }
            ]
        },
        Expected => ['1',$ContactID2,$ContactID3]
    },
    {
        Name     => "Search: Field AssignedUserID / Operator IN / Value [\$UserID1,\$UserID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'AssignedUserID',
                    Operator => 'IN',
                    Value    => [$UserID1,$UserID3]
                }
            ]
        },
        Expected => [$ContactID1,$ContactID3]
    },
    {
        Name     => "Search: Field AssignedUserID / Operator !IN / Value [\$UserID1,\$UserID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'AssignedUserID',
                    Operator => '!IN',
                    Value    => [$UserID1,$UserID3]
                }
            ]
        },
        Expected => ['1',$ContactID2]
    },
    {
        Name     => "Search: Field Login / Operator EQ / Value \$UserLogin1",
        Search   => {
            'AND' => [
                {
                    Field    => 'Login',
                    Operator => 'EQ',
                    Value    => $UserLogin1
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Login / Operator NE / Value \$UserLogin1",
        Search   => {
            'AND' => [
                {
                    Field    => 'Login',
                    Operator => 'NE',
                    Value    => $UserLogin1
                }
            ]
        },
        Expected => ['1',$ContactID2,$ContactID3]
    },
    {
        Name     => "Search: Field Login / Operator IN / Value [\$UserLogin1,\$UserLogin2]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Login',
                    Operator => 'IN',
                    Value    => [$UserLogin1,$UserLogin2]
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2]
    },
    {
        Name     => "Search: Field Login / Operator !IN / Value [\$UserLogin1,\$UserLogin2]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Login',
                    Operator => '!IN',
                    Value    => [$UserLogin1,$UserLogin2]
                }
            ]
        },
        Expected => ['1',$ContactID3]
    },
    {
        Name     => "Search: Field Login / Operator STARTSWITH / Value \$UserLogin2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Login',
                    Operator => 'STARTSWITH',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field Login / Operator STARTSWITH / Value substr(\$UserLogin2,0,2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Login',
                    Operator => 'STARTSWITH',
                    Value    => substr($UserLogin2,0,2)
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => "Search: Field Login / Operator ENDSWITH / Value \$UserLogin2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Login',
                    Operator => 'ENDSWITH',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field Login / Operator ENDSWITH / Value substr(\$UserLogin2,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Login',
                    Operator => 'ENDSWITH',
                    Value    => substr($UserLogin2,-2)
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field Login / Operator CONTAINS / Value \$UserLogin3",
        Search   => {
            'AND' => [
                {
                    Field    => 'Login',
                    Operator => 'CONTAINS',
                    Value    => $UserLogin3
                }
            ]
        },
        Expected => [$ContactID3]
    },
    {
        Name     => "Search: Field Login / Operator CONTAINS / Value substr(\$UserLogin3,2,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Login',
                    Operator => 'CONTAINS',
                    Value    => substr($UserLogin3,2,-2)
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => "Search: Field Login / Operator LIKE / Value \$UserLogin3",
        Search   => {
            'AND' => [
                {
                    Field    => 'Login',
                    Operator => 'LIKE',
                    Value    => $UserLogin3
                }
            ]
        },
        Expected => [$ContactID3]
    },
    {
        Name     => "Search: Field Login / Operator LIKE / Value *substr(\$UserLogin3,2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Login',
                    Operator => 'LIKE',
                    Value    => q{*} . substr($UserLogin3,2)
                }
            ]
        },
        Expected => [$ContactID3]
    },
    {
        Name     => "Search: Field UserLogin / Operator EQ / Value \$UserLogin1",
        Search   => {
            'AND' => [
                {
                    Field    => 'UserLogin',
                    Operator => 'EQ',
                    Value    => $UserLogin1
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field UserLogin / Operator NE / Value \$UserLogin1",
        Search   => {
            'AND' => [
                {
                    Field    => 'UserLogin',
                    Operator => 'NE',
                    Value    => $UserLogin1
                }
            ]
        },
        Expected => ['1',$ContactID2,$ContactID3]
    },
    {
        Name     => "Search: Field UserLogin / Operator IN / Value [\$UserLogin1,\$UserLogin2]",
        Search   => {
            'AND' => [
                {
                    Field    => 'UserLogin',
                    Operator => 'IN',
                    Value    => [$UserLogin1,$UserLogin2]
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2]
    },
    {
        Name     => "Search: Field UserLogin / Operator !IN / Value [\$UserLogin1,\$UserLogin2]",
        Search   => {
            'AND' => [
                {
                    Field    => 'UserLogin',
                    Operator => '!IN',
                    Value    => [$UserLogin1,$UserLogin2]
                }
            ]
        },
        Expected => ['1',$ContactID3]
    },
    {
        Name     => "Search: Field UserLogin / Operator STARTSWITH / Value \$UserLogin2",
        Search   => {
            'AND' => [
                {
                    Field    => 'UserLogin',
                    Operator => 'STARTSWITH',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field UserLogin / Operator STARTSWITH / Value substr(\$UserLogin2,0,2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'UserLogin',
                    Operator => 'STARTSWITH',
                    Value    => substr($UserLogin2,0,2)
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => "Search: Field UserLogin / Operator ENDSWITH / Value \$UserLogin2",
        Search   => {
            'AND' => [
                {
                    Field    => 'UserLogin',
                    Operator => 'ENDSWITH',
                    Value    => $UserLogin2
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field UserLogin / Operator ENDSWITH / Value substr(\$UserLogin2,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'UserLogin',
                    Operator => 'ENDSWITH',
                    Value    => substr($UserLogin2,-2)
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field UserLogin / Operator CONTAINS / Value \$UserLogin3",
        Search   => {
            'AND' => [
                {
                    Field    => 'UserLogin',
                    Operator => 'CONTAINS',
                    Value    => $UserLogin3
                }
            ]
        },
        Expected => [$ContactID3]
    },
    {
        Name     => "Search: Field UserLogin / Operator CONTAINS / Value substr(\$UserLogin3,2,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'UserLogin',
                    Operator => 'CONTAINS',
                    Value    => substr($UserLogin3,2,-2)
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => "Search: Field UserLogin / Operator LIKE / Value \$UserLogin3",
        Search   => {
            'AND' => [
                {
                    Field    => 'UserLogin',
                    Operator => 'LIKE',
                    Value    => $UserLogin3
                }
            ]
        },
        Expected => [$ContactID3]
    },
    {
        Name     => "Search: Field UserLogin / Operator LIKE / Value *substr(\$UserLogin3,2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'UserLogin',
                    Operator => 'LIKE',
                    Value    => q{*} . substr($UserLogin3,2)
                }
            ]
        },
        Expected => [$ContactID3]
    },
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Contact',
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
        Name     => 'Sort: Field UserID',
        Sort     => [
            {
                Field => 'UserID'
            }
        ],
        Expected => ['1',$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => 'Sort: Field UserID / Direction ascending',
        Sort     => [
            {
                Field     => 'UserID',
                Direction => 'ascending'
            }
        ],
        Expected => ['1',$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => 'Sort: Field UserID / Direction descending',
        Sort     => [
            {
                Field     => 'UserID',
                Direction => 'descending'
            }
        ],
        Expected => [$ContactID3,$ContactID2,$ContactID1,'1']
    },
    {
        Name     => 'Sort: Field AssignedUserID',
        Sort     => [
            {
                Field => 'AssignedUserID'
            }
        ],
        Expected => ['1',$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => 'Sort: Field AssignedUserID / Direction ascending',
        Sort     => [
            {
                Field     => 'AssignedUserID',
                Direction => 'ascending'
            }
        ],
        Expected => ['1',$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => 'Sort: Field AssignedUserID / Direction descending',
        Sort     => [
            {
                Field     => 'AssignedUserID',
                Direction => 'descending'
            }
        ],
        Expected => [$ContactID3,$ContactID2,$ContactID1,'1']
    },
    {
        Name     => 'Sort: Field Login',
        Sort     => [
            {
                Field => 'Login'
            }
        ],
        Expected => $CaseSensitive ? [$ContactID1,$ContactID3,'1',$ContactID2] : ['1',$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => 'Sort: Field Login / Direction ascending',
        Sort     => [
            {
                Field     => 'Login',
                Direction => 'ascending'
            }
        ],
        Expected => $CaseSensitive ? [$ContactID1,$ContactID3,'1',$ContactID2] : ['1',$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => 'Sort: Field Login / Direction descending',
        Sort     => [
            {
                Field     => 'Login',
                Direction => 'descending'
            }
        ],
        Expected => $CaseSensitive ? [$ContactID2,'1',$ContactID3,$ContactID1] : [$ContactID3,$ContactID2,$ContactID1,'1']
    },
    {
        Name     => 'Sort: Field UserLogin',
        Sort     => [
            {
                Field => 'UserLogin'
            }
        ],
        Expected => $CaseSensitive ? [$ContactID1,$ContactID3,'1',$ContactID2] : ['1',$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => 'Sort: Field UserLogin / Direction ascending',
        Sort     => [
            {
                Field     => 'UserLogin',
                Direction => 'ascending'
            }
        ],
        Expected => $CaseSensitive ? [$ContactID1,$ContactID3,'1',$ContactID2] : ['1',$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => 'Sort: Field UserLogin / Direction descending',
        Sort     => [
            {
                Field     => 'UserLogin',
                Direction => 'descending'
            }
        ],
        Expected => $CaseSensitive ? [$ContactID2,'1',$ContactID3,$ContactID1] : [$ContactID3,$ContactID2,$ContactID1,'1']
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Contact',
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

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
