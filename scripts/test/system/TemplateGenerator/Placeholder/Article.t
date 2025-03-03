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

my $PlaceholderModule = 'Kernel::System::Placeholder::Article';

# require module
return if ( !$Kernel::OM->Get('Main')->Require( $PlaceholderModule ) );

# create backend object
my $PlaceholderObject = $PlaceholderModule->new( %{ $Self } );
$Self->Is(
    ref( $PlaceholderObject ),
    $PlaceholderModule,
    'Placeholder object has correct module ref'
);

# check supported methods
for my $Method (
    qw(
        ReplacePlaceholder _HashGlobalReplace
        _Replace _ReplaceArticlePlaceholders _ReplaceBodyRichtext
        _GetPreparedBody _CloseTags
    )
) {
    $Self->True(
        $PlaceholderObject->can($Method),
        'Placeholder object can "' . $Method . q{"}
    );
}

# begin transaction on database
$Helper->BeginWork();

# prepare Users
my $UserID1    = $Helper->TestUserCreate(
    Roles => [
        'Ticket Agent'
    ]
);

my %User1 = $Kernel::OM->Get('User')->GetUserData(
    User  => $UserID1
);
$Self->True(
    $UserID1,
    'Create: First User'
);

# prepare contacts
my $ContactID1 = $Helper->TestContactCreate();

my %Contact1 = $Kernel::OM->Get('Contact')->ContactGet(
    ID => $ContactID1
);
$Self->True(
    $ContactID1,
    'Create: First Contact'
);

# prepare dynamic field
my $DFID = $Kernel::OM->Get('DynamicField')->DynamicFieldAdd(
    Name            => 'ArticlePlaceholderTestDF',
    Label           => 'ArticlePlaceholderTestDF',
    FieldType       => 'Text',
    ObjectType      => 'Article',
    Config          => {},
    ValidID         => 1,
    UserID          => 1
);
$Self->True(
    $DFID,
    'Created: DynamicField ArticlePlaceholderTestDF'
);
my $DynamicField = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
    ID   => $DFID
);
$Self->True(
    IsHashRefWithData($DynamicField) ? 1 : 0,
    'Check: DynamicField ArticlePlaceholderTestDF exists'
);

# Prepare Ticktes
my $TicketID1 = _CreateTicket(
    Contact  => \%Contact1,
    User     => \%User1,
    Name     => "Create: First Ticket | Contact $ContactID1"
);

my $TicketID2 = _CreateTicket(
    Contact  => \%Contact1,
    User     => \%User1,
    Name     => "Create: Second Ticket | Contact $ContactID1"
);

my $TicketID3 = _CreateTicket(
    Contact  => \%Contact1,
    User     => \%User1,
    Name     => "Create: Third Ticket | Contact $ContactID1"
);

