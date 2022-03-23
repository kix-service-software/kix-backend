#!/usr/bin/perl
# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
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

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1566',
    },
);

use vars qw(%INC);

_UpdateRole();

exit 0;

sub _UpdateRole {

    my $LogObject  = $Kernel::OM->Get('Log');
    my $RoleObject = $Kernel::OM->Get('Role');

    my $CustomerRoleID = $RoleObject->RoleLookup(
        Role => 'Customer',
    );

    # update ticket permission
    if (!$CustomerRoleID) {
        $LogObject->Log(
            Priority => 'notice',
            Message  => 'Cannot add/update permissions (can not find role "Customer").'
        );
        return 1;
    }
    my $ObjectTypeID = $RoleObject->PermissionTypeLookup(
        Name => 'Object'
    );
    if (!$ObjectTypeID) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Cannot add/update permissions (can not find type Object).'
        );
        return;
    }
    my $CustomerTicketPermissionID = $RoleObject->PermissionLookup(
        RoleID => $CustomerRoleID,
        TypeID => $ObjectTypeID,
        Target => '/tickets/*{Ticket.OrganisationID NE $CurrentUser.Contact.PrimaryOrganisationID}'
    );
    if($CustomerTicketPermissionID) {
        my %CustomerTicketPermission = $RoleObject->PermissionGet(
            ID => $CustomerTicketPermissionID
        );
        if (IsHashRefWithData(\%CustomerTicketPermission)) {
            $CustomerTicketPermissionID = $Kernel::OM->Get('Role')->PermissionUpdate(
                %CustomerTicketPermission,
                Target => '/tickets/*{Ticket.OrganisationID !IN $CurrentUser.Contact.OrganisationIDs}',
                UserID => 1,
            );
        } else {
            $LogObject->Log(
                Priority => 'error',
                Message  => 'Cannot update permission "'. $CustomerTicketPermissionID .'" of role "Customer" (can not load its data).'
            );
            return;
        }
    }

    # add organisation permissions
    my @NewPermissions = (
        {
            Type   => 'Resource',
            Target => '/organisations',
            Value  => 2    # -R---
        },
        {
            Type   => 'Object',
            Target => '/organisations/*{Organisation.ID !IN $CurrentUser.Contact.OrganisationIDs}',
            Value  => 0    # -----
        }
    );
    my %PermissionTypeList = reverse $RoleObject->PermissionTypeList();
    foreach my $Permission (@NewPermissions) {
        my $PermissionTypeID = $PermissionTypeList{$Permission->{Type}};
        if (!$PermissionTypeID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Unable to find permission type "'.$Permission->{Type}.'"!'
            );
            next;
        }

        my $PermissionID = $RoleObject->PermissionLookup(
            RoleID => $CustomerRoleID,
            TypeID => $PermissionTypeID,
            Target => $Permission->{Target}
        );
        if (!$PermissionID) {
            $PermissionID = $RoleObject->PermissionAdd(
                RoleID     => $CustomerRoleID,
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
                    Message  => "Unable to add permission (role=Customer, type=$Permission->{Type}, target=$Permission->{Target}!"
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
