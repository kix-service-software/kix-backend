# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
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

    return {
        'UserLogin' => {
            RequiredIfNot => ['NegotiateToken']
        },
        'UserType' => {
            Required => 1,
            OneOf => [
                'Agent',
                'Customer'
            ]
        },
        'Password' => {
            RequiredIfNot => ['NegotiateToken']
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

    my $UserID;
    my $User;

    # get params
    my $PostPw = $Param{Data}->{Password} || '';

    if ( defined $Param{Data}->{UserType} ) {
        # check submitted data
        $User = $Kernel::OM->Get('Auth')->Auth(
            User           => $Param{Data}->{UserLogin} || '',
            UsageContext   => $Param{Data}->{UserType},
            Pw             => $PostPw,
            NegotiateToken => $Param{Data}->{NegotiateToken},
        );
        if ( $User ) {
            $UserID = $Kernel::OM->Get('User')->UserLookup(
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
        }
    }

    # not authenticated
    if ( !$User ) {

        return $Self->_Error(
            Code => 'SessionCreate.AuthFail'
        );
    }

    # create new token
    my $Token = $Kernel::OM->Get('Token')->CreateToken(
        Payload => {
            UserID      => $UserID,
            UserType    => $Param{Data}->{UserType},
        }
    );

    if ( !$Token ) {

        return $Self->_Error(
            Code => 'SessionCreate.AuthFail'
        );
    }

    return $Self->_Success(
        Code  => 'Object.Created',
        Token => $Token,
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
