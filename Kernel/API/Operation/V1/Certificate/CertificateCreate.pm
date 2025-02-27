# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
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
        'Certificate' => {
            Type     => 'HASH',
            Required => 1
        },
        'Certificate::File' => {
            Type     => 'HASH',
            Required => 1
        },
        'Certificate::File::ContentType' => {
            Required => 1
        },
        'Certificate::File::Content' => {
            Required => 1
        },
        'Certificate::File::Filename' => {
            Required => 1
        },
        'Certificate::File::Filesize' => {},
        'Certificate::Type' => {
            Required => 1,
            OneOf    => [
                'Private',
                'Cert'
            ]
        },
        'Certificate::Passphrase' => {},
        'Certificate::CType'      => {}
    };
}

=item Run()

perform CertificateCreate Operation. This will return the created CertificateID.

    my $Result = $OperationObject->Run(
        Data => {
            File => {
                Filename    => '...',
                ContentType => '...',
                Content     => '...',
                Filesize    => '...'
            },
            Passphrase  => '...',
            Type        => '...'
            CType       => '...'
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            CertificateID  => '',                   # ID of the created Certificate
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Certificate parameter
    my $Certificate = $Self->_Trim(
        Data => $Param{Data}->{Certificate}
    );

    # create Certificate
    my $CertificateID = $Kernel::OM->Get('Certificate')->CertificateCreate(
        %{$Certificate},
        CType  => $Certificate->{CType} || 'SMIME',
        UserID => $Self->{Authorization}->{UserID},
    );

    if ( !$CertificateID ) {
        my $LogMessage = $Kernel::OM->Get('Log')->GetLogEntry(
            Type => 'error',
            What => 'Message'
        );
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => "Could not create Certificate! ( Error: $LogMessage )"
        );
    }

    # return result
    return $Self->_Success(
        Code        => 'Object.Created',
        CertificateID => $CertificateID,
    );
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
