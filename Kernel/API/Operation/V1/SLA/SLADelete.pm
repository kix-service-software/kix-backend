# --
# Kernel/API/Operation/SLA/SLADelete.pm - API SLA Delete operation backend
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

package Kernel::API::Operation::V1::SLA::SLADelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::SLA::SLADelete - API SLA SLADelete Operation backend

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

perform SLADelete Operation. This will return the deleted SLAID.

    my $Result = $OperationObject->Run(
        Data => {
            SLAID  => '...',
        },		
    );

    $Result = {
        Message    => '',                      # in case of error
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;
    
    # init webService
    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        $Self->_Error(
            Code    => 'WebService.InvalidConfiguration',
            Message => $Result->{Message},
        );
    }

    # prepare data
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
        Parameters => {
            'SLAID' => {
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
  
    # start SLA loop
    SLA:    
    foreach my $SLAID ( @{$Param{Data}->{SLAID}} ) {

        my $ResultTicketSearch = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(        
		    Result       => 'COUNT',
		    Limit        => 1,
		    Filter       => {
		        AND => [ 
		            {
		                Field => 'SLAID',
		                Value => $SLAID,
		                Operator => 'EQ',
		            },
		        ]
		    },
		    UserID       => 1,
		    Permission   => 'ro',         
        );
        
        if ( $ResultTicketSearch ) {
            return $Self->_Error(
                Code    => 'Object.DependingObjectExists',
                Message => 'Can not delete SLA. A Ticket with this SLA already exists.',
            );
        }
      
        # delete SLA	    
        my $Success = $Kernel::OM->Get('Kernel::System::SLA')->SLADelete(
            SLAID  => $SLAID,
            UserID  => $Self->{Authorization}->{UserID},
        );
 
        if ( !$Success ) {
            return $Self->_Error(
                Code    => 'Object.UnableToDelete',
                Message => 'Could not delete SLA, please contact the system administrator',
            );
        }
    }

    # return result
    return $Self->_Success();
}

1;
