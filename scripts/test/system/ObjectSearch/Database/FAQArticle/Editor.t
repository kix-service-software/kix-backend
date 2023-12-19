# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::FAQArticle::Editor';

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
        CreateBy => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN'],
            ValueType    => 'NUMERIC'
        },
        CreatedUserIDs => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN'],
            ValueType    => 'NUMERIC'
        },
        ChangeBy => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN'],
            ValueType    => 'NUMERIC'
        },
        LastChangedUserIDs => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN'],
            ValueType    => 'NUMERIC'
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
            Field    => 'CreateBy',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'CreateBy',
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
            Field    => 'CreateBy',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'CreateBy',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
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
                'f.created_by = 1'
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
                'f.created_by <> 1'
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
        BoolOperator => 'AND',
        Expected     => {
            'Where' => [
                'f.created_by IN (1)'
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
                'f.created_by NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedUserIDs / Operator EQ',
        Search       => {
            Field    => 'CreatedUserIDs',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'f.created_by = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedUserIDs / Operator NE',
        Search       => {
            Field    => 'CreatedUserIDs',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'f.created_by <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedUserIDs / Operator IN',
        Search       => {
            Field    => 'CreatedUserIDs',
            Operator => 'IN',
            Value    => ['1']
        },
        BoolOperator => 'AND',
        Expected     => {
            'Where' => [
                'f.created_by IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CreatedUserIDs / Operator !IN',
        Search       => {
            Field    => 'CreatedUserIDs',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'f.created_by NOT IN (1)'
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
                'f.changed_by = 1'
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
                'f.changed_by <> 1'
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
        BoolOperator => 'AND',
        Expected     => {
            'Where' => [
                'f.changed_by IN (1)'
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
                'f.changed_by NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field LastChangedUserIDs / Operator EQ',
        Search       => {
            Field    => 'LastChangedUserIDs',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'f.changed_by = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field LastChangedUserIDs / Operator NE',
        Search       => {
            Field    => 'LastChangedUserIDs',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'f.changed_by <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field LastChangedUserIDs / Operator IN',
        Search       => {
            Field    => 'LastChangedUserIDs',
            Operator => 'IN',
            Value    => ['1']
        },
        BoolOperator => 'AND',
        Expected     => {
            'Where' => [
                'f.changed_by IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field LastChangedUserIDs / Operator !IN',
        Search       => {
            Field    => 'LastChangedUserIDs',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'f.changed_by NOT IN (1)'
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
        Name      => 'Sort: Attribute "CreateBy"',
        Attribute => 'CreateBy',
        Expected  => {
            'Join'    => [
                'INNER JOIN contact ccr ON ccr.user_id = f.created_by'
            ],
            'OrderBy' => [
                'ccr.lastname', 'ccr.firstname'
            ],
            'Select'  => [
                'ccr.lastname', 'ccr.firstname'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "CreatedUserIDs"',
        Attribute => 'CreatedUserIDs',
        Expected  => {
            'Join'    => [
                'INNER JOIN contact ccr ON ccr.user_id = f.created_by'
            ],
            'OrderBy' => [
                'ccr.lastname', 'ccr.firstname'
            ],
            'Select'  => [
                'ccr.lastname', 'ccr.firstname'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "CreateBy"',
        Attribute => 'ChangeBy',
        Expected  => {
            'Join'    => [
                'INNER JOIN contact cch ON cch.user_id = f.changed_by'
            ],
            'OrderBy' => [
                'cch.lastname', 'cch.firstname'
            ],
            'Select'  => [
                'cch.lastname', 'cch.firstname'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "LastChangedUserIDs"',
        Attribute => 'LastChangedUserIDs',
        Expected  => {
            'Join'    => [
                'INNER JOIN contact cch ON cch.user_id = f.changed_by'
            ],
            'OrderBy' => [
                'cch.lastname', 'cch.firstname'
            ],
            'Select'  => [
                'cch.lastname', 'cch.firstname'
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
my $UserID1 = 1;
my $UserID2 = $Helper->TestUserCreate( Result => 'ID' );
my $UserID3 = $Helper->TestUserCreate( Result => 'ID' );

## prepare test faq articles ##
# first faq article
my $FAQArticleID1 = $Kernel::OM->Get('FAQ')->FAQAdd(
    Title       => $Helper->GetRandomID(),
    CategoryID  => 1,
    Visibility  => 'internal',
    Language    => 'en',
    ValidID     => 1,
    ContentType => 'text/plain',
    UserID      => $UserID1,
);
$Self->True(
    $FAQArticleID1,
    'Created first faq article'
);
# second faq article
my $FAQArticleID2 = $Kernel::OM->Get('FAQ')->FAQAdd(
    Title       => $Helper->GetRandomID(),
    CategoryID  => 1,
    Visibility  => 'public',
    Language    => 'en',
    ValidID     => 1,
    ContentType => 'text/plain',
    UserID      => $UserID2,
);
$Self->True(
    $FAQArticleID1,
    'Created second faq article'
);
# third faq article
my $FAQArticleID3 = $Kernel::OM->Get('FAQ')->FAQAdd(
    Title       => $Helper->GetRandomID(),
    CategoryID  => 1,
    Visibility  => 'external',
    Language    => 'en',
    ValidID     => 1,
    ContentType => 'text/plain',
    UserID      => $UserID3,
);
$Self->True(
    $FAQArticleID1,
    'Created third faq article'
);

# test Search
my @IntegrationSearchTests = (
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
        Expected => [$FAQArticleID2]
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
        Expected => [$FAQArticleID1,$FAQArticleID3]
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
        Expected => [$FAQArticleID1, $FAQArticleID3]
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
        Expected => [$FAQArticleID2]
    },
    {
        Name     => "Search: Field CreatedUserIDs / Operator EQ / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedUserIDs',
                    Operator => 'EQ',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$FAQArticleID2]
    },
    {
        Name     => "Search: Field CreatedUserIDs / Operator NE / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedUserIDs',
                    Operator => 'NE',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID3]
    },
    {
        Name     => "Search: Field CreatedUserIDs / Operator IN / Value [\$UserID1,\$UserID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedUserIDs',
                    Operator => 'IN',
                    Value    => [$UserID1,$UserID3]
                }
            ]
        },
        Expected => [$FAQArticleID1, $FAQArticleID3]
    },
    {
        Name     => "Search: Field CreateUserIDs / Operator !IN / Value [\$UserID1,\$UserID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'CreatedUserIDs',
                    Operator => '!IN',
                    Value    => [$UserID1,$UserID3]
                }
            ]
        },
        Expected => [$FAQArticleID2]
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
        Expected => [$FAQArticleID2]
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
        Expected => [$FAQArticleID1,$FAQArticleID3]
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
        Expected => [$FAQArticleID1, $FAQArticleID3]
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
        Expected => [$FAQArticleID2]
    },
    {
        Name     => "Search: Field LastChangedUserIDs / Operator EQ / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'LastChangedUserIDs',
                    Operator => 'EQ',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$FAQArticleID2]
    },
    {
        Name     => "Search: Field LastChangedUserIDs / Operator NE / Value \$UserID2",
        Search   => {
            'AND' => [
                {
                    Field    => 'LastChangedUserIDs',
                    Operator => 'NE',
                    Value    => $UserID2
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID3]
    },
    {
        Name     => "Search: Field LastChangedUserIDs / Operator IN / Value [\$UserID1,\$UserID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'LastChangedUserIDs',
                    Operator => 'IN',
                    Value    => [$UserID1,$UserID3]
                }
            ]
        },
        Expected => [$FAQArticleID1, $FAQArticleID3]
    },
    {
        Name     => "Search: Field LastChangedUserIDs / Operator !IN / Value [\$UserID1,\$UserID3]",
        Search   => {
            'AND' => [
                {
                    Field    => 'LastChangedUserIDs',
                    Operator => '!IN',
                    Value    => [$UserID1,$UserID3]
                }
            ]
        },
        Expected => [$FAQArticleID2]
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'FAQArticle',
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

# test Sort
my @IntegrationSortTests = (
    {
        Name     => 'Sort: Field CreateBy',
        Sort     => [
            {
                Field => 'CreateBy'
            }
        ],
        Language => 'en',
        Expected => [$FAQArticleID1, $FAQArticleID2, $FAQArticleID3]
    },
    {
        Name     => 'Sort: Field CreateBy / Direction ascending',
        Sort     => [
            {
                Field     => 'CreateBy',
                Direction => 'ascending'
            }
        ],
        Language => 'en',
        Expected => [$FAQArticleID1, $FAQArticleID2, $FAQArticleID3]
    },
    {
        Name     => 'Sort: Field CreateBy / Direction descending',
        Sort     => [
            {
                Field     => 'CreateBy',
                Direction => 'descending'
            }
        ],
        Language => 'en',
        Expected => [$FAQArticleID3, $FAQArticleID2, $FAQArticleID1]
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'FAQArticle',
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
