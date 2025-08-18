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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Ticket::Article';

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

# set fixed time to have predetermined verifiable results
my $SystemTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
    String => '2014-01-01 12:00:00',
);
$Helper->FixedTimeSet($SystemTime);

# check GetSupportedAttributes
my $AttributeList = $AttributeObject->GetSupportedAttributes();
$Self->IsDeeply(
    $AttributeList,
    {
        ArticleID         => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType      => 'NUMERIC'
        },
        ChannelID         => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType      => 'NUMERIC'
        },
        Channel           => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        SenderTypeID      => {
            IsSelectable => 0,
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType    => 'NUMERIC'
        },
        SenderType        => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        CustomerVisible   => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType      => 'NUMERIC'
        },
        From              => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        To                => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Cc                => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Subject           => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Body              => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        ArticleCreateTime => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 0,
            Operators      => ['EQ','LT','GT','LTE','GTE'],
            ValueType      => 'DATETIME'
        }
    },
    'GetSupportedAttributes provides expected data'
);

# check Select
my @SelectTests = (
    {
        Name      => 'Select: Attribute undef',
        Parameter => {
            Attribute => undef
        },
        Expected  => undef
    },
    {
        Name      => 'Select: Attribute invalid',
        Parameter => {
            Attribute => 'Test'
        },
        Expected  => undef
    },
    {
        Name      => 'Select: Attribute "ArticleID"',
        Parameter => {
            Attribute => 'ArticleID'
        },
        Expected  => {
            Select => undef
        }
    },
    {
        Name      => 'Select: Attribute "ChannelID"',
        Parameter => {
            Attribute => 'ChannelID'
        },
        Expected  => undef
    },
    {
        Name      => 'Select: Attribute "Channel"',
        Parameter => {
            Attribute => 'Channel'
        },
        Expected  => undef
    },
    {
        Name      => 'Select: Attribute "SenderTypeID"',
        Parameter => {
            Attribute => 'SenderTypeID'
        },
        Expected  => undef
    },
    {
        Name      => 'Select: Attribute "SenderType"',
        Parameter => {
            Attribute => 'SenderType'
        },
        Expected  => undef
    },
    {
        Name      => 'Select: Attribute "CustomerVisible"',
        Parameter => {
            Attribute => 'CustomerVisible'
        },
        Expected  => undef
    },
    {
        Name      => 'Select: Attribute "From"',
        Parameter => {
            Attribute => 'From'
        },
        Expected  => undef
    },
    {
        Name      => 'Select: Attribute "To"',
        Parameter => {
            Attribute => 'To'
        },
        Expected  => undef
    },
    {
        Name      => 'Select: Attribute "Cc"',
        Parameter => {
            Attribute => 'Cc'
        },
        Expected  => undef
    },
    {
        Name      => 'Select: Attribute "Subject"',
        Parameter => {
            Attribute => 'Subject'
        },
        Expected  => undef
    },
    {
        Name      => 'Select: Attribute "Body"',
        Parameter => {
            Attribute => 'Body'
        },
        Expected  => undef
    },
    {
        Name      => 'Select: Attribute "ArticleCreateTime"',
        Parameter => {
            Attribute => 'ArticleCreateTime'
        },
        Expected  => undef
    }
);
for my $Test ( @SelectTests ) {
    my $Result = $AttributeObject->Select(
        %{ $Test->{Parameter} },
        Silent => defined( $Test->{Expected} ) ? 0 : 1
    );
    $Self->IsDeeply(
        $Result,
        $Test->{Expected},
        $Test->{Name}
    );
}

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
# set config 'Ticket::SearchIndexModule' to RuntimeDB
$Kernel::OM->Get('Config')->Set(
    Key   => 'Ticket::SearchIndexModule',
    Value => 'Kernel::System::Ticket::ArticleSearchIndex::RuntimeDB'
);

