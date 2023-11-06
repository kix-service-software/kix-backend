# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
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

my $AutomationObject = $Kernel::OM->Get('Automation');
my $TicketObject     = $Kernel::OM->Get('Ticket');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# prevent event handling
$Kernel::OM->Get('Config')->Set(
    Key => 'Ticket::EventModulePost',
);

my %Data = (
    ContactEmail       => 'TicketCreate@test.com',
    OrganisationNumber => 'TicketCreateOrganisation',
    UserLogin          => 'TicketCreate',
    Priority           => '5 very low',
    State              => 'closed',
    Team               => 'Junk',
    Type               => 'Unclassified',
    Title              => 'TicketCreate_SourceTicket',

    DFSelectionName => 'TicketCreateSelection',
    DFSelection_PossibleValues => {
        Key1 => "Value1",
        Key2 => "Value2",
        Key3 => "Value3"
    },
    DFSelection_Value => ['Key1', 'Key2'],

    DFTextName => 'TicketCreateText'
);

my ($ContactID, $OrgID, $UserID);
my $Success = _AddObjects();

if ($Success) {
    my $PrioID = $Kernel::OM->Get('Priority')->PriorityLookup(
        Priority => $Data{Priority},
        Silent   => 1
    );
    $Self->True(
        $PrioID,
        'Priority lookup'
    );
    my $StateID = $Kernel::OM->Get('State')->StateLookup(
        State  => $Data{State},
        Silent => 1
    );
    $Self->True(
        $StateID,
        'State lookup'
    );
    my $TeamID = $Kernel::OM->Get('Queue')->QueueLookup(
        Queue  => $Data{Team},
        Silent => 1
    );
    $Self->True(
        $TeamID,
        'Team lookup'
    );
    my $TypeID = $Kernel::OM->Get('Type')->TypeLookup(
        Type   => $Data{Type},
        Silent => 1
    );
    $Self->True(
        $TypeID,
        'Type lookup'
    );

    if ($PrioID, $StateID, $TeamID, $TypeID) {
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
            my @DFValue = map{ [$Data{DFSelectionName}, $_] } @{$Data{DFSelection_Value}};
            my $MacroActionID = $AutomationObject->MacroActionAdd(
                MacroID    => $MacroID,
                Type       => 'TicketCreate',
                Parameters => {
                    ContactEmailOrID       => $Data{ContactEmail},
                    OrganisationNumberOrID => $Data{OrganisationNumber},
                    OwnerLoginOrID         => $Data{UserLogin},
                    Priority               => $Data{Priority},
                    State                  => $Data{State},
                    Title                  => $Data{Title},
                    Team                   => $Data{Team},
                    Type                   => $Data{Type},
                    DynamicFieldList       => \@DFValue,
                    Body => 'some body for TicketCreate test'
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

                    $Success = $AutomationObject->MacroExecute(
                        ID       => $MacroID,
                        # ObjectID => $TicketID, # no object id
                        UserID   => 1,
                    );
                    $Self->True(
                        $Success,
                        'MacroExecute (source ticket)',
                    );

                    $Self->True(
                        $AutomationObject->{MacroResults}->{NewTicketID},
                        'Ticket created and ID in results (source ticket)',
                    );
                    if ($AutomationObject->{MacroResults}->{NewTicketID}) {
                        my %SourceTicket = $TicketObject->TicketGet(
                            TicketID      => $AutomationObject->{MacroResults}->{NewTicketID},
                            DynamicFields => 1,
                            UserID        => 1,
                            Silent        => 1
                        );
                        if (IsHashRefWithData(\%SourceTicket)) {
                            $Self->Is(
                                $SourceTicket{Title},
                                $Data{Title},
                                'Check title (source ticket)'
                            );
                            $Self->Is(
                                $SourceTicket{PriorityID},
                                $PrioID,
                                'Check prio (source ticket)'
                            );
                            $Self->Is(
                                $SourceTicket{StateID},
                                $StateID,
                                'Check state (source ticket)'
                            );
                            $Self->Is(
                                $SourceTicket{QueueID},
                                $TeamID,
                                'Check team (source ticket)'
                            );
                            $Self->Is(
                                $SourceTicket{TypeID},
                                $TypeID,
                                'Check type (source ticket)'
                            );
                            $Self->Is(
                                $SourceTicket{ContactID},
                                $ContactID,
                                'Check contact (source ticket)'
                            );
                            $Self->Is(
                                $SourceTicket{OrganisationID},
                                $OrgID,
                                'Check organisation (source ticket)'
                            );
                            $Self->Is(
                                $SourceTicket{OwnerID},
                                $UserID,
                                'Check owner (source ticket)'
                            );

                            my $SelectionValue = $SourceTicket{'DynamicField_'.$Data{DFSelectionName}};
                            $Self->True(
                                IsArrayRefWithData($SelectionValue) ? 1 : 0,
                                'Check selection DF (source ticket)'
                            );
                            if (IsArrayRefWithData($SelectionValue)) {
                                $Self->Is(
                                    scalar(@{$SelectionValue}),
                                    2,
                                    'Check selection DF (source ticket)'
                                );
                                $Self->IsDeeply(
                                    $SelectionValue,
                                    $Data{DFSelection_Value},
                                    'Check selection DF (source ticket)'
                                );
                            }
                        }
                    }

                    $AutomationObject->MacroActionUpdate(
                        %MacroAction,
                        UserID => 1,
                        Parameters => {
                            ContactEmailOrID       => '<KIX_TICKET_ContactID>',
                            OrganisationNumberOrID => '<KIX_TICKET_OrgansationID>',
                            OwnerLoginOrID         => '<KIX_TICKET_OwnerID>',
                            Priority               => '<KIX_TICKET_Priority>',
                            State                  => '<KIX_TICKET_State>',
                            Title                  => '<KIX_TICKET_Title> clone',
                            Team                   => '<KIX_TICKET_Queue>',
                            Type                   => '<KIX_TICKET_Type>',
                            DynamicFieldList       => [
                                [$Data{DFSelectionName},"<KIX_TICKET_DynamicField_$Data{DFSelectionName}_Key>"],
                                [$Data{DFTextName},"KEYS: <KIX_TICKET_DynamicField_$Data{DFSelectionName}_Key>"]
                            ],
                            Body => 'some body for TicketCreate test'
                        }
                    );
                    my $SourceTicketID = $AutomationObject->{MacroResults}->{NewTicketID};
                    $Success = $AutomationObject->MacroExecute(
                        ID       => $MacroID,
                        ObjectID => $SourceTicketID, # use previous created ticket
                        UserID   => 1,
                    );
                    $Self->True(
                        $Success,
                        'MacroExecute (clone ticket)'
                    );
                    $Self->True(
                        $AutomationObject->{MacroResults}->{NewTicketID},
                        'Ticket created and ID in results (clone ticket)'
                    );
                    $Self->IsNot(
                        $SourceTicketID,
                        $AutomationObject->{MacroResults}->{NewTicketID},
                        'clone ticket create'
                    );
                    if ($AutomationObject->{MacroResults}->{NewTicketID}) {
                        my %CloneTicket = $TicketObject->TicketGet(
                            TicketID      => $AutomationObject->{MacroResults}->{NewTicketID},
                            DynamicFields => 1,
                            UserID        => 1,
                            Silent        => 1
                        );
                        if (IsHashRefWithData(\%CloneTicket)) {
                            $Self->Is(
                                $CloneTicket{Title},
                                $Data{Title} . " clone",
                                'Check title (clone ticket)'
                            );
                            $Self->Is(
                                $CloneTicket{PriorityID},
                                $PrioID,
                                'Check prio (clone ticket)'
                            );
                            $Self->Is(
                                $CloneTicket{StateID},
                                $StateID,
                                'Check state (clone ticket)'
                            );
                            $Self->Is(
                                $CloneTicket{QueueID},
                                $TeamID,
                                'Check team (clone ticket)'
                            );
                            $Self->Is(
                                $CloneTicket{TypeID},
                                $TypeID,
                                'Check type (clone ticket)'
                            );
                            $Self->Is(
                                $CloneTicket{ContactID},
                                $ContactID,
                                'Check contact (clone ticket)'
                            );
                            $Self->Is(
                                $CloneTicket{OrganisationID},
                                $OrgID,
                                'Check organisation (clone ticket)'
                            );
                            $Self->Is(
                                $CloneTicket{OwnerID},
                                $UserID,
                                'Check owner (clone ticket)'
                            );

                            my $SelectionValue = $CloneTicket{'DynamicField_'.$Data{DFSelectionName}};
                            $Self->True(
                                IsArrayRefWithData($SelectionValue) ? 1 : 0,
                                'Check selection DF (clone ticket)'
                            );
                            if (IsArrayRefWithData($SelectionValue)) {
                                $Self->Is(
                                    scalar(@{$SelectionValue}),
                                    2,
                                    'Check selection DF (clone ticket)'
                                );
                                $Self->IsDeeply(
                                    $SelectionValue,
                                    $Data{DFSelection_Value},
                                    'Check selection DF (clone ticket)'
                                );
                            }

                            my $TextValue = $CloneTicket{'DynamicField_'.$Data{DFTextName}};
                            $Self->True(
                                IsArrayRefWithData($TextValue) ? 1 : 0,
                                'Check text DF (clone ticket)'
                            );
                            if (IsArrayRefWithData($TextValue)) {
                                $Self->Is(
                                    scalar(@{$TextValue}),
                                    1,
                                    'Check text DF (clone ticket)'
                                );
                                $Self->Is(
                                    $TextValue->[0],
                                    'KEYS: '. join('#', @{ $Data{DFSelection_Value} }),
                                    'Check text DF (clone ticket)'
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
    $ContactID = $Kernel::OM->Get('Contact')->ContactAdd(
        Firstname             => 'TicketCreateTest',
        Lastname              => 'TicketCreateTest',
        Email                 => $Data{ContactEmail},
        ValidID               => 1,
        UserID                => 1
    );
    $Self->True(
        $ContactID,
        '_AddObjects - contact create',
    );
    return if (!$ContactID);

    $OrgID = $Kernel::OM->Get('Organisation')->OrganisationAdd(
        Number   => $Data{OrganisationNumber},
        Name     => 'TicketCreateTest',
        ValidID  => 1,
        UserID   => 1
    );
    $Self->True(
        $OrgID,
        '_AddObjects - organisation create',
    );
    return if (!$OrgID);

    $UserID = $Kernel::OM->Get('User')->UserAdd(
        UserLogin     => $Data{UserLogin},
        ValidID       => 1,
        ChangeUserID  => 1,
        IsAgent       => 1
    );
    $Self->True(
        $UserID,
        '_AddObjects - user create',
    );
    return if (!$UserID);

    my $SelectionDFID = $Kernel::OM->Get('DynamicField')->DynamicFieldAdd(
        Name            => $Data{DFSelectionName},
        Label           => $Data{DFSelectionName},
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
        ValidID => 1,
        UserID  => 1
    );
    $Self->True(
        $SelectionDFID,
        '_AddObjectss - create selection dynamic field'
    );
    return if (!$SelectionDFID);

    my $TextDFID = $Kernel::OM->Get('DynamicField')->DynamicFieldAdd(
        Name            => $Data{DFTextName},
        Label           => $Data{DFTextName},
        FieldType       => 'Text',
        ObjectType      => 'Ticket',
        Config          => {
                CountMin => 0,
                CountMax => 2,
                CountDefault => 0,
                ItemSeparator => q{#},
                DefaultValue => undef
        },
        ValidID => 1,
        UserID  => 1
    );
    $Self->True(
        $TextDFID,
        '_AddObjectss - create text dynamic field'
    );
    return if (!$TextDFID);

    return 1;
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
