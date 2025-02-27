# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use vars qw($Self);

use Kernel::System::FAQ;

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my $CacheObject = $Kernel::OM->Get('Cache');

my $AddignedUser  = $Helper->GetRandomID();
my $AddignedUser2 = $Helper->GetRandomID();

my $ItemID = $Kernel::OM->Get('FAQ')->FAQLookup(
    Number => '123807670',
    Silent => 1
);

$Self->Is(
    $ItemID,
    undef,
    "FAQLookup() - Get ItemID with unknown number - should be undef"
);

my $FAQID = $Kernel::OM->Get('FAQ')->FAQAdd(
    Title       => 'Some Text',
    CategoryID  => 1,
    Visibility  => 'internal',
    Language    => 'en',
    Keywords    => 'some keywords',
    Field1      => 'Problem...',
    Field2      => 'Solution...',
    ContentType => 'text/html',
    UserID      => 1,
);
$Self->IsNot(
    $FAQID,
    undef,
    "FAQAdd() - 1",
);

my $FAQNumber = $Kernel::OM->Get('FAQ')->FAQLookup(
    FAQArticleID  => $FAQID,
);

$Self->True(
    $FAQNumber,
    "FAQLookup() - Get number for ItemID '$FAQID'"
);

my %FAQ = $Kernel::OM->Get('FAQ')->FAQGet(
    ItemID     => $FAQID,
    ItemFields => 1,
    UserID     => 1,
);
my $FAQNumber1 = $FAQ{Number};

my %FAQTest = (
    Title       => 'Some Text',
    CategoryID  => 1,
    Visibility  => 'internal',
    Language    => 'en',
    Keywords    => 'some keywords',
    Field1      => 'Problem...',
    Field2      => 'Solution...',
    ContentType => 'text/html',
);

for my $Test ( sort keys %FAQTest ) {
    $Self->Is(
        $FAQ{$Test},
        $FAQTest{$Test},
        "FAQGet() - $Test",
    );
}

$Kernel::OM->ObjectsDiscard(
    Objects => ['FAQ'],
);

my $FAQUpdate = $Kernel::OM->Get('FAQ')->FAQUpdate(
    %FAQ,
    ItemID      => $FAQID,
    CategoryID  => 1,
    Visibility  => 'external',
    Language    => 'de',
    Approved    => 1,
    Title       => 'Some Text2',
    Keywords    => 'some keywords2',
    Field1      => 'Problem...2',
    Field2      => 'Solution found...2',
    UserID      => 1,
    ContentType => 'text/plain',
);

%FAQ = $Kernel::OM->Get('FAQ')->FAQGet(
    ItemID     => $FAQID,
    ItemFields => 1,
    UserID     => 1,
);

%FAQTest = (
    Title       => 'Some Text2',
    CategoryID  => 1,
    Visibility  => 'external',
    Language    => 'de',
    Keywords    => 'some keywords2',
    Field1      => 'Problem...2',
    Field2      => 'Solution found...2',
    ContentType => 'text/plain',
);

for my $Test ( sort keys %FAQTest ) {
    $Self->Is(
        $FAQTest{$Test},
        $FAQ{$Test},
        "FAQGet() - $Test",
    );
}
$Kernel::OM->ObjectsDiscard(
    Objects => ['FAQ'],
);

# voting tests
my @TestVotes = (
    {
        Config => {
            CreatedBy => $AddignedUser,
            Rate      => 100
        },
        Excaption => {
            Success => 0,
            Search  => 0
        },
        Name      => 'Added Vote (100) - Missing ItemID'
    },
    {
        Config => {
            ItemID    => $FAQID,
            Rate      => 100
        },
        Excaption => {
            Success => 0,
            Search  => 0
        },
        Name      => 'Added Vote (100) - Missing CreatedBy'
    },
    {
        Config => {
            CreatedBy => $AddignedUser,
            ItemID    => $FAQID,
            Rate      => 100
        },
        Excaption => {
            Success => 1,
            Search  => 1
        },
        Name      => 'Added Vote (100) - with true'
    },
    {
        Config => {
            CreatedBy => $AddignedUser,
            ItemID    => $FAQID,
            Rate      => 50
        },
        Excaption => {
            Success => 1,
            Search  => 1
        },
        Name      => 'Added Vote (50) with same creator - with true'
    },
    {
        Config => {
            CreatedBy => $AddignedUser2,
            ItemID    => $FAQID,
            Rate      => 80
        },
        Excaption => {
            Success => 1,
            Search  => 2
        },
        Name      => 'Added Vote (80) with new creator - with true'
    },
);

