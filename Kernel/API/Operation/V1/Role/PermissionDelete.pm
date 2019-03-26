# --
# Kernel/API/Operation/Role/PermissionDelete.pm - API Permission Delete operation backend
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

package Kernel::API::Operation::V1::Role::PermissionDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Role::PermissionDelete - API Role PermissionDelete Operation backend

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
        'RoleID' => {
            DataType => 'NUMERIC',
            Required => 1
        },
        'PermissionID' => {
            DataType => 'NUMERIC',
            Type     => 'ARRAY',
            Required => 1
        },
    }
}

=item Run()

perform PermissionDelete Operation. This will return the deleted PermissionID.

    my $Result = $OperationObject->Run(
        Data => {
            RoleID        => 123,
            PermissionID  => 123,
        },		
    );

    $Result = {
        Message    => '',                      # in case of error
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # start loop
    foreach my $PermissionID ( @{$Param{Data}->{PermissionID}} ) {

        # check if permission exists and belongs to this role    
        my %Permission = $Kernel::OM->Get('Kernel::System::Role')->PermissionGet(
            ID => $PermissionID,
        );
   
        if ( !IsHashRefWithData(\%Permission) || $Permission{RoleID} != $Param{Data}->{RoleID} ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # delete permission	    
        my $Success = $Kernel::OM->Get('Kernel::System::Role')->PermissionDelete(
            ID  => $PermissionID,
        );

        if ( !$Success ) {
            return $Self->_Error(
                Code => 'Object.UnableToDelete',
            );
        }
    }


    # return result
    return $Self->_Success();
}

1;