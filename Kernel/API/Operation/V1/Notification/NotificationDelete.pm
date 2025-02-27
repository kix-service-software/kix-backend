# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Notification::NotificationDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::API::Operation::V1::Common);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Notification::NotificationDelete - API Notification Delete Operation backend

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
        'NotificationID' => {
            DataType => 'NUMERIC',
            Type     => 'ARRAY',
            Required => 1
        },
    };
}

=item Run()

perform NotificationDelete Operation. This will return the deleted NotificationID.

    my $Result = $OperationObject->Run(
        Data => {
            NotificationID => 1,
        },
    );

    $Result = {
        Message => '',                      # in case of error
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # start loop
    foreach my $NotificationID ( @{ $Param{Data}->{NotificationID} } ) {

        # check if Notification exists
        my %NotificationData = $Kernel::OM->Get('NotificationEvent')->NotificationGet(
            ID => $NotificationID,
        );
        if ( !IsHashRefWithData(\%NotificationData) ) {
            return $Self->_Error(
                Code    => 'Object.NotFound',
            );
        }

        # delete Notification
        my $Success = $Kernel::OM->Get('NotificationEvent')->NotificationDelete(
            ID     => $NotificationID,
            UserID => $Self->{Authorization}->{UserID}
        );

        if ( !$Success ) {
            return $Self->_Error(
                Code    => 'Object.UnableToDelete',
                Message => 'Could not delete Notification, please contact the system administrator',
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
