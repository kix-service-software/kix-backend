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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Article::Fulltext';

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

### ToDo: Needs to be adjusted because the behavior has changed again.
# # check Search
# my @SearchTests = (
#     {
#         Name         => 'Search: undef search',
#         Search       => undef,
#         Expected     => undef
#     },
#     {
#         Name         => 'Search: Value undef',
#         Search       => {
#             Field    => 'Fulltext',
#             Operator => 'STARTSWITH',
#             Value    => undef

#         },
#         Expected     => undef
#     },
#     {
#         Name         => 'Search: Field undef',
#         Search       => {
#             Field    => undef,
#             Operator => 'STARTSWITH',
#             Value    => 'Test'
#         },
#         Expected     => undef
#     },
#     {
#         Name         => 'Search: Field invalid',
#         Search       => {
#             Field    => 'Test',
#             Operator => 'STARTSWITH',
#             Value    => 'Test'
#         },
#         Expected     => undef
#     },
#     {
#         Name         => 'Search: Operator undef',
#         Search       => {
#             Field    => 'Fulltext',
#             Operator => undef,
#             Value    => 'Test'
#         },
#         Expected     => undef
#     },
#     {
#         Name         => 'Search: Operator invalid',
#         Search       => {
#             Field    => 'Fulltext',
#             Operator => 'Test',
#             Value    => 'Test'
#         },
#         Expected     => undef
#     },
#     {
#         Name         => 'Search: valid search / Field Fulltext / Operator STARTSWITH',
#         Search       => {
#             Field    => 'Fulltext',
#             Operator => 'STARTSWITH',
#             Value    => 'Test'
#         },
#         Expected     => {
#             'Where' => [
#                 '(((LOWER(a.a_from) LIKE LOWER(\'Test%\')  OR LOWER(a.a_to) LIKE LOWER(\'Test%\')  OR LOWER(a.a_cc) LIKE LOWER(\'Test%\')  OR LOWER(a.a_subject) LIKE LOWER(\'Test%\')  OR LOWER(a.a_body) LIKE LOWER(\'Test%\') ) ))'
#             ]
#         }
#     },
#     {
#         Name         => 'Search: valid search / Field Fulltext / Operator STARTSWITH / with special inline operators',
#         Search       => {
#             Field    => 'Fulltext',
#             Operator => 'STARTSWITH',
#             Value    => 'Test+Foo|Baa'
#         },
#         Expected     => {
#             'Where' => [
#                 '(((LOWER(a.a_from) LIKE LOWER(\'Test%\')  OR LOWER(a.a_to) LIKE LOWER(\'Test%\')  OR LOWER(a.a_cc) LIKE LOWER(\'Test%\')  OR LOWER(a.a_subject) LIKE LOWER(\'Test%\')  OR LOWER(a.a_body) LIKE LOWER(\'Test%\') )  AND (LOWER(a.a_from) LIKE LOWER(\'Foo%\')  OR LOWER(a.a_to) LIKE LOWER(\'Foo%\')  OR LOWER(a.a_cc) LIKE LOWER(\'Foo%\')  OR LOWER(a.a_subject) LIKE LOWER(\'Foo%\')  OR LOWER(a.a_body) LIKE LOWER(\'Foo%\') ) ) OR ((LOWER(a.a_from) LIKE LOWER(\'Baa%\')  OR LOWER(a.a_to) LIKE LOWER(\'Baa%\')  OR LOWER(a.a_cc) LIKE LOWER(\'Baa%\')  OR LOWER(a.a_subject) LIKE LOWER(\'Baa%\')  OR LOWER(a.a_body) LIKE LOWER(\'Baa%\') ) ))'
#             ]
#         }
#     },
#     {
#         Name         => 'Search: valid search / Field Fulltext / Operator ENDSWITH',
#         Search       => {
#             Field    => 'Fulltext',
#             Operator => 'ENDSWITH',
#             Value    => 'Test'
#         },
#         Expected     => {
#             'Where' => [
#                 '(((LOWER(a.a_from) LIKE LOWER(\'%Test\')  OR LOWER(a.a_to) LIKE LOWER(\'%Test\')  OR LOWER(a.a_cc) LIKE LOWER(\'%Test\')  OR LOWER(a.a_subject) LIKE LOWER(\'%Test\')  OR LOWER(a.a_body) LIKE LOWER(\'%Test\') ) ))'
#             ]
#         }
#     },
#     {
#         Name         => 'Search: valid search / Field Fulltext / Operator ENDSWITH / with special inline operators',
#         Search       => {
#             Field    => 'Fulltext',
#             Operator => 'ENDSWITH',
#             Value    => 'Test+Foo|Baa'
#         },
#         Expected     => {
#             'Where' => [
#                 '(((LOWER(a.a_from) LIKE LOWER(\'%Test\')  OR LOWER(a.a_to) LIKE LOWER(\'%Test\')  OR LOWER(a.a_cc) LIKE LOWER(\'%Test\')  OR LOWER(a.a_subject) LIKE LOWER(\'%Test\')  OR LOWER(a.a_body) LIKE LOWER(\'%Test\') )  AND (LOWER(a.a_from) LIKE LOWER(\'%Foo\')  OR LOWER(a.a_to) LIKE LOWER(\'%Foo\')  OR LOWER(a.a_cc) LIKE LOWER(\'%Foo\')  OR LOWER(a.a_subject) LIKE LOWER(\'%Foo\')  OR LOWER(a.a_body) LIKE LOWER(\'%Foo\') ) ) OR ((LOWER(a.a_from) LIKE LOWER(\'%Baa\')  OR LOWER(a.a_to) LIKE LOWER(\'%Baa\')  OR LOWER(a.a_cc) LIKE LOWER(\'%Baa\')  OR LOWER(a.a_subject) LIKE LOWER(\'%Baa\')  OR LOWER(a.a_body) LIKE LOWER(\'%Baa\') ) ))'
#             ]
#         }
#     },
#     {
#         Name         => 'Search: valid search / Field Fulltext / Operator CONTAINS',
#         Search       => {
#             Field    => 'Fulltext',
#             Operator => 'CONTAINS',
#             Value    => 'Test'
#         },
#         Expected     => {
#             'Where' => [
#                 '(((LOWER(a.a_from) LIKE LOWER(\'%Test%\')  OR LOWER(a.a_to) LIKE LOWER(\'%Test%\')  OR LOWER(a.a_cc) LIKE LOWER(\'%Test%\')  OR LOWER(a.a_subject) LIKE LOWER(\'%Test%\')  OR LOWER(a.a_body) LIKE LOWER(\'%Test%\') ) ))'
#             ]
#         }
#     },
#     {
#         Name         => 'Search: valid search / Field Fulltext / Operator CONTAINS / with special inline operators',
#         Search       => {
#             Field    => 'Fulltext',
#             Operator => 'CONTAINS',
#             Value    => 'Test+Foo|Baa'
#         },
#         Expected     => {
#             'Where' => [
#                 '(((LOWER(a.a_from) LIKE LOWER(\'%Test%\')  OR LOWER(a.a_to) LIKE LOWER(\'%Test%\')  OR LOWER(a.a_cc) LIKE LOWER(\'%Test%\')  OR LOWER(a.a_subject) LIKE LOWER(\'%Test%\')  OR LOWER(a.a_body) LIKE LOWER(\'%Test%\') )  AND (LOWER(a.a_from) LIKE LOWER(\'%Foo%\')  OR LOWER(a.a_to) LIKE LOWER(\'%Foo%\')  OR LOWER(a.a_cc) LIKE LOWER(\'%Foo%\')  OR LOWER(a.a_subject) LIKE LOWER(\'%Foo%\')  OR LOWER(a.a_body) LIKE LOWER(\'%Foo%\') ) ) OR ((LOWER(a.a_from) LIKE LOWER(\'%Baa%\')  OR LOWER(a.a_to) LIKE LOWER(\'%Baa%\')  OR LOWER(a.a_cc) LIKE LOWER(\'%Baa%\')  OR LOWER(a.a_subject) LIKE LOWER(\'%Baa%\')  OR LOWER(a.a_body) LIKE LOWER(\'%Baa%\') ) ))'
#             ]
#         }
#     },
#     {
#         Name         => 'Search: valid search / Field Fulltext / Operator LIKE',
#         Search       => {
#             Field    => 'Fulltext',
#             Operator => 'LIKE',
#             Value    => '* Te*t'
#         },
#         Expected     => {
#             'Where' => [
#                 '(((LOWER(a.a_from) LIKE LOWER(\'% Te%t\')  OR LOWER(a.a_to) LIKE LOWER(\'% Te%t\')  OR LOWER(a.a_cc) LIKE LOWER(\'% Te%t\')  OR LOWER(a.a_subject) LIKE LOWER(\'% Te%t\')  OR LOWER(a.a_body) LIKE LOWER(\'% Te%t\') ) ))'
#             ]
#         }
#     },
#     {
#         Name         => 'Search: valid search / Field Fulltext / Operator LIKE / with special inline operators',
#         Search       => {
#             Field    => 'Fulltext',
#             Operator => 'LIKE',
#             Value    => 'Test+F*o|Baa*'
#         },
#         Expected     => {
#             'Where' => [
#                 '(((LOWER(a.a_from) = LOWER(\'Test\') OR LOWER(a.a_to) = LOWER(\'Test\') OR LOWER(a.a_cc) = LOWER(\'Test\') OR LOWER(a.a_subject) = LOWER(\'Test\') OR LOWER(a.a_body) = LOWER(\'Test\'))  AND (LOWER(a.a_from) LIKE LOWER(\'F%o\')  OR LOWER(a.a_to) LIKE LOWER(\'F%o\')  OR LOWER(a.a_cc) LIKE LOWER(\'F%o\')  OR LOWER(a.a_subject) LIKE LOWER(\'F%o\')  OR LOWER(a.a_body) LIKE LOWER(\'F%o\') ) ) OR ((LOWER(a.a_from) LIKE LOWER(\'Baa%\')  OR LOWER(a.a_to) LIKE LOWER(\'Baa%\')  OR LOWER(a.a_cc) LIKE LOWER(\'Baa%\')  OR LOWER(a.a_subject) LIKE LOWER(\'Baa%\')  OR LOWER(a.a_body) LIKE LOWER(\'Baa%\') ) ))'
#             ]
#         }
#     },
# );
# for my $Test ( @SearchTests ) {
#     my $Result = $AttributeObject->Search(
#         Search       => $Test->{Search},
#         BoolOperator => 'AND',
#         UserID       => 1,
#         Silent       => defined( $Test->{Expected} ) ? 0 : 1
#     );
#     $Self->IsDeeply(
#         $Result,
#         $Test->{Expected},
#         $Test->{Name}
#     );
# }