my $Count = 1;
for my $Test ( @TestVotes ) {

    my $VoteID = $Kernel::OM->Get('FAQ')->VoteAdd(
        %{$Test->{Config}},
        UserID => 1
    );

    $Kernel::OM->ObjectsDiscard(
        Objects => ['FAQ'],
    );

    if ( $Test->{Excaption}->{Success} ) {
        $Self->True(
            $VoteID,
            "$Count# $Test->{Name}"
        );
    }
    else {
        $Self->False(
            $VoteID,
            $Test->{Name}
        );
        $Count++;
        next;
    }

    my $Votes = $Kernel::OM->Get('FAQ')->VoteSearch(
        ItemID => $Test->{Config}->{ItemID},
        UserID => 1
    );

    $Self->Is(
        scalar(@{$Votes}),
        $Test->{Excaption}->{Search},
        "$Count.5# Check total votes - with true"
    );

    $Count++;
}

my $FAQID15 = $Kernel::OM->Get('FAQ')->FAQAdd(
    Title       => 'Title',
    Visibility  => 'internal',
    CategoryID  => 1,
    Language    => 'en',
    Keywords    => q{},
    Field1      => 'Problem Description 1...',
    Field2      => 'Solution not found1...',
    ContentType => 'text/html',
    UserID      => 1,
    Number      => $FAQNumber1,
    Silent      => 1
);

$Self->Is(
    $FAQID15,
    undef,
    "FAQAdd() - 1.5 don't create FAQ with existing number - should be undef",
);


my $FAQNumber2 = $Helper->GetRandomNumber();
my $FAQID2 = $Kernel::OM->Get('FAQ')->FAQAdd(
    Title       => 'Title',
    Visibility  => 'internal',
    CategoryID  => 1,
    Language    => 'en',
    Keywords    => q{},
    Field1      => 'Problem Description 1...',
    Field2      => 'Solution not found1...',
    ContentType => 'text/html',
    UserID      => 1,
    Number      => $FAQNumber2
);

$Self->True(
    $FAQID2,
    "FAQAdd() - 2",
);

my $ItemID2 = $Kernel::OM->Get('FAQ')->FAQLookup(
    Number  => $FAQNumber2,
);

$Self->Is(
    $ItemID2,
    $FAQID2,
    "FAQLookup() - Get ItemID with number '$FAQNumber2'"
);

my $Home            = $Kernel::OM->Get('Config')->Get('Home');
my @AttachmentTests = (
    {
        File => 'FAQ-Test1.pdf',
        MD5  => '5ee767f3b68f24a9213e0bef82dc53e5',
    },
    {
        File => 'FAQ-Test1.doc',
        MD5  => '2e520036a0cda6a806a8838b1000d9d7',
    },
);

$Kernel::OM->ObjectsDiscard(
    Objects => ['FAQ'],
);

# get main object
my $MainObject = $Kernel::OM->Get('Main');

for my $AttachmentTest (@AttachmentTests) {
    my $ContentSCALARRef = $MainObject->FileRead(
        Location => $Home . '/scripts/test/system/sample/' . $AttachmentTest->{File},
    );
    my $Add = $Kernel::OM->Get('FAQ')->AttachmentAdd(
        ItemID      => $FAQID2,
        Content     => ${$ContentSCALARRef},
        ContentType => 'text/xml',
        Filename    => $AttachmentTest->{File},
        UserID      => 1,
    );
    $Self->True(
        $Add,
        "AttachmentAdd() - $AttachmentTest->{File}",
    );
    my @AttachmentIndex = $Kernel::OM->Get('FAQ')->AttachmentIndex(
        ItemID => $FAQID2,
        UserID => 1,
    );
    my %File = $Kernel::OM->Get('FAQ')->AttachmentGet(
        ItemID => $FAQID2,
        FileID => $AttachmentIndex[0]->{FileID},
        UserID => 1,
    );
    $Self->Is(
        $File{Filename},
        $AttachmentTest->{File},
        "AttachmentGet() - Filename $AttachmentTest->{File}",
    );
    my $MD5 = $MainObject->MD5sum(
        String => \$File{Content},
    );
    $Self->Is(
        $MD5,
        $AttachmentTest->{MD5},
        "AttachmentGet() - MD5 $AttachmentTest->{File}",
    );

    my $Delete = $Kernel::OM->Get('FAQ')->AttachmentDelete(
        ItemID => $FAQID2,
        FileID => $AttachmentIndex[0]->{FileID},
        UserID => 1,
    );
    $Self->True(
        $Delete,
        "AttachmentDelete() - $AttachmentTest->{File}",
    );
}

my $VoteIDsRef = $Kernel::OM->Get('FAQ')->VoteSearch(
    ItemID => $FAQID,
    UserID => 1,
);

for my $VoteID ( @{$VoteIDsRef} ) {
    my $VoteDelete = $Kernel::OM->Get('FAQ')->VoteDelete(
        VoteID => $VoteID,
        UserID => 1,
    );
    $Self->True(
        $VoteDelete,
        "VoteDelete()",
    );
}

# add FAQ article to log
my $Success = $Kernel::OM->Get('FAQ')->FAQLogAdd(
    ItemID    => $FAQID,
    Interface => 'internal',
    UserID    => 1,
);
$Self->True(
    $Success,
    "FAQLogAdd() - $FAQID",
);

# try to add same FAQ article to log again (must return false)
$Success = $Kernel::OM->Get('FAQ')->FAQLogAdd(
    ItemID    => $FAQID,
    Interface => 'internal',
    UserID    => 1,
);
$Self->False(
    $Success,
    "FAQLogAdd() - $FAQID",
);

# add another FAQ article to log
$Success = $Kernel::OM->Get('FAQ')->FAQLogAdd(
    ItemID    => $FAQID2,
    Interface => 'internal',
    UserID    => 1,
);
$Self->True(
    $Success,
    "FAQLogAdd() - $FAQID2",
);

my $FAQDelete = $Kernel::OM->Get('FAQ')->FAQDelete(
    ItemID => $FAQID,
    UserID => 1,
);
$Self->True(
    $FAQDelete,
    "FAQDelete() - FAQID: $FAQID",
);

my $FAQDelete2 = $Kernel::OM->Get('FAQ')->FAQDelete(
    ItemID => $FAQID2,
    UserID => 1,
);
$Self->True(
    $FAQDelete2,
    "FAQDelete() - FAQID: $FAQID2",
);

my $CategoryID = $Kernel::OM->Get('FAQ')->CategoryAdd(
    Name     => 'TestCategory',
    Comment  => 'Category for testing',
    ParentID => 0,
    ValidID  => 1,
    UserID   => 1,
);

$Self->True(
    $CategoryID,
    "CategoryAdd() - Root Category",
);

# set ParentID to empty to make it fail
my $CategoryIDFail = $Kernel::OM->Get('FAQ')->CategoryAdd(
    Name     => 'TestCategory',
    Comment  => 'Category for testing',
    ParentID => q{},
    ValidID  => 1,
    UserID   => 1,
    Silent   => 1,
);

$Self->False(
    $CategoryIDFail,
    "CategoryAdd() - Root Category",
);

my $CategoryUpdate = $Kernel::OM->Get('FAQ')->CategoryUpdate(
    CategoryID => $CategoryID,
    ParentID   => 0,
    Name       => 'RootCategory',
    Comment    => 'Root Category for testing',
    ValidID    => 1,
    UserID     => 1,
);

$Self->True(
    $CategoryUpdate,
    "CategoryUpdate() - Root Category",
);

# set ParentID to empty to make it fail
my $CategoryUpdateFail = $Kernel::OM->Get('FAQ')->CategoryUpdate(
    CategoryID => $CategoryID,
    ParentID   => q{},
    Name       => 'RootCategory',
    Comment    => 'Root Category for testing',
    ValidID    => 1,
    UserID     => 1,
    Silent     => 1
);

$Self->False(
    $CategoryUpdateFail,
    "CategoryUpdate() - Root Category",
);

my $ChildCategoryID = $Kernel::OM->Get('FAQ')->CategoryAdd(
    Name     => 'ChildCategory',
    Comment  => 'Child Category for testing',
    ParentID => $CategoryID,
    ValidID  => 1,
    UserID   => 1,
);

$Self->True(
    $ChildCategoryID,
    "CategoryAdd() - Child Category",
);

my $ChildCategoryDelete = $Kernel::OM->Get('FAQ')->CategoryDelete(
    CategoryID => $ChildCategoryID,
    UserID     => 1,
);

$Self->True(
    $ChildCategoryDelete,
    "CategoryDelete() - Child Category",
);

my $CategoryDelete = $Kernel::OM->Get('FAQ')->CategoryDelete(
    CategoryID => $CategoryID,
    UserID     => 1,
);

$Self->True(
    $CategoryDelete,
    "CategoryDelete() - Root Category",
);

#ItemFieldGet Tests
my %TestFields = (
    Field1 => 'Symptom...',
    Field2 => 'Problem...',
    Field3 => 'Solution...',
    Field4 => 'User Field4...',
    Field5 => 'User Field5...',
    Field6 => 'Comment...',
);

$FAQID = $Kernel::OM->Get('FAQ')->FAQAdd(
    Title      => 'Some Text',
    CategoryID => 1,
    Visibility => 'external',
    Language   => 'en',
    Keywords   => 'some keywords',
    %TestFields,
    ContentType => 'text/html',
    UserID      => 1,
);

$Self->True(
    $FAQID,
    "FAQAdd() for ItemFieldGet with True",
);

my %ResultFields;

my $CheckFields = sub {
    my %Param = @_;

    for my $FieldCount ( 1 .. 6 ) {
        my $Field = "Field$FieldCount";

        # check that cache is clean
        my $Cache = $CacheObject->Get(
            Type => 'FAQ',
            Key  => "ItemFieldGet::ItemID::$FAQID",
        );

        # on before first Get cache should be undef, after firs cache exist, but the Field key must be
        # undef
        if ( ref $Cache eq 'HASH' ) {
            $Self->Is(
                $Cache->{$Field},
                undef,
                "Cache before ItemFieldGet(): $Field",
            );
        }
        else {
            $Self->Is(
                $Cache,
                undef,
                "Cache before ItemFieldGet(): Complete cache",
            );
        }

        # get the field
        $ResultFields{$Field} = $Kernel::OM->Get('FAQ')->ItemFieldGet(
            ItemID => $FAQID,
            Field  => $Field,
            UserID => 1,
        );

        # check cache is set
        $Cache = $CacheObject->Get(
            Type => 'FAQ',
            Key  => "ItemFieldGet::ItemID::$FAQID",
        );

        $Self->Is(
            ref $Cache,
            'HASH',
            "Cache after ItemFieldGet(): ref",
        );
        $Self->Is(
            $Cache->{$Field},
            $Param{CompareFields}->{$Field},
            "Cache after ItemFieldGet(): $Field matched with original field data",
        );
    }
};

$CheckFields->( CompareFields => \%TestFields );

$Self->IsDeeply(
    \%ResultFields,
    \%TestFields,
    "ItemFieldGet(): for all fields match expected data",
);

%FAQ = $Kernel::OM->Get('FAQ')->FAQGet(
    ItemID => $FAQID,
    UserID => 1,
);

# update the FAQ item
my %UpdatedTestFields = (
    Field1 => 'Updated Symptom...',
    Field2 => 'Updated Problem...',
    Field3 => 'Updated Solution...',
    Field4 => 'Updated User Field4...',
    Field5 => 'Updated User Field5...',
    Field6 => 'Updated Comment...',
);

$FAQUpdate = $Kernel::OM->Get('FAQ')->FAQUpdate(
    %FAQ,
    ItemID      => $FAQID,
    Title       => 'Some Text',
    CategoryID  => 1,
    Visibility  => 'external',
    Language    => 'en',
    Keywords    => 'some keywords',
    %UpdatedTestFields,
    ContentType => 'text/html',
    UserID      => 1,
    ValidID     => 1
);

$Self->True(
    $FAQUpdate,
    "FAQUpdate() for ItemFieldGet with True",
);

$CheckFields->( CompareFields => \%UpdatedTestFields );

$FAQDelete = $Kernel::OM->Get('FAQ')->FAQDelete(
    ItemID => $FAQID,
    UserID => 1,
);

$Self->True(
    $FAQDelete,
    "FAQDelete() for ItemFieldGet: with True",
);

# check that cache is clean
my $Cache = $CacheObject->Get(
    Type => 'FAQ',
    Key  => "ItemFieldGet::ItemID::$FAQID",
);

$Self->Is(
    $Cache,
    undef,
    "Cache for ItemFieldGet() after FAQDelete: Complete cache",
);

# FAQ item cache tests
$FAQID = $Kernel::OM->Get('FAQ')->FAQAdd(
    Title      => 'Some Text',
    CategoryID => 1,
    Visibility => 'external',
    Language   => 'en',
    Keywords   => 'some keywords',
    %TestFields,
    ContentType => 'text/html',
    UserID      => 1,
);

# check that cache is clean
$Cache = $CacheObject->Get(
    Type => 'FAQ',
    Key  => 'FAQGet::ItemID::' . $FAQID . '::ItemFields::0',
);
$Self->Is(
    $Cache,
    undef,
    "Cache for FAQ No ItemFields Before FAQGet(): Complete cache",
);
$Cache = $CacheObject->Get(
    Type => 'FAQ',
    Key  => 'FAQGet::ItemID::' . $FAQID . '::ItemFields::1',
);
$Self->Is(
    $Cache,
    undef,
    "Cache for FAQ With ItemFields Before FAQGet(): Complete cache",
);

# get FAQ no Item Fields
my %FAQData = $Kernel::OM->Get('FAQ')->FAQGet(
    ItemID     => $FAQID,
    ItemFields => 0,
    UserID     => 1
);

$Self->Is(
    $FAQData{ItemID},
    $FAQID,
    "Sanity Check for FAQGet(): match ItemID"
);

# sanity check Item Fields
for my $FieldCount ( 1 .. 6 ) {
    my $Field = "Field$FieldCount";

    $Self->Is(
        $FAQData{$Field},
        undef,
        "Sanity Check for FAQGet(): no ItemFields $Field",
    );
}
$Cache = $CacheObject->Get(
    Type => 'FAQ',
    Key  => 'FAQGet::ItemID::' . $FAQID . '::ItemFields::0',
);
$Self->Is(
    ref $Cache,
    'HASH',
    "Cache for FAQ No ItemFields After FAQGet(): Complete cache ref",
);
$Cache = $CacheObject->Get(
    Type => 'FAQ',
    Key  => 'FAQGet::ItemID::' . $FAQID . '::ItemFields::1',
);
$Self->Is(
    $Cache,
    undef,
    "Cache for FAQ With ItemFields After FAQGet(): Complete cache",
);

# get FAQ with Item Fields
%FAQData = $Kernel::OM->Get('FAQ')->FAQGet(
    ItemID     => $FAQID,
    ItemFields => 1,
    UserID     => 1
);

$Self->Is(
    $FAQData{ItemID},
    $FAQID,
    "Sanity Check for FAQGet(): match ItemID"
);

