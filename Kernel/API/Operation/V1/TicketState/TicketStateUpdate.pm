# --
# Kernel/API/Operation/TicketState/TicketStateUpdate.pm - API TicketState Update operation backend
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Ralf(dot)Boehm(at)cape(dash)it(dot)de
# 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::TicketState::TicketStateUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::TicketState::TicketStateUpdate - API TicketState Create Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::TicketStateUpdate');

    return $Self;
}

=item Run()

perform TicketStateUpdate Operation. This will return the updated TicketStateID.

    my $Result = $OperationObject->Run(
        Data => {
        	StateID => '...',
        }        
    	TicketState => (
        	Name    => ''...',
        	ValidID => '...',
        	TypeID  => '...',
        	Comment => '...',        	        	
    	),
    );
    
    $Result = {
        Success      => 1,                  # 0 or 1
        Message      => '',                 # in case of error
        Data         => {                   # result data payload after Operation
            StateID  => '',                 #StateID 
            Error    => {                         # should not return errors
                    Code    => 'TicketState.Update.ErrorCode'
                    Message => 'Error Description'
            },
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
                Type  => 'HASH',
                Required => 1
            },
            'TicketState::Name' => {
               Required => 1
            },
            'TicketState::TypeID' => {
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

    # isolate TicketState parameter
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
   
    my $StateID;
    
    # check if ticketState exists
    my %TicketStateData = $Kernel::OM->Get('Kernel::System::State')->StateGet(
        ID => $Param{Data}->{StateID},
    );
    
    if ( !%TicketStateData ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Can not upgrade ticketState. TicketState with this ID '$Param{Data}->{TicketStateID}' not exists.",
        );
    }

    my $Success = $Kernel::OM->Get('Kernel::System::State')->StateUpdate(
        %{$TicketState},    
        ID      => $Param{Data}->{StateID},
        UserID  => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update TicketState, please contact the system administrator',
        );
    }
    
    # return result     
    return $Self->_Success(
        TicketStateID => $TicketStateData{ID},
    );    
}

1;