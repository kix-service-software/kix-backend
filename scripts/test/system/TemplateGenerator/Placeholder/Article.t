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

# begin transaction on database
$Helper->BeginWork();

my $TestUser    = $Helper->TestUserCreate(
    Roles => [
        'Ticket Agent'
    ]
);

my %User = $Kernel::OM->Get('User')->GetUserData(
    User  => $TestUser
);

my $TestContactID = $Helper->TestContactCreate();

my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
    ID => $TestContactID
);

my $TicketID = _CreateTicket(
    Contact  => \%Contact,
    User     => \%User,
    TestName => '_CreateTicket(): ticket create'
);

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
    'Added dynamic field'
);
my $DynamicField = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
    ID   => $DFID
);
$Self->True(
    IsHashRefWithData($DynamicField) ? 1 : 0,
    'Get dynamic field'
);

my %FirstArticle = (
    TicketID         => $TicketID,
    Channel          => 'email',
    CustomerVisible  => 1,
    SenderType       => 'external',
    To               => 'unit.test@ut.com',
    From             => "$Contact{Fullname} <$Contact{Email}>",
    Subject          => 'UnitTest First Article',
    Body             => 'UnitTest Body',
    ContentType      => 'text/plain; charset=utf8',
    HistoryType      => 'AddNote',
    HistoryComment   => 'UnitTest Article!',
    TimeUnit         => 5,
    UserID           => 1,
    Loop             => 0,
);

my %ArticleFirst = _CreateArticle(
    Config   => \%FirstArticle,
    TestName => '_CreateArticle(): First article create'
);

my %LastArticle = (
    TicketID         => $TicketID,
    Channel          => 'note',
    CustomerVisible  => 1,
    SenderType       => 'agent',
    From             => 'unit.test@ut.com',
    To               => "$Contact{Fullname} <$Contact{Email}>",
    Subject          => 'UnitTest Last Article',
    Body             => 'UnitTest Body',
    ContentType      => 'text/plain; charset=utf8',
    HistoryType      => 'AddNote',
    HistoryComment   => 'UnitTest Article!',
    TimeUnit         => 5,
    UserID           => $User{UserID},
);

my %ArticleLast = _CreateArticle(
    Config   => \%LastArticle,
    TestName => '_CreateArticle(): Last article create'
);

my @UnitTests;
# placeholder of KIX_ARTICLE_ with first article
for my $Attribute ( sort keys %ArticleFirst ) {
    push(
        @UnitTests,
        {
            TestName  => "Placeholder: <KIX_ARTICLE_$Attribute>",
            ArticleID => $ArticleFirst{ArticleID},
            Test      => "<KIX_ARTICLE_$Attribute>",
            Expection => defined $ArticleFirst{$Attribute} ? $ArticleFirst{$Attribute} : q{-},
        }
    );
}

# placeholder of KIX_FIRST_ with first article
for my $Attribute ( sort keys %ArticleFirst ) {
    push(
        @UnitTests,
        {
            TestName  => "Placeholder: <KIX_FIRST_$Attribute>",
            TicketID  => $ArticleFirst{TicketID},
            Test      => "<KIX_FIRST_$Attribute>",
            Expection => defined $ArticleFirst{$Attribute} ? $ArticleFirst{$Attribute} : q{-},
        }
    );
}

# placeholder of KIX_ARTICLE_DATA_ with second article
for my $Attribute ( sort keys %ArticleLast ) {
    push(
        @UnitTests,
        {
            TestName  => "Placeholder: <KIX_ARTICLE_DATA_$Attribute>",
            ArticleID => $ArticleLast{ArticleID},
            Test      => "<KIX_ARTICLE_DATA_$Attribute>",
            Expection => defined $ArticleLast{$Attribute} ? $ArticleLast{$Attribute} : q{-},
        }
    );
}

