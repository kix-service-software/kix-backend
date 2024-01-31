# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::OAuth2::ProfileDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::OAuth2::Delete - API OAuth2 Profile Delete Operation backend

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
        'ProfileID' => {
            DataType => 'NUMERIC',
            Type     => 'ARRAY',
            Required => 1
        },
    }
}

=item Run()

perform OAuth2 ProfileDelete Operation. Returns no content on success

    my $Result = $OperationObject->Run(
        Data => {
            ProfileID => [
                123,
            ]
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # start loop
    foreach my $ProfileID ( @{$Param{Data}->{ProfileID}} ) {

        # delete Profile
        my $Success = $Kernel::OM->Get('OAuth2')->ProfileDelete(
            ID     => $ProfileID,
            UserID => $Self->{Authorization}->{UserID},
        );

        if ( !$Success ) {
            my $LogMessage = $Kernel::OM->Get('Log')->GetLogEntry(
                Type => 'error',
                What => 'Message',
            );
            return $Self->_Error(
                Code    => 'Object.UnableToDelete',
                Message => 'Could not delete OAuth2 Profile (error: $LogMessage).',
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
