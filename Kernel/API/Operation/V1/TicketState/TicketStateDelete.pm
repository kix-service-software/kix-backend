# --
# Kernel/API/Operation/TicketState/TicketStateDelete.pm - API TicketState Delete operation backend
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

package Kernel::API::Operation::V1::TicketState::TicketStateDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::TicketState::TickeStateDelete - GenericInterface TicketState TicketStateDelete Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::TicketStateDelete');

    return $Self;
}

=item Run()

perform TicketStateDelete Operation. This will return the delete StateID.

    my $Result = $OperationObject->Run(
        Data => {
            StateID      => '...',
        }
    );

    $Result = {
        Message    => '',                      # in case of error
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
            'StateID' => {
                Type     => 'ARRAY',
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

    my $Message = '';

    # start State loop
    State:    
    foreach my $TicketStateID ( @{$Param{Data}->{StateID}} ) {
	           
        my $ResultTicketSearch = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(
	        Result => 'COUNT',
	        StateIDs => [$TicketStateID],
	        UserID => $Self->{Authorization}->{UserID},
	    );
	    
	    if ( $ResultTicketSearch ) {
            return $Self->_Error(
                Code    => 'TicketStateDelete.TicketExists',
                Message => 'Can not delete TicketState. A Ticket with this TicketState already exists.',
            );
	    }
	    
        # delete ticketstate	    
	    my $Success = $Kernel::OM->Get('Kernel::System::State')->TicketStateDelete(
	        StateID  => $TicketStateID,
	        UserID  => $Self->{Authorization}->{UserID},
	    );

        if ( !$Success ) {
            return $Self->_Error(
                Code    => 'Object.UnableToDelete',
                Message => 'Could not delete TicketState, please contact the system administrator',
            );
        }
    }

    # return result
    return $Self->_Success();
}

1;
