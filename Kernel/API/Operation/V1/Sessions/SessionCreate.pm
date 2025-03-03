# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Sessions::SessionCreate;
use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsStringWithData IsHashRefWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Sessions::SessionCreate - API Login Operation backend

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

    my $PreAuthTypes = [];
    my $MFAuthTypes  = [];
    if ( $Param{Data}->{UserType} ) {
        $PreAuthTypes = $Kernel::OM->Get('Auth')->GetPreAuthTypes(
            UsageContext => $Param{Data}->{UserType}
        );
        $MFAuthTypes  = $Kernel::OM->Get('Auth')->GetMFAuthTypes(
            UsageContext => $Param{Data}->{UserType}
        );
    }

    return {
        'UserLogin' => {
            RequiredIfNot => ['PreAuthRequest','NegotiateToken','state']
        },
        'UserType' => {
            Required => 1,
            OneOf    => [
                'Agent',
                'Customer'
            ]
        },
        'Password' => {
            RequiredIf => ['UserLogin']
        },
        'MFAToken' => {
            Type => 'HASH'
        },
        'MFAToken::Type' => {
            RequiredIf => ['MFAToken'],
            OneOf      => $MFAuthTypes
        },
        'MFAToken::Value' => {
            RequiredIf => ['MFAToken'],
        },
        'code' => {
            RequiredIf => ['state']
        },
        'csrfCookie' => {
            RequiredIf => ['state']
        },
        'PreAuthRequest' => {
            Type => 'HASH'
        },
        'PreAuthRequest::Type' => {
            RequiredIf => ['PreAuthRequest'],
            OneOf      => $PreAuthTypes
        },
        'PreAuthRequest::Data' => {
            RequiredIf => ['PreAuthRequest'],
            Type       => 'HASH'
        }
    }
}

=item Run()

Authenticate user.

    my $Result = $OperationObject->Run(
        Data => {
            UserLogin            => 'Login',             # required
            Password             => 'some password',     # required, plain text password
            UserType             => 'Agent'|'Customer'   # required
        },
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Message => '',                               # In case of an error
        Data         => {
            Token => '...,
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # get remote addresses
    my $CGIObject       = CGI->new;
    my @RemoteAddresses = ();
    if ( $CGIObject->http('HTTP_X_FORWARDED_FOR') ) {
        @RemoteAddresses = split(/",\s{0,1}"/, $CGIObject->http('HTTP_X_FORWARDED_FOR'));
    }

    # special handling for PreAuthRequest
    if ( ref( $Param{Data}->{PreAuthRequest} ) eq 'HASH' ) {
        my $PreAuthData = $Kernel::OM->Get('Auth')->PreAuth(
            %{ $Param{Data}->{PreAuthRequest} },
            UsageContext    => $Param{Data}->{UserType},
            RemoteAddresses => \@RemoteAddresses
        );

        if ( !defined( $PreAuthData ) ) {
            return $Self->_Error(
                Code => 'SessionCreate.PreAuthFail'
            );
        }

        return $Self->_Success(
            Code => 'Object.Created',
            Data => $PreAuthData,
        );
    }

    # auth with submitted data
    my $User = $Kernel::OM->Get('Auth')->Auth(
        User            => $Param{Data}->{UserLogin} || '',
        UsageContext    => $Param{Data}->{UserType},
        Pw              => $Param{Data}->{Password} || '',
        MFAToken        => $Param{Data}->{MFAToken} || {},
        NegotiateToken  => $Param{Data}->{NegotiateToken},
        Code            => $Param{Data}->{code},
        State           => $Param{Data}->{state},
        CSRFToken       => $Param{Data}->{csrfCookie},
        RemoteAddresses => \@RemoteAddresses
    );
    if ( $User ) {
        my $UserID = $Kernel::OM->Get('User')->UserLookup(
            UserLogin => $User,
        );

        # check permission - this is something special since this operation is not protected by the framework because the UserID will just be determined here
        my $HasPermission = $Kernel::OM->Get('User')->CheckResourcePermission(
            UserID              => $UserID,
            UsageContext        => $Param{Data}->{UserType},
            Target              => '/auth',
            RequestedPermission => 'CREATE'
        );
        if ( !$HasPermission ) {
            return $Self->_Error(
                Code => 'Forbidden'
            );
        }

        # create new token
        my $Token = $Kernel::OM->Get('Token')->CreateToken(
            Payload => {
                UserID      => $UserID,
                UserType    => $Param{Data}->{UserType},
            }
        );
        if ( $Token ) {
            return $Self->_Success(
                Code  => 'Object.Created',
                Token => $Token,
            );
        }
    }

    # not authenticated
    return $Self->_Error(
        Code => 'SessionCreate.AuthFail'
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
