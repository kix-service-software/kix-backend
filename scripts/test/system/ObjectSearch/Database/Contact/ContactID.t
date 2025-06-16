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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Contact::ContactID';

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
    $AttributeList,
    {
        ContactID => {
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType      => 'NUMERIC'
        },
        ID => {
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
            Field    => 'ContactID',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'ContactID',
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
            Field    => 'ContactID',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'ContactID',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field ContactID / Operator EQ',
        Search       => {
            Field    => 'ContactID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'c.id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ContactID / Operator NE',
        Search       => {
            Field    => 'ContactID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'c.id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ContactID / Operator IN',
        Search       => {
            Field    => 'ContactID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'c.id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ContactID / Operator !IN',
        Search       => {
            Field    => 'ContactID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'c.id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ContactID / Operator LT',
        Search       => {
            Field    => 'ContactID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'c.id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ContactID / Operator LTE',
        Search       => {
            Field    => 'ContactID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'c.id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ContactID / Operator GT',
        Search       => {
            Field    => 'ContactID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'c.id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ContactID / Operator GTE',
        Search       => {
            Field    => 'ContactID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'c.id >= 1'
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
                'c.id = 1'
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
                'c.id <> 1'
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
                'c.id IN (1)'
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
                'c.id NOT IN (1)'
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
                'c.id < 1'
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
                'c.id <= 1'
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
                'c.id > 1'
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
                'c.id >= 1'
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
        Name      => 'Sort: Attribute "ContactID"',
        Attribute => 'ContactID',
        Expected  => {
            'Select'  => ['c.id'],
            'OrderBy' => ['c.id']
        }
    },
    {
        Name      => 'Sort: Attribute "ID"',
        Attribute => 'ID',
        Expected  => {
            'Select'  => ['c.id'],
            'OrderBy' => ['c.id']
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

## prepare test contact ##
# first contact
my $ContactID1 = $Helper->TestContactCreate();
$Self->True(
    $ContactID1,
    'Created first contact'
);
# second contact
my $ContactID2 = $Helper->TestContactCreate();
$Self->True(
    $ContactID2,
    'Created second contact'
);
# third contact
my $ContactID3 = $Helper->TestContactCreate();
$Self->True(
    $ContactID3,
    'Created third contact'
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Contact'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field ContactID / Operator EQ / Value $ContactID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ContactID',
                    Operator => 'EQ',
                    Value    => $ContactID2
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => 'Search: Field ContactID / Operator NE / Value $ContactID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ContactID',
                    Operator => 'NE',
                    Value    => $ContactID2
                }
            ]
        },
        Expected => ['1',$ContactID1,$ContactID3]
    },
    {
        Name     => 'Search: Field ContactID / Operator IN / Value [$ContactID1,$ContactID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ContactID',
                    Operator => 'IN',
                    Value    => [$ContactID1,$ContactID3]
                }
            ]
        },
        Expected => [$ContactID1,$ContactID3]
    },
    {
        Name     => 'Search: Field ContactID / Operator !IN / Value [$ContactID1,$ContactID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ContactID',
                    Operator => '!IN',
                    Value    => [$ContactID1,$ContactID3]
                }
            ]
        },
        Expected => ['1',$ContactID2]
    },
    {
        Name     => 'Search: Field ContactID / Operator LT / Value $ContactID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ContactID',
                    Operator => 'LT',
                    Value    => $ContactID2
                }
            ]
        },
        Expected => ['1',$ContactID1]
    },
    {
        Name     => 'Search: Field ContactID / Operator LTE / Value $ContactID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ContactID',
                    Operator => 'LTE',
                    Value    => $ContactID2
                }
            ]
        },
        Expected => ['1',$ContactID1,$ContactID2]
    },
    {
        Name     => 'Search: Field ContactID / Operator GT / Value $ContactID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ContactID',
                    Operator => 'GT',
                    Value    => $ContactID2
                }
            ]
        },
        Expected => [$ContactID3]
    },
    {
        Name     => 'Search: Field ContactID / Operator GTE / Value $ContactID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ContactID',
                    Operator => 'GTE',
                    Value    => $ContactID2
                }
            ]
        },
        Expected => [$ContactID2,$ContactID3]
    },
    {
        Name     => 'Search: Field ID / Operator EQ / Value $ContactID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'EQ',
                    Value    => $ContactID2
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => 'Search: Field ID / Operator NE / Value $ContactID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'NE',
                    Value    => $ContactID2
                }
            ]
        },
        Expected => ['1',$ContactID1,$ContactID3]
    },
    {
        Name     => 'Search: Field ID / Operator IN / Value [$ContactID1,$ContactID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'IN',
                    Value    => [$ContactID1,$ContactID3]
                }
            ]
        },
        Expected => [$ContactID1,$ContactID3]
    },
    {
        Name     => 'Search: Field ID / Operator !IN / Value [$ContactID1,$ContactID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => '!IN',
                    Value    => [$ContactID1,$ContactID3]
                }
            ]
        },
        Expected => ['1',$ContactID2]
    },
    {
        Name     => 'Search: Field ID / Operator LT / Value $ContactID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'LT',
                    Value    => $ContactID2
                }
            ]
        },
        Expected => ['1',$ContactID1]
    },
    {
        Name     => 'Search: Field ID / Operator LTE / Value $ContactID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'LTE',
                    Value    => $ContactID2
                }
            ]
        },
        Expected => ['1',$ContactID1,$ContactID2]
    },
    {
        Name     => 'Search: Field ID / Operator GT / Value $ContactID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'GT',
                    Value    => $ContactID2
                }
            ]
        },
        Expected => [$ContactID3]
    },
    {
        Name     => 'Search: Field ID / Operator GTE / Value $ContactID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'GTE',
                    Value    => $ContactID2
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
        Name     => 'Sort: Field ContactID',
        Sort     => [
            {
                Field => 'ContactID'
            }
        ],
        Expected => ['1',$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => 'Sort: Field ContactID / Direction ascending',
        Sort     => [
            {
                Field     => 'ContactID',
                Direction => 'ascending'
            }
        ],
        Expected => ['1',$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => 'Sort: Field ContactID / Direction descending',
        Sort     => [
            {
                Field     => 'ContactID',
                Direction => 'descending'
            }
        ],
        Expected => [$ContactID3,$ContactID2,$ContactID1,'1']
    },
    {
        Name     => 'Sort: Field ID',
        Sort     => [
            {
                Field => 'ID'
            }
        ],
        Expected => ['1',$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => 'Sort: Field ID / Direction ascending',
        Sort     => [
            {
                Field     => 'ID',
                Direction => 'ascending'
            }
        ],
        Expected => ['1',$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => 'Sort: Field ID / Direction descending',
        Sort     => [
            {
                Field     => 'ID',
                Direction => 'descending'
            }
        ],
        Expected => [$ContactID3,$ContactID2,$ContactID1,'1']
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Contact',
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
