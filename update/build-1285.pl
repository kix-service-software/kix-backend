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
        LogPrefix => 'framework_update-to-build-1285',
    },
);

use vars qw(%INC);

_RemoveSLAPermission();

sub _RemoveSLAPermission {

    my ($Self, %Param) = @_;

    my $LogObject = $Kernel::OM->Get('Log');
    my $RoleObject = $Kernel::OM->Get('Role');

    my $RessourceTypeID = $RoleObject->PermissionTypeLookup(
        Name => 'Resource'
    );
    if (!$RessourceTypeID) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Cannot remove SLA permissions (can not find permission type \'Ressource\').'
        );
        return;
    }

    # remove permission from Ticket Agent
    my $TicketAgentRoleID = $RoleObject->RoleLookup(
        Role => 'Ticket Agent',
    );
    if (!$TicketAgentRoleID) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Cannot remove SLA permission (can not find role \'Ticket Agent\').'
        );
        return;
    }
    my $SLAPermissionID = $RoleObject->PermissionLookup(
        RoleID => $TicketAgentRoleID,
        TypeID => $RessourceTypeID,
        Target => '/system/ticket/slas'
    );
    if($SLAPermissionID) {
        my $Result = $Kernel::OM->Get('Role')->PermissionDelete(
            ID => $SLAPermissionID
        );
    }

    # remove permission from Ticket Reader
    my $TicketReaderRoleID = $RoleObject->RoleLookup(
        Role => 'Ticket Reader',
    );
    if (!$TicketReaderRoleID) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Cannot remove SLA permission (can not find role \'Ticket Reader\').'
        );
        return;
    }
    $SLAPermissionID = $RoleObject->PermissionLookup(
        RoleID => $TicketReaderRoleID,
        TypeID => $RessourceTypeID,
        Target => '/system/ticket/slas'
    );
    if($SLAPermissionID) {
        $SLAPermissionID = $Kernel::OM->Get('Role')->PermissionDelete(
            ID => $SLAPermissionID
        );
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

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
