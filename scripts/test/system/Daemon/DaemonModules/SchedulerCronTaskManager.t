# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
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

# get needed objects
## IMPORTANT - First get Daemon::DaemonModules::SchedulerCronTaskManager object,
## or it will not use the same config object as the test somehow
my $TaskManagerObject = $Kernel::OM->Get('Daemon::DaemonModules::SchedulerCronTaskManager');
my $CacheObject       = $Kernel::OM->Get('Cache');
my $TaskWorkerObject  = $Kernel::OM->Get('Daemon::DaemonModules::SchedulerTaskWorker');
my $SchedulerDBObject = $Kernel::OM->Get('Daemon::SchedulerDB');
my $Helper            = $Kernel::OM->Get('UnitTest::Helper');
my $ConfigObject      = $Kernel::OM->Get('Config');

my $Home = $ConfigObject->Get('Home');

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

# Wait for slow systems
print "Waiting at most $SleepTime s until pending tasks are executed\n";
ACTIVESLEEP:
for my $Seconds ( 1 .. $SleepTime ) {
    $TaskWorkerObject->PreRun();
    $TaskWorkerObject->Run();
    $TaskWorkerObject->PostRun();

    my @List = $SchedulerDBObject->TaskList();

    last ACTIVESLEEP if !scalar @List;

    print "Waiting for $Seconds seconds...\n";
    sleep 1;
}

# get original Cron settings
my $OriginalSettings = $ConfigObject->Get('Daemon::SchedulerCronTaskManager::Task') || {};

# remove all Cron jobs from config
$ConfigObject->Set(
    Key   => 'Daemon::SchedulerCronTaskManager::Task',
    Value => {},
);

# freeze time
$Helper->FixedTimeSet();

my $TimeObject = $Kernel::OM->Get('Time');
my ( $Sec, $Min, $Hour, $Day, $Month, $Year, $WeekDay ) = $TimeObject->SystemTime2Date(
    SystemTime => $TimeObject->SystemTime(),
);

my $SecsDiff = $Sec - 60;

# go back in time to have 0 seconds in the current minute
$Helper->FixedTimeAddSeconds($SecsDiff);

# get random ID
my $RandomID = $Helper->GetRandomID();

my @Tests = (
    {
        Name    => 'No Schedule',
        CronJob => {
            Name => 'NoSchedule' . $RandomID,
            Data => {
                TaskName => 'NoSchedule' . $RandomID,
                Module   => 'Kernel::System::Console::Command::Admin::Installation::ListPlugins',
                Function => 'Execute',
            },
        },
        Silent  => 1,
        TaskAdd => 0,
    },
    {
        Name    => 'Wrong Schedule',
        CronJob => {
            Name => 'WrongSchedue' . $RandomID,
            Data => {
                TaskName => 'NoSchedule' . $RandomID,
                Module   => 'Kernel::System::Console::Command::Admin::Installation::ListPlugins',
                Function => 'Execute',
                Schedule => '\1 * * * *',
            },
        },
        Silent  => 1,
        TaskAdd => 0,
    },

    # Test block (this tests needs to be run together in the same order)
    {
        Name    => 'All Minutes',
        CronJob => {
            Name => 'CronAllMinutes' . $RandomID,
            Data => {
                TaskName => 'CronAllMinutes' . $RandomID,
                Module   => 'Kernel::System::Console::Command::Admin::Installation::ListPlugins',
                Function => 'Execute',
                Params   => [ '--quiet' ],
                Schedule => '* * * * *',
            },
        },
        TaskAdd  => 1,
        KeepCron => 1,
    },
    {
        Name       => 'All Minutes (same minute)',
        CronName   => 'CronAllMinutes' . $RandomID,
        TaskAdd    => 0,
        SecondsAdd => 50,
        KeepCron   => 1,
    },
    {
        Name     => 'All Minutes (same minute w/o cache)',
        CronName => 'CronAllMinutes' . $RandomID,
        TaskAdd  => 0,
        NoCache  => 1,
        KeepCron => 1,
    },
    {
        Name       => 'All Minutes (next minute)',
        CronName   => 'CronAllMinutes' . $RandomID,
        TaskAdd    => 1,
        SecondsAdd => 10,
    },

    # Test block end

);

