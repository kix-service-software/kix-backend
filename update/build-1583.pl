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

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1583',
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
        my $Target = '/tickets/*/articles/*{Article.[!To,!ToRealname,!Cc,!CcRealname,!From,!FromRealname] IF Article.ChannelID EQ 1 && Article.SenderTypeID EQ 1}';

        my $PermissionID = $RoleObject->PermissionLookup(
            RoleID => $RoleID,
            TypeID => $PermissionTypeID,
            Target => $Target
        );

        if (!$PermissionID) {
            $PermissionID = $RoleObject->PermissionAdd(
                RoleID => $RoleID,
                TypeID => $PermissionTypeID,
                Target     => $Target,
                Value      => 2,
                Comment    => 'hide communication properties in note articles (maybe personal agent email addresses)',
                UserID => 1
            );

            if (!$PermissionID) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unable to create permission (role=Customer, type=Poroperty, target=$Target)!"
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
