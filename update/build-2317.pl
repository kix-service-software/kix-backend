#!/usr/bin/perl
# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/
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

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-2317',
    },
);

use vars qw(%INC);

_UpdateTimeAccounting();

sub _UpdateTimeAccounting {
    my ( $Self, %Param ) = @_;

    # create a new async task
    my $TaskID = $Kernel::OM->Get('Scheduler')->TaskAdd(
        Type                     => 'AsynchronousExecutor',
        Name                     => 'build-2317.pl',
        Attempts                 => 1,
        MaximumParallelInstances => 1,
        Data                     => {
            Object   => 'Kernel::System::Installation::Update::2317',
            Function => 'TimeAccountingUpdate',
            Params   => {},
        },
    );

    if ( !$TaskID ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Could not create new AsynchronousExecutor task!",
        );
        return;
    }
    
    $Kernel::OM->Get('Log')->Log(
        Priority => 'info',
        Message  => "Started AsynchronousExecutor task to update ticket accounted times.",
    );

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
