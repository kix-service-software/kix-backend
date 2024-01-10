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
use Kernel::System::VariableCheck qw(:all);

# get needed objects for rollback
my $UserObject         = $Kernel::OM->Get('User'); # without, config changes are ignored!!

# get actual needed objects
my $ConfigObject       = $Kernel::OM->Get('Config');
my $FAQObject          = $Kernel::OM->Get('FAQ');
my $DynamicFieldObject = $Kernel::OM->Get('DynamicField');
my $DFBackendObject    = $Kernel::OM->Get('DynamicField::Backend');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# prepare test data
my %TestData = _PrepareData();

_CheckCustomerVisibleConfig();

_CheckCategoryConfig();

_CheckLanguageConfig();

_CheckDynamicFieldConfig();

_CheckTitleConfig();

_DoNegativeTests();

# rollback transaction on database
$Helper->Rollback();

sub _PrepareData {

    # create categories
    my $FAQCategoryID_A = $FAQObject->CategoryAdd(
        Name     => 'Category A',
        Comment  => q{},
        ParentID => 0,
        ValidID  => 1,
        UserID   => 1,
    );
    $Self->True(
        $FAQCategoryID_A,
        'Create category',
    );
    my $FAQCategoryID_B = $FAQObject->CategoryAdd(
        Name     => 'Category B',
        Comment  => q{},
        ParentID => 0,
        ValidID  => 1,
        UserID   => 1,
    );
    $Self->True(
        $FAQCategoryID_B,
        'Create category',
    );

    # create faq articles
    my $FAQArticleID_1 = $FAQObject->FAQAdd(
        Title       => 'external english FAQ of category A',
        CategoryID  => $FAQCategoryID_A,
        Visibility  => 'external',
        Language    => 'en',
        ValidID     => 1,
        ContentType => 'text/plain',
        UserID      => 1,
    );
    $Self->True(
        $FAQArticleID_1,
        'Create FAQ',
    );
    my $FAQArticleID_2 = $FAQObject->FAQAdd(
        Title       => 'internal german FAQ of category B',
        CategoryID  => $FAQCategoryID_B,
        Visibility  => 'internal',
        Language    => 'de',
        ValidID     => 1,
        ContentType => 'text/plain',
        UserID      => 1,
    );
    $Self->True(
        $FAQArticleID_2,
        'Create FAQ',
    );

    my $DFName  = 'CustomerAssignedFAQsSelection';
    my $DFValue = 'Key';
    my $SelectionDynamicFieldID = $DynamicFieldObject->DynamicFieldAdd(
        Name            => $DFName,
        Label           => $DFName,
        InternalField   => 1,
        FieldType       => 'Multiselect',
        ObjectType      => 'FAQArticle',
        Config          => {
            PossibleValues => {
                $DFValue =>  'Value',
                'Key2'   =>  'Value2'
            }
        },
        CustomerVisible => 1,
        ValidID         => 1,
        UserID          => 1,
    );
    $Self->True(
        $SelectionDynamicFieldID,
        'Create SelectionDynamicField',
    );
    my $SelectionDynamicField = $DynamicFieldObject->DynamicFieldGet(
        ID => $SelectionDynamicFieldID,
    );
    $Self->True(
        IsHashRefWithData($SelectionDynamicField) || 0,
        'Get SelectionDynamicField',
    );
    if (IsHashRefWithData($SelectionDynamicField)) {
        my $Success = $DFBackendObject->ValueSet(
            DynamicFieldConfig => $SelectionDynamicField,
            ObjectID           => $FAQArticleID_2,
            Value              => [$DFValue],
            UserID             => 1,
        );
    }

    return (
        CategoryAID     => $FAQCategoryID_A,
        CategoryBID     => $FAQCategoryID_B,
        VisibleFAQID    => $FAQArticleID_1,
        NotVisibleFAQID => $FAQArticleID_2,
        FAQOfAID        => $FAQArticleID_1,
        FAQOfBID        => $FAQArticleID_2,
        EnglishFAQID    => $FAQArticleID_1,
        GermanFAQID     => $FAQArticleID_2,
        DFName          => $DFName,
        DFValue         => $DFValue,
        DFFAQID         => $FAQArticleID_2,
        Title           => '*english FAQ*',
        TitleFAQID      => $FAQArticleID_1
    );
}

