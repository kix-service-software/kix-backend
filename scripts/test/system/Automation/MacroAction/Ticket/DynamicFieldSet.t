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

my $ContactObject    = $Kernel::OM->Get('Contact');
my $AutomationObject = $Kernel::OM->Get('Automation');
my $TicketObject     = $Kernel::OM->Get('Ticket');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my %Data = (
    DFSelection_PossibleValues => {
        Key1 => "Value1",
        Key2 => "Value2",
        Key3 => "Value3"
    },

    DFSelection_SourceValue  => ['Key1', 'Key2'],
    DFSelection_ContactValue => ['Key1', 'Key3'],

    DFSelectionTargetName => 'DFSetTargetSelection',
    DFTextTargetName      => 'DFSetTargetText',

    DFSelectionSourceName        => 'DFSetSourceSelection',
    DFSelectionContactSourceName => 'DFSetContactSelection'
);

my $TicketID = _AddObjects();

if ($TicketID) {
    my %Ticket = $TicketObject->TicketGet(
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

        my $MacroID = $AutomationObject->MacroAdd(
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
            my $MacroActionID = $AutomationObject->MacroActionAdd(
                MacroID    => $MacroID,
                Type       => 'DynamicFieldSet',
                Parameters => {
                    DynamicFieldName   => $Data{DFSelectionTargetName},
                    DynamicFieldValue  => 'Key1',
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
                my %MacroAction = $AutomationObject->MacroActionGet(
                    ID => $MacroActionID
                );

                if (IsHashRefWithData(\%MacroAction)) {

                    # update macro - set ExecOrder
                    my $Success = $AutomationObject->MacroUpdate(
                        ID        => $MacroID,
                        ExecOrder => [ $MacroActionID ],
                        UserID    => 1,
                    );
                    $Self->True(
                        $Success,
                        'MacroUpdate - ExecOrder',
                    );

                    ###### 1st execute
                    $Success = $AutomationObject->MacroExecute(
                        ID       => $MacroID,
                        ObjectID => $TicketID,
                        UserID   => 1,
                    );
                    $Self->True(
                        $Success,
                        '1st MacroExecute',
                    );
                    %Ticket = $TicketObject->TicketGet(
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

                    ###### 2nd execute
                    $AutomationObject->MacroActionUpdate(
                        %MacroAction,
                        UserID => 1,
                        Parameters => {
                            DynamicFieldName   => $Data{DFSelectionTargetName},
                            DynamicFieldValue  => 'Key2',
                            DynamicFieldAppend => 0
                        }
                    );
                    $Success = $AutomationObject->MacroExecute(
                        ID       => $MacroID,
                        ObjectID => $TicketID,
                        UserID   => 1,
                    );
                    $Self->True(
                        $Success,
                        '2nd MacroExecute',
                    );
                    %Ticket = $TicketObject->TicketGet(
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
                    $AutomationObject->MacroActionUpdate(
                        %MacroAction,
                        UserID => 1,
                        Parameters => {
                            DynamicFieldName   => $Data{DFSelectionTargetName},
                            DynamicFieldValue  => 'Key3',
                            DynamicFieldAppend => 1          # now append
                        }
                    );
                    $Success = $AutomationObject->MacroExecute(
                        ID       => $MacroID,
                        ObjectID => $TicketID,
                        UserID   => 1,
                    );
                    $Self->True(
                        $Success,
                        '3rd MacroExecute',
                    );
                    %Ticket = $TicketObject->TicketGet(
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
                    $AutomationObject->MacroActionUpdate(
                        %MacroAction,
                        UserID => 1,
                        Parameters => {
                            DynamicFieldName   => $Data{DFSelectionTargetName},
                            DynamicFieldValue  => "<KIX_TICKET_DynamicField_$Data{DFSelectionSourceName}_Key>",
                            DynamicFieldAppend => 0
                        }
                    );
                    $Success = $AutomationObject->MacroExecute(
                        ID       => $MacroID,
                        ObjectID => $TicketID,
                        UserID   => 1,
                    );
                    $Self->True(
                        $Success,
                        'key placeholder (MacroExecute)',
                    );
                    %Ticket = $TicketObject->TicketGet(
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
                        if (IsArrayRefWithData($SelectionValue)) {
                            $Self->Is(
                                scalar(@{$SelectionValue}),
                                2,
                                'Check target selection DF (key placeholder)',
                            );
                            $Self->IsDeeply(
                                $SelectionValue,
                                $Data{DFSelection_SourceValue},
                                'Check target selection DF (key placeholder)',
                            );
                        }
                    }
                    ###### by other dynamic field (with object value placeholder)
                    $AutomationObject->MacroActionUpdate(
                        %MacroAction,
                        UserID => 1,
                        Parameters => {
                            DynamicFieldName   => $Data{DFSelectionTargetName},
                            DynamicFieldValue  => "<KIX_TICKET_DynamicField_$Data{DFSelectionSourceName}_ObjectValue>",
                            DynamicFieldAppend => 0
                        }
                    );
                    $Success = $AutomationObject->MacroExecute(
                        ID       => $MacroID,
                        ObjectID => $TicketID,
                        UserID   => 1,
                    );
                    $Self->True(
                        $Success,
                        'object value placeholder (MacroExecute)',
                    );
                    %Ticket = $TicketObject->TicketGet(
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
                    ###### by contact dynamic field (with key placeholder)
                    $AutomationObject->MacroActionUpdate(
                        %MacroAction,
                        UserID => 1,
                        Parameters => {
                            DynamicFieldName   => $Data{DFSelectionTargetName},
                            DynamicFieldValue  => "<KIX_CONTACT_DynamicField_$Data{DFSelectionContactSourceName}_Key>",
                            DynamicFieldAppend => 0
                        }
                    );
                    $Success = $AutomationObject->MacroExecute(
                        ID       => $MacroID,
                        ObjectID => $TicketID,
                        UserID   => 1,
                    );
                    $Self->True(
                        $Success,
                        'contact DF placeholder (MacroExecute)',
                    );
                    %Ticket = $TicketObject->TicketGet(
                        TicketID      => $TicketID,
                        DynamicFields => 1,
                        UserID        => 1,
                        Silent        => 1
                    );
                    if (IsHashRefWithData(\%Ticket)) {
                        my $SelectionValue = $Ticket{'DynamicField_'.$Data{DFSelectionTargetName}};
                        $Self->True(
                            IsArrayRefWithData($SelectionValue) ? 1 : 0,
                            'Check target selection DF (child DF placeholder)',
                        );
                        if (IsArrayRefWithData($SelectionValue)) {
                            $Self->Is(
                                scalar(@{$SelectionValue}),
                                2,
                                'Check target selection DF (child DF placeholder)',
                            );
                            $Self->IsDeeply(
                                $SelectionValue,
                                $Data{DFSelection_ContactValue},
                                'Check target selection DF (child DF placeholder)',
                            );
                        }
                    }
                    ###### for text DF by other dynamic field (only key placeholder)
                    $AutomationObject->MacroActionUpdate(
                        %MacroAction,
                        UserID => 1,
                        Parameters => {
                            DynamicFieldName   => $Data{DFTextTargetName},
                            DynamicFieldValue  => "<KIX_TICKET_DynamicField_$Data{DFSelectionSourceName}_Key>",
                            DynamicFieldAppend => 0
                        }
                    );
                    $Success = $AutomationObject->MacroExecute(
                        ID       => $MacroID,
                        ObjectID => $TicketID,
                        UserID   => 1,
                    );
                    $Self->True(
                        $Success,
                        'text DF (MacroExecute) - key placeholder',
                    );
                    %Ticket = $TicketObject->TicketGet(
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
                                2,
                                'Check target text DF (key placeholder)',
                            );
                            $Self->IsDeeply(
                                $TextValue,
                                $Data{DFSelection_SourceValue},
                                'Check target text DF (key placeholder)', # text DF has 2 values (the keys of the other DF)
                            );
                        }
                    }
                    ###### for text DF by other dynamic field (only value placeholder)
                    $AutomationObject->MacroActionUpdate(
                        %MacroAction,
                        UserID => 1,
                        Parameters => {
                            DynamicFieldName   => $Data{DFTextTargetName},
                            DynamicFieldValue  => "<KIX_TICKET_DynamicField_$Data{DFSelectionSourceName}_Value>",
                            DynamicFieldAppend => 0
                        }
                    );
                    $Success = $AutomationObject->MacroExecute(
                        ID       => $MacroID,
                        ObjectID => $TicketID,
                        UserID   => 1,
                    );
                    $Self->True(
                        $Success,
                        'text DF (MacroExecute) - value placeholder',
                    );
                    %Ticket = $TicketObject->TicketGet(
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
                    ###### for text DF by other dynamic field (value & key placeholder) # check if key placeholder is not alone, textual replacement should happen
                    $AutomationObject->MacroActionUpdate(
                        %MacroAction,
                        UserID => 1,
                        Parameters => {
                            DynamicFieldName   => $Data{DFTextTargetName},
                            DynamicFieldValue  => "<KIX_TICKET_DynamicField_$Data{DFSelectionSourceName}_Value><KIX_TICKET_DynamicField_$Data{DFSelectionSourceName}_Key>",
                            DynamicFieldAppend => 0
                        }
                    );
                    $Success = $AutomationObject->MacroExecute(
                        ID       => $MacroID,
                        ObjectID => $TicketID,
                        UserID   => 1,
                    );
                    $Self->True(
                        $Success,
                        'text DF (MacroExecute) - value & key placeholder'
                    );
                    %Ticket = $TicketObject->TicketGet(
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
                                'Value1#Value2'.join('#',@{ $Data{DFSelection_SourceValue} }),
                                'Check target text DF (value & key placeholder)'
                            );
                        }
                    }
                }
            }
        }
    }
}

sub _AddObjects {
    my $ContactID = $ContactObject->ContactAdd(
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
        '_AddObjectss - create dynamic field 1'
    );
    return if (!$DF1ID);
    my $DynamicField1Config = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
        ID => $DF1ID
    );
    $Self->True(
        IsHashRefWithData($DynamicField1Config),
        '_AddObjectss - get dynamic field 1 config'
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
        '_AddObjectss - create dynamic field 2'
    );
    return if (!$DF2ID);
    my $DynamicField2Config = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
        ID => $DF2ID
    );
    $Self->True(
        IsHashRefWithData($DynamicField2Config),
        '_AddObjectss - get dynamic field 2 config'
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
        '_AddObjectss - create dynamic field 3'
    );
    return if (!$DF3ID);
    my $DynamicField3Config = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
        ID => $DF3ID
    );
    $Self->True(
        IsHashRefWithData($DynamicField3Config),
        '_AddObjectss - get dynamic field 3 config'
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
        '_AddObjectss - create dynamic field 4'
    );
    return if (!$DF4ID);
    my $DynamicField4Config = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
        ID => $DF4ID
    );
    $Self->True(
        IsHashRefWithData($DynamicField4Config),
        '_AddObjectss - get dynamic field 4 config'
    );
    return if (!IsHashRefWithData($DynamicField4Config));

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

    return $TicketID_1;
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
