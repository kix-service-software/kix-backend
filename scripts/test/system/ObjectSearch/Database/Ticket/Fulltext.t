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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Ticket::Fulltext';

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

# check if database is casesensitive
my $CaseSensitive = $Kernel::OM->Get('DB')->GetDatabaseFunction('CaseSensitive');

# set config 'Ticket::SearchIndexModule' to 'StaticDB' to check sql preparation
$Kernel::OM->Get('Config')->Set(
    Key   => 'Ticket::SearchIndexModule',
    Value => 'Kernel::System::Ticket::ArticleSearchIndex::StaticDB'
);

# check Search
my @SearchTests = (
    {
        Name         => 'Search/StaticDB: undef search',
        Search       => undef,
        Expected     => undef
    },
    {
        Name         => 'Search/StaticDB: Value undef',
        Search       => {
            Field    => 'Fulltext',
            Operator => 'LIKE',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search/StaticDB: Field undef',
        Search       => {
            Field    => undef,
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search/StaticDB: Field invalid',
        Search       => {
            Field    => 'Test',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search/StaticDB: Operator undef',
        Search       => {
            Field    => 'Fulltext',
            Operator => undef,
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search/StaticDB: Operator invalid',
        Search       => {
            Field    => 'Fulltext',
            Operator => 'Test',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search/StaticDB: valid search / Field Fulltext / Operator LIKE',
        Search       => {
            Field    => 'Fulltext',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id'
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(st.tn) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(st.title) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR s_ta.a_to LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR s_ta.a_cc LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR s_ta.a_from LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR s_ta.a_body LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR s_ta.a_subject LIKE \'%test%\' ESCAPE \'' . $Escape . '\') ' : '(st.tn LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR st.title LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR s_ta.a_to LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR s_ta.a_cc LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR s_ta.a_from LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR s_ta.a_body LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR s_ta.a_subject LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
            ]
        }
    }
);
for my $Test ( @SearchTests ) {
    my $Result = $AttributeObject->Search(
        Search       => $Test->{Search},
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

# set config 'Ticket::SearchIndexModule' to 'RuntimeDB' to check sql preparation
$Kernel::OM->Get('Config')->Set(
    Key   => 'Ticket::SearchIndexModule',
    Value => 'Kernel::System::Ticket::ArticleSearchIndex::RuntimeDB'
);

# check Search
@SearchTests = (
    {
        Name         => 'Search/RuntimeDB: undef search',
        Search       => undef,
        Expected     => undef
    },
    {
        Name         => 'Search/RuntimeDB: Value undef',
        Search       => {
            Field    => 'Fulltext',
            Operator => 'LIKE',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search/RuntimeDB: Field undef',
        Search       => {
            Field    => undef,
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search/RuntimeDB: Field invalid',
        Search       => {
            Field    => 'Test',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search/RuntimeDB: Operator undef',
        Search       => {
            Field    => 'Fulltext',
            Operator => undef,
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search/RuntimeDB: Operator invalid',
        Search       => {
            Field    => 'Fulltext',
            Operator => 'Test',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search/RuntimeDB: valid search / Field Fulltext / Operator LIKE',
        Search       => {
            Field    => 'Fulltext',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article_search ta ON ta.ticket_id = st.id'
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(st.tn) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(st.title) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(ta.a_to) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(ta.a_cc) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(ta.a_from) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(ta.a_body) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(ta.a_subject) LIKE \'%test%\' ESCAPE \'' . $Escape . '\') ' : '(st.tn LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR st.title LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR ta.a_to LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR ta.a_c) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR ta.a_from LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR ta.a_body LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR ta.a_subject LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
            ]
        }
    }
);
for my $Test ( @SearchTests ) {
    my $Result = $AttributeObject->Search(
        Search       => $Test->{Search},
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

# set config 'Ticket::SearchIndexModule' to 'StaticDB' to get data prepared
$Kernel::OM->Get('Config')->Set(
    Key   => 'Ticket::SearchIndexModule',
    Value => 'Kernel::System::Ticket::ArticleSearchIndex::StaticDB'
);

my $SearchIndexAttributes = $Kernel::OM->Get('Config')->Get('Ticket::SearchIndex::Attribute');

## prepare mappings ##
my $Title1          = 'Unit Test + 001';
my $Title2          = 'Unit Test + 002';
my $Title3          = 'Unit Test + 003';
my $ChannelName1    = 'note';
my $ChannelName2    = 'email';
my $ChannelID1      = $Kernel::OM->Get('Channel')->ChannelLookup( Name => $ChannelName1 );
my $ChannelID2      = $Kernel::OM->Get('Channel')->ChannelLookup( Name => $ChannelName2 );
my $SenderTypeName1 = 'agent';
my $SenderTypeName2 = 'external';
my $SenderTypeID1   = $Kernel::OM->Get('Ticket')->ArticleSenderTypeLookup( SenderType => $SenderTypeName1 );
my $SenderTypeID2   = $Kernel::OM->Get('Ticket')->ArticleSenderTypeLookup( SenderType => $SenderTypeName2 );
my $From1           = '"Agent" <agent@kixdesk.com>';
my $From2           = '"Customer" <customer@external.com>';
my $To1             = '"Customer" <customer@external.com>';
my $To2             = '"Agent" <agent@kixdesk.com>';
my $Cc1             = '"External" <external@external.com>';
my $Cc2             = '"External" <external@external.com>';
my $Subject1        = 'Test1';
my $Subject2        = 'Test2';
my $Body1           = 'You have to test again.';
my $Body2           = 'You have to test again and again.';

## prepare test tickets ##
# first ticket
my $TicketID1 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Title1,
    QueueID        => 1,
    Lock           => 'unlock',
    PriorityID     => 1,
    StateID        => 1,
    TypeID         => 1,
    OrganisationID => 1,
    ContactID      => 1,
    OwnerID        => 1,
    ResponsibleID  => 1,
    UserID         => 1
);
$Self->True(
    $TicketID1,
    'Created first ticket'
);
my $ArticleID1 = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID        => $TicketID1,
    ChannelID       => $ChannelID1,
    SenderTypeID    => $SenderTypeID1,
    From            => $From1,
    To              => $To1,
    Cc              => $Cc1,
    Subject         => $Subject1,
    Body            => $Body1,
    ContentType     => 'text/plain; charset=utf-8',
    HistoryType     => 'AddNote',
    HistoryComment  => 'UnitTest',
    CustomerVisible => 0,
    UserID          => 1
);
$Self->True(
    $ArticleID1,
    'Created article for first ticket'
);
# second ticket
$Helper->FixedTimeAddSeconds(60);
my $TicketID2 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Title2,
    QueueID        => 1,
    Lock           => 'unlock',
    PriorityID     => 1,
    StateID        => 1,
    TypeID         => 1,
    OrganisationID => 1,
    ContactID      => 1,
    OwnerID        => 1,
    ResponsibleID  => 1,
    UserID         => 1
);
$Self->True(
    $TicketID2,
    'Created second ticket'
);
my $ArticleID2 = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID        => $TicketID2,
    ChannelID       => $ChannelID2,
    SenderTypeID    => $SenderTypeID2,
    From            => $From2,
    To              => $To2,
    Cc              => $Cc2,
    Subject         => $Subject2,
    Body            => $Body2,
    ContentType     => 'text/plain; charset=utf-8',
    HistoryType     => 'AddNote',
    HistoryComment  => 'UnitTest',
    CustomerVisible => 1,
    UserID          => 1
);
$Self->True(
    $ArticleID2,
    'Created article for second ticket'
);
# third ticket
$Helper->FixedTimeAddSeconds(60);
my $TicketID3 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Title3,
    QueueID        => 1,
    Lock           => 'unlock',
    PriorityID     => 1,
    StateID        => 1,
    TypeID         => 1,
    OrganisationID => 1,
    ContactID      => 1,
    OwnerID        => 1,
    ResponsibleID  => 1,
    UserID         => 1
);
$Self->True(
    $TicketID3,
    'Created third ticket without article'
);

# prepare search variable
$Subject1 = $Kernel::OM->Get('Ticket')->_ArticleIndexString(
    String => $Subject1
);
$Subject2 = $Kernel::OM->Get('Ticket')->_ArticleIndexString(
    String => $Subject2
);
$Body1 = $Kernel::OM->Get('Ticket')->_ArticleIndexString(
    String => $Body1
);
$Body2 = $Kernel::OM->Get('Ticket')->_ArticleIndexString(
    String => $Body2
);
$From1 = $Kernel::OM->Get('Ticket')->_ArticleIndexString(
    String => $From1
);
$From2 = $Kernel::OM->Get('Ticket')->_ArticleIndexString(
    String => $From2
);
$To1 = $Kernel::OM->Get('Ticket')->_ArticleIndexString(
    String => $To1
);
$To2 = $Kernel::OM->Get('Ticket')->_ArticleIndexString(
    String => $To2
);
$Cc1 = $Kernel::OM->Get('Ticket')->_ArticleIndexString(
    String => $Cc1
);
$Cc2 = $Kernel::OM->Get('Ticket')->_ArticleIndexString(
    String => $Cc2
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Ticket'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value \$To1",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => $To1
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value substr(\$To1,0,4)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => substr($To1,0,4)
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value \$Body1",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => q{"} . $Body1 . q{"}
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value substr(\$Body1,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => q{"} . substr($Body1,-5) . q{"}
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value \$Title2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => q{"} . $Title2 . q{"}
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value substr(\$Title2,2,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => q{"} . substr($Title2,2,-2) . q{"}
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value \$Subject2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => q{"} . $Subject2 . q{"}
                }
            ]
        },
        Expected => [$TicketID2]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value \"\$To2\"",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => q{"} . $To2 . q{"}
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value \"substr(\$To2,0,4)\"",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => q{"} . substr($To2,0,4) . q{"}
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value \$Body2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => q{"} . $Body2 . q{"}
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value substr(\$Body2,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => q{"} . substr($Body2,-5) . q{"}
                }
            ]
        },
        Expected => [$TicketID1,$TicketID2,$TicketID3]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value \$Title3",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => q{"} . $Title3 . q{"}
                }
            ]
        },
        Expected => [$TicketID3]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value substr(\$Title3,2,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => q{"} . substr($Title3,2,-2) . q{"}
                }
            ]
        },
        Expected => [$TicketID1, $TicketID2, $TicketID3]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value \$Subject1",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => q{"} . $Subject1 . q{"}
                }
            ]
        },
        Expected => [$TicketID1]
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Ticket',
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
