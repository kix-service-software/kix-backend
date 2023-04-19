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
        LogPrefix => 'framework_update-to-build-1430',
    },
);
my $LogObject = $Kernel::OM->Get('Log');

use vars qw(%INC);


_RemoveDuplicatePermissions();

exit 0;

sub _RemoveDuplicatePermissions {

    my $DBObject = $Kernel::OM->Get('DB');

    if ( !$DBObject->Prepare( SQL => "SELECT count(*) FROM role_permission" ) ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Unable to determine permission count!"
        );
    }

    my $Count = 0;
    while ( my @Data = $DBObject->FetchrowArray() ) {
        $Count = $Data[0];
        last;
    }

    # do the deletion of duplicates
    my $Result;
    if ( $DBObject->{'DB::Type'} eq 'mysql' ) {
        $Result = $DBObject->Do(
            SQL => 'DELETE rp FROM role_permission rp
                    INNER JOIN role_permission rp2
                    WHERE rp2.id > rp.id
                        AND rp2.role_id = rp.role_id
                        AND rp2.target = rp.target
                        AND rp2.type_id = rp.type_id
                        AND rp2.id <> rp.id'
        );
    }
    else {
        $Result = $DBObject->Do(
            SQL => 'DELETE FROM role_permission rp
                    WHERE EXISTS (
                        SELECT id FROM role_permission rp2
                        WHERE rp2.role_id = rp.role_id
                            AND rp2.target = rp.target
                            AND rp2.type_id = rp.type_id
                            AND rp2.id > rp.id
                    )'
        );
    }

    if ( !$DBObject->Prepare( SQL => "SELECT count(*) FROM role_permission" ) ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Unable to determine permission count!"
        );
    }

    my $AfterCount = 0;
    while ( my @Data = $DBObject->FetchrowArray() ) {
        $AfterCount = $Data[0];
        last;
    }

    if ( !$Result ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Unable to delete duplicate permissions!"
        );
        return;
    }
    else {
        $LogObject->Log(
            Priority => 'info',
            Message  => "Deleted " . ($Count - $AfterCount) . " duplicate permissions."
        );
    }

    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp();

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'CLEAR_CACHE',
        Namespace => 'Role.Permission'
    );

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
