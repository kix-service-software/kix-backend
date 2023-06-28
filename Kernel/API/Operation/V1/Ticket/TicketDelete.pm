# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Ticket::TicketDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Ticket::TicketDelete - API Ticket TicketDelete Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

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

    return {
        'TicketID' => {
            DataType => 'NUMERIC',
            Required => 1
        },
    }
}

=item Run()

perform TicketDelete Operation. This will return the deleted TicketID. The ticket will just be set to "removed" state.

    my $Result = $OperationObject->Run(
        Data => {
            TicketID          => 123,                                           # required
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        ErrorMessage    => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            TicketID    => 123,                     # ID of changed ticket
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $TicketObject = $Kernel::OM->Get('Ticket');

    # unlock the ticket
    $TicketObject->TicketLockSet(
        TicketID => $Param{Data}->{TicketID},
        Lock     => 'unlock',
        UserID   => $Self->{Authorization}->{UserID},
    );

    # don't delete the ticket, just set the removed state
    my $Success = $TicketObject->TicketStateSet(
        State    => 'removed',
        TicketID => $Param{Data}->{TicketID},
        UserID   => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToDelete',
            Message => 'Unable to set ticket to removed state, please contact system administrator!',
        );
    }

    return $Self->_Success();
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
