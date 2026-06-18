# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/
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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::TimeAccounting::GeneralIDs';

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
for my $Method ( qw(GetSupportedAttributes AttributePrepare Select Search Sort) ) {
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
        TicketID => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType      => 'NUMERIC'
        },
        ArticleID => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType      => 'NUMERIC'
        }
    },
    'GetSupportedAttributes provides expected data'
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
            Field    => 'TicketID',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'TicketID',
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
            Field    => 'TicketID',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'TicketID',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field TicketID / Operator EQ',
        Search       => {
            Field    => 'TicketID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ta.ticket_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TicketID / Operator NE',
        Search       => {
            Field    => 'TicketID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ta.ticket_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TicketID / Operator IN',
        Search       => {
            Field    => 'TicketID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'ta.ticket_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TicketID / Operator !IN',
        Search       => {
            Field    => 'TicketID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'ta.ticket_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TicketID / Operator LT',
        Search       => {
            Field    => 'TicketID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ta.ticket_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TicketID / Operator LTE',
        Search       => {
            Field    => 'TicketID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ta.ticket_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TicketID / Operator GT',
        Search       => {
            Field    => 'TicketID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ta.ticket_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field TicketID / Operator GTE',
        Search       => {
            Field    => 'TicketID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ta.ticket_id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ArticleID / Operator EQ',
        Search       => {
            Field    => 'ArticleID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ta.article_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ArticleID / Operator NE',
        Search       => {
            Field    => 'ArticleID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ta.article_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ArticleID / Operator IN',
        Search       => {
            Field    => 'ArticleID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'ta.article_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ArticleID / Operator !IN',
        Search       => {
            Field    => 'ArticleID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'ta.article_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ArticleID / Operator LT',
        Search       => {
            Field    => 'ArticleID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ta.article_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ArticleID / Operator LTE',
        Search       => {
            Field    => 'ArticleID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ta.article_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ArticleID / Operator GT',
        Search       => {
            Field    => 'ArticleID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ta.article_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ArticleID / Operator GTE',
        Search       => {
            Field    => 'ArticleID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'ta.article_id >= 1'
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
        Name      => 'Sort: Attribute "TicketID"',
        Attribute => 'TicketID',
        Expected  => {
            'Select'  => ['ta.ticket_id AS SortAttr0'],
            'OrderBy' => ['SortAttr0']
        }
    },
    {
        Name      => 'Sort: Attribute "ArticleID"',
        Attribute => 'ArticleID',
        Expected  => {
            'Select'  => ['ta.article_id AS SortAttr0'],
            'OrderBy' => ['SortAttr0']
        }
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

my $TimeStamp = $Kernel::OM->Get('Time')->CurrentTimestamp();

## prepare Ticket ##
my $TicketID1 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title    => 'UnitTest',
    OwnerID  => 1,
    Queue    => 'Junk',
    Priority => '3 normal',
    UserID   => 1,
    State    => 'new',
    Lock     => 'unlock'
);
$Self->True(
    $TicketID1,
    'first ticket created'
);

my $ArticleID1 = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID         => $TicketID1,
    Channel          => 'note',
    SenderType       => 'agent',
    Subject          => 'Some Unit Test',
    Body             => 'the message text',
    Charset          => 'utf-8',
    MimeType         => 'text/plain',
    HistoryType      => 'AddNote',
    HistoryComment   => '%%',
    UserID           => 1,
);
$Self->True(
    $ArticleID1,
    'first article of first ticket created'
);

my $TicketID2 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title    => 'UnitTest',
    OwnerID  => 1,
    Queue    => 'Junk',
    Priority => '3 normal',
    UserID   => 1,
    State    => 'new',
    Lock     => 'unlock'
);
$Self->True(
    $TicketID2,
    'second ticket created'
);

my $ArticleID2 = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID         => $TicketID2,
    Channel          => 'note',
    SenderType       => 'agent',
    Subject          => 'Some Unit Test',
    Body             => 'the message text',
    Charset          => 'utf-8',
    MimeType         => 'text/plain',
    HistoryType      => 'AddNote',
    HistoryComment   => '%%',
    UserID           => 1,
);
$Self->True(
    $ArticleID2,
    'first article of second ticket created'
);

my $ArticleID3 = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID         => $TicketID2,
    Channel          => 'note',
    SenderType       => 'agent',
    Subject          => 'Some Unit Test',
    Body             => 'the message text',
    Charset          => 'utf-8',
    MimeType         => 'text/plain',
    HistoryType      => 'AddNote',
    HistoryComment   => '%%',
    UserID           => 1,
);
$Self->True(
    $ArticleID3,
    'second article of second ticket created'
);

my $TicketID3 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title    => 'UnitTest',
    OwnerID  => 1,
    Queue    => 'Junk',
    Priority => '3 normal',
    UserID   => 1,
    State    => 'new',
    Lock     => 'unlock'
);
$Self->True(
    $TicketID3,
    'third ticket created'
);

## prepare TimeAccounting ##
my $TimeAccountingID1 = $Kernel::OM->Get('TimeAccounting')->TimeAccountingCreate(
    TicketID           => $TicketID1,
    ArticleID          => $ArticleID1,
    StartTime          => $TimeStamp,
    TimeUnit           => 1,
    IsInvoiced         => 0,
    UserID             => 1,
    UserType           => 'Agent',
    ExecutingContactID => 1,
);
$Self->True(
    $TimeAccountingID1,
    'first time accounting created'
);

my $TimeAccountingID2 = $Kernel::OM->Get('TimeAccounting')->TimeAccountingCreate(
    TicketID           => $TicketID2,
    ArticleID          => $ArticleID2,
    StartTime          => $TimeStamp,
    TimeUnit           => 1,
    IsInvoiced         => 0,
    UserID             => 1,
    UserType           => 'Agent',
    ExecutingContactID => 1,
);
$Self->True(
    $TimeAccountingID2,
    'second time accounting created'
);

my $TimeAccountingID3 = $Kernel::OM->Get('TimeAccounting')->TimeAccountingCreate(
    TicketID           => $TicketID2,
    ArticleID          => $ArticleID3,
    StartTime          => $TimeStamp,
    TimeUnit           => 1,
    IsInvoiced         => 0,
    UserID             => 1,
    UserType           => 'Agent',
    ExecutingContactID => 1,
);
$Self->True(
    $TimeAccountingID3,
    'third time accounting created'
);

my $TimeAccountingID4 = $Kernel::OM->Get('TimeAccounting')->TimeAccountingCreate(
    TicketID           => $TicketID2,
    StartTime          => $TimeStamp,
    TimeUnit           => 1,
    IsInvoiced         => 0,
    UserID             => 1,
    UserType           => 'Agent',
    ExecutingContactID => 1,
);
$Self->True(
    $TimeAccountingID4,
    'fourth time accounting created'
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Ticket'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field TicketID / Operator EQ / Value $TicketID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketID',
                    Operator => 'EQ',
                    Value    => $TicketID2
                }
            ]
        },
        Expected => [$TimeAccountingID2,$TimeAccountingID3,$TimeAccountingID4 ]
    },
    {
        Name     => 'Search: Field TicketID / Operator NE / Value $TicketID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketID',
                    Operator => 'NE',
                    Value    => $TicketID2
                }
            ]
        },
        Expected => [$TimeAccountingID1]
    },
    {
        Name     => 'Search: Field TicketID / Operator IN / Value [$TicketID1,$TicketID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketID',
                    Operator => 'IN',
                    Value    => [$TicketID1,$TicketID3]
                }
            ]
        },
        Expected => [$TimeAccountingID1]
    },
    {
        Name     => 'Search: Field TicketID / Operator !IN / Value [$TicketID1,$TicketID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketID',
                    Operator => '!IN',
                    Value    => [$TicketID1,$TicketID3]
                }
            ]
        },
        Expected => [$TimeAccountingID2,$TimeAccountingID3,$TimeAccountingID4 ]
    },
    {
        Name     => 'Search: Field TicketID / Operator LT / Value $TicketID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketID',
                    Operator => 'LT',
                    Value    => $TicketID2
                }
            ]
        },
        Expected => [$TimeAccountingID1]
    },
    {
        Name     => 'Search: Field TicketID / Operator LTE / Value $TicketID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketID',
                    Operator => 'LTE',
                    Value    => $TicketID2
                }
            ]
        },
        Expected => [$TimeAccountingID1,$TimeAccountingID2,$TimeAccountingID3,$TimeAccountingID4 ]
    },
    {
        Name     => 'Search: Field TicketID / Operator GT / Value $TicketID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketID',
                    Operator => 'GT',
                    Value    => $TicketID2
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field TicketID / Operator GTE / Value $TicketID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'TicketID',
                    Operator => 'GTE',
                    Value    => $TicketID2
                }
            ]
        },
        Expected => [$TimeAccountingID2,$TimeAccountingID3,$TimeAccountingID4]
    },
    {
        Name     => 'Search: Field ArticleID / Operator EQ / Value $ArticleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'EQ',
                    Value    => $ArticleID2
                }
            ]
        },
        Expected => [$TimeAccountingID2]
    },
    {
        Name     => 'Search: Field ArticleID / Operator NE / Value $ArticleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'NE',
                    Value    => $ArticleID2
                }
            ]
        },
        Expected => [$TimeAccountingID1,$TimeAccountingID3]
    },
    {
        Name     => 'Search: Field ArticleID / Operator IN / Value [$ArticleID1,$ArticleID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'IN',
                    Value    => [$ArticleID1,$ArticleID3]
                }
            ]
        },
        Expected => [$TimeAccountingID1,$TimeAccountingID3]
    },
    {
        Name     => 'Search: Field ArticleID / Operator !IN / Value [$ArticleID1,$ArticleID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => '!IN',
                    Value    => [$ArticleID1,$ArticleID3]
                }
            ]
        },
        Expected => [$TimeAccountingID2]
    },
    {
        Name     => 'Search: Field ArticleID / Operator LT / Value $ArticleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'LT',
                    Value    => $ArticleID2
                }
            ]
        },
        Expected => [$TimeAccountingID1]
    },
    {
        Name     => 'Search: Field ArticleID / Operator LTE / Value $ArticleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'LTE',
                    Value    => $ArticleID2
                }
            ]
        },
        Expected => [$TimeAccountingID1,$TimeAccountingID2]
    },
    {
        Name     => 'Search: Field ArticleID / Operator GT / Value $ArticleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'GT',
                    Value    => $ArticleID2
                }
            ]
        },
        Expected => [$TimeAccountingID3]
    },
    {
        Name     => 'Search: Field ArticleID / Operator GTE / Value $ArticleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'GTE',
                    Value    => $ArticleID2
                }
            ]
        },
        Expected => [$TimeAccountingID2,$TimeAccountingID3]
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'TimeAccounting',
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
my @IntegrationSortTests = (
    {
        Name     => 'Sort: Field TicketID',
        Sort     => [
            {
                Field => 'TicketID'
            }
        ],
        Expected => [$TimeAccountingID1,$TimeAccountingID2,$TimeAccountingID3,$TimeAccountingID4]
    },
    {
        Name     => 'Sort: Field TicketID / Direction ascending',
        Sort     => [
            {
                Field     => 'TicketID',
                Direction => 'ascending'
            }
        ],
        Expected => [$TimeAccountingID1,$TimeAccountingID2,$TimeAccountingID3,$TimeAccountingID4]
    },
    {
        Name     => 'Sort: Field TicketID / Direction descending',
        Sort     => [
            {
                Field     => 'TicketID',
                Direction => 'descending'
            }
        ],
        Expected => [$TimeAccountingID2,$TimeAccountingID3,$TimeAccountingID4,$TimeAccountingID1]
    },
    {
        Name     => 'Sort: Field ArticleID',
        Sort     => [
            {
                Field => 'ArticleID'
            }
        ],
        Expected => [$TimeAccountingID1,$TimeAccountingID2,$TimeAccountingID3,$TimeAccountingID4]
    },
    {
        Name     => 'Sort: Field ArticleID / Direction ascending',
        Sort     => [
            {
                Field     => 'ArticleID',
                Direction => 'ascending'
            }
        ],
        Expected => [$TimeAccountingID1,$TimeAccountingID2,$TimeAccountingID3,$TimeAccountingID4]
    },
    {
        Name     => 'Sort: Field ArticleID / Direction descending',
        Sort     => [
            {
                Field     => 'ArticleID',
                Direction => 'descending'
            }
        ],
        Expected => [$TimeAccountingID4,$TimeAccountingID3,$TimeAccountingID2,$TimeAccountingID1]
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'TimeAccounting',
        Result     => 'ARRAY',
        Sort       => $Test->{Sort},
        UserType   => 'Agent',
        UserID     => 1,
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
