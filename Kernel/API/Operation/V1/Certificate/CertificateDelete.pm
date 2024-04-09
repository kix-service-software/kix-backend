# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Certificate::CertificateDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Certificate::CertificateDelete - API Certificate Delete Operation backend

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
        'Fingerprint' => {
            Type     => 'ARRAY',
            Required => 1
        },
    }
}

=item Run()

perform CertificateDelete Operation. This will return the deleted Filename.

    my $Result = $OperationObject->Run(
        Data => {
            Filename  => '...',
        },
    );

    $Result = {
        Message    => '',                      # in case of error
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # start loop
    foreach my $Filename ( @{$Param{Data}->{Filename}} ) {

        # delete Certificate
        my $Success = $Kernel::OM->Get('Certificate')->CertificateDelete(
            Filename  => $Filename,
        );

        if ( !$Success ) {
            return $Self->_Error(
                Code    => 'Object.UnableToDelete',
                Message => 'Could not delete Certificate, please contact the system administrator',
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