# prepare articles
my @ArticleConfigs = (
    {
        Config => {
            TicketID         => $TicketID1,
            Channel          => 'email',
            CustomerVisible  => 1,
            SenderType       => 'external',
            To               => 'unit.test@ut.com',
            From             => "$Contact1{Fullname} <$Contact1{Email}>",
            Subject          => 'UnitTest First Article',
            Body             => 'UnitTest Body',
            ContentType      => 'text/plain; charset=utf8',
            HistoryType      => 'AddNote',
            HistoryComment   => 'UnitTest Article!',
            TimeUnit         => 5,
            UserID           => 1,
            Loop             => 0
        },
        Name => "Create: Article | First article | TicketID $TicketID1"
    },
    {
        Config => {
            TicketID         => $TicketID1,
            Channel          => 'note',
            CustomerVisible  => 1,
            SenderType       => 'agent',
            From             => 'unit.test@ut.com',
            To               => "$Contact1{Fullname} <$Contact1{Email}>",
            Subject          => 'UnitTest Last Article',
            Body             => 'UnitTest Body',
            ContentType      => 'text/plain; charset=utf8',
            HistoryType      => 'AddNote',
            HistoryComment   => 'UnitTest Article!',
            TimeUnit         => 5,
            UserID           => $User1{UserID}
        },
        Name => "Create: Article | Last article | TicketID $TicketID1"
    },
    {
        Config => {
            TicketID        => $TicketID2,
            Channel         => 'note',
            CustomerVisible => 0,
            SenderType      => 'agent',
            From            => 'unit.test@ut.com',
            To              => 'unit.test2@ut.com',
            Subject         => 'UnitTest Article',
            ContentType     => 'text/text; charset=utf8',
            UserID          => $User1{UserID},
            HistoryType     => 'AddNote',
            HistoryComment  => 'UnitTest Plain Article!',
            Body            => 'This is a text for body limit tests.'
        },
        Name => "Create: Article | Content Plain | TicketID $TicketID2"
    },
    {
        Config => {
            TicketID        => $TicketID3,
            Channel         => 'note',
            CustomerVisible => 0,
            SenderType      => 'agent',
            From            => 'unit.test@ut.com',
            To              => 'unit.test2@ut.com',
            Subject         => 'UnitTest Article with html',
            ContentType     => 'text/html; charset=utf8',
            UserID          => $User1{UserID},
            HistoryType     => 'AddNote',
            HistoryComment  => 'UnitTest HTML Article!',
            Body            => <<'END'
Line 1<br />
Line 2<br />
Line 3
<div>
    <table border="1" cellpadding="1" cellspacing="1" style="width:500px">
        <tbody>
            <tr>
                <td>Column 1:1</td>
                <td>
                    <div>Column 1:2</div>
                </td>
            </tr>
            <tr>
                <td>Column 2:1</td>
                <td>Column 2:2</td>
            </tr>
            <tr>
                <td>Column 3:1</td>
                <td>Column 3:2</td>
            </tr>
        </tbody>
    </table>
</div>
Line 4<br />
Line 5<br />
<img alt="" src="data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/4QBoRXhpZgAASUkqAAgAAAADABIBAwABAAAAAQAAADEBAgAQAAAAMgAAAGmHBAABAAAAQgAAAAAAAABTaG90d2VsbCAwLjIyLjAAAgACoAkAAQAAAD0AAAADoAkAAQAAAD8AAAAAAAAA/+ELyWh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8APD94cGFja2V0IGJlZ2luPSLvu78iIGlkPSJXNU0wTXBDZWhpSHpyZVN6TlRjemtjOWQiPz4gPHg6eG1wbWV0YSB4bWxuczp4PSJhZG9iZTpuczptZXRhLyIgeDp4bXB0az0iWE1QIENvcmUgNC40LjAtRXhpdjIiPiA8cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkvMDIvMjItcmRmLXN5bnRheC1ucyMiPiA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0iIiB4bWxuczp4bXA9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iIHhtbG5zOnhtcE1NPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvbW0vIiB4bWxuczpzdFJlZj0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL3NUeXBlL1Jlc291cmNlUmVmIyIgeG1sbnM6ZXhpZj0iaHR0cDovL25zLmFkb2JlLmNvbS9leGlmLzEuMC8iIHhtbG5zOnRpZmY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vdGlmZi8xLjAvIiB4bXA6Q3JlYXRvclRvb2w9IkFkb2JlIFBob3Rvc2hvcCBDUzUgV2luZG93cyIgeG1wTU06SW5zdGFuY2VJRD0ieG1wLmlpZDpCM0M1MUFCNjFCQUYxMUUzODQ4N0ZERkMwNzFGMTQ0RSIgeG1wTU06RG9jdW1lbnRJRD0ieG1wLmRpZDpCM0M1MUFCNzFCQUYxMUUzODQ4N0ZERkMwNzFGMTQ0RSIgZXhpZjpQaXhlbFhEaW1lbnNpb249IjYxIiBleGlmOlBpeGVsWURpbWVuc2lvbj0iNjMiIHRpZmY6SW1hZ2VXaWR0aD0iNjEiIHRpZmY6SW1hZ2VIZWlnaHQ9IjYzIiB0aWZmOk9yaWVudGF0aW9uPSIxIj4gPHhtcE1NOkRlcml2ZWRGcm9tIHN0UmVmOmluc3RhbmNlSUQ9InhtcC5paWQ6QjNDNTFBQjQxQkFGMTFFMzg0ODdGREZDMDcxRjE0NEUiIHN0UmVmOmRvY3VtZW50SUQ9InhtcC5kaWQ6QjNDNTFBQjUxQkFGMTFFMzg0ODdGREZDMDcxRjE0NEUiLz4gPC9yZGY6RGVzY3JpcHRpb24+IDwvcmRmOlJERj4gPC94OnhtcG1ldGE+ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgPD94cGFja2V0IGVuZD0idyI/Pv/bAEMAAwICAwICAwMDAwQDAwQFCAUFBAQFCgcHBggMCgwMCwoLCw0OEhANDhEOCwsQFhARExQVFRUMDxcYFhQYEhQVFP/bAEMBAwQEBQQFCQUFCRQNCw0UFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFP/AABEIAD8APQMBIgACEQEDEQH/xAAfAAABBQEBAQEBAQAAAAAAAAAAAQIDBAUGBwgJCgv/xAC1EAACAQMDAgQDBQUEBAAAAX0BAgMABBEFEiExQQYTUWEHInEUMoGRoQgjQrHBFVLR8CQzYnKCCQoWFxgZGiUmJygpKjQ1Njc4OTpDREVGR0hJSlNUVVZXWFlaY2RlZmdoaWpzdHV2d3h5eoOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4eLj5OXm5+jp6vHy8/T19vf4+fr/xAAfAQADAQEBAQEBAQEBAAAAAAAAAQIDBAUGBwgJCgv/xAC1EQACAQIEBAMEBwUEBAABAncAAQIDEQQFITEGEkFRB2FxEyIygQgUQpGhscEJ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" /><br />
Line 6<br />
Line 7<br />
Line 8<br />
Line 9<br />
Line 10
END
        },
        Name => "Create: Article | Content HTML | TicketID $TicketID3"
    },
    {
        Config => {
            TicketID        => $TicketID3,
            Channel         => 'note',
            CustomerVisible => 0,
            SenderType      => 'agent',
            From            => 'unit.test@ut.com',
            To              => 'unit.test2@ut.com',
            Subject         => 'UnitTest Article with special html',
            ContentType     => 'text/html; charset=utf8',
            UserID          => $User1{UserID},
            HistoryType     => 'AddNote',
            HistoryComment  => 'UnitTest Special HTML Article!',
            Body => <<'END'
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
<head>
    <link type="text/css">
    <script scr="some.source">
</head>
<body>
    <!--
    <meta>
    <br>
    </br>
    <span
        class="someClass"
    >
        <div>
            <div>
END
        },
        Name   => "Create: Article | Content HTML with special tags | TicketID $TicketID3"
    }
);

my @Articles;
for my $Data ( @ArticleConfigs ) {
    push(
        @Articles,
        _CreateArticle(
            %{$Data}
        )
    );
}

my @UnitTests;
# placeholder of KIX_ARTICLE_, KIX_FIRST_ and KIX_CUSTOMER_ with first article
my @PH_Article;
my @PH_First;
my @PH_Customer;
for my $Attribute ( sort keys %{$Articles[0]} ) {

    # KIX_ARTICLE_
    push(
        @PH_Article,
        {
            Name      => "Placeholder: <KIX_ARTICLE_$Attribute>",
            Data      => {
                RichText  => 0,
                Text      => "<KIX_ARTICLE_$Attribute>",
                TicketID  => $TicketID1,
                UserID    => 1,
                Data      => {
                    ArticleID => $Articles[0]{ArticleID}
                }
            },
            Expection => defined $Articles[0]{$Attribute} ? $Articles[0]{$Attribute} : q{-},
        }
    );

    # KIX_FIRST_
    push(
        @PH_First,
        {
            Name      => "Placeholder: <KIX_FIRST_$Attribute>",
            Data      => {
                RichText  => 0,
                Text      => "<KIX_FIRST_$Attribute>",
                TicketID  => $TicketID1,
                UserID    => 1,
                Data      => {}
            },
            Expection => defined $Articles[0]{$Attribute} ? $Articles[0]{$Attribute} : q{-},
        }
    );

    # KIX_CUSTOMER_
    push(
        @PH_Customer,
        {
            Name      => "Placeholder: <KIX_CUSTOMER_$Attribute>",
            Data      => {
                RichText  => 0,
                Text      => "<KIX_CUSTOMER_$Attribute>",
                TicketID  => $TicketID1,
                UserID    => 1,
                Data      => {}
            },
            Expection => defined $Articles[0]{$Attribute} ? $Articles[0]{$Attribute} : q{-},
        }
    );
}

push( @UnitTests, @PH_Article, @PH_First, @PH_Customer );

# placeholder of KIX_ARTICLE_DATA_, KIX_LAST_, KIX_AGENT_, KIX_CUSTOMER_ with second article
my @PH_ArticleData;
my @PH_Last;
my @PH_Agent;
for my $Attribute ( sort keys %{$Articles[1]} ) {
    # KIX_ARTICLE_DATA_
    push(
        @PH_ArticleData,
        {
            Name      => "Placeholder: <KIX_ARTICLE_DATA_$Attribute>",
            Data      => {
                RichText  => 0,
                Text      => "<KIX_ARTICLE_DATA_$Attribute>",
                TicketID  => $TicketID1,
                UserID    => 1,
                Data      => {
                    ArticleID => $Articles[1]{ArticleID}
                }
            },
            Expection => defined $Articles[1]{$Attribute} ? $Articles[1]{$Attribute} : q{-},
        }
    );

    # KIX_LAST_
    push(
        @PH_Last,
        {
            Name      => "Placeholder: <KIX_LAST_$Attribute>",
            Data      => {
                RichText  => 0,
                Text      => "<KIX_LAST_$Attribute>",
                TicketID  => $TicketID1,
                UserID    => 1,
                Data      => {}
            },
            Expection => defined $Articles[1]{$Attribute} ? $Articles[1]{$Attribute} : q{-},
        }
    );

    # KIX_AGENT_
    push(
        @PH_Agent,
        {
            Name      => "Placeholder: <KIX_AGENT_$Attribute>",
            Data      => {
                RichText  => 0,
                Text      => "<KIX_AGENT_$Attribute>",
                TicketID  => $TicketID1,
                UserID    => 1,
                Data      => {}
            },
            Expection => defined $Articles[1]{$Attribute} ? $Articles[1]{$Attribute} : q{-},
        }
    );
}
push( @UnitTests, @PH_ArticleData, @PH_Last, @PH_Agent );

# placeholder of KIX_ARTICLE_ with ticket attributes there are not exists in article
for my $Attribute (
    qw(
        Queue State Type Priority
    )
) {
    push(
        @UnitTests,
        {
            Name      => "Placeholder: <KIX_ARTICLE_$Attribute> not exists",
            Data      => {
                RichText  => 0,
                Text      => "<KIX_ARTICLE_$Attribute>",
                TicketID  => $TicketID1,
                UserID    => 1,
                Data      => {}
            },
            Expection => defined $Articles[0]{$Attribute} ? $Articles[0]{$Attribute} : q{-}
        }
    );
}

# simple check for dynamic field placeholders - are they possible
push(
    @UnitTests,
    {
        Name      => 'Article dynamic field placeholder test',
        Data      => {
            RichText  => 0,
            Text      => "ARTICLE: <KIX_ARTICLE_DynamicField_ArticlePlaceholderTestDF>, FIRST: <KIX_FIRST_DynamicField_ArticlePlaceholderTestDF>, LAST: <KIX_LAST_DynamicField_ArticlePlaceholderTestDF>, AGENT: <KIX_AGENT_DynamicField_ArticlePlaceholderTestDF>, CUSTOMER: <KIX_CUSTOMER_DynamicField_ArticlePlaceholderTestDF>",
            TicketID  => $TicketID1,
            UserID    => 1,
            Data      => {
                ArticleID => $Articles[0]{ArticleID}
            }
        },
        Expection => "ARTICLE: $Articles[0]{Subject}, FIRST: $Articles[0]{Subject}, LAST: $Articles[1]{Subject}, AGENT: $Articles[1]{Subject}, CUSTOMER: $Articles[0]{Subject}",
    }
);

# body placeholder with limit
push(
    @UnitTests,
    {
        Data => {
            RichText  => 1,
            Text      => '<KIX_ARTICLE_Body>',
            Data      => {
                ArticleID => $Articles[2]{ArticleID}
            },
            TicketID  => $TicketID2,
            UserID    => 1
        },
        Expection => 'This is a text for body limit tests.',
        Name      => 'Placeholder: <KIX_ARTICLE_Body>'
    },
    {
        Data => {
            RichText  => 1,
            Text      => '<KIX_ARTICLE_Body_6>',
            Data      => {
                ArticleID => $Articles[2]{ArticleID}
            },
            TicketID  => $TicketID2,
            UserID    => 1
        },
        Expection => 'This i [...]',
        Name      => 'Placeholder: <KIX_ARTICLE_Body_6>'
    },
    {
        Data => {
            RichText  => 1,
            Text      => "<KIX_ARTICLE_Body_6>\n-----\n<KIX_ARTICLE_Body_8>",
            Data      => {
                ArticleID => $Articles[2]{ArticleID}
            },
            TicketID  => $TicketID2,
            UserID    => 1
        },
        Expection => "This i [...]\n-----\nThis is  [...]",
        Name      => 'Placeholder: <KIX_ARTICLE_Body_6> and <KIX_ARTICLE_Body_8>'
    },
    {
        Data => {
            RichText  => 1,
            Text      => '<KIX_ARTICLE_BodyRichtext>',
            Data      => {
                ArticleID => $Articles[3]{ArticleID}
            },
            TicketID  => $TicketID3,
            UserID    => 1
        },
        Config    => {
            Key   => 'Ticket::Placeholder::BodyRichtext::DefaultLineCount',
            Value => 99
        },
        Expection => <<'END',
Line 1<br />
Line 2<br />
Line 3
<div>
    <table border="1" cellpadding="1" cellspacing="1" style="width:500px">
        <tbody>
            <tr>
                <td>Column 1:1</td>
                <td>
                    <div>Column 1:2</div>
                </td>
            </tr>
            <tr>
                <td>Column 2:1</td>
                <td>Column 2:2</td>
            </tr>
            <tr>
                <td>Column 3:1</td>
                <td>Column 3:2</td>
            </tr>
        </tbody>
    </table>
</div>
Line 4<br />
Line 5<br />
<img alt="" src="data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/4QBoRXhpZgAASUkqAAgAAAADABIBAwABAAAAAQAAADEBAgAQAAAAMgAAAGmHBAABAAAAQgAAAAAAAABTaG90d2VsbCAwLjIyLjAAAgACoAkAAQAAAD0AAAADoAkAAQAAAD8AAAAAAAAA/+ELyWh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8APD94cGFja2V0IGJlZ2luPSLvu78iIGlkPSJXNU0wTXBDZWhpSHpyZVN6TlRjemtjOWQiPz4gPHg6eG1wbWV0YSB4bWxuczp4PSJhZG9iZTpuczptZXRhLyIgeDp4bXB0az0iWE1QIENvcmUgNC40LjAtRXhpdjIiPiA8cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkvMDIvMjItcmRmLXN5bnRheC1ucyMiPiA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0iIiB4bWxuczp4bXA9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iIHhtbG5zOnhtcE1NPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvbW0vIiB4bWxuczpzdFJlZj0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL3NUeXBlL1Jlc291cmNlUmVmIyIgeG1sbnM6ZXhpZj0iaHR0cDovL25zLmFkb2JlLmNvbS9leGlmLzEuMC8iIHhtbG5zOnRpZmY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vdGlmZi8xLjAvIiB4bXA6Q3JlYXRvclRvb2w9IkFkb2JlIFBob3Rvc2hvcCBDUzUgV2luZG93cyIgeG1wTU06SW5zdGFuY2VJRD0ieG1wLmlpZDpCM0M1MUFCNjFCQUYxMUUzODQ4N0ZERkMwNzFGMTQ0RSIgeG1wTU06RG9jdW1lbnRJRD0ieG1wLmRpZDpCM0M1MUFCNzFCQUYxMUUzODQ4N0ZERkMwNzFGMTQ0RSIgZXhpZjpQaXhlbFhEaW1lbnNpb249IjYxIiBleGlmOlBpeGVsWURpbWVuc2lvbj0iNjMiIHRpZmY6SW1hZ2VXaWR0aD0iNjEiIHRpZmY6SW1hZ2VIZWlnaHQ9IjYzIiB0aWZmOk9yaWVudGF0aW9uPSIxIj4gPHhtcE1NOkRlcml2ZWRGcm9tIHN0UmVmOmluc3RhbmNlSUQ9InhtcC5paWQ6QjNDNTFBQjQxQkFGMTFFMzg0ODdGREZDMDcxRjE0NEUiIHN0UmVmOmRvY3VtZW50SUQ9InhtcC5kaWQ6QjNDNTFBQjUxQkFGMTFFMzg0ODdGREZDMDcxRjE0NEUiLz4gPC9yZGY6RGVzY3JpcHRpb24+IDwvcmRmOlJERj4gPC94OnhtcG1ldGE+ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgPD94cGFja2V0IGVuZD0idyI/Pv/bAEMAAwICAwICAwMDAwQDAwQFCAUFBAQFCgcHBggMCgwMCwoLCw0OEhANDhEOCwsQFhARExQVFRUMDxcYFhQYEhQVFP/bAEMBAwQEBQQFCQUFCRQNCw0UFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFP/AABEIAD8APQMBIgACEQEDEQH/xAAfAAABBQEBAQEBAQAAAAAAAAAAAQIDBAUGBwgJCgv/xAC1EAACAQMDAgQDBQUEBAAAAX0BAgMABBEFEiExQQYTUWEHInEUMoGRoQgjQrHBFVLR8CQzYnKCCQoWFxgZGiUmJygpKjQ1Njc4OTpDREVGR0hJSlNUVVZXWFlaY2RlZmdoaWpzdHV2d3h5eoOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4eLj5OXm5+jp6vHy8/T19vf4+fr/xAAfAQADAQEBAQEBAQEBAAAAAAAAAQIDBAUGBwgJCgv/xAC1EQACAQIEBAMEBwUEBAABAncAAQIDEQQFITEGEkFRB2FxEyIygQgUQpGhscEJ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" /><br />
Line 6<br />
Line 7<br />
Line 8<br />
Line 9<br />
Line 10
END
        Name      => 'Placeholder: <KIX_ARTICLE_Body>'
    },
    {
        Data => {
            RichText  => 1,
            Text      => '<KIX_ARTICLE_BodyRichtext_0>',
            Data      => {
                ArticleID => $Articles[3]{ArticleID}
            },
            TicketID  => $TicketID3,
            UserID    => 1
        },
        Config    => {
            Key   => 'Ticket::Placeholder::BodyRichtext::DefaultLineCount',
            Value => 5
        },
        Expection =>  <<'END',
Line 1<br />
Line 2<br />
Line 3
<div>
    <table border="1" cellpadding="1" cellspacing="1" style="width:500px">
        <tbody>
            <tr>
                <td>Column 1:1</td>
                <td>
                    <div>Column 1:2</div>
                </td>
            </tr>
            <tr>
                <td>Column 2:1</td>
                <td>Column 2:2</td>
            </tr>
            <tr>
                <td>Column 3:1</td>
                <td>Column 3:2</td>
            </tr>
        </tbody>
    </table>
</div>
Line 4<br />
Line 5<br />
<img alt="" src="data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/4QBoRXhpZgAASUkqAAgAAAADABIBAwABAAAAAQAAADEBAgAQAAAAMgAAAGmHBAABAAAAQgAAAAAAAABTaG90d2VsbCAwLjIyLjAAAgACoAkAAQAAAD0AAAADoAkAAQAAAD8AAAAAAAAA/+ELyWh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8APD94cGFja2V0IGJlZ2luPSLvu78iIGlkPSJXNU0wTXBDZWhpSHpyZVN6TlRjemtjOWQiPz4gPHg6eG1wbWV0YSB4bWxuczp4PSJhZG9iZTpuczptZXRhLyIgeDp4bXB0az0iWE1QIENvcmUgNC40LjAtRXhpdjIiPiA8cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkvMDIvMjItcmRmLXN5bnRheC1ucyMiPiA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0iIiB4bWxuczp4bXA9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iIHhtbG5zOnhtcE1NPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvbW0vIiB4bWxuczpzdFJlZj0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL3NUeXBlL1Jlc291cmNlUmVmIyIgeG1sbnM6ZXhpZj0iaHR0cDovL25zLmFkb2JlLmNvbS9leGlmLzEuMC8iIHhtbG5zOnRpZmY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vdGlmZi8xLjAvIiB4bXA6Q3JlYXRvclRvb2w9IkFkb2JlIFBob3Rvc2hvcCBDUzUgV2luZG93cyIgeG1wTU06SW5zdGFuY2VJRD0ieG1wLmlpZDpCM0M1MUFCNjFCQUYxMUUzODQ4N0ZERkMwNzFGMTQ0RSIgeG1wTU06RG9jdW1lbnRJRD0ieG1wLmRpZDpCM0M1MUFCNzFCQUYxMUUzODQ4N0ZERkMwNzFGMTQ0RSIgZXhpZjpQaXhlbFhEaW1lbnNpb249IjYxIiBleGlmOlBpeGVsWURpbWVuc2lvbj0iNjMiIHRpZmY6SW1hZ2VXaWR0aD0iNjEiIHRpZmY6SW1hZ2VIZWlnaHQ9IjYzIiB0aWZmOk9yaWVudGF0aW9uPSIxIj4gPHhtcE1NOkRlcml2ZWRGcm9tIHN0UmVmOmluc3RhbmNlSUQ9InhtcC5paWQ6QjNDNTFBQjQxQkFGMTFFMzg0ODdGREZDMDcxRjE0NEUiIHN0UmVmOmRvY3VtZW50SUQ9InhtcC5kaWQ6QjNDNTFBQjUxQkFGMTFFMzg0ODdGREZDMDcxRjE0NEUiLz4gPC9yZGY6RGVzY3JpcHRpb24+IDwvcmRmOlJERj4gPC94OnhtcG1ldGE+ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgPD94cGFja2V0IGVuZD0idyI/Pv/bAEMAAwICAwICAwMDAwQDAwQFCAUFBAQFCgcHBggMCgwMCwoLCw0OEhANDhEOCwsQFhARExQVFRUMDxcYFhQYEhQVFP/bAEMBAwQEBQQFCQUFCRQNCw0UFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFP/AABEIAD8APQMBIgACEQEDEQH/xAAfAAABBQEBAQEBAQAAAAAAAAAAAQIDBAUGBwgJCgv/xAC1EAACAQMDAgQDBQUEBAAAAX0BAgMABBEFEiExQQYTUWEHInEUMoGRoQgjQrHBFVLR8CQzYnKCCQoWFxgZGiUmJygpKjQ1Njc4OTpDREVGR0hJSlNUVVZXWFlaY2RlZmdoaWpzdHV2d3h5eoOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4eLj5OXm5+jp6vHy8/T19vf4+fr/xAAfAQADAQEBAQEBAQEBAAAAAAAAAQIDBAUGBwgJCgv/xAC1EQACAQIEBAMEBwUEBAABAncAAQIDEQQFITEGEkFRB2FxEyIygQgUQpGhscEJ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" /><br />
Line 6<br />
Line 7<br />
Line 8<br />
Line 9<br />
Line 10
END
        Name      => 'Placeholder: <KIX_ARTICLE_BodyRichtext_0>'
    },
    {
        Data => {
            RichText  => 1,
            Text      => '<KIX_ARTICLE_BodyRichtext>',
            Data      => {
                ArticleID => $Articles[3]{ArticleID}
            },
            TicketID  => $TicketID3,
            UserID    => 1
        },
        Expection => 'Line 1<br />
Line 2<br />
Line 3
<div>
    <table border="1" cellpadding="1" cellspacing="1" style="width:500px">
</table>
</div>
[...]',
        Name      => 'Placeholder: <KIX_ARTICLE_BodyRichtext> (config reduced)'
    },
    {
        Data => {
            RichText  => 1,
            Text      => '<KIX_ARTICLE_BodyRichtext_8>',
            Data      => {
                ArticleID => $Articles[3]{ArticleID}
            },
            TicketID  => $TicketID3,
            UserID    => 1
        },
        Expection => 'Line 1<br />
Line 2<br />
Line 3
<div>
    <table border="1" cellpadding="1" cellspacing="1" style="width:500px">
        <tbody>
            <tr>
                <td>Column 1:1</td>
</tr>
</tbody>
</table>
</div>
[...]',
        Name      => 'Placeholder: <KIX_ARTICLE_BodyRichtext_8>'
    },
    {
        Data => {
            RichText  => 1,
            Text      => '<KIX_ARTICLE_BodyRichtext_10>',
            Data      => {
                ArticleID => $Articles[3]{ArticleID}
            },
            TicketID  => $TicketID3,
            UserID    => 1
        },
        Expection => 'Line 1<br />
Line 2<br />
Line 3
<div>
    <table border="1" cellpadding="1" cellspacing="1" style="width:500px">
        <tbody>
            <tr>
                <td>Column 1:1</td>
                <td>
                    <div>Column 1:2</div>
</td>
</tr>
</tbody>
</table>
</div>
[...]',
        Name      => 'Placeholder: <KIX_ARTICLE_BodyRichtext_10>'
    },
    {
        Data => {
            RichText  => 1,
            Text      => "<KIX_ARTICLE_BodyRichtext>\n-----\n<KIX_ARTICLE_BodyRichtext_8>",
            Data      => {
                ArticleID => $Articles[3]{ArticleID}
            },
            TicketID  => $TicketID3,
            UserID    => 1
        },
        Expection => 'Line 1<br />
Line 2<br />
Line 3
<div>
    <table border="1" cellpadding="1" cellspacing="1" style="width:500px">
</table>
</div>
[...]
-----
Line 1<br />
Line 2<br />
Line 3
<div>
    <table border="1" cellpadding="1" cellspacing="1" style="width:500px">
        <tbody>
            <tr>
                <td>Column 1:1</td>
</tr>
</tbody>
</table>
</div>
[...]',
        Name => 'Placeholder: <KIX_ARTICLE_BodyRichtext> and <KIX_ARTICLE_BodyRichtext_8>'
    },
    # do not close !DOCETYPE, link, script, comment, meta and line breaks but consider mulitplie span
    # DOCETYPE, Head (with content) and Body will be removed completely (HTMLUtils->DocumentStrip)
    # => only close span
    {
        Data => {
            RichText  => 1,
            Text      => '<KIX_ARTICLE_BodyRichtext_11>',
            Data      => {
                ArticleID => $Articles[4]{ArticleID}
            },
            TicketID  => $TicketID3,
            UserID    => 1
        },
        Expection => '



    <!--
    <meta>
    <br>
    </br>
    <span
        class="someClass"
    >
</span>
[...]',
        Name => 'Placeholder: <KIX_ARTICLE_BodyRichtext_11> - special tags'
    },
    {
        Data => {
            RichText  => 1,
            Text      => '<KIX_FIRST_BodyRichtext>',
            Data      => {},
            TicketID  => $TicketID3,
            UserID    => 1
        },
        Config    => {
            Key   => 'Ticket::Placeholder::BodyRichtext::DefaultLineCount',
            Value => 99
        },
        Expection => <<'END',
Line 1<br />
Line 2<br />
Line 3
<div>
    <table border="1" cellpadding="1" cellspacing="1" style="width:500px">
        <tbody>
            <tr>
                <td>Column 1:1</td>
                <td>
                    <div>Column 1:2</div>
                </td>
            </tr>
            <tr>
                <td>Column 2:1</td>
                <td>Column 2:2</td>
            </tr>
            <tr>
                <td>Column 3:1</td>
                <td>Column 3:2</td>
            </tr>
        </tbody>
    </table>
</div>
Line 4<br />
Line 5<br />
<img alt="" src="data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/4QBoRXhpZgAASUkqAAgAAAADABIBAwABAAAAAQAAADEBAgAQAAAAMgAAAGmHBAABAAAAQgAAAAAAAABTaG90d2VsbCAwLjIyLjAAAgACoAkAAQAAAD0AAAADoAkAAQAAAD8AAAAAAAAA/+ELyWh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8APD94cGFja2V0IGJlZ2luPSLvu78iIGlkPSJXNU0wTXBDZWhpSHpyZVN6TlRjemtjOWQiPz4gPHg6eG1wbWV0YSB4bWxuczp4PSJhZG9iZTpuczptZXRhLyIgeDp4bXB0az0iWE1QIENvcmUgNC40LjAtRXhpdjIiPiA8cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkvMDIvMjItcmRmLXN5bnRheC1ucyMiPiA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0iIiB4bWxuczp4bXA9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iIHhtbG5zOnhtcE1NPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvbW0vIiB4bWxuczpzdFJlZj0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL3NUeXBlL1Jlc291cmNlUmVmIyIgeG1sbnM6ZXhpZj0iaHR0cDovL25zLmFkb2JlLmNvbS9leGlmLzEuMC8iIHhtbG5zOnRpZmY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vdGlmZi8xLjAvIiB4bXA6Q3JlYXRvclRvb2w9IkFkb2JlIFBob3Rvc2hvcCBDUzUgV2luZG93cyIgeG1wTU06SW5zdGFuY2VJRD0ieG1wLmlpZDpCM0M1MUFCNjFCQUYxMUUzODQ4N0ZERkMwNzFGMTQ0RSIgeG1wTU06RG9jdW1lbnRJRD0ieG1wLmRpZDpCM0M1MUFCNzFCQUYxMUUzODQ4N0ZERkMwNzFGMTQ0RSIgZXhpZjpQaXhlbFhEaW1lbnNpb249IjYxIiBleGlmOlBpeGVsWURpbWVuc2lvbj0iNjMiIHRpZmY6SW1hZ2VXaWR0aD0iNjEiIHRpZmY6SW1hZ2VIZWlnaHQ9IjYzIiB0aWZmOk9yaWVudGF0aW9uPSIxIj4gPHhtcE1NOkRlcml2ZWRGcm9tIHN0UmVmOmluc3RhbmNlSUQ9InhtcC5paWQ6QjNDNTFBQjQxQkFGMTFFMzg0ODdGREZDMDcxRjE0NEUiIHN0UmVmOmRvY3VtZW50SUQ9InhtcC5kaWQ6QjNDNTFBQjUxQkFGMTFFMzg0ODdGREZDMDcxRjE0NEUiLz4gPC9yZGY6RGVzY3JpcHRpb24+IDwvcmRmOlJERj4gPC94OnhtcG1ldGE+ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgPD94cGFja2V0IGVuZD0idyI/Pv/bAEMAAwICAwICAwMDAwQDAwQFCAUFBAQFCgcHBggMCgwMCwoLCw0OEhANDhEOCwsQFhARExQVFRUMDxcYFhQYEhQVFP/bAEMBAwQEBQQFCQUFCRQNCw0UFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFP/AABEIAD8APQMBIgACEQEDEQH/xAAfAAABBQEBAQEBAQAAAAAAAAAAAQIDBAUGBwgJCgv/xAC1EAACAQMDAgQDBQUEBAAAAX0BAgMABBEFEiExQQYTUWEHInEUMoGRoQgjQrHBFVLR8CQzYnKCCQoWFxgZGiUmJygpKjQ1Njc4OTpDREVGR0hJSlNUVVZXWFlaY2RlZmdoaWpzdHV2d3h5eoOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4eLj5OXm5+jp6vHy8/T19vf4+fr/xAAfAQADAQEBAQEBAQEBAAAAAAAAAQIDBAUGBwgJCgv/xAC1EQACAQIEBAMEBwUEBAABAncAAQIDEQQFITEGEkFRB2FxEyIygQgUQpGhscEJ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" /><br />
Line 6<br />
Line 7<br />
Line 8<br />
Line 9<br />
Line 10
END
        Name      => 'Placeholder: <KIX_FIRST_BodyRichtext>'
    },
    {
        Data => {
            RichText  => 1,
            Text      => '<KIX_FIRST_BodyRichtext_0>',
            Data      => {},
            TicketID  => $TicketID3,
            UserID    => 1
        },
        Config    => {
            Key   => 'Ticket::Placeholder::BodyRichtext::DefaultLineCount',
            Value => 5
        },
        Expection =>  <<'END',
Line 1<br />
Line 2<br />
Line 3
<div>
    <table border="1" cellpadding="1" cellspacing="1" style="width:500px">
        <tbody>
            <tr>
                <td>Column 1:1</td>
                <td>
                    <div>Column 1:2</div>
                </td>
            </tr>
            <tr>
                <td>Column 2:1</td>
                <td>Column 2:2</td>
            </tr>
            <tr>
                <td>Column 3:1</td>
                <td>Column 3:2</td>
            </tr>
        </tbody>
    </table>
</div>
Line 4<br />
Line 5<br />
<img alt="" src="data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/4QBoRXhpZgAASUkqAAgAAAADABIBAwABAAAAAQAAADEBAgAQAAAAMgAAAGmHBAABAAAAQgAAAAAAAABTaG90d2VsbCAwLjIyLjAAAgACoAkAAQAAAD0AAAADoAkAAQAAAD8AAAAAAAAA/+ELyWh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8APD94cGFja2V0IGJlZ2luPSLvu78iIGlkPSJXNU0wTXBDZWhpSHpyZVN6TlRjemtjOWQiPz4gPHg6eG1wbWV0YSB4bWxuczp4PSJhZG9iZTpuczptZXRhLyIgeDp4bXB0az0iWE1QIENvcmUgNC40LjAtRXhpdjIiPiA8cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkvMDIvMjItcmRmLXN5bnRheC1ucyMiPiA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0iIiB4bWxuczp4bXA9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iIHhtbG5zOnhtcE1NPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvbW0vIiB4bWxuczpzdFJlZj0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL3NUeXBlL1Jlc291cmNlUmVmIyIgeG1sbnM6ZXhpZj0iaHR0cDovL25zLmFkb2JlLmNvbS9leGlmLzEuMC8iIHhtbG5zOnRpZmY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vdGlmZi8xLjAvIiB4bXA6Q3JlYXRvclRvb2w9IkFkb2JlIFBob3Rvc2hvcCBDUzUgV2luZG93cyIgeG1wTU06SW5zdGFuY2VJRD0ieG1wLmlpZDpCM0M1MUFCNjFCQUYxMUUzODQ4N0ZERkMwNzFGMTQ0RSIgeG1wTU06RG9jdW1lbnRJRD0ieG1wLmRpZDpCM0M1MUFCNzFCQUYxMUUzODQ4N0ZERkMwNzFGMTQ0RSIgZXhpZjpQaXhlbFhEaW1lbnNpb249IjYxIiBleGlmOlBpeGVsWURpbWVuc2lvbj0iNjMiIHRpZmY6SW1hZ2VXaWR0aD0iNjEiIHRpZmY6SW1hZ2VIZWlnaHQ9IjYzIiB0aWZmOk9yaWVudGF0aW9uPSIxIj4gPHhtcE1NOkRlcml2ZWRGcm9tIHN0UmVmOmluc3RhbmNlSUQ9InhtcC5paWQ6QjNDNTFBQjQxQkFGMTFFMzg0ODdGREZDMDcxRjE0NEUiIHN0UmVmOmRvY3VtZW50SUQ9InhtcC5kaWQ6QjNDNTFBQjUxQkFGMTFFMzg0ODdGREZDMDcxRjE0NEUiLz4gPC9yZGY6RGVzY3JpcHRpb24+IDwvcmRmOlJERj4gPC94OnhtcG1ldGE+ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgPD94cGFja2V0IGVuZD0idyI/Pv/bAEMAAwICAwICAwMDAwQDAwQFCAUFBAQFCgcHBggMCgwMCwoLCw0OEhANDhEOCwsQFhARExQVFRUMDxcYFhQYEhQVFP/bAEMBAwQEBQQFCQUFCRQNCw0UFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFP/AABEIAD8APQMBIgACEQEDEQH/xAAfAAABBQEBAQEBAQAAAAAAAAAAAQIDBAUGBwgJCgv/xAC1EAACAQMDAgQDBQUEBAAAAX0BAgMABBEFEiExQQYTUWEHInEUMoGRoQgjQrHBFVLR8CQzYnKCCQoWFxgZGiUmJygpKjQ1Njc4OTpDREVGR0hJSlNUVVZXWFlaY2RlZmdoaWpzdHV2d3h5eoOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4eLj5OXm5+jp6vHy8/T19vf4+fr/xAAfAQADAQEBAQEBAQEBAAAAAAAAAQIDBAUGBwgJCgv/xAC1EQACAQIEBAMEBwUEBAABAncAAQIDEQQFITEGEkFRB2FxEyIygQgUQpGhscEJ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" /><br />
Line 6<br />
Line 7<br />
Line 8<br />
Line 9<br />
Line 10
END
        Name      => 'Placeholder: <KIX_FIRST_BodyRichtext_0>'
    },
    {
        Data => {
            RichText  => 1,
            Text      => '<KIX_FIRST_BodyRichtext>',
            Data      => {},
            TicketID  => $TicketID3,
            UserID    => 1
        },
        Expection => 'Line 1<br />
Line 2<br />
Line 3
<div>
    <table border="1" cellpadding="1" cellspacing="1" style="width:500px">
</table>
</div>
[...]',
        Name      => 'Placeholder: <KIX_FIRST_BodyRichtext> (config reduced)'
    },
    {
        Data => {
            RichText  => 1,
            Text      => '<KIX_FIRST_BodyRichtext_8>',
            Data      => {},
            TicketID  => $TicketID3,
            UserID    => 1
        },
        Expection => 'Line 1<br />
Line 2<br />
Line 3
<div>
    <table border="1" cellpadding="1" cellspacing="1" style="width:500px">
        <tbody>
            <tr>
                <td>Column 1:1</td>
</tr>
</tbody>
</table>
</div>
[...]',
        Name      => 'Placeholder: <KIX_FIRST_BodyRichtext_8>'
    },
    {
        Data => {
            RichText  => 1,
            Text      => '<KIX_FIRST_BodyRichtext_10>',
            Data      => {},
            TicketID  => $TicketID3,
            UserID    => 1
        },
        Expection => 'Line 1<br />
Line 2<br />
Line 3
<div>
    <table border="1" cellpadding="1" cellspacing="1" style="width:500px">
        <tbody>
            <tr>
                <td>Column 1:1</td>
                <td>
                    <div>Column 1:2</div>
</td>
</tr>
</tbody>
</table>
</div>
[...]',
        Name      => 'Placeholder: <KIX_FIRST_BodyRichtext_10>'
    },
    {
        Data => {
            RichText  => 1,
            Text      => "<KIX_FIRST_BodyRichtext>\n-----\n<KIX_FIRST_BodyRichtext_8>",
            Data      => {},
            TicketID  => $TicketID3,
            UserID    => 1
        },
        Expection => 'Line 1<br />
Line 2<br />
Line 3
<div>
    <table border="1" cellpadding="1" cellspacing="1" style="width:500px">
</table>
</div>
[...]
-----
Line 1<br />
Line 2<br />
Line 3
<div>
    <table border="1" cellpadding="1" cellspacing="1" style="width:500px">
        <tbody>
            <tr>
                <td>Column 1:1</td>
</tr>
</tbody>
</table>
</div>
[...]',
        Name => 'Placeholder: <KIX_FIRST_BodyRichtext> and <KIX_FIRST_BodyRichtext_8>'
    },
    {
        Data => {
            RichText  => 1,
            Text      => '<KIX_LAST_BodyRichtext>',
            Data      => {},
            TicketID  => $TicketID3,
            UserID    => 1
        },
        Config    => {
            Key   => 'Ticket::Placeholder::BodyRichtext::DefaultLineCount',
            Value => 99
        },
        Expection => '



    <!--
    <meta>
    <br>
    </br>
    <span
        class="someClass"
    >
        <div>
            <div>
',
        Name => 'Placeholder: <KIX_LAST_BodyRichtext> - special tags'
    },
    # do not close !DOCETYPE, link, script, comment, meta and line breaks but consider mulitplie span
    # DOCETYPE, Head (with content) and Body will be removed completely (HTMLUtils->DocumentStrip)
    # => only close span
    {
        Data => {
            RichText  => 1,
            Text      => '<KIX_LAST_BodyRichtext_11>',
            Data      => {},
            TicketID  => $TicketID3,
            UserID    => 1
        },
        Expection => '



    <!--
    <meta>
    <br>
    </br>
    <span
        class="someClass"
    >
</span>
[...]',
        Name => 'Placeholder: <KIX_LAST_BodyRichtext_11> - special tags'
    }
);

