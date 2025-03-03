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
        LogPrefix => 'framework_update-to-build-1932',
    },
);

use vars qw(%INC);

# add virtual fs ressource permission
_AddNewPermissions();

sub _AddNewPermissions {
    my ( $Self, %Param ) = @_;

    my %RoleList           = reverse $Kernel::OM->Get('Role')->RoleList();
    my %PermissionTypeList = reverse $Kernel::OM->Get('Role')->PermissionTypeList();

    # add new permissions
    my @NewPermissions = (
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Resource',
            Target => '/virtualfs',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ},
        }
    );

    foreach my $Permission (@NewPermissions) {
        my $RoleID = $RoleList{$Permission->{Role}};
        if (!$RoleID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Unable to find role "'
                    . $Permission->{Role}
                    . q{"!}
            );
            next;
        }
        my $PermissionTypeID = $PermissionTypeList{$Permission->{Type}};
        if (!$PermissionTypeID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Unable to find permission type "'
                    . $Permission->{Type}
                    . q{"!}
            );
            next;
        }

        # check if permission is needed
        my $PermissionID = $Kernel::OM->Get('Role')->PermissionLookup(
            RoleID => $RoleID,
            TypeID => $PermissionTypeID,
            Target => $Permission->{Target}
        );
        next if ($PermissionID);

        $PermissionID = $Kernel::OM->Get('Role')->PermissionAdd(
            RoleID     => $RoleID,
            TypeID     => $PermissionTypeID,
            Target     => $Permission->{Target},
            Value      => $Permission->{Value},
            IsRequired => 0,
            Comment    => q{},
            UserID     => 1,
        );

        if (!$PermissionID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to add permission (role=$Permission->{Role}, type=$Permission->{Type}, target=$Permission->{Target})!"
            );
        }
        else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'info',
                Message  => "Added permission (role=$Permission->{Role}, type=$Permission->{Type}, target=$Permission->{Target})."
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
