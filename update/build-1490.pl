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
use lib dirname($Bin) . '/plugins';
use lib dirname($Bin) . '/Kernel/cpan-lib';

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1490',
    },
);

use vars qw(%INC);

_UpdateReportUserRole();

exit 0;

sub _UpdateReportUserRole {
    # get database object
    my $DBObject = $Kernel::OM->Get('DB');
    my $RoleObject = $Kernel::OM->Get('Role');

    my %RoleList = reverse $RoleObject->RoleList();
    my %PermissionTypeList = reverse $RoleObject->PermissionTypeList();

    my $RegExTarget = '^\/reporting\/reports\/\*\{\}$';
    my $ChangeTarget = '/reporting/reports/*{Report.DefinitionID GT 0}';

    my $AllOk = 1;
    my $RoleID = $RoleList{'Report User'};
    if (!$RoleID) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Unable to find role "Report User"!'
        );
        $AllOk = 0;
    }

    my $PermissionTypeID = $PermissionTypeList{"Object"};
    if (!$PermissionTypeID) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Unable to find permission type "Object"!'
        );
        $AllOk = 0;
    }

    my @PermissionIDs = $RoleObject->PermissionList(
        RoleID => $RoleID,
    );
    if (!@PermissionIDs) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Unable to find any permissions for role "Report User"!'
        );
        $AllOk = 0;
    }

    foreach my $PermissionID (@PermissionIDs) {
        my %Permission = $RoleObject->PermissionGet(
            ID => $PermissionID,
        );

        if ($Permission{Target} =~ $RegExTarget) {
            my $Success = $RoleObject->PermissionUpdate(
                ID     => $PermissionID,
                UserID => 1,
                Target => $ChangeTarget,
            );

            if (!$Success) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => 'Unable to update permission (role="Report User", type="Property", target="' . $Permission{Target} . '"!'
                );
                $AllOk = 0;
            }
            else {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'info',
                    Message  => "Updated permission ID $PermissionID successfully!"
                );
            }
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
