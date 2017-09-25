# --
# Kernel/API/Operation/Priority/PriorityUpdate.pm - API Priority Update operation backend
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

package Kernel::API::Operation::V1::Priority::PriorityUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Priority::PriorityUpdate - API Priority Update Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to update an instance of this
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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::PriorityUpdate');

    return $Self;
}

=item Run()

perform PriorityUpdate Operation. This will return the updated Priority.

    my $Result = $OperationObject->Run(
        Data => {
            PriorityID => 123,
    	    Priority   => {
    	        Name    => '...',
    	        ValidID => '...',       # optional
    	    },
        }
	);
    

    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            PriorityID  => '',                  # PriorityID 
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
            'PriorityID' => {
                Required => 1
            },
            'Priority' => {
                Type => 'HASH',
                Required => 1
            },
            'Priority::Name' => {
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
    my $Priority = $Param{Data}->{Priority};

    # remove leading and trailing spaces
    for my $Attribute ( sort keys %{$Priority} ) {
        if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

            #remove leading spaces
            $Priority->{$Attribute} =~ s{\A\s+}{};

            #remove trailing spaces
            $Priority->{$Attribute} =~ s{\s+\z}{};
        }
    }   

    # check if Priority exists 
    my %PriorityData = $Kernel::OM->Get('Kernel::System::Priority')->PriorityGet(
        PriorityID => $Param{Data}->{PriorityID},
        UserID  => $Self->{Authorization}->{UserID},
    );
    
    if ( !%PriorityData ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Can not patch Priority. Priority with this ID '$Param{Data}->{PriorityID}' not exists.",
        );
    }

    # update Priority
    my $Success = $Kernel::OM->Get('Kernel::System::Priority')->PriorityUpdate(
        %{$Priority},
        ValidID    => $Priority{ValidID} ||$PriorityData{ValidID} || 1,
        PriorityID => $Param{Data}->{PriorityID},
        UserID     => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update Priority, please contact the system administrator',
        );
    }

    # return result    
    return $Self->_Success(
        PriorityID => $Param{Data}->{PriorityID},
    );    
}


