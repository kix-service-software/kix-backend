# --
# Kernel/API/Operation/Priority/PriorityDelete.pm - API Priority Delete operation backend
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

package Kernel::API::Operation::V1::Priority::PriorityDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Priority::PriorityDelete - API Priority PriorityDelete Operation backend

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

perform PriorityDelete Operation. This will return the deleted PriorityID.

    my $Result = $OperationObject->Run(
        Data => {
            PriorityID  => '...',
        },		
    );

    $Result = {
        Success    => 1,
        Code       => '',                       # in case of error    
        Message    => '',                       # in case of error
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
            'PriorityID' => {
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
 
    # start priority loop
    PRIORITY:    
    foreach my $PriorityID ( @{$Param{Data}->{PriorityID}} ) {

        # search ticket       
        my $ResultTicketSearch = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(
            Result  => 'COUNT',
            PriorityIDs => [$PriorityID],
            UserID  => $Self->{Authorization}->{UserID},
        );
    
        if ( $ResultTicketSearch ) {
            return $Self->_Error(
                Code    => 'PriorityDelete.TicketExists',
                Message => 'Can not delete Priority. A Ticket with this Priority already exists.',
            );
        }

        # delete Priority	    
        my $Success = $Kernel::OM->Get('Kernel::System::Priority')->PriorityDelete(
            PriorityID  => $PriorityID,
            UserID  => $Self->{Authorization}->{UserID},
        );

        if ( !$Success ) {
            return $Self->_Error(
                Code    => 'Object.UnableToDelete',
                Message => 'Could not delete Priority, please contact the system administrator',
            );
        }
    }

    # return result
    return $Self->_Success();
}

1;