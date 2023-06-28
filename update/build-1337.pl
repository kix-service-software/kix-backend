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
        LogPrefix => 'framework_update-to-build-1337',
    },
);
my $LogObject = $Kernel::OM->Get('Log');

use vars qw(%INC);


_UpdatePermissions();
_UpdateSysConfigKeys();

# delete whole cache
$Kernel::OM->Get('Cache')->CleanUp();

exit 0;

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
                Target => '/tickets/*{Ticket.[Age,Articles,Changed,ContactID,Created,CreateTimeUnix,DynamicFields,OrganisationID,PriorityID,QueueID,StateID,TypeID]}'
            },
            Change => {
                Target => '/tickets/*{Ticket.[Age,Articles,Changed,ContactID,Created,CreateTimeUnix,DynamicFields,OrganisationID,PriorityID,QueueID,StateID,TypeID,TicketNumber]}',
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

sub _UpdateSysConfigKeys {
    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    my $SysConfigObject = $Kernel::OM->Get('SysConfig');

    my @Items = qw{
        Ticket::Hook
        Ticket::HookDivider
        DefaultLanguage
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
        }
    }

    return 1;

    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp();
}

exit 0;

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
