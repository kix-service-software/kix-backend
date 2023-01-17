#!/usr/bin/perl
# --
# Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
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
        LogPrefix => 'framework_update-to-build-1657',
    },
);

use vars qw(%INC);

_UpdateTicketAgentRole();

sub _UpdateTicketAgentRole {

    my $RoleObject = $Kernel::OM->Get('Role');
    my @Roles   = ('Ticket Agent', 'Ticket Reader', 'Ticket Agent (w/o teams)');
    my @Targets = ('/system/htmltopdf', '/system/htmltopdf/convert');
    foreach my $RoleName ( @Roles ) {
        my $RoleID = $RoleObject->RoleLookup(Role => $RoleName);
        my $PermissionResourceTypeID = $RoleObject->PermissionTypeLookup(Name => 'Resource');

        next if !$RoleID || !$PermissionResourceTypeID;

        for my $Target ( sort @Targets ) {
            my $PermissionID = $RoleObject->PermissionLookup(
                RoleID => $RoleID,
                TypeID => $PermissionResourceTypeID,
                Target => $Target
            );

            if ( !$PermissionID ) {
                my $Success = $RoleObject->PermissionAdd(
                    RoleID     => $RoleID,
                    TypeID     => $PermissionResourceTypeID,
                    Target     => $Target,
                    Value      => 2,
                    UserID     => 1,
                );

                if ( !$Success ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => "Unable to add permission to target $Target!"
                    );
                }
                else {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'info',
                        Message  => "Added permission ID $PermissionResourceTypeID successfully!"
                    );
                }
            } else {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Permission $PermissionResourceTypeID - $Target already exists!"
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
