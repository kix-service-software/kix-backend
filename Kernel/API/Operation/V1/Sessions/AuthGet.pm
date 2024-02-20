# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Sessions::AuthGet;
use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsStringWithData IsHashRefWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Sessions::AuthGet - API Login Operation backend

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

    my $PreAuthTypes = $Kernel::OM->Get('Auth')->GetPreAuthTypes();

    return {
        'code' => {
            RequiredIf => ['state']
        },
        'UserType' => {
            RequiredIfNot => ['state'],
            OneOf         => [
                'Agent',
                'Customer'
            ]
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

    # handling for openid redirect
    if ( $Param{Data}->{code} ) {
        # get state data
        my $StateData = $Kernel::OM->Get('OAuth2')->StateGet(
            State => $Param{Data}->{state}
        );
        if (
            ref( $StateData ) ne 'HASH'
            || !$StateData->{UsageContext}
        ) {
            return $Self->_Error(
                Code => 'Forbidden'
            );
        }

        # get remote addresses
        my $CGIObject       = CGI->new;
        my @RemoteAddresses = ();
        if ( $CGIObject->http('HTTP_X_FORWARDED_FOR') ) {
            @RemoteAddresses = split(/",\s{0,1}"/, $CGIObject->http('HTTP_X_FORWARDED_FOR'));
        }

        # auth with submitted data
        my $User = $Kernel::OM->Get('Auth')->Auth(
            UsageContext    => $StateData->{UsageContext},
            Code            => $Param{Data}->{code},
            State           => $Param{Data}->{state},
            RemoteAddresses => \@RemoteAddresses
        );
        if ( $User ) {
            my $UserID = $Kernel::OM->Get('User')->UserLookup(
                UserLogin => $User,
            );

            # check permission - this is something special since this operation is not protected by the framework because the UserID will just be determined here
            my $HasPermission = $Kernel::OM->Get('User')->CheckResourcePermission(
                UserID              => $UserID,
                UsageContext        => $StateData->{UsageContext},
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
                    UserType    => $StateData->{UsageContext},
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

    # get possible auth methods
    my $AuthMethods = $Kernel::OM->Get('Auth')->GetAuthMethods(
        UsageContext => $Param{Data}->{UserType}
    );

    # return auth methods
    return $Self->_Success(
        AuthMethods => $AuthMethods,
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
