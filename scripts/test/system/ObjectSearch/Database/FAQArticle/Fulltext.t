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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::FAQArticle::Fulltext';

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
            Field    => 'Fulltext',
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
            Field    => 'Fulltext',
            Operator => undef,
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'Fulltext',
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
                $CaseSensitive ? '(LOWER(f.f_number) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_subject) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_keywords) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field1) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field2) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field3) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field4) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field5) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field6) LIKE \'%test%\' ESCAPE \'' . $Escape . '\') ' : '(f.f_number LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR f.f_subject LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR f.f_keywords LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR f.f_field1 LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR f.f_field2 LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR f.f_field3 LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR f.f_field4 LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR f.f_field5 LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR f.f_field6 LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Fulltext / Operator LIKE / with special inline operators',
        Search       => {
            Field    => 'Fulltext',
            Operator => 'LIKE',
            Value    => 'Test+Foo|Baa'
        },
        Expected     => {
            'Where' => [
                $CaseSensitive ? '(LOWER(f.f_number) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_subject) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_keywords) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field1) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field2) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field3) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field4) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field5) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field6) LIKE \'%test%\' ESCAPE \'' . $Escape . '\')  AND (LOWER(f.f_number) LIKE \'%foo%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_subject) LIKE \'%foo%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_keywords) LIKE \'%foo%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field1) LIKE \'%foo%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field2) LIKE \'%foo%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field3) LIKE \'%foo%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field4) LIKE \'%foo%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field5) LIKE \'%foo%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field6) LIKE \'%foo%\' ESCAPE \'' . $Escape . '\')  OR (LOWER(f.f_number) LIKE \'%baa%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_subject) LIKE \'%baa%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_keywords) LIKE \'%baa%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field1) LIKE \'%baa%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field2) LIKE \'%baa%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field3) LIKE \'%baa%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field4) LIKE \'%baa%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field5) LIKE \'%baa%\' ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field6) LIKE \'%baa%\' ESCAPE \'' . $Escape . '\') ' : '(f.f_number LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR f.f_subject LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR f.f_keywords LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR f.f_field1 LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR f.f_field2 LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR f.f_field3 LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR f.f_field4 LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR f.f_field5 LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR f.f_field6 LIKE \'%test%\' ESCAPE \'' . $Escape . '\')  AND (f.f_number LIKE \'%foo%\' ESCAPE \'' . $Escape . '\' OR f.f_subject LIKE \'%foo%\' ESCAPE \'' . $Escape . '\' OR f.f_keywords LIKE \'%foo%\' ESCAPE \'' . $Escape . '\' OR f.f_field1 LIKE \'%foo%\' ESCAPE \'' . $Escape . '\' OR f.f_field2 LIKE \'%foo%\' ESCAPE \'' . $Escape . '\' OR f.f_field3 LIKE \'%foo%\' ESCAPE \'' . $Escape . '\' OR f.f_field4 LIKE \'%foo%\' ESCAPE \'' . $Escape . '\' OR f.f_field5 LIKE \'%foo%\' ESCAPE \'' . $Escape . '\' OR f.f_field6 LIKE \'%foo%\' ESCAPE \'' . $Escape . '\')  OR (f.f_number LIKE \'%baa%\' ESCAPE \'' . $Escape . '\' OR f.f_subject LIKE \'%baa%\' ESCAPE \'' . $Escape . '\' OR f.f_keywords LIKE \'%baa%\' ESCAPE \'' . $Escape . '\' OR f.f_field1 LIKE \'%baa%\' ESCAPE \'' . $Escape . '\' OR f.f_field2 LIKE \'%baa%\' ESCAPE \'' . $Escape . '\' OR f.f_field3 LIKE \'%baa%\' ESCAPE \'' . $Escape . '\' OR f.f_field4 LIKE \'%baa%\' ESCAPE \'' . $Escape . '\' OR f.f_field5 LIKE \'%baa%\' ESCAPE \'' . $Escape . '\' OR f.f_field6 LIKE \'%baa%\' ESCAPE \'' . $Escape . '\') '
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

## prepare test faq articles ##
# first faq article
my $FAQArticleID1 = $Kernel::OM->Get('FAQ')->FAQAdd(
    Title       => $Helper->GetRandomID(),
    CategoryID  => 1,
    Visibility  => 'external',
    Language    => 'en',
    ValidID     => 1,
    ContentType => 'text/plain',
    UserID      => 1,
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
    UserID      => 1,
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
    UserID      => 1,
    Field1      => 'Test',
    Field3      => 'Baa',
    Field4      => 'Unit Test',
);
$Self->True(
    $FAQArticleID1,
    'Created third faq article'
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value substr('Unit Test',0,4)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => substr('Unit Test',0,4)
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value substr('Unit Test',-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => substr('Unit Test',-5)
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value substr('Unit Test,2,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => substr('Unit Test',2,-2)
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value 'Test'",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => 'Test'
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value 'Foo|Unit*'",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => 'Foo|Unit*'
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID3]
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
