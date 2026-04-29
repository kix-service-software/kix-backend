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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Automation::JobRun::Job';

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
        'Attribute object can "' . $Method . '"'
    );
}

# check GetSupportedAttributes
my $AttributeList = $AttributeObject->GetSupportedAttributes();
$Self->IsDeeply(
    $AttributeList,
    {
        JobID => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType      => 'NUMERIC'
        },
        Job   => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
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
            Field    => 'JobID',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'JobID',
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
            Field    => 'JobID',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'JobID',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field JobID / Operator EQ',
        Search       => {
            Field    => 'JobID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ajr.job_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field JobID / Operator NE',
        Search       => {
            Field    => 'JobID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ajr.job_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field JobID / Operator IN',
        Search       => {
            Field    => 'JobID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ajr.job_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field JobID / Operator !IN',
        Search       => {
            Field    => 'JobID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ajr.job_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field JobID / Operator LT',
        Search       => {
            Field    => 'JobID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ajr.job_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field JobID / Operator GT',
        Search       => {
            Field    => 'JobID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ajr.job_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field JobID / Operator LTE',
        Search       => {
            Field    => 'JobID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ajr.job_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field JobID / Operator GTE',
        Search       => {
            Field    => 'JobID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ajr.job_id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Job / Operator EQ',
        Search       => {
            Field    => 'Job',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN job ajrj ON ajrj.id = ajr.job_id'
            ],
            'Where' => [
                'ajrj.name = \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Job / Operator NE',
        Search       => {
            Field    => 'Job',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN job ajrj ON ajrj.id = ajr.job_id'
            ],
            'Where' => [
                'ajrj.name != \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Job / Operator IN',
        Search       => {
            Field    => 'Job',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN job ajrj ON ajrj.id = ajr.job_id'
            ],
            'Where' => [
                'ajrj.name IN (\'Test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Job / Operator !IN',
        Search       => {
            Field    => 'Job',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN job ajrj ON ajrj.id = ajr.job_id'
            ],
            'Where' => [
                'ajrj.name NOT IN (\'Test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Job / Operator STARTSWITH',
        Search       => {
            Field    => 'Job',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN job ajrj ON ajrj.id = ajr.job_id'
            ],
            'Where' => [
                'ajrj.name LIKE \'Test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Job / Operator ENDSWITH',
        Search       => {
            Field    => 'Job',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN job ajrj ON ajrj.id = ajr.job_id'
            ],
            'Where' => [
                'ajrj.name LIKE \'%Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Job / Operator CONTAINS',
        Search       => {
            Field    => 'Job',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN job ajrj ON ajrj.id = ajr.job_id'
            ],
            'Where' => [
                'ajrj.name LIKE \'%Test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Job / Operator LIKE',
        Search       => {
            Field    => 'Job',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN job ajrj ON ajrj.id = ajr.job_id'
            ],
            'Where' => [
                'ajrj.name LIKE \'Test\''
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
        Name      => 'Sort: Attribute "JobID"',
        Attribute => 'JobID',
        Expected  => {
            'Join'    => [],
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select'  => [
                'ajr.job_id AS SortAttr0'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Job"',
        Attribute => 'Job',
        Expected  => {
            'Join'    => [
                'INNER JOIN job ajrj ON ajrj.id = ajr.job_id',
            ],
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select'  => [
                'LOWER(ajrj.name) AS SortAttr0'
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

## prepare test jobs
my $JobName1 = 'UnitTest1';
my $JobID1   = $Kernel::OM->Get('Automation')->JobAdd(
    Name    => $JobName1,
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
    Silent  => 1,
);
$Self->True(
    $JobID1,
    'Created first job'
);
my $JobRunID1 = $Kernel::OM->Get('Automation')->JobExecute(
    ID     => $JobID1,
    UserID => 1
);
$Self->True(
    $JobRunID1,
    'Job run for first job executed'
);
my $JobName2 = 'UnitTest2';
my $JobID2   = $Kernel::OM->Get('Automation')->JobAdd(
    Name    => $JobName2,
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
    Silent  => 1,
);
$Self->True(
    $JobID2,
    'Created second job'
);
my $JobRunID2 = $Kernel::OM->Get('Automation')->JobExecute(
    ID     => $JobID2,
    UserID => 1
);
$Self->True(
    $JobRunID2,
    'Job run for second job executed'
);
my $JobName3 = 'UnitTest3';
my $JobID3   = $Kernel::OM->Get('Automation')->JobAdd(
    Name    => $JobName3,
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
    Silent  => 1,
);
$Self->True(
    $JobID3,
    'Created third job'
);
my $JobRunID3 = $Kernel::OM->Get('Automation')->JobExecute(
    ID     => $JobID3,
    UserID => 1
);
$Self->True(
    $JobRunID3,
    'Job run for third job executed'
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field JobID / Operator EQ / Value $JobID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'JobID',
                    Operator => 'EQ',
                    Value    => $JobID2
                }
            ]
        },
        Expected => [$JobRunID2]
    },
    {
        Name     => 'Search: Field JobID / Operator NE / Value $JobID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'JobID',
                    Operator => 'NE',
                    Value    => $JobID2
                }
            ]
        },
        Expected => [$JobRunID1,$JobRunID3]
    },
    {
        Name     => 'Search: Field JobID / Operator IN / Value [$JobID1,$JobID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'JobID',
                    Operator => 'IN',
                    Value    => [$JobID1,$JobID3]
                }
            ]
        },
        Expected => [$JobRunID1, $JobRunID3]
    },
    {
        Name     => 'Search: Field JobID / Operator !IN / Value [$JobID1,$JobID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'JobID',
                    Operator => '!IN',
                    Value    => [$JobID1,$JobID3]
                }
            ]
        },
        Expected => [$JobRunID2]
    },
    {
        Name     => 'Search: Field JobID / Operator LT / Value $JobID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'JobID',
                    Operator => 'LT',
                    Value    => $JobID2
                }
            ]
        },
        Expected => [$JobRunID1]
    },
    {
        Name     => 'Search: Field JobID / Operator GT / Value $JobID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'JobID',
                    Operator => 'GT',
                    Value    => $JobID2
                }
            ]
        },
        Expected => [$JobRunID3]
    },
    {
        Name     => 'Search: Field JobID / Operator LTE / Value $JobID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'JobID',
                    Operator => 'LTE',
                    Value    => $JobID2
                }
            ]
        },
        Expected => [$JobRunID1, $JobRunID2]
    },
    {
        Name     => 'Search: Field JobID / Operator GTE / Value $JobID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'JobID',
                    Operator => 'GTE',
                    Value    => $JobID2
                }
            ]
        },
        Expected => [$JobRunID2, $JobRunID3]
    },
    {
        Name     => 'Search: Field Job / Operator EQ / Value $JobName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Job',
                    Operator => 'EQ',
                    Value    => $JobName2
                }
            ]
        },
        Expected => [$JobRunID2]
    },
    {
        Name     => 'Search: Field Job / Operator NE / Value $JobName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Job',
                    Operator => 'NE',
                    Value    => $JobName2
                }
            ]
        },
        Expected => [$JobRunID1,$JobRunID3]
    },
    {
        Name     => 'Search: Field Job / Operator IN / Value [$JobName1,$JobName3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Job',
                    Operator => 'IN',
                    Value    => [$JobName1,$JobName3]
                }
            ]
        },
        Expected => [$JobRunID1, $JobRunID3]
    },
    {
        Name     => 'Search: Field Job / Operator !IN / Value [$JobName1,$JobName3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Job',
                    Operator => '!IN',
                    Value    => [$JobName1,$JobName3]
                }
            ]
        },
        Expected => [$JobRunID2]
    },
    {
        Name     => 'Search: Field Job / Operator STARTSWITH / Value $JobName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Job',
                    Operator => 'STARTSWITH',
                    Value    => $JobName2
                }
            ]
        },
        Expected => [$JobRunID2]
    },
    {
        Name     => 'Search: Field Job / Operator STARTSWITH / Value substr($JobName3,0,4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Job',
                    Operator => 'STARTSWITH',
                    Value    => substr($JobName3,0,4)
                }
            ]
        },
        Expected => [$JobRunID1,$JobRunID2,$JobRunID3]
    },
    {
        Name     => 'Search: Field Job / Operator ENDSWITH / Value $JobName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Job',
                    Operator => 'ENDSWITH',
                    Value    => $JobName2
                }
            ]
        },
        Expected => [$JobRunID2]
    },
    {
        Name     => 'Search: Field Job / Operator ENDSWITH / Value substr($JobName3,-4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Job',
                    Operator => 'ENDSWITH',
                    Value    => substr($JobName3,-4)
                }
            ]
        },
        Expected => [$JobRunID3]
    },
    {
        Name     => 'Search: Field Job / Operator CONTAINS / Value $JobName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Job',
                    Operator => 'CONTAINS',
                    Value    => $JobName2
                }
            ]
        },
        Expected => [$JobRunID2]
    },
    {
        Name     => 'Search: Field Job / Operator CONTAINS / Value substr($JobName3,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Job',
                    Operator => 'CONTAINS',
                    Value    => substr($JobName3,2,-2)
                }
            ]
        },
        Expected => [$JobRunID1,$JobRunID2,$JobRunID3]
    },
    {
        Name     => 'Search: Field Job / Operator LIKE / Value $JobName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Job',
                    Operator => 'LIKE',
                    Value    => $JobName2
                }
            ]
        },
        Expected => [$JobRunID2]
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
        Name     => 'Sort: Field JobID',
        Sort     => [
            {
                Field => 'JobID'
            }
        ],
        Expected => [$JobRunID1, $JobRunID2, $JobRunID3]
    },
    {
        Name     => 'Sort: Field JobID / Direction ascending',
        Sort     => [
            {
                Field     => 'JobID',
                Direction => 'ascending'
            }
        ],
        Expected => [$JobRunID1, $JobRunID2, $JobRunID3]
    },
    {
        Name     => 'Sort: Field JobID / Direction descending',
        Sort     => [
            {
                Field     => 'JobID',
                Direction => 'descending'
            }
        ],
        Expected => [$JobRunID3, $JobRunID2, $JobRunID1]
    },
    {
        Name     => 'Sort: Field Job',
        Sort     => [
            {
                Field => 'Job'
            }
        ],
        Expected => [$JobRunID1, $JobRunID2, $JobRunID3]
    },
    {
        Name     => 'Sort: Field Job / Direction ascending',
        Sort     => [
            {
                Field     => 'Job',
                Direction => 'ascending'
            }
        ],
        Expected => [$JobRunID1, $JobRunID2, $JobRunID3]
    },
    {
        Name     => 'Sort: Field Job / Direction descending',
        Sort     => [
            {
                Field     => 'Job',
                Direction => 'descending'
            }
        ],
        Expected => [$JobRunID3, $JobRunID2, $JobRunID1]
    },
    {
        Name     => 'Sort: Field Job / Language de',
        Sort     => [
            {
                Field => 'Job'
            }
        ],
        Language => 'de',
        Expected => [$JobRunID1, $JobRunID2, $JobRunID3]
    },
    {
        Name     => 'Sort: Field Job / Direction ascending / Language de',
        Sort     => [
            {
                Field     => 'Job',
                Direction => 'ascending'
            }
        ],
        Language => 'de',
        Expected => [$JobRunID1, $JobRunID2, $JobRunID3]
    },
    {
        Name     => 'Sort: Field Job / Direction descending / Language de',
        Sort     => [
            {
                Field     => 'Job',
                Direction => 'descending'
            }
        ],
        Language => 'de',
        Expected => [$JobRunID3, $JobRunID2, $JobRunID1]
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
