# --
# Kernel/API/Operation/Role/RoleDelete.pm - API Role Delete operation backend
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

package Kernel::API::Operation::V1::Role::RoleDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Role::RoleDelete - API Role RoleDelete Operation backend

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

perform RoleDelete Operation. This will return the deleted RoleID.

    my $Result = $OperationObject->Run(
        Data => {
            RoleID  => '...',
        },		
    );

    $Result = {
        Message    => '',                      # in case of error
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
            'RoleID' => {
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
  
    # start type loop
    TYPE:    
    foreach my $RoleID ( @{$Param{Data}->{RoleID}} ) {

        # search Role user       
        my %ResultUserList = $Kernel::OM->Get('Kernel::System::Group')->PermissionRoleUserGet(
            Type    => 'move_into',
            RoleID => $RoleID,
        );
   
        if ( IsHashRefWithData(\%ResultUserList) ) {
            return $Self->_Error(
                Code    => 'RoleDelete.UserExists',
                Message => 'Cannot delete Role. At least one user is assigned to this Role.',
            );
        }

        # search Role role       
        my %ResultRoleList = $Kernel::OM->Get('Kernel::System::Group')->PermissionRoleGroupGet(
            Type    => 'move_into',
            RoleID => $RoleID,
        );
  
        if ( IsHashRefWithData(\%ResultRoleList) ) {
            return $Self->_Error(
                Code    => 'RoleDelete.RolesExists',
                Message => 'Cannot delete Role. This Role is assgined to at least one role.',
            );
        }
        
        # delete Role	    
        my $Success = $Kernel::OM->Get('Kernel::System::Group')->RoleDelete(
            RoleID  => $RoleID,
            UserID  => $Self->{Authorization}->{UserID},
        );

        if ( !$Success ) {
            return $Self->_Error(
                Code    => 'Object.UnableToDelete',
                Message => 'Could not delete Role, please contact the system administrator',
            );
        }
    }

    # return result
    return $Self->_Success();
}

1;
