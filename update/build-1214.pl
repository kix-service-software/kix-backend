#!/usr/bin/perl
# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
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

    my %RoleList           = reverse $RoleObject->RoleList();
    my %PermissionTypeList = reverse $RoleObject->PermissionTypeList();

    my @PermissionUpdates = (
        {
            Permission => {
                Role   => 'Customer',
                Type   => 'PropertyValue',
                Target => '/tickets{Ticket.ContactID NE $CurrentUser.Contact.ID && Ticket.OrganisationID NE $CurrentUser.Contact.PrimaryOrganisationID}'
            },
            Change => {
                Value => 0,
            }
        },
        {
            Permission => {
                Role   => 'Customer',
                Type   => 'PropertyValue',
                Target => '/tickets/*{Ticket.ContactID NE $CurrentUser.Contact.ID && Ticket.OrganisationID NE $CurrentUser.Contact.PrimaryOrganisationID}'
            },
            Change => {
                Value => 0,
            }
        },
        {
            Permission => {
                Role   => 'Customer',
                Type   => 'PropertyValue',
                Target => '/tickets/*/articles/*{Article.CustomerVisible EQ 1}',
            },
            Change => {
                Target => '/tickets/*/articles/*{Article.CustomerVisible NE 1}',
                Value  => 0,
            }
        },
        {
            Permission => {
                Role   => 'Customer',
                Type   => 'PropertyValue',
                Target => '/faq/articles/*{FAQArticle.CustomerVisible EQ 1}',
            },
            Change => {
                Target => '/faq/articles/*{FAQArticle.CustomerVisible NE 1}',
                Value  => 0,
            }
        },
    );

    foreach my $Update ( @PermissionUpdates ) {
        my $RoleID = $RoleList{$Update->{Permission}->{Role}};
        if (!$RoleID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Unable to find role "'.$Update->{Permission}->{Role}.'"!'
            );
            next;
        }
        my $PermissionTypeID = $PermissionTypeList{$Update->{Permission}->{Type}};
        if (!$PermissionTypeID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Unable to find permission type "'.$Update->{Permission}->{Type}.'"!'
            );
            next;
        }

        my $PermissionID = $RoleObject->PermissionLookup(
            RoleID => $RoleID,
            TypeID => $PermissionTypeID,
            Target => $Update->{Permission}->{Target}
        );
        # nothing to do
        next if !$PermissionID;

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
            Type   => 'Resource',
            Target => '/system/config',
            Value  => 2
        },
        {
            Role   => 'Customer',
            Type   => 'Resource',
            Target => '/system/config/*',
            Value  => 2
        },
        {
            Role   => 'Customer',
            Type   => 'PropertyValue',
            Target => '/system/config{SysConfigOption.AccessLevel NE external}',
            Value  => 0
        },
        {
            Role   => 'Customer',
            Type   => 'PropertyValue',
            Target => '/system/config/*{SysConfigOption.AccessLevel NE external}',
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

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
