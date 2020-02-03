# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
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

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1::Sessions::SessionCreate->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw( DebuggerObject WebserviceID )) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    return $Self;
}

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
            Required => 1
        },
        'UserType' => {
            Required => 1,
            OneOf => [
                'Agent',
                'Customer'
            ]
        },
        'Password' => {
            Required => 1
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

    if ( defined $Param{Data}->{UserType} && $Param{Data}->{UserType} eq 'Agent' ) {
        # check submitted data
        $User = $Kernel::OM->Get('Kernel::System::Auth')->Auth(
            User => $Param{Data}->{UserLogin} || '',
            Pw   => $PostPw,
        );
        if ( $User ) {
            $UserID = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
                UserLogin => $Param{Data}->{UserLogin},
            );
            # check permission - this is something special since this operation is not protected by the framework because the UserID will just be determined here
            my $HasPermission = $Kernel::OM->Get('Kernel::System::User')->CheckResourcePermission(
                UserID              => $UserID,
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
    elsif ( defined $Param{Data}->{UserType} && $Param{Data}->{UserType} eq 'Customer' ) {
        # check submitted data
        $User = $Kernel::OM->Get('Kernel::System::ContactAuth')->Auth(
            User => $Param{Data}->{UserLogin} || '',
            Pw   => $PostPw,
        );
        if ( $User ) {
            $UserID = $Param{Data}->{UserLogin};
            # check permission - this is something special since this operation is not protected by the framework because the UserID will just be determined here
            my $HasPermission = $Kernel::OM->Get('Kernel::System::Contact')->CheckResourcePermission(
                UserID              => $UserID,
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
    my $Token = $Kernel::OM->Get('Kernel::System::Token')->CreateToken(
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
