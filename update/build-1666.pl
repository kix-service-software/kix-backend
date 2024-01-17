#!/usr/bin/perl
# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
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
        LogPrefix => 'framework_update-to-build-1666',
    },
);

use vars qw(%INC);

_AddNewPermissions();

# allow only customer relevant user
sub _AddNewPermissions {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Log');
    my $DBObject = $Kernel::OM->Get('DB');
    my $RoleObject = $Kernel::OM->Get('Role');

    my %RoleList           = reverse $RoleObject->RoleList();
    my %PermissionTypeList = reverse $RoleObject->PermissionTypeList();

    # add new permissions
    my @NewPermissions = (
        {
            Role   => 'Customer',
            Type   => 'Object',
            Target => '/system/users/*{User.UserID NE $CurrentUser.UserID}',
            Value  => 0
        },
    );

    my $PermissionID;
    my $AllPermsOK = 1;
    foreach my $Permission (@NewPermissions) {
        my $RoleID = $RoleList{$Permission->{Role}};
        if (!$RoleID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Unable to find role "'.$Permission->{Role}.'"!'
            );
            next;
        }
        my $PermissionTypeID = $PermissionTypeList{$Permission->{Type}};
        if (!$PermissionTypeID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Unable to find permission type "'.$Permission->{Type}.'"!'
            );
            next;
        }

        # check if permission is needed
        $PermissionID = $RoleObject->PermissionLookup(
            RoleID => $RoleID,
            TypeID => $PermissionTypeID,
            Target => $Permission->{Target}
        );
        next if ($PermissionID);

        $PermissionID = $RoleObject->PermissionAdd(
            RoleID     => $RoleID,
            TypeID     => $PermissionTypeID,
            Target     => $Permission->{Target},
            Value      => $Permission->{Value},
            IsRequired => 0,
            Comment    => '',
            UserID     => 1,
        );

        if (!$PermissionID) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Unable to add permission (role=$Permission->{Role}, type=$Permission->{Type}, target=$Permission->{Target}!"
            );
            $AllPermsOK = 0;
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