# sanity check Item Fields
for my $FieldCount ( 1 .. 6 ) {
    my $Field = "Field$FieldCount";

    $Self->IsNot(
        $FAQData{$Field},
        undef,
        "Sanity Check for FAQGet(): with ItemFields $Field",
    );
}
$Cache = $CacheObject->Get(
    Type => 'FAQ',
    Key  => 'FAQGet::ItemID::' . $FAQID . '::ItemFields::0',
);
$Self->Is(
    ref $Cache,
    'HASH',
    "Cache for FAQ No ItemFields After FAQGet(): Complete cache ref",
);
$Cache = $CacheObject->Get(
    Type => 'FAQ',
    Key  => 'FAQGet::ItemID::' . $FAQID . '::ItemFields::1',
);
$Self->Is(
    ref $Cache,
    'HASH',
    "Cache for FAQ With ItemFields After FAQGet(): Complete cache ref",
);

# -------------------------

# ContentTypeSet() tests

my $FAQItemID1 = $Kernel::OM->Get('FAQ')->FAQAdd(
    Title       => 'Some Text',
    CategoryID  => 1,
    Visibility  => 'internal',
    Language    => 'en',
    Field1      => 'Symptom...',    # (optional)
    ValidID     => 1,
    ContentType => 'text/plain',    # or 'text/html'
    UserID      => 1,
);
$Self->IsNot(
    undef,
    $FAQItemID1,
    "FAQAdd()"
);

my @Tests = (
    {
        Name   => 'Text with <br />',
        ItemID => $FAQItemID1,
        Update => {
            Field1      => 'Symptom <br />',
            ContentType => 'text/plain',
        },
        ExpectedResultAuto => 'text/html',
    },
    {
        Name   => 'Text with </li>',
        ItemID => $FAQItemID1,
        Update => {
            Field1      => '<li>Symptom </li>',
            ContentType => 'text/plain',
        },
        ExpectedResultAuto => 'text/html',
    },
    {
        Name   => 'Text with </ol>',
        ItemID => $FAQItemID1,
        Update => {
            Field1      => '<ol>Symptom </ol>',
            ContentType => 'text/plain',
        },
        ExpectedResultAuto => 'text/html',
    },
    {
        Name   => 'Text with </ul>',
        ItemID => $FAQItemID1,
        Update => {
            Field1      => '<ul>Symptom </ul>',
            ContentType => 'text/plain',
        },
        ExpectedResultAuto => 'text/html',
    },
    {
        Name   => 'Text with </table>',
        ItemID => $FAQItemID1,
        Update => {
            Field1      => '<table>Symptom </table>',
            ContentType => 'text/plain',
        },
        ExpectedResultAuto => 'text/html',
    },
    {
        Name   => 'Text with </tr>',
        ItemID => $FAQItemID1,
        Update => {
            Field1      => '<tr>Symptom </tr>',
            ContentType => 'text/plain',
        },
        ExpectedResultAuto => 'text/html',
    },
    {
        Name   => 'Text with </td>',
        ItemID => $FAQItemID1,
        Update => {
            Field1      => '<td>Symptom </td>',
            ContentType => 'text/plain',
        },
        ExpectedResultAuto => 'text/html',
    },
    {
        Name   => 'Text with </td>',
        ItemID => $FAQItemID1,
        Update => {
            Field1      => '<td>Symptom </td>',
            ContentType => 'text/plain',
        },
        ExpectedResultAuto => 'text/html',
    },
    {
        Name   => 'Text with </div>',
        ItemID => $FAQItemID1,
        Update => {
            Field1      => '<div>Symptom </div>',
            ContentType => 'text/plain',
        },
        ExpectedResultAuto => 'text/html',
    },
    {
        Name   => 'Text with </o>',
        ItemID => $FAQItemID1,
        Update => {
            Field1      => '<o>Symptom </o>',
            ContentType => 'text/plain',
        },
        ExpectedResultAuto => 'text/html',
    },
    {
        Name   => 'Text with </span>',
        ItemID => $FAQItemID1,
        Update => {
            Field1      => '<span>Symptom </span>',
            ContentType => 'text/plain',
        },
        ExpectedResultAuto => 'text/html',
    },
    {
        Name   => 'Text with </p>',
        ItemID => $FAQItemID1,
        Update => {
            Field1      => '<p>Symptom </p>',
            ContentType => 'text/plain',
        },
        ExpectedResultAuto => 'text/html',
    },
    {
        Name   => 'Text with </pre>',
        ItemID => $FAQItemID1,
        Update => {
            Field1      => '<pre>Symptom </pre>',
            ContentType => 'text/plain',
        },
        ExpectedResultAuto => 'text/html',
    },
    {
        Name   => 'Text with </h1>',
        ItemID => $FAQItemID1,
        Update => {
            Field1      => '<h1>Symptom </h1>',
            ContentType => 'text/plain',
        },
        ExpectedResultAuto => 'text/html',
    },
    {
        Name   => 'Text with </h9>',
        ItemID => $FAQItemID1,
        Update => {
            Field1      => '<h9>Symptom </h9>',
            ContentType => 'text/plain',
        },
        ExpectedResultAuto => 'text/html',
    },
    {
        Name   => 'Text with out HTML tags',
        ItemID => $FAQItemID1,
        Update => {
            Field1      => 'Symptom ',
            ContentType => 'text/plain',
        },
        ExpectedResultAuto => 'text/plain',
    },
    {
        Name   => 'Text with </u>',
        ItemID => $FAQItemID1,
        Update => {
            Field1      => '<u>Symptom </u>',
            ContentType => 'text/plain',
        },
        ExpectedResultAuto => 'text/plain',
    },
    {
        Name   => 'Text with </dib>',
        ItemID => $FAQItemID1,
        Update => {
            Field1      => '<dib>Symptom </dib>',
            ContentType => 'text/plain',
        },
        ExpectedResultAuto => 'text/plain',
    },
    {
        Name   => 'Text with </spam>',
        ItemID => $FAQItemID1,
        Update => {
            Field1      => '<spam>Symptom </spam>',
            ContentType => 'text/plain',
        },
        ExpectedResultAuto => 'text/plain',
    },
);

