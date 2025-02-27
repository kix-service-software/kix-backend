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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::FAQArticle::Assigned';

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
        AssignedContact => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ'],
            ValueType    => 'NUMERIC'
        },
    },
    'GetSupportedAttributes provides expected data'
);

# begin transaction on database
$Helper->BeginWork();

# create customer user
my $CustomerContactID = $Helper->TestContactCreate();
$Self->True(
    $CustomerContactID,
    'TestContactCreate',
);
my %CustomerContact = $Kernel::OM->Get('Contact')->ContactGet(
    ID     => $CustomerContactID,
    UserID => 1
);
my $AdditionalOrganisationID = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => $Helper->GetRandomID(),
    Name    => $Helper->GetRandomID(),
    UserID  => 1
);
$Self->True(
    $AdditionalOrganisationID,
    'Created additional organisation'
);
my $ContactUpdateSuccess = $Kernel::OM->Get('Contact')->ContactUpdate(
    %CustomerContact,
    ID              => $CustomerContactID,
    OrganisationIDs => [
        $CustomerContact{PrimaryOrganisationID},
        $AdditionalOrganisationID
    ],
    UserID          => 1
);
$Self->True(
    $ContactUpdateSuccess,
    'Added additional organisation to contact'
);

## prepare test faq articles ##
# first faq article
my $FAQArticleID1 = $Kernel::OM->Get('FAQ')->FAQAdd(
    Title       => $Helper->GetRandomID(),
    CategoryID  => 1,
    Visibility  => 'external',
    Language    => 'en',
    ValidID     => 1,
    ContentType => 'text/plain',
    UserID      => $CustomerContact{AssignedUserID},
    Field3      => 'Baa',
    Field6      => 'some Text',
);
$Self->True(
    $FAQArticleID1,
    'Created first faq article'
);
# second faq article
my $FAQArticleID2 = $Kernel::OM->Get('FAQ')->FAQAdd(
    Title       => $Helper->GetRandomID(),
    CategoryID  => 1,
    Visibility  => 'internal',
    Language    => 'en',
    ValidID     => 1,
    ContentType => 'text/plain',
    UserID      => $CustomerContact{AssignedUserID},
    Field1      => 'Baa',
    Field5      => 'Foo',
    Field4      => 'Unit Test',
);
$Self->True(
    $FAQArticleID1,
    'Created second faq article'
);
# third faq article
my $FAQArticleID3 = $Kernel::OM->Get('FAQ')->FAQAdd(
    Title       => $Helper->GetRandomID(),
    CategoryID  => 1,
    Visibility  => 'public',
    Language    => 'en',
    ValidID     => 1,
    ContentType => 'text/plain',
    UserID      => $CustomerContact{AssignedUserID},
    Field1      => 'Test',
    Field3      => 'Baa',
    Field4      => 'Unit Test',
);
$Self->True(
    $FAQArticleID1,
    'Created third faq article'
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
            Field    => 'AssignedContact',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'AssignedContact',
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
            Field    => 'AssignedContact',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'AssignedContact',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field AssignedContact / Operator EQ ',
        Search       => {
            Field    => 'AssignedContact',
            Operator => 'EQ',
            Value    => $CustomerContact{ID}
        },
        Expected     => {
            'Where' => [
                "f.id IN ($FAQArticleID1,$FAQArticleID3)"
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
        Name      => 'Sort: Attribute "AssignedContact"',
        Attribute => 'AssignedContact',
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

# test Search
my @IntegrationSearchTests = (
    {
        Name     => "Search: Field AssignedContact / Operator EQ / Value \$CustomerContact{ID} (with faq articles)",
        Search   => {
            'AND' => [
                {
                    Field    => 'AssignedContact',
                    Operator => 'EQ',
                    Value    => $CustomerContact{ID}
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID3]
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'FAQArticle',
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
