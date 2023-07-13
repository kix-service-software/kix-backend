# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::TicketState::TicketStateDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::TicketState::TickeStateDelete - GenericInterface TicketState TicketStateDelete Operation backend

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
        'StateID' => {
            DataType => 'NUMERIC',
            Type     => 'ARRAY',
            Required => 1
        },
    }
}

=item Run()

perform TicketStateDelete Operation. This will return the delete StateID.

    my $Result = $OperationObject->Run(
        Data => {
            StateID      => '...',
        }
    );

    $Result = {
        Message    => '',                      # in case of error
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # start loop
    foreach my $TicketStateID ( @{$Param{Data}->{StateID}} ) {

        my $ResultTicketSearch = $Kernel::OM->Get('Ticket')->TicketSearch(
            Result       => 'COUNT',
            Limit        => 1,
            Search       => {
                AND => [
                    {
                        Field => 'TicketStateID',
                        Value => $TicketStateID,
                        Operator => 'EQ',
                    },
                ]
            },
            UserID       => 1,
            Permission   => 'ro',
        );

        if ( $ResultTicketSearch ) {
            return $Self->_Error(
                Code    => 'Object.DependingObjectExists',
                Message => 'Cannot delete state. A ticket with this state already exists.',
            );
        }

        # delete ticketstate
        my $Success = $Kernel::OM->Get('State')->StateDelete(
            StateID  => $TicketStateID,
            UserID  => $Self->{Authorization}->{UserID},
        );

        if ( !$Success ) {
            return $Self->_Error(
                Code    => 'Object.UnableToDelete',
                Message => 'Could not delete state, please contact the system administrator',
            );
        }
    }

    # return result
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
