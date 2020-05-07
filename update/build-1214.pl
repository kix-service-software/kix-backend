#!/usr/bin/perl
# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
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

use Getopt::Std;

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1214',
    },
);
my $LogObject = $Kernel::OM->Get('Log');

use vars qw(%INC);

use vars qw(%INC);

# updates permissions for role Customer
_UpdatePermissionsForRoleCustomer();

exit 0;


sub _UpdatePermissionsForRoleCustomer {
    # get database object
    my $DBObject = $Kernel::OM->Get('DB');
    my $RoleObject = $Kernel::OM->Get('Role');
    my $RoleID = $RoleObject->RoleLookup(
        Role => 'Customer'
    );

    if (!$RoleID) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Unable to find role "Customer"! Aborting.'
        );
        return;
    }

    # update existing permissions
    my $PermissionID = 0;

    $PermissionID = $RoleObject->PermissionLookup(
        RoleID => $RoleID,
        TypeID => 2,
        Target => '/tickets{Ticket.ContactID NE $CurrentUser.Contact.ID && Ticket.OrganisationID NE $CurrentUser.Contact.PrimaryOrganisationID}'
    );

    if (!$PermissionID) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Unable to find permission for target "/tickets{Ticket.ContactID NE $CurrentUser.Contact.ID && Ticket.OrganisationID NE $CurrentUser.Contact.PrimaryOrganisationID}"! Aborting.'
        );
        return;
    }

    my $IsPermissionUpdated = 0;
    $IsPermissionUpdated = $RoleObject->PermissionUpdate(
        ID     => $PermissionID,
        Target => '/tickets{Ticket.ContactID EQ $CurrentUser.Contact.ID && Ticket.OrganisationID EQ $CurrentUser.Contact.PrimaryOrganisationID}',
        Value  => 3
    );

    if (!$IsPermissionUpdated) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Unable to update permission with target "/tickets{Ticket.ContactID NE $CurrentUser.Contact.ID && Ticket.OrganisationID NE $CurrentUser.Contact.PrimaryOrganisationID}"!'
        );
        return;
    }

    $PermissionID = 0;

    $PermissionID = $RoleObject->PermissionLookup(
        RoleID => $RoleID,
        TypeID => 2,
        Target => '/tickets/*{Ticket.ContactID NE $CurrentUser.Contact.ID && Ticket.OrganisationID NE $CurrentUser.Contact.PrimaryOrganisationID}'
    );

    if (!$PermissionID) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Unable to find permission for target "/tickets/*{Ticket.ContactID NE $CurrentUser.Contact.ID && Ticket.OrganisationID NE $CurrentUser.Contact.PrimaryOrganisationID}"! Aborting.'
        );
        return;
    }

    $IsPermissionUpdated = 0;

    $IsPermissionUpdated = $RoleObject->PermissionUpdate(
        ID     => $PermissionID,
        Target => '/tickets/*{Ticket.ContactID EQ $CurrentUser.Contact.ID && Ticket.OrganisationID EQ $CurrentUser.Contact.PrimaryOrganisationID}',
        Value  => 3
    );

    if (!$IsPermissionUpdated) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Unable to update permission with target "/tickets{Ticket.ContactID NE $CurrentUser.Contact.ID && Ticket.OrganisationID NE $CurrentUser.Contact.PrimaryOrganisationID}"!'
        );
        return;
    }

    #add new permissions
    my @NewPermissions = (
        {
            TypeID => 1,
            Target => '/system/config',
            Value  => 2
        },
        {
            TypeID => 1,
            Target => '/system/config/*',
            Value  => 2
        },
        {
            TypeID => 2,
            Target => '/system/config{SysConfigOption.AccessLevel EQ external}',
            Value  => 2
        },
        {
            TypeID => 2,
            Target => '/system/config/*{SysConfigOption.AccessLevel EQ external}',
            Value  => 2
        },
    );

    my $PermissionID;
    my $AllPermsOK = 1;
    for my $p (@NewPermissions) {
        $PermissionID = $RoleObject->PermissionAdd(
            RoleID     => $RoleID,
            TypeID     => $p->{TypeID},
            Target     => $p->{Target},
            Value      => $p->{Value},
            IsRequired => 0,
            Comment    => '',
            UserID     => 1,
        );

        if (!$PermissionID) {
            $LogObject->Log(
                Priority => 'error',
                Message  => 'Could not add permission for ' . $p->{Target} . '!'
            );
            $AllPermsOK = 0;
        }
    }

    if (!$AllPermsOK) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Error during adding permissions to role. Aborting.',
        );
        return;
    }


    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp();

    return 1;
}

exit 0;

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
