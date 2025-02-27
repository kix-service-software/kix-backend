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
        LogPrefix => 'framework_update-to-build-1444',
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

    my $AllOk = 1;

    # permissions to update
    my @PermissionUpdates = (
        {
            Permission => {
                Role   => 'Customer',
                Type   => 'Object',
                Target => '/tickets{Ticket.ContactID NE $CurrentUser.Contact.ID && Ticket.OrganisationID NE $CurrentUser.Contact.PrimaryOrganisationID}'
            },
            Change => {
                Target => '/tickets{Ticket.ContactID NE $CurrentUser.Contact.ID}',
            }
        },
        {
            Permission => {
                Role   => 'Customer',
                Type   => 'Object',
                Target => '/tickets/*{Ticket.ContactID NE $CurrentUser.Contact.ID && Ticket.OrganisationID NE $CurrentUser.Contact.PrimaryOrganisationID}'
            },
            Change => {
                Target => '/tickets/*{Ticket.ContactID NE $CurrentUser.Contact.ID}',
            }
        }
    );

    foreach my $Update ( @PermissionUpdates ) {
        my $RoleID = $RoleList{$Update->{Permission}->{Role}};
        if (!$RoleID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Unable to find role "'.$Update->{Permission}->{Role}.'"! Skipping...'
            );
            $AllOk = 0;
            next;
        }
        my $PermissionTypeID = $PermissionTypeList{$Update->{Permission}->{Type}};
        if (!$PermissionTypeID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Unable to find permission type "'.$Update->{Permission}->{Type}.'"! Skipping...'
            );
            $AllOk = 0;
            next;
        }

        my $PermissionID = $RoleObject->PermissionLookup(
            RoleID => $RoleID,
            TypeID => $PermissionTypeID,
            Target => $Update->{Permission}->{Target}
        );
        # nothing to do
        if (!$PermissionID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to find permission (role=$Update->{Permission}->{Role}, type=$Update->{Permission}->{Type}, target=$Update->{Permission}->{Target})! Skipping..."
            );
            $AllOk = 0;
            next;
        }

        my $Success = $RoleObject->PermissionUpdate(
            ID     => $PermissionID,
            UserID => 1,
            %{$Update->{Change}}
        );

        if (!$Success) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to update permission (role=$Update->{Permission}->{Role}, type=$Update->{Permission}->{Type}, target=$Update->{Permission}->{Target})!"
            );
            $AllOk = 0;
        }
        else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'info',
                Message  => "Updated permission ID $PermissionID!"
            );
        }
    }

    #add new permissions
    my @NewPermissions = (
        {
            Role   => 'Customer',
            Type   => 'Object',
            Target => '/tickets{Ticket.OrganisationID NE $CurrentUser.Contact.PrimaryOrganisationID}',
            Value  => 0
        },
        {
            Role   => 'Customer',
            Type   => 'Object',
            Target => '/tickets/*{Ticket.OrganisationID NE $CurrentUser.Contact.PrimaryOrganisationID}',
            Value  => 0
        },
    );

    my $PermissionID;
    foreach my $Permission (@NewPermissions) {
        my $RoleID = $RoleList{$Permission->{Role}};
        if (!$RoleID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Unable to find role "'.$Permission->{Role}.'"! Skipping...'
            );
            $AllOk = 0;
            next;
        }
        my $PermissionTypeID = $PermissionTypeList{$Permission->{Type}};
        if (!$PermissionTypeID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Unable to find permission type "'.$Permission->{Type}.'"! Skipping...'
            );
            $AllOk = 0;
            next;
        }

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
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to add permission (role=$Permission->{Role}, type=$Permission->{Type}, target=$Permission->{Target})!"
            );
            $AllOk = 0;
        } else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'info',
                Message  => "Successfully created a new permission (role=$Permission->{Role}, type=$Permission->{Type}, target=$Permission->{Target})!"
            );
        }
    }



    if ($AllOk) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'info',
            Message  => "Update to BUILDNUMBER 1444: successful!"
        );
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Update to BUILDNUMBER 1444: There have been errors!"
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
