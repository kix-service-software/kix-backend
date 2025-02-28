#!/usr/bin/perl
# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use File::Basename;
use FindBin qw($Bin);
use lib dirname($Bin);
use lib dirname($Bin) . '/Kernel/cpan-lib';

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);
use Kernel::System::Role::Permission;

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1697',
    },
);

use vars qw(%INC);

_AddNewRoleTextModuleAdmin();
_AddNewRoleFAQAdmin();

sub _AddNewRoleTextModuleAdmin {
    my ( $Self, %Param ) = @_;

    my $RoleObject = $Kernel::OM->Get('Role');

    my %RoleList = reverse $RoleObject->RoleList();
    my %PermissionTypeList = reverse $RoleObject->PermissionTypeList();

    my @NewRoles = (
        {
            Name => 'Textmodule Admin',
            Comment => Kernel::Language::Translatable('allows to create, edit, delete text modules'),
            UsageContext => 1
        }
    );

    foreach my $Role ( @NewRoles ) {
        my $RoleID = $RoleObject->RoleAdd(
            %{$Role},
            ValidID => 1,
            UserID  => 1
        );
        if ( !$RoleID ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to create role \"$Role->{Name}\"!",
            );
            next;
        } else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'info',
                Message  => "Created role \"$Role->{Name}\"",
            );
        }
    }

    # reload role list
    %RoleList = reverse $RoleObject->RoleList();

    my @NewPermissions = (
        {
            Role   => 'Textmodule Admin',
            Type   => 'Resource',
            Target => '/system/textmodules',
            Value  => Kernel::System::Role::Permission::PERMISSION_CRUD
        }
    );

    foreach my $Permission (@NewPermissions) {
        my $RoleID = $RoleList{$Permission->{Role}};
        if (!$RoleID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Unable to find role "' . $Permission->{Role} . '"!'
            );
            next;
        }
        my $PermissionTypeID = $Permission->{TypeID} || $PermissionTypeList{$Permission->{Type}};
        if (!$PermissionTypeID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Unable to find permission type "' . $Permission->{Type} . '"!'
            );
            next;
        }

        my $PermissionID = $RoleObject->PermissionLookup(
            RoleID => $RoleID,
            TypeID => $PermissionTypeID,
            Target => $Permission->{Target}
        );
        # nothing to do if this permission already exists
        next if $PermissionID;

        $PermissionID = $RoleObject->PermissionAdd(
            UserID => 1,
            RoleID => $RoleID,
            TypeID => $PermissionTypeID,
            %{$Permission},
        );

        if (!$PermissionID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to create permission (role=$Permission->{Role}, type=$Permission->{Type}, target=$Permission->{Target})!"
            );
        } else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'info',
                Message  => "Created permission ID $PermissionID!"
            );
        }
    }

    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp();

    return 1;
}

sub _AddNewRoleFAQAdmin {
    my ( $Self, %Param ) = @_;

    my $RoleObject = $Kernel::OM->Get('Role');

    my %RoleList = reverse $RoleObject->RoleList();
    my %PermissionTypeList = reverse $RoleObject->PermissionTypeList();

    my @NewRoles = (
        {
            Name => 'FAQ Admin',
            Comment => Kernel::Language::Translatable('allows to create, edit, delete FAQ categories'),
            UsageContext => 1
        }
    );

    foreach my $Role ( @NewRoles ) {
        my $RoleID = $RoleObject->RoleAdd(
            %{$Role},
            ValidID => 1,
            UserID  => 1
        );
        if ( !$RoleID ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to create role \"$Role->{Name}\"!",
            );
            next;
        } else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'info',
                Message  => "Created role \"$Role->{Name}\"",
            );
        }
    }

    # reload role list
    %RoleList = reverse $RoleObject->RoleList();

    my @NewPermissions = (
        {
            Role   => 'FAQ Admin',
            Type   => 'Resource',
            Target => '/system/faq',
            Value  => Kernel::System::Role::Permission::PERMISSION_CRUD
        }
    );

    foreach my $Permission (@NewPermissions) {
        my $RoleID = $RoleList{$Permission->{Role}};
        if (!$RoleID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Unable to find role "' . $Permission->{Role} . '"!'
            );
            next;
        }
        my $PermissionTypeID = $Permission->{TypeID} || $PermissionTypeList{$Permission->{Type}};
        if (!$PermissionTypeID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Unable to find permission type "' . $Permission->{Type} . '"!'
            );
            next;
        }

        my $PermissionID = $RoleObject->PermissionLookup(
            RoleID => $RoleID,
            TypeID => $PermissionTypeID,
            Target => $Permission->{Target}
        );
        # nothing to do if this permission already exists
        next if $PermissionID;

        $PermissionID = $RoleObject->PermissionAdd(
            UserID => 1,
            RoleID => $RoleID,
            TypeID => $PermissionTypeID,
            %{$Permission},
        );

        if (!$PermissionID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to create permission (role=$Permission->{Role}, type=$Permission->{Type}, target=$Permission->{Target})!"
            );
        } else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'info',
                Message  => "Created permission ID $PermissionID!"
            );
        }
    }

    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp();

    return 1;
}

exit 0;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
