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
            Operators    => ['STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        }
    },
    'GetSupportedAttributes provides expected data'
);

# Quoting ESCAPE character backslash
my $QuoteBack = $Kernel::OM->Get('DB')->{'DB::QuoteBack'};
my $Escape = "\\";
if ( $QuoteBack ) {
    $Escape =~ s/\\/$QuoteBack\\/g;
}

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
            Operator => 'STARTSWITH',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Field undef',
        Search       => {
            Field    => undef,
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Field invalid',
        Search       => {
            Field    => 'Test',
            Operator => 'STARTSWITH',
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
        Name         => 'Search: valid search / Field Fulltext / Operator STARTSWITH',
        Search       => {
            Field    => 'Fulltext',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                '(LOWER(f.f_number) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_subject) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_keywords) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field1) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field2) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field3) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field4) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field5) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field6) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\') '
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Fulltext / Operator STARTSWITH / with special inline operators',
        Search       => {
            Field    => 'Fulltext',
            Operator => 'STARTSWITH',
            Value    => 'Test+Foo|Baa'
        },
        Expected     => {
            'Where' => [
                '(LOWER(f.f_number) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_subject) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_keywords) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field1) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field2) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field3) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field4) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field5) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field6) LIKE LOWER(\'Test%\') ESCAPE \'' . $Escape . '\')  AND (LOWER(f.f_number) LIKE LOWER(\'Foo%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_subject) LIKE LOWER(\'Foo%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_keywords) LIKE LOWER(\'Foo%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field1) LIKE LOWER(\'Foo%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field2) LIKE LOWER(\'Foo%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field3) LIKE LOWER(\'Foo%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field4) LIKE LOWER(\'Foo%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field5) LIKE LOWER(\'Foo%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field6) LIKE LOWER(\'Foo%\') ESCAPE \'' . $Escape . '\')  OR (LOWER(f.f_number) LIKE LOWER(\'Baa%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_subject) LIKE LOWER(\'Baa%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_keywords) LIKE LOWER(\'Baa%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field1) LIKE LOWER(\'Baa%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field2) LIKE LOWER(\'Baa%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field3) LIKE LOWER(\'Baa%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field4) LIKE LOWER(\'Baa%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field5) LIKE LOWER(\'Baa%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field6) LIKE LOWER(\'Baa%\') ESCAPE \'' . $Escape . '\') '
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Fulltext / Operator ENDSWITH',
        Search       => {
            Field    => 'Fulltext',
            Operator => 'ENDSWITH',
            Value    => 'TEST'
        },
        Expected     => {
            'Where' => [
                '(LOWER(f.f_number) LIKE LOWER(\'%TEST\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_subject) LIKE LOWER(\'%TEST\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_keywords) LIKE LOWER(\'%TEST\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field1) LIKE LOWER(\'%TEST\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field2) LIKE LOWER(\'%TEST\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field3) LIKE LOWER(\'%TEST\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field4) LIKE LOWER(\'%TEST\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field5) LIKE LOWER(\'%TEST\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field6) LIKE LOWER(\'%TEST\') ESCAPE \'' . $Escape . '\') '
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Fulltext / Operator ENDSWITH / with special inline operators',
        Search       => {
            Field    => 'Fulltext',
            Operator => 'ENDSWITH',
            Value    => 'Test+Foo|Baa'
        },
        Expected     => {
            'Where' => [
                '(LOWER(f.f_number) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_subject) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_keywords) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field1) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field2) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field3) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field4) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field5) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field6) LIKE LOWER(\'%Test\') ESCAPE \'' . $Escape . '\')  AND (LOWER(f.f_number) LIKE LOWER(\'%Foo\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_subject) LIKE LOWER(\'%Foo\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_keywords) LIKE LOWER(\'%Foo\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field1) LIKE LOWER(\'%Foo\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field2) LIKE LOWER(\'%Foo\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field3) LIKE LOWER(\'%Foo\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field4) LIKE LOWER(\'%Foo\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field5) LIKE LOWER(\'%Foo\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field6) LIKE LOWER(\'%Foo\') ESCAPE \'' . $Escape . '\')  OR (LOWER(f.f_number) LIKE LOWER(\'%Baa\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_subject) LIKE LOWER(\'%Baa\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_keywords) LIKE LOWER(\'%Baa\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field1) LIKE LOWER(\'%Baa\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field2) LIKE LOWER(\'%Baa\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field3) LIKE LOWER(\'%Baa\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field4) LIKE LOWER(\'%Baa\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field5) LIKE LOWER(\'%Baa\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field6) LIKE LOWER(\'%Baa\') ESCAPE \'' . $Escape . '\') '
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Fulltext / Operator CONTAINS',
        Search       => {
            Field    => 'Fulltext',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                '(LOWER(f.f_number) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_subject) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_keywords) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field1) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field2) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field3) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field4) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field5) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field6) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\') '
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Fulltext / Operator CONTAINS / with special inline operators',
        Search       => {
            Field    => 'Fulltext',
            Operator => 'CONTAINS',
            Value    => 'Test+Foo|Baa'
        },
        Expected     => {
            'Where' => [
                '(LOWER(f.f_number) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_subject) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_keywords) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field1) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field2) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field3) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field4) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field5) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field6) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\')  AND (LOWER(f.f_number) LIKE LOWER(\'%Foo%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_subject) LIKE LOWER(\'%Foo%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_keywords) LIKE LOWER(\'%Foo%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field1) LIKE LOWER(\'%Foo%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field2) LIKE LOWER(\'%Foo%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field3) LIKE LOWER(\'%Foo%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field4) LIKE LOWER(\'%Foo%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field5) LIKE LOWER(\'%Foo%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field6) LIKE LOWER(\'%Foo%\') ESCAPE \'' . $Escape . '\')  OR (LOWER(f.f_number) LIKE LOWER(\'%Baa%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_subject) LIKE LOWER(\'%Baa%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_keywords) LIKE LOWER(\'%Baa%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field1) LIKE LOWER(\'%Baa%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field2) LIKE LOWER(\'%Baa%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field3) LIKE LOWER(\'%Baa%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field4) LIKE LOWER(\'%Baa%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field5) LIKE LOWER(\'%Baa%\') ESCAPE \'' . $Escape . '\' OR LOWER(f.f_field6) LIKE LOWER(\'%Baa%\') ESCAPE \'' . $Escape . '\') '
            ]
        }
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
                '(LOWER(f.f_number) = LOWER(\'Test\') OR LOWER(f.f_subject) = LOWER(\'Test\') OR LOWER(f.f_keywords) = LOWER(\'Test\') OR LOWER(f.f_field1) = LOWER(\'Test\') OR LOWER(f.f_field2) = LOWER(\'Test\') OR LOWER(f.f_field3) = LOWER(\'Test\') OR LOWER(f.f_field4) = LOWER(\'Test\') OR LOWER(f.f_field5) = LOWER(\'Test\') OR LOWER(f.f_field6) = LOWER(\'Test\')) '
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Fulltext / Operator STARTSWITH / with special inline operators',
        Search       => {
            Field    => 'Fulltext',
            Operator => 'LIKE',
            Value    => 'Test+Foo|Baa'
        },
        Expected     => {
            'Where' => [
                '(LOWER(f.f_number) = LOWER(\'Test\') OR LOWER(f.f_subject) = LOWER(\'Test\') OR LOWER(f.f_keywords) = LOWER(\'Test\') OR LOWER(f.f_field1) = LOWER(\'Test\') OR LOWER(f.f_field2) = LOWER(\'Test\') OR LOWER(f.f_field3) = LOWER(\'Test\') OR LOWER(f.f_field4) = LOWER(\'Test\') OR LOWER(f.f_field5) = LOWER(\'Test\') OR LOWER(f.f_field6) = LOWER(\'Test\'))  AND (LOWER(f.f_number) = LOWER(\'Foo\') OR LOWER(f.f_subject) = LOWER(\'Foo\') OR LOWER(f.f_keywords) = LOWER(\'Foo\') OR LOWER(f.f_field1) = LOWER(\'Foo\') OR LOWER(f.f_field2) = LOWER(\'Foo\') OR LOWER(f.f_field3) = LOWER(\'Foo\') OR LOWER(f.f_field4) = LOWER(\'Foo\') OR LOWER(f.f_field5) = LOWER(\'Foo\') OR LOWER(f.f_field6) = LOWER(\'Foo\'))  OR (LOWER(f.f_number) = LOWER(\'Baa\') OR LOWER(f.f_subject) = LOWER(\'Baa\') OR LOWER(f.f_keywords) = LOWER(\'Baa\') OR LOWER(f.f_field1) = LOWER(\'Baa\') OR LOWER(f.f_field2) = LOWER(\'Baa\') OR LOWER(f.f_field3) = LOWER(\'Baa\') OR LOWER(f.f_field4) = LOWER(\'Baa\') OR LOWER(f.f_field5) = LOWER(\'Baa\') OR LOWER(f.f_field6) = LOWER(\'Baa\')) '
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
        Name     => "Search: Field Fulltext / Operator STARTSWITH / Value 'Test'",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'STARTSWITH',
                    Value    => 'Test'
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Fulltext / Operator STARTSWITH / Value substr('Unit Test',0,4)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'STARTSWITH',
                    Value    => substr('Unit Test',0,4)
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Fulltext / Operator ENDSWITH / Value 'Baa'",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'ENDSWITH',
                    Value    => 'Baa'
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Fulltext / Operator ENDSWITH / Value substr('Unit Test',-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'ENDSWITH',
                    Value    => substr('Unit Test',-5)
                }
            ]
        },
        Expected => [$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Fulltext / Operator CONTAINS / Value 'Test'",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'CONTAINS',
                    Value    => 'Test'
                }
            ]
        },
        Expected => [$FAQArticleID1,$FAQArticleID2,$FAQArticleID3]
    },
    {
        Name     => "Search: Field Fulltext / Operator CONTAINS / Value substr('Unit Test,2,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'CONTAINS',
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
        Expected => [$FAQArticleID3]
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