# run tests for UserType 'Agent' and 'Customer'
for my $UserType ( qw(Agent Customer) ) {
    # prepare suffix for article join
    my $JoinArticleSuffix = '';
    if ( $UserType eq 'Customer' ) {
        $JoinArticleSuffix = ' AND ta.customer_visible = 1'
    }

    # define tests
    my @SearchTests = (
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / undef search',
            Search       => undef,
            Expected     => undef
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / Value undef',
            Search       => {
                Field    => 'ArticleID',
                Operator => 'EQ',
                Value    => undef

            },
            Expected     => undef
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / Value invalid',
            Search       => {
                Field    => 'ArticleID',
                Operator => 'EQ',
                Value    => 'Test'
            },
            Expected     => undef
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / Field undef',
            Search       => {
                Field    => undef,
                Operator => 'EQ',
                Value    => '1'
            },
            Expected     => undef
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / Field invalid',
            Search       => {
                Field    => 'Test',
                Operator => 'EQ',
                Value    => '1'
            },
            Expected     => undef
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / Operator undef',
            Search       => {
                Field    => 'ArticleID',
                Operator => undef,
                Value    => '1'
            },
            Expected     => undef
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / Operator invalid',
            Search       => {
                Field    => 'ArticleID',
                Operator => 'Test',
                Value    => '1'
            },
            Expected     => undef
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field ArticleID / Operator EQ',
            Search       => {
                Field    => 'ArticleID',
                Operator => 'EQ',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.id = 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field ArticleID / Operator EQ / Value zero',
            Search       => {
                Field    => 'ArticleID',
                Operator => 'EQ',
                Value    => '0'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    '(ta.id = 0 OR ta.id IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field ArticleID / Operator NE',
            Search       => {
                Field    => 'ArticleID',
                Operator => 'NE',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    '(ta.id <> 1 OR ta.id IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field ArticleID / Operator NE / Value zero',
            Search       => {
                Field    => 'ArticleID',
                Operator => 'NE',
                Value    => '0'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.id <> 0'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field ArticleID / Operator IN',
            Search       => {
                Field    => 'ArticleID',
                Operator => 'IN',
                Value    => ['1']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.id IN (1)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field ArticleID / Operator !IN',
            Search       => {
                Field    => 'ArticleID',
                Operator => '!IN',
                Value    => ['1']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.id NOT IN (1)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field ArticleID / Operator LT',
            Search       => {
                Field    => 'ArticleID',
                Operator => 'LT',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.id < 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field ArticleID / Operator GT',
            Search       => {
                Field    => 'ArticleID',
                Operator => 'GT',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.id > 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field ArticleID / Operator LTE',
            Search       => {
                Field    => 'ArticleID',
                Operator => 'LTE',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.id <= 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field ArticleID / Operator GTE',
            Search       => {
                Field    => 'ArticleID',
                Operator => 'GTE',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.id >= 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field ChannelID / Operator EQ',
            Search       => {
                Field    => 'ChannelID',
                Operator => 'EQ',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.channel_id = 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field ChannelID / Operator EQ / Value zero',
            Search       => {
                Field    => 'ChannelID',
                Operator => 'EQ',
                Value    => '0'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    '(ta.channel_id = 0 OR ta.channel_id IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field ChannelID / Operator NE',
            Search       => {
                Field    => 'ChannelID',
                Operator => 'NE',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    '(ta.channel_id <> 1 OR ta.channel_id IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field ChannelID / Operator NE / Value zero',
            Search       => {
                Field    => 'ChannelID',
                Operator => 'NE',
                Value    => '0'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.channel_id <> 0'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field ChannelID / Operator IN',
            Search       => {
                Field    => 'ChannelID',
                Operator => 'IN',
                Value    => ['1']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.channel_id IN (1)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field ChannelID / Operator !IN',
            Search       => {
                Field    => 'ChannelID',
                Operator => '!IN',
                Value    => ['1']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.channel_id NOT IN (1)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field ChannelID / Operator LT',
            Search       => {
                Field    => 'ChannelID',
                Operator => 'LT',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.channel_id < 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field ChannelID / Operator GT',
            Search       => {
                Field    => 'ChannelID',
                Operator => 'GT',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.channel_id > 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field ChannelID / Operator LTE',
            Search       => {
                Field    => 'ChannelID',
                Operator => 'LTE',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.channel_id <= 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field ChannelID / Operator GTE',
            Search       => {
                Field    => 'ChannelID',
                Operator => 'GTE',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.channel_id >= 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Channel / Operator EQ',
            Search       => {
                Field    => 'Channel',
                Operator => 'EQ',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN channel tac ON tac.id = ta.channel_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(tac.name) = \'test\'' : 'tac.name = \'test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Channel / Operator EQ / Value empty string',
            Search       => {
                Field    => 'Channel',
                Operator => 'EQ',
                Value    => ''
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN channel tac ON tac.id = ta.channel_id'
                ],
                'Where' => [
                    $CaseSensitive ? '(LOWER(tac.name) = \'\' OR tac.name IS NULL)' : '(tac.name = \'\' OR tac.name IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Channel / Operator NE',
            Search       => {
                Field    => 'Channel',
                Operator => 'NE',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN channel tac ON tac.id = ta.channel_id'
                ],
                'Where' => [
                    $CaseSensitive ? '(LOWER(tac.name) != \'test\' OR tac.name IS NULL)' : '(tac.name != \'test\' OR tac.name IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Channel / Operator NE / Value empty string',
            Search       => {
                Field    => 'Channel',
                Operator => 'NE',
                Value    => ''
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN channel tac ON tac.id = ta.channel_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(tac.name) != \'\'' : 'tac.name != \'\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Channel / Operator IN',
            Search       => {
                Field    => 'Channel',
                Operator => 'IN',
                Value    => ['Test']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN channel tac ON tac.id = ta.channel_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(tac.name) IN (\'test\')' : 'tac.name IN (\'test\')'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Channel / Operator !IN',
            Search       => {
                Field    => 'Channel',
                Operator => '!IN',
                Value    => ['Test']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN channel tac ON tac.id = ta.channel_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(tac.name) NOT IN (\'test\')' : 'tac.name NOT IN (\'test\')'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Channel / Operator STARTSWITH',
            Search       => {
                Field    => 'Channel',
                Operator => 'STARTSWITH',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN channel tac ON tac.id = ta.channel_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(tac.name) LIKE \'test%\'' : 'tac.name LIKE \'test%\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Channel / Operator ENDSWITH',
            Search       => {
                Field    => 'Channel',
                Operator => 'ENDSWITH',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN channel tac ON tac.id = ta.channel_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(tac.name) LIKE \'%test\'' : 'tac.name LIKE \'%test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Channel / Operator CONTAINS',
            Search       => {
                Field    => 'Channel',
                Operator => 'CONTAINS',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN channel tac ON tac.id = ta.channel_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(tac.name) LIKE \'%test%\'' : 'tac.name LIKE \'%test%\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Channel / Operator LIKE',
            Search       => {
                Field    => 'Channel',
                Operator => 'LIKE',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN channel tac ON tac.id = ta.channel_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(tac.name) LIKE \'test\'' : 'tac.name LIKE \'test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field SenderTypeID / Operator EQ',
            Search       => {
                Field    => 'SenderTypeID',
                Operator => 'EQ',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.article_sender_type_id = 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field SenderTypeID / Operator EQ / Value zero',
            Search       => {
                Field    => 'SenderTypeID',
                Operator => 'EQ',
                Value    => '0'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    '(ta.article_sender_type_id = 0 OR ta.article_sender_type_id IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field SenderTypeID / Operator NE',
            Search       => {
                Field    => 'SenderTypeID',
                Operator => 'NE',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    '(ta.article_sender_type_id <> 1 OR ta.article_sender_type_id IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field SenderTypeID / Operator NE / Value zero',
            Search       => {
                Field    => 'SenderTypeID',
                Operator => 'NE',
                Value    => '0'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.article_sender_type_id <> 0'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field SenderTypeID / Operator IN',
            Search       => {
                Field    => 'SenderTypeID',
                Operator => 'IN',
                Value    => ['1']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.article_sender_type_id IN (1)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field SenderTypeID / Operator !IN',
            Search       => {
                Field    => 'SenderTypeID',
                Operator => '!IN',
                Value    => ['1']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.article_sender_type_id NOT IN (1)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field SenderTypeID / Operator LT',
            Search       => {
                Field    => 'SenderTypeID',
                Operator => 'LT',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.article_sender_type_id < 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field SenderTypeID / Operator GT',
            Search       => {
                Field    => 'SenderTypeID',
                Operator => 'GT',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.article_sender_type_id > 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field SenderTypeID / Operator LTE',
            Search       => {
                Field    => 'SenderTypeID',
                Operator => 'LTE',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.article_sender_type_id <= 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field SenderTypeID / Operator GTE',
            Search       => {
                Field    => 'SenderTypeID',
                Operator => 'GTE',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.article_sender_type_id >= 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field SenderType / Operator EQ',
            Search       => {
                Field    => 'SenderType',
                Operator => 'EQ',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN article_sender_type tast ON tast.id = ta.article_sender_type_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(tast.name) = \'test\'' : 'tast.name = \'test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field SenderType / Operator EQ / Value empty string',
            Search       => {
                Field    => 'SenderType',
                Operator => 'EQ',
                Value    => ''
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN article_sender_type tast ON tast.id = ta.article_sender_type_id'
                ],
                'Where' => [
                    $CaseSensitive ? '(LOWER(tast.name) = \'\' OR tast.name IS NULL)' : '(tast.name = \'\' OR tast.name IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field SenderType / Operator NE',
            Search       => {
                Field    => 'SenderType',
                Operator => 'NE',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN article_sender_type tast ON tast.id = ta.article_sender_type_id'
                ],
                'Where' => [
                    $CaseSensitive ? '(LOWER(tast.name) != \'test\' OR tast.name IS NULL)' : '(tast.name != \'test\' OR tast.name IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field SenderType / Operator NE / Value empty string',
            Search       => {
                Field    => 'SenderType',
                Operator => 'NE',
                Value    => ''
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN article_sender_type tast ON tast.id = ta.article_sender_type_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(tast.name) != \'\'' : 'tast.name != \'\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field SenderType / Operator IN',
            Search       => {
                Field    => 'SenderType',
                Operator => 'IN',
                Value    => ['Test']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN article_sender_type tast ON tast.id = ta.article_sender_type_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(tast.name) IN (\'test\')' : 'tast.name IN (\'test\')'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field SenderType / Operator !IN',
            Search       => {
                Field    => 'SenderType',
                Operator => '!IN',
                Value    => ['Test']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN article_sender_type tast ON tast.id = ta.article_sender_type_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(tast.name) NOT IN (\'test\')' : 'tast.name NOT IN (\'test\')'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field SenderType / Operator STARTSWITH',
            Search       => {
                Field    => 'SenderType',
                Operator => 'STARTSWITH',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN article_sender_type tast ON tast.id = ta.article_sender_type_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(tast.name) LIKE \'test%\'' : 'tast.name LIKE \'test%\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field SenderType / Operator ENDSWITH',
            Search       => {
                Field    => 'SenderType',
                Operator => 'ENDSWITH',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN article_sender_type tast ON tast.id = ta.article_sender_type_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(tast.name) LIKE \'%test\'' : 'tast.name LIKE \'%test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field SenderType / Operator CONTAINS',
            Search       => {
                Field    => 'SenderType',
                Operator => 'CONTAINS',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN article_sender_type tast ON tast.id = ta.article_sender_type_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(tast.name) LIKE \'%test%\'' : 'tast.name LIKE \'%test%\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field SenderType / Operator LIKE',
            Search       => {
                Field    => 'SenderType',
                Operator => 'LIKE',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN article_sender_type tast ON tast.id = ta.article_sender_type_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(tast.name) LIKE \'test\'' : 'tast.name LIKE \'test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field CustomerVisible / Operator EQ',
            Search       => {
                Field    => 'CustomerVisible',
                Operator => 'EQ',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.customer_visible = 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field CustomerVisible / Operator EQ / Value zero',
            Search       => {
                Field    => 'CustomerVisible',
                Operator => 'EQ',
                Value    => '0'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    '(ta.customer_visible = 0 OR ta.customer_visible IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field CustomerVisible / Operator NE',
            Search       => {
                Field    => 'CustomerVisible',
                Operator => 'NE',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    '(ta.customer_visible <> 1 OR ta.customer_visible IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field CustomerVisible / Operator NE / Value zero',
            Search       => {
                Field    => 'CustomerVisible',
                Operator => 'NE',
                Value    => '0'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.customer_visible <> 0'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field CustomerVisible / Operator IN',
            Search       => {
                Field    => 'CustomerVisible',
                Operator => 'IN',
                Value    => ['1']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.customer_visible IN (1)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field CustomerVisible / Operator !IN',
            Search       => {
                Field    => 'CustomerVisible',
                Operator => '!IN',
                Value    => ['1']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.customer_visible NOT IN (1)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field CustomerVisible / Operator LT',
            Search       => {
                Field    => 'CustomerVisible',
                Operator => 'LT',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.customer_visible < 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field CustomerVisible / Operator GT',
            Search       => {
                Field    => 'CustomerVisible',
                Operator => 'GT',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.customer_visible > 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field CustomerVisible / Operator LTE',
            Search       => {
                Field    => 'CustomerVisible',
                Operator => 'LTE',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.customer_visible <= 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field CustomerVisible / Operator GTE',
            Search       => {
                Field    => 'CustomerVisible',
                Operator => 'GTE',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.customer_visible >= 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field From / Operator EQ',
            Search       => {
                Field    => 'From',
                Operator => 'EQ',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_from) = \'test\'' : 'ta.a_from = \'test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field From / Operator EQ / Value empty string',
            Search       => {
                Field    => 'From',
                Operator => 'EQ',
                Value    => ''
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? '(LOWER(ta.a_from) = \'\' OR ta.a_from IS NULL)' : '(ta.a_from = \'\' OR ta.a_from IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field From / Operator NE',
            Search       => {
                Field    => 'From',
                Operator => 'NE',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? '(LOWER(ta.a_from) != \'test\' OR ta.a_from IS NULL)' : '(ta.a_from != \'test\' OR ta.a_from IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field From / Operator NE / Value empty string',
            Search       => {
                Field    => 'From',
                Operator => 'NE',
                Value    => ''
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_from) != \'\'' : 'ta.a_from != \'\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field From / Operator IN',
            Search       => {
                Field    => 'From',
                Operator => 'IN',
                Value    => ['Test']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_from) IN (\'test\')' : 'ta.a_from IN (\'test\')'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field From / Operator !IN',
            Search       => {
                Field    => 'From',
                Operator => '!IN',
                Value    => ['Test']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_from) NOT IN (\'test\')' : 'ta.a_from NOT IN (\'test\')'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field From / Operator STARTSWITH',
            Search       => {
                Field    => 'From',
                Operator => 'STARTSWITH',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_from) LIKE \'test%\'' : 'ta.a_from LIKE \'test%\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field From / Operator ENDSWITH',
            Search       => {
                Field    => 'From',
                Operator => 'ENDSWITH',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_from) LIKE \'%test\'' : 'ta.a_from LIKE \'%test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field From / Operator CONTAINS',
            Search       => {
                Field    => 'From',
                Operator => 'CONTAINS',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_from) LIKE \'%test%\'' : 'ta.a_from LIKE \'%test%\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field From / Operator LIKE',
            Search       => {
                Field    => 'From',
                Operator => 'LIKE',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_from) LIKE \'test\'' : 'ta.a_from LIKE \'test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field To / Operator EQ',
            Search       => {
                Field    => 'To',
                Operator => 'EQ',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_to) = \'test\'' : 'ta.a_to = \'test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field To / Operator EQ / Value empty string',
            Search       => {
                Field    => 'To',
                Operator => 'EQ',
                Value    => ''
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? '(LOWER(ta.a_to) = \'\' OR ta.a_to IS NULL)' : '(ta.a_to = \'\' OR ta.a_to IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field To / Operator NE',
            Search       => {
                Field    => 'To',
                Operator => 'NE',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? '(LOWER(ta.a_to) != \'test\' OR ta.a_to IS NULL)' : '(ta.a_to != \'test\' OR ta.a_to IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field To / Operator NE / Value empty string',
            Search       => {
                Field    => 'To',
                Operator => 'NE',
                Value    => ''
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_to) != \'\'' : 'ta.a_to != \'\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field To / Operator IN',
            Search       => {
                Field    => 'To',
                Operator => 'IN',
                Value    => ['Test']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_to) IN (\'test\')' : 'ta.a_to IN (\'test\')'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field To / Operator !IN',
            Search       => {
                Field    => 'To',
                Operator => '!IN',
                Value    => ['Test']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_to) NOT IN (\'test\')' : 'ta.a_to NOT IN (\'test\')'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field To / Operator STARTSWITH',
            Search       => {
                Field    => 'To',
                Operator => 'STARTSWITH',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_to) LIKE \'test%\'' : 'ta.a_to LIKE \'test%\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field To / Operator ENDSWITH',
            Search       => {
                Field    => 'To',
                Operator => 'ENDSWITH',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_to) LIKE \'%test\'' : 'ta.a_to LIKE \'%test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field To / Operator CONTAINS',
            Search       => {
                Field    => 'To',
                Operator => 'CONTAINS',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_to) LIKE \'%test%\'' : 'ta.a_to LIKE \'%test%\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field To / Operator LIKE',
            Search       => {
                Field    => 'To',
                Operator => 'LIKE',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_to) LIKE \'test\'' : 'ta.a_to LIKE \'test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Cc / Operator EQ',
            Search       => {
                Field    => 'Cc',
                Operator => 'EQ',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_cc) = \'test\'' : 'ta.a_cc = \'test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Cc / Operator EQ / Value empty string',
            Search       => {
                Field    => 'Cc',
                Operator => 'EQ',
                Value    => ''
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? '(LOWER(ta.a_cc) = \'\' OR ta.a_cc IS NULL)' : '(ta.a_cc = \'\' OR ta.a_cc IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Cc / Operator NE',
            Search       => {
                Field    => 'Cc',
                Operator => 'NE',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? '(LOWER(ta.a_cc) != \'test\' OR ta.a_cc IS NULL)' : '(ta.a_cc != \'test\' OR ta.a_cc IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Cc / Operator NE / Value empty string',
            Search       => {
                Field    => 'Cc',
                Operator => 'NE',
                Value    => ''
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_cc) != \'\'' : 'ta.a_cc != \'\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Cc / Operator IN',
            Search       => {
                Field    => 'Cc',
                Operator => 'IN',
                Value    => ['Test']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_cc) IN (\'test\')' : 'ta.a_cc IN (\'test\')'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Cc / Operator !IN',
            Search       => {
                Field    => 'Cc',
                Operator => '!IN',
                Value    => ['Test']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_cc) NOT IN (\'test\')' : 'ta.a_cc NOT IN (\'test\')'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Cc / Operator STARTSWITH',
            Search       => {
                Field    => 'Cc',
                Operator => 'STARTSWITH',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_cc) LIKE \'test%\'' : 'ta.a_cc LIKE \'test%\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Cc / Operator ENDSWITH',
            Search       => {
                Field    => 'Cc',
                Operator => 'ENDSWITH',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_cc) LIKE \'%test\'' : 'ta.a_cc LIKE \'%test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Cc / Operator CONTAINS',
            Search       => {
                Field    => 'Cc',
                Operator => 'CONTAINS',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_cc) LIKE \'%test%\'' : 'ta.a_cc LIKE \'%test%\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Cc / Operator LIKE',
            Search       => {
                Field    => 'Cc',
                Operator => 'LIKE',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_cc) LIKE \'test\'' : 'ta.a_cc LIKE \'test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Subject / Operator EQ',
            Search       => {
                Field    => 'Subject',
                Operator => 'EQ',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_subject) = \'test\'' : 'ta.a_subject = \'test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Subject / Operator EQ / Value empty string',
            Search       => {
                Field    => 'Subject',
                Operator => 'EQ',
                Value    => ''
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? '(LOWER(ta.a_subject) = \'\' OR ta.a_subject IS NULL)' : '(ta.a_subject = \'\' OR ta.a_subject IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Subject / Operator NE',
            Search       => {
                Field    => 'Subject',
                Operator => 'NE',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? '(LOWER(ta.a_subject) != \'test\' OR ta.a_subject IS NULL)' : '(ta.a_subject != \'test\' OR ta.a_subject IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Subject / Operator NE / Value empty string',
            Search       => {
                Field    => 'Subject',
                Operator => 'NE',
                Value    => ''
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_subject) != \'\'' : 'ta.a_subject != \'\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Subject / Operator IN',
            Search       => {
                Field    => 'Subject',
                Operator => 'IN',
                Value    => ['Test']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_subject) IN (\'test\')' : 'ta.a_subject IN (\'test\')'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Subject / Operator !IN',
            Search       => {
                Field    => 'Subject',
                Operator => '!IN',
                Value    => ['Test']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_subject) NOT IN (\'test\')' : 'ta.a_subject NOT IN (\'test\')'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Subject / Operator STARTSWITH',
            Search       => {
                Field    => 'Subject',
                Operator => 'STARTSWITH',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_subject) LIKE \'test%\'' : 'ta.a_subject LIKE \'test%\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Subject / Operator ENDSWITH',
            Search       => {
                Field    => 'Subject',
                Operator => 'ENDSWITH',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_subject) LIKE \'%test\'' : 'ta.a_subject LIKE \'%test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Subject / Operator CONTAINS',
            Search       => {
                Field    => 'Subject',
                Operator => 'CONTAINS',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_subject) LIKE \'%test%\'' : 'ta.a_subject LIKE \'%test%\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Subject / Operator LIKE',
            Search       => {
                Field    => 'Subject',
                Operator => 'LIKE',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_subject) LIKE \'test\'' : 'ta.a_subject LIKE \'test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Body / Operator EQ',
            Search       => {
                Field    => 'Body',
                Operator => 'EQ',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_body) = \'test\'' : 'ta.a_body = \'test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Body / Operator EQ / Value empty string',
            Search       => {
                Field    => 'Body',
                Operator => 'EQ',
                Value    => ''
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? '(LOWER(ta.a_body) = \'\' OR ta.a_body IS NULL)' : '(ta.a_body = \'\' OR ta.a_body IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Body / Operator NE',
            Search       => {
                Field    => 'Body',
                Operator => 'NE',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? '(LOWER(ta.a_body) != \'test\' OR ta.a_body IS NULL)' : '(ta.a_body != \'test\' OR ta.a_body IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Body / Operator NE / Value empty string',
            Search       => {
                Field    => 'Body',
                Operator => 'NE',
                Value    => ''
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_body) != \'\'' : 'ta.a_body != \'\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Body / Operator IN',
            Search       => {
                Field    => 'Body',
                Operator => 'IN',
                Value    => ['Test']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_body) IN (\'test\')' : 'ta.a_body IN (\'test\')'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Body / Operator !IN',
            Search       => {
                Field    => 'Body',
                Operator => '!IN',
                Value    => ['Test']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_body) NOT IN (\'test\')' : 'ta.a_body NOT IN (\'test\')'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Body / Operator STARTSWITH',
            Search       => {
                Field    => 'Body',
                Operator => 'STARTSWITH',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_body) LIKE \'test%\'' : 'ta.a_body LIKE \'test%\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Body / Operator ENDSWITH',
            Search       => {
                Field    => 'Body',
                Operator => 'ENDSWITH',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_body) LIKE \'%test\'' : 'ta.a_body LIKE \'%test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Body / Operator CONTAINS',
            Search       => {
                Field    => 'Body',
                Operator => 'CONTAINS',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_body) LIKE \'%test%\'' : 'ta.a_body LIKE \'%test%\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field Body / Operator LIKE',
            Search       => {
                Field    => 'Body',
                Operator => 'LIKE',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(ta.a_body) LIKE \'test\'' : 'ta.a_body LIKE \'test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field ArticleCreateTime / Operator EQ / absolute value',
            Search       => {
                Field    => 'ArticleCreateTime',
                Operator => 'EQ',
                Value    => '2014-01-01 12:00:00'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.incoming_time = ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '2014-01-01 12:00:00')
                ],
                'IsRelative' => undef
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field ArticleCreateTime / Operator EQ / relative value',
            Search       => {
                Field    => 'ArticleCreateTime',
                Operator => 'EQ',
                Value    => '+1h'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.incoming_time = ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '+1h')
                ],
                'IsRelative' => 1
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field ArticleCreateTime / Operator LT / absolute value',
            Search       => {
                Field    => 'ArticleCreateTime',
                Operator => 'LT',
                Value    => '2014-01-01 12:00:00'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.incoming_time < ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '2014-01-01 12:00:00')
                ],
                'IsRelative' => undef
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field ArticleCreateTime / Operator LT / relative value',
            Search       => {
                Field    => 'ArticleCreateTime',
                Operator => 'LT',
                Value    => '+1h'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.incoming_time < ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '+1h')
                ],
                'IsRelative' => 1
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field ArticleCreateTime / Operator GT / absolute value',
            Search       => {
                Field    => 'ArticleCreateTime',
                Operator => 'GT',
                Value    => '2014-01-01 12:00:00'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.incoming_time > ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '2014-01-01 12:00:00')
                ],
                'IsRelative' => undef
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field ArticleCreateTime / Operator GT / relative value',
            Search       => {
                Field    => 'ArticleCreateTime',
                Operator => 'GT',
                Value    => '+1h'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.incoming_time > ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '+1h')
                ],
                'IsRelative' => 1
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field ArticleCreateTime / Operator LTE / absolute value',
            Search       => {
                Field    => 'ArticleCreateTime',
                Operator => 'LTE',
                Value    => '2014-01-01 12:00:00'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.incoming_time <= ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '2014-01-01 12:00:00')
                ],
                'IsRelative' => undef
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field ArticleCreateTime / Operator LTE / relative value',
            Search       => {
                Field    => 'ArticleCreateTime',
                Operator => 'LTE',
                Value    => '+1h'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.incoming_time <= ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '+1h')
                ],
                'IsRelative' => 1
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field ArticleCreateTime / Operator GTE / absolute value',
            Search       => {
                Field    => 'ArticleCreateTime',
                Operator => 'GTE',
                Value    => '2014-01-01 12:00:00'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.incoming_time >= ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '2014-01-01 12:00:00')
                ],
                'IsRelative' => undef
            }
        },
        {
            Name         => 'Search: SearchIndexModule RuntimeDB / UserType ' . $UserType . ' / valid search / Field ArticleCreateTime / Operator GTE / relative value',
            Search       => {
                Field    => 'ArticleCreateTime',
                Operator => 'GTE',
                Value    => '+1h'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    'ta.incoming_time >= ' . $Kernel::OM->Get('Time')->TimeStamp2SystemTime(String => '+1h')
                ],
                'IsRelative' => 1
            }
        }
    );
    for my $Test ( @SearchTests ) {
        my $Result = $AttributeObject->Search(
            Search       => $Test->{Search},
            BoolOperator => 'AND',
            UserType     => $UserType,
            UserID       => 1,
            Silent       => defined( $Test->{Expected} ) ? 0 : 1
        );
        $Self->IsDeeply(
            $Result,
            $Test->{Expected},
            $Test->{Name}
        );
    }
}

# set config 'Ticket::SearchIndexModule' to StaticDB
$Kernel::OM->Get('Config')->Set(
    Key   => 'Ticket::SearchIndexModule',
    Value => 'Kernel::System::Ticket::ArticleSearchIndex::StaticDB'
);

# run tests for UserType 'Agent' and 'Customer'
for my $UserType ( qw(Agent Customer) ) {
    # prepare suffix for article join
    my $JoinArticleSuffix = '';
    if ( $UserType eq 'Customer' ) {
        $JoinArticleSuffix = ' AND s_ta.customer_visible = 1'
    }

    # define tests
    my @SearchTests = (
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / undef search',
            Search       => undef,
            Expected     => undef
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / Value undef',
            Search       => {
                Field    => 'ArticleID',
                Operator => 'EQ',
                Value    => undef

            },
            Expected     => undef
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / Value invalid',
            Search       => {
                Field    => 'ArticleID',
                Operator => 'EQ',
                Value    => 'Test'
            },
            Expected     => undef
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / Field undef',
            Search       => {
                Field    => undef,
                Operator => 'EQ',
                Value    => '1'
            },
            Expected     => undef
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / Field invalid',
            Search       => {
                Field    => 'Test',
                Operator => 'EQ',
                Value    => '1'
            },
            Expected     => undef
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / Operator undef',
            Search       => {
                Field    => 'ArticleID',
                Operator => undef,
                Value    => '1'
            },
            Expected     => undef
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / Operator invalid',
            Search       => {
                Field    => 'ArticleID',
                Operator => 'Test',
                Value    => '1'
            },
            Expected     => undef
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field ArticleID / Operator EQ',
            Search       => {
                Field    => 'ArticleID',
                Operator => 'EQ',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.id = 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field ArticleID / Operator EQ / Value zero',
            Search       => {
                Field    => 'ArticleID',
                Operator => 'EQ',
                Value    => '0'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    '(s_ta.id = 0 OR s_ta.id IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field ArticleID / Operator NE',
            Search       => {
                Field    => 'ArticleID',
                Operator => 'NE',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    '(s_ta.id <> 1 OR s_ta.id IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field ArticleID / Operator NE / Value zero',
            Search       => {
                Field    => 'ArticleID',
                Operator => 'NE',
                Value    => '0'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.id <> 0'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field ArticleID / Operator IN',
            Search       => {
                Field    => 'ArticleID',
                Operator => 'IN',
                Value    => ['1']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.id IN (1)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field ArticleID / Operator !IN',
            Search       => {
                Field    => 'ArticleID',
                Operator => '!IN',
                Value    => ['1']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.id NOT IN (1)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field ArticleID / Operator LT',
            Search       => {
                Field    => 'ArticleID',
                Operator => 'LT',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.id < 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field ArticleID / Operator GT',
            Search       => {
                Field    => 'ArticleID',
                Operator => 'GT',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.id > 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field ArticleID / Operator LTE',
            Search       => {
                Field    => 'ArticleID',
                Operator => 'LTE',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.id <= 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field ArticleID / Operator GTE',
            Search       => {
                Field    => 'ArticleID',
                Operator => 'GTE',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.id >= 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field ChannelID / Operator EQ',
            Search       => {
                Field    => 'ChannelID',
                Operator => 'EQ',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.channel_id = 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field ChannelID / Operator EQ / Value zero',
            Search       => {
                Field    => 'ChannelID',
                Operator => 'EQ',
                Value    => '0'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    '(s_ta.channel_id = 0 OR s_ta.channel_id IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field ChannelID / Operator NE',
            Search       => {
                Field    => 'ChannelID',
                Operator => 'NE',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    '(s_ta.channel_id <> 1 OR s_ta.channel_id IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field ChannelID / Operator NE / Value zero',
            Search       => {
                Field    => 'ChannelID',
                Operator => 'NE',
                Value    => '0'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.channel_id <> 0'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field ChannelID / Operator IN',
            Search       => {
                Field    => 'ChannelID',
                Operator => 'IN',
                Value    => ['1']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.channel_id IN (1)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field ChannelID / Operator !IN',
            Search       => {
                Field    => 'ChannelID',
                Operator => '!IN',
                Value    => ['1']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.channel_id NOT IN (1)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field ChannelID / Operator LT',
            Search       => {
                Field    => 'ChannelID',
                Operator => 'LT',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.channel_id < 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field ChannelID / Operator GT',
            Search       => {
                Field    => 'ChannelID',
                Operator => 'GT',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.channel_id > 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field ChannelID / Operator LTE',
            Search       => {
                Field    => 'ChannelID',
                Operator => 'LTE',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.channel_id <= 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field ChannelID / Operator GTE',
            Search       => {
                Field    => 'ChannelID',
                Operator => 'GTE',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.channel_id >= 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Channel / Operator EQ',
            Search       => {
                Field    => 'Channel',
                Operator => 'EQ',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN channel s_tac ON s_tac.id = s_ta.channel_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(s_tac.name) = \'test\'' : 's_tac.name = \'test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Channel / Operator EQ / Value empty string',
            Search       => {
                Field    => 'Channel',
                Operator => 'EQ',
                Value    => ''
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN channel s_tac ON s_tac.id = s_ta.channel_id'
                ],
                'Where' => [
                    $CaseSensitive ? '(LOWER(s_tac.name) = \'\' OR s_tac.name IS NULL)' : '(s_tac.name = \'\' OR s_tac.name IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Channel / Operator NE',
            Search       => {
                Field    => 'Channel',
                Operator => 'NE',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN channel s_tac ON s_tac.id = s_ta.channel_id'
                ],
                'Where' => [
                    $CaseSensitive ? '(LOWER(s_tac.name) != \'test\' OR s_tac.name IS NULL)' : '(s_tac.name != \'test\' OR s_tac.name IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Channel / Operator NE / Value empty string',
            Search       => {
                Field    => 'Channel',
                Operator => 'NE',
                Value    => ''
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN channel s_tac ON s_tac.id = s_ta.channel_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(s_tac.name) != \'\'' : 's_tac.name != \'\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Channel / Operator IN',
            Search       => {
                Field    => 'Channel',
                Operator => 'IN',
                Value    => ['Test']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN channel s_tac ON s_tac.id = s_ta.channel_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(s_tac.name) IN (\'test\')' : 's_tac.name IN (\'test\')'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Channel / Operator !IN',
            Search       => {
                Field    => 'Channel',
                Operator => '!IN',
                Value    => ['Test']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN channel s_tac ON s_tac.id = s_ta.channel_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(s_tac.name) NOT IN (\'test\')' : 's_tac.name NOT IN (\'test\')'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Channel / Operator STARTSWITH',
            Search       => {
                Field    => 'Channel',
                Operator => 'STARTSWITH',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN channel s_tac ON s_tac.id = s_ta.channel_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(s_tac.name) LIKE \'test%\'' : 's_tac.name LIKE \'test%\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Channel / Operator ENDSWITH',
            Search       => {
                Field    => 'Channel',
                Operator => 'ENDSWITH',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN channel s_tac ON s_tac.id = s_ta.channel_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(s_tac.name) LIKE \'%test\'' : 's_tac.name LIKE \'%test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Channel / Operator CONTAINS',
            Search       => {
                Field    => 'Channel',
                Operator => 'CONTAINS',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN channel s_tac ON s_tac.id = s_ta.channel_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(s_tac.name) LIKE \'%test%\'' : 's_tac.name LIKE \'%test%\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Channel / Operator LIKE',
            Search       => {
                Field    => 'Channel',
                Operator => 'LIKE',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN channel s_tac ON s_tac.id = s_ta.channel_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(s_tac.name) LIKE \'test\'' : 's_tac.name LIKE \'test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field SenderTypeID / Operator EQ',
            Search       => {
                Field    => 'SenderTypeID',
                Operator => 'EQ',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.article_sender_type_id = 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field SenderTypeID / Operator EQ / Value zero',
            Search       => {
                Field    => 'SenderTypeID',
                Operator => 'EQ',
                Value    => '0'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    '(s_ta.article_sender_type_id = 0 OR s_ta.article_sender_type_id IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field SenderTypeID / Operator NE',
            Search       => {
                Field    => 'SenderTypeID',
                Operator => 'NE',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    '(s_ta.article_sender_type_id <> 1 OR s_ta.article_sender_type_id IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field SenderTypeID / Operator NE / Value zero',
            Search       => {
                Field    => 'SenderTypeID',
                Operator => 'NE',
                Value    => '0'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.article_sender_type_id <> 0'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field SenderTypeID / Operator IN',
            Search       => {
                Field    => 'SenderTypeID',
                Operator => 'IN',
                Value    => ['1']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.article_sender_type_id IN (1)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field SenderTypeID / Operator !IN',
            Search       => {
                Field    => 'SenderTypeID',
                Operator => '!IN',
                Value    => ['1']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.article_sender_type_id NOT IN (1)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field SenderTypeID / Operator LT',
            Search       => {
                Field    => 'SenderTypeID',
                Operator => 'LT',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.article_sender_type_id < 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field SenderTypeID / Operator GT',
            Search       => {
                Field    => 'SenderTypeID',
                Operator => 'GT',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.article_sender_type_id > 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field SenderTypeID / Operator LTE',
            Search       => {
                Field    => 'SenderTypeID',
                Operator => 'LTE',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.article_sender_type_id <= 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field SenderTypeID / Operator GTE',
            Search       => {
                Field    => 'SenderTypeID',
                Operator => 'GTE',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.article_sender_type_id >= 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field SenderType / Operator EQ',
            Search       => {
                Field    => 'SenderType',
                Operator => 'EQ',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN article_sender_type s_tast ON s_tast.id = s_ta.article_sender_type_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(s_tast.name) = \'test\'' : 's_tast.name = \'test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field SenderType / Operator EQ / Value empty string',
            Search       => {
                Field    => 'SenderType',
                Operator => 'EQ',
                Value    => ''
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN article_sender_type s_tast ON s_tast.id = s_ta.article_sender_type_id'
                ],
                'Where' => [
                    $CaseSensitive ? '(LOWER(s_tast.name) = \'\' OR s_tast.name IS NULL)' : '(s_tast.name = \'\' OR s_tast.name IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field SenderType / Operator NE',
            Search       => {
                Field    => 'SenderType',
                Operator => 'NE',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN article_sender_type s_tast ON s_tast.id = s_ta.article_sender_type_id'
                ],
                'Where' => [
                    $CaseSensitive ? '(LOWER(s_tast.name) != \'test\' OR s_tast.name IS NULL)' : '(s_tast.name != \'test\' OR s_tast.name IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field SenderType / Operator NE / Value empty string',
            Search       => {
                Field    => 'SenderType',
                Operator => 'NE',
                Value    => ''
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN article_sender_type s_tast ON s_tast.id = s_ta.article_sender_type_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(s_tast.name) != \'\'' : 's_tast.name != \'\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field SenderType / Operator IN',
            Search       => {
                Field    => 'SenderType',
                Operator => 'IN',
                Value    => ['Test']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN article_sender_type s_tast ON s_tast.id = s_ta.article_sender_type_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(s_tast.name) IN (\'test\')' : 's_tast.name IN (\'test\')'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field SenderType / Operator !IN',
            Search       => {
                Field    => 'SenderType',
                Operator => '!IN',
                Value    => ['Test']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN article_sender_type s_tast ON s_tast.id = s_ta.article_sender_type_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(s_tast.name) NOT IN (\'test\')' : 's_tast.name NOT IN (\'test\')'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field SenderType / Operator STARTSWITH',
            Search       => {
                Field    => 'SenderType',
                Operator => 'STARTSWITH',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN article_sender_type s_tast ON s_tast.id = s_ta.article_sender_type_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(s_tast.name) LIKE \'test%\'' : 's_tast.name LIKE \'test%\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field SenderType / Operator ENDSWITH',
            Search       => {
                Field    => 'SenderType',
                Operator => 'ENDSWITH',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN article_sender_type s_tast ON s_tast.id = s_ta.article_sender_type_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(s_tast.name) LIKE \'%test\'' : 's_tast.name LIKE \'%test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field SenderType / Operator CONTAINS',
            Search       => {
                Field    => 'SenderType',
                Operator => 'CONTAINS',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN article_sender_type s_tast ON s_tast.id = s_ta.article_sender_type_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(s_tast.name) LIKE \'%test%\'' : 's_tast.name LIKE \'%test%\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field SenderType / Operator LIKE',
            Search       => {
                Field    => 'SenderType',
                Operator => 'LIKE',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix,
                    'LEFT OUTER JOIN article_sender_type s_tast ON s_tast.id = s_ta.article_sender_type_id'
                ],
                'Where' => [
                    $CaseSensitive ? 'LOWER(s_tast.name) LIKE \'test\'' : 's_tast.name LIKE \'test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field CustomerVisible / Operator EQ',
            Search       => {
                Field    => 'CustomerVisible',
                Operator => 'EQ',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.customer_visible = 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field CustomerVisible / Operator EQ / Value zero',
            Search       => {
                Field    => 'CustomerVisible',
                Operator => 'EQ',
                Value    => '0'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    '(s_ta.customer_visible = 0 OR s_ta.customer_visible IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field CustomerVisible / Operator NE',
            Search       => {
                Field    => 'CustomerVisible',
                Operator => 'NE',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    '(s_ta.customer_visible <> 1 OR s_ta.customer_visible IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field CustomerVisible / Operator NE / Value zero',
            Search       => {
                Field    => 'CustomerVisible',
                Operator => 'NE',
                Value    => '0'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.customer_visible <> 0'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field CustomerVisible / Operator IN',
            Search       => {
                Field    => 'CustomerVisible',
                Operator => 'IN',
                Value    => ['1']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.customer_visible IN (1)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field CustomerVisible / Operator !IN',
            Search       => {
                Field    => 'CustomerVisible',
                Operator => '!IN',
                Value    => ['1']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.customer_visible NOT IN (1)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field CustomerVisible / Operator LT',
            Search       => {
                Field    => 'CustomerVisible',
                Operator => 'LT',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.customer_visible < 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field CustomerVisible / Operator GT',
            Search       => {
                Field    => 'CustomerVisible',
                Operator => 'GT',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.customer_visible > 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field CustomerVisible / Operator LTE',
            Search       => {
                Field    => 'CustomerVisible',
                Operator => 'LTE',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.customer_visible <= 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field CustomerVisible / Operator GTE',
            Search       => {
                Field    => 'CustomerVisible',
                Operator => 'GTE',
                Value    => '1'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.customer_visible >= 1'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field From / Operator EQ',
            Search       => {
                Field    => 'From',
                Operator => 'EQ',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_from = \'test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field From / Operator EQ / Value empty string',
            Search       => {
                Field    => 'From',
                Operator => 'EQ',
                Value    => ''
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    '(s_ta.a_from = \'\' OR s_ta.a_from IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field From / Operator NE',
            Search       => {
                Field    => 'From',
                Operator => 'NE',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    '(s_ta.a_from != \'test\' OR s_ta.a_from IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field From / Operator NE / Value empty string',
            Search       => {
                Field    => 'From',
                Operator => 'NE',
                Value    => ''
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_from != \'\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field From / Operator IN',
            Search       => {
                Field    => 'From',
                Operator => 'IN',
                Value    => ['Test']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_from IN (\'test\')'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field From / Operator !IN',
            Search       => {
                Field    => 'From',
                Operator => '!IN',
                Value    => ['Test']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_from NOT IN (\'test\')'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field From / Operator STARTSWITH',
            Search       => {
                Field    => 'From',
                Operator => 'STARTSWITH',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_from LIKE \'test%\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field From / Operator ENDSWITH',
            Search       => {
                Field    => 'From',
                Operator => 'ENDSWITH',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_from LIKE \'%test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field From / Operator CONTAINS',
            Search       => {
                Field    => 'From',
                Operator => 'CONTAINS',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_from LIKE \'%test%\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field From / Operator LIKE',
            Search       => {
                Field    => 'From',
                Operator => 'LIKE',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_from LIKE \'test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field To / Operator EQ',
            Search       => {
                Field    => 'To',
                Operator => 'EQ',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_to = \'test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field To / Operator EQ / Value empty string',
            Search       => {
                Field    => 'To',
                Operator => 'EQ',
                Value    => ''
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    '(s_ta.a_to = \'\' OR s_ta.a_to IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field To / Operator NE',
            Search       => {
                Field    => 'To',
                Operator => 'NE',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    '(s_ta.a_to != \'test\' OR s_ta.a_to IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field To / Operator NE / Value empty string',
            Search       => {
                Field    => 'To',
                Operator => 'NE',
                Value    => ''
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_to != \'\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field To / Operator IN',
            Search       => {
                Field    => 'To',
                Operator => 'IN',
                Value    => ['Test']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_to IN (\'test\')'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field To / Operator !IN',
            Search       => {
                Field    => 'To',
                Operator => '!IN',
                Value    => ['Test']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_to NOT IN (\'test\')'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field To / Operator STARTSWITH',
            Search       => {
                Field    => 'To',
                Operator => 'STARTSWITH',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_to LIKE \'test%\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field To / Operator ENDSWITH',
            Search       => {
                Field    => 'To',
                Operator => 'ENDSWITH',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_to LIKE \'%test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field To / Operator CONTAINS',
            Search       => {
                Field    => 'To',
                Operator => 'CONTAINS',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_to LIKE \'%test%\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field To / Operator LIKE',
            Search       => {
                Field    => 'To',
                Operator => 'LIKE',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_to LIKE \'test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Cc / Operator EQ',
            Search       => {
                Field    => 'Cc',
                Operator => 'EQ',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_cc = \'test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Cc / Operator EQ / Value empty string',
            Search       => {
                Field    => 'Cc',
                Operator => 'EQ',
                Value    => ''
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    '(s_ta.a_cc = \'\' OR s_ta.a_cc IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Cc / Operator NE',
            Search       => {
                Field    => 'Cc',
                Operator => 'NE',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    '(s_ta.a_cc != \'test\' OR s_ta.a_cc IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Cc / Operator NE / Value empty string',
            Search       => {
                Field    => 'Cc',
                Operator => 'NE',
                Value    => ''
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_cc != \'\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Cc / Operator IN',
            Search       => {
                Field    => 'Cc',
                Operator => 'IN',
                Value    => ['Test']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_cc IN (\'test\')'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Cc / Operator !IN',
            Search       => {
                Field    => 'Cc',
                Operator => '!IN',
                Value    => ['Test']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_cc NOT IN (\'test\')'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Cc / Operator STARTSWITH',
            Search       => {
                Field    => 'Cc',
                Operator => 'STARTSWITH',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_cc LIKE \'test%\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Cc / Operator ENDSWITH',
            Search       => {
                Field    => 'Cc',
                Operator => 'ENDSWITH',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_cc LIKE \'%test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Cc / Operator CONTAINS',
            Search       => {
                Field    => 'Cc',
                Operator => 'CONTAINS',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_cc LIKE \'%test%\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Cc / Operator LIKE',
            Search       => {
                Field    => 'Cc',
                Operator => 'LIKE',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_cc LIKE \'test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Subject / Operator EQ',
            Search       => {
                Field    => 'Subject',
                Operator => 'EQ',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_subject = \'test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Subject / Operator EQ / Value empty string',
            Search       => {
                Field    => 'Subject',
                Operator => 'EQ',
                Value    => ''
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    '(s_ta.a_subject = \'\' OR s_ta.a_subject IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Subject / Operator NE',
            Search       => {
                Field    => 'Subject',
                Operator => 'NE',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    '(s_ta.a_subject != \'test\' OR s_ta.a_subject IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Subject / Operator NE / Value empty string',
            Search       => {
                Field    => 'Subject',
                Operator => 'NE',
                Value    => ''
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_subject != \'\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Subject / Operator IN',
            Search       => {
                Field    => 'Subject',
                Operator => 'IN',
                Value    => ['Test']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_subject IN (\'test\')'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Subject / Operator !IN',
            Search       => {
                Field    => 'Subject',
                Operator => '!IN',
                Value    => ['Test']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_subject NOT IN (\'test\')'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Subject / Operator STARTSWITH',
            Search       => {
                Field    => 'Subject',
                Operator => 'STARTSWITH',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_subject LIKE \'test%\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Subject / Operator ENDSWITH',
            Search       => {
                Field    => 'Subject',
                Operator => 'ENDSWITH',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_subject LIKE \'%test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Subject / Operator CONTAINS',
            Search       => {
                Field    => 'Subject',
                Operator => 'CONTAINS',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_subject LIKE \'%test%\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Subject / Operator LIKE',
            Search       => {
                Field    => 'Subject',
                Operator => 'LIKE',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_subject LIKE \'test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Body / Operator EQ',
            Search       => {
                Field    => 'Body',
                Operator => 'EQ',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_body = \'test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Body / Operator EQ / Value empty string',
            Search       => {
                Field    => 'Body',
                Operator => 'EQ',
                Value    => ''
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    '(s_ta.a_body = \'\' OR s_ta.a_body IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Body / Operator NE',
            Search       => {
                Field    => 'Body',
                Operator => 'NE',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    '(s_ta.a_body != \'test\' OR s_ta.a_body IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Body / Operator NE / Value empty string',
            Search       => {
                Field    => 'Body',
                Operator => 'NE',
                Value    => ''
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_body != \'\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Body / Operator IN',
            Search       => {
                Field    => 'Body',
                Operator => 'IN',
                Value    => ['Test']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_body IN (\'test\')'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Body / Operator !IN',
            Search       => {
                Field    => 'Body',
                Operator => '!IN',
                Value    => ['Test']
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_body NOT IN (\'test\')'
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Body / Operator STARTSWITH',
            Search       => {
                Field    => 'Body',
                Operator => 'STARTSWITH',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_body LIKE \'test%\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Body / Operator ENDSWITH',
            Search       => {
                Field    => 'Body',
                Operator => 'ENDSWITH',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_body LIKE \'%test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Body / Operator CONTAINS',
            Search       => {
                Field    => 'Body',
                Operator => 'CONTAINS',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_body LIKE \'%test%\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field Body / Operator LIKE',
            Search       => {
                Field    => 'Body',
                Operator => 'LIKE',
                Value    => 'Test'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.a_body LIKE \'test\''
                ]
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field ArticleCreateTime / Operator EQ / absolute value',
            Search       => {
                Field    => 'ArticleCreateTime',
                Operator => 'EQ',
                Value    => '2014-01-01 12:00:00'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.incoming_time = 1388574000'
                ],
                'IsRelative' => undef
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field ArticleCreateTime / Operator EQ / relative value',
            Search       => {
                Field    => 'ArticleCreateTime',
                Operator => 'EQ',
                Value    => '+1h'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.incoming_time = 1388577600'
                ],
                'IsRelative' => 1
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field ArticleCreateTime / Operator LT / absolute value',
            Search       => {
                Field    => 'ArticleCreateTime',
                Operator => 'LT',
                Value    => '2014-01-01 12:00:00'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.incoming_time < 1388574000'
                ],
                'IsRelative' => undef
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field ArticleCreateTime / Operator LT / relative value',
            Search       => {
                Field    => 'ArticleCreateTime',
                Operator => 'LT',
                Value    => '+1h'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.incoming_time < 1388577600'
                ],
                'IsRelative' => 1
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field ArticleCreateTime / Operator GT / absolute value',
            Search       => {
                Field    => 'ArticleCreateTime',
                Operator => 'GT',
                Value    => '2014-01-01 12:00:00'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.incoming_time > 1388574000'
                ],
                'IsRelative' => undef
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field ArticleCreateTime / Operator GT / relative value',
            Search       => {
                Field    => 'ArticleCreateTime',
                Operator => 'GT',
                Value    => '+1h'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.incoming_time > 1388577600'
                ],
                'IsRelative' => 1
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field ArticleCreateTime / Operator LTE / absolute value',
            Search       => {
                Field    => 'ArticleCreateTime',
                Operator => 'LTE',
                Value    => '2014-01-01 12:00:00'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.incoming_time <= 1388574000'
                ],
                'IsRelative' => undef
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field ArticleCreateTime / Operator LTE / relative value',
            Search       => {
                Field    => 'ArticleCreateTime',
                Operator => 'LTE',
                Value    => '+1h'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.incoming_time <= 1388577600'
                ],
                'IsRelative' => 1
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field ArticleCreateTime / Operator GTE / absolute value',
            Search       => {
                Field    => 'ArticleCreateTime',
                Operator => 'GTE',
                Value    => '2014-01-01 12:00:00'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.incoming_time >= 1388574000'
                ],
                'IsRelative' => undef
            }
        },
        {
            Name         => 'Search: SearchIndexModule StaticDB / UserType ' . $UserType . ' / valid search / Field ArticleCreateTime / Operator GTE / relative value',
            Search       => {
                Field    => 'ArticleCreateTime',
                Operator => 'GTE',
                Value    => '+1h'
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id' . $JoinArticleSuffix
                ],
                'Where' => [
                    's_ta.incoming_time >= 1388577600'
                ],
                'IsRelative' => 1
            }
        }
    );
    for my $Test ( @SearchTests ) {
        my $Result = $AttributeObject->Search(
            Search       => $Test->{Search},
            BoolOperator => 'AND',
            UserType     => $UserType,
            UserID       => 1,
            Silent       => defined( $Test->{Expected} ) ? 0 : 1
        );
        $Self->IsDeeply(
            $Result,
            $Test->{Expected},
            $Test->{Name}
        );
    }
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
        Name      => 'Sort: Attribute "ArticleID"',
        Attribute => 'ArticleID',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "ChannelID"',
        Attribute => 'ChannelID',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "Channel"',
        Attribute => 'Channel',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "SenderTypeID"',
        Attribute => 'SenderTypeID',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "SenderType"',
        Attribute => 'SenderType',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "CustomerVisible"',
        Attribute => 'CustomerVisible',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "From"',
        Attribute => 'From',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "To"',
        Attribute => 'To',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "Cc"',
        Attribute => 'Cc',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "Subject"',
        Attribute => 'Subject',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "Body"',
        Attribute => 'Body',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "ArticleCreateTime"',
        Attribute => 'ArticleCreateTime',
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
my $Body2           = 'You have to test again.';

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

# test Search for StaticDB
my @IntegrationSearchTestsStaticDB = (
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field ArticleID / Operator EQ / Value $ArticleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'EQ',
                    Value    => $ArticleID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field ArticleID / Operator NE / Value $ArticleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'NE',
                    Value    => $ArticleID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field ArticleID / Operator IN / Value [$ArticleID1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'IN',
                    Value    => [$ArticleID1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field ArticleID / Operator !IN / Value [$ArticleID1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => '!IN',
                    Value    => [$ArticleID1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field ArticleID / Operator LT / Value $ArticleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'LT',
                    Value    => $ArticleID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field ArticleID / Operator LTE / Value $ArticleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'LTE',
                    Value    => $ArticleID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field ArticleID / Operator GT / Value $ArticleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'GT',
                    Value    => $ArticleID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field ArticleID / Operator GTE / Value $ArticleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'GTE',
                    Value    => $ArticleID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field ArticleID / Operator EQ / Value $ArticleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'EQ',
                    Value    => $ArticleID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field ArticleID / Operator NE / Value $ArticleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'NE',
                    Value    => $ArticleID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field ArticleID / Operator IN / Value [$ArticleID1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'IN',
                    Value    => [$ArticleID1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field ArticleID / Operator !IN / Value [$ArticleID1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => '!IN',
                    Value    => [$ArticleID1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field ArticleID / Operator LT / Value $ArticleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'LT',
                    Value    => $ArticleID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field ArticleID / Operator LTE / Value $ArticleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'LTE',
                    Value    => $ArticleID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field ArticleID / Operator GT / Value $ArticleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'GT',
                    Value    => $ArticleID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field ArticleID / Operator GTE / Value $ArticleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'GTE',
                    Value    => $ArticleID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field ChannelID / Operator EQ / Value $ChannelID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => 'EQ',
                    Value    => $ChannelID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field ChannelID / Operator NE / Value $ChannelID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => 'NE',
                    Value    => $ChannelID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field ChannelID / Operator IN / Value [$ChannelID1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => 'IN',
                    Value    => [$ChannelID1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field ChannelID / Operator !IN / Value [$ChannelID1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => '!IN',
                    Value    => [$ChannelID1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field ChannelID / Operator LT / Value $ChannelID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => 'LT',
                    Value    => $ChannelID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field ChannelID / Operator LTE / Value $ChannelID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => 'LTE',
                    Value    => $ChannelID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field ChannelID / Operator GT / Value $ChannelID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => 'GT',
                    Value    => $ChannelID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field ChannelID / Operator GTE / Value $ChannelID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => 'GTE',
                    Value    => $ChannelID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field ChannelID / Operator EQ / Value $ChannelID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => 'EQ',
                    Value    => $ChannelID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field ChannelID / Operator NE / Value $ChannelID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => 'NE',
                    Value    => $ChannelID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field ChannelID / Operator IN / Value [$ChannelID1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => 'IN',
                    Value    => [$ChannelID1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field ChannelID / Operator !IN / Value [$ChannelID1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => '!IN',
                    Value    => [$ChannelID1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field ChannelID / Operator LT / Value $ChannelID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => 'LT',
                    Value    => $ChannelID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field ChannelID / Operator LTE / Value $ChannelID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => 'LTE',
                    Value    => $ChannelID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field ChannelID / Operator GT / Value $ChannelID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => 'GT',
                    Value    => $ChannelID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field ChannelID / Operator GTE / Value $ChannelID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => 'GTE',
                    Value    => $ChannelID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Channel / Operator EQ / Value $ChannelName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'EQ',
                    Value    => $ChannelName2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Channel / Operator NE / Value $ChannelName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'NE',
                    Value    => $ChannelName2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Channel / Operator IN / Value [$ChannelName1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'IN',
                    Value    => [$ChannelName1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Channel / Operator !IN / Value [$ChannelName1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => '!IN',
                    Value    => [$ChannelName1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Channel / Operator STARTSWITH / Value $ChannelName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'STARTSWITH',
                    Value    => $ChannelName2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Channel / Operator STARTSWITH / Value substr($ChannelName2,0,2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'STARTSWITH',
                    Value    => substr($ChannelName2,0,2)
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Channel / Operator ENDSWITH / Value $ChannelName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'ENDSWITH',
                    Value    => $ChannelName2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Channel / Operator ENDSWITH / Value substr($ChannelName2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'ENDSWITH',
                    Value    => substr($ChannelName2,-2)
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Channel / Operator CONTAINS / Value $ChannelName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'CONTAINS',
                    Value    => $ChannelName2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Channel / Operator CONTAINS / Value substr($ChannelName2,1,-1)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'CONTAINS',
                    Value    => substr($ChannelName2,1,-1)
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Channel / Operator LIKE / Value $ChannelName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'LIKE',
                    Value    => $ChannelName2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Channel / Operator EQ / Value $ChannelName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'EQ',
                    Value    => $ChannelName2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Channel / Operator NE / Value $ChannelName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'NE',
                    Value    => $ChannelName2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Channel / Operator IN / Value [$ChannelName1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'IN',
                    Value    => [$ChannelName1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Channel / Operator !IN / Value [$ChannelName1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => '!IN',
                    Value    => [$ChannelName1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Channel / Operator STARTSWITH / Value $ChannelName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'STARTSWITH',
                    Value    => $ChannelName2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Channel / Operator STARTSWITH / Value substr($ChannelName2,0,2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'STARTSWITH',
                    Value    => substr($ChannelName2,0,2)
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Channel / Operator ENDSWITH / Value $ChannelName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'ENDSWITH',
                    Value    => $ChannelName2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Channel / Operator ENDSWITH / Value substr($ChannelName2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'ENDSWITH',
                    Value    => substr($ChannelName2,-2)
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Channel / Operator CONTAINS / Value $ChannelName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'CONTAINS',
                    Value    => $ChannelName2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Channel / Operator CONTAINS / Value substr($ChannelName2,1,-1)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'CONTAINS',
                    Value    => substr($ChannelName2,1,-1)
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Channel / Operator LIKE / Value $ChannelName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'LIKE',
                    Value    => $ChannelName2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field SenderTypeID / Operator EQ / Value $SenderTypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => 'EQ',
                    Value    => $SenderTypeID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field SenderTypeID / Operator NE / Value $SenderTypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => 'NE',
                    Value    => $SenderTypeID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field SenderTypeID / Operator IN / Value [$SenderTypeID1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => 'IN',
                    Value    => [$SenderTypeID1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field SenderTypeID / Operator !IN / Value [$SenderTypeID1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => '!IN',
                    Value    => [$SenderTypeID1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field SenderTypeID / Operator LT / Value $SenderTypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => 'LT',
                    Value    => $SenderTypeID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field SenderTypeID / Operator LTE / Value $SenderTypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => 'LTE',
                    Value    => $SenderTypeID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field SenderTypeID / Operator GT / Value $SenderTypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => 'GT',
                    Value    => $SenderTypeID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field SenderTypeID / Operator GTE / Value $SenderTypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => 'GTE',
                    Value    => $SenderTypeID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field SenderTypeID / Operator EQ / Value $SenderTypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => 'EQ',
                    Value    => $SenderTypeID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field SenderTypeID / Operator NE / Value $SenderTypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => 'NE',
                    Value    => $SenderTypeID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field SenderTypeID / Operator IN / Value [$SenderTypeID1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => 'IN',
                    Value    => [$SenderTypeID1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field SenderTypeID / Operator !IN / Value [$SenderTypeID1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => '!IN',
                    Value    => [$SenderTypeID1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field SenderTypeID / Operator LT / Value $SenderTypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => 'LT',
                    Value    => $SenderTypeID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field SenderTypeID / Operator LTE / Value $SenderTypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => 'LTE',
                    Value    => $SenderTypeID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field SenderTypeID / Operator GT / Value $SenderTypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => 'GT',
                    Value    => $SenderTypeID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field SenderTypeID / Operator GTE / Value $SenderTypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => 'GTE',
                    Value    => $SenderTypeID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field SenderType / Operator EQ / Value $SenderTypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'EQ',
                    Value    => $SenderTypeName2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field SenderType / Operator NE / Value $SenderTypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'NE',
                    Value    => $SenderTypeName2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field SenderType / Operator IN / Value [$SenderTypeName1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'IN',
                    Value    => [$SenderTypeName1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field SenderType / Operator !IN / Value [$SenderTypeName1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => '!IN',
                    Value    => [$SenderTypeName1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field SenderType / Operator STARTSWITH / Value $SenderTypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'STARTSWITH',
                    Value    => $SenderTypeName2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field SenderType / Operator STARTSWITH / Value substr($SenderTypeName2,0,2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'STARTSWITH',
                    Value    => substr($SenderTypeName2,0,2)
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field SenderType / Operator ENDSWITH / Value $SenderTypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'ENDSWITH',
                    Value    => $SenderTypeName2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field SenderType / Operator ENDSWITH / Value substr($SenderTypeName2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'ENDSWITH',
                    Value    => substr($SenderTypeName2,-2)
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field SenderType / Operator CONTAINS / Value $SenderTypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'CONTAINS',
                    Value    => $SenderTypeName2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field SenderType / Operator CONTAINS / Value substr($SenderTypeName2,1,-1)',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'CONTAINS',
                    Value    => substr($SenderTypeName2,1,-1)
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field SenderType / Operator LIKE / Value $SenderTypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'LIKE',
                    Value    => $SenderTypeName2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field SenderType / Operator EQ / Value $SenderTypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'EQ',
                    Value    => $SenderTypeName2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field SenderType / Operator NE / Value $SenderTypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'NE',
                    Value    => $SenderTypeName2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field SenderType / Operator IN / Value [$SenderTypeName1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'IN',
                    Value    => [$SenderTypeName1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field SenderType / Operator !IN / Value [$SenderTypeName1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => '!IN',
                    Value    => [$SenderTypeName1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field SenderType / Operator STARTSWITH / Value $SenderTypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'STARTSWITH',
                    Value    => $SenderTypeName2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field SenderType / Operator STARTSWITH / Value substr($SenderTypeName2,0,2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'STARTSWITH',
                    Value    => substr($SenderTypeName2,0,2)
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field SenderType / Operator ENDSWITH / Value $SenderTypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'ENDSWITH',
                    Value    => $SenderTypeName2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field SenderType / Operator ENDSWITH / Value substr($SenderTypeName2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'ENDSWITH',
                    Value    => substr($SenderTypeName2,-2)
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field SenderType / Operator CONTAINS / Value $SenderTypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'CONTAINS',
                    Value    => $SenderTypeName2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field SenderType / Operator CONTAINS / Value substr($SenderTypeName2,1,-1)',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'CONTAINS',
                    Value    => substr($SenderTypeName2,1,-1)
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field SenderType / Operator LIKE / Value $SenderTypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'LIKE',
                    Value    => $SenderTypeName2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field CustomerVisible / Operator EQ / Value 0',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => 'EQ',
                    Value    => 0
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field CustomerVisible / Operator NE / Value 0',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => 'NE',
                    Value    => 0
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field CustomerVisible / Operator IN / Value [1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => 'IN',
                    Value    => [1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field CustomerVisible / Operator !IN / Value [1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => '!IN',
                    Value    => [1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field CustomerVisible / Operator LT / Value 1',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => 'LT',
                    Value    => 1
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field CustomerVisible / Operator LTE / Value 1',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => 'LTE',
                    Value    => 1
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field CustomerVisible / Operator GT / Value 0',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => 'GT',
                    Value    => 0
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field CustomerVisible / Operator GTE / Value 0',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => 'GTE',
                    Value    => 0
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field CustomerVisible / Operator EQ / Value 0',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => 'EQ',
                    Value    => 0
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field CustomerVisible / Operator NE / Value 0',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => 'NE',
                    Value    => 0
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field CustomerVisible / Operator IN / Value [1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => 'IN',
                    Value    => [1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field CustomerVisible / Operator !IN / Value [1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => '!IN',
                    Value    => [1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field CustomerVisible / Operator LT / Value 1',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => 'LT',
                    Value    => 1
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field CustomerVisible / Operator LTE / Value 1',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => 'LTE',
                    Value    => 1
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field CustomerVisible / Operator GT / Value 0',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => 'GT',
                    Value    => 0
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field CustomerVisible / Operator GTE / Value 0',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => 'GTE',
                    Value    => 0
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field From / Operator EQ / Value "customer customer@external.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'EQ',
                    Value    => 'customer customer@external.com'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field From / Operator NE / Value "customer customer@external.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'NE',
                    Value    => 'customer customer@external.com'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field From / Operator IN / Value ["agent agent@kixdesk.com"]',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'IN',
                    Value    => ['agent agent@kixdesk.com']
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field From / Operator !IN / Value ["agent agent@kixdesk.com"]',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => '!IN',
                    Value    => ['agent agent@kixdesk.com']
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field From / Operator STARTSWITH / Value "customer customer@external.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'STARTSWITH',
                    Value    => 'customer customer@external.com'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field From / Operator STARTSWITH / Value "customer"',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'STARTSWITH',
                    Value    => 'customer'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field From / Operator ENDSWITH / Value "customer customer@external.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'ENDSWITH',
                    Value    => 'customer customer@external.com'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field From / Operator ENDSWITH / Value "external.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'ENDSWITH',
                    Value    => 'external.com'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field From / Operator CONTAINS / Value "customer customer@external.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'CONTAINS',
                    Value    => 'customer customer@external.com'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field From / Operator CONTAINS / Value "mer@ext"',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'CONTAINS',
                    Value    => 'mer@ext'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field From / Operator LIKE / Value "customer customer@external.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'LIKE',
                    Value    => 'customer customer@external.com'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field From / Operator EQ / Value "customer customer@external.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'EQ',
                    Value    => 'customer customer@external.com'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field From / Operator NE / Value "customer customer@external.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'NE',
                    Value    => 'customer customer@external.com'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field From / Operator IN / Value ["agent agent@kixdesk.com"]',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'IN',
                    Value    => ['agent agent@kixdesk.com']
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field From / Operator !IN / Value ["agent agent@kixdesk.com"]',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => '!IN',
                    Value    => ['agent agent@kixdesk.com']
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field From / Operator STARTSWITH / Value "customer customer@external.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'STARTSWITH',
                    Value    => 'customer customer@external.com'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field From / Operator STARTSWITH / Value "customer"',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'STARTSWITH',
                    Value    => 'customer'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field From / Operator ENDSWITH / Value "customer customer@external.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'ENDSWITH',
                    Value    => 'customer customer@external.com'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field From / Operator ENDSWITH / Value "external.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'ENDSWITH',
                    Value    => 'external.com'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field From / Operator CONTAINS / Value "customer customer@external.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'CONTAINS',
                    Value    => 'customer customer@external.com'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field From / Operator CONTAINS / Value "mer@ext"',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'CONTAINS',
                    Value    => 'mer@ext'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field From / Operator LIKE / Value "customer customer@external.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'LIKE',
                    Value    => 'customer customer@external.com'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field To / Operator EQ / Value "agent agent@kixdesk.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'EQ',
                    Value    => 'agent agent@kixdesk.com'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field To / Operator NE / Value "agent agent@kixdesk.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'NE',
                    Value    => 'agent agent@kixdesk.com'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field To / Operator IN / Value ["customer customer@external.com"]',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'IN',
                    Value    => ['customer customer@external.com']
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field To / Operator !IN / Value ["customer customer@external.com"]',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => '!IN',
                    Value    => ['customer customer@external.com']
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field To / Operator STARTSWITH / Value "agent agent@kixdesk.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'STARTSWITH',
                    Value    => 'agent agent@kixdesk.com'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field To / Operator STARTSWITH / Value "agent"',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'STARTSWITH',
                    Value    => 'agent'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field To / Operator ENDSWITH / Value "agent agent@kixdesk.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'ENDSWITH',
                    Value    => 'agent agent@kixdesk.com'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field To / Operator ENDSWITH / Value "kixdesk.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'ENDSWITH',
                    Value    => 'kixdesk.com'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field To / Operator CONTAINS / Value "agent agent@kixdesk.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'CONTAINS',
                    Value    => 'agent agent@kixdesk.com'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field To / Operator CONTAINS / Value "ent@kix"',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'CONTAINS',
                    Value    => 'ent@kix'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field To / Operator LIKE / Value "agent agent@kixdesk.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'LIKE',
                    Value    => 'agent agent@kixdesk.com'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field To / Operator EQ / Value "agent agent@kixdesk.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'EQ',
                    Value    => 'agent agent@kixdesk.com'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field To / Operator NE / Value "agent agent@kixdesk.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'NE',
                    Value    => 'agent agent@kixdesk.com'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field To / Operator IN / Value ["customer customer@external.com"]',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'IN',
                    Value    => ['customer customer@external.com']
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field To / Operator !IN / Value ["customer customer@external.com"]',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => '!IN',
                    Value    => ['customer customer@external.com']
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field To / Operator STARTSWITH / Value "agent agent@kixdesk.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'STARTSWITH',
                    Value    => 'agent agent@kixdesk.com'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field To / Operator STARTSWITH / Value "agent"',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'STARTSWITH',
                    Value    => 'agent'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field To / Operator ENDSWITH / Value "agent agent@kixdesk.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'ENDSWITH',
                    Value    => 'agent agent@kixdesk.com'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field To / Operator ENDSWITH / Value "kixdesk.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'ENDSWITH',
                    Value    => 'kixdesk.com'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field To / Operator CONTAINS / Value "agent agent@kixdesk.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'CONTAINS',
                    Value    => 'agent agent@kixdesk.com'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field To / Operator CONTAINS / Value "ent@kix"',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'CONTAINS',
                    Value    => 'ent@kix'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field To / Operator LIKE / Value "agent agent@kixdesk.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'LIKE',
                    Value    => 'agent agent@kixdesk.com'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Cc / Operator EQ / Value "external external@external.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'EQ',
                    Value    => 'external external@external.com'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Cc / Operator NE / Value "external external@external.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'NE',
                    Value    => 'external external@external.com'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Cc / Operator IN / Value ["external external@external.com"]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'IN',
                    Value    => ['external external@external.com']
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Cc / Operator !IN / Value ["external external@external.com"]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => '!IN',
                    Value    => ['external external@external.com']
                }
            ]
        },
        UserType => 'Agent',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Cc / Operator STARTSWITH / Value "external external@external.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'STARTSWITH',
                    Value    => 'external external@external.com'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Cc / Operator STARTSWITH / Value "external"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'STARTSWITH',
                    Value    => 'external'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Cc / Operator ENDSWITH / Value "external external@external.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'ENDSWITH',
                    Value    => 'external external@external.com'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Cc / Operator ENDSWITH / Value "external.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'ENDSWITH',
                    Value    => 'external.com'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Cc / Operator CONTAINS / Value "external external@external.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'CONTAINS',
                    Value    => 'external external@external.com'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Cc / Operator CONTAINS / Value "nal@ext"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'CONTAINS',
                    Value    => 'nal@ext'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Cc / Operator LIKE / Value "external external@external.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'LIKE',
                    Value    => 'external external@external.com'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Cc / Operator EQ / Value "external external@external.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'EQ',
                    Value    => 'external external@external.com'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Cc / Operator NE / Value "external external@external.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'NE',
                    Value    => 'external external@external.com'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Cc / Operator IN / Value ["external external@external.com"]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'IN',
                    Value    => ['external external@external.com']
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Cc / Operator !IN / Value ["external external@external.com"]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => '!IN',
                    Value    => ['external external@external.com']
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Cc / Operator STARTSWITH / Value "external external@external.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'STARTSWITH',
                    Value    => 'external external@external.com'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Cc / Operator STARTSWITH / Value "external"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'STARTSWITH',
                    Value    => 'external'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Cc / Operator ENDSWITH / Value "external external@external.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'ENDSWITH',
                    Value    => 'external external@external.com'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Cc / Operator ENDSWITH / Value "external.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'ENDSWITH',
                    Value    => 'external.com'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Cc / Operator CONTAINS / Value "external external@external.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'CONTAINS',
                    Value    => 'external external@external.com'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Cc / Operator CONTAINS / Value "nal@ext"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'CONTAINS',
                    Value    => 'nal@ext'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Cc / Operator LIKE / Value "external external@external.com"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'LIKE',
                    Value    => 'external external@external.com'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Subject / Operator EQ / Value "Test2"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'EQ',
                    Value    => 'Test2'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Subject / Operator NE / Value "Test2"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'NE',
                    Value    => 'Test2'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Subject / Operator IN / Value ["Test1"]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'IN',
                    Value    => ['Test1']
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Subject / Operator !IN / Value ["Test1"]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => '!IN',
                    Value    => ['Test1']
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Subject / Operator STARTSWITH / Value "Test2"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'STARTSWITH',
                    Value    => 'Test2'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Subject / Operator STARTSWITH / Value "Test"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'STARTSWITH',
                    Value    => 'Test'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Subject / Operator ENDSWITH / Value "Test2"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'ENDSWITH',
                    Value    => 'Test2'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Subject / Operator ENDSWITH / Value "t2"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'ENDSWITH',
                    Value    => 't2'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Subject / Operator CONTAINS / Value "Test2"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'CONTAINS',
                    Value    => 'Test2'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Subject / Operator CONTAINS / Value "est"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'CONTAINS',
                    Value    => 'est'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Subject / Operator LIKE / Value "Test2"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'LIKE',
                    Value    => 'Test2'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Subject / Operator EQ / Value "Test2"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'EQ',
                    Value    => 'Test2'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Subject / Operator NE / Value "Test2"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'NE',
                    Value    => 'Test2'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Subject / Operator IN / Value ["Test1"]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'IN',
                    Value    => ['Test1']
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Subject / Operator !IN / Value ["Test1"]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => '!IN',
                    Value    => ['Test1']
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Subject / Operator STARTSWITH / Value "Test2"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'STARTSWITH',
                    Value    => 'Test2'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Subject / Operator STARTSWITH / Value "Test"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'STARTSWITH',
                    Value    => 'Test'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Subject / Operator ENDSWITH / Value "Test2"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'ENDSWITH',
                    Value    => 'Test2'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Subject / Operator ENDSWITH / Value "t2"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'ENDSWITH',
                    Value    => 't2'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Subject / Operator CONTAINS / Value "Test2"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'CONTAINS',
                    Value    => 'Test2'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Subject / Operator CONTAINS / Value "est"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'CONTAINS',
                    Value    => 'est'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Subject / Operator LIKE / Value "Test2"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'LIKE',
                    Value    => 'Test2'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Body / Operator EQ / Value "Test"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'EQ',
                    Value    => 'Test'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Body / Operator NE / Value "Test"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'NE',
                    Value    => 'Test'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Body / Operator IN / Value ["Test"]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'IN',
                    Value    => ['Test']
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Body / Operator !IN / Value ["Test"]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => '!IN',
                    Value    => ['Test']
                }
            ]
        },
        UserType => 'Agent',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Body / Operator STARTSWITH / Value "Test"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'STARTSWITH',
                    Value    => 'Test'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Body / Operator STARTSWITH / Value "Tes"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'STARTSWITH',
                    Value    => 'Tes'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Body / Operator ENDSWITH / Value "Test"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'ENDSWITH',
                    Value    => 'Test'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Body / Operator ENDSWITH / Value "st"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'ENDSWITH',
                    Value    => 'st'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Body / Operator CONTAINS / Value "Test"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'CONTAINS',
                    Value    => 'Test'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Body / Operator CONTAINS / Value "es"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'CONTAINS',
                    Value    => 'es'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field Body / Operator LIKE / Value "Test"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'LIKE',
                    Value    => 'Test'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Body / Operator EQ / Value "Test"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'EQ',
                    Value    => 'Test'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Body / Operator NE / Value "Test"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'NE',
                    Value    => 'Test'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Body / Operator IN / Value ["Test"]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'IN',
                    Value    => ['Test']
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Body / Operator !IN / Value ["Test"]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => '!IN',
                    Value    => ['Test']
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Body / Operator STARTSWITH / Value "Test"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'STARTSWITH',
                    Value    => 'Test'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Body / Operator STARTSWITH / Value "Tes"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'STARTSWITH',
                    Value    => 'Tes'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Body / Operator ENDSWITH / Value "Test"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'ENDSWITH',
                    Value    => 'Test'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Body / Operator ENDSWITH / Value "st"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'ENDSWITH',
                    Value    => 'st'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Body / Operator CONTAINS / Value "Test"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'CONTAINS',
                    Value    => 'Test'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Body / Operator CONTAINS / Value "es"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'CONTAINS',
                    Value    => 'es'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field Body / Operator LIKE / Value "Test"',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'LIKE',
                    Value    => 'Test'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field ArticleCreateTime / Operator EQ / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'EQ',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field ArticleCreateTime / Operator EQ / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'EQ',
                    Value    => '-1m'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field ArticleCreateTime / Operator LT / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'LT',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field ArticleCreateTime / Operator LT / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'LT',
                    Value    => '-1m'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field ArticleCreateTime / Operator GT / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'GT',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        UserType => 'Agent',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field ArticleCreateTime / Operator GT / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'GT',
                    Value    => '-1m'
                }
            ]
        },
        UserType => 'Agent',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field ArticleCreateTime / Operator LTE / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'LTE',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1, $TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field ArticleCreateTime / Operator LTE / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'LTE',
                    Value    => '-1m'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1, $TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field ArticleCreateTime / Operator GTE / Value2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'GTE',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Agent / Field ArticleCreateTime / Operator GTE / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'GTE',
                    Value    => '-1m'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field ArticleCreateTime / Operator EQ / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'EQ',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field ArticleCreateTime / Operator EQ / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'EQ',
                    Value    => '-1m'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field ArticleCreateTime / Operator LT / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'LT',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field ArticleCreateTime / Operator LT / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'LT',
                    Value    => '-1m'
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field ArticleCreateTime / Operator GT / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'GT',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field ArticleCreateTime / Operator GT / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'GT',
                    Value    => '-1m'
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field ArticleCreateTime / Operator LTE / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'LTE',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field ArticleCreateTime / Operator LTE / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'LTE',
                    Value    => '-1m'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field ArticleCreateTime / Operator GTE / Value2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'GTE',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule StaticDB / UserType Customer / Field ArticleCreateTime / Operator GTE / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'GTE',
                    Value    => '-1m'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    }
);
for my $Test ( @IntegrationSearchTestsStaticDB ) {
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

# set config 'Ticket::SearchIndexModule' to 'RuntimeDB' to check non static search
$Kernel::OM->Get('Config')->Set(
    Key   => 'Ticket::SearchIndexModule',
    Value => 'Kernel::System::Ticket::ArticleSearchIndex::RuntimeDB'
);

# cleanup cache before search
$Kernel::OM->Get('Cache')->CleanUp(
    Type => 'ObjectSearch_Ticket',
);

# test Search for RuntimeDB
my @IntegrationSearchTestsRuntimeDB = (
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field ArticleID / Operator EQ / Value $ArticleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'EQ',
                    Value    => $ArticleID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field ArticleID / Operator NE / Value $ArticleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'NE',
                    Value    => $ArticleID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field ArticleID / Operator IN / Value [$ArticleID1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'IN',
                    Value    => [$ArticleID1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field ArticleID / Operator !IN / Value [$ArticleID1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => '!IN',
                    Value    => [$ArticleID1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field ArticleID / Operator LT / Value $ArticleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'LT',
                    Value    => $ArticleID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field ArticleID / Operator LTE / Value $ArticleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'LTE',
                    Value    => $ArticleID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field ArticleID / Operator GT / Value $ArticleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'GT',
                    Value    => $ArticleID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field ArticleID / Operator GTE / Value $ArticleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'GTE',
                    Value    => $ArticleID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field ArticleID / Operator EQ / Value $ArticleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'EQ',
                    Value    => $ArticleID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field ArticleID / Operator NE / Value $ArticleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'NE',
                    Value    => $ArticleID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field ArticleID / Operator IN / Value [$ArticleID1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'IN',
                    Value    => [$ArticleID1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field ArticleID / Operator !IN / Value [$ArticleID1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => '!IN',
                    Value    => [$ArticleID1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field ArticleID / Operator LT / Value $ArticleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'LT',
                    Value    => $ArticleID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field ArticleID / Operator LTE / Value $ArticleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'LTE',
                    Value    => $ArticleID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field ArticleID / Operator GT / Value $ArticleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'GT',
                    Value    => $ArticleID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field ArticleID / Operator GTE / Value $ArticleID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'GTE',
                    Value    => $ArticleID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field ChannelID / Operator EQ / Value $ChannelID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => 'EQ',
                    Value    => $ChannelID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field ChannelID / Operator NE / Value $ChannelID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => 'NE',
                    Value    => $ChannelID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field ChannelID / Operator IN / Value [$ChannelID1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => 'IN',
                    Value    => [$ChannelID1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field ChannelID / Operator !IN / Value [$ChannelID1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => '!IN',
                    Value    => [$ChannelID1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field ChannelID / Operator LT / Value $ChannelID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => 'LT',
                    Value    => $ChannelID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field ChannelID / Operator LTE / Value $ChannelID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => 'LTE',
                    Value    => $ChannelID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field ChannelID / Operator GT / Value $ChannelID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => 'GT',
                    Value    => $ChannelID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field ChannelID / Operator GTE / Value $ChannelID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => 'GTE',
                    Value    => $ChannelID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field ChannelID / Operator EQ / Value $ChannelID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => 'EQ',
                    Value    => $ChannelID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field ChannelID / Operator NE / Value $ChannelID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => 'NE',
                    Value    => $ChannelID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field ChannelID / Operator IN / Value [$ChannelID1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => 'IN',
                    Value    => [$ChannelID1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field ChannelID / Operator !IN / Value [$ChannelID1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => '!IN',
                    Value    => [$ChannelID1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field ChannelID / Operator LT / Value $ChannelID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => 'LT',
                    Value    => $ChannelID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field ChannelID / Operator LTE / Value $ChannelID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => 'LTE',
                    Value    => $ChannelID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field ChannelID / Operator GT / Value $ChannelID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => 'GT',
                    Value    => $ChannelID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field ChannelID / Operator GTE / Value $ChannelID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ChannelID',
                    Operator => 'GTE',
                    Value    => $ChannelID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Channel / Operator EQ / Value $ChannelName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'EQ',
                    Value    => $ChannelName2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Channel / Operator NE / Value $ChannelName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'NE',
                    Value    => $ChannelName2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Channel / Operator IN / Value [$ChannelName1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'IN',
                    Value    => [$ChannelName1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Channel / Operator !IN / Value [$ChannelName1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => '!IN',
                    Value    => [$ChannelName1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Channel / Operator STARTSWITH / Value $ChannelName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'STARTSWITH',
                    Value    => $ChannelName2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Channel / Operator STARTSWITH / Value substr($ChannelName2,0,2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'STARTSWITH',
                    Value    => substr($ChannelName2,0,2)
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Channel / Operator ENDSWITH / Value $ChannelName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'ENDSWITH',
                    Value    => $ChannelName2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Channel / Operator ENDSWITH / Value substr($ChannelName2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'ENDSWITH',
                    Value    => substr($ChannelName2,-2)
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Channel / Operator CONTAINS / Value $ChannelName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'CONTAINS',
                    Value    => $ChannelName2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Channel / Operator CONTAINS / Value substr($ChannelName2,1,-1)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'CONTAINS',
                    Value    => substr($ChannelName2,1,-1)
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Channel / Operator LIKE / Value $ChannelName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'LIKE',
                    Value    => $ChannelName2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Channel / Operator EQ / Value $ChannelName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'EQ',
                    Value    => $ChannelName2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Channel / Operator NE / Value $ChannelName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'NE',
                    Value    => $ChannelName2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Channel / Operator IN / Value [$ChannelName1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'IN',
                    Value    => [$ChannelName1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Channel / Operator !IN / Value [$ChannelName1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => '!IN',
                    Value    => [$ChannelName1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Channel / Operator STARTSWITH / Value $ChannelName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'STARTSWITH',
                    Value    => $ChannelName2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Channel / Operator STARTSWITH / Value substr($ChannelName2,0,2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'STARTSWITH',
                    Value    => substr($ChannelName2,0,2)
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Channel / Operator ENDSWITH / Value $ChannelName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'ENDSWITH',
                    Value    => $ChannelName2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Channel / Operator ENDSWITH / Value substr($ChannelName2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'ENDSWITH',
                    Value    => substr($ChannelName2,-2)
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Channel / Operator CONTAINS / Value $ChannelName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'CONTAINS',
                    Value    => $ChannelName2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Channel / Operator CONTAINS / Value substr($ChannelName2,1,-1)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'CONTAINS',
                    Value    => substr($ChannelName2,1,-1)
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Channel / Operator LIKE / Value $ChannelName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Channel',
                    Operator => 'LIKE',
                    Value    => $ChannelName2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field SenderTypeID / Operator EQ / Value $SenderTypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => 'EQ',
                    Value    => $SenderTypeID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field SenderTypeID / Operator NE / Value $SenderTypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => 'NE',
                    Value    => $SenderTypeID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field SenderTypeID / Operator IN / Value [$SenderTypeID1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => 'IN',
                    Value    => [$SenderTypeID1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field SenderTypeID / Operator !IN / Value [$SenderTypeID1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => '!IN',
                    Value    => [$SenderTypeID1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field SenderTypeID / Operator LT / Value $SenderTypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => 'LT',
                    Value    => $SenderTypeID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field SenderTypeID / Operator LTE / Value $SenderTypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => 'LTE',
                    Value    => $SenderTypeID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field SenderTypeID / Operator GT / Value $SenderTypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => 'GT',
                    Value    => $SenderTypeID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field SenderTypeID / Operator GTE / Value $SenderTypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => 'GTE',
                    Value    => $SenderTypeID2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field SenderTypeID / Operator EQ / Value $SenderTypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => 'EQ',
                    Value    => $SenderTypeID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field SenderTypeID / Operator NE / Value $SenderTypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => 'NE',
                    Value    => $SenderTypeID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field SenderTypeID / Operator IN / Value [$SenderTypeID1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => 'IN',
                    Value    => [$SenderTypeID1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field SenderTypeID / Operator !IN / Value [$SenderTypeID1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => '!IN',
                    Value    => [$SenderTypeID1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field SenderTypeID / Operator LT / Value $SenderTypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => 'LT',
                    Value    => $SenderTypeID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field SenderTypeID / Operator LTE / Value $SenderTypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => 'LTE',
                    Value    => $SenderTypeID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field SenderTypeID / Operator GT / Value $SenderTypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => 'GT',
                    Value    => $SenderTypeID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field SenderTypeID / Operator GTE / Value $SenderTypeID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderTypeID',
                    Operator => 'GTE',
                    Value    => $SenderTypeID2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field SenderType / Operator EQ / Value $SenderTypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'EQ',
                    Value    => $SenderTypeName2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field SenderType / Operator NE / Value $SenderTypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'NE',
                    Value    => $SenderTypeName2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field SenderType / Operator IN / Value [$SenderTypeName1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'IN',
                    Value    => [$SenderTypeName1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field SenderType / Operator !IN / Value [$SenderTypeName1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => '!IN',
                    Value    => [$SenderTypeName1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field SenderType / Operator STARTSWITH / Value $SenderTypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'STARTSWITH',
                    Value    => $SenderTypeName2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field SenderType / Operator STARTSWITH / Value substr($SenderTypeName2,0,2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'STARTSWITH',
                    Value    => substr($SenderTypeName2,0,2)
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field SenderType / Operator ENDSWITH / Value $SenderTypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'ENDSWITH',
                    Value    => $SenderTypeName2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field SenderType / Operator ENDSWITH / Value substr($SenderTypeName2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'ENDSWITH',
                    Value    => substr($SenderTypeName2,-2)
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field SenderType / Operator CONTAINS / Value $SenderTypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'CONTAINS',
                    Value    => $SenderTypeName2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field SenderType / Operator CONTAINS / Value substr($SenderTypeName2,1,-1)',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'CONTAINS',
                    Value    => substr($SenderTypeName2,1,-1)
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field SenderType / Operator LIKE / Value $SenderTypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'LIKE',
                    Value    => $SenderTypeName2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field SenderType / Operator EQ / Value $SenderTypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'EQ',
                    Value    => $SenderTypeName2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field SenderType / Operator NE / Value $SenderTypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'NE',
                    Value    => $SenderTypeName2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field SenderType / Operator IN / Value [$SenderTypeName1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'IN',
                    Value    => [$SenderTypeName1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field SenderType / Operator !IN / Value [$SenderTypeName1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => '!IN',
                    Value    => [$SenderTypeName1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field SenderType / Operator STARTSWITH / Value $SenderTypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'STARTSWITH',
                    Value    => $SenderTypeName2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field SenderType / Operator STARTSWITH / Value substr($SenderTypeName2,0,2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'STARTSWITH',
                    Value    => substr($SenderTypeName2,0,2)
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field SenderType / Operator ENDSWITH / Value $SenderTypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'ENDSWITH',
                    Value    => $SenderTypeName2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field SenderType / Operator ENDSWITH / Value substr($SenderTypeName2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'ENDSWITH',
                    Value    => substr($SenderTypeName2,-2)
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field SenderType / Operator CONTAINS / Value $SenderTypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'CONTAINS',
                    Value    => $SenderTypeName2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field SenderType / Operator CONTAINS / Value substr($SenderTypeName2,1,-1)',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'CONTAINS',
                    Value    => substr($SenderTypeName2,1,-1)
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field SenderType / Operator LIKE / Value $SenderTypeName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'SenderType',
                    Operator => 'LIKE',
                    Value    => $SenderTypeName2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field CustomerVisible / Operator EQ / Value 0',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => 'EQ',
                    Value    => 0
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field CustomerVisible / Operator NE / Value 0',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => 'NE',
                    Value    => 0
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field CustomerVisible / Operator IN / Value [1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => 'IN',
                    Value    => [1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field CustomerVisible / Operator !IN / Value [1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => '!IN',
                    Value    => [1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field CustomerVisible / Operator LT / Value 1',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => 'LT',
                    Value    => 1
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field CustomerVisible / Operator LTE / Value 1',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => 'LTE',
                    Value    => 1
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field CustomerVisible / Operator GT / Value 0',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => 'GT',
                    Value    => 0
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field CustomerVisible / Operator GTE / Value 0',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => 'GTE',
                    Value    => 0
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field CustomerVisible / Operator EQ / Value 0',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => 'EQ',
                    Value    => 0
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field CustomerVisible / Operator NE / Value 0',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => 'NE',
                    Value    => 0
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field CustomerVisible / Operator IN / Value [1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => 'IN',
                    Value    => [1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field CustomerVisible / Operator !IN / Value [1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => '!IN',
                    Value    => [1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field CustomerVisible / Operator LT / Value 1',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => 'LT',
                    Value    => 1
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field CustomerVisible / Operator LTE / Value 1',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => 'LTE',
                    Value    => 1
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field CustomerVisible / Operator GT / Value 0',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => 'GT',
                    Value    => 0
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field CustomerVisible / Operator GTE / Value 0',
        Search   => {
            'AND' => [
                {
                    Field    => 'CustomerVisible',
                    Operator => 'GTE',
                    Value    => 0
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field From / Operator EQ / Value $From2',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'EQ',
                    Value    => $From2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field From / Operator NE / Value $From2',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'NE',
                    Value    => $From2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field From / Operator IN / Value [$From1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'IN',
                    Value    => [$From1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field From / Operator !IN / Value [$From1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => '!IN',
                    Value    => [$From1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field From / Operator STARTSWITH / Value $From2',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'STARTSWITH',
                    Value    => $From2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field From / Operator STARTSWITH / Value substr($From2,0,2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'STARTSWITH',
                    Value    => substr($From2,0,2)
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field From / Operator ENDSWITH / Value $From2',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'ENDSWITH',
                    Value    => $From2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field From / Operator ENDSWITH / Value substr($From2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'ENDSWITH',
                    Value    => substr($From2,-2)
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field From / Operator CONTAINS / Value $From2',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'CONTAINS',
                    Value    => $From2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field From / Operator CONTAINS / Value substr($From2,1,-1)',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'CONTAINS',
                    Value    => substr($From2,1,-1)
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field From / Operator LIKE / Value $From2',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'LIKE',
                    Value    => $From2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field From / Operator EQ / Value $From2',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'EQ',
                    Value    => $From2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field From / Operator NE / Value $From2',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'NE',
                    Value    => $From2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field From / Operator IN / Value [$From1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'IN',
                    Value    => [$From1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field From / Operator !IN / Value [$From1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => '!IN',
                    Value    => [$From1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field From / Operator STARTSWITH / Value $From2',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'STARTSWITH',
                    Value    => $From2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field From / Operator STARTSWITH / Value substr($From2,0,2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'STARTSWITH',
                    Value    => substr($From2,0,2)
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field From / Operator ENDSWITH / Value $From2',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'ENDSWITH',
                    Value    => $From2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field From / Operator ENDSWITH / Value substr($From2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'ENDSWITH',
                    Value    => substr($From2,-2)
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field From / Operator CONTAINS / Value $From2',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'CONTAINS',
                    Value    => $From2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field From / Operator CONTAINS / Value substr($From2,1,-1)',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'CONTAINS',
                    Value    => substr($From2,1,-1)
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field From / Operator LIKE / Value $From2',
        Search   => {
            'AND' => [
                {
                    Field    => 'From',
                    Operator => 'LIKE',
                    Value    => $From2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field To / Operator EQ / Value $To2',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'EQ',
                    Value    => $To2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field To / Operator NE / Value $To2',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'NE',
                    Value    => $To2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field To / Operator IN / Value [$To1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'IN',
                    Value    => [$To1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field To / Operator !IN / Value [$To1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => '!IN',
                    Value    => [$To1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field To / Operator STARTSWITH / Value $To2',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'STARTSWITH',
                    Value    => $To2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field To / Operator STARTSWITH / Value substr($To2,0,2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'STARTSWITH',
                    Value    => substr($To2,0,2)
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field To / Operator ENDSWITH / Value $To2',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'ENDSWITH',
                    Value    => $To2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field To / Operator ENDSWITH / Value substr($To2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'ENDSWITH',
                    Value    => substr($To2,-2)
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field To / Operator CONTAINS / Value $To2',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'CONTAINS',
                    Value    => $To2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field To / Operator CONTAINS / Value substr($To2,1,-1)',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'CONTAINS',
                    Value    => substr($To2,1,-1)
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field To / Operator LIKE / Value $To2',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'LIKE',
                    Value    => $To2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field To / Operator EQ / Value $To2',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'EQ',
                    Value    => $To2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field To / Operator NE / Value $To2',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'NE',
                    Value    => $To2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field To / Operator IN / Value [$To1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'IN',
                    Value    => [$To1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field To / Operator !IN / Value [$To1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => '!IN',
                    Value    => [$To1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field To / Operator STARTSWITH / Value $To2',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'STARTSWITH',
                    Value    => $To2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field To / Operator STARTSWITH / Value substr($To2,0,2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'STARTSWITH',
                    Value    => substr($To2,0,2)
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field To / Operator ENDSWITH / Value $To2',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'ENDSWITH',
                    Value    => $To2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field To / Operator ENDSWITH / Value substr($To2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'ENDSWITH',
                    Value    => substr($To2,-2)
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field To / Operator CONTAINS / Value $To2',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'CONTAINS',
                    Value    => $To2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field To / Operator CONTAINS / Value substr($To2,1,-1)',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'CONTAINS',
                    Value    => substr($To2,1,-1)
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field To / Operator LIKE / Value $To2',
        Search   => {
            'AND' => [
                {
                    Field    => 'To',
                    Operator => 'LIKE',
                    Value    => $To2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Cc / Operator EQ / Value $Cc2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'EQ',
                    Value    => $Cc2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Cc / Operator NE / Value $Cc2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'NE',
                    Value    => $Cc2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Cc / Operator IN / Value [$Cc1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'IN',
                    Value    => [$Cc1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Cc / Operator !IN / Value [$Cc1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => '!IN',
                    Value    => [$Cc1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Cc / Operator STARTSWITH / Value $Cc2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'STARTSWITH',
                    Value    => $Cc2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Cc / Operator STARTSWITH / Value substr($Cc2,0,2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'STARTSWITH',
                    Value    => substr($Cc2,0,2)
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Cc / Operator ENDSWITH / Value $Cc2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'ENDSWITH',
                    Value    => $Cc2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Cc / Operator ENDSWITH / Value substr($Cc2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'ENDSWITH',
                    Value    => substr($Cc2,-2)
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Cc / Operator CONTAINS / Value $Cc2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'CONTAINS',
                    Value    => $Cc2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Cc / Operator CONTAINS / Value substr($Cc2,1,-1)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'CONTAINS',
                    Value    => substr($Cc2,1,-1)
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Cc / Operator LIKE / Value $Cc2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'LIKE',
                    Value    => $Cc2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Cc / Operator EQ / Value $Cc2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'EQ',
                    Value    => $Cc2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Cc / Operator NE / Value $Cc2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'NE',
                    Value    => $Cc2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Cc / Operator IN / Value [$Cc1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'IN',
                    Value    => [$Cc1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Cc / Operator !IN / Value [$Cc1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => '!IN',
                    Value    => [$Cc1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Cc / Operator STARTSWITH / Value $Cc2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'STARTSWITH',
                    Value    => $Cc2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Cc / Operator STARTSWITH / Value substr($Cc2,0,2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'STARTSWITH',
                    Value    => substr($Cc2,0,2)
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Cc / Operator ENDSWITH / Value $Cc2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'ENDSWITH',
                    Value    => $Cc2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Cc / Operator ENDSWITH / Value substr($Cc2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'ENDSWITH',
                    Value    => substr($Cc2,-2)
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Cc / Operator CONTAINS / Value $Cc2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'CONTAINS',
                    Value    => $Cc2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Cc / Operator CONTAINS / Value substr($Cc2,1,-1)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'CONTAINS',
                    Value    => substr($Cc2,1,-1)
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Cc / Operator LIKE / Value $Cc2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Cc',
                    Operator => 'LIKE',
                    Value    => $Cc2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Subject / Operator EQ / Value $Subject2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'EQ',
                    Value    => $Subject2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Subject / Operator NE / Value $Subject2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'NE',
                    Value    => $Subject2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Subject / Operator IN / Value [$Subject1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'IN',
                    Value    => [$Subject1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Subject / Operator !IN / Value [$Subject1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => '!IN',
                    Value    => [$Subject1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Subject / Operator STARTSWITH / Value $Subject2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'STARTSWITH',
                    Value    => $Subject2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Subject / Operator STARTSWITH / Value substr($Subject2,0,2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'STARTSWITH',
                    Value    => substr($Subject2,0,2)
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Subject / Operator ENDSWITH / Value $Subject2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'ENDSWITH',
                    Value    => $Subject2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Subject / Operator ENDSWITH / Value substr($Subject2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'ENDSWITH',
                    Value    => substr($Subject2,-2)
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Subject / Operator CONTAINS / Value $Subject2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'CONTAINS',
                    Value    => $Subject2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Subject / Operator CONTAINS / Value substr($Subject2,1,-1)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'CONTAINS',
                    Value    => substr($Subject2,1,-1)
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Subject / Operator LIKE / Value $Subject2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'LIKE',
                    Value    => $Subject2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Subject / Operator EQ / Value $Subject2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'EQ',
                    Value    => $Subject2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Subject / Operator NE / Value $Subject2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'NE',
                    Value    => $Subject2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Subject / Operator IN / Value [$Subject1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'IN',
                    Value    => [$Subject1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Subject / Operator !IN / Value [$Subject1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => '!IN',
                    Value    => [$Subject1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Subject / Operator STARTSWITH / Value $Subject2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'STARTSWITH',
                    Value    => $Subject2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Subject / Operator STARTSWITH / Value substr($Subject2,0,2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'STARTSWITH',
                    Value    => substr($Subject2,0,2)
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Subject / Operator ENDSWITH / Value $Subject2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'ENDSWITH',
                    Value    => $Subject2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Subject / Operator ENDSWITH / Value substr($Subject2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'ENDSWITH',
                    Value    => substr($Subject2,-2)
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Subject / Operator CONTAINS / Value $Subject2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'CONTAINS',
                    Value    => $Subject2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Subject / Operator CONTAINS / Value substr($Subject2,1,-1)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'CONTAINS',
                    Value    => substr($Subject2,1,-1)
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Subject / Operator LIKE / Value $Subject2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Subject',
                    Operator => 'LIKE',
                    Value    => $Subject2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Body / Operator EQ / Value $Body2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'EQ',
                    Value    => $Body2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Body / Operator NE / Value $Body2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'NE',
                    Value    => $Body2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Body / Operator IN / Value [$Body1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'IN',
                    Value    => [$Body1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Body / Operator !IN / Value [$Body1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => '!IN',
                    Value    => [$Body1]
                }
            ]
        },
        UserType => 'Agent',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Body / Operator STARTSWITH / Value $Body2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'STARTSWITH',
                    Value    => $Body2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Body / Operator STARTSWITH / Value substr($Body2,0,2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'STARTSWITH',
                    Value    => substr($Body2,0,2)
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Body / Operator ENDSWITH / Value $Body2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'ENDSWITH',
                    Value    => $Body2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Body / Operator ENDSWITH / Value substr($Body2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'ENDSWITH',
                    Value    => substr($Body2,-2)
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Body / Operator CONTAINS / Value $Body2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'CONTAINS',
                    Value    => $Body2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Body / Operator CONTAINS / Value substr($Body2,1,-1)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'CONTAINS',
                    Value    => substr($Body2,1,-1)
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field Body / Operator LIKE / Value $Body2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'LIKE',
                    Value    => $Body2
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1,$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Body / Operator EQ / Value $Body2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'EQ',
                    Value    => $Body2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Body / Operator NE / Value $Body2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'NE',
                    Value    => $Body2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID1,$TicketID3]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Body / Operator IN / Value [$Body1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'IN',
                    Value    => [$Body1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Body / Operator !IN / Value [$Body1]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => '!IN',
                    Value    => [$Body1]
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Body / Operator STARTSWITH / Value $Body2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'STARTSWITH',
                    Value    => $Body2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Body / Operator STARTSWITH / Value substr($Body2,0,2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'STARTSWITH',
                    Value    => substr($Body2,0,2)
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Body / Operator ENDSWITH / Value $Body2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'ENDSWITH',
                    Value    => $Body2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Body / Operator ENDSWITH / Value substr($Body2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'ENDSWITH',
                    Value    => substr($Body2,-2)
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Body / Operator CONTAINS / Value $Body2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'CONTAINS',
                    Value    => $Body2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Body / Operator CONTAINS / Value substr($Body2,1,-1)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'CONTAINS',
                    Value    => substr($Body2,1,-1)
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field Body / Operator LIKE / Value $Body2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Body',
                    Operator => 'LIKE',
                    Value    => $Body2
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field ArticleCreateTime / Operator EQ / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'EQ',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field ArticleCreateTime / Operator EQ / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'EQ',
                    Value    => '-1m'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field ArticleCreateTime / Operator LT / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'LT',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field ArticleCreateTime / Operator LT / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'LT',
                    Value    => '-1m'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field ArticleCreateTime / Operator GT / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'GT',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        UserType => 'Agent',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field ArticleCreateTime / Operator GT / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'GT',
                    Value    => '-1m'
                }
            ]
        },
        UserType => 'Agent',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field ArticleCreateTime / Operator LTE / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'LTE',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1, $TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field ArticleCreateTime / Operator LTE / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'LTE',
                    Value    => '-1m'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID1, $TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field ArticleCreateTime / Operator GTE / Value2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'GTE',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Agent / Field ArticleCreateTime / Operator GTE / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'GTE',
                    Value    => '-1m'
                }
            ]
        },
        UserType => 'Agent',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field ArticleCreateTime / Operator EQ / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'EQ',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field ArticleCreateTime / Operator EQ / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'EQ',
                    Value    => '-1m'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field ArticleCreateTime / Operator LT / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'LT',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field ArticleCreateTime / Operator LT / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'LT',
                    Value    => '-1m'
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field ArticleCreateTime / Operator GT / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'GT',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field ArticleCreateTime / Operator GT / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'GT',
                    Value    => '-1m'
                }
            ]
        },
        UserType => 'Customer',
        Expected => []
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field ArticleCreateTime / Operator LTE / Value 2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'LTE',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field ArticleCreateTime / Operator LTE / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'LTE',
                    Value    => '-1m'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field ArticleCreateTime / Operator GTE / Value2014-01-01 12:01:00',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'GTE',
                    Value    => '2014-01-01 12:01:00'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    },
    {
        Name     => 'Search: SearchIndexModule RuntimeDB / UserType Customer / Field ArticleCreateTime / Operator GTE / Value -1m',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleCreateTime',
                    Operator => 'GTE',
                    Value    => '-1m'
                }
            ]
        },
        UserType => 'Customer',
        Expected => [$TicketID2]
    }
);
for my $Test ( @IntegrationSearchTestsRuntimeDB ) {
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

my $TimeStamp = $Kernel::OM->Get('Time')->CurrentTimestamp();
$Self->Is(
    $TimeStamp,
    '2014-01-01 12:02:00',
    'Timestamp before first relative search'
);
my @FirstResult = $ObjectSearch->Search(
    ObjectType => 'Ticket',
    Result     => 'ARRAY',
    Search     => {
        'AND' => [
            {
                Field    => 'ArticleCreateTime',
                Operator => 'GTE',
                Value    => '-1m'
            }
        ]
    },
    UserType   => 'Agent',
    UserID     => 1,
);
$Self->IsDeeply(
    \@FirstResult,
    [$TicketID2],
    'Result of first relative search'
);
$Helper->FixedTimeAddSeconds(60);
$TimeStamp = $Kernel::OM->Get('Time')->CurrentTimestamp();
$Self->Is(
    $TimeStamp,
    '2014-01-01 12:03:00',
    'Timestamp before second relative search'
);
my @SecondResult = $ObjectSearch->Search(
    ObjectType => 'Ticket',
    Result     => 'ARRAY',
    Search     => {
        'AND' => [
            {
                Field    => 'ArticleCreateTime',
                Operator => 'GTE',
                Value    => '-1m'
            }
        ]
    },
    UserType   => 'Agent',
    UserID     => 1,
);
$Self->IsDeeply(
    \@SecondResult,
    [],
    'Result of second relative search'
);

# reset fixed time
$Helper->FixedTimeUnset();

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
