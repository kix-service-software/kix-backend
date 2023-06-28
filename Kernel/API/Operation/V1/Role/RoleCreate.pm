# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Role::RoleCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Role::RoleCreate - API Role RoleCreate Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

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
        'Role' => {
            Type     => 'HASH',
            Required => 1
        },
        'Role::Name' => {
            Required => 1
        },
        'Role::UsageContext' => {
            Required => 1
        },
    }
}

=item Run()

perform RoleCreate Operation. This will return the created RoleID.

    my $Result = $OperationObject->Run(
        Data => {
	    	Role  => {
	        	Name         => '...',
	        	Comment      => '...',                 # optional
	        	ValidID      => '...',                 # optional
                UsageContext => 0x0003,
	    	},
	    },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            RoleID  => '',                         # ID of the created Role
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Role parameter
    my $Role = $Self->_Trim(
        Data => $Param{Data}->{Role}
    );

    # check if Role exists
    my $Exists = $Kernel::OM->Get('Role')->RoleLookup(
        Role => $Role->{Name},
    );

    if ($Exists) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Cannot create role. Role with the name '$Role->{Name}' already exists.",
        );
    }

    # create Role
    my $RoleID = $Kernel::OM->Get('Role')->RoleAdd(
        Name         => $Role->{Name},
        Comment      => $Role->{Comment} || '',
        ValidID      => $Role->{ValidID} || 1,
        UsageContext => $Role->{UsageContext},
        UserID       => $Self->{Authorization}->{UserID},
    );

    if ( !$RoleID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create role, please contact the system administrator',
        );
    }

    # assign users
    if ( IsArrayRefWithData( $Role->{UserIDs} ) ) {
        foreach my $UserID ( @{ $Role->{UserIDs} } ) {
            my $Result = $Self->ExecOperation(
                OperationType => 'V1::Role::RoleUserIDCreate',
                Data          => {
                    RoleID => $RoleID,
                    UserID => $UserID,
                }
            );

            if ( !$Result->{Success} ) {
                return $Result;
            }
        }
    }

    # assign permissions
    if ( IsArrayRefWithData( $Role->{Permissions} ) ) {
        foreach my $Permission ( @{ $Role->{Permissions} } ) {
            my $Result = $Self->ExecOperation(
                OperationType => 'V1::Role::PermissionCreate',
                Data          => {
                    RoleID     => $RoleID,
                    Permission => $Permission,
                }
            );

            if ( !$Result->{Success} ) {
                return $Result;
            }
        }
    }

    # return result
    return $Self->_Success(
        Code   => 'Object.Created',
        RoleID => 0 + $RoleID,
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