TESTCASE:
for my $Test (@Tests) {

    my $CronName;

    # create a Cron job if needed
    if ( $Test->{CronJob} ) {
        my $CronAdd = $ConfigObject->Set(
            Key   => "Daemon::SchedulerCronTaskManager::Task###$Test->{CronJob}->{Name}",
            Value => $Test->{CronJob}->{Data},
        );
        $Self->True(
            $CronAdd,
            "$Test->{Name} Cron setting added - for Cron job '$Test->{CronJob}->{Name}' with true",
        );

        $CronName = $Test->{CronJob}->{Name};

        # run the task manager
        my $RunSuccess = $TaskManagerObject->Run(
            Silent => $Test->{Silent},
        );
        $Self->True(
            $RunSuccess,
            "$Test->{Name} task manager Run() - with true (this will create the recurrent task but not execution)",
        );

        my $StartSystemTime = $TimeObject->SystemTime();
        my ( $Sec, $Min, $Hour, $Day, $Month, $Year, $WeekDay ) = $TimeObject->SystemTime2Date(
            SystemTime => $StartSystemTime,
        );
        my $SecondsAdd = ( 60 - $Sec );
        $Helper->FixedTimeAddSeconds($SecondsAdd);
        my $EndSystemTime = $TimeObject->SystemTime();
        print("  Added $SecondsAdd seconds to time (initial adjustment) from $StartSystemTime to $EndSystemTime\n");

    }

    $CronName //= $Test->{CronName} || '';

    # add seconds if needed
    if ( $Test->{SecondsAdd} ) {
        my $StartSystemTime = $TimeObject->SystemTime();
        $Helper->FixedTimeAddSeconds( $Test->{SecondsAdd} );
        my $EndSystemTime = $TimeObject->SystemTime();
        print("  Added $Test->{SecondsAdd} seconds to time from $StartSystemTime to $EndSystemTime\n");
    }

    # cleanup Task Manager Cache
    my $Cache;
    if ( $Test->{NoCache} ) {
        $Cache = $CacheObject->Get(
            Type           => 'SchedulerDBRecurrentTaskExecute',
            Key            => $CronName . '::Cron',
            CacheInMemory  => 0,
            CacheInBackend => 1,
        );
        $CacheObject->CleanUp(
            Type => 'SchedulerDBRecurrentTaskExecute',
        );
        print "  Cache cleared before task manager execution...\n"
    }

    # run the task manager
    my $RunSuccess = $TaskManagerObject->Run(
        Silent => $Test->{Silent},
    );
    $Self->True(
        $RunSuccess,
        "$Test->{Name} task manager Run() - with true",
    );

    # return the cache as it was
    if (
        $Test->{NoCache}
        && defined( $Cache )
    ) {
        $CacheObject->Set(
            Type           => 'SchedulerDBRecurrentTaskExecute',
            Key            => $CronName . '::Cron',
            Value          => $Cache,
            TTL            => 60 * 5,
            CacheInMemory  => 0,
            CacheInBackend => 1,
        );
        print "  Cache restored after task manager execution...\n";
    }

    my @List = $SchedulerDBObject->TaskList(
        Type => 'Cron',
    );

    my @FilteredList = grep { $_->{Name} eq $CronName } @List;

    if ( $Test->{TaskAdd} ) {
        $Self->Is(
            scalar @FilteredList,
            1,
            "$Test->{Name} - task manager creates one task",
        );

        local $SIG{CHLD} = "IGNORE";

        # wait until task is executed
        ACTIVESLEEP:
        for my $Sec ( 1 .. 120 ) {

            # run the worker
            $TaskWorkerObject->Run();
            $TaskWorkerObject->_WorkerPIDsCheck();

            @List = $SchedulerDBObject->TaskList(
                Type => 'Cron',
            );

            @FilteredList = grep {$CronName} @List;

            last ACTIVESLEEP if !scalar @FilteredList;

            sleep 1;

            print "  Waiting $Sec secs for the task to be executed\n";
        }

        @List = $SchedulerDBObject->TaskList(
            Type => 'Cron',
        );

        @FilteredList = grep {$CronName} @List;
        $Self->Is(
            scalar @FilteredList,
            0,
            "$Test->{Name} - task worker execute the task",
        );

    }
    else {
        $Self->Is(
            scalar @FilteredList,
            0,
            "$Test->{Name} - task manager should not create any tasks"
        );

    }

    next TESTCASE if $Test->{KeepCron};

    # remove all Cron jobs from config
    my $CronDelete = $ConfigObject->Set(
        Key   => 'Daemon::SchedulerCronTaskManager::Task',
        Value => {},
    );
    $Self->True(
        $CronDelete,
        "$Test->{Name} Delete Cron Tasks - with true",
    );

    # recurrent task delete
    @List = $SchedulerDBObject->RecurrentTaskList(
        Type => 'Cron',
    );

    @FilteredList = grep { $_->{Name} eq $CronName } @List;

    TASK:
    for my $Task (@FilteredList) {
        next TASK if $Task->{Type} ne 'Cron';
        next TASK if $Task->{Name} ne $CronName;

        my $TaskID = $Task->{TaskID};

        my $Success = $SchedulerDBObject->RecurrentTaskDelete(
            TaskID => $TaskID,
        );
        $Self->True(
            $Success,
            "RecurrentTaskDelete() - for $TaskID with true",
        );
    }
}

