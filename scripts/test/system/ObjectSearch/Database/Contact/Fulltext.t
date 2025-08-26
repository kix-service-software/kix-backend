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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Contact::Fulltext';

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
for my $Method ( qw(GetSupportedAttributes FulltextSearch) ) {
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
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 0,
            Operators      => ['LIKE']
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

# check FulltextSearch
my @FulltextSearchTests = (
    {
        Name         => 'FulltextSearch: Search undef / Columns undef',
        Search       => undef,
        Columns      => undef,
        Expected     => undef
    },
    {
        Name         => 'FulltextSearch: Search->Value undef / Columns valid',
        Search       => {
            Field    => 'Fulltext',
            Operator => 'LIKE',
            Value    => undef

        },
        Columns      => ['Title','Subject'],
        Expected     => undef
    },
    {
        Name         => 'FulltextSearch: Search->Field undef / Columns valid',
        Search       => {
            Field    => undef,
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Columns      => ['Title','Subject'],
        Expected     => undef
    },
    {
        Name         => 'FulltextSearch: Search->Field invalid / Columns valid',
        Search       => {
            Field    => 'Test',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Columns      => ['Title','Subject'],
        Expected     => undef
    },
    {
        Name         => 'FulltextSearch: Search->Operator undef / Columns valid',
        Search       => {
            Field    => 'Fulltext',
            Operator => undef,
            Value    => 'Test'
        },
        Columns      => ['Title','Subject'],
        Expected     => undef
    },
    {
        Name         => 'FulltextSearch: Search->Operator invalid / Columns valid',
        Search       => {
            Field    => 'Fulltext',
            Operator => 'Test',
            Value    => 'Test'
        },
        Columns      => ['Title','Subject'],
        Expected     => undef
    },
    {
        Name         => 'FulltextSearch: Search valid / Columns undef',
        Search       => {
            Field    => 'Fulltext',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Columns      => undef,
        Expected     => undef
    },
    {
        Name         => 'FulltextSearch: Search valid / Columns invalid',
        Search       => {
            Field    => 'Fulltext',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Columns      => 'Test',
        Expected     => undef
    },
    {
        Name         => 'FulltextSearch: valid search / Field Fulltext / Operator LIKE',
        Search       => {
            Field    => 'Fulltext',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Columns      => ['Test'],
        Expected     => {
            'Join' => undef,
            'Where' => [
                $CaseSensitive ? '(LOWER(Test) LIKE \'%test%\' ESCAPE \'' . $Escape . '\') ' : '(Test LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
            ]
        }
    }
);
for my $Test ( @FulltextSearchTests ) {
    my $Result = $AttributeObject->FulltextSearch(
        Search       => $Test->{Search},
        Columns      => $Test->{Columns},
        BoolOperator => 'AND',
        UserID       => 1,
        UserType     => 'Agent',
        Silent       => defined( $Test->{Expected} ) ? 0 : 1
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
my $TestData1 = '123456789';
my $TestData2 = 'unittest|subtests';
my $TestData3 = '846+23456|Mustermann';
my $TestData4 = '"108 34567 18"';

# first contact
my $ContactID1 = $Kernel::OM->Get('Contact')->ContactAdd(
    Firstname             => 'Huber',
    Lastname              => 'Manfred',
    Email                 => 'hubert.manfred@unittest.com',
    Phone                 => '123456789',
    Fax                   => '123456789',
    Mobile                => '123456789',
    Street                => 'Somestreet 123',
    Zip                   => '12345',
    City                  => 'Somewhere',
    Country               => 'Somecountry',
    Comment               => 'some comment',
    ValidID               => 1,
    UserID                => 1
);
$Self->True(
    $ContactID1,
    'Created first contact'
);

# second contact
my $ContactID2 = $Kernel::OM->Get('Contact')->ContactAdd(
    Firstname             => 'Max',
    Lastname              => 'Mustermann',
    Email                 => 'max.mustermann@unittest.com',
    Phone                 => '21569818864',
    Street                => 'Some alle 123',
    Zip                   => '23456',
    City                  => 'musterstadt',
    Country               => 'musterland',
    Comment               => 'Some comment',
    ValidID               => 1,
    UserID                => 1
);
$Self->True(
    $ContactID1,
    'Created second contact'
);

# third contact
my $ContactID3 = $Kernel::OM->Get('Contact')->ContactAdd(
    Firstname             => 'Ablert',
    Lastname              => 'Round',
    Email                 => 'albert.round@subtests.com',
    Phone                 => '846 23456 3',
    Fax                   => '578 7849',
    Mobile                => '108 34567 18',
    Zip                   => '02687',
    City                  => 'Somewhere',
    Country               => 'Somecountry',
    Comment               => 'some comment',
    ValidID               => 1,
    UserID                => 1
);
$Self->True(
    $ContactID1,
    'Created third contact'
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Contact'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value substr(\$TestData1,2,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => substr($TestData1,2,-2)
                }
            ]
        },
        Expected => [$ContactID1,$ContactID3]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value \$TestData1",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => $TestData1
                }
            ]
        },
        Expected => [$ContactID1]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value \$TestData2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$ContactID1,$ContactID2,$ContactID3]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value \$TestData3",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => $TestData3
                }
            ]
        },
        Expected => [$ContactID2,$ContactID3]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value \$TestData4",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => $TestData4
                }
            ]
        },
        Expected => [$ContactID3]
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
