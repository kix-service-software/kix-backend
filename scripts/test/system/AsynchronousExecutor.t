# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $Home = $Kernel::OM->Get('Config')->Get('Home');

my $Daemon = $Home . '/bin/kix.Daemon.pl';

my $SleepTime = 20;

# get current daemon status
my $PreviousDaemonStatus = `$Daemon status`;

# stop daemon if it was already running before this test
if ( $PreviousDaemonStatus =~ m{Daemon running}i ) {
    `$Daemon stop`;

    my $SleepTime = 2;

    do {
        # wait to get daemon fully stopped before test continues
        print 'Sleeping ' . $SleepTime . "s\n";
        sleep $SleepTime;
    } while ( `$Daemon status` =~ m{Daemon running}i );
}

# prepare tests
my @Tests = (
    {
        Name     => 'Synchronous Call',
        Function => 'Execute',
    },
    {
        Name     => 'Asynchronous Call',
        Function => 'ExecuteAsync',
    },
    {
        Name     => 'Asynchronous Call With Object Name',
        Function => 'ExecuteAsyncWithObjectName',
    },
);

# get scheduler db object
my $SchedulerDBObject = $Kernel::OM->Get('Daemon::SchedulerDB');

# get worker object
my $WorkerObject = $Kernel::OM->Get('Daemon::DaemonModules::SchedulerTaskWorker');

# Wait for slow systems
print "Waiting at most $SleepTime s until pending tasks are executed\n";
ACTIVESLEEP:
for my $Seconds ( 1 .. $SleepTime ) {
    $WorkerObject->PreRun();
    $WorkerObject->Run();
    $WorkerObject->PostRun();

    my @List = $SchedulerDBObject->TaskList();

    last ACTIVESLEEP if !scalar @List;

    print "Waiting for $Seconds seconds...\n";
    sleep 1;
}

# get needed objects
my $AsynchronousExecutorObject = $Kernel::OM->Get('scripts::test::system::sample::AsynchronousExecutor::TestAsynchronousExecutor');

my $MainObject = $Kernel::OM->Get('Main');

my @FileRemember;
for my $Test (@Tests) {

    my $File = $Home . '/var/tmp/task_' . $Helper->GetRandomNumber();
    if ( -e $File ) {
        unlink $File;
    }
    push @FileRemember, $File;

    my $Function = $Test->{Function};

    $AsynchronousExecutorObject->$Function(
        File    => $File,
        Success => 1,
    );

    if ( $Function eq 'ExecuteAsync' || $Function eq 'ExecuteAsyncWithObjectName' ) {
        # Wait for slow systems
        print "Waiting at most $SleepTime s until unittest tasks are executed\n";
        ACTIVESLEEP:
        for my $Seconds ( 1 .. $SleepTime ) {
            $WorkerObject->PreRun();
            $WorkerObject->Run();
            $WorkerObject->PostRun();

            my @List = $SchedulerDBObject->TaskList();

            last ACTIVESLEEP if !scalar @List;

            print "Waiting for $Seconds seconds...\n";
            sleep 1;
        }
    }

    $Self->True(
        -e $File,
        "$Test->{Name} - $File exists with true",
    );

    my $ContentSCALARRef = $MainObject->FileRead(
        Location        => $File,
        Mode            => 'utf8',
        Type            => 'Local',
        Result          => 'SCALAR',
        DisableWarnings => 1,
    );

    $Self->Is(
        ${$ContentSCALARRef},
        '123',
        "$Test->{Name} - $File content match",
    );
}

# perform cleanup
for my $File (@FileRemember) {
    if ( -e $File ) {
        unlink $File;
    }
    $Self->True(
        !-e $File,
        "$File removed with true",
    );
}

# start daemon if it was already running before this test
if ( $PreviousDaemonStatus =~ m{Daemon running}i ) {
    system("$Daemon start");
}

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
