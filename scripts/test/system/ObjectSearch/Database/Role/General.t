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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Role::General';

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
        Name => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        UsageContext => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType      => 'NUMERIC'
        },
        Comment => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
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
            Field    => 'Name',
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
            Value    => 'test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Field invalid',
        Search       => {
            Field    => 'Test',
            Operator => 'LIKE',
            Value    => 'test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator undef',
        Search       => {
            Field    => 'Name',
            Operator => undef,
            Value    => 'test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'Name',
            Operator => 'Test',
            Value    => 'test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field Name / Operator EQ',
        Search       => {
            Field    => 'Name',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(r.name) = \'test\'' : 'r.name = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator NE',
        Search       => {
            Field    => 'Name',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(r.name) != \'test\'' : 'r.name != \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator IN',
        Search       => {
            Field    => 'Name',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(r.name) IN (\'test\')' : 'r.name IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator !IN',
        Search       => {
            Field    => 'Name',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(r.name) NOT IN (\'test\')' : 'r.name NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator STARTSWITH',
        Search       => {
            Field    => 'Name',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(r.name) LIKE \'test%\'' : 'r.name LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator ENDSWITH',
        Search       => {
            Field    => 'Name',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(r.name) LIKE \'%test\'' : 'r.name LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator CONTAINS',
        Search       => {
            Field    => 'Name',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(r.name) LIKE \'%test%\'' : 'r.name LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Name / Operator LIKE',
        Search       => {
            Field    => 'Name',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(r.name) LIKE \'test\'' : 'r.name LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field UsageContext / Operator EQ',
        Search       => {
            Field    => 'UsageContext',
            Operator => 'EQ',
            Value    => 1
        },
        Expected     => {
            'Where' => [
                'r.usage_context = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field UsageContext / Operator NE',
        Search       => {
            Field    => 'UsageContext',
            Operator => 'NE',
            Value    => 1
        },
        Expected     => {
            'Where' => [
                'r.usage_context <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field UsageContext / Operator IN',
        Search       => {
            Field    => 'UsageContext',
            Operator => 'IN',
            Value    => [1]
        },
        BoolOperator => 'AND',
        Expected     => {
            'Where' => [
                'r.usage_context IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field UsageContext / Operator !IN',
        Search       => {
            Field    => 'UsageContext',
            Operator => '!IN',
            Value    => [1]
        },
        Expected     => {
            'Where' => [
                'r.usage_context NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Comment / Operator EQ',
        Search       => {
            Field    => 'Comment',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(r.comments) = \'test\'' : 'r.comments = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Comment / Operator NE',
        Search       => {
            Field    => 'Comment',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(r.comments) != \'test\'' : 'r.comments != \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Comment / Operator IN',
        Search       => {
            Field    => 'Comment',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(r.comments) IN (\'test\')' : 'r.comments IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Comment / Operator !IN',
        Search       => {
            Field    => 'Comment',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(r.comments) NOT IN (\'test\')' : 'r.comments NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Comment / Operator STARTSWITH',
        Search       => {
            Field    => 'Comment',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(r.comments) LIKE \'test%\'' : 'r.comments LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Comment / Operator ENDSWITH',
        Search       => {
            Field    => 'Comment',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(r.comments) LIKE \'%test\'' : 'r.comments LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Comment / Operator CONTAINS',
        Search       => {
            Field    => 'Comment',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(r.comments) LIKE \'%test%\'' : 'r.comments LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Comment / Operator LIKE',
        Search       => {
            Field    => 'Comment',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(r.comments) LIKE \'test\'' : 'r.comments LIKE \'test\''
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
        Name      => 'Sort: Attribute "Name"',
        Attribute => 'Name',
        Expected  => {
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select' => [
                'r.name AS SortAttr0'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "UsageContext"',
        Attribute => 'UsageContext',
        Expected  => {
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select' => [
                'r.usage_context AS SortAttr0'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Comment"',
        Attribute => 'Comment',
        Expected  => {
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select' => [
                'r.comments AS SortAttr0'
            ]
        }
    },
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

my %ExistingRoleIDs = $Kernel::OM->Get('Role')->RoleList();
foreach my $RoleID ( sort keys %ExistingRoleIDs ) {
    my $Success = $Kernel::OM->Get('Role')->RoleDelete(
        ID     => $RoleID,
        UserID => 1
    );
}

## prepare faq params ##
my %RoleParam;
for my $Key (
    qw(
        Name Comment
    )
) {
    my $Count  = 658_849;
    for ( 0..4 ) {
        push(
            @{$RoleParam{$Key}}, $Key . q{-} . $Count++
        );
    }
}

## prepare test roles ##
# first role
my $RoleID1 = $Kernel::OM->Get('Role')->RoleAdd(
    Name         => $RoleParam{Name}[0],
    UsageContext => Kernel::System::Role->USAGE_CONTEXT->{AGENT},
    Comment      => $RoleParam{Comment}[0],
    ValidID      => 1,
    UserID       => 1,
);
$Self->True(
    $RoleID1,
    'Created first role'
);
# second role
my $RoleID2 = $Kernel::OM->Get('Role')->RoleAdd(
    Name         => $RoleParam{Name}[1],
    UsageContext => Kernel::System::Role->USAGE_CONTEXT->{CUSTOMER},
    Comment      => $RoleParam{Comment}[1],
    ValidID      => 1,
    UserID       => 1,
);
$Self->True(
    $RoleID1,
    'Created second role'
);
# third role
my $RoleID3 = $Kernel::OM->Get('Role')->RoleAdd(
    Name         => $RoleParam{Name}[2],
    UsageContext => Kernel::System::Role->USAGE_CONTEXT->{CUSTOMER} + Kernel::System::Role->USAGE_CONTEXT->{AGENT},
    Comment      => $RoleParam{Comment}[2],
    ValidID      => 1,
    UserID       => 1,
);
$Self->True(
    $RoleID1,
    'Created third role'
);

# fourth role
my $RoleID4 = $Kernel::OM->Get('Role')->RoleAdd(
    Name         => $RoleParam{Name}[3],
    UsageContext => Kernel::System::Role->USAGE_CONTEXT->{AGENT},
    Comment      => $RoleParam{Comment}[3],
    ValidID      => 1,
    UserID       => 1,
);
$Self->True(
    $RoleID4,
    'Created fourth role'
);

my %Results = $ObjectSearch->Search(
    ObjectType => 'Role',
    Result     => 'HASH',
    UserType   => 'Agent',
    UserID     => 1,
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => "Search: Field Name / Operator EQ / Value \$RoleParam{Name}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'EQ',
                    Value    => $RoleParam{Name}[0]
                }
            ]
        },
        Expected => [$RoleID1]
    },
    {
        Name     => "Search: Field Name / Operator NE / Value \$RoleParam{Name}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'NE',
                    Value    => $RoleParam{Name}[0]
                }
            ]
        },
        Expected => [$RoleID2,$RoleID3,$RoleID4]
    },
    {
        Name     => "Search: Field Name / Operator IN / Value \$RoleParam{Name}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'IN',
                    Value    => $RoleParam{Name}[0]
                }
            ]
        },
        Expected => [$RoleID1]
    },
    {
        Name     => "Search: Field Name / Operator !IN / Value \$RoleParam{Name}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => '!IN',
                    Value    => $RoleParam{Name}[0]
                }
            ]
        },
        Expected => [$RoleID2,$RoleID3,$RoleID4]
    },
    {
        Name     => "Search: Field Name / Operator STARTSWITH / Value \$RoleParam{Name}[1]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'STARTSWITH',
                    Value    => $RoleParam{Name}[1]
                }
            ]
        },
        Expected => [$RoleID2]
    },
    {
        Name     => "Search: Field Name / Operator STARTSWITH / Value substr(\$RoleParam{Name}[1],0,5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'STARTSWITH',
                    Value    => substr($RoleParam{Name}[1],0,5)
                }
            ]
        },
        Expected => [$RoleID1,$RoleID2,$RoleID3,$RoleID4]
    },
    {
        Name     => "Search: Field Name / Operator ENDSWITH / Value \$RoleParam{Name}[2]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'ENDSWITH',
                    Value    => $RoleParam{Name}[2]
                }
            ]
        },
        Expected => [$RoleID3]
    },
    {
        Name     => "Search: Field Name / Operator ENDSWITH / Value substr(\$RoleParam{Name}[2],-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'ENDSWITH',
                    Value    => substr($RoleParam{Name}[2],-5)
                }
            ]
        },
        Expected => [$RoleID3]
    },
    {
        Name     => "Search: Field Name / Operator CONTAINS / Value \$RoleParam{Name}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'CONTAINS',
                    Value    => $RoleParam{Name}[0]
                }
            ]
        },
        Expected => [$RoleID1]
    },
    {
        Name     => "Search: Field Name / Operator CONTAINS / Value substr(\$RoleParam{Name}[0],5,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'CONTAINS',
                    Value    => substr($RoleParam{Name}[0],5,-5)
                }
            ]
        },
        Expected => [$RoleID1,$RoleID2,$RoleID3,$RoleID4]
    },
    {
        Name     => "Search: Field Name / Operator LIKE / Value \$RoleParam{Name}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'LIKE',
                    Value    => $RoleParam{Name}[0]
                }
            ]
        },
        Expected => [$RoleID1]
    },
    {
        Name     => "Search: Field Name / Operator LIKE / Value *substr(\$RoleParam{Name}[0],5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Name',
                    Operator => 'LIKE',
                    Value    => q{*} . substr($RoleParam{Name}[0],5)
                }
            ]
        },
        Expected => [$RoleID1]
    },
    {
        Name     => "Search: Field UsageContext / Operator EQ / Value AGENT",
        Search   => {
            'AND' => [
                {
                    Field    => 'UsageContext',
                    Operator => 'EQ',
                    Value    => Kernel::System::Role->USAGE_CONTEXT->{AGENT}
                }
            ]
        },
        Expected => [$RoleID1,$RoleID4]
    },
    {
        Name     => "Search: Field UsageContext / Operator NE / Value AGENT",
        Search   => {
            'AND' => [
                {
                    Field    => 'UsageContext',
                    Operator => 'NE',
                    Value    => Kernel::System::Role->USAGE_CONTEXT->{AGENT}
                }
            ]
        },
        Expected => [$RoleID2,$RoleID3]
    },
    {
        Name     => "Search: Field UsageContext / Operator IN / Value AGENT",
        Search   => {
            'AND' => [
                {
                    Field    => 'UsageContext',
                    Operator => 'IN',
                    Value    => Kernel::System::Role->USAGE_CONTEXT->{AGENT}
                }
            ]
        },
        Expected => [$RoleID1,$RoleID4]
    },
    {
        Name     => "Search: Field UsageContext / Operator !IN / Value AGENT",
        Search   => {
            'AND' => [
                {
                    Field    => 'UsageContext',
                    Operator => '!IN',
                    Value    => Kernel::System::Role->USAGE_CONTEXT->{AGENT}
                }
            ]
        },
        Expected => [$RoleID2,$RoleID3]
    },
    {
        Name     => 'Search: Field UsageContext / Operator LT / Value AGENT',
        Search   => {
            'AND' => [
                {
                    Field    => 'UsageContext',
                    Operator => 'LT',
                    Value    => Kernel::System::Role->USAGE_CONTEXT->{AGENT}
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field UsageContext / Operator LTE / Value AGENT',
        Search   => {
            'AND' => [
                {
                    Field    => 'UsageContext',
                    Operator => 'LTE',
                    Value    => Kernel::System::Role->USAGE_CONTEXT->{AGENT}
                }
            ]
        },
        Expected => [$RoleID1,$RoleID4]
    },
    {
        Name     => 'Search: Field UsageContext / Operator GT / Value AGENT',
        Search   => {
            'AND' => [
                {
                    Field    => 'UsageContext',
                    Operator => 'GT',
                    Value    => Kernel::System::Role->USAGE_CONTEXT->{AGENT}
                }
            ]
        },
        Expected => [$RoleID2,$RoleID3]
    },
    {
        Name     => 'Search: Field UsageContext / Operator GTE / Value AGENT',
        Search   => {
            'AND' => [
                {
                    Field    => 'UsageContext',
                    Operator => 'GTE',
                    Value    => Kernel::System::Role->USAGE_CONTEXT->{AGENT}
                }
            ]
        },
        Expected => [$RoleID1,$RoleID2,$RoleID3,$RoleID4]
    },
    {
        Name     => "Search: Field Comment / Operator EQ / Value \$RoleParam{Comment}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'EQ',
                    Value    => $RoleParam{Comment}[0]
                }
            ]
        },
        Expected => [$RoleID1]
    },
    {
        Name     => "Search: Field Comment / Operator NE / Value \$RoleParam{Comment}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'NE',
                    Value    => $RoleParam{Comment}[0]
                }
            ]
        },
        Expected => [$RoleID2,$RoleID3,$RoleID4]
    },
    {
        Name     => "Search: Field Comment / Operator IN / Value \$RoleParam{Comment}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'IN',
                    Value    => $RoleParam{Comment}[0]
                }
            ]
        },
        Expected => [$RoleID1]
    },
    {
        Name     => "Search: Field Comment / Operator !IN / Value \$RoleParam{Comment}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => '!IN',
                    Value    => $RoleParam{Comment}[0]
                }
            ]
        },
        Expected => [$RoleID2,$RoleID3,$RoleID4]
    },
    {
        Name     => "Search: Field Comment / Operator STARTSWITH / Value \$RoleParam{Comment}[1]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'STARTSWITH',
                    Value    => $RoleParam{Comment}[1]
                }
            ]
        },
        Expected => [$RoleID2]
    },
    {
        Name     => "Search: Field Comment / Operator STARTSWITH / Value substr(\$RoleParam{Comment}[1],0,5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'STARTSWITH',
                    Value    => substr($RoleParam{Comment}[1],0,5)
                }
            ]
        },
        Expected => [$RoleID1,$RoleID2,$RoleID3,$RoleID4]
    },
    {
        Name     => "Search: Field Comment / Operator ENDSWITH / Value \$RoleParam{Comment}[2]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'ENDSWITH',
                    Value    => $RoleParam{Comment}[2]
                }
            ]
        },
        Expected => [$RoleID3]
    },
    {
        Name     => "Search: Field Comment / Operator ENDSWITH / Value substr(\$RoleParam{Comment}[2],-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'ENDSWITH',
                    Value    => substr($RoleParam{Comment}[2],-5)
                }
            ]
        },
        Expected => [$RoleID3]
    },
    {
        Name     => "Search: Field Comment / Operator CONTAINS / Value \$RoleParam{Comment}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'CONTAINS',
                    Value    => $RoleParam{Comment}[0]
                }
            ]
        },
        Expected => [$RoleID1]
    },
    {
        Name     => "Search: Field Comment / Operator CONTAINS / Value substr(\$RoleParam{Comment}[0],5,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'CONTAINS',
                    Value    => substr($RoleParam{Comment}[0],5,-5)
                }
            ]
        },
        Expected => [$RoleID1,$RoleID2,$RoleID3,$RoleID4]
    },
    {
        Name     => "Search: Field Comment / Operator LIKE / Value \$RoleParam{Comment}[0]",
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'LIKE',
                    Value    => $RoleParam{Comment}[0]
                }
            ]
        },
        Expected => [$RoleID1]
    },
    {
        Name     => "Search: Field Comment / Operator LIKE / Value *substr(\$RoleParam{Comment}[0],5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Comment',
                    Operator => 'LIKE',
                    Value    => q{*} . substr($RoleParam{Comment}[0],5)
                }
            ]
        },
        Expected => [$RoleID1]
    },
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Role',
        Result     => 'ARRAY',
        Search     => $Test->{Search},
        UserType   => 'Agent',
        UserID     => 1
    );
    $Self->IsDeeply(
        \@Result,
        $Test->{Expected},
        $Test->{Name}
    );
}