for my $Test (@Tests) {
    for my $ContentTypeRaw (qw(auto text/plain text/html)) {

        my $ContentType = $ContentTypeRaw eq 'auto' ? q{} : $ContentTypeRaw;

        my %FAQData = $Kernel::OM->Get('FAQ')->FAQGet(
            ItemID => $Test->{ItemID},
            UserID => 1,
        );

        my $FAQUpdate = $Kernel::OM->Get('FAQ')->FAQUpdate(
            %FAQData,
            %{ $Test->{Update} },
            ItemID => $Test->{ItemID},
            UserID => 1,
        );

        my $Success = $Kernel::OM->Get('FAQ')->FAQContentTypeSet(
            FAQItemIDs  => [ $Test->{ItemID} ],
            ContentType => $ContentType,
        );

        my $ExpectedResult = $ContentTypeRaw eq 'auto' ? $Test->{ExpectedResultAuto} : $ContentType;

        %FAQData = $Kernel::OM->Get('FAQ')->FAQGet(
            ItemID => $Test->{ItemID},
            UserID => 1,
        );

        $Self->Is(
            $FAQData{ContentType},
            $ExpectedResult,
            "$Test->{Name} - ContentType after set to $ContentTypeRaw",
        );
    }
}

%FAQData = $Kernel::OM->Get('FAQ')->FAQGet(
    ItemID => $FAQItemID1,
    UserID => 1,
);
$FAQUpdate = $Kernel::OM->Get('FAQ')->FAQUpdate(
    %FAQData,
    ItemID  => $FAQItemID1,
    ValidID => 2,
    UserID  => 1,
);
$Self->True(
    $FAQUpdate,
    "FAQUpdate() set FAQ $FAQItemID1 to invalid",
);

$FAQDelete = $Kernel::OM->Get('FAQ')->FAQDelete(
    ItemID => $FAQItemID1,
    UserID => 1,
);

$Self->True(
    $FAQDelete,
    "FAQDelete(): with True ($FAQItemID1)",
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
