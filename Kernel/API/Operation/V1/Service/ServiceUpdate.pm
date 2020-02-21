# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Service::ServiceUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

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

perform ServiceUpdate Operation. This will return the updated ServcieID.

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
            Code => 'Object.NotFound',
        );
    }

    # check if Service exists
    # prepare full name for lookup
    my $FullName = $Service->{Name} || $ServiceData{Name};
    if ( $Service->{ParentID} || $ServiceData{ParentID} ) {
        my $ParentName = $Kernel::OM->Get('Kernel::System::Service')->ServiceLookup(
            ServiceID => $Service->{ParentID} || $ServiceData{ParentID},
        );        
        if ($ParentName) {
            $FullName = $ParentName . '::' . ( $Service->{Name} || $ServiceData{Name} );
        }
        else {
            return $Self->_Error(
                Code => 'ParentObject.NotFound',
            );
        }
    }

    # check if Service exists
    my $ServiceID = $Kernel::OM->Get('Kernel::System::Service')->ServiceLookup(
        Name    => $FullName,
        UserID  => 1,
    );
    
    if ( $ServiceID && $ServiceID != $ServiceData{ServiceID} ) {
        return $Self->_Error(
            Code => 'Object.AlreadyExists',
        );
    }

    # update Service
    my $Success = $Kernel::OM->Get('Kernel::System::Service')->ServiceUpdate(
        ServiceID   => $Service->{ServiceID} || $ServiceData{ServiceID},    
        Name        => $Service->{Name} || $ServiceData{Name},
        Comment     => exists $Service->{Comment} ? $Service->{Comment} : $ServiceData{Comment},
        ValidID     => $Service->{ValidID} || $ServiceData{ValidID},
        ParentID    => exists $Service->{ParentID} ? $Service->{ParentID} : $ServiceData{ParentID},
        TypeID      => $Service->{TypeID} || $ServiceData{TypeID},
        Criticality => $Service->{Criticality} || $ServiceData{Criticality},
        UserID      => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate',
        );
    }

    # return result    
    return $Self->_Success(
        ServiceID => $ServiceData{ServiceID},
    );    
}


1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
