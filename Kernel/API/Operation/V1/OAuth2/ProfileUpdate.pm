# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::OAuth2::ProfileUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::OAuth2::ProfileUpdate - API OAuth2 Profile Update Operation backend

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
            Required => 1
        },
        'Profile' => {
            Type     => 'HASH',
            Required => 1
        },
        'Profile::Name' => {
            RequiresValueIfUsed => 1
        },
        'Profile::URLAuth' => {
            RequiresValueIfUsed => 1
        },
        'Profile::URLToken' => {
            RequiresValueIfUsed => 1
        },
        'Profile::URLRedirect' => {
            RequiresValueIfUsed => 1
        },
        'Profile::ClientID' => {
            RequiresValueIfUsed => 1
        },
        'Profile::ClientSecret' => {
            RequiresValueIfUsed => 1
        },
        'Profile::Scope' => {
            RequiresValueIfUsed => 1
        },
        'Profile::PKCE' => {
            DataType            => 'NUMERIC',
            RequiresValueIfUsed => 1
        },
    }
}

=item Run()

perform OAuth2 ProfileUpdate Operation. This will return the updated ProfileID.

    my $Result = $OperationObject->Run(
        Data => {
            ProfileID => 123,
            Profile   => {
                Name              => 'Profile',       # optional
                URLAuth           => 'https://...',   # optional
                URLToken          => 'https://...',   # optional
                URLRedirect       => 'https://...',   # optional
                ClientID          => 'ClientID',      # optional
                ClientSecret      => 'ClientSecret',  # optional
                Scope             => 'Scope'          # optional
                PKCE              => 1,               # optional
                ValidID           => 1,               # optional
            },
        },
    );

    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            ProfileID  => 123,                  # ID of the updated Profile
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim MailAccount parameter
    my $Profile = $Self->_Trim(
        Data => $Param{Data}->{Profile}
    );

    # check if Profile exists
    my %ProfileData = $Kernel::OM->Get('OAuth2')->ProfileGet(
        ID     => $Param{Data}->{ProfileID},
        UserID => $Self->{Authorization}->{UserID},
    );

    if ( !%ProfileData ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # update Profile
    my $Success = $Kernel::OM->Get('OAuth2')->ProfileUpdate(
        ID           => $Param{Data}->{ProfileID},
        Name         => $Profile->{Name}         || $ProfileData{Name},
        URLAuth      => $Profile->{URLAuth}      || $ProfileData{URLAuth},
        URLToken     => $Profile->{URLToken}     || $ProfileData{URLToken},
        URLRedirect  => $Profile->{URLRedirect}  || $ProfileData{URLRedirect},
        ClientID     => $Profile->{ClientID}     || $ProfileData{ClientID},
        ClientSecret => $Profile->{ClientSecret} || $ProfileData{ClientSecret},
        Scope        => $Profile->{Scope}        || $ProfileData{Scope},
        PKCE         => $Profile->{PKCE}         // $ProfileData{PKCE},
        ValidID      => $Profile->{ValidID}      || $ProfileData{ValidID},
        UserID       => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        my $LogMessage = $Kernel::OM->Get('Log')->GetLogEntry(
            Type => 'error',
            What => 'Message',
        );
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update OAuth2 Profile (error: $LogMessage).',
        );
    }

    # return result
    return $Self->_Success(
        ProfileID => $Param{Data}->{ProfileID},
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
