# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::OAuth2::AuthCodeProcess;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::OAuth2::AuthCodeProcess - API OAuth2 AuthCode Process Operation backend

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
        'ProfileAuth' => {
            Type     => 'HASH',
            Required => 1
        },
        'ProfileAuth::Code' => {
            Required => 1
        },
        'ProfileAuth::State' => {
            Required => 1
        }
    }
}

=item Run()

perform OAuth2 AuthCodeProcess Operation. This will return the ProfileID.

    my $Result = $OperationObject->Run(
        Data => {
            ProfileAuth => {
                Code  => 'Code',
                State => 'State'
            }
        },
    );

    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            ProfileID  => 123                   # ID of the Profile
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my ( $ProfileID ) = $Kernel::OM->Get('OAuth2')->ProcessAuthCode(
        AuthCode => $Param{Data}->{ProfileAuth}->{Code},
        State    => $Param{Data}->{ProfileAuth}->{State}
    );

    if ( !$ProfileID ) {
        my $LogMessage = $Kernel::OM->Get('Log')->GetLogEntry(
            Type => 'error',
            What => 'Message',
        );
        return $Self->_Error(
            Code    => 'Object.ExecFailed',
            Message => "An error occured while requesting initial access token (error: $LogMessage).",
        );
    }

    # return result
    return $Self->_Success(
        ProfileID => $ProfileID,
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