# placeholder of KIX_LAST_ with second article
for my $Attribute ( sort keys %ArticleLast ) {
    push(
        @UnitTests,
        {
            TestName  => "Placeholder: <KIX_LAST_$Attribute>",
            TicketID  => $ArticleLast{TicketID},
            Test      => "<KIX_LAST_$Attribute>",
            Expection => defined $ArticleLast{$Attribute} ? $ArticleLast{$Attribute} : q{-},
        }
    );
}

# placeholder of KIX_AGENT_ with last agent article
for my $Attribute ( sort keys %ArticleLast ) {
    push(
        @UnitTests,
        {
            TestName  => "Placeholder: <KIX_AGENT_$Attribute>",
            TicketID  => $ArticleLast{TicketID},
            Test      => "<KIX_AGENT_$Attribute>",
            Expection => defined $ArticleLast{$Attribute} ? $ArticleLast{$Attribute} : q{-},
        }
    );
}

# placeholder of KIX_CUSTOMER_ with last customer article
for my $Attribute ( sort keys %ArticleLast ) {
    push(
        @UnitTests,
        {
            TestName  => "Placeholder: <KIX_CUSTOMER_$Attribute>",
            TicketID  => $ArticleFirst{TicketID},
            Test      => "<KIX_CUSTOMER_$Attribute>",
            Expection => defined $ArticleFirst{$Attribute} ? $ArticleFirst{$Attribute} : q{-},
        }
    );
}

# placeholder of KIX_ARTICLE_ with ticket attributes there are not exists in article
for my $Attribute (
    qw(
        Queue State Type Priority
    )
) {
    push(
        @UnitTests,
        {
            TestName  => "Placeholder: <KIX_ARTICLE_$Attribute> not exists",
            TicketID  => $ArticleFirst{TicketID},
            Test      => "<KIX_ARTICLE_$Attribute>",
            Expection => defined $ArticleFirst{$Attribute} ? $ArticleFirst{$Attribute} : q{-},
        }
    );
}

_TestRun(
    Tests => \@UnitTests
);

sub _TestRun {
    my (%Param) = @_;

    for my $Test ( @{$Param{Tests}} ) {
        my $Result = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
            RichText  => 0,                                         # if html qouting is needed
            Text      => $Test->{Test},
            Data      => {
                ArticleID => $Test->{ArticleID} || undef
            },
            TicketID  => $Test->{TicketID} || undef,
            UserID    => 1
        );

        $Self->Is(
            $Result,
            $Test->{Expection},
            $Test->{TestName}
        );
    }

    return 1;
}

# simple check for dynamic field placeholders - are they possible
my $Result = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
    RichText  => 0,
    Text      => "ARTICLE: <KIX_ARTICLE_DynamicField_ArticlePlaceholderTestDF>, FIRST: <KIX_FIRST_DynamicField_ArticlePlaceholderTestDF>, LAST: <KIX_LAST_DynamicField_ArticlePlaceholderTestDF>, AGENT: <KIX_AGENT_DynamicField_ArticlePlaceholderTestDF>, CUSTOMER: <KIX_CUSTOMER_DynamicField_ArticlePlaceholderTestDF>",
    Data      => {
        ArticleID => $ArticleFirst{ArticleID}
    },
    TicketID  => $TicketID,
    UserID    => 1
);
$Self->Is(
    $Result,
    "ARTICLE: $ArticleFirst{Subject}, FIRST: $ArticleFirst{Subject}, LAST: $ArticleLast{Subject}, AGENT: $ArticleLast{Subject}, CUSTOMER: $ArticleFirst{Subject}",
    'Article dynamic field placeholder test'
);

sub _CreateTicket {
    my (%Param) = @_;

    my $ID = $Kernel::OM->Get('Ticket')->TicketCreate(
        Title           => 'UnitTest Ticket ' . $Helper->GetRandomID(),
        Queue           => 'Junk',
        Lock            => 'unlock',
        Priority        => '3 normal',
        State           => 'new',
        OrganisationID  => $Contact{PrimaryOrganisationID},
        ContactID       => $Contact{UserID},
        OwnerID         => $User{UserID},
        UserID          => 1
    );

    $Self->True(
        $ID,
        $Param{TestName}
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
        $Param{TestName}
    );

    my $Success = $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
        DynamicFieldConfig => $DynamicField,
        ObjectID           => $ArticleID,
        Value              => [$Param{Config}->{Subject}],
        UserID             => 1
    );

    $Self->True(
        $Success,
        "$Param{TestName} :: set dynamic field"
    );

    $Kernel::OM->ObjectsDiscard(
        Objects => [
            'Ticket'
        ]
    );

    return %Article;
}

# -----------------------------
# body placeholder with limit
my %Article = _CreateArticle(
    Config   => {
        TicketID        => $TicketID,
        Channel         => 'note',
        CustomerVisible => 0,
        SenderType      => 'agent',
        From            => 'unit.test@ut.com',
        To              => 'unit.test2@ut.com',
        Subject         => 'UnitTest Article',
        ContentType     => 'text/text; charset=utf8',
        UserID          => $User{UserID},
        HistoryType     => 'AddNote',
        HistoryComment  => 'UnitTest HTML Article!',
        Body            => 'This is a text for body limit tests.'
    },
    TestName => '_CreateArticle(): body limit article create'
);

# full body
my $Result = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
    RichText  => 1,
    Text      => '<KIX_ARTICLE_Body>',
    Data      => {ArticleID => $Article{ArticleID}},
    TicketID  => $TicketID,
    UserID    => 1
);
$Self->Is(
    $Result,
    'This is a text for body limit tests.',
    'Placeholder: <KIX_ARTICLE_Body>'
);

# limited body
my $Result = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
    RichText  => 1,
    Text      => '<KIX_ARTICLE_Body_6>',
    Data      => {ArticleID => $Article{ArticleID}},
    TicketID  => $TicketID,
    UserID    => 1
);
$Self->Is(
    $Result,
    'This i [...]',
    'Placeholder: <KIX_ARTICLE_Body_6>'
);

# 2 limited bodies
$Result = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
    RichText  => 1,
    Text      => "<KIX_ARTICLE_Body_6>\n-----\n<KIX_ARTICLE_Body_8>",
    Data      => {ArticleID => $Article{ArticleID}},
    TicketID  => $TicketID,
    UserID    => 1
);
$Self->Is(
    $Result,
    "This i [...]\n-----\nThis is  [...]",
    'Placeholder: <KIX_ARTICLE_Body_6> and <KIX_ARTICLE_Body_8>'
);

# -----------------------------
# add article with html content
my $Body = 'Line 1<br />
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
Line 10';
my %ArticleHTML = _CreateArticle(
    Config   => {
        TicketID        => $TicketID,
        Channel         => 'note',
        CustomerVisible => 0,
        SenderType      => 'agent',
        From            => 'unit.test@ut.com',
        To              => 'unit.test2@ut.com',
        Subject         => 'UnitTest Article with html',
        ContentType     => 'text/html; charset=utf8',
        UserID          => $User{UserID},
        HistoryType     => 'AddNote',
        HistoryComment  => 'UnitTest HTML Article!',
        Body            => $Body
    },
    TestName => '_CreateArticle(): html article create'
);

$Kernel::OM->Get('Config')->Set(
    Key   => 'Ticket::Placeholder::BodyRichtext::DefaultLineCount',
    Value => 99
);

# full html
$Result = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
    RichText  => 1,
    Text      => '<KIX_ARTICLE_BodyRichtext>',
    Data      => {
        ArticleID => $ArticleHTML{ArticleID}
    },
    TicketID  => $TicketID,
    UserID    => 1
);
$Self->Is(
    $Result,
    $Body,
    'Placeholder: <KIX_ARTICLE_BodyRichtext>'
);

# reduce config
$Kernel::OM->Get('Config')->Set(
    Key   => 'Ticket::Placeholder::BodyRichtext::DefaultLineCount',
    Value => 5
);