sub _CheckCustomerVisibleConfig {

    _SetConfig(
        'with static for CustomerVisible = 1',
        <<"END",
{
    "Contact": {
        "FAQArticle": {
            "CustomerVisible": {
                "SearchStatic": [
                    1
                ]
            }
        }
    }
}
END
        1
    );

    # get visible faq articles
    my $VisibleArticleIDList = $FAQObject->GetAssignedFAQArticlesForObject(
        ObjectType   => 'Contact',
        UserID       => 1,

        # consider only test articles
        ObjectIDList => [ $TestData{VisibleFAQID}, $TestData{NotVisibleFAQID} ]
    );
    $Self->Is(
        scalar(@{$VisibleArticleIDList}),
        1,
        'Article list should contain 1 article (visible = 1)',
    );
    $Self->ContainedIn(
        $TestData{VisibleFAQID},
        $VisibleArticleIDList,
        'List should contain visible articles (visible = 1)',
    );
    $Self->NotContainedIn(
        $TestData{NotVisibleFAQID},
        $VisibleArticleIDList,
        'List should NOT contain not visible articles (visible = 1)',
    );

    # get visible faq articles (without article ids given - can be more articles)
    my $VisibleArticleIDListWithout = $FAQObject->GetAssignedFAQArticlesForObject(
        ObjectType   => 'Contact',
        UserID       => 1
    );
    $Self->True(
        (scalar(@{$VisibleArticleIDListWithout}) >= 1) ? 1 : 0,
        'Article list should contain at least 1 article (visible = 1, without ids)',
    );
    $Self->ContainedIn(
        $TestData{VisibleFAQID},
        $VisibleArticleIDListWithout,
        'List should contain visible articles (visible = 1, without ids)',
    );
    $Self->NotContainedIn(
        $TestData{NotVisibleFAQID},
        $VisibleArticleIDListWithout,
        'List should NOT contain not visible articles (visible = 1, without ids)',
    );

    _SetConfig(
        'with static for CustomerVisible = 0',
        <<"END"
{
    "Contact": {
        "FAQArticle": {
            "CustomerVisible": {
                "SearchStatic": [
                    0
                ]
            }
        }
    }
}
END
    );

    # get not visible faq articles
    my $NotVisibleArticleIDList = $FAQObject->GetAssignedFAQArticlesForObject(
        ObjectType   => 'Contact',
        UserID       => 1,

        # consider only test articles
        ObjectIDList => [ $TestData{VisibleFAQID}, $TestData{NotVisibleFAQID} ]
    );
    $Self->Is(
        scalar(@{$NotVisibleArticleIDList}),
        1,
        'Article list should contain 1 article (visible = 0)',
    );
    $Self->ContainedIn(
        $TestData{NotVisibleFAQID},
        $NotVisibleArticleIDList,
        'List should contain not visible articles (visible = 0)',
    );
    $Self->NotContainedIn(
        $TestData{VisibleFAQID},
        $NotVisibleArticleIDList,
        'List should NOT contain visible articles (visible = 0)',
    );

    _SetConfig(
        'with static for CustomerVisible = 1 OR 0',
        <<"END"
{
    "Contact": {
        "FAQArticle": {
            "CustomerVisible": {
                "SearchStatic": [
                    0, 1
                ]
            }
        }
    }
}
END
    );

    # get not visible faq articles
    my $AllArticleIDList = $FAQObject->GetAssignedFAQArticlesForObject(
        ObjectType   => 'Contact',
        UserID       => 1,

        # consider only test articles
        ObjectIDList => [ $TestData{VisibleFAQID}, $TestData{NotVisibleFAQID} ]
    );
    $Self->Is(
        scalar(@{$AllArticleIDList}),
        2,
        'Article list should contain 2 article (visible = 0 OR 1)',
    );
    $Self->ContainedIn(
        $TestData{VisibleFAQID},
        $AllArticleIDList,
        'List should contain visible articles (visible = 0 OR 1)',
    );
    $Self->ContainedIn(
        $TestData{NotVisibleFAQID},
        $AllArticleIDList,
        'List should contain not visible articles (visible = 0 OR 1)',
    );

    return 1;
}

