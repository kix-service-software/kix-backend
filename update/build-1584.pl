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
        LogPrefix => 'framework_update-to-build-1584',
    },
);

use vars qw(%INC);

_UpdateCustomerRole();

sub _UpdateCustomerRole {

    # get database object
    my $RoleObject = $Kernel::OM->Get('Role');

    my $RoleID = $RoleObject->RoleLookup(Role => 'Customer');
    my $PermissionTypeID = $RoleObject->PermissionTypeLookup(Name => 'Property');

    if ($RoleID && $PermissionTypeID) {
        # update permission
        my $Target = '/tickets/*/articles/*{Article.[*,!Bcc,!BccRealname,!TimeUnit]}';

        my $PermissionID = $RoleObject->PermissionLookup(
            RoleID => $RoleID,
            TypeID => $PermissionTypeID,
            Target => $Target
        );

        if ($PermissionID) {
            my $Success = $RoleObject->PermissionUpdate(
                ID      => $PermissionID,
                RoleID  => $RoleID,
                TypeID  => $PermissionTypeID,
                Target  => '/tickets/*/articles/*{Article.[*,!Bcc,!BccRealname,!TimeUnit,!To,!ToRealname,!Cc,!CcRealname,!From,!FromRealname]}',
                Value   => 2,
                Comment => 'hide communication properties (may be personal agent email addresses)',
                UserID  => 1
            );

            if (!$Success) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unable to update permission (role=Customer, type=Property, target=$Target)!"
                );
            }
        }

        #delete permission
        $Target = '/tickets/*/articles/*{Article.[!To,!ToRealname,!Cc,!CcRealname,!From,!FromRealname] IF Article.ChannelID EQ 1 && Article.SenderTypeID EQ 1}';
        $PermissionID = $RoleObject->PermissionLookup(
            RoleID => $RoleID,
            TypeID => $PermissionTypeID,
            Target => $Target
        );

        if ($PermissionID) {
            my $Success = $RoleObject->PermissionDelete(
                ID      => $PermissionID,
            );

            if (!$Success) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unable to delete permission (role=Customer, type=Property, target=$Target)!"
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
