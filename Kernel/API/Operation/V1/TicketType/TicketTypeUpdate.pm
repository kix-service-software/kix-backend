# --
# Kernel/API/Operation/TicketType/TicketTypeUpdate.pm - API TicketType Update operation backend
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

package Kernel::API::Operation::V1::TicketType::TicketTypeUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::TicketType::TicketTypeUpdate - API TicketType Create Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::TicketTypeUpdate');

    return $Self;
}

=item Run()

perform TicketTypeUpdate Operation. This will return the updated TypeID.

    my $Result = $OperationObject->Run(
        Data => {
            ID      => '...',
        }
	    TicketType => {
	        Name    => '...',
	        ValidID => '...',
	    },
	);
    

    $Result = {
        Success     => 1,                       # 0 or 1
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            TypeID  => '',                      # TypeID 
            Error   => {                        # should not return errors
                    Code    => 'TicketType.Update.ErrorCode'
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
        Data         => $Param{Data},
        Parameters   => {
            'TypeID' => {
                Type => 'HASH',
                Required => 1
            },
            'TicketType::Name' => {
                Required => 1
            },
            'TicketType::ValidID' => {
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

    # check if tickettype exists 
    my %TicketTypeData = $Kernel::OM->Get('Kernel::System::Type')->TypeGet(
        ID => $Param{Data}->{TypeID},
    );
    
    if ( !%TicketTypeData ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Can not patch tickettype. TicketType with this ID '$Param{Data}->{TypeID}' not exists.",
        );
    }

    # update tickettype
    my $Success = $Kernel::OM->Get('Kernel::System::Type')->TypeUpdate(
        ID      => $Param{Data}->{TypeID},
        Name    => $Param{Data}->{TicketType}->{Name},
        ValidID => $Param{Data}->{TicketType}->{ValidID},
        UserID  => $Param{Data}->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update TicketType, please contact the system administrator',
        );
    }

    # return result    
    return $Self->_Success(
        TypeID => $TicketTypeData{ID},
    );    
}


