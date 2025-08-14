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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Contact::Valid';

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
            Field    => 'ValidID',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'ValidID',
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
            'Where'      => [
                'c.valid_id = 1'
            ],
            'IsRelative' => undef,
            'Join'       => []
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
            'Where' => [
                'c.valid_id <> 1'
            ],
            'IsRelative' => undef,
            'Join'       => []
        }
    },
    {
        Name         => 'Search: valid search / Field ValidID / Operator IN',
        Search       => {
            Field    => 'ValidID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'c.valid_id IN (1)'
            ],
            'IsRelative' => undef,
            'Join'       => []
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
            'Where' => [
                'c.valid_id NOT IN (1)'
            ],
            'IsRelative' => undef,
            'Join'       => []
        }
    },
    {
        Name         => 'Search: valid search / Field Valid / Operator EQ',
        Search       => {
            Field    => 'Valid',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN valid cv ON cv.id = c.valid_id'
            ],
            'Where' => [
                'cv.name = \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Valid / Operator NE',
        Search       => {
            Field    => 'Valid',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN valid cv ON cv.id = c.valid_id'
            ],
            'Where' => [
                'cv.name != \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Valid / Operator IN',
        Search       => {
            Field    => 'Valid',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN valid cv ON cv.id = c.valid_id'
            ],
            'Where' => [
                'cv.name IN (\'Test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Valid / Operator !IN',
        Search       => {
            Field    => 'Valid',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN valid cv ON cv.id = c.valid_id'
            ],
            'Where' => [
                'cv.name NOT IN (\'Test\')'
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
        Name      => 'Sort: Attribute "ValidID"',
        Attribute => 'ValidID',
        Expected  => {
            'Join'    => [],
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select'  => [
                'c.valid_id AS SortAttr0'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Valid"',
        Attribute => 'Valid',
        Expected  => {
            'Join'    => [
                'INNER JOIN valid cv ON cv.id = c.valid_id',
                'LEFT OUTER JOIN translation_pattern tlp0 ON tlp0.value = cv.name',
                'LEFT OUTER JOIN translation_language tl0 ON tl0.pattern_id = tlp0.id AND tl0.language = \'en\''
            ],
            'OrderBy' => [
                'SortAttr0'
            ],
            'Select'  => [
                'LOWER(COALESCE(tl0.value, cv.name)) AS SortAttr0'
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

# load translations for given language
my @Translations = $Kernel::OM->Get('Translation')->TranslationList();
my %TranslationsDE;
for my $Translation ( @Translations ) {
    $TranslationsDE{ $Translation->{Pattern} } = $Translation->{Languages}->{'de'};
}

## prepare valid mapping
my $ValidID1 = 1;
my $ValidID2 = 2;
my $ValidID3 = 3;
my $ValidName1 = $Kernel::OM->Get('Valid')->ValidLookup(
    ValidID => $ValidID1
);
$Self->Is(
    $ValidName1,
    'valid',
    'ValidID 1 has expected name'
);
$Self->Is(
    $TranslationsDE{ $ValidName1 },
    'gültig',
    'ValidID 1 has expected translation (de)'
);
my $ValidName2 = $Kernel::OM->Get('Valid')->ValidLookup(
    ValidID => $ValidID2
);
$Self->Is(
    $ValidName2,
    'invalid',
    'ValidID 2 has expected name'
);
$Self->Is(
    $TranslationsDE{ $ValidName2 },
    'ungültig',
    'ValidID 2 has expected translation (de)'
);
my $ValidName3 = $Kernel::OM->Get('Valid')->ValidLookup(
    ValidID => $ValidID3
);
$Self->Is(
    $ValidName3,
    'invalid-temporarily',
    'ValidID 3 has expected name'
);
$Self->Is(
    $TranslationsDE{ $ValidName3 },
    'temporär ungültig',
    'ValidID 3 has expected translation (de)'
);


## prepare test contacts ##
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
# second contact valid change
my %Contact2 = $Kernel::OM->Get('Contact')->ContactGet(
    ID => $ContactID2
);
$Kernel::OM->Get('Contact')->ContactUpdate(
    %Contact2,
    ID      => $ContactID2,
    ValidID => $ValidID2,
    UserID  => 1
);
# third contact
my $ContactID3 = $Helper->TestContactCreate();
$Self->True(
    $ContactID2,
    'Created third contact'
);
# second contact valid change
my %Contact3 = $Kernel::OM->Get('Contact')->ContactGet(
    ID => $ContactID3
);
$Kernel::OM->Get('Contact')->ContactUpdate(
    %Contact3,
    ID      => $ContactID3,
    ValidID => $ValidID3,
    UserID  => 1
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Contact'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field ValidID / Operator EQ / Value $ValidID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ValidID',
                    Operator => 'EQ',
                    Value    => $ValidID2
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => 'Search: Field ValidID / Operator NE / Value $ValidID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ValidID',
                    Operator => 'NE',
                    Value    => $ValidID2
                }
            ]
        },
        Expected => ['1',$ContactID1,$ContactID3]
    },
    {
        Name     => 'Search: Field ValidID / Operator IN / Value [$ValidID1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ValidID',
                    Operator => 'IN',
                    Value    => [$ValidID1]
                }
            ]
        },
        Expected => ['1',$ContactID1]
    },
    {
        Name     => 'Search: Field ValidID / Operator !IN / Value [$ValidID1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ValidID',
                    Operator => '!IN',
                    Value    => [$ValidID1]
                }
            ]
        },
        Expected => [$ContactID2,$ContactID3]
    },
    {
        Name     => 'Search: Field Valid / Operator EQ / Value $ValidName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Valid',
                    Operator => 'EQ',
                    Value    => $ValidName2
                }
            ]
        },
        Expected => [$ContactID2]
    },
    {
        Name     => 'Search: Field Valid / Operator NE / Value $ValidName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Valid',
                    Operator => 'NE',
                    Value    => $ValidName2
                }
            ]
        },
        Expected => ['1',$ContactID1,$ContactID3]
    },
    {
        Name     => 'Search: Field Valid / Operator IN / Value [$ValidName1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Valid',
                    Operator => 'IN',
                    Value    => [$ValidName1]
                }
            ]
        },
        Expected => ['1',$ContactID1]
    },
    {
        Name     => 'Search: Field Valid / Operator !IN / Value [$ValidName1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Valid',
                    Operator => '!IN',
                    Value    => [$ValidName1]
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
        Name     => 'Sort: Field ValidID',
        Sort     => [
            {
                Field => 'ValidID'
            }
        ],
        Expected => ['1',$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => 'Sort: Field ValidID / Direction ascending',
        Sort     => [
            {
                Field     => 'ValidID',
                Direction => 'ascending'
            }
        ],
        Expected => ['1',$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => 'Sort: Field ValidID / Direction descending',
        Sort     => [
            {
                Field     => 'ValidID',
                Direction => 'descending'
            }
        ],
        Expected => [$ContactID3,$ContactID2,'1',$ContactID1]
    },
    {
        Name     => 'Sort: Field Valid',
        Sort     => [
            {
                Field => 'Valid'
            }
        ],
        Expected => [$ContactID2,$ContactID3,'1',$ContactID1]
    },
    {
        Name     => 'Sort: Field Valid / Direction ascending',
        Sort     => [
            {
                Field     => 'Valid',
                Direction => 'ascending'
            }
        ],
        Expected => [$ContactID2,$ContactID3,'1',$ContactID1]
    },
    {
        Name     => 'Sort: Field Valid / Direction descending',
        Sort     => [
            {
                Field     => 'Valid',
                Direction => 'descending'
            }
        ],
        Expected => ['1',$ContactID1,$ContactID3,$ContactID2]
    },
    {
        Name     => 'Sort: Field Valid / Language de',
        Sort     => [
            {
                Field => 'Valid'
            }
        ],
        Language => 'de',
        Expected => ['1',$ContactID1,$ContactID3,$ContactID2]
    },
    {
        Name     => 'Sort: Field Valid / Direction ascending / Language de',
        Sort     => [
            {
                Field     => 'Valid',
                Direction => 'ascending'
            }
        ],
        Language => 'de',
        Expected => ['1',$ContactID1,$ContactID3,$ContactID2]
    },
    {
        Name     => 'Sort: Field Valid / Direction descending / Language de',
        Sort     => [
            {
                Field     => 'Valid',
                Direction => 'descending'
            }
        ],
        Language => 'de',
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