# check Sort
my @IntegrationSortTests = (
    {
        Name     => 'Sort: Field Name',
        Sort     => [
            {
                Field => 'Name'
            }
        ],
        Expected => [$RoleID1, $RoleID2, $RoleID3, $RoleID4]
    },
    {
        Name     => 'Sort: Field Name / Direction ascending',
        Sort     => [
            {
                Field     => 'Name',
                Direction => 'ascending'
            }
        ],
        Expected => [$RoleID1, $RoleID2, $RoleID3, $RoleID4]
    },
    {
        Name     => 'Sort: Field Name / Direction descending',
        Sort     => [
            {
                Field     => 'Name',
                Direction => 'descending'
            }
        ],
        Expected => [$RoleID4, $RoleID3, $RoleID2, $RoleID1]
    },
    {
        Name     => 'Sort: Field UsageContext',
        Sort     => [
            {
                Field => 'UsageContext'
            }
        ],
        Expected => [$RoleID1, $RoleID4, $RoleID2, $RoleID3]
    },
    {
        Name     => 'Sort: Field UsageContext / Direction ascending',
        Sort     => [
            {
                Field     => 'UsageContext',
                Direction => 'ascending'
            }
        ],
        Expected => [$RoleID1, $RoleID4, $RoleID2, $RoleID3]
    },
    {
        Name     => 'Sort: Field UsageContext / Direction descending',
        Sort     => [
            {
                Field     => 'UsageContext',
                Direction => 'descending'
            }
        ],
        Expected => [$RoleID3, $RoleID2, $RoleID1, $RoleID4]
    },
    {
        Name     => 'Sort: Field Comment',
        Sort     => [
            {
                Field => 'Comment'
            }
        ],
        Expected => [$RoleID1, $RoleID2, $RoleID3, $RoleID4]
    },
    {
        Name     => 'Sort: Field Comment / Direction ascending',
        Sort     => [
            {
                Field     => 'Comment',
                Direction => 'ascending'
            }
        ],
        Expected => [$RoleID1, $RoleID2, $RoleID3, $RoleID4]
    },
    {
        Name     => 'Sort: Field Comment / Direction descending',
        Sort     => [
            {
                Field     => 'Comment',
                Direction => 'descending'
            }
        ],
        Expected => [$RoleID4, $RoleID3, $RoleID2, $RoleID1]
    },
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
