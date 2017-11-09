# --
# Kernel/API/Operation/Service/ServiceUpdate.pm - API Service Update operation backend
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

package Kernel::API::Operation::V1::Service::ServiceUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Service::ServiceUpdate - API Service Create Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::ServiceUpdate');

    return $Self;
}

=item Run()

perform ServiceUpdate Operation. This will return the updated TypeID.

    my $Result = $OperationObject->Run(
        Data => {
            ServiceID => 123,
            Service   => {
	            Name    => '...',
	            Comment => '...',
	            ValidID => 1,
                ParentID    => '...',
                TypeID      => '...',
                Criticality => '...',	            
            }
	    },
	);
    

    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            ServiceID  => 123,                     # ID of the updated Service 
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
            'ServiceID' => {
                Required => 1
            },
            'Service' => {
                Type => 'HASH',
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

    # isolate Service parameter
    my $Service = $Param{Data}->{Service};

    # remove leading and trailing spaces
    for my $Attribute ( sort keys %{$Service} ) {
        if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

            #remove leading spaces
            $Service->{$Attribute} =~ s{\A\s+}{};

            #remove trailing spaces
            $Service->{$Attribute} =~ s{\s+\z}{};
        }
    }   

    # check if Service exists 
    my %ServiceData = $Kernel::OM->Get('Kernel::System::Service')->ServiceGet(
        ServiceID => $Param{Data}->{ServiceID},
        UserID      => $Self->{Authorization}->{UserID},        
    );
 
    if ( !%ServiceData ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Cannot update Service. No Service with ID '$Param{Data}->{ServiceID}' found.",
        );
    }

    # update Service
    my $Success = $Kernel::OM->Get('Kernel::System::Service')->ServiceUpdate(
        ServiceID   => $Param{Data}->{ServiceID} || $ServiceData{ServiceID},    
        Name        => $Service->{Name} || $ServiceData{Name},
        Comment     => $Service->{Comment} || $ServiceData{Comment},
        ValidID     => $Service->{ValidID} || $ServiceData{ValidID},
        ParentID    => $Service->{ParentID} || $ServiceData{ParentID},
        TypeID      => $Service->{TypeID} || $ServiceData{TypeID},
        Criticality => $Service->{Criticality} || $ServiceData{Criticality},
        UserID      => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update Service, please contact the system administrator',
        );
    }

    # return result    
    return $Self->_Success(
        ServiceID => $Param{Data}->{ServiceID},
    );    
}


1;