sub _CheckCategoryConfig {

    _SetConfig(
        'with static for CustomerVisible = 1',
        <<"END"
{
    "Contact": {
        "FAQArticle": {
            "CategoryID": {
                "SearchStatic": [
                    $TestData{CategoryAID}
                ]
            }
        }
    }
}
END
    );

    # get relevant category faq articles
    my $CategoryAArticleIDList = $FAQObject->GetAssignedFAQArticlesForObject(
        ObjectType   => 'Contact',
        UserID       => 1,

        # consider only test articles
        ObjectIDList => [ $TestData{FAQOfAID}, $TestData{FAQOfBID} ]
    );
    $Self->Is(
        scalar(@{$CategoryAArticleIDList}),
        1,
        'Article list should contain 1 article (category A)',
    );
    $Self->ContainedIn(
        $TestData{FAQOfAID},
        $CategoryAArticleIDList,
        'List should contain articles of category A (category A)',
    );
    $Self->NotContainedIn(
        $TestData{FAQOfBID},
        $CategoryAArticleIDList,
        'List should NOT contain articles of category B (category A)',
    );

    _SetConfig(
        'with static for CustomerVisible = 0',
        <<"END"
{
    "Contact": {
        "FAQArticle": {
            "CategoryID": {
                "SearchStatic": [
                    $TestData{CategoryAID},$TestData{CategoryBID}
                ]
            }
        }
    }
}
END
    );

    # get relevant categories faq articles
    my $CategoryAAndBArticleList = $FAQObject->GetAssignedFAQArticlesForObject(
        ObjectType   => 'Contact',
        UserID       => 1,

        # consider only test articles
        ObjectIDList => [ $TestData{VisibleFAQID}, $TestData{NotVisibleFAQID} ]
    );
    $Self->Is(
        scalar(@{$CategoryAAndBArticleList}),
        2,
        'Article list should contain 2 article (category A OR B)',
    );
    $Self->ContainedIn(
        $TestData{NotVisibleFAQID},
        $CategoryAAndBArticleList,
        'List should contain articles of category A (category A OR B)',
    );
    $Self->ContainedIn(
        $TestData{VisibleFAQID},
        $CategoryAAndBArticleList,
        'List should contain articles of category B (category A OR B)',
    );

    return 1;
}

