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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Automation::JobRun::JobRunID';

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
        JobRunID => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType      => 'NUMERIC'
        },
        ID => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
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
            Field    => 'JobRunID',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'JobRunID',
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
            Field    => 'JobRunID',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'JobRunID',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field JobRunID / Operator EQ',
        Search       => {
            Field    => 'JobRunID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ajr.id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field JobRunID / Operator NE',
        Search       => {
            Field    => 'JobRunID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ajr.id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field JobRunID / Operator IN',
        Search       => {
            Field    => 'JobRunID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'ajr.id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field JobRunID / Operator !IN',
        Search       => {
            Field    => 'JobRunID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'ajr.id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field JobRunID / Operator LT',
        Search       => {
            Field    => 'JobRunID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ajr.id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field JobRunID / Operator LTE',
        Search       => {
            Field    => 'JobRunID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ajr.id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field JobRunID / Operator GT',
        Search       => {
            Field    => 'JobRunID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ajr.id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field JobRunID / Operator GTE',
        Search       => {
            Field    => 'JobRunID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ajr.id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ID / Operator EQ',
        Search       => {
            Field    => 'ID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ajr.id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ID / Operator NE',
        Search       => {
            Field    => 'ID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ajr.id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ID / Operator IN',
        Search       => {
            Field    => 'ID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'ajr.id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ID / Operator !IN',
        Search       => {
            Field    => 'ID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'ajr.id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ID / Operator LT',
        Search       => {
            Field    => 'ID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ajr.id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ID / Operator LTE',
        Search       => {
            Field    => 'ID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ajr.id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ID / Operator GT',
        Search       => {
            Field    => 'ID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ajr.id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ID / Operator GTE',
        Search       => {
            Field    => 'ID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ajr.id >= 1'
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
        Name      => 'Sort: Attribute "JobRunID"',
        Attribute => 'JobRunID',
        Expected  => {
            'Select'  => ['ajr.id AS SortAttr0'],
            'OrderBy' => ['SortAttr0']
        }
    },
    {
        Name      => 'Sort: Attribute "ID"',
        Attribute => 'ID',
        Expected  => {
            'Select'  => ['ajr.id AS SortAttr0'],
            'OrderBy' => ['SortAttr0']
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
        Name     => 'Search: Field JobRunID / Operator EQ / Value $JobRunID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'JobRunID',
                    Operator => 'EQ',
                    Value    => $JobRunID2
                }
            ]
        },
        Expected => [$JobRunID2]
    },
    {
        Name     => 'Search: Field JobRunID / Operator NE / Value $JobRunID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'JobRunID',
                    Operator => 'NE',
                    Value    => $JobRunID2
                }
            ]
        },
        Expected => [$JobRunID1,$JobRunID3]
    },
    {
        Name     => 'Search: Field JobRunID / Operator IN / Value [$JobRunID1,$JobRunID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'JobRunID',
                    Operator => 'IN',
                    Value    => [$JobRunID1,$JobRunID3]
                }
            ]
        },
        Expected => [$JobRunID1,$JobRunID3]
    },
    {
        Name     => 'Search: Field JobRunID / Operator !IN / Value [$JobRunID1,$JobRunID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'JobRunID',
                    Operator => '!IN',
                    Value    => [$JobRunID1,$JobRunID3]
                }
            ]
        },
        Expected => [$JobRunID2]
    },
    {
        Name     => 'Search: Field JobRunID / Operator LT / Value $JobRunID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'JobRunID',
                    Operator => 'LT',
                    Value    => $JobRunID2
                }
            ]
        },
        Expected => [$JobRunID1]
    },
    {
        Name     => 'Search: Field JobRunID / Operator LTE / Value $JobRunID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'JobRunID',
                    Operator => 'LTE',
                    Value    => $JobRunID2
                }
            ]
        },
        Expected => [$JobRunID1,$JobRunID2]
    },
    {
        Name     => 'Search: Field JobRunID / Operator GT / Value $JobRunID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'JobRunID',
                    Operator => 'GT',
                    Value    => $JobRunID2
                }
            ]
        },
        Expected => [$JobRunID3]
    },
    {
        Name     => 'Search: Field JobRunID / Operator GTE / Value $JobRunID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'JobRunID',
                    Operator => 'GTE',
                    Value    => $JobRunID2
                }
            ]
        },
        Expected => [$JobRunID2,$JobRunID3]
    },
    {
        Name     => 'Search: Field ID / Operator EQ / Value $JobRunID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'EQ',
                    Value    => $JobRunID2
                }
            ]
        },
        Expected => [$JobRunID2]
    },
    {
        Name     => 'Search: Field ID / Operator NE / Value $JobRunID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'NE',
                    Value    => $JobRunID2
                }
            ]
        },
        Expected => [$JobRunID1,$JobRunID3]
    },
    {
        Name     => 'Search: Field ID / Operator IN / Value [$JobRunID1,$JobRunID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'IN',
                    Value    => [$JobRunID1,$JobRunID3]
                }
            ]
        },
        Expected => [$JobRunID1,$JobRunID3]
    },
    {
        Name     => 'Search: Field ID / Operator !IN / Value [$JobRunID1,$JobRunID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => '!IN',
                    Value    => [$JobRunID1,$JobRunID3]
                }
            ]
        },
        Expected => [$JobRunID2]
    },
    {
        Name     => 'Search: Field ID / Operator LT / Value $JobRunID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'LT',
                    Value    => $JobRunID2
                }
            ]
        },
        Expected => [$JobRunID1]
    },
    {
        Name     => 'Search: Field ID / Operator LTE / Value $JobRunID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'LTE',
                    Value    => $JobRunID2
                }
            ]
        },
        Expected => [$JobRunID1,$JobRunID2]
    },
    {
        Name     => 'Search: Field ID / Operator GT / Value $JobRunID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'GT',
                    Value    => $JobRunID2
                }
            ]
        },
        Expected => [$JobRunID3]
    },
    {
        Name     => 'Search: Field ID / Operator GTE / Value $JobRunID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'GTE',
                    Value    => $JobRunID2
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
        Name     => 'Sort: Field JobRunID',
        Sort     => [
            {
                Field => 'JobRunID'
            }
        ],
        Expected => [$JobRunID1,$JobRunID2,$JobRunID3]
    },
    {
        Name     => 'Sort: Field JobRunID / Direction ascending',
        Sort     => [
            {
                Field     => 'JobRunID',
                Direction => 'ascending'
            }
        ],
        Expected => [$JobRunID1,$JobRunID2,$JobRunID3]
    },
    {
        Name     => 'Sort: Field JobRunID / Direction descending',
        Sort     => [
            {
                Field     => 'JobRunID',
                Direction => 'descending'
            }
        ],
        Expected => [$JobRunID3,$JobRunID2,$JobRunID1]
    },
    {
        Name     => 'Sort: Field ID',
        Sort     => [
            {
                Field => 'ID'
            }
        ],
        Expected => [$JobRunID1,$JobRunID2,$JobRunID3]
    },
    {
        Name     => 'Sort: Field ID / Direction ascending',
        Sort     => [
            {
                Field     => 'ID',
                Direction => 'ascending'
            }
        ],
        Expected => [$JobRunID1,$JobRunID2,$JobRunID3]
    },
    {
        Name     => 'Sort: Field ID / Direction descending',
        Sort     => [
            {
                Field     => 'ID',
                Direction => 'descending'
            }
        ],
        Expected => [$JobRunID3,$JobRunID2,$JobRunID1]
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Automation_JobRun',
        Result     => 'ARRAY',
        Sort       => $Test->{Sort},
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
