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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Contact::UsageContext';

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
for my $Method ( qw(GetSupportedAttributes AttributePrepare Select Search Sort) ) {
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
        IsAgent => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE'],
            ValueType      => 'NUMERIC'
        },
        IsCustomer => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE'],
            ValueType      => 'NUMERIC'
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
            Field    => 'Title',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'Title',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field IsAgent / Operator EQ',
        Search       => {
            Field    => 'IsAgent',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN users u0 ON c.user_id = u0.id'
            ],
            'Where' => [
                'u0.is_agent = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field IsAgent / Operator EQ / Value 0',
        Search       => {
            Field    => 'IsAgent',
            Operator => 'EQ',
            Value    => '0'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN users u0 ON c.user_id = u0.id'
            ],
            'Where' => [
                '(u0.is_agent = 0 OR u0.is_agent IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field IsAgent / Operator NE',
        Search       => {
            Field    => 'IsAgent',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN users u0 ON c.user_id = u0.id'
            ],
            'Where' => [
                '(u0.is_agent <> 1 OR u0.is_agent IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field IsAgent / Operator NE / Value 0',
        Search       => {
            Field    => 'IsAgent',
            Operator => 'NE',
            Value    => '0'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN users u0 ON c.user_id = u0.id'
            ],
            'Where' => [
                'u0.is_agent <> 0'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field IsCustomer / Operator EQ',
        Search       => {
            Field    => 'IsCustomer',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN users u0 ON c.user_id = u0.id'
            ],
            'Where' => [
                'u0.is_customer = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field IsCustomer / Operator EQ / Value 0',
        Search       => {
            Field    => 'IsCustomer',
            Operator => 'EQ',
            Value    => '0'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN users u0 ON c.user_id = u0.id'
            ],
            'Where' => [
                '(u0.is_customer = 0 OR u0.is_customer IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field IsCustomer / Operator NE',
        Search       => {
            Field    => 'IsCustomer',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN users u0 ON c.user_id = u0.id'
            ],
            'Where' => [
                '(u0.is_customer <> 1 OR u0.is_customer IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field IsCustomer / Operator NE / Value 0',
        Search       => {
            Field    => 'IsCustomer',
            Operator => 'NE',
            Value    => '0'
        },
        Expected     => {
            'Join' => [
                'LEFT JOIN users u0 ON c.user_id = u0.id'
            ],
            'Where' => [
                'u0.is_customer <> 0'
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
        Name      => 'Sort: Attribute "IsAgent"',
        Attribute => 'IsAgent',
        Expected  => {
            'Join' => [
                'LEFT JOIN users u0 ON c.user_id = u0.id'
            ],
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select' => [
                'COALESCE(u0.is_agent,0) AS SortAttr0'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "IsCustomer"',
        Attribute => 'IsCustomer',
        Expected  => {
            'Join' => [
                'LEFT JOIN users u0 ON c.user_id = u0.id'
            ],
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select' => [
                'COALESCE(u0.is_customer,0) AS SortAttr0'
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
    IsCustomer    => 1
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
    IsCustomer    => 1,
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
        Name     => "Search: Field IsAgent / Operator EQ / Value 1",
        Search   => {
            'AND' => [
                {
                    Field    => 'IsAgent',
                    Operator => 'EQ',
                    Value    => '1'
                }
            ]
        },
        Expected => ['1',$ContactID1,$ContactID3]
    },
    {
        Name     => "Search: Field IsAgent / Operator EQ / Value 0",
        Search   => {
            'AND' => [
                {
                    Field    => 'IsAgent',
                    Operator => 'EQ',
                    Value    => '0'
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field IsAgent / Operator NE / Value 1",
        Search   => {
            'AND' => [
                {
                    Field    => 'IsAgent',
                    Operator => 'NE',
                    Value    => '1'
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => "Search: Field IsAgent / Operator NE / Value 0",
        Search   => {
            'AND' => [
                {
                    Field    => 'IsAgent',
                    Operator => 'NE',
                    Value    => '0'
                }
            ]
        },
        Expected => ['1',$ContactID1,$ContactID3]
    },
    {
        Name     => "Search: Field IsCustomer / Operator EQ / Value 1",
        Search   => {
            'AND' => [
                {
                    Field    => 'IsCustomer',
                    Operator => 'EQ',
                    Value    => '1'
                }
            ]
        },
        Expected => [$ContactID2,$ContactID3]
    },
    {
        Name     => "Search: Field IsCustomer / Operator EQ / Value 0",
        Search   => {
            'AND' => [
                {
                    Field    => 'IsCustomer',
                    Operator => 'EQ',
                    Value    => '0'
                }
            ]
        },
        Expected => ['1',$ContactID1]
    },
    {
        Name     => "Search: Field IsCustomer / Operator NE / Value 1",
        Search   => {
            'AND' => [
                {
                    Field    => 'IsCustomer',
                    Operator => 'NE',
                    Value    => '1'
                }
            ]
        },
        Expected => ['1',$ContactID1]
    },
    {
        Name     => "Search: Field IsCustomer / Operator NE / Value 0",
        Search   => {
            'AND' => [
                {
                    Field    => 'IsCustomer',
                    Operator => 'NE',
                    Value    => '0'
                }
            ]
        },
        Expected => [$ContactID2,$ContactID3]
    }
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
        Name     => 'Sort: Field IsAgent',
        Sort     => [
            {
                Field => 'IsAgent'
            }
        ],
        Expected => [$ContactID2,'1',$ContactID1,$ContactID3]
    },
    {
        Name     => 'Sort: Field IsAgent / Direction ascending',
        Sort     => [
            {
                Field     => 'IsAgent',
                Direction => 'ascending'
            }
        ],
        Expected => [$ContactID2,'1',$ContactID1,$ContactID3]
    },
    {
        Name     => 'Sort: Field IsAgent / Direction descending',
        Sort     => [
            {
                Field     => 'IsAgent',
                Direction => 'descending'
            }
        ],
        Expected => ['1',$ContactID1,$ContactID3,$ContactID2]
    },
    {
        Name     => 'Sort: Field IsCustomer',
        Sort     => [
            {
                Field => 'IsCustomer'
            }
        ],
        Expected => ['1',$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => 'Sort: Field IsCustomer / Direction ascending',
        Sort     => [
            {
                Field     => 'IsCustomer',
                Direction => 'ascending'
            }
        ],
        Expected => ['1',$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => 'Sort: Field IsCustomer / Direction descending',
        Sort     => [
            {
                Field     => 'IsCustomer',
                Direction => 'descending'
            }
        ],
        Expected => [$ContactID2,$ContactID3,'1',$ContactID1]
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
