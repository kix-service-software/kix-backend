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

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my %Data = (
    # possible value of both source DFs
    DFSelection_PossibleValues => {
        Key1 => "Value1",
        Key2 => "Value2",
        Key3 => "Value3"
    },

    # name and values of source DF on ticket
    DFSelectionSourceName    => 'DFSetSourceSelection',
    DFSelection_SourceValue  => ['Key1', 'Key2'],

    # name and value of source DF on contact
    DFSelectionContactSourceName => 'DFSetContactSelection',
    DFSelection_ContactValue     => ['Key1', 'Key3'],

    # target DFs on ticket
    DFSelectionTargetName => 'DFSetTargetSelection',
    DFTextTargetName      => 'DFSetTargetText',

    # target DF on article
    DFTextTargetNameArticle => 'DFSetTargetTextArticle'
);

my ($TicketID, $ArticleID) = _AddObjects();

if ($TicketID) {
    my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
        TicketID      => $TicketID,
        DynamicFields => 1,
        UserID        => 1,
        Silent        => 1
    );

    if (IsHashRefWithData(\%Ticket)) {
        # check dfs (should be empty)
        my $SelectionValue = $Ticket{'DynamicField_'.$Data{DFSelectionTargetName}};
        $Self->False(
            $SelectionValue,
            'Check target selection DF',
        );
        my $TextValue = $Ticket{'DynamicField_'.$Data{DFTextTargetName}};
        $Self->False(
            $TextValue,
            'Check target text DF',
        );

        my $MacroID = $Kernel::OM->Get('Automation')->MacroAdd(
            Name    => 'DFSet Tests',
            Type    => 'Ticket',
            ValidID => 1,
            UserID  => 1,
        );
        $Self->True(
            $MacroID,
            'MacroAdd',
        );

        if ($MacroID) {
            my $MacroActionID = $Kernel::OM->Get('Automation')->MacroActionAdd(
                MacroID    => $MacroID,
                Type       => 'DynamicFieldSet',
                Parameters => {
                    ObjectID           => $TicketID, # use ObjectID parameter for first execution
                    DynamicFieldName   => $Data{DFSelectionTargetName},
                    DynamicFieldValue  => 'Key1', # use first possible value for first execution
                    DynamicFieldAppend => 0
                },
                ValidID    => 1,
                UserID     => 1,
            );
            $Self->True(
                $MacroActionID,
                'MacroActionAdd',
            );
            if ($MacroActionID) {
                my %MacroAction = $Kernel::OM->Get('Automation')->MacroActionGet(
                    ID => $MacroActionID
                );

                if (IsHashRefWithData(\%MacroAction)) {

                    # update macro - set ExecOrder
                    my $Success = $Kernel::OM->Get('Automation')->MacroUpdate(
                        ID        => $MacroID,
                        ExecOrder => [ $MacroActionID ],
                        UserID    => 1,
                    );
                    $Self->True(
                        $Success,
                        'MacroUpdate - ExecOrder',
                    );

                    ###### 1st execute - with ObjectID parameter
                    $Success = $Kernel::OM->Get('Automation')->MacroExecute(
                        ID       => $MacroID,
                        ObjectID => $TicketID,
                        UserID   => 1,
                    );
                    $Self->True(
                        $Success,
                        '1st MacroExecute',
                    );
                    %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
                        TicketID      => $TicketID,
                        DynamicFields => 1,
                        UserID        => 1,
                        Silent        => 1
                    );
                    if (IsHashRefWithData(\%Ticket)) {
                        my $SelectionValue = $Ticket{'DynamicField_'.$Data{DFSelectionTargetName}};
                        $Self->True(
                            IsArrayRefWithData($SelectionValue) ? 1 : 0,
                            'Check target selection DF (1st execute)',
                        );
                        if (IsArrayRefWithData($SelectionValue)) {
                            $Self->Is(
                                scalar(@{$SelectionValue}),
                                1,
                                'Check target selection DF (1st execute)',
                            );
                            $Self->Is(
                                $SelectionValue->[0],
                                'Key1',
                                'Check target selection DF (1st execute)',
                            );
                        }
                    }

                    ###### 2nd execute (without ObjectID parameter - should use default "${ObjectID}")
                    $Kernel::OM->Get('Automation')->MacroActionUpdate(
                        %MacroAction,
                        UserID => 1,
                        Parameters => {
                            DynamicFieldName   => $Data{DFSelectionTargetName},
                            DynamicFieldValue  => 'Key2', # use second possible value (result should not be first value anymore, even if the target object (ID) is not explicit given)
                            DynamicFieldAppend => 0
                        }
                    );
                    $Success = $Kernel::OM->Get('Automation')->MacroExecute(
                        ID       => $MacroID,
                        ObjectID => $TicketID,
                        UserID   => 1,
                    );
                    $Self->True(
                        $Success,
                        '2nd MacroExecute',
                    );
                    %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
                        TicketID      => $TicketID,
                        DynamicFields => 1,
                        UserID        => 1,
                        Silent        => 1
                    );
                    if (IsHashRefWithData(\%Ticket)) {
                        my $SelectionValue = $Ticket{'DynamicField_'.$Data{DFSelectionTargetName}};
                        $Self->True(
                            IsArrayRefWithData($SelectionValue) ? 1 : 0,
                            'Check target selection DF (2nd execute)',
                        );
                        if (IsArrayRefWithData($SelectionValue)) {
                            $Self->Is(
                                scalar(@{$SelectionValue}),
                                1,
                                'Check target selection DF (2nd execute)',
                            );
                            $Self->Is(
                                $SelectionValue->[0],
                                'Key2',
                                'Check target selection DF (2nd execute)',
                            );
                        }
                    }

                    ###### 3rd execute
                    $Kernel::OM->Get('Automation')->MacroActionUpdate(
                        %MacroAction,
                        UserID => 1,
                        Parameters => {
                            DynamicFieldName   => $Data{DFSelectionTargetName},
                            DynamicFieldValue  => 'Key3', # use third value, but ...
                            DynamicFieldAppend => 1       # ... append now (result = Key2 and Key3)
                        }
                    );
                    $Success = $Kernel::OM->Get('Automation')->MacroExecute(
                        ID       => $MacroID,
                        ObjectID => $TicketID,
                        UserID   => 1,
                    );
                    $Self->True(
                        $Success,
                        '3rd MacroExecute',
                    );
                    %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
                        TicketID      => $TicketID,
                        DynamicFields => 1,
                        UserID        => 1,
                        Silent        => 1
                    );
                    if (IsHashRefWithData(\%Ticket)) {
                        my $SelectionValue = $Ticket{'DynamicField_'.$Data{DFSelectionTargetName}};
                        $Self->True(
                            IsArrayRefWithData($SelectionValue) ? 1 : 0,
                            'Check target selection DF (3rd execute)',
                        );
                        if (IsArrayRefWithData($SelectionValue)) {
                            $Self->Is(
                                scalar(@{$SelectionValue}),
                                2,
                                'Check target selection DF (3rd execute)',
                            );
                            $Self->Is(
                                $SelectionValue->[0],
                                'Key2',
                                'Check target selection DF (3rd execute)',
                            );
                            $Self->Is(
                                $SelectionValue->[1],
                                'Key3',
                                'Check target selection DF (3rd execute)',
                            );
                        }
                    }

                    ## value by placeholders
                    ###### by other dynamic field (with key placeholder)
                    $Kernel::OM->Get('Automation')->MacroActionUpdate(
                        %MacroAction,
                        UserID => 1,
                        Parameters => {
                            DynamicFieldName   => $Data{DFSelectionTargetName},
                            DynamicFieldValue  => "<KIX_TICKET_DynamicField_$Data{DFSelectionSourceName}_Key>", # use Key value of sourc DF of ticket => should fail, because string "Key1#Key2" is no valid possible value
                            DynamicFieldAppend => 0
                        }
                    );
                    $Success = $Kernel::OM->Get('Automation')->MacroExecute(
                        ID       => $MacroID,
                        ObjectID => $TicketID,
                        UserID   => 1,
                    );
                    $Self->True(
                        $Success,
                        'key placeholder (MacroExecute)',
                    );
                    %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
                        TicketID      => $TicketID,
                        DynamicFields => 1,
                        UserID        => 1,
                        Silent        => 1
                    );
                    if (IsHashRefWithData(\%Ticket)) {
                        my $SelectionValue = $Ticket{'DynamicField_'.$Data{DFSelectionTargetName}};
                        $Self->True(
                            IsArrayRefWithData($SelectionValue) ? 1 : 0,
                            'Check target selection DF (key placeholder)',
                        );
                        # should still be old value
                        if (IsArrayRefWithData($SelectionValue)) {
                            $Self->Is(
                                scalar(@{$SelectionValue}),
                                2,
                                'Check target selection DF (key placeholder)',
                            );
                            $Self->Is(
                                $SelectionValue->[0],
                                'Key2',
                                'Check target selection DF (key placeholder)',
                            );
                            $Self->Is(
                                $SelectionValue->[1],
                                'Key3',
                                'Check target selection DF (key placeholder)',
                            );
                        }
                    }
                    ###### by other dynamic field (with object value placeholder)
                    $Kernel::OM->Get('Automation')->MacroActionUpdate(
                        %MacroAction,
                        UserID => 1,
                        Parameters => {
                            DynamicFieldName   => $Data{DFSelectionTargetName},
                            DynamicFieldValue  => "<KIX_TICKET_DynamicField_$Data{DFSelectionSourceName}_ObjectValue>", # should "copy" the value from source DF
                            DynamicFieldAppend => 0
                        }
                    );
                    $Success = $Kernel::OM->Get('Automation')->MacroExecute(
                        ID       => $MacroID,
                        ObjectID => $TicketID,
                        UserID   => 1,
                    );
                    $Self->True(
                        $Success,
                        'object value placeholder (MacroExecute)',
                    );
                    %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
                        TicketID      => $TicketID,
                        DynamicFields => 1,
                        UserID        => 1,
                        Silent        => 1
                    );
                    if (IsHashRefWithData(\%Ticket)) {
                        my $SelectionValue = $Ticket{'DynamicField_'.$Data{DFSelectionTargetName}};
                        $Self->True(
                            IsArrayRefWithData($SelectionValue) ? 1 : 0,
                            'Check target selection DF (object value placeholder)',
                        );
                        if (IsArrayRefWithData($SelectionValue)) {
                            $Self->Is(
                                scalar(@{$SelectionValue}),
                                2,
                                'Check target selection DF (object value placeholder)',
                            );
                            $Self->IsDeeply(
                                $SelectionValue,
                                $Data{DFSelection_SourceValue},
                                'Check target selection DF (object value placeholder)',
                            );
                        }
                    }
                    ###### by other dynamic field (with first object value placeholder)
                    $Kernel::OM->Get('Automation')->MacroActionUpdate(
                        %MacroAction,
                        UserID => 1,
                        Parameters => {
                            DynamicFieldName   => $Data{DFSelectionTargetName},
                            DynamicFieldValue  => "<KIX_TICKET_DynamicField_$Data{DFSelectionSourceName}_ObjectValue_0>", # should use first value from source DF
                            DynamicFieldAppend => 0
                        }
                    );
                    $Success = $Kernel::OM->Get('Automation')->MacroExecute(
                        ID       => $MacroID,
                        ObjectID => $TicketID,
                        UserID   => 1,
                    );
                    $Self->True(
                        $Success,
                        'object value placeholder (MacroExecute)',
                    );
                    %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
                        TicketID      => $TicketID,
                        DynamicFields => 1,
                        UserID        => 1,
                        Silent        => 1
                    );
                    if (IsHashRefWithData(\%Ticket)) {
                        my $SelectionValue = $Ticket{'DynamicField_'.$Data{DFSelectionTargetName}};
                        $Self->True(
                            IsArrayRefWithData($SelectionValue) ? 1 : 0,
                            'Check target selection DF (fist object value placeholder)',
                        );
                        if (IsArrayRefWithData($SelectionValue)) {
                            $Self->Is(
                                scalar(@{$SelectionValue}),
                                1,
                                'Check target selection DF (fist object value placeholder)',
                            );
                            $Self->IsDeeply(
                                $SelectionValue,
                                [ $Data{DFSelection_SourceValue}->[0] ],
                                'Check target selection DF (fist object value placeholder)',
                            );
                        }
                    }
                    ###### by contact dynamic field (with key placeholder)
                    $Kernel::OM->Get('Automation')->MacroActionUpdate(
                        %MacroAction,
                        UserID => 1,
                        Parameters => {
                            DynamicFieldName   => $Data{DFSelectionTargetName},
                            DynamicFieldValue  => "<KIX_CONTACT_DynamicField_$Data{DFSelectionContactSourceName}_Key>", # should fail, because key string is no possible value
                            DynamicFieldAppend => 0
                        }
                    );
                    $Success = $Kernel::OM->Get('Automation')->MacroExecute(
                        ID       => $MacroID,
                        ObjectID => $TicketID,
                        UserID   => 1,
                    );
                    $Self->True(
                        $Success,
                        'contact DF placeholder (MacroExecute)',
                    );
                    %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
                        TicketID      => $TicketID,
                        DynamicFields => 1,
                        UserID        => 1,
                        Silent        => 1
                    );
                    if (IsHashRefWithData(\%Ticket)) {
                        my $SelectionValue = $Ticket{'DynamicField_'.$Data{DFSelectionTargetName}};
                        $Self->True(
                            IsArrayRefWithData($SelectionValue) ? 1 : 0,
                            'Check target selection DF (contact DF placeholder (Key))',
                        );
                        # should still be old value
                        if (IsArrayRefWithData($SelectionValue)) {
                            $Self->Is(
                                scalar(@{$SelectionValue}),
                                1,
                                'Check target selection DF (contact DF placeholder (Key))',
                            );
                            $Self->Is(
                                $SelectionValue->[0],
                                $Data{DFSelection_SourceValue}->[0],
                                'Check target selection DF (contact DF placeholder (Key))',
                            );
                        }
                    }
                    ###### by contact dynamic field (with first object value placeholder)
                    $Kernel::OM->Get('Automation')->MacroActionUpdate(
                        %MacroAction,
                        UserID => 1,
                        Parameters => {
                            DynamicFieldName   => $Data{DFSelectionTargetName},
                            DynamicFieldValue  => "<KIX_CONTACT_DynamicField_$Data{DFSelectionContactSourceName}_ObjectValue_0>", # result should be first value of contact source DF
                            DynamicFieldAppend => 0
                        }
                    );
                    $Success = $Kernel::OM->Get('Automation')->MacroExecute(
                        ID       => $MacroID,
                        ObjectID => $TicketID,
                        UserID   => 1,
                    );
                    $Self->True(
                        $Success,
                        'contact DF placeholder (MacroExecute)',
                    );
                    %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
                        TicketID      => $TicketID,
                        DynamicFields => 1,
                        UserID        => 1,
                        Silent        => 1
                    );
                    if (IsHashRefWithData(\%Ticket)) {
                        my $SelectionValue = $Ticket{'DynamicField_'.$Data{DFSelectionTargetName}};
                        $Self->True(
                            IsArrayRefWithData($SelectionValue) ? 1 : 0,
                            'Check target selection DF (contact DF placeholder (ObjectValue_0))',
                        );
                        if (IsArrayRefWithData($SelectionValue)) {
                            $Self->Is(
                                scalar(@{$SelectionValue}),
                                1,
                                'Check target selection DF (contact DF placeholder (ObjectValue_0))',
                            );
                            $Self->IsDeeply(
                                $SelectionValue,
                                [ $Data{DFSelection_ContactValue}->[0] ],
                                'Check target selection DF (contact DF placeholder (ObjectValue_0))',
                            );
                        }
                    }
                    ###### for text DF by other dynamic field (only key placeholder)
                    $Kernel::OM->Get('Automation')->MacroActionUpdate(
                        %MacroAction,
                        UserID => 1,
                        Parameters => {
                            DynamicFieldName   => $Data{DFTextTargetName},
                            DynamicFieldValue  => "<KIX_TICKET_DynamicField_$Data{DFSelectionSourceName}_Key>",
                            DynamicFieldAppend => 0
                        }
                    );
                    $Success = $Kernel::OM->Get('Automation')->MacroExecute(
                        ID       => $MacroID,
                        ObjectID => $TicketID,
                        UserID   => 1,
                    );
                    $Self->True(
                        $Success,
                        'text DF (MacroExecute) - key placeholder',
                    );
                    %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
                        TicketID      => $TicketID,
                        DynamicFields => 1,
                        UserID        => 1,
                        Silent        => 1
                    );
                    if (IsHashRefWithData(\%Ticket)) {
                        my $TextValue = $Ticket{'DynamicField_'.$Data{DFTextTargetName}};
                        $Self->True(
                            IsArrayRefWithData($TextValue) ? 1 : 0,
                            'Check target text DF (key placeholder)',
                        );
                        if (IsArrayRefWithData($TextValue)) {
                            $Self->Is(
                                scalar(@{$TextValue}),
                                1,
                                'Check target text DF (key placeholder)',
                            );
                            $Self->Is(
                                $TextValue->[0],
                                'Key1#Key2',
                                'Check target text DF (key placeholder)',
                            );
                        }
                    }
                    ###### for text DF by other dynamic field (object value placeholder)
                    $Kernel::OM->Get('Automation')->MacroActionUpdate(
                        %MacroAction,
                        UserID => 1,
                        Parameters => {
                            DynamicFieldName   => $Data{DFTextTargetName},
                            DynamicFieldValue  => "<KIX_TICKET_DynamicField_$Data{DFSelectionSourceName}_ObjectValue>",
                            DynamicFieldAppend => 0
                        }
                    );
                    $Success = $Kernel::OM->Get('Automation')->MacroExecute(
                        ID       => $MacroID,
                        ObjectID => $TicketID,
                        UserID   => 1,
                    );
                    $Self->True(
                        $Success,
                        'text DF (MacroExecute) - object value placeholder',
                    );
                    %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
                        TicketID      => $TicketID,
                        DynamicFields => 1,
                        UserID        => 1,
                        Silent        => 1
                    );
                    if (IsHashRefWithData(\%Ticket)) {
                        my $TextValue = $Ticket{'DynamicField_'.$Data{DFTextTargetName}};
                        $Self->True(
                            IsArrayRefWithData($TextValue) ? 1 : 0,
                            'Check target text DF (object value placeholder)',
                        );
                        if (IsArrayRefWithData($TextValue)) {
                            $Self->Is(
                                scalar(@{$TextValue}),
                                2,
                                'Check target text DF (object value placeholder)',
                            );
                            $Self->IsDeeply(
                                $TextValue,
                                $Data{DFSelection_SourceValue},
                                'Check target text DF (object value placeholder)',
                            );
                        }
                    }
                    ###### for text DF by other dynamic field (additional check with value placeholder)
                    $Kernel::OM->Get('Automation')->MacroActionUpdate(
                        %MacroAction,
                        UserID => 1,
                        Parameters => {
                            DynamicFieldName   => $Data{DFTextTargetName},
                            DynamicFieldValue  => "<KIX_TICKET_DynamicField_$Data{DFSelectionSourceName}_Value>",
                            DynamicFieldAppend => 0
                        }
                    );
                    $Success = $Kernel::OM->Get('Automation')->MacroExecute(
                        ID       => $MacroID,
                        ObjectID => $TicketID,
                        UserID   => 1,
                    );
                    $Self->True(
                        $Success,
                        'text DF (MacroExecute) - value placeholder',
                    );
                    %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
                        TicketID      => $TicketID,
                        DynamicFields => 1,
                        UserID        => 1,
                        Silent        => 1
                    );
                    if (IsHashRefWithData(\%Ticket)) {
                        my $TextValue = $Ticket{'DynamicField_'.$Data{DFTextTargetName}};
                        $Self->True(
                            IsArrayRefWithData($TextValue) ? 1 : 0,
                            'Check target text DF (value placeholder)',
                        );
                        if (IsArrayRefWithData($TextValue)) {
                            $Self->Is(
                                scalar(@{$TextValue}),
                                1,
                                'Check target text DF (value placeholder)',
                            );
                            $Self->Is(
                                $TextValue->[0],
                                'Value1#Value2',
                                'Check target text DF (value placeholder)',
                            );
                        }
                    }
                    ###### for text DF by other dynamic field (value & key placeholder)
                    $Kernel::OM->Get('Automation')->MacroActionUpdate(
                        %MacroAction,
                        UserID => 1,
                        Parameters => {
                            DynamicFieldName   => $Data{DFTextTargetName},
                            DynamicFieldValue  => "<KIX_TICKET_DynamicField_$Data{DFSelectionSourceName}_Value><KIX_TICKET_DynamicField_$Data{DFSelectionSourceName}_Key>",
                            DynamicFieldAppend => 0
                        }
                    );
                    $Success = $Kernel::OM->Get('Automation')->MacroExecute(
                        ID       => $MacroID,
                        ObjectID => $TicketID,
                        UserID   => 1,
                    );
                    $Self->True(
                        $Success,
                        'text DF (MacroExecute) - value & key placeholder'
                    );
                    %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
                        TicketID      => $TicketID,
                        DynamicFields => 1,
                        UserID        => 1,
                        Silent        => 1
                    );
                    if (IsHashRefWithData(\%Ticket)) {
                        my $TextValue = $Ticket{'DynamicField_'.$Data{DFTextTargetName}};
                        $Self->True(
                            IsArrayRefWithData($TextValue) ? 1 : 0,
                            'Check target text DF (value & key placeholder)',
                        );
                        if (IsArrayRefWithData($TextValue)) {
                            $Self->Is(
                                scalar(@{$TextValue}),
                                1,
                                'Check target text DF (value & key placeholder)'
                            );
                            $Self->Is(
                                $TextValue->[0],
                                'Value1#Value2Key1#Key2',
                                'Check target text DF (value & key placeholder)'
                            );
                        }
                    }

                    ## article tests
                    if ($ArticleID) {
                        ###### use ArticleID as ObjectID in parameters, but execute macro still with TicketID => DF should be set on article (because target DF is for articles)
                        $Kernel::OM->Get('Automation')->MacroActionUpdate(
                            %MacroAction,
                            UserID => 1,
                            Parameters => {
                                ObjectID => $ArticleID,
                                DynamicFieldName   => $Data{DFTextTargetNameArticle},
                                DynamicFieldValue  => "FirstArticleTest",
                                DynamicFieldAppend => 0
                            }
                        );
                        $Success = $Kernel::OM->Get('Automation')->MacroExecute(
                            ID       => $MacroID,
                            ObjectID => $TicketID,
                            UserID   => 1,
                        );
                        $Self->True(
                            $Success,
                            'article text DF (MacroExecute) - ArticleID as ObjectID'
                        );
                        my %Article = $Kernel::OM->Get('Ticket')->ArticleGet(
                            ArticleID     => $ArticleID,
                            DynamicFields => 1,
                            UserID        => 1,
                            Silent        => 1
                        );
                        if (IsHashRefWithData(\%Article)) {
                            my $TextValue = $Article{'DynamicField_'.$Data{DFTextTargetNameArticle}};
                            $Self->True(
                                IsArrayRefWithData($TextValue) ? 1 : 0,
                                'Check target text DF (article)',
                            );
                            if (IsArrayRefWithData($TextValue)) {
                                $Self->Is(
                                    scalar(@{$TextValue}),
                                    1,
                                    'Check target text DF (article)'
                                );
                                $Self->Is(
                                    $TextValue->[0],
                                    'FirstArticleTest',
                                    'Check target text DF (article, value check)'
                                );
                            }
                        }

                        ###### use placeholder for article as ObjectID in parameters and append new value
                        $Kernel::OM->Get('Automation')->MacroActionUpdate(
                            %MacroAction,
                            UserID => 1,
                            Parameters => {
                                ObjectID => '<KIX_LAST_ArticleID>',
                                DynamicFieldName   => $Data{DFTextTargetNameArticle},
                                DynamicFieldValue  => "SecondArticleTest",
                                DynamicFieldAppend => 1
                            }
                        );
                        $Success = $Kernel::OM->Get('Automation')->MacroExecute(
                            ID       => $MacroID,
                            ObjectID => $TicketID,
                            UserID   => 1,
                        );
                        $Self->True(
                            $Success,
                            'article text DF (MacroExecute) - ArticleID placeholder as ObjectID'
                        );
                        %Article = $Kernel::OM->Get('Ticket')->ArticleGet(
                            ArticleID     => $ArticleID,
                            DynamicFields => 1,
                            UserID        => 1,
                            Silent        => 1
                        );
                        if (IsHashRefWithData(\%Article)) {
                            my $TextValue = $Article{'DynamicField_'.$Data{DFTextTargetNameArticle}};
                            $Self->True(
                                IsArrayRefWithData($TextValue) ? 1 : 0,
                                'Check target text DF (article, by placeholder)',
                            );
                            if (IsArrayRefWithData($TextValue)) {
                                $Self->Is(
                                    scalar(@{$TextValue}),
                                    2,
                                    'Check target text DF (article, by placeholder)'
                                );
                                $Self->Is(
                                    $TextValue->[0],
                                    'FirstArticleTest',
                                    'Check target text DF (article, by placeholder, first value)'
                                );
                                $Self->Is(
                                    $TextValue->[1],
                                    'SecondArticleTest',
                                    'Check target text DF (article, by placeholder, second value)'
                                );
                            }
                        }
                    }
                }
            }
        }
    }
}

sub _AddObjects {
    my $ContactID = $Kernel::OM->Get('Contact')->ContactAdd(
        Firstname             => 'DFSetFirstname',
        Lastname              => 'DFSetLastname',
        Email                 => 'dfset@text.com',
        ValidID               => 1,
        UserID                => 1
    );
    $Self->True(
        $ContactID,
        '_AddObjects - contact create',
    );
    return if (!$ContactID);

    my $TicketID_1 = $Kernel::OM->Get('Ticket')->TicketCreate(
        Title     => 'DFSetTicket',
        OwnerID   => 1,
        Queue     => 'Junk',
        Lock      => 'unlock',
        Priority  => '3 normal',
        State     => 'closed',
        UserID    => 1,
        ContactID => $ContactID
    );
    $Self->True(
        $TicketID_1,
        '_AddObjects - create ticket'
    );
    return if (!$TicketID_1);

    my $ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
        TicketID         => $TicketID_1,
        ChannelID        => 1,
        CustomerVisible  => 0,
        SenderType       => 'agent',
        Subject          => 'DFSetArticleSubject',
        Body             => 'DFSetArticleBody',
        Charset          => 'utf-8',
        MimeType         => 'text/plain',
        HistoryType      => 'AddNote',
        HistoryComment   => 'test article!',
        UserID           => 1
    );
    $Self->True(
        $ArticleID,
        '_AddObjects - create aarticle'
    );
    return if (!$ArticleID);

    my $DF1ID = $Kernel::OM->Get('DynamicField')->DynamicFieldAdd(
        Name            => $Data{DFSelectionSourceName},
        Label           => $Data{DFSelectionSourceName},
        FieldType       => 'Multiselect',
        ObjectType      => 'Ticket',
        Config          => {
                CountMin => 0,
                CountMax => 2,
                CountDefault => 0,
                ItemSeparator => q{#},
                DefaultValue => undef,
                PossibleValues => $Data{DFSelection_PossibleValues}
        },
        ValidID         => 1,
        UserID          => 1
    );
    $Self->True(
        $DF1ID,
        '_AddObjects - create dynamic field 1'
    );
    return if (!$DF1ID);
    my $DynamicField1Config = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
        ID => $DF1ID
    );
    $Self->True(
        IsHashRefWithData($DynamicField1Config),
        '_AddObjects - get dynamic field 1 config'
    );
    return if (!IsHashRefWithData($DynamicField1Config));

    my $DF2ID = $Kernel::OM->Get('DynamicField')->DynamicFieldAdd(
        Name            => $Data{DFSelectionTargetName},
        Label           => $Data{DFSelectionTargetName},
        FieldType       => 'Multiselect',
        ObjectType      => 'Ticket',
        Config          => {
                CountMin => 0,
                CountMax => 2,
                CountDefault => 0,
                ItemSeparator => q{#},
                DefaultValue => undef,
                PossibleValues => $Data{DFSelection_PossibleValues}
        },
        ValidID         => 1,
        UserID          => 1
    );
    $Self->True(
        $DF2ID,
        '_AddObjects - create dynamic field 2'
    );
    return if (!$DF2ID);
    my $DynamicField2Config = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
        ID => $DF2ID
    );
    $Self->True(
        IsHashRefWithData($DynamicField2Config),
        '_AddObjects - get dynamic field 2 config'
    );
    return if (!IsHashRefWithData($DynamicField2Config));

    my $DF3ID = $Kernel::OM->Get('DynamicField')->DynamicFieldAdd(
        Name            => $Data{DFSelectionContactSourceName},
        Label           => $Data{DFSelectionContactSourceName},
        FieldType       => 'Multiselect',
        ObjectType      => 'Contact',
        Config          => {
                CountMin => 0,
                CountMax => 2,
                CountDefault => 0,
                ItemSeparator => q{#},
                DefaultValue => undef,
                PossibleValues => $Data{DFSelection_PossibleValues}
        },
        ValidID         => 1,
        UserID          => 1
    );
    $Self->True(
        $DF3ID,
        '_AddObjects - create dynamic field 3'
    );
    return if (!$DF3ID);
    my $DynamicField3Config = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
        ID => $DF3ID
    );
    $Self->True(
        IsHashRefWithData($DynamicField3Config),
        '_AddObjects - get dynamic field 3 config'
    );
    return if (!IsHashRefWithData($DynamicField3Config));

    my $DF4ID = $Kernel::OM->Get('DynamicField')->DynamicFieldAdd(
        Name            => $Data{DFTextTargetName},
        Label           => $Data{DFTextTargetName},
        FieldType       => 'Text',
        ObjectType      => 'Ticket',
        Config          => {
                CountMin => 0,
                CountMax => 2,
                CountDefault => 0,
                ItemSeparator => q{#},
                DefaultValue => undef
        },
        ValidID         => 1,
        UserID          => 1
    );
    $Self->True(
        $DF4ID,
        '_AddObjects - create dynamic field 4'
    );
    return if (!$DF4ID);
    my $DynamicField4Config = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
        ID => $DF4ID
    );
    $Self->True(
        IsHashRefWithData($DynamicField4Config),
        '_AddObjects - get dynamic field 4 config'
    );
    return if (!IsHashRefWithData($DynamicField4Config));

    my $DF5ID = $Kernel::OM->Get('DynamicField')->DynamicFieldAdd(
        Name            => $Data{DFTextTargetNameArticle},
        Label           => $Data{DFTextTargetNameArticle},
        FieldType       => 'Text',
        ObjectType      => 'Article',
        Config          => {
                CountMin => 0,
                CountMax => 2,
                CountDefault => 0,
                ItemSeparator => q{#},
                DefaultValue => undef
        },
        ValidID         => 1,
        UserID          => 1
    );
    $Self->True(
        $DF5ID,
        '_AddObjects - create dynamic field 5'
    );
    return if (!$DF5ID);
    my $DynamicField5Config = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
        ID => $DF5ID
    );
    $Self->True(
        IsHashRefWithData($DynamicField5Config),
        '_AddObjects - get dynamic field 5 config'
    );
    return if (!IsHashRefWithData($DynamicField5Config));

    my $Success = $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
        DynamicFieldConfig => $DynamicField1Config,
        ObjectID => $TicketID_1,
        Value    => $Data{DFSelection_SourceValue},
        UserID => 1
    );
    return if (!$Success);

    $Success = $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
        DynamicFieldConfig => $DynamicField3Config,
        ObjectID => $ContactID,
        Value    => $Data{DFSelection_ContactValue},
        UserID => 1
    );
    return if (!$Success);

    return ($TicketID_1, $ArticleID);
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
