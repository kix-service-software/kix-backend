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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Role::Valid';

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
        Valid => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN']
        },
        ValidID => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN'],
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
            Field    => 'RoleID',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'RoleID',
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
            Field    => 'ValidID',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'ValidID',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field ValidID / Operator EQ',
        Search       => {
            Field    => 'ValidID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'r.valid_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ValidID / Operator NE',
        Search       => {
            Field    => 'ValidID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'r.valid_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ValidID / Operator IN',
        Search       => {
            Field    => 'ValidID',
            Operator => 'IN',
            Value    => ['1']
        },
        BoolOperator => 'AND',
        Expected     => {
            'Join'  => [],
            'Where' => [
                'r.valid_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ValidID / Operator !IN',
        Search       => {
            Field    => 'ValidID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'r.valid_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Valid / Operator EQ',
        Search       => {
            Field    => 'Valid',
            Operator => 'EQ',
            Value    => 'valid'
        },
        Expected     => {
            'Join'  => [
                'INNER JOIN valid rv ON rv.id = r.valid_id'
            ],
            'Where' => [
                'rv.name = \'valid\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Valid / Operator NE',
        Search       => {
            Field    => 'Valid',
            Operator => 'NE',
            Value    => 'valid'
        },
        Expected     => {
            'Join'  => [
                'INNER JOIN valid rv ON rv.id = r.valid_id'
            ],
            'Where' => [
                'rv.name != \'valid\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Valid / Operator IN',
        Search       => {
            Field    => 'Valid',
            Operator => 'IN',
            Value    => ['valid']
        },
        BoolOperator => 'AND',
        Expected     => {
            'Join'  => [
                'INNER JOIN valid rv ON rv.id = r.valid_id'
            ],
            'Where' => [
                'rv.name IN (\'valid\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ID / Operator !IN',
        Search       => {
            Field    => 'Valid',
            Operator => '!IN',
            Value    => ['valid']
        },
        Expected     => {
            'Join'  => [
                'INNER JOIN valid rv ON rv.id = r.valid_id'
            ],
            'Where' => [
                'rv.name NOT IN (\'valid\')'
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
        Name      => 'Sort: Attribute "ValidID"',
        Attribute => 'ValidID',
        Expected  => {
            'Join' => [],
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select' => [
                'r.valid_id AS SortAttr0'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Valid"',
        Attribute => 'Valid',
        Expected  => {
            'Join' => [
                'INNER JOIN valid rv ON rv.id = r.valid_id',
                'LEFT OUTER JOIN translation_pattern tlp0 ON tlp0.value = rv.name',
                'LEFT OUTER JOIN translation_language tl0 ON tl0.pattern_id = tlp0.id AND tl0.language = \'en\''
            ],
            'Join' => [
                'INNER JOIN valid rv ON rv.id = r.valid_id',
                'LEFT OUTER JOIN translation_pattern tlp0 ON tlp0.value = rv.name',
                'LEFT OUTER JOIN translation_language tl0 ON tl0.pattern_id = tlp0.id AND tl0.language = \'en\''
            ],
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select' => [
                'LOWER(COALESCE(tl0.value, rv.name)) AS SortAttr0'
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

## prepare test valid ##
my $ValidID1 = 1;
my $ValidID2 = 2;
my $ValidID3 = 3;

## prepare test roles ##
# first role
my $RoleID1 = $Kernel::OM->Get('Role')->RoleAdd(
    Name         => $Helper->GetRandomID(),
    UsageContext => Kernel::System::Role->USAGE_CONTEXT->{AGENT},
    ValidID      => $ValidID1,
    UserID       => 1,
);
$Self->True(
    $RoleID1,
    'Created first role'
);
# second role
my $RoleID2 = $Kernel::OM->Get('Role')->RoleAdd(
    Name         => $Helper->GetRandomID(),
    UsageContext => Kernel::System::Role->USAGE_CONTEXT->{CUSTOMER},
    ValidID      => $ValidID2,
    UserID       => 1,
);
$Self->True(
    $RoleID1,
    'Created second role'
);
# third role
my $RoleID3 = $Kernel::OM->Get('Role')->RoleAdd(
    Name         => $Helper->GetRandomID(),
    UsageContext => Kernel::System::Role->USAGE_CONTEXT->{AGENT} + Kernel::System::Role->USAGE_CONTEXT->{CUSTOMER},
    ValidID      => $ValidID3,
    UserID       => 1,
);
$Self->True(
    $RoleID1,
    'Created third role'
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => "Search: Field ValidID / Operator EQ / Value \$ValidID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ValidID',
                    Operator => 'EQ',
                    Value    => $ValidID2
                }
            ]
        },
        Expected => [$RoleID2]
    },
    {
        Name     => "Search: Field ValidID / Operator NE / Value \$ValidID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'ValidID',
                    Operator => 'NE',
                    Value    => $ValidID2
                }
            ]
        },
        Expected => [$RoleID1,$RoleID3]
    },
    {
        Name     => "Search: Field ValidID / Operator IN / Value [\$ValidID1,\$ValidID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'ValidID',
                    Operator => 'IN',
                    Value    => [$ValidID1,$ValidID3]
                }
            ]
        },
        Expected => [$RoleID1, $RoleID3]
    },
    {
        Name     => "Search: Field RoleID / Operator !IN / Value [\$ValidID1,\$ValidID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'ValidID',
                    Operator => '!IN',
                    Value    => [$ValidID1,$ValidID3]
                }
            ]
        },
        Expected => [$RoleID2]
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Role',
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
        Name     => 'Sort: Field ValidID',
        Sort     => [
            {
                Field => 'ValidID'
            }
        ],
        Expected => [$RoleID1, $RoleID2, $RoleID3]
    },
    {
        Name     => 'Sort: Field ValidID / Direction ascending',
        Sort     => [
            {
                Field     => 'ValidID',
                Direction => 'ascending'
            }
        ],
        Expected => [$RoleID1, $RoleID2, $RoleID3]
    },
    {
        Name     => 'Sort: Field ValidID / Direction descending',
        Sort     => [
            {
                Field     => 'ValidID',
                Direction => 'descending'
            }
        ],
        Expected => [$RoleID3, $RoleID2, $RoleID1]
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Role',
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
