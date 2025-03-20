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
use lib dirname($Bin).'/';
use lib dirname($Bin).'/Kernel/cpan-lib';

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

# migrate column object_id from varchar to integer
_MigrateWatcherObjectID();

exit 0;


sub _MigrateWatcherObjectID {
    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # get all ticket watchers
    return if !$DBObject->Prepare(
        SQL => 'SELECT id, object_id FROM watcher',
    );

    # fetch the result
    my $Rows = $DBObject->FetchAllArrayRef(
        Columns => [ 'ID', 'ObjectID' ],
    );

    foreach my $Row (@{$Rows}) {
        my $Success = $DBObject->Do(
            SQL  => "UPDATE watcher SET object_id_int = ? WHERE id = ?",
            Bind => [ \$Row->{ObjectID}, \$Row->{ID} ],
        );
        if (!$Success) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to migrate watcher table!"
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
