# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
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
            my $HasPermission = $Kernel::OM->Get('Kernel::System::User')->CheckPermission(
                UserID            => $UserID,
                Target            => '/sessions',
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
            my $HasPermission = $Kernel::OM->Get('Kernel::System::Contact')->CheckPermission(
                UserID            => $UserID,
                Target            => '/sessions',
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
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
