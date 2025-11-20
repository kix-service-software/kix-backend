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

use Getopt::Std;
use File::Path qw(mkpath);

use Kernel::System::ObjectManager;

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'db-update-17.3.0.pl',
    },
);

use vars qw(%INC);

# migrate ticket watchers to generic watchers
_MigrateWatchers();

exit 0;


sub _MigrateWatchers {
    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # get all ticket watchers
    return if !$DBObject->Prepare(
        SQL => 'SELECT ticket_id, user_id, create_time, create_by, change_time, change_by FROM ticket_watcher',
    );

    # fetch the result
    my $Rows = $DBObject->FetchAllArrayRef(
        Columns => [ 'TicketID', 'UserID', 'CreateTime', 'CreateBy', 'ChangeTime', 'ChangeBy' ],
    );

    foreach my $Row (@{$Rows}) {
        my $Success = $DBObject->Do(
            SQL  => "
                INSERT INTO watcher (object, object_id, user_id, create_time, create_by, change_time, change_by)
                VALUES ('Ticket', ?, ?, ?, ?, ?, ?)",
            Bind => [ \$Row->{TicketID}, \$Row->{UserID}, \$Row->{CreateTime}, \$Row->{CreateBy}, \$Row->{ChangeTime}, \$Row->{ChangeBy} ],
        );
        if (!$Success) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to migrate ticket watchers!"
            );
        }
    }

    return 1;
}

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
