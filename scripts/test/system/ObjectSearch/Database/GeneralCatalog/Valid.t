# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::GeneralCatalog::Valid';

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
        Valid => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN']
        },
        ValidID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN'],
            ValueType    => 'NUMERIC'
        }
    },
    'GetSupportedAttributes prgcv.ides expected data'
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
            'Join'  => [],
            'Where' => [
                'gc.valid_id = 1'
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
                'gc.valid_id <> 1'
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
        Expected     => {
            'Join'  => [],
            'Where' => [
                'gc.valid_id IN (1)'
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
                'gc.valid_id NOT IN (1)'
            ]
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
                'INNER JOIN valid gcv ON gcv.id = gc.valid_id'
            ],
            'Where' => [
                'gcv.name = \'Test\''
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
                'INNER JOIN valid gcv ON gcv.id = gc.valid_id'
            ],
            'Where' => [
                'gcv.name != \'Test\''
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
                'INNER JOIN valid gcv ON gcv.id = gc.valid_id'
            ],
            'Where' => [
                'gcv.name IN (\'Test\')'
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
                'INNER JOIN valid gcv ON gcv.id = gc.valid_id'
            ],
            'Where' => [
                'gcv.name NOT IN (\'Test\')'
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
                'gc.valid_id'
            ],
            'Select'  => [
                'gc.valid_id'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Valid"',
        Attribute => 'Valid',
        Expected  => {
            'Join'    => [
                'INNER JOIN valid gcv ON gcv.id = gc.valid_id',
                'LEFT OUTER JOIN translation_pattern tlp0 ON tlp0.value = gcv.name',
                'LEFT OUTER JOIN translation_language tl0 ON tl0.pattern_id = tlp0.id AND tl0.language = \'en\''
            ],
            'OrderBy' => [
                'TranslateValid'
            ],
            'Select'  => [
                'LOWER(COALESCE(tl0.value, gcv.name)) AS TranslateValid'
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

## prepare test general catalog items ##
# first asset
my $ItemID1 = $Kernel::OM->Get('GeneralCatalog')->ItemAdd(
    Class   => 'Unit::Test::Type',
    Name    => 'Foo',
    ValidID => $ValidID3,
    UserID  => 1
);
$Self->True(
    $ItemID1,
    'Created first item'
);
# second asset
my $ItemID2 = $Kernel::OM->Get('GeneralCatalog')->ItemAdd(
    Class   => 'Unit::Test::Type',
    Name    => 'Baa',
    ValidID => $ValidID2,
    UserID  => 1
);
$Self->True(
    $ItemID2,
    'Created second item'
);
# third asset
my $ItemID3 = $Kernel::OM->Get('GeneralCatalog')->ItemAdd(
    Class   => 'Unit::Test::Type',
    Name    => 'Test',
    ValidID => $ValidID3,
    UserID  => 1
);
$Self->True(
    $ItemID3,
    'Created third item'
);

# discard config item object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['GeneralCatalog'],
);

# prepare result lists
my @ItemIDs = $ObjectSearch->Search(
    ObjectType => 'GeneralCatalog',
    Result     => 'ARRAY',
    UserType   => 'Agent',
    UserID     => 1,
);

$Self->True(
    scalar( @ItemIDs ),
    'ItemID: GET / All Items'
);

# List for NE
my @TmpList = @ItemIDs;
splice(@TmpList, -2,1);  # remove ItemID2
my @List1 = @TmpList;

# List for IN and for Sort
@TmpList = @ItemIDs;
splice(@TmpList, -3);  # remove ItemID1-3
my @List2 = @TmpList;


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
        Expected => [$ItemID2]
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
        Expected => \@List1
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
        Expected => \@List2
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
        Expected => [$ItemID1,$ItemID2,$ItemID3]
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
        Expected => [$ItemID2]
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
        Expected => \@List1
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
        Expected => \@List2
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
        Expected => [$ItemID1,$ItemID2,$ItemID3]
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'GeneralCatalog',
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
        Expected => [@List2,$ItemID2,$ItemID1,$ItemID3]
    },
    {
        Name     => 'Sort: Field ValidID / Direction ascending',
        Sort     => [
            {
                Field     => 'ValidID',
                Direction => 'ascending'
            }
        ],
        Expected => [@List2,$ItemID2,$ItemID1,$ItemID3]
    },
    {
        Name     => 'Sort: Field ValidID / Direction descending',
        Sort     => [
            {
                Field     => 'ValidID',
                Direction => 'descending'
            }
        ],
        Limit    => 3,
        Expected => [$ItemID1,$ItemID3,$ItemID2]
    },
    {
        Name     => 'Sort: Field Valid',
        Sort     => [
            {
                Field => 'Valid'
            }
        ],
        Expected => [$ItemID2,$ItemID1,$ItemID3,@List2]
    },
    {
        Name     => 'Sort: Field Valid / Direction ascending',
        Sort     => [
            {
                Field     => 'Valid',
                Direction => 'ascending'
            }
        ],
        Expected => [$ItemID2,$ItemID1,$ItemID3,@List2]
    },
    {
        Name     => 'Sort: Field Valid / Direction descending',
        Sort     => [
            {
                Field     => 'Valid',
                Direction => 'descending'
            }
        ],
        Expected => [@List2,$ItemID1,$ItemID3,$ItemID2]
    },
    {
        Name     => 'Sort: Field Valid / Language de',
        Sort     => [
            {
                Field => 'Valid'
            }
        ],
        Language => 'de',
        Expected => [@List2,$ItemID1,$ItemID3,$ItemID2]
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
        Expected => [@List2,$ItemID1,$ItemID3,$ItemID2]
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
        Limit    => 3,
        Expected => [$ItemID2,$ItemID1,$ItemID3]
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'GeneralCatalog',
        Result     => 'ARRAY',
        Sort       => $Test->{Sort},
        Language   => $Test->{Language},
        UserType   => 'Agent',
        UserID     => 1,
        Limit      => $Test->{Limit}
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
