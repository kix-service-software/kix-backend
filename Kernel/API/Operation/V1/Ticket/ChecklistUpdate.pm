# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Ticket::ChecklistUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Ticket::ChecklistUpdate - API ChecklistUpdate Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw( DebuggerObject WebserviceID )) {
        if ( !$Param{$Needed} ) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!"
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    $Self->{Config} = $Kernel::OM->Get('Config')->Get('API::Operation::V1::ChecklistUpdate');

    return $Self;
}

=item ParameterDefinition()

define parameter preparation and check for this operation

    my $Result = $OperationObject->ParameterDefinition(
        Data => {
            ...
        },
    );

    $Result = {
        ...
    };

=cut

sub ParameterDefinition {
    my ( $Self, %Param ) = @_;

    # get possible item states
    my $PossibleItemStates = $Kernel::OM->Get('Config')->Get('Ticket::Frontend::KIXSidebarChecklist')->{ItemState};
    my @PossibleItemStates = sort keys %{$PossibleItemStates};

    return {
        'TicketID' => {
            Required => 1
        },
        'ChecklistItem' => {
            Type     => 'HASH',
            Required => 1
        },
        'ChecklistItem::Text' => {
            RequiresValueIfUsed => 1,
        },
        'ChecklistItem::State' => {
            RequiresValueIfUsed => 1,
            OneOf    => \@PossibleItemStates,
        },
        'ChecklistItem::Position' => {
            RequiresValueIfUsed => 1,
            Format   => '^(\d+)$',
        },            
    }
}

=item Run()

perform TicketChecklistUpdate Operation. This will return the updated ChecklistItemID

    my $Result = $OperationObject->Run(
        Data => {
            TicketID  => 123,                                                  # required
            ChecklistItemID  => 123',                                          # required            
            ChecklistItem => {                                                 # required
                Text     => '...',
                State    => 'open',
                Position => 1,
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            ChecklistItemID => 123,                 # ID of changed item
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check if checklist item exists
    my $Checklist = $Kernel::OM->Get('Ticket')->TicketChecklistGet(
        TicketID => $Param{Data}->{TicketID},
        Result   => 'ID',
        UserID   => $Self->{Authorization}->{UserID},
    );

    if ( !IsHashRefWithData($Checklist) || !$Checklist->{$Param{Data}->{ChecklistItemID}}) {
        return $Self->_Error(
            Code => 'Object.NotFound'
        );
    }

    # isolate and trim ChecklistItem parameter
    my $ChecklistItem = $Self->_Trim(
        Data => $Param{Data}->{ChecklistItem},
    );

    my $ChecklistItemID = $Kernel::OM->Get('Ticket')->TicketChecklistItemUpdate(
        TicketID   => $Param{Data}->{TicketID},
        ItemID     => $Param{Data}->{ChecklistItemID},
        Text       => $ChecklistItem->{Text} || $Checklist->{$Param{Data}->{ChecklistItemID}}->{Text},
        State      => $ChecklistItem->{State} || $Checklist->{$Param{Data}->{ChecklistItemID}}->{State},
        Position   => $ChecklistItem->{Position} || $Checklist->{$Param{Data}->{ChecklistItemID}}->{Position},
        UserID     => $Self->{Authorization}->{UserID},
    );

    if ( !$ChecklistItemID ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate'
        );
    }

    return $Self->_Success(
        ChecklistItemID => $Param{Data}->{ChecklistItemID},
    );
}

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
