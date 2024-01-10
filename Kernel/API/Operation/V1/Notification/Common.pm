# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Notification::Common;

use strict;
use warnings;

use MIME::Base64();

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Notification::Common - Base class for all Notification Operations

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=begin Internal:

=item _CheckNotification()

checks if the given Notification parameter is valid.

    my $Result = $OperationObject->_CheckNotification(
        Notification => $Notification,
    );

    returns:

    $Result = {
        Success => 1,                               # if everything is OK
    }

    $Result = {
        Code    => 'Function.Error',           # if error
        Message => 'Error description',
    }

=cut

sub _CheckNotification {
    my ( $Self, %Param ) = @_;

    my $Notification = $Param{Notification};

    if ( exists $Notification->{Data} && IsHashRefWithData($Notification->{Data}) ) {
        # validate Data attribute
        foreach my $Key ( sort keys %{ $Notification->{Data} } ) {

            # error if message data is incomplete
            if ( !IsArrayRefWithData($Notification->{Data}->{$Key}) ) {
                return $Self->_Error(
                    Code    => 'BadRequest',
                    Message => "Parameter $Key is invalid!"
                );
            }
        }
    }

    if ( exists $Notification->{Message} && IsHashRefWithData($Notification->{Message}) ) {
        # validate Message attribute
        foreach my $Language ( sort keys %{ $Notification->{Message} } ) {

            # error if Language is not a valid hash
            if ( !IsHashRefWithData($Notification->{Message}->{$Language}) ) {
                return $Self->_Error(
                    Code    => 'BadRequest',
                    Message => "Parameter Message::$Language is invalid!"
                );
            }

            foreach my $Parameter (qw(Subject Body ContentType)) {
                # error if message data is incomplete
                if ( !$Notification->{Message}->{$Language}->{$Parameter} ) {
                    return $Self->_Error(
                        Code    => 'BadRequest',
                        Message => "Required parameter Message::$Language::$Parameter is missing or undefined!"
                    );
                }
            }
        }
    }

    # if everything is OK then return Success
    return $Self->_Success();
}

1;

=end Internal:





=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