# cleanup
my $CleanupSuccess = $SchedulerDBObject->CronTaskCleanup();
$Self->True(
    $CleanupSuccess,
    "CronTaskCleanup() - executed with true",
);

# CronTaskToExecute() tests
my $CronName = 'CronAllMinutes' . $RandomID;

my $CronAdd = $ConfigObject->Set(
    Key   => "Daemon::SchedulerCronTaskManager::Task###$CronName",
    Value => {
        TaskName => $CronName,
        Module   => 'Admin::Package::List',
        Function => 'run',
        Schedule => '* * * * *',
    },
);
$Self->True(
    $CronAdd,
    "Cron setting added - for Cron job '$CronName' with true",
);

my %TestJobNames = (
    "CronAllMinutes$RandomID" => 1,
    "UnitTest$RandomID"       => 1,
    "Test$RandomID"           => 1,
    "SafeToDelete$RandomID"   => 1,
);

# get db object
my $DBObject = $Kernel::OM->Get('DB');

my $SystemTime = $TimeObject->SystemTime();

# add tasks
for my $Name ( sort keys %TestJobNames ) {
    my $AddSucess = $DBObject->Do(
        SQL => "
            INSERT INTO scheduler_recurrent_task
                (name, task_type, last_execution_time, lock_key, create_time, change_time)
            VALUES
                (?, ?, current_timestamp, 0, current_timestamp, current_timestamp)",
        Bind => [
            \$Name,
            \'Cron',
        ],
    );
    $Self->True(
        $AddSucess,
        "Recurrent task added - for Cron job '$Name' with true",
    );
}

# make sure all task are listed
my @List = $SchedulerDBObject->RecurrentTaskList(
    Type => 'Cron',
);

my %FilteredTaskNames = map { $_->{Name} => 1 } grep { $TestJobNames{ $_->{Name} } } @List;

for my $Name ( sort keys %TestJobNames ) {
    $Self->True(
        $FilteredTaskNames{$Name},
        "Task $Name exists with true",
    );
}

# remove fake test tasks
$CleanupSuccess = $SchedulerDBObject->CronTaskCleanup();
$Self->True(
    $CleanupSuccess,
    "CronTaskCleanup() - executed with true",
);

# make sure only CronAllMinutes is listed
@List = $SchedulerDBObject->RecurrentTaskList(
    Type => 'Cron',
);

%FilteredTaskNames = map { $_->{Name} => 1 } grep { $TestJobNames{ $_->{Name} } } @List;

for my $Name ( sort keys %TestJobNames ) {
    if ( $Name eq "CronAllMinutes$RandomID" ) {
        $Self->True(
            $FilteredTaskNames{$Name},
            "Task $Name exists with true",
        );
    }
    else {
        $Self->False(
            $FilteredTaskNames{$Name},
            "Task $Name exists with False",
        );
    }
}

# remove all Cron jobs from config
my $JobDelete = $ConfigObject->Set(
    Key   => 'Daemon::SchedulerCronTaskManager::Task',
    Value => {},
);
$Self->True(
    $JobDelete,
    "Removed all cron task settings - executed with true",
);

# remove all cron jobs from config
$ConfigObject->Set(
    Key   => 'Daemon::SchedulerCronTaskManager::Task',
    Value => $OriginalSettings,
);

# re-create original tasks
my $RunSuccess = $TaskManagerObject->Run();
$Self->True(
    $RunSuccess,
    "Task manager Run() - with true",
);

# also remove the task form the just removed Cron job
$CleanupSuccess = $SchedulerDBObject->CronTaskCleanup();
$Self->True(
    $CleanupSuccess,
    "CronTaskCleanup() - executed with true",
);

# start daemon if it was already running before this test
if ( $PreviousDaemonStatus =~ m{Daemon running}i ) {
    system("$Daemon start");
}

# cleanup cache
$Kernel::OM->Get('Cache')->CleanUp();

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
