# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Certificate::CertificateGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Certificate::CertificateGet - API Certificate Get Operation backend

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
        'CertificateID' => {
            Type     => 'ARRAY',
            DataType => 'NUMBER',
            Required => 1
        }
    }
}

=item Run()

perform CertificateGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            CertificateID => 1       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            Certificate => [
                {
                    ...
                },
                {
                    ...
                },
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @CertificateList;

    my $Include;
    if ( $Param{Data}->{include}->{Content} ) {
        $Include = 'Content';
    }
    # start loop
    foreach my $ID ( @{$Param{Data}->{CertificateID}} ) {

        # get the Certificate data
        my $CertificateData = $Kernel::OM->Get('Certificate')->CertificateGet(
            ID      => $ID,
            Include => $Include
        );

        if ( !IsHashRefWithData($CertificateData) ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # add
        push(@CertificateList, $CertificateData);
    }

    if ( scalar(@CertificateList) == 1 ) {
        return $Self->_Success(
            Certificate => $CertificateList[0],
        );
    }

    # return result
    return $Self->_Success(
        Certificate => \@CertificateList,
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
