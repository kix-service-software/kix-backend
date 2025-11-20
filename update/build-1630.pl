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
        LogPrefix => 'framework_update-to-build-1630',
    },
);

use vars qw(%INC);

_UpdateCustomerManagerRole();

sub _UpdateCustomerManagerRole {

    my $RoleObject = $Kernel::OM->Get('Role');
    my @Roles = ('Customer Manager');

    foreach my $RoleName ( @Roles ) {
        my $RoleID = $RoleObject->RoleLookup(Role => $RoleName);
        my $PermissionResourceTypeID = $RoleObject->PermissionTypeLookup(Name => 'Resource');

        if ( $RoleID ) {           

            if ( $PermissionResourceTypeID ) {            
                my $Success = $RoleObject->PermissionAdd(
                    RoleID      => $RoleID,
                    TypeID      => $PermissionResourceTypeID,
                    UserID      => 1,
                    Target      => '/system/objecticons',
                    Value       => 7
                );

                if ( !$Success ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => 'Unable to add permission to target "/system/objecticons"!'
                    );
                }
                else {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'info',
                        Message  => "Updated permission ID $RoleID successfully!"
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