# full html 2.0
$Result = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
    RichText  => 1,
    Text      => '<KIX_ARTICLE_BodyRichtext_0>',
    Data      => {
        ArticleID => $ArticleHTML{ArticleID}
    },
    TicketID  => $TicketID,
    UserID    => 1
);
$Self->Is(
    $Result,
    $Body,
    'Placeholder: <KIX_ARTICLE_BodyRichtext_0>'
);

# 5 lines because of config
$Result = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
    RichText  => 1,
    Text      => '<KIX_ARTICLE_BodyRichtext>',
    Data      => {
        ArticleID => $ArticleHTML{ArticleID}
    },
    TicketID  => $TicketID,
    UserID    => 1
);
$Self->Is(
    $Result,
    'Line 1<br />
Line 2<br />
Line 3
<div>
    <table border="1" cellpadding="1" cellspacing="1" style="width:500px">
</table>
</div>
[...]', # should add missing closing tags and [...]
    'Placeholder: <KIX_ARTICLE_BodyRichtext> (config reduced)'
);

# 8 lines because defined in placeholder
$Result = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
    RichText  => 1,
    Text      => '<KIX_ARTICLE_BodyRichtext_8>',
    Data      => {
        ArticleID => $ArticleHTML{ArticleID}
    },
    TicketID  => $TicketID,
    UserID    => 1
);
$Self->Is(
    $Result,
    'Line 1<br />
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
[...]', # should add missing closing tags and [...]
    'Placeholder: <KIX_ARTICLE_BodyRichtext_8>'
);

# 9 lines because defined in placeholder (check if last div )
$Result = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
    RichText  => 1,
    Text      => '<KIX_ARTICLE_BodyRichtext_10>',
    Data      => {
        ArticleID => $ArticleHTML{ArticleID}
    },
    TicketID  => $TicketID,
    UserID    => 1
);
$Self->Is(
    $Result,
    'Line 1<br />
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
[...]', # should add missing closing tags and [...]
    'Placeholder: <KIX_ARTICLE_BodyRichtext_10>'
);

# 2 times body, one reduced  by config one reduced by placeholder
$Result = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
    RichText  => 1,
    Text      => "<KIX_ARTICLE_BodyRichtext>\n-----\n<KIX_ARTICLE_BodyRichtext_8>",
    Data      => {
        ArticleID => $ArticleHTML{ArticleID}
    },
    TicketID  => $TicketID,
    UserID    => 1
);
$Self->Is(
    $Result,
    'Line 1<br />
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
[...]', # should add missing closing tags and [...]
    'Placeholder: <KIX_ARTICLE_BodyRichtext> and <KIX_ARTICLE_BodyRichtext_8>'
);

# test some "special" tags (ignore some and consider multiline)
my $SpecialBody = '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
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
            <div>';
my %SpecialArticleHTML = _CreateArticle(
    Config   => {
        TicketID        => $TicketID,
        Channel         => 'note',
        CustomerVisible => 0,
        SenderType      => 'agent',
        From            => 'unit.test@ut.com',
        To              => 'unit.test2@ut.com',
        Subject         => 'UnitTest Article with html',
        ContentType     => 'text/html; charset=utf8',
        UserID          => $User{UserID},
        HistoryType     => 'AddNote',
        HistoryComment  => 'UnitTest HTML Article!',
        Body            => $SpecialBody
    },
    TestName => '_CreateArticle(): html article create with some special tags'
);

# do not close !DOCETYPE, link, script, comment, meta and line breaks but consider mulitplie span
# DOCETYPE, Head (with content) and Body will be removed completely (HTMLUtils->DocumentStrip)
# => only close span
my $SpecialResult = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
    RichText  => 1,
    Text      => '<KIX_ARTICLE_BodyRichtext_11>',
    Data      => {
        ArticleID => $SpecialArticleHTML{ArticleID}
    },
    TicketID  => $TicketID,
    UserID    => 1
);
$Self->Is(
    $SpecialResult,
    '



    <!--
    <meta>
    <br>
    </br>
    <span
        class="someClass"
    >
</span>
[...]',
    'Placeholder: <KIX_ARTICLE_BodyRichtext_11> - special tags'
);

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