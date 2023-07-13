# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::TicketType::TicketTypeDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::TicketType::TicketypeDelete - API TicketType TicketTypeDelete Operation backend

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
        'TypeID' => {
            DataType => 'NUMERIC',
            Type     => 'ARRAY',
            Required => 1
        },
    }
}

=item Run()

perform TicketTypeDelete Operation. This will return the deleted TypeID.

    my $Result = $OperationObject->Run(
        Data => {
            TypeID  => '...',
        },
    );

    $Result = {
        Message    => '',                      # in case of error
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # start loop
    foreach my $TypeID ( @{$Param{Data}->{TypeID}} ) {

        # search ticket
        my $ResultTicketSearch = $Kernel::OM->Get('Ticket')->TicketSearch(
            Result       => 'COUNT',
            Limit        => 1,
            Search       => {
                AND => [
                    {
                        Field => 'TypeID',
                        Value => $TypeID,
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
                Message => 'Cannot delete type. A ticket with this type already exists.',
            );
        }

        # delete tickettype
        my $Success = $Kernel::OM->Get('Type')->TypeDelete(
            TypeID  => $TypeID,
            UserID  => $Self->{Authorization}->{UserID},
        );

        if ( !$Success ) {
            return $Self->_Error(
                Code    => 'Object.UnableToDelete',
                Message => 'Could not delete type, please contact the system administrator',
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