for my $Test ( @UnitTests ) {

    if ( IsHashRefWithData($Test->{Config}) ) {
        $Kernel::OM->Get('Config')->Set(
            %{$Test->{Config}}
        );
    }

    my $Result = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
        %{$Test->{Data}}
    );

    $Self->Is(
        $Result,
        $Test->{Expection},
        $Test->{Name}
    );
}

sub _CreateTicket {
    my (%Param) = @_;

    my $ID = $Kernel::OM->Get('Ticket')->TicketCreate(
        Title           => 'UnitTest Ticket ' . $Helper->GetRandomID(),
        Queue           => 'Junk',
        Lock            => 'unlock',
        Priority        => '3 normal',
        State           => 'new',
        OrganisationID  => $Param{Contact}{PrimaryOrganisationID},
        ContactID       => $Param{Contact}{UserID},
        OwnerID         => $Param{User}{UserID},
        UserID          => 1
    );

    $Self->True(
        $ID,
        $Param{Name}
    );

    $Kernel::OM->ObjectsDiscard(
        Objects => [
            'Ticket'
        ]
    );

    return $ID;
}

sub _CreateArticle {
    my (%Param) = @_;

    my $ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
        %{$Param{Config}}
    );

    my %Article = $Kernel::OM->Get('Ticket')->ArticleGet(
        ArticleID => $ArticleID,
        UserID    => 1
    );

    $Self->True(
        $ArticleID,
        $Param{Name}
    );

    my $Success = $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
        DynamicFieldConfig => $DynamicField,
        ObjectID           => $ArticleID,
        Value              => [$Param{Config}->{Subject}],
        UserID             => 1
    );

    $Self->True(
        $Success,
        "$Param{Name} | set DynamicField"
    );

    $Kernel::OM->ObjectsDiscard(
        Objects => [
            'Ticket'
        ]
    );

    return \%Article;
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