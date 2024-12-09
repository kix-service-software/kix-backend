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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Organisation::Fulltext';

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
                $CaseSensitive ? '(LOWER(o.name) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(o.number) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(o.street) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(o.city) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(o.zip) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(o.url) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(o.country) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\') ' : '(o.name LIKE \'%Test%\' ESCAPE \'' . $Escape . '\' OR o.number LIKE \'%Test%\' ESCAPE \'' . $Escape . '\' OR o.street LIKE \'%Test%\' ESCAPE \'' . $Escape . '\' OR o.city LIKE \'%Test%\' ESCAPE \'' . $Escape . '\' OR o.zip LIKE \'%Test%\' ESCAPE \'' . $Escape . '\' OR o.url LIKE \'%Test%\' ESCAPE \'' . $Escape . '\' OR o.country LIKE \'%Test%\' ESCAPE \'' . $Escape . '\') '
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

## prepare test organisation ##
my $TestData1 = 'Test001';
my $TestData2 = 'test002';
my $TestData3 = 'Test003';
my $TestData4 = 'Test004';

# first organisation
my $OrganisationID1 = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => $TestData1,
    Name    => $Helper->GetRandomID(),
    Street  => $Helper->GetRandomID(),
    Zip     => $Helper->GetRandomID(),
    City    => $Helper->GetRandomID(),
    Country => $Helper->GetRandomID(),
    Url     => $Helper->GetRandomID(),
    Comment => $Helper->GetRandomID(),
    UserID  => 1
);
$Self->True(
    $OrganisationID1,
    'Created first organisation'
);
# second organisation
my $OrganisationID2 = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => $Helper->GetRandomID(),
    Name    => $Helper->GetRandomID(),
    Street  => $TestData2,
    UserID  => 1
);
$Self->True(
    $OrganisationID2,
    'Created second organisation'
);
# third organisation
my $OrganisationID3 = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => $Helper->GetRandomID(),
    Name    => $TestData3,
    Comment => $Helper->GetRandomID(),
    UserID  => 1
);
$Self->True(
    $OrganisationID3,
    'Created third organisation'
);
# fourth organisation
my $OrganisationID4 = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => $TestData4,
    Name    => $TestData4,
    UserID  => 1
);
$Self->True(
    $OrganisationID4,
    'Created fourth organisation without optional parameter'
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Organisation'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field Fulltext / Operator LIKE / Value substr($TestData2,0,4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => substr($TestData2,0,4)
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3,$OrganisationID4]
    },
    {
        Name     => 'Search: Field Fulltext / Operator LIKE / Value substr($TestData2,-5)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => substr($TestData2,-5)
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Fulltext / Operator LIKE / Value substr($TestData2,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => substr($TestData2,2,-2)
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3,$OrganisationID4]
    },
    {
        Name     => 'Search: Field Fulltext / Operator LIKE / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Organisation',
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
