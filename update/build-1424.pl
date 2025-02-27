#!/usr/bin/perl
# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
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

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1424',
    },
);

use vars qw(%INC);

_UpdateCustomerRole();

exit 0;

sub _UpdateCustomerRole {
    # get database object
    my $DBObject = $Kernel::OM->Get('DB');
    my $RoleObject = $Kernel::OM->Get('Role');

    my %RoleList = reverse $RoleObject->RoleList();
    my %PermissionTypeList = reverse $RoleObject->PermissionTypeList();

    my $RegExTarget = qr/\/tickets\/\*\{Ticket\.\[Age,Articles,Changed,ContactID,Created,CreateTimeUnix,DynamicFields,OrganisationID,PriorityID,QueueID,StateID,TypeID/;
    my $ChangeTarget = '/tickets/*{Ticket.[Age,Articles,Changed,ContactID,Created,CreateTimeUnix,DynamicFields,OrganisationID,PriorityID,QueueID,StateID,TypeID,TicketNumber,Title]}';

    my $AllOk = 1;
    my $RoleID = $RoleList{Customer};
    if (!$RoleID) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Unable to find role "Customer"!'
        );
        $AllOk = 0;
    }

    my $PermissionTypeID = $PermissionTypeList{"Property"};
    if (!$PermissionTypeID) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Unable to find permission type "Property"!'
        );
        $AllOk = 0;
    }

    my @PermissionIDs = $RoleObject->PermissionList(
        RoleID => $RoleID,
    );
    if (!@PermissionIDs) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Unable to find any permissions for role "Customer"!'
        );
        $AllOk = 0;
    }

    foreach my $PermissionID (@PermissionIDs) {
        my %permission = $RoleObject->PermissionGet(
            ID => $PermissionID,
        );

        if ($permission{Target} =~ $RegExTarget) {
            my $Success = $RoleObject->PermissionUpdate(
                ID     => $PermissionID,
                UserID => 1,
                Target => $ChangeTarget,
            );

            if (!$Success) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => 'Unable to update permission (role="Customer", type="Property", target="' . $permission{Target} . '"!'
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

    if ($AllOk) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'info',
            Message  => "Update to BUILDNUMBER 1424: successful!"
        );
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Update to BUILDNUMBER 1424: There have been errors!"
        );
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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
