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

use Getopt::Std;

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1403',
    },
);
my $LogObject = $Kernel::OM->Get('Log');

use vars qw(%INC);


_AddNewPermissions();
_UpdatePermissions();

# delete whole cache
$Kernel::OM->Get('Cache')->CleanUp();

exit 0;

sub _AddNewPermissions {
    # get database object
    my $DBObject = $Kernel::OM->Get('DB');
    my $RoleObject = $Kernel::OM->Get('Role');

    my %RoleList           = reverse $RoleObject->RoleList();
    my %PermissionTypeList = reverse $RoleObject->PermissionTypeList();

    #add new permissions
    my @NewPermissions = (
        {
            Role   => 'Customer',
            Type   => 'Property',
            Target => '/tickets/*/articles{Article.[!*,TimeUnit]}',
            Value  => 61440    # DENY
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

sub _UpdatePermissions {
    # get database object
    my $DBObject = $Kernel::OM->Get('DB');
    my $RoleObject = $Kernel::OM->Get('Role');

    my %RoleList           = reverse $RoleObject->RoleList();
    my %PermissionTypeList = reverse $RoleObject->PermissionTypeList();

    my @PermissionUpdates = (
        {
            Permission => {
                Role   => 'Customer',
                Type   => 'Property',
                Target => '/tickets/*/articles/*{Article.[*,!Bcc,!BccRealname]}'
            },
            Change => {
                Target => '/tickets/*/articles/*{Article.[*,!Bcc,!BccRealname,!TimeUnit]}',
            }
        }
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

        # Update existing permission
        if($PermissionID) {

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