sub _CheckLanguageConfig {

    _SetConfig(
        'with static for CustomerVisible = 1',
        <<"END"
{
    "Contact": {
        "FAQArticle": {
            "Language": {
                "SearchStatic": [
                    "en"
                ]
            }
        }
    }
}
END
    );

    # get english faq articles
    my $EnglishArticleIDList = $FAQObject->GetAssignedFAQArticlesForObject(
        ObjectType   => 'Contact',
        UserID       => 1,

        # consider only test articles
        ObjectIDList => [ $TestData{EnglishFAQID}, $TestData{GermanFAQID} ]
    );
    $Self->Is(
        scalar(@{$EnglishArticleIDList}),
        1,
        'Article list should contain 1 article (english)',
    );
    $Self->ContainedIn(
        $TestData{EnglishFAQID},
        $EnglishArticleIDList,
        'List should contain english articles (english)',
    );
    $Self->NotContainedIn(
        $TestData{GermanFAQID},
        $EnglishArticleIDList,
        'List should NOT contain german articles (english)',
    );

    _SetConfig(
        'with static for CustomerVisible = 1',
        <<"END"
{
    "Contact": {
        "FAQArticle": {
            "Language": {
                "SearchStatic": [
                    "en", "de"
                ]
            }
        }
    }
}
END
    );

    # get english and german faq articles
    $EnglishArticleIDList = $FAQObject->GetAssignedFAQArticlesForObject(
        ObjectType   => 'Contact',
        UserID       => 1,

        # consider only test articles
        ObjectIDList => [ $TestData{EnglishFAQID}, $TestData{GermanFAQID} ]
    );
    $Self->Is(
        scalar(@{$EnglishArticleIDList}),
        2,
        'Article list should contain 2 article (english and german)',
    );
    $Self->ContainedIn(
        $TestData{EnglishFAQID},
        $EnglishArticleIDList,
        'List should contain english articles (english and german)',
    );
    $Self->ContainedIn(
        $TestData{GermanFAQID},
        $EnglishArticleIDList,
        'List should contain german articles (english and german)',
    );

    # get english and german faq articles (without article ids given - can be more articles)
    $EnglishArticleIDList = $FAQObject->GetAssignedFAQArticlesForObject(
        ObjectType   => 'Contact',
        UserID       => 1
    );
    $Self->True(
        (scalar(@{$EnglishArticleIDList}) >= 2) ? 1 : 0,
        'Article list should contain at least 2 article (english and german, without ids)',
    );
    $Self->ContainedIn(
        $TestData{EnglishFAQID},
        $EnglishArticleIDList,
        'List should contain english articles (english and german, without ids)',
    );
    $Self->ContainedIn(
        $TestData{GermanFAQID},
        $EnglishArticleIDList,
        'List should contain german articles (english and german, without ids)',
    );

    return 1;
}

sub _CheckDynamicFieldConfig {

    _SetConfig(
        'with static for CustomerVisible = 1',
        <<"END"
{
    "Contact": {
        "FAQArticle": {
            "DynamicField_$TestData{DFName}": {
                "SearchStatic": [
                    "$TestData{DFValue}"
                ]
            }
        }
    }
}
END
    );

    # get faq articles
    my $DFRelevantArticleIDList = $FAQObject->GetAssignedFAQArticlesForObject(
        ObjectType   => 'Contact',
        UserID       => 1
    );
    $Self->Is(
        scalar(@{$DFRelevantArticleIDList}),
        1,
        'Article list should contain 1 article (df relevant)',
    );
    $Self->ContainedIn(
        $TestData{DFFAQID},
        $DFRelevantArticleIDList,
        'List should contain df relevant articles',
    );

    return 1;
}

sub _CheckTitleConfig {

    _SetConfig(
        'with static for CustomerVisible = 1',
        <<"END"
{
    "Contact": {
        "FAQArticle": {
            "Title": {
                "SearchStatic": [
                    "$TestData{Title}"
                ]
            }
        }
    }
}
END
    );

    # get faq articles
    my $TitleArticleIDList = $FAQObject->GetAssignedFAQArticlesForObject(
        ObjectType   => 'Contact',
        UserID       => 1
    );
    $Self->Is(
        scalar(@{$TitleArticleIDList}),
        1,
        'Article list should contain 1 article (title)',
    );
    $Self->ContainedIn(
        $TestData{TitleFAQID},
        $TitleArticleIDList,
        'List should contain articles (title)',
    );

    return 1;
}

