# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Role::PermissionUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Permission::PermissionUpdate - API Permission Create Operation backend

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
        'RoleID' => {
            DataType => 'NUMERIC',
            Required => 1
        },
        'PermissionID' => {
            DataType => 'NUMERIC',
            Required => 1
        },
        'Permission' => {
            Type => 'HASH',
            Required => 1
        },
    }
}

=item Run()

perform PermissionUpdate Operation. This will return the updated PermissionID.

    my $Result = $OperationObject->Run(
        Data => {
            RoleID       => 123,
            PermissionID => 123,
            Permission   => {
	            Target  => '...',
                Value   => 0x0003,
	            Comment => '...',
            }
	    },
	);


    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            PermissionID  => 123,               # ID of the updated permission
        },
    };

=cut


sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Permission parameter
    my $Permission = $Self->_Trim(
        Data => $Param{Data}->{Permission}
    );

    # check if role exists
    my $Rolename = $Kernel::OM->Get('Role')->RoleLookup(
        RoleID => $Param{Data}->{RoleID},
    );

    if ( !$Rolename ) {
        return $Self->_Error(
            Code => 'Object.ParentNotFound',
        );
    }

    # check if permission exists and belongs to this role
    my %PermissionData = $Kernel::OM->Get('Role')->PermissionGet(
        ID => $Param{Data}->{PermissionID},
    );

    if ( !IsHashRefWithData(\%PermissionData) || $PermissionData{RoleID} != $Param{Data}->{RoleID} ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # validate permission
    my $ValidationResult = $Kernel::OM->Get('Role')->ValidatePermission(
        TypeID => $Permission->{TypeID} || $PermissionData{TypeID},
        Target => $Permission->{Target} || $PermissionData{Target},
        Value  => defined $Permission->{Value} ? $Permission->{Value} : $PermissionData{Value},
    );
    if ( !$ValidationResult ) {
        my %PermissionTypeList = $Kernel::OM->Get('Role')->PermissionTypeList( Valid => 1 );
        my $Type = $PermissionTypeList{$Permission->{TypeID}} || 'unknown';

        return $Self->_Error(
            Code    => 'BadRequest',
            Message => "Cannot create permission. The permission target doesn't match the possible ones for type $Type.",
        );
    }

    # update permission
    my $Success = $Kernel::OM->Get('Role')->PermissionUpdate(
        ID         => $Param{Data}->{PermissionID},
        TypeID     => $Permission->{TypeID} || $PermissionData{TypeID},
        Target     => $Permission->{Target} || $PermissionData{Target},
        Value      => defined $Permission->{Value} ? $Permission->{Value} : $PermissionData{Value},
        IsRequired => $Permission->{IsRequired} || $PermissionData{IsRequired},
        Comment    => exists $Permission->{Comment} ? $Permission->{Comment} : $PermissionData{Comment},
        UserID     => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate',
        );
    }

    # return result
    return $Self->_Success(

        PermissionID => $Param{Data}->{PermissionID},
    );
}

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
