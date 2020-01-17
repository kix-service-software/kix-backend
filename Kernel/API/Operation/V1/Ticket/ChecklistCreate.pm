# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Ticket::ChecklistCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Ticket::ChecklistCreate - API ChecklistCreate Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::TicketChecklistCreate');

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
    my $PossibleItemStates = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Frontend::KIXSidebarChecklist')->{ItemState};
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
            Required => 1
        },
        'ChecklistItem::State' => {
            OneOf    => \@PossibleItemStates,
            Required => 1
        },
        'ChecklistItem::Position' => {
            Required => 1,
            Format   => '^(\d+)$',
        },            
    }
}

=item Run()

perform ChecklistCreate Operation. This will return the created ChecklistItemID

    my $Result = $OperationObject->Run(
        Data => {
            TicketID  => 123,                                                  # required
            ChecklistItem => {                                                 # required
                Text     => '...',                                             # required
                State    => 'open',                                            # required
                Position => 1,                                                 # required
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            ChecklistItemID => 1
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim ChecklistItem parameter
    my $ChecklistItem = $Self->_Trim(
        Data => $Param{Data}->{ChecklistItem},
    );

    my $ChecklistItemID = $Kernel::OM->Get('Kernel::System::Ticket')->TicketChecklistItemCreate(
        TicketID   => $Param{Data}->{TicketID},
        Text       => $ChecklistItem->{Text},
        State      => $ChecklistItem->{State},
        Position   => $ChecklistItem->{Position},
        UserID     => $Self->{Authorization}->{UserID},
    );

    if ( !$ChecklistItemID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create checklist item, please contact the system administrator',
        );
    }

    return $Self->_Success(
        Code            => 'Object.Created',
        ChecklistItemID => $ChecklistItemID,
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
