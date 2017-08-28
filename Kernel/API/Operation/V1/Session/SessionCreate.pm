# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Session::SessionCreate;
use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsStringWithData IsHashRefWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Session::SessionCreate - API Login Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1::Session::SessionCreate->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!",
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    return $Self;
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
        ErrorMessage => '',                               # In case of an error
        Data         => {
            Token => '..., 
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # init webservice
    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        $Self->ReturnError(
            ErrorCode    => 'Webservice.InvalidConfiguration',
            ErrorMessage => $Result->{ErrorMessage},
        );
    }

    # prepare data
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
        Parameters => {
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
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->ReturnError(
            ErrorCode    => 'SessionCreate.PrepareDataError',
            ErrorMessage => $Result->{ErrorMessage},
        );
    }

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
        }
    }
    elsif ( defined $Param{Data}->{UserType} && $Param{Data}->{UserType} eq 'Customer' ) {
        # check submitted data
        $User = $Kernel::OM->Get('Kernel::System::CustomerAuth')->Auth(
            User => $Param{Data}->{UserLogin} || '',
            Pw   => $PostPw,
        );
        if ( $User ) {
            $UserID = $Param{Data}->{UserLogin};
        }        
    }

    # not authenticated
    if ( !$User ) {

        return $Self->ReturnError(
            ErrorCode    => 'SessionCreate.AuthFail',
            ErrorMessage => "SessionCreate: Authorization failing!",
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

        return $Self->ReturnError(
            ErrorCode    => 'SessionCreate.AuthFail',
            ErrorMessage => "SessionCreate: Authorization failing!",
        );
    }

    return $Self->ReturnSuccess(
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