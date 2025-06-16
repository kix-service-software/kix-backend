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

$Self->True(
    0,
    'ToDo: Needs to be rewritten because the functionality of the full text has changed.'
);

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
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Field invalid',
        Search       => {
            Field    => 'Test',
            Operator => 'EQ',
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
            'Join' => [
                'LEFT JOIN users u0 ON c.user_id = u0.id',
                'LEFT JOIN contact_organisation co0 ON c.id = co0.contact_id',
                'LEFT JOIN organisation o0 ON o0.id = co0.org_id'
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(c.firstname) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(c.lastname) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(c.email) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(c.email1) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(c.email2) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(c.email3) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(c.email4) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(c.email5) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(c.title) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(c.phone) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(c.fax) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(c.mobile) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(c.street) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(c.city) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(c.zip) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(c.country) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(u0.login) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(o0.number) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(o0.name) LIKE \'%test%\' ESCAPE \'' . $Escape . '\') ' : '(c.firstname LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR c.lastname LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR c.email LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR c.email1 LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR c.email2 LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR c.email3 LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR c.email4 LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR c.email5 LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR c.title LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR c.phone LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR c.fax LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR c.mobile LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR c.street LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR c.city LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR c.zip LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR c.country LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR u0.login LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR o0.number LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR o0.name LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
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

## prepare test contact ##
my $TestData1 = 'Somewhere';
my $TestData2 = 'unittest|Somecountry';
my $TestData3 = '02687+23456|musterstadt';

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
    Phone                 => '846 84 218 3',
    Fax                   => '108 60615 18',
    Mobile                => '578 7849',
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
        Expected => [$ContactID1,$ContactID3]
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
        Expected => [$ContactID2]
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
