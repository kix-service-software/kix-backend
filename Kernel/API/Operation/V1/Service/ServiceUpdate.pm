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

=item ParameterDefinition()

define parameter preparation and check for this operation

    my $Result = $OperationObject->ParameterDefinition(
        Data => {
            ...
        },
    );

    $Result = {
        ...
    };

=cut

sub ParameterDefinition {
    my ( $Self, %Param ) = @_;

    return {
        'ServiceID' => {
            Required => 1
        },
        'Service' => {
            Type => 'HASH',
            Required => 1
        },
    }
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
            },
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

    # isolate and trim Service parameter
    my $Service = $Self->_Trim(
        Data => $Param{Data}->{Service}
    );

    # check if Service exists 
    my %ServiceData = $Kernel::OM->Get('Kernel::System::Service')->ServiceGet(
        ServiceID => $Param{Data}->{ServiceID},
        UserID    => 1,        
    );
 
    if ( !%ServiceData ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Cannot update Service. No Service with ID '$Param{Data}->{ServiceID}' found.",
        );
    }

    # check if Service exists
    # prepare full name for lookup
    my $FullName = $Service->{Name};
    if ( $Service->{ParentID} ) {
        my $ParentName = $Kernel::OM->Get('Kernel::System::Service')->ServiceLookup(
            ServiceID => $Service->{ParentID} || $ServiceData{ParentID},
        );
        if ($ParentName) {
            $FullName = $ParentName . '::' . $Service->{Name};
        }
    }

    # check if Service exists
    my $ServiceID = $Kernel::OM->Get('Kernel::System::Service')->ServiceLookup(
        Name    => $FullName,
        UserID  => 1,
    );
    
    if ( $ServiceID != $ServiceData{ServiceID} ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Cannot update Service. Service with same name '$Service->{Name}' already exists.",
        );
    }

    # update Service
    my $Success = $Kernel::OM->Get('Kernel::System::Service')->ServiceUpdate(
        ServiceID   => $Service->{ServiceID} || $ServiceData{ServiceID},    
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
