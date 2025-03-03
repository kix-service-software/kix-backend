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

# Quoting ESCAPE character backslash
my $QuoteBack = $Kernel::OM->Get('DB')->GetDatabaseFunction('QuoteBack');
my $Escape = "\\";
if ( $QuoteBack ) {
    $Escape =~ s/\\/$QuoteBack\\/g;
}

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
                $CaseSensitive ? '(LOWER(a.a_from) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(a.a_to) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(a.a_cc) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(a.a_subject) LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR LOWER(a.a_body) LIKE \'%test%\' ESCAPE \'' . $Escape . '\') ' : '(a.a_from LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR a.a_to LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR a.a_cc LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR a.a_subject LIKE \'%test%\' ESCAPE \'' . $Escape . '\' OR a.a_body LIKE \'%test%\' ESCAPE \'' . $Escape . '\') '
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

## prepare mappings ##
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
my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
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
    $TicketID,
    'Created ticket'
);
my $ArticleID1 = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID        => $TicketID,
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
    'Created first article for ticket'
);
$Helper->FixedTimeAddSeconds(60);
my $ArticleID2 = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID        => $TicketID,
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
    'Created second article for ticket'
);

# prepare search values
$To2 =~ s/"/\"/g;

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
        Expected => [$ArticleID1,$ArticleID2]
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
        Expected => [$ArticleID1,$ArticleID2]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value \$Body1",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => $Body1
                }
            ]
        },
        Expected => [$ArticleID1,$ArticleID2]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value substr(\$Body1,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => substr($Body1,-5)
                }
            ]
        },
        Expected => [$ArticleID1,$ArticleID2]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value \$Subject2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => $Subject2
                }
            ]
        },
        Expected => [$ArticleID2]
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
        Expected => [$ArticleID1, $ArticleID2]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value \"substr(\$To2,0,4)\"",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => q{"} . substr($To2,2,4) . q{"}
                }
            ]
        },
        Expected => [$ArticleID1, $ArticleID2]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value \"\$Body2\"",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => q{"} . $Body2 . q{"}
                }
            ]
        },
        Expected => [$ArticleID2]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value \"substr(\$Body2,-5)\"",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => q{"} . substr($Body2,-5) . q{"}
                }
            ]
        },
        Expected => [$ArticleID1,$ArticleID2]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value \"\$Subject1\"",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => q{"} . $Subject1 . q{"}
                }
            ]
        },
        Expected => [$ArticleID1]
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my %Search = %{$Test->{Search}};
    $Search{AND} //= [];
    push @{$Search{AND}}, { Field => 'TicketID', Operator => 'EQ', Value => $TicketID };

    my @Result = $ObjectSearch->Search(
        ObjectType => 'Article',
        Result     => 'ARRAY',
        Search     => \%Search,
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