# # check Sort
# my @SortTests = (
#     {
#         Name      => 'Sort: Attribute undef',
#         Attribute => undef,
#         Expected  => undef
#     },
#     {
#         Name      => 'Sort: Attribute invalid',
#         Attribute => 'Test',
#         Expected  => undef
#     },
#     {
#         Name      => 'Sort: Attribute "Fulltext"',
#         Attribute => 'Fulltext',
#         Expected  => undef
#     }
# );
# for my $Test ( @SortTests ) {
#     my $Result = $AttributeObject->Sort(
#         Attribute => $Test->{Attribute},
#         Language  => 'en',
#         Silent    => defined( $Test->{Expected} ) ? 0 : 1
#     );
#     $Self->IsDeeply(
#         $Result,
#         $Test->{Expected},
#         $Test->{Name}
#     );
# }


# ### Integration Test ###
# # discard current object search object
# $Kernel::OM->ObjectsDiscard(
#     Objects => ['ObjectSearch'],
# );

# # make sure config 'ObjectSearch::Backend' is set to Module 'ObjectSearch::Database'
# $Kernel::OM->Get('Config')->Set(
#     Key   => 'ObjectSearch::Backend',
#     Value => {
#         Module => 'ObjectSearch::Database',
#     }
# );

# # get objectsearch object
# my $ObjectSearch = $Kernel::OM->Get('ObjectSearch');

