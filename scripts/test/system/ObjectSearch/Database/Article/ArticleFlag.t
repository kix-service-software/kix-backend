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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Article::ArticleFlag';

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
    $AttributeList,
    {
        'ArticleFlag.Seen' => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE']
        }
    },
    'GetSupportedAttributes provides expected data'
);

# check Search
my @SearchTests = (
    {
        Name         => 'Search: undef search',
        Search       => undef,
        UserType     => 'Agent',
        Expected     => undef
    },
    {
        Name         => 'Search: Value undef',
        Search       => {
            Field    => 'ArticleFlag.Seen',
            Operator => 'EQ',
            Value    => undef

        },
        UserType     => 'Agent',
        Expected     => undef
    },
    {
        Name         => 'Search: Field undef',
        Search       => {
            Field    => undef,
            Operator => 'EQ',
            Value    => 'Test'
        },
        UserType     => 'Agent',
        Expected     => undef
    },
    {
        Name         => 'Search: Field invalid',
        Search       => {
            Field    => 'Test',
            Operator => 'EQ',
            Value    => 'Test'
        },
        UserType     => 'Agent',
        Expected     => undef
    },
    {
        Name         => 'Search: Operator undef',
        Search       => {
            Field    => 'ArticleFlag.Seen',
            Operator => undef,
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'ArticleFlag.Seen',
            Operator => 'Test',
            Value    => 'Test'
        },
        UserType     => 'Agent',
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field ArticleFlag.Seen / Operator EQ',
        Search       => {
            Field    => 'ArticleFlag.Seen',
            Operator => 'EQ',
            Value    => 'Test'
        },
        UserType     => 'Agent',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article_flag af_left0 ON af_left0.article_id = a.id AND af_left0.article_key = \'Seen\' AND af_left0.create_by = 1'
            ],
            'Where' => [
                'af_left0.article_value = \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ArticleFlag.Seen / Operator EQ / empty string',
        Search       => {
            Field    => 'ArticleFlag.Seen',
            Operator => 'EQ',
            Value    => ''
        },
        UserType     => 'Agent',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article_flag af_left0 ON af_left0.article_id = a.id AND af_left0.article_key = \'Seen\' AND af_left0.create_by = 1'
            ],
            'Where' => [
                '(af_left0.article_value = \'\' OR af_left0.article_value IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ArticleFlag.Seen / Operator NE',
        Search       => {
            Field    => 'ArticleFlag.Seen',
            Operator => 'NE',
            Value    => 'Test'
        },
        UserType     => 'Agent',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article_flag af_left0 ON af_left0.article_id = a.id AND af_left0.article_key = \'Seen\' AND af_left0.create_by = 1'
            ],
            'Where' => [
                '(af_left0.article_value != \'Test\' OR af_left0.article_value IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ArticleFlag.Seen / Operator NE / empty string',
        Search       => {
            Field    => 'ArticleFlag.Seen',
            Operator => 'NE',
            Value    => ''
        },
        UserType     => 'Agent',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article_flag af_left0 ON af_left0.article_id = a.id AND af_left0.article_key = \'Seen\' AND af_left0.create_by = 1'
            ],
            'Where' => [
                'af_left0.article_value != \'\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ArticleFlag.Seen / Operator EQ / UserType Customer',
        Search       => {
            Field    => 'ArticleFlag.Seen',
            Operator => 'EQ',
            Value    => 'Test'
        },
        UserType     => 'Customer',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article_flag af_left0 ON af_left0.article_id = a.id AND af_left0.article_key = \'Seen\' AND af_left0.create_by = 1'
            ],
            'Where' => [
                'af_left0.article_value = \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ArticleFlag.Seen / Operator EQ / empty string / UserType Customer',
        Search       => {
            Field    => 'ArticleFlag.Seen',
            Operator => 'EQ',
            Value    => ''
        },
        UserType     => 'Customer',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article_flag af_left0 ON af_left0.article_id = a.id AND af_left0.article_key = \'Seen\' AND af_left0.create_by = 1'
            ],
            'Where' => [
                '(af_left0.article_value = \'\' OR af_left0.article_value IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ArticleFlag.Seen / Operator NE / UserType Customer',
        Search       => {
            Field    => 'ArticleFlag.Seen',
            Operator => 'NE',
            Value    => 'Test'
        },
        UserType     => 'Customer',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article_flag af_left0 ON af_left0.article_id = a.id AND af_left0.article_key = \'Seen\' AND af_left0.create_by = 1'
            ],
            'Where' => [
                '(af_left0.article_value != \'Test\' OR af_left0.article_value IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ArticleFlag.Seen / Operator NE / empty string / UserType Customer',
        Search       => {
            Field    => 'ArticleFlag.Seen',
            Operator => 'NE',
            Value    => ''
        },
        UserType     => 'Customer',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article_flag af_left0 ON af_left0.article_id = a.id AND af_left0.article_key = \'Seen\' AND af_left0.create_by = 1'
            ],
            'Where' => [
                'af_left0.article_value != \'\''
            ]
        }
    }
);
for my $Test ( @SearchTests ) {
    my $Result = $AttributeObject->Search(
        Search       => $Test->{Search},
        UserType     => $Test->{UserType},
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
        Name      => 'Sort: Attribute "ArticleFlag.Seen"',
        Attribute => 'ArticleFlag.Seen',
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

## prepare test tickets ##
# first ticket
my $TicketID1 = $Kernel::OM->Get('Ticket')->TicketCreate(
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
    $TicketID1,
    'Created first ticket'
);
my $ArticleID1 = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID        => $TicketID1,
    Channel         => 'note',
    SenderType      => 'agent',
    Subject         => 'Test',
    Body            => 'Test',
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
## ArticleFlag Seen is set by EventHandler 'TicketNewMessageUpdate'
# second ticket
my $TicketID2 = $Kernel::OM->Get('Ticket')->TicketCreate(
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
    $TicketID2,
    'Created second ticket'
);
my $ArticleID2 = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID        => $TicketID2,
    Channel         => 'note',
    SenderType      => 'agent',
    Subject         => 'Test',
    Body            => 'Test',
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
my $ArticleFlagSet2 = $Kernel::OM->Get('Ticket')->ArticleFlagSet(
    ArticleID => $ArticleID2,
    Key      => 'Seen',
    Value    => 1,
    UserID   => 1,
);
$Self->True(
    $ArticleFlagSet2,
    'Set flag Seen for article of second ticket'
);
# third ticket
my $TicketID3 = $Kernel::OM->Get('Ticket')->TicketCreate(
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
    $TicketID3,
    'Created third ticket'
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Ticket'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field ArticleFlag.Seen / Operator EQ / Value 1 / UserType Agent',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleFlag.Seen',
                    Operator => 'EQ',
                    Value    => '1'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: Field ArticleFlag.Seen / Operator EQ / Value empty string / UserType Agent',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleFlag.Seen',
                    Operator => 'EQ',
                    Value    => ''
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field ArticleFlag.Seen / Operator EQ / Value zero / UserType Agent',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleFlag.Seen',
                    Operator => 'EQ',
                    Value    => '0'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field ArticleFlag.Seen / Operator NE / Value 1 / UserType Agent',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleFlag.Seen',
                    Operator => 'NE',
                    Value    => '1'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field ArticleFlag.Seen / Operator NE / Value empty string / UserType Agent',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleFlag.Seen',
                    Operator => 'NE',
                    Value    => ''
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: Field ArticleFlag.Seen / Operator NE / Value zero / UserType Agent',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleFlag.Seen',
                    Operator => 'NE',
                    Value    => '0'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: Field ArticleFlag.Seen / Operator EQ / Value 1 / UserType Customer',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleFlag.Seen',
                    Operator => 'EQ',
                    Value    => '1'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field ArticleFlag.Seen / Operator EQ / Value empty string / UserType Customer',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleFlag.Seen',
                    Operator => 'EQ',
                    Value    => ''
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field ArticleFlag.Seen / Operator EQ / Value zero / UserType Customer',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleFlag.Seen',
                    Operator => 'EQ',
                    Value    => '0'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field ArticleFlag.Seen / Operator NE / Value 1 / UserType Customer',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleFlag.Seen',
                    Operator => 'NE',
                    Value    => '1'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field ArticleFlag.Seen / Operator NE / Value empty string / UserType Customer',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleFlag.Seen',
                    Operator => 'NE',
                    Value    => ''
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field ArticleFlag.Seen / Operator NE / Value zero / UserType Customer',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleFlag.Seen',
                    Operator => 'NE',
                    Value    => '0'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Ticket',
        Result     => 'ARRAY',
        Search     => $Test->{Search},
        UserType   => $Test->{UserType},
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
