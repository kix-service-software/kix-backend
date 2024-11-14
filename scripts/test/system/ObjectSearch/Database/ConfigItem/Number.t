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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::ConfigItem::Number';

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
        Number => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
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
            Field    => 'Number',
            Operator => 'EQ',
            Value    => undef

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
            Field    => 'Number',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'Number',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field Number / Operator EQ',
        Search       => {
            Field    => 'Number',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(ci.configitem_number) = \'test\'' : 'ci.configitem_number = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Number / Operator NE',
        Search       => {
            Field    => 'Number',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(ci.configitem_number) != \'test\'' : 'ci.configitem_number != \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Number / Operator IN',
        Search       => {
            Field    => 'Number',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(ci.configitem_number) IN (\'test\')' : 'ci.configitem_number IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Number / Operator !IN',
        Search       => {
            Field    => 'Number',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(ci.configitem_number) NOT IN (\'test\')' : 'ci.configitem_number NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Number / Operator STARTSWITH',
        Search       => {
            Field    => 'Number',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(ci.configitem_number) LIKE \'test%\'' : 'ci.configitem_number LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Number / Operator ENDSWITH',
        Search       => {
            Field    => 'Number',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(ci.configitem_number) LIKE \'%test\'' : 'ci.configitem_number LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Number / Operator CONTAINS',
        Search       => {
            Field    => 'Number',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(ci.configitem_number) LIKE \'%test%\'' : 'ci.configitem_number LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Number / Operator LIKE',
        Search       => {
            Field    => 'Number',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? 'LOWER(ci.configitem_number) LIKE \'test\'' : 'ci.configitem_number LIKE \'test\''
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
        Name      => 'Sort: Attribute "Number"',
        Attribute => 'Number',
        Expected  => {
            'OrderBy' => [ 'LOWER(ci.configitem_number)' ],
            'Select'  => [ 'ci.configitem_number' ]
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

# prepare class mapping
my $ClassRef = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class         => 'ITSM::ConfigItem::Class',
    Name          => 'Building',
    NoPreferences => 1
);

## prepare test assets ##
# first asset
my $ConfigItemNumber1 = '123000001';
my $ConfigItemID1     = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
    Number  => $ConfigItemNumber1,
    ClassID => $ClassRef->{ItemID},
    UserID  => 1,
);
$Self->True(
    $ConfigItemID1,
    'Created first asset'
);
# second asset
my $ConfigItemNumber2 = '123000002';
my $ConfigItemID2     = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
    Number  => $ConfigItemNumber2,
    ClassID => $ClassRef->{ItemID},
    UserID  => 1,
);
$Self->True(
    $ConfigItemID2,
    'Created second asset'
);
# third asset
my $ConfigItemNumber3 = '123000003';
my $ConfigItemID3     = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
    Number  => $ConfigItemNumber3,
    ClassID => $ClassRef->{ItemID},
    UserID  => 1,
);
$Self->True(
    $ConfigItemID3,
    'Created third asset'
);

# discard config item object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['ITSMConfigItem'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field Number / Operator EQ / Value $ConfigItemNumber2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'EQ',
                    Value    => $ConfigItemNumber2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Number / Operator NE / Value $ConfigItemNumber2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'NE',
                    Value    => $ConfigItemNumber2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID3]
    },
    {
        Name     => 'Search: Field Number / Operator IN / Value [$ConfigItemNumber1,$ConfigItemNumber3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'IN',
                    Value    => [$ConfigItemNumber1,$ConfigItemNumber3]
                }
            ]
        },
        Expected => [$ConfigItemID1, $ConfigItemID3]
    },
    {
        Name     => 'Search: Field Number / Operator !IN / Value [$ConfigItemNumber1,$ConfigItemNumber3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => '!IN',
                    Value    => [$ConfigItemNumber1,$ConfigItemNumber3]
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Number / Operator STARTSWITH / Value $ConfigItemNumber2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'STARTSWITH',
                    Value    => $ConfigItemNumber2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Number / Operator STARTSWITH / Value substr($ConfigItemNumber2,0,5)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'STARTSWITH',
                    Value    => substr($ConfigItemNumber2,0,5)
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => 'Search: Field Number / Operator ENDSWITH / Value $ConfigItemNumber2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'ENDSWITH',
                    Value    => $ConfigItemNumber2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Number / Operator ENDSWITH / Value substr($ConfigItemNumber2,-4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'ENDSWITH',
                    Value    => substr($ConfigItemNumber2,-4)
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Number / Operator CONTAINS / Value $ConfigItemNumber2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'CONTAINS',
                    Value    => $ConfigItemNumber2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Number / Operator CONTAINS / Value substr($ConfigItemNumber2,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'CONTAINS',
                    Value    => substr($ConfigItemNumber2,2,-2)
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => 'Search: Field Number / Operator LIKE / Value $ConfigItemNumber2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Number',
                    Operator => 'LIKE',
                    Value    => $ConfigItemNumber2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'ConfigItem',
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
        Name     => 'Sort: Field Number',
        Sort     => [
            {
                Field => 'Number'
            }
        ],
        Expected => [$ConfigItemID1,$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => 'Sort: Field Number / Direction ascending',
        Sort     => [
            {
                Field     => 'Number',
                Direction => 'ascending'
            }
        ],
        Expected => [$ConfigItemID1,$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => 'Sort: Field Number / Direction descending',
        Sort     => [
            {
                Field     => 'Number',
                Direction => 'descending'
            }
        ],
        Expected => [$ConfigItemID3,$ConfigItemID2,$ConfigItemID1]
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'ConfigItem',
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
