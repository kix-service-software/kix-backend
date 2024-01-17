# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::OAuth2::ProfileCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::OAuth2::ProfileCreate - API OAuth2 Profile Create Operation backend

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
        'Profile' => {
            Type     => 'HASH',
            Required => 1
        },
        'Profile::Name' => {
            Required => 1
        },
        'Profile::URLAuth' => {
            Required => 1
        },
        'Profile::URLToken' => {
            Required => 1
        },
        'Profile::URLRedirect' => {
            Required => 1
        },
        'Profile::ClientID' => {
            Required => 1
        },
        'Profile::ClientSecret' => {
            Required => 1
        },
        'Profile::Scope' => {
            Required => 1
        },
    }
}

=item Run()

perform OAuth2 ProfileCreate Operation. This will return the created ProfileID.

    my $Result = $OperationObject->Run(
        Data => {
            Profile  => {
                Name         => 'Profile',
                URLAuth      => 'https://...',
                URLToken     => 'https://...',
                URLRedirect  => 'https://...',
                ClientID     => 'ClientID',
                ClientSecret => 'ClientSecret',
                Scope        => 'Scope'
                ValidID      => 1,
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            ProfileID => '',                        # ID of the created Profile
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Profile parameter
    my $Profile = $Self->_Trim(
        Data => $Param{Data}->{Profile}
    );

    # check if oauth2 profile exists
    my $Exists = $Kernel::OM->Get('OAuth2')->ProfileLookup(
        Name => $Profile->{Name},
    );

    if ( $Exists ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Cannot create OAuth2 Profile. Profile already exists.",
        );
    }

    # create Profile
    my $ProfileID = $Kernel::OM->Get('OAuth2')->ProfileAdd(
        Name         => $Profile->{Name},
        URLAuth      => $Profile->{URLAuth},
        URLToken     => $Profile->{URLToken},
        URLRedirect  => $Profile->{URLRedirect},
        ClientID     => $Profile->{ClientID},
        ClientSecret => $Profile->{ClientSecret},
        Scope        => $Profile->{Scope},
        ValidID      => $Profile->{ValidID} || 1,
        UserID       => $Self->{Authorization}->{UserID},
    );

    if ( !$ProfileID ) {
        my $LogMessage = $Kernel::OM->Get('Log')->GetLogEntry(
            Type => 'error',
            What => 'Message',
        );
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create OAuth2 Profile (error: $LogMessage).',
        );
    }

    # return result
    return $Self->_Success(
        Code      => 'Object.Created',
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
