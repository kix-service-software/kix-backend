# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::GeneralCatalog::Fulltext';

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
    $AttributeList, {
        Fulltext => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['LIKE']
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
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Field invalid',
        Search       => {
            Field    => 'Test',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator undef',
        Search       => {
            Field    => 'Name',
            Operator => undef,
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'Name',
            Operator => 'Test',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field Fulltext / Operator LIKE',
        Search       => {
            Field    => 'Fulltext',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(gc.name) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(gc.general_catalog_class) LIKE \'%test%\' ESCAPE \'' . $Escape . '\') ' : '(gc.name LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR gc.general_catalog_class LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
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
        Name      => 'Sort: Attribute "Fulltext"',
        Attribute => 'Fulltext',
        Expected  => undef
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


## prepare test general catalog items ##
my $SearchValue1 = 'Unit::Test::Type';
my $SearchValue2 = 'Unit';
my $SearchValue3 = 'Baa';

# first item
my $ItemID1     = $Kernel::OM->Get('GeneralCatalog')->ItemAdd(
    Class   => 'Unit::Test::Type',
    Name    => 'Foo',
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $ItemID1,
    'Created first item'
);
# second item
my $ItemID2 = $Kernel::OM->Get('GeneralCatalog')->ItemAdd(
    Class   => 'Unit::Test::Type',
    Name    => 'Baa',
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $ItemID2,
    'Created second item'
);
# third item
my $ItemID3 = $Kernel::OM->Get('GeneralCatalog')->ItemAdd(
    Class   => 'Unit::Test::Test',
    Name    => 'Baa',
    ValidID => 1,
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

# test Search
my @IntegrationSearchTests = (
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value substr(\$SearchValue1,-10)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => substr($SearchValue1,-10)
                }
            ]
        },
        Expected => [$ItemID1,$ItemID2]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value \$SearchValue1",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => $SearchValue1
                }
            ]
        },
        Expected => [$ItemID1,$ItemID2]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value substr(\$SearchValue2,1,-1)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => substr($SearchValue2,1,-1)
                },
                {
                    Field    => 'Class',
                    Operator => 'IN',
                    Value    => ['Unit::Test::Type','Unit::Test::Test']
                }
            ]
        },
        Expected => [$ItemID1,$ItemID2,$ItemID3]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value \$SearchValue2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => $SearchValue2
                }
            ]
        },
        Expected => [$ItemID1,$ItemID2,$ItemID3]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value substr(\$SearchValue3,0,12)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => substr($SearchValue3,0,12)
                }
            ]
        },
        Expected => [$ItemID2,$ItemID3]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value substr(\$SearchValue3,-12)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => substr($SearchValue3,-12)
                }
            ]
        },
        Expected => [$ItemID2,$ItemID3]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value \$SearchValue3",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => $SearchValue3
                }
            ]
        },
        Expected => [$ItemID2,$ItemID3]
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
# attributes of this backend are not sortable

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
