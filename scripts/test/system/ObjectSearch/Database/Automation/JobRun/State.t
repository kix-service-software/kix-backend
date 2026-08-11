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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Automation::JobRun::State';

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
        StateID     => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType      => 'NUMERIC'
        },
        State       => {
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
            Field    => 'StateID',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'StateID',
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
            Field    => 'StateID',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'StateID',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field StateID / Operator EQ',
        Search       => {
            Field    => 'StateID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ajr.state_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateID / Operator NE',
        Search       => {
            Field    => 'StateID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ajr.state_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateID / Operator IN',
        Search       => {
            Field    => 'StateID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ajr.state_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateID / Operator !IN',
        Search       => {
            Field    => 'StateID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ajr.state_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateID / Operator LT',
        Search       => {
            Field    => 'StateID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ajr.state_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateID / Operator GT',
        Search       => {
            Field    => 'StateID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ajr.state_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateID / Operator LTE',
        Search       => {
            Field    => 'StateID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ajr.state_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StateID / Operator GTE',
        Search       => {
            Field    => 'StateID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ajr.state_id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field State / Operator EQ',
        Search       => {
            Field    => 'State',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN job_run_state ajrs ON ajrs.id = ajr.state_id'
            ],
            'Where' => [
                'ajrs.name = \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field State / Operator NE',
        Search       => {
            Field    => 'State',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN job_run_state ajrs ON ajrs.id = ajr.state_id'
            ],
            'Where' => [
                'ajrs.name != \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field State / Operator IN',
        Search       => {
            Field    => 'State',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN job_run_state ajrs ON ajrs.id = ajr.state_id'
            ],
            'Where' => [
                'ajrs.name IN (\'Test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field State / Operator !IN',
        Search       => {
            Field    => 'State',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN job_run_state ajrs ON ajrs.id = ajr.state_id'
            ],
            'Where' => [
                'ajrs.name NOT IN (\'Test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field State / Operator STARTSWITH',
        Search       => {
            Field    => 'State',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN job_run_state ajrs ON ajrs.id = ajr.state_id'
            ],
            'Where' => [
                'ajrs.name LIKE \'Test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field State / Operator ENDSWITH',
        Search       => {
            Field    => 'State',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN job_run_state ajrs ON ajrs.id = ajr.state_id'
            ],
            'Where' => [
                'ajrs.name LIKE \'%Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field State / Operator CONTAINS',
        Search       => {
            Field    => 'State',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN job_run_state ajrs ON ajrs.id = ajr.state_id'
            ],
            'Where' => [
                'ajrs.name LIKE \'%Test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field State / Operator LIKE',
        Search       => {
            Field    => 'State',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN job_run_state ajrs ON ajrs.id = ajr.state_id'
            ],
            'Where' => [
                'ajrs.name LIKE \'Test\''
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
        Name      => 'Sort: Attribute "StateID"',
        Attribute => 'StateID',
        Expected  => {
            'Join'    => [],
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select'  => [
                'ajr.state_id AS SortAttr0'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "State"',
        Attribute => 'State',
        Expected  => {
            'Join'    => [
                'INNER JOIN job_run_state ajrs ON ajrs.id = ajr.state_id',
                'LEFT OUTER JOIN translation_pattern tlp0 ON tlp0.value = ajrs.name',
                'LEFT OUTER JOIN translation_language tl0 ON tl0.pattern_id = tlp0.id AND tl0.language = \'en\''
            ],
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select'  => [
                'LOWER(COALESCE(tl0.value, ajrs.name)) AS SortAttr0'
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

# clear job runs
$Kernel::OM->Get('DB')->Do( SQL => 'DELETE FROM automation_log' );
$Kernel::OM->Get('DB')->Do( SQL => 'DELETE FROM job_run' );

# load translations for given language
my @Translations = $Kernel::OM->Get('Translation')->TranslationList();
my %TranslationsDE;
for my $Translation ( @Translations ) {
    $TranslationsDE{ $Translation->{Pattern} } = $Translation->{Languages}->{'de'};
}

## prepare job run state mapping
my %JobRunStates = $Kernel::OM->Get('Automation')->JobRunStateList();
my $JobRunStateID1   = 1;
my $JobRunStateName1 = $JobRunStates{ $JobRunStateID1 }->{Name};
my $JobRunStateID2   = 2;
my $JobRunStateName2 = $JobRunStates{ $JobRunStateID2 }->{Name};
my $JobRunStateID3   = 3;
my $JobRunStateName3 = $JobRunStates{ $JobRunStateID3 }->{Name};
$Self->Is(
    $JobRunStateName1,
    'running',
    'JobRunStateID1 1 has expected name'
);
$Self->Is(
    $TranslationsDE{ $JobRunStateName1 },
    'laufend',
    'JobRunStateID1 1 has expected translation (de)'
);
$Self->Is(
    $JobRunStateName2,
    'finished',
    'JobRunStateID2 2 has expected name'
);
$Self->Is(
    $TranslationsDE{ $JobRunStateName2 },
    'abgeschlossen',
    'JobRunStateID2 2 has expected translation (de)'
);
$Self->Is(
    $JobRunStateName3,
    'warning',
    'JobRunStateID3 3 has expected name'
);
$Self->Is(
    $TranslationsDE{ $JobRunStateName3 },
    'Warnung',
    'JobRunStateID3 3 has expected translation (de)'
);

## prepare test jobs
my $JobName1 = 'UnitTest1';
my $JobID1   = $Kernel::OM->Get('Automation')->JobAdd(
    Name    => $JobName1,
    Type    => 'Synchronisation',
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
$Kernel::OM->Get('DB')->Do(
    SQL => 'UPDATE job_run SET state_id = ? WHERE id = ?',
    Bind => [ \$JobRunStateID1, \$JobRunID1 ],
);
my %JobRunData1 = $Kernel::OM->Get('Automation')->JobRunGet(
    ID => $JobRunID1,
);
$Self->Is(
    $JobRunData1{StateID},
    $JobRunStateID1,
    'First job run as expected StateID'
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
$Kernel::OM->Get('DB')->Do(
    SQL => 'UPDATE job_run SET state_id = ? WHERE id = ?',
    Bind => [ \$JobRunStateID2, \$JobRunID2 ],
);
my %JobRunData2 = $Kernel::OM->Get('Automation')->JobRunGet(
    ID => $JobRunID2,
);
$Self->Is(
    $JobRunData2{StateID},
    $JobRunStateID2,
    'Second job run as expected StateID'
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
$Kernel::OM->Get('DB')->Do(
    SQL => 'UPDATE job_run SET state_id = ? WHERE id = ?',
    Bind => [ \$JobRunStateID3, \$JobRunID3 ],
);
my %JobRunData3 = $Kernel::OM->Get('Automation')->JobRunGet(
    ID => $JobRunID3,
);
$Self->Is(
    $JobRunData3{StateID},
    $JobRunStateID3,
    'Third job run as expected StateID'
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field StateID / Operator EQ / Value $JobRunStateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateID',
                    Operator => 'EQ',
                    Value    => $JobRunStateID2
                }
            ]
        },
        Expected => [$JobRunID2]
    },
    {
        Name     => 'Search: Field StateID / Operator NE / Value $JobRunStateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateID',
                    Operator => 'NE',
                    Value    => $JobRunStateID2
                }
            ]
        },
        Expected => [$JobRunID1,$JobRunID3]
    },
    {
        Name     => 'Search: Field StateID / Operator IN / Value [$JobRunStateID1,$JobRunStateID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateID',
                    Operator => 'IN',
                    Value    => [$JobRunStateID1,$JobRunStateID3]
                }
            ]
        },
        Expected => [$JobRunID1, $JobRunID3]
    },
    {
        Name     => 'Search: Field StateID / Operator !IN / Value [$JobRunStateID1,$JobRunStateID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateID',
                    Operator => '!IN',
                    Value    => [$JobRunStateID1,$JobRunStateID3]
                }
            ]
        },
        Expected => [$JobRunID2]
    },
    {
        Name     => 'Search: Field StateID / Operator LT / Value $JobRunStateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateID',
                    Operator => 'LT',
                    Value    => $JobRunStateID2
                }
            ]
        },
        Expected => [$JobRunID1]
    },
    {
        Name     => 'Search: Field StateID / Operator GT / Value $JobRunStateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateID',
                    Operator => 'GT',
                    Value    => $JobRunStateID2
                }
            ]
        },
        Expected => [$JobRunID3]
    },
    {
        Name     => 'Search: Field StateID / Operator LTE / Value $JobRunStateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateID',
                    Operator => 'LTE',
                    Value    => $JobRunStateID2
                }
            ]
        },
        Expected => [$JobRunID1, $JobRunID2]
    },
    {
        Name     => 'Search: Field StateID / Operator GTE / Value $JobRunStateID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'StateID',
                    Operator => 'GTE',
                    Value    => $JobRunStateID2
                }
            ]
        },
        Expected => [$JobRunID2, $JobRunID3]
    },
    {
        Name     => 'Search: Field State / Operator EQ / Value $JobRunStateName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'State',
                    Operator => 'EQ',
                    Value    => $JobRunStateName2
                }
            ]
        },
        Expected => [$JobRunID2]
    },
    {
        Name     => 'Search: Field State / Operator NE / Value $JobRunStateName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'State',
                    Operator => 'NE',
                    Value    => $JobRunStateName2
                }
            ]
        },
        Expected => [$JobRunID1,$JobRunID3]
    },
    {
        Name     => 'Search: Field State / Operator IN / Value [$JobRunStateName1,$JobRunStateName3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'State',
                    Operator => 'IN',
                    Value    => [$JobRunStateName1,$JobRunStateName3]
                }
            ]
        },
        Expected => [$JobRunID1, $JobRunID3]
    },
    {
        Name     => 'Search: Field State / Operator !IN / Value [$JobRunStateName1,$JobRunStateName3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'State',
                    Operator => '!IN',
                    Value    => [$JobRunStateName1,$JobRunStateName3]
                }
            ]
        },
        Expected => [$JobRunID2]
    },
    {
        Name     => 'Search: Field State / Operator STARTSWITH / Value $JobRunStateName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'State',
                    Operator => 'STARTSWITH',
                    Value    => $JobRunStateName2
                }
            ]
        },
        Expected => [$JobRunID2]
    },
    {
        Name     => 'Search: Field State / Operator STARTSWITH / Value substr($JobRunStateName3,0,4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'State',
                    Operator => 'STARTSWITH',
                    Value    => substr($JobRunStateName3,0,4)
                }
            ]
        },
        Expected => [$JobRunID3]
    },
    {
        Name     => 'Search: Field State / Operator ENDSWITH / Value $JobRunStateName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'State',
                    Operator => 'ENDSWITH',
                    Value    => $JobRunStateName2
                }
            ]
        },
        Expected => [$JobRunID2]
    },
    {
        Name     => 'Search: Field State / Operator ENDSWITH / Value substr($JobRunStateName3,-4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'State',
                    Operator => 'ENDSWITH',
                    Value    => substr($JobRunStateName3,-4)
                }
            ]
        },
        Expected => [$JobRunID1,$JobRunID3]
    },
    {
        Name     => 'Search: Field State / Operator CONTAINS / Value $JobRunStateName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'State',
                    Operator => 'CONTAINS',
                    Value    => $JobRunStateName2
                }
            ]
        },
        Expected => [$JobRunID2]
    },
    {
        Name     => 'Search: Field State / Operator CONTAINS / Value substr($JobRunStateName3,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'State',
                    Operator => 'CONTAINS',
                    Value    => substr($JobRunStateName3,2,-2)
                }
            ]
        },
        Expected => [$JobRunID3]
    },
    {
        Name     => 'Search: Field State / Operator LIKE / Value $JobRunStateName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'State',
                    Operator => 'LIKE',
                    Value    => $JobRunStateName2
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
        Name     => 'Sort: Field StateID',
        Sort     => [
            {
                Field => 'StateID'
            }
        ],
        Expected => [$JobRunID1, $JobRunID2, $JobRunID3]
    },
    {
        Name     => 'Sort: Field StateID / Direction ascending',
        Sort     => [
            {
                Field     => 'StateID',
                Direction => 'ascending'
            }
        ],
        Expected => [$JobRunID1, $JobRunID2, $JobRunID3]
    },
    {
        Name     => 'Sort: Field StateID / Direction descending',
        Sort     => [
            {
                Field     => 'StateID',
                Direction => 'descending'
            }
        ],
        Expected => [$JobRunID3, $JobRunID2, $JobRunID1]
    },
    {
        Name     => 'Sort: Field State',
        Sort     => [
            {
                Field => 'State'
            }
        ],
        Expected => [$JobRunID2, $JobRunID1, $JobRunID3]
    },
    {
        Name     => 'Sort: Field State / Direction ascending',
        Sort     => [
            {
                Field     => 'State',
                Direction => 'ascending'
            }
        ],
        Expected => [$JobRunID2, $JobRunID1, $JobRunID3]
    },
    {
        Name     => 'Sort: Field State / Direction descending',
        Sort     => [
            {
                Field     => 'State',
                Direction => 'descending'
            }
        ],
        Expected => [$JobRunID3, $JobRunID1, $JobRunID2]
    },
    {
        Name     => 'Sort: Field State / Language de',
        Sort     => [
            {
                Field => 'State'
            }
        ],
        Language => 'de',
        Expected => [$JobRunID2, $JobRunID1, $JobRunID3]
    },
    {
        Name     => 'Sort: Field State / Direction ascending / Language de',
        Sort     => [
            {
                Field     => 'State',
                Direction => 'ascending'
            }
        ],
        Language => 'de',
        Expected => [$JobRunID2, $JobRunID1, $JobRunID3]
    },
    {
        Name     => 'Sort: Field State / Direction descending / Language de',
        Sort     => [
            {
                Field     => 'State',
                Direction => 'descending'
            }
        ],
        Language => 'de',
        Expected => [$JobRunID3, $JobRunID1, $JobRunID2]
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
