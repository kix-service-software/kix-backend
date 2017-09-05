# --
# Kernel/API/Operation/TicketType/TicketTypeDelete.pm - API TicketType Delete operation backend
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

package Kernel::API::Operation::V1::TicketType::TicketTypeDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use Kernel::System::Ticket::TicketSearch;

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::TicketType::TicketypeDelete - API TicketType TicketTypeDelete Operation backend

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

perform TicketTypeDelete Operation. This will return the deleted TicketTypeID.

    my $Result = $OperationObject->Run(
        Data => {
            Authorization => {
                ...
            },

			TicketTypeDelete {
        		TicketTypeID    => '...',
        		ValidID => 1,
        		UserID  => 123,
        	},
        },		
    };

    $Result = {
        Success         => 1,                       # 0 or 1
        Message    => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            TicketTypeID  => '',                          # TicketTypeID 
            Error => {                              # should not return errors
                    Code    => 'TicketTypeDelete.Delete.ErrorCode'
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
            'TicketTypeID' => {
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
    my @TicketTypeList;
  
    # start type loop
    TYPE:    
    foreach my $TicketTypeID ( @{$Param{Data}->{TicketTypeID}} ) {
           	
	    # check if tickettype exists
	    my $TicketTypeData = $Kernel::OM->Get('Kernel::System::Type')->TypeLookup(
	        TypeID => $TicketTypeID,
	    );

	    if ( !$TicketTypeData ) {
	        next $Self->_Error(
	            Code    => 'TicketTypeDelete.TicketTypeNotExists',
	            Message => 'Can not delete TicketType. TicketType not exists.',
	        );
	    }
	           
	    my $ResultTicketSearch = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(
	        Result => 'COUNT',
	        TypeIDs => [$TicketTypeID],
	        UserID => $Param{Data}->{Authorization}->{UserID},
	    );
     
	    if ( $ResultTicketSearch ) {
	        next $Self->_Error(
	            Code    => 'TicketTypeDelete.TicketExists',
	            Message => 'Can not delete TicketType. A Ticket with same TicketType already exists.',
	        );
	    }
	    
	    my $Success = $Kernel::OM->Get('Kernel::System::Type')->TicketTypeDelete(
	        TicketTypeID  => $TicketTypeID,
	        ValidID => 1,
	        UserID  => $Param{Data}->{Authorization}->{UserID},
	    );

	    if ( !$Success ) {
	        return $Self->_Error(
	            Code    => 'Object.UnableToDelete',
	            Message => 'Could not delete TicketType, please contact the system administrator',
	        );
	    }
	    else {
	        push(@TicketTypeList, $TicketTypeID);	    	
	    }
    }
    if ( scalar(@TicketTypeList) == 1 ) {
        return $Self->_Success(
            TicketType => $TicketTypeList[0],
        );    
    }

    return $Self->_Success(
        TicketType => \@TicketTypeList,
    );
}