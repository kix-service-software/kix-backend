# --
# Kernel/API/Operation/ClientRegistration/ClientRegistrationCreate.pm - API ClientRegistration Create operation backend
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::ClientRegistration::ClientRegistrationCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::ClientRegistration::ClientRegistrationCreate - API ClientRegistration Create Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation->new();

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

=item Run()

perform ClientRegistrationCreate Operation. This will return the created ClientRegistrationID.

    my $Result = $OperationObject->Run(
        Data => {
        	ClientRegistration => {
                ClientID       => '...',
                CallbackURL    => '...',
                Authentication => '...'     # optional
            }
	    },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      # 
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            ClientID  => '',                        # ID of the created ClientRegistration
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # init webservice
    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    # trim 
    if ( !$Result->{Success} ) {
        $Self->_Error(
            Code    => 'Webservice.InvalidConfiguration',
            Message => $Result->{Message},
        );
    }

    # prepare data
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
        Parameters => {
            'ClientRegistration' => {
                Type => 'HASH',
                Required => 1
            },
            'ClientRegistration::ClientID' => {
                Required => 1
            },
            'ClientRegistration::CallbackURL' => {
                Required => 1
            },
        }
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }

     # isolate and trim ClientRegistration parameter
    my $ClientRegistration = $Self->_Trim(
        Data => $Param{Data}->{ClientRegistration},
    );        
   
    # check if ClientRegistration exists
    my %ClientRegistration = $Kernel::OM->Get('Kernel::System::ClientRegistration')->ClientRegistrationGet(
        ClientID => $ClientRegistration->{ClientID},
    );

    if ( IsHashRefWithData(\%ClientRegistration) ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Can not create client registration. A registration for the given ClientID already exists.",
        );
    }

    # create ClientRegistration
    my $ClientRegistrationID = $Kernel::OM->Get('Kernel::System::ClientRegistration')->ClientRegistrationAdd(
        ClientID       => $ClientRegistration->{ClientID},
        CallbackURL    => $ClientRegistration->{CallbackURL},
        Authentication => $ClientRegistration->{Authentication},
    );

    if ( !$ClientRegistrationID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create client registration, please contact the system administrator',
        );
    }
    
    # return result    
    return $Self->_Success(
        Code   => 'Object.Created',
        ClientRegistrationID => $ClientRegistrationID,
    );    
}

1;