# # begin transaction on database
# $Helper->BeginWork();

# ## prepare test tickets ##
# # first ticket
# my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
#     Title          => $Helper->GetRandomID(),
#     QueueID        => 1,
#     Lock           => 'unlock',
#     PriorityID     => 1,
#     StateID        => 1,
#     TypeID         => 1,
#     OrganisationID => 1,
#     ContactID      => 1,
#     OwnerID        => 1,
#     ResponsibleID  => 1,
#     UserID         => 1
# );
# $Self->True(
#     $TicketID,
#     'Created ticket'
# );
# my $ArticleID1 = $Kernel::OM->Get('Ticket')->ArticleCreate(
#     TicketID        => $TicketID,
#     ChannelID       => $Kernel::OM->Get('Channel')->ChannelLookup( Name => 'note' ),
#     SenderTypeID    => $Kernel::OM->Get('Ticket')->ArticleSenderTypeLookup( SenderType => 'agent' ),
#     From            => '"Agent" <agent@kixdesk.com>',
#     To              => '"Customer" <customer@external.com>',
#     Cc              => '"External" <external@external.com>',
#     Subject         => 'Foo',
#     Body            => 'Baa',
#     ContentType     => 'text/plain; charset=utf-8',
#     HistoryType     => 'AddNote',
#     HistoryComment  => 'UnitTest',
#     CustomerVisible => 0,
#     UserID          => 1
# );
# $Self->True(
#     $ArticleID1,
#     'Created first article for ticket'
# );
# $Helper->FixedTimeAddSeconds(60);
# my $ArticleID2 = $Kernel::OM->Get('Ticket')->ArticleCreate(
#     TicketID        => $TicketID,
#     ChannelID       => $Kernel::OM->Get('Channel')->ChannelLookup( Name => 'note' ),
#     SenderTypeID    => $Kernel::OM->Get('Ticket')->ArticleSenderTypeLookup( SenderType => 'external' ),
#     From            => '"Customer" <customer@external.com>',
#     To              => '"Agent" <agent@kixdesk.com>',
#     Cc              => '"External" <external@external.com>',
#     Subject         => 'Foo',
#     Body            => 'Unit Test',
#     ContentType     => 'text/plain; charset=utf-8',
#     HistoryType     => 'AddNote',
#     HistoryComment  => 'UnitTest',
#     CustomerVisible => 0,
#     UserID          => 1
# );
# $Self->True(
#     $ArticleID2,
#     'Created second article for ticket'
# );

# # test Search
# my @IntegrationSearchTests = (
#     {
#         Name     => "Search: Field Fulltext / Operator STARTSWITH / Value 'Test'",
#         Search   => {
#             'AND' => [
#                 {
#                     Field    => 'Fulltext',
#                     Operator => 'STARTSWITH',
#                     Value    => 'Test'
#                 }
#             ]
#         },
#         Expected => [ ]
#     },
#     {
#         Name     => "Search: Field Fulltext / Operator STARTSWITH / Value substr('Unit Test',0,4)",
#         Search   => {
#             'AND' => [
#                 {
#                     Field    => 'Fulltext',
#                     Operator => 'STARTSWITH',
#                     Value    => substr('Unit Test',0,4)
#                 }
#             ]
#         },
#         Expected => [ $ArticleID2 ]
#     },
#     {
#         Name     => "Search: Field Fulltext / Operator ENDSWITH / Value 'Baa'",
#         Search   => {
#             'AND' => [
#                 {
#                     Field    => 'Fulltext',
#                     Operator => 'ENDSWITH',
#                     Value    => 'Baa'
#                 }
#             ]
#         },
#         Expected => [ $ArticleID1 ]
#     },
#     {
#         Name     => "Search: Field Fulltext / Operator ENDSWITH / Value substr('Unit Test',-5)",
#         Search   => {
#             'AND' => [
#                 {
#                     Field    => 'Fulltext',
#                     Operator => 'ENDSWITH',
#                     Value    => substr('Unit Test',-5)
#                 }
#             ]
#         },
#         Expected => [ $ArticleID2 ]
#     },
#     {
#         Name     => "Search: Field Fulltext / Operator CONTAINS / Value 'Test'",
#         Search   => {
#             'AND' => [
#                 {
#                     Field    => 'Fulltext',
#                     Operator => 'CONTAINS',
#                     Value    => 'Test'
#                 }
#             ]
#         },
#         Expected => [ $ArticleID2 ]
#     },
#     {
#         Name     => "Search: Field Fulltext / Operator CONTAINS / Value substr('Unit Test,2,-2)",
#         Search   => {
#             'AND' => [
#                 {
#                     Field    => 'Fulltext',
#                     Operator => 'CONTAINS',
#                     Value    => substr('Unit Test',2,-2)
#                 }
#             ]
#         },
#         Expected => [ $ArticleID2 ]
#     },
#     {
#         Name     => "Search: Field Fulltext / Operator LIKE / Value 'Test'",
#         Search   => {
#             'AND' => [
#                 {
#                     Field    => 'Fulltext',
#                     Operator => 'LIKE',
#                     Value    => 'Foo'
#                 }
#             ]
#         },
#         Expected => [ $ArticleID1, $ArticleID2 ]
#     },
#     {
#         Name     => "Search: Field Fulltext / Operator LIKE / Value 'Foo|Unit*'",
#         Search   => {
#             'AND' => [
#                 {
#                     Field    => 'Fulltext',
#                     Operator => 'LIKE',
#                     Value    => 'Foo|Unit*'
#                 }
#             ]
#         },
#         Expected => [$ArticleID1,$ArticleID2]
#     }
# );

# for my $Test ( @IntegrationSearchTests ) {
#     my %Search = %{$Test->{Search}};
#     $Search{AND} //= [];
#     push @{$Search{AND}}, { Field => 'TicketID', Operator => 'EQ', Value => $TicketID };

#     my @Result = $ObjectSearch->Search(
#         ObjectType => 'Article',
#         Result     => 'ARRAY',
#         Search     => \%Search,
#         UserType   => 'Agent',
#         UserID     => 1
#     );
#     $Self->IsDeeply(
#         \@Result,
#         $Test->{Expected},
#         $Test->{Name}
#     );
# }
#
# # rollback transaction on database
# $Helper->Rollback();

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
