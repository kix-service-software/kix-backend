# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Certificate::CertificateCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Certificate::CertificateCreate - API Certificate CertificateCreate Operation backend

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
        'Filename' => {
            Required => 1
        },
        'ContentType' => {
            Required => 1
        },
        'Content' => {
            Required => 1
        },
        'Type' => {
            Required => 1
        },
        'Passphrase' => {}
    };
}

=item Run()

perform CertificateCreate Operation. This will return the created CertificateID.

    my $Result = $OperationObject->Run(
        Data => {
            Filename    => '...',
            ContentType => '...',
            Content     => '...',
            Passphrase  => '...',
            Type        => '...'
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            Fingerprint  => '',                      # boolean of the created Certificate
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Certificate parameter
    my $Certificate = $Self->_Trim(
        Data => $Param{Data}
    );

    # check attribute values
    my $CheckResult = $Self->_CheckCertificate(
        Certificate => $Certificate
    );

    if ( !$CheckResult->{Success} ) {
        return $Self->_Error(
            %{$CheckResult},
        );
    }

    # check if Certificate exists
    my $CertificateList = $Kernel::OM->Get('Certificate')->CertificateSearch(
        %{$Certificate},
        UserID => $Self->{Authorization}->{UserID},
    );

    if ( IsArrayRefWithData($CertificateList) ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Cannot create Certificate. A Certificate with these parameters already exists.",
        );
    }

    # create Certificate
    my $Fingerprint = $Kernel::OM->Get('Certificate')->CertificateCreate(
        %{$Certificate},
        UserID  => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create Certificate, please contact the system administrator',
        );
    }

    # return result
    return $Self->_Success(
        Code       => 'Object.Created',
        Fingerprint => $Fingerprint,
    );
}


sub _CheckCertificate {
    my ( $Self, %Param ) = @_;




    return 1;
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
