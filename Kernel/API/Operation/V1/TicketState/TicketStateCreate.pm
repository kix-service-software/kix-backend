# --
# Kernel/API/Operation/TicketState/TicketStateCreate.pm - API TicketState Create operation backend
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

package Kernel::API::Operation::V1::TicketState::TicketStateCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::TicketState::TicketStateCreate - API TicketState TicketStateCreate Operation backend

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

perform TicketStateCreate Operation. This will return the created TicketStateID.

    my $Result = $OperationObject->Run(
        Data => {
			TicketState(
        		Name    => '...',
        		ValidID => '...',
        		UserID  => '...',
    		},
    	},
    );

    $Result = {
        Success      => 1,                       # 0 or 1
        Code         => '',                      # 
        Message      => '',                      # in case of error
        Data         => {                        # result data payload after Operation
            StateID  => '',                      # StateID 
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
        $Self->_Error(
            Code    => 'Webservice.InvalidConfiguration',
            Message => $Result->{Message},
        );
    }

    # prepare data
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
        Parameters => {
            'TicketState' => {
                State     => 'HASH',
                Required => 1
            },
            'TicketState::Name' => {
               Required => 1
            },
            'TicketState::TypeID' => {
               Required => 1
            },
            'TicketState::ValidID' => {
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


    # isolate TicketType parameter
    my $TicketState = $Param{Data}->{TicketState};

    # remove leading and trailing spaces
    for my $Attribute ( sort keys %{$TicketState} ) {
        if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

            #remove leading spaces
            $TicketState->{$Attribute} =~ s{\A\s+}{};

            #remove trailing spaces
            $TicketState->{$Attribute} =~ s{\s+\z}{};
        }
    }   

    # check if ticketState exists
    my $Exists = $Kernel::OM->Get('Kernel::System::State')->StateLookup(
        State => $TicketState->{Name},
    );
    if ( $Exists ) {
        return $Self->_Error(
            Code    => 'TicketStateCreate.TicketStateExists',
            Message => "Can not create TicketState. TicketState already exists.",
        );
    }

    # create ticketstate
    my $TicketStateID = $Kernel::OM->Get('Kernel::System::State')->StateAdd(
        %{$TicketState},
        UserID  => $Self->{Authorization}->{UserID},
    );

    if ( !$TicketStateID ) {
        return $Self->_Error(
            Code    => 'TicketStateCreate.UnableToCreate',
            Message => 'Could not create TicketState, please contact the system administrator',
        );
    }
    
    # return result    
    return $Self->_Success(
        Code   => 'Object.Created',
        TicketStateID => $TicketStateID,
    );    
}