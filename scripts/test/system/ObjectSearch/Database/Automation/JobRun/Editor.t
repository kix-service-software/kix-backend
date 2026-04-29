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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Automation::JobRun::Editor';

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
        CreateByID => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType      => 'NUMERIC'
        },
        CreateBy => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
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
                'ajr.create_by = 1'
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
                'ajr.create_by <> 1'
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
                'ajr.create_by IN (1)'
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
                'ajr.create_by NOT IN (1)'
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
                'ajr.create_by < 1'
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
                'ajr.create_by <= 1'
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
                'ajr.create_by > 1'
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
                'ajr.create_by >= 1'
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
                'ajr.create_by = 1'
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
                'ajr.create_by <> 1'
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
                'ajr.create_by IN (1)'
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
                'ajr.create_by NOT IN (1)'
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
                'ajr.create_by < 1'
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
                'ajr.create_by <= 1'
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
                'ajr.create_by > 1'
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
                'ajr.create_by >= 1'
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
            'Select'  => ['ajr.create_by AS SortAttr0'],
            'OrderBy' => ['SortAttr0']
        }
    },
    {
        Name      => 'Sort: Attribute "CreateBy"',
        Attribute => 'CreateBy',
        Expected  => {
            'Join'    => [
                'INNER JOIN users ajrcru ON ajrcru.id = ajr.create_by',
                'LEFT OUTER JOIN contact ajrcruc ON ajrcruc.user_id = ajrcru.id'
            ],
            'Select'  => [
                'LOWER(ajrcruc.lastname) AS SortAttr0',
                'LOWER(ajrcruc.firstname) AS SortAttr1',
                'LOWER(ajrcru.login) AS SortAttr2'
            ],
            'OrderBy' => [
                'SortAttr0',
                'SortAttr1',
                'SortAttr2'
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
my $ContactFirstName1 = 'Alf';
my $ContactFirstName2 = 'Bert';
my $ContactFirstName3 = 'Alvin';
my $ContactLastName1  = 'test';
my $ContactLastName2  = 'Test';
my $ContactLastName3  = 'tesT';
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
my $ContactID3 = $Kernel::OM->Get('Contact')->ContactAdd(
    Firstname             => $ContactFirstName3,
    Lastname              => $ContactLastName3,
    AssignedUserID        => $UserID3,
    ValidID               => 1,
    UserID                => $UserID3
);
$Self->True(
    $ContactID3,
    'Contact for third user created'
);

my $JobID = $Kernel::OM->Get('Automation')->JobAdd(
    Name    => 'UnitTest',
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
    Silent  => 1,
);
$Self->True(
    $JobID,
    'Job created'
);
my $JobRunID1 = $Kernel::OM->Get('Automation')->JobExecute(
    ID     => $JobID,
    UserID => $UserID1
);
$Self->True(
    $JobRunID1,
    'Job run by first user executed'
);
my $JobRunID2 = $Kernel::OM->Get('Automation')->JobExecute(
    ID     => $JobID,
    UserID => $UserID2
);
$Self->True(
    $JobRunID2,
    'Job run by second user executed'
);
my $JobRunID3 = $Kernel::OM->Get('Automation')->JobExecute(
    ID     => $JobID,
    UserID => $UserID3
);
$Self->True(
    $JobRunID3,
    'Job run by third user executed'
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
        Expected => [$JobRunID2]
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
        Expected => [$JobRunID1,$JobRunID3]
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
        Expected => [$JobRunID1,$JobRunID3]
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
        Expected => [$JobRunID2]
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
        Expected => [$JobRunID1]
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
        Expected => [$JobRunID3]
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
        Expected => [$JobRunID1,$JobRunID2]
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
        Expected => [$JobRunID2,$JobRunID3]
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
        Expected => [$JobRunID2]
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
        Expected => [$JobRunID1,$JobRunID3]
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
        Expected => [$JobRunID1,$JobRunID3]
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
        Expected => [$JobRunID2]
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
        Expected => [$JobRunID1]
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
        Expected => [$JobRunID3]
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
        Expected => [$JobRunID1,$JobRunID2]
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
        Expected => [$JobRunID2,$JobRunID3]
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Automation_JobRun',
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
        Expected => [$JobRunID1,$JobRunID2,$JobRunID3]
    },
    {
        Name     => 'Sort: Field CreateByID / Direction ascending',
        Sort     => [
            {
                Field     => 'CreateByID',
                Direction => 'ascending'
            }
        ],
        Expected => [$JobRunID1,$JobRunID2,$JobRunID3]
    },
    {
        Name     => 'Sort: Field CreateByID / Direction descending',
        Sort     => [
            {
                Field     => 'CreateByID',
                Direction => 'descending'
            }
        ],
        Expected => [$JobRunID3,$JobRunID2,$JobRunID1]
    },
    {
        Name     => 'Sort: Field CreateBy',
        Sort     => [
            {
                Field => 'CreateBy'
            }
        ],
        Expected => [$JobRunID1,$JobRunID3,$JobRunID2]
    },
    {
        Name     => 'Sort: Field CreateBy / Direction ascending',
        Sort     => [
            {
                Field     => 'CreateBy',
                Direction => 'ascending'
            }
        ],
        Expected => [$JobRunID1,$JobRunID3,$JobRunID2]
    },
    {
        Name     => 'Sort: Field CreateBy / Direction descending',
        Sort     => [
            {
                Field     => 'CreateBy',
                Direction => 'descending'
            }
        ],
        Expected => [$JobRunID2,$JobRunID3,$JobRunID1]
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Automation_JobRun',
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
