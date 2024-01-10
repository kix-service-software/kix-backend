# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Priority::PriorityDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Priority::PriorityDelete - API Priority PriorityDelete Operation backend

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
        'PriorityID' => {
            DataType => 'NUMERIC',
            Type     => 'ARRAY',
            Required => 1
        }
    }
}

=item Run()

perform PriorityDelete Operation. This will return the deleted PriorityID.

    my $Result = $OperationObject->Run(
        Data => {
            PriorityID  => '...',
        },
    );

    $Result = {
        Success    => 1,
        Code       => '',                       # in case of error
        Message    => '',                       # in case of error
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # start loop
    foreach my $PriorityID ( @{$Param{Data}->{PriorityID}} ) {

        # search ticket
        my $ResultTicketSearch = $Kernel::OM->Get('ObjectSearch')->Search(
            ObjectType   => 'Ticket',
            Result       => 'COUNT',
            Limit        => 1,
            Search       => {
                AND => [
                    {
                        Field => 'PriorityID',
                        Value => $PriorityID,
                        Operator => 'EQ',
                    },
                ]
            },
            UserID   => 1,
            UserType => 'Agent',
        );

        if ( $ResultTicketSearch ) {
            return $Self->_Error(
                Code    => 'Object.DependingObjectExists',
                Message => 'Cannot delete priority. A ticket with this priority already exists.',
            );
        }

        # delete Priority
        my $Success = $Kernel::OM->Get('Priority')->PriorityDelete(
            PriorityID  => $PriorityID,
            UserID  => $Self->{Authorization}->{UserID},
        );

        if ( !$Success ) {
            return $Self->_Error(
                Code    => 'Object.UnableToDelete',
                Message => 'Could not delete Priority, please contact the system administrator',
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
