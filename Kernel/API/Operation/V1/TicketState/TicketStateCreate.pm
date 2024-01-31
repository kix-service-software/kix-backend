# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::TicketState::TicketStateCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::TicketState::TicketStateCreate - API TicketState TicketStateCreate Operation backend

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
        'TicketState' => {
            Type     => 'HASH',
            Required => 1
        },
        'TicketState::Name' => {
            Required => 1
        },
        'TicketState::TypeID' => {
            Required => 1
        },
    }
}

=item Run()

perform TicketStateCreate Operation. This will return the created TicketStateID.

    my $Result = $OperationObject->Run(
        Data => {
            TicketState => (
                Name    => '...',
                ValidID => '...',
            },
    	},
    );

    $Result = {
        Success      => 1,                       # 0 or 1
        Code         => '',                      #
        Message      => '',                      # in case of error
        Data         => {                        # result data payload after Operation
            StateID  => '',                      # StateID
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim TicketState parameter
    my $TicketState = $Self->_Trim(
        Data => $Param{Data}->{TicketState},
    );

    # check if ticketState exists
    my $Exists = $Kernel::OM->Get('State')->StateLookup(
        State  => $TicketState->{Name},
        Silent => 1
    );

    if ( $Exists ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Cannot create TicketState. TicketState already exists.",
        );
    }

    # create ticketstate
    my $TicketStateID = $Kernel::OM->Get('State')->StateAdd(
        %{$TicketState},
        ValidID => $TicketState->{ValidID} || 1,
        UserID  => $Self->{Authorization}->{UserID},
    );

    if ( !$TicketStateID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create state, please contact the system administrator',
        );
    }

    # return result
    return $Self->_Success(
        Code   => 'Object.Created',
        TicketStateID => $TicketStateID,
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
