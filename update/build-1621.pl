#!/usr/bin/perl
# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
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
        LogPrefix => 'framework_update-to-build-1621',
    },
);

use vars qw(%INC);

_UpdateTicketAgentRole();

sub _UpdateTicketAgentRole {

    my $RoleObject = $Kernel::OM->Get('Role');
    my @Roles = ('Ticket Agent', 'Ticket Reader', 'Ticket Agent (w/o teams)');

    foreach my $RoleName ( @Roles ) {
        my $RoleID = $RoleObject->RoleLookup(Role => $RoleName);
        my $PermissionResourceTypeID = $RoleObject->PermissionTypeLookup(Name => 'Resource');
        my $PermissionObjectTypeID = $RoleObject->PermissionTypeLookup(Name => 'Object');

        if ( $RoleID ) {
            if ( $PermissionResourceTypeID ) {
                # delete permission
                my $PermissionID = $RoleObject->PermissionLookup(
                    RoleID => $RoleID,
                    TypeID => $PermissionResourceTypeID,
                    Target => '/reporting/reports/*'
                );

                if ( $PermissionID ) {
                    my $Success = $RoleObject->PermissionDelete(
                        ID      => $PermissionID,
                        UserID  => 1
                    );            
                }
            }

            if ( $PermissionObjectTypeID ) {
                # update permission
                my $ObjectPermissionID = $RoleObject->PermissionLookup(
                    RoleID => $RoleID,
                    TypeID => $PermissionObjectTypeID,
                    Target => '/reporting/reports/*{Report.DefinitionID IN [3,4,5,6,7,8]}'
                );

                if ( $ObjectPermissionID ) {
                    my $Success = $RoleObject->PermissionUpdate(
                        ID     => $ObjectPermissionID,
                        UserID => 1,
                        Target => '/reporting/reports/*{Report.DefinitionID !IN [3,4,5,6,7,8]}',
                        Value  => 0
                    );

                    if ( !$Success ) {
                        $Kernel::OM->Get('Log')->Log(
                            Priority => 'error',
                            Message  => 'Unable to update permission to target "/reporting/reports/*{Report.DefinitionID !IN [3,4,5,6,7,8]}"!'
                        );
                    }
                    else {
                        $Kernel::OM->Get('Log')->Log(
                            Priority => 'info',
                            Message  => "Updated permission ID $ObjectPermissionID successfully!"
                        );
                    }
                } else {
                    $Kernel::OM->Get('Log')->Log(
                            Priority => 'error',
                            Message  => 'No object permission /reporting/reports/*{Report.DefinitionID IN [3,4,5,6,7,8]} found!'
                        );
                }
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