sub _DoNegativeTests {

    # negative (unknown attribute) ---------------------------
    _SetConfig(
        'unknown attribute',
        <<"END"
{
    "Contact": {
        "FAQArticle": {
            "OwnerID": {
                "SearchStatic": [
                    1
                ]
            }
        }
    }
}
END
    );
    my $ArticleIDList = $FAQObject->GetAssignedFAQArticlesForObject(
        ObjectType   => 'Contact',
        UserID       => 1
    );
    $Self->Is(
        scalar(@{$ArticleIDList}),
        0,
        'FAQ article list should be empty (unknown attribute)',
    );

    # negative (missing faq article config) ---------------------------
    _SetConfig(
        'negative (missing faq article config)',
        <<"END"
{
    "Contact": {
        "Ticket": {
            "ContactID": {
                "SearchStatic": [
                    1
                ]
            }
        }
    }
}
END
    );
    $ArticleIDList = $FAQObject->GetAssignedFAQArticlesForObject(
        ObjectType   => 'Contact',
        UserID       => 1
    );
    $Self->Is(
        scalar(@{$ArticleIDList}),
        0,
        'Article list should be empty (missing faq article config)',
    );

    # negative (empty faq config) ---------------------------
    _SetConfig(
        'negative (empty faq config)',
        <<"END"
{
    "Contact": {
        "FAQArticle": {}
    }
}
END
    );
    $ArticleIDList = $FAQObject->GetAssignedFAQArticlesForObject(
        ObjectType   => 'Contact',
        UserID       => 1
    );
    $Self->Is(
        scalar(@{$ArticleIDList}),
        0,
        'Article list should be empty (empty faq article config)',
    );

    # negative (empty attribute) ---------------------------
    _SetConfig(
        'negative (empty value)',
        <<"END"
{
    "Contact": {
        "FAQArticle": {
            "CustomerVisible": {}
        }
    }
}
END
    );
    $ArticleIDList = $FAQObject->GetAssignedFAQArticlesForObject(
        ObjectType   => 'Contact',
        UserID       => 1
    );
    $Self->Is(
        scalar(@{$ArticleIDList}),
        0,
        'Article list should be empty (empty attribute)',
    );

    # negative (empty value) ---------------------------
    _SetConfig(
        'negative (empty value)',
        <<"END"
{
    "Contact": {
        "FAQArticle": {
            "CustomerVisible": {
                "SearchStatic": []
            }
        }
    }
}
END
    );
    $ArticleIDList = $FAQObject->GetAssignedFAQArticlesForObject(
        ObjectType   => 'Contact',
        UserID       => 1
    );
    $Self->Is(
        scalar(@{$ArticleIDList}),
        0,
        'Article list should be empty (empty value)',
    );

    # negative (empty config) ---------------------------
    _SetConfig(
        'negative (empty config)',
        q{}
    );
    $ArticleIDList = $FAQObject->GetAssignedFAQArticlesForObject(
        ObjectType   => 'Contact',
        UserID       => 1
    );
    $Self->Is(
        scalar(@{$ArticleIDList}),
        0,
        'Article list should be empty (empty config)',
    );

    # negative (invalid config, missing " and unnecessary ,) ---------------------------
    _SetConfig(
        'negative (invalid config)',
        <<"END"
{
    "Contact": {
        "FAQArticle": {
            "CustomerVisible": {
                SearchStatic: [
                    1
                ]
            }
        },
    }
}
END
    );
    $ArticleIDList = $FAQObject->GetAssignedFAQArticlesForObject(
        ObjectType   => 'Contact',
        UserID       => 1,
        Silent       => 1
    );
    $Self->Is(
        scalar(@{$ArticleIDList}),
        0,
        'Article list should be empty (invalid config)',
    );

    return 1;
}

sub _SetConfig {
    my ($Name, $Config, $DoCheck) = @_;

    $ConfigObject->Set(
        Key   => 'AssignedObjectsMapping',
        Value => $Config,
    );

    # check config
    if ($DoCheck) {
        my $MappingString = $ConfigObject->Get('AssignedObjectsMapping');
        $Self->True(
            IsStringWithData($MappingString) || 0,
            "AssignedObjectsMapping - get config string ($Name)",
        );

        my $NewConfig = 0;
        if ($MappingString && $MappingString eq $Config) {
            $NewConfig = 1;
        }
        $Self->True(
            $NewConfig,
            "AssignedObjectsMapping - mapping is new value",
        );
    }

    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
