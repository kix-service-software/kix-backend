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
        LogPrefix => 'framework_update-to-build-1423',
    },
);
my $LogObject = $Kernel::OM->Get('Log');

use vars qw(%INC);


_UpdateSysConfigKeys();
_AddNewPermissions();

# delete whole cache
$Kernel::OM->Get('Cache')->CleanUp();

exit 0;

sub _UpdateSysConfigKeys {
    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    my $SysConfigObject = $Kernel::OM->Get('SysConfig');

    my @Items = qw{
        ITSMConfigItem::Hook
        FAQ::FAQHook
    };

    foreach my $Key (@Items) {
        my %Option = $SysConfigObject->OptionGet(
            Name => $Key
        );
        if (!%Option) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to get option $Key from sysconfig!"
            );
            return;
        }

        my $Result = $SysConfigObject->OptionUpdate(
            %Option,
            AccessLevel => 'external',
            UserID      => 1
        );

        if (!$Result) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to update item $Key from sysconfig!"
            );
            return;
        } else {
            $LogObject->Log(
                Priority => 'info',
                Message  => "Successfully updated sysconfig (key=$Key, AccessLevel=external)!"
            );
        }
    }

    return 1;

    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp();
}

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
            Target => '/system/cmdb/classes/*{ConfigItemClass.[ID,Name]}',
            Value  => 2    # READ
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
                Message  => "Unable to add permission (role=$Permission->{Role}, type=$Permission->{Type}, target=$Permission->{Target})!"
            );
            $AllPermsOK = 0;
        } else {
            $LogObject->Log(
                Priority => 'info',
                Message  => "Successfully created a new permission (role=$Permission->{Role}, type=$Permission->{Type}, target=$Permission->{Target})!"
            );
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
