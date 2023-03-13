# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::BasePermissionHandler;

use strict;
use warnings;

use Time::HiRes;

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::BasePermissionHandler - base permission handler interface

=head1 SYNOPSIS

Inherit from this class if you want to handle base permissions.

    use base qw(Kernel::System::BasePermissionHandler);

In your class, you have to call L</BasePermissionHandlerInit('<BaseType>')>.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item BasePermissionHandlerInit()

Call this to initialize the handling mechanisms to work
correctly with your object.

    $Self->BasePermissionHandlerInit(
        Type => '<BaseType>'
    );

Example:

    $Self->BasePermissionHandlerInit(
        Type => 'Base::Ticket'
    );

=cut

sub BasePermissionHandlerInit {
    my ( $Self, %Param ) = @_;

    $Self->{BasePermissionHandlerInit} = \%Param;

    return 1;
}

=item UpdateBasePermissions()

get a list of base permissions for this object and update the permissions

Example:

    my $Success = $BasePermissionHandler->UpdateBasePermissions(
        ObjectID       => 123,
        PermissionList => [],
        UserID         => 123,
    );

=cut

sub UpdateBasePermissions {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ObjectID PermissionList UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my $RoleObject = $Kernel::OM->Get('Role');

    my %PermissionTypeList = reverse $RoleObject->PermissionTypeList(
        Valid => 1
    );

    my @PermissionList = $RoleObject->PermissionListGet(
        Types  => [ $Self->{BasePermissionHandlerInit}->{Type} ],
        Target => $Param{ObjectID},
    );
    my %AssignedPermissions = map { $_->{RoleID} => $_ } @PermissionList;

    PERMISSION:
    foreach my $Permission ( @{$Param{PermissionList}} ) {
        my $Value = 0;
        foreach my $ValueStr ( split('\+', $Permission->{Permission}) ) {
            $Value += Kernel::System::Role::Permission::PERMISSION->{$ValueStr};
        }
        my $AssignedPermission = $AssignedPermissions{$Permission->{RoleID}};

        if ( IsHashRefWithData($AssignedPermission) && $AssignedPermission->{Value} != $Value ) {
            # update permission
            my $Success = $RoleObject->PermissionUpdate(
                %{$AssignedPermission},
                Value  => $Value,
                UserID => $Param{UserID}
            );
            if ( !$Success ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unable to update $Self->{BasePermissionHandlerInit}->{Type} permission with ID $AssignedPermission->{ID}!"
                );
                next PERMISSION;
            }
        } 
        elsif ( !IsHashRefWithData($AssignedPermission) ) {
            # add permission
            my $Success = $RoleObject->PermissionAdd(
                RoleID => $Permission->{RoleID},
                TypeID => $PermissionTypeList{$Self->{BasePermissionHandlerInit}->{Type}},
                Target => $Param{ObjectID},
                Value  => $Value,
                UserID => $Param{UserID}
            );
            if ( !$Success ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unable to add $Self->{BasePermissionHandlerInit}->{Type} permission for RoleID $Permission->{RoleID} on ObjectID $Param{ObjectID}!"
                );
                next PERMISSION;
            }
        }
        delete $AssignedPermissions{$Permission->{RoleID}};
    }

    # delete all obsolete permissions
    foreach my $Permission ( values %AssignedPermissions ) {
        my $Success = $RoleObject->PermissionDelete(
            ID     => $Permission->{ID},
            UserID => $Param{UserID}
        );
        if ( !$Success ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to remove $Self->{BasePermissionHandlerInit}->{Type} permission with ID $Permission->{ID}!"
            );
        }
    }

    return 1;
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
