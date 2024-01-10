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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Ticket::ArticleAttachment';

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

# make sure config 'Ticket::StorageModule' is 'Kernel::System::Ticket::ArticleStorageFS'
$Kernel::OM->Get('Config')->Set(
    Key   => 'Ticket::StorageModule',
    Value => 'Kernel::System::Ticket::ArticleStorageFS'
);

# check GetSupportedAttributes
my $InactiveAttributeList = $AttributeObject->GetSupportedAttributes();
$Self->IsDeeply(
    $InactiveAttributeList,
    {},
    'GetSupportedAttributes provides expected data when "Ticket::StorageModule" is not  "Kernel::System::Ticket::ArticleStorageDB"'
);

# make sure config 'Ticket::StorageModule' is 'Kernel::System::Ticket::ArticleStorageDB'
$Kernel::OM->Get('Config')->Set(
    Key   => 'Ticket::StorageModule',
    Value => 'Kernel::System::Ticket::ArticleStorageDB'
);

# check GetSupportedAttributes
my $ActiveAttributeList = $AttributeObject->GetSupportedAttributes();
$Self->IsDeeply(
    $ActiveAttributeList,
    {
        AttachmentName => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        }
    },
    'GetSupportedAttributes provides expected data when "Ticket::StorageModule" is "Kernel::System::Ticket::ArticleStorageDB"'
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
            Field    => 'AttachmentName',
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
            Field    => 'AttachmentName',
            Operator => undef,
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'AttachmentName',
            Operator => 'Test',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field AttachmentName / Operator EQ',
        Search       => {
            Field    => 'AttachmentName',
            Operator => 'EQ',
            Value    => 'Test'
        },
        UserType     => 'Agent',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id',
                'LEFT OUTER JOIN article_attachment att ON att.article_id = ta.id'
            ],
            'Where' => [
                'LOWER(att.filename) = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AttachmentName / Operator EQ / Value empty string',
        Search       => {
            Field    => 'AttachmentName',
            Operator => 'EQ',
            Value    => ''
        },
        UserType     => 'Agent',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id',
                'LEFT OUTER JOIN article_attachment att ON att.article_id = ta.id'
            ],
            'Where' => [
                '(LOWER(att.filename) = \'\' OR att.filename IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AttachmentName / Operator NE',
        Search       => {
            Field    => 'AttachmentName',
            Operator => 'NE',
            Value    => 'Test'
        },
        UserType     => 'Agent',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id',
                'LEFT OUTER JOIN article_attachment att ON att.article_id = ta.id'
            ],
            'Where' => [
                '(LOWER(att.filename) != \'test\' OR att.filename IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AttachmentName / Operator NE / Value empty string',
        Search       => {
            Field    => 'AttachmentName',
            Operator => 'NE',
            Value    => ''
        },
        UserType     => 'Agent',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id',
                'LEFT OUTER JOIN article_attachment att ON att.article_id = ta.id'
            ],
            'Where' => [
                'LOWER(att.filename) != \'\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AttachmentName / Operator IN',
        Search       => {
            Field    => 'AttachmentName',
            Operator => 'IN',
            Value    => ['Test']
        },
        UserType     => 'Agent',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id',
                'LEFT OUTER JOIN article_attachment att ON att.article_id = ta.id'
            ],
            'Where' => [
                'LOWER(att.filename) IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AttachmentName / Operator !IN',
        Search       => {
            Field    => 'AttachmentName',
            Operator => '!IN',
            Value    => ['Test']
        },
        UserType     => 'Agent',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id',
                'LEFT OUTER JOIN article_attachment att ON att.article_id = ta.id'
            ],
            'Where' => [
                'LOWER(att.filename) NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AttachmentName / Operator STARTSWITH',
        Search       => {
            Field    => 'AttachmentName',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        UserType     => 'Agent',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id',
                'LEFT OUTER JOIN article_attachment att ON att.article_id = ta.id'
            ],
            'Where' => [
                'LOWER(att.filename) LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AttachmentName / Operator ENDSWITH',
        Search       => {
            Field    => 'AttachmentName',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        UserType     => 'Agent',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id',
                'LEFT OUTER JOIN article_attachment att ON att.article_id = ta.id'
            ],
            'Where' => [
                'LOWER(att.filename) LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AttachmentName / Operator CONTAINS',
        Search       => {
            Field    => 'AttachmentName',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        UserType     => 'Agent',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id',
                'LEFT OUTER JOIN article_attachment att ON att.article_id = ta.id'
            ],
            'Where' => [
                'LOWER(att.filename) LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AttachmentName / Operator LIKE',
        Search       => {
            Field    => 'AttachmentName',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        UserType     => 'Agent',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id',
                'LEFT OUTER JOIN article_attachment att ON att.article_id = ta.id'
            ],
            'Where' => [
                'LOWER(att.filename) LIKE \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AttachmentName / Operator EQ / UserType Customer',
        Search       => {
            Field    => 'AttachmentName',
            Operator => 'EQ',
            Value    => 'Test'
        },
        UserType     => 'Customer',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id AND ta.customer_visible = 1',
                'LEFT OUTER JOIN article_attachment att ON att.article_id = ta.id'
            ],
            'Where' => [
                'LOWER(att.filename) = \'test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AttachmentName / Operator EQ / Value empty string / UserType Customer',
        Search       => {
            Field    => 'AttachmentName',
            Operator => 'EQ',
            Value    => ''
        },
        UserType     => 'Customer',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id AND ta.customer_visible = 1',
                'LEFT OUTER JOIN article_attachment att ON att.article_id = ta.id'
            ],
            'Where' => [
                '(LOWER(att.filename) = \'\' OR att.filename IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AttachmentName / Operator NE / UserType Customer',
        Search       => {
            Field    => 'AttachmentName',
            Operator => 'NE',
            Value    => 'Test'
        },
        UserType     => 'Customer',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id AND ta.customer_visible = 1',
                'LEFT OUTER JOIN article_attachment att ON att.article_id = ta.id'
            ],
            'Where' => [
                '(LOWER(att.filename) != \'test\' OR att.filename IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AttachmentName / Operator NE / Value empty string / UserType Customer',
        Search       => {
            Field    => 'AttachmentName',
            Operator => 'NE',
            Value    => ''
        },
        UserType     => 'Customer',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id AND ta.customer_visible = 1',
                'LEFT OUTER JOIN article_attachment att ON att.article_id = ta.id'
            ],
            'Where' => [
                'LOWER(att.filename) != \'\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AttachmentName / Operator IN / UserType Customer',
        Search       => {
            Field    => 'AttachmentName',
            Operator => 'IN',
            Value    => ['Test']
        },
        UserType     => 'Customer',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id AND ta.customer_visible = 1',
                'LEFT OUTER JOIN article_attachment att ON att.article_id = ta.id'
            ],
            'Where' => [
                'LOWER(att.filename) IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AttachmentName / Operator !IN / UserType Customer',
        Search       => {
            Field    => 'AttachmentName',
            Operator => '!IN',
            Value    => ['Test']
        },
        UserType     => 'Customer',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id AND ta.customer_visible = 1',
                'LEFT OUTER JOIN article_attachment att ON att.article_id = ta.id'
            ],
            'Where' => [
                'LOWER(att.filename) NOT IN (\'test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AttachmentName / Operator STARTSWITH / UserType Customer',
        Search       => {
            Field    => 'AttachmentName',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        UserType     => 'Customer',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id AND ta.customer_visible = 1',
                'LEFT OUTER JOIN article_attachment att ON att.article_id = ta.id'
            ],
            'Where' => [
                'LOWER(att.filename) LIKE \'test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AttachmentName / Operator ENDSWITH / UserType Customer',
        Search       => {
            Field    => 'AttachmentName',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        UserType     => 'Customer',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id AND ta.customer_visible = 1',
                'LEFT OUTER JOIN article_attachment att ON att.article_id = ta.id'
            ],
            'Where' => [
                'LOWER(att.filename) LIKE \'%test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AttachmentName / Operator CONTAINS / UserType Customer',
        Search       => {
            Field    => 'AttachmentName',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        UserType     => 'Customer',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id AND ta.customer_visible = 1',
                'LEFT OUTER JOIN article_attachment att ON att.article_id = ta.id'
            ],
            'Where' => [
                'LOWER(att.filename) LIKE \'%test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field AttachmentName / Operator LIKE / UserType Customer',
        Search       => {
            Field    => 'AttachmentName',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        UserType     => 'Customer',
        Expected     => {
            'Join' => [
                'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id AND ta.customer_visible = 1',
                'LEFT OUTER JOIN article_attachment att ON att.article_id = ta.id'
            ],
            'Where' => [
                'LOWER(att.filename) LIKE \'test\''
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
        Name      => 'Sort: Attribute "AttachmentName"',
        Attribute => 'AttachmentName',
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

# make sure config 'Ticket::StorageModule' is 'Kernel::System::Ticket::ArticleStorageDB'
$Kernel::OM->Get('Config')->Set(
    Key   => 'Ticket::StorageModule',
    Value => 'Kernel::System::Ticket::ArticleStorageDB'
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
    'Created article for first ticket (CustomerVisible 0)'
);
my $AttachmentName1 = 'test001.txt';
my $AttachmentID1   = $Kernel::OM->Get('Ticket')->ArticleWriteAttachment(
    ArticleID   => $ArticleID1,
    Filename    => $AttachmentName1,
    ContentType => 'text/plain; charset=utf-8',
    Content     => 'Test',
    UserID      => 1
);
$Self->True(
    $AttachmentID1,
    'Created attachment for first ticket'
);
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
    'Created article for second ticket (CustomerVisible 1)'
);
my $AttachmentName2 = 'Test002.txt';
my $AttachmentID2   = $Kernel::OM->Get('Ticket')->ArticleWriteAttachment(
    ArticleID   => $ArticleID2,
    Filename    => $AttachmentName2,
    ContentType => 'text/plain; charset=utf-8',
    Content     => 'Test',
    UserID      => 1
);
$Self->True(
    $AttachmentID2,
    'Created attachment for second ticket'
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
    'Created third ticket without article'
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Ticket'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field AttachmentName / Operator EQ / Value $AttachmentName2 / UserType Agent',
        Search   => {
            'AND' => [
                {
                    Field    => 'AttachmentName',
                    Operator => 'EQ',
                    Value    => $AttachmentName2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field AttachmentName / Operator EQ / Value empty string / UserType Agent',
        Search   => {
            'AND' => [
                {
                    Field    => 'AttachmentName',
                    Operator => 'EQ',
                    Value    => ''
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: Field AttachmentName / Operator NE / Value $AttachmentName2 / UserType Agent',
        Search   => {
            'AND' => [
                {
                    Field    => 'AttachmentName',
                    Operator => 'NE',
                    Value    => $AttachmentName2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field AttachmentName / Operator NE / Value empty string / UserType Agent',
        Search   => {
            'AND' => [
                {
                    Field    => 'AttachmentName',
                    Operator => 'NE',
                    Value    => ''
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: Field AttachmentName / Operator IN / Value [$AttachmentName1] / UserType Agent',
        Search   => {
            'AND' => [
                {
                    Field    => 'AttachmentName',
                    Operator => 'IN',
                    Value    => [$AttachmentName1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: Field AttachmentName / Operator !IN / Value [$AttachmentName1] / UserType Agent',
        Search   => {
            'AND' => [
                {
                    Field    => 'AttachmentName',
                    Operator => '!IN',
                    Value    => [$AttachmentName1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field AttachmentName / Operator STARTSWITH / Value $AttachmentName2 / UserType Agent',
        Search   => {
            'AND' => [
                {
                    Field    => 'AttachmentName',
                    Operator => 'STARTSWITH',
                    Value    => $AttachmentName2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field AttachmentName / Operator STARTSWITH / Value substr($AttachmentName2,0,5) / UserType Agent',
        Search   => {
            'AND' => [
                {
                    Field    => 'AttachmentName',
                    Operator => 'STARTSWITH',
                    Value    => substr($AttachmentName2,0,5)
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: Field AttachmentName / Operator ENDSWITH / Value $AttachmentName2 / UserType Agent',
        Search   => {
            'AND' => [
                {
                    Field    => 'AttachmentName',
                    Operator => 'ENDSWITH',
                    Value    => $AttachmentName2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field AttachmentName / Operator ENDSWITH / Value substr($AttachmentName2,-4) / UserType Agent',
        Search   => {
            'AND' => [
                {
                    Field    => 'AttachmentName',
                    Operator => 'ENDSWITH',
                    Value    => substr($AttachmentName2,-4)
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: Field AttachmentName / Operator CONTAINS / Value $AttachmentName2 / UserType Agent',
        Search   => {
            'AND' => [
                {
                    Field    => 'AttachmentName',
                    Operator => 'CONTAINS',
                    Value    => $AttachmentName2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field AttachmentName / Operator CONTAINS / Value substr($AttachmentName2,2,-2) / UserType Agent',
        Search   => {
            'AND' => [
                {
                    Field    => 'AttachmentName',
                    Operator => 'CONTAINS',
                    Value    => substr($AttachmentName2,2,-2)
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field AttachmentName / Operator LIKE / Value $AttachmentName2 / UserType Agent',
        Search   => {
            'AND' => [
                {
                    Field    => 'AttachmentName',
                    Operator => 'LIKE',
                    Value    => $AttachmentName2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field AttachmentName / Operator EQ / Value $AttachmentName2 / UserType Customer',
        Search   => {
            'AND' => [
                {
                    Field    => 'AttachmentName',
                    Operator => 'EQ',
                    Value    => $AttachmentName2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field AttachmentName / Operator EQ / Value empty string / UserType Customer',
        Search   => {
            'AND' => [
                {
                    Field    => 'AttachmentName',
                    Operator => 'EQ',
                    Value    => ''
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field AttachmentName / Operator NE / Value $AttachmentName2 / UserType Customer',
        Search   => {
            'AND' => [
                {
                    Field    => 'AttachmentName',
                    Operator => 'NE',
                    Value    => $AttachmentName2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: Field AttachmentName / Operator NE / Value empty string / UserType Customer',
        Search   => {
            'AND' => [
                {
                    Field    => 'AttachmentName',
                    Operator => 'NE',
                    Value    => ''
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field AttachmentName / Operator IN / Value [$AttachmentName1] / UserType Customer',
        Search   => {
            'AND' => [
                {
                    Field    => 'AttachmentName',
                    Operator => 'IN',
                    Value    => [$AttachmentName1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: Field AttachmentName / Operator !IN / Value [$AttachmentName1] / UserType Customer',
        Search   => {
            'AND' => [
                {
                    Field    => 'AttachmentName',
                    Operator => '!IN',
                    Value    => [$AttachmentName1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field AttachmentName / Operator STARTSWITH / Value $AttachmentName2 / UserType Customer',
        Search   => {
            'AND' => [
                {
                    Field    => 'AttachmentName',
                    Operator => 'STARTSWITH',
                    Value    => $AttachmentName2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field AttachmentName / Operator STARTSWITH / Value substr($AttachmentName2,0,5) / UserType Customer',
        Search   => {
            'AND' => [
                {
                    Field    => 'AttachmentName',
                    Operator => 'STARTSWITH',
                    Value    => substr($AttachmentName2,0,5)
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field AttachmentName / Operator ENDSWITH / Value $AttachmentName2 / UserType Customer',
        Search   => {
            'AND' => [
                {
                    Field    => 'AttachmentName',
                    Operator => 'ENDSWITH',
                    Value    => $AttachmentName2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field AttachmentName / Operator ENDSWITH / Value substr($AttachmentName2,-4) / UserType Customer',
        Search   => {
            'AND' => [
                {
                    Field    => 'AttachmentName',
                    Operator => 'ENDSWITH',
                    Value    => substr($AttachmentName2,-4)
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field AttachmentName / Operator CONTAINS / Value $AttachmentName2 / UserType Customer',
        Search   => {
            'AND' => [
                {
                    Field    => 'AttachmentName',
                    Operator => 'CONTAINS',
                    Value    => $AttachmentName2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field AttachmentName / Operator CONTAINS / Value substr($AttachmentName2,2,-2) / UserType Customer',
        Search   => {
            'AND' => [
                {
                    Field    => 'AttachmentName',
                    Operator => 'CONTAINS',
                    Value    => substr($AttachmentName2,2,-2)
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: Field AttachmentName / Operator LIKE / Value $AttachmentName2 / UserType Customer',
        Search   => {
            'AND' => [
                {
                    Field    => 'AttachmentName',
                    Operator => 'LIKE',
                    Value    => $AttachmentName2
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
