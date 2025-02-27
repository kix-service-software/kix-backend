# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Queue::QueueDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Queue::QueueDelete - API Queue QueueDelete Operation backend

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
        'QueueID' => {
            DataType => 'NUMERIC',
            Type     => 'ARRAY',
            Required => 1
        },
    }
}

=item Run()

perform QueueDelete Operation. This will return the deleted QueueID.

    my $Result = $OperationObject->Run(
        Data => {
            QueueID  => '...',
        },
    );

    $Result = {
        Message    => '',                      # in case of error
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # start loop
    foreach my $QueueID ( @{$Param{Data}->{QueueID}} ) {

        my $ResultTicketSearch = $Kernel::OM->Get('ObjectSearch')->Search(
            ObjectType   => 'Ticket',
            Result       => 'COUNT',
            Limit        => 1,
            Search       => {
                AND => [
                    {
                        Field => 'QueueID',
                        Value => $QueueID,
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
                Message => 'Cannot delete queue. A ticket with this queue already exists.',
            );
        }

        # get all roles assigned to this queue
        my @Permissions = $Kernel::OM->Get('Role')->PermissionList(
            Types  => ['Base::Ticket'],
            Target => $QueueID,
        );
        if ( IsArrayRefWithData(\@Permissions) ) {
            return $Self->_Error(
                Code    => 'Object.DependingObjectExists',
                Message => 'Cannot delete queue. At least one permission is assigned to this queue.',
            );
        }

        # delete Queue
        my $Success = $Kernel::OM->Get('Queue')->QueueDelete(
            QueueID  => $QueueID,
            UserID  => $Self->{Authorization}->{UserID},
        );

        if ( !$Success ) {
            return $Self->_Error(
                Code    => 'Object.UnableToDelete',
                Message => 'Could not delete queue, please contact the system administrator',
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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
