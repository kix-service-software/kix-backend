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
        LogPrefix => 'framework_update-to-build-1323',
    },
);
my $LogObject = $Kernel::OM->Get('Log');

use vars qw(%INC);

# rename Ticket Creator role
_RenameTicketCreator();

sub _RenameTicketCreator {

    my $RoleObject = $Kernel::OM->Get('Role');

    my $RoleID = $RoleObject->RoleLookup(
        Role => 'Ticket Creator',
    );

    if ($RoleID) {
        my %RoleData = $RoleObject->RoleGet(
            ID => $RoleID,
        );

        if (IsHashRefWithData(\%RoleData)) {
            my $Success = $RoleObject->RoleUpdate(
                %RoleData,
                Name    => 'Webform Ticket Creator',
                Comment => 'allows to create new tickets by using the "Customer Portal Light" webform mechanism',
                UserID  => 1,
            );

            if (!$Success) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Unable to update name of role 'Ticket Creator' to 'Webform Ticket Creator'!"
                );
            }
        }
    }

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
