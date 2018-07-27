# --
# Kernel/API/Operation/Service/ServiceCreate.pm - API Service Create operation backend
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

package Kernel::API::Operation::V1::Service::ServiceCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Service::ServiceCreate - API Service ServiceCreate Operation backend

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
        'Service' => {
            Type     => 'HASH',
            Required => 1
        },
        'Service::Name' => {
            Required => 1
        },
        'Service::TypeID' => {
            Required => 1
        },            
    }
}

=item Run()

perform ServiceCreate Operation. This will return the created ServiceID.

    my $Result = $OperationObject->Run(
        Data => {
            Service  => {
                Name     => '...',
                ParentID => 1,            # (optional)
                Comment  => '...',        # (optional)
                ValidID     => 1,
                TypeID      => 2,
                Criticality => '...',
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      # 
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            ServiceID  => '',                         # ID of the created Service
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
    my $Exists = $Kernel::OM->Get('Kernel::System::Service')->ServiceLookup(
        Name    => $Service->{Name},
        UserID  => $Self->{Authorization}->{UserID},
    );
    
    if ( $Exists ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Can not create Service. Service with same name '$Service->{Name}' already exists.",
        );
    }

    # create Service
    my $ServiceID = $Kernel::OM->Get('Kernel::System::Service')->ServiceAdd(
        Name        => $Service->{Name},
        Comment     => $Service->{Comment} || '',
        ValidID     => $Service->{ValidID} || 1,
        ParentID    => $Service->{ParentID} || '',
        TypeID      => $Service->{TypeID},
        Criticality => $Service->{Criticality} ||'3 normal',
        UserID      => $Self->{Authorization}->{UserID},
    );

    if ( !$ServiceID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create Service, please contact the system administrator',
        );
    }
    
    # return result    
    return $Self->_Success(
        Code   => 'Object.Created',
        ServiceID => $ServiceID,
    );    
}


1;
