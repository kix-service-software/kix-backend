# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Daemon::DaemonModules::SchedulerTaskWorker;

use strict;
use warnings;
use utf8;

use File::Path qw();
use Time::HiRes qw(sleep);

use base qw(Kernel::System::Daemon::BaseDaemon);

our @ObjectDependencies = (
    'Config',
    'DB',
    'Daemon::SchedulerDB',
    'Cache',
    'Log',
    'Main',
    'Storable',
    'Time',
);

=head1 NAME

Kernel::System::Daemon::DaemonModules::SchedulerTaskWorker - worker daemon for the scheduler

=head1 SYNOPSIS

Scheduler worker daemon

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

Create scheduler task worker object.

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # Allocate new hash for object.
    my $Self = {};
    bless $Self, $Type;

    # Get objects in constructor to save performance.
    $Self->{ConfigObject}      = $Kernel::OM->Get('Config');
    $Self->{CacheObject}       = $Kernel::OM->Get('Cache');
    $Self->{TimeObject}        = $Kernel::OM->Get('Time');
    $Self->{MainObject}        = $Kernel::OM->Get('Main');
    $Self->{DBObject}          = $Kernel::OM->Get('DB');
    $Self->{StorableObject}    = $Kernel::OM->Get('Storable');
    $Self->{SchedulerDBObject} = $Kernel::OM->Get('Daemon::SchedulerDB');

    # Disable in memory cache to be clusterable.
    $Self->{CacheObject}->Configure(
        CacheInMemory  => 0,
        CacheInBackend => 1,
    );

    # Get the NodeID from the SysConfig settings, this is used on High Availability systems.
    $Self->{NodeID} = $Self->{ConfigObject}->Get('NodeID') || 1;

    # Check NodeID, if does not match is impossible to continue.
    if ( $Self->{NodeID} !~ m{ \A \d+ \z }xms && $Self->{NodeID} > 0 && $Self->{NodeID} < 1000 ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "NodeID '$Self->{NodeID}' is invalid!",
        );
        return;
    }

    # Get pid directory.
    $Self->{PIDDir}  = $Self->{ConfigObject}->Get('Home') . '/var/run/Daemon/Scheduler/';
    $Self->{PIDFile} = $Self->{PIDDir} . "Worker-NodeID-$Self->{NodeID}.pid";

    # Check pid hash and pid file.
    return if !$Self->_WorkerPIDsCheck();

    # Get the maximum number of workers (forks to execute the tasks).
    $Self->{MaximumWorkers} = $Self->{ConfigObject}->Get('Daemon::SchedulerTaskWorker::MaximumWorkers') || 5;

    # Do not change the following values!
    # Modulo in PreRun() can be damaged after a change.
    $Self->{SleepPost} = 0.25;       # sleep 0.25 seconds after each loop
    $Self->{Discard}   = 60 * 60;    # discard every hour

    $Self->{DiscardCount} = $Self->{Discard} / $Self->{SleepPost};

    $Self->{Debug}      = $Param{Debug};
    $Self->{DaemonName} = 'Daemon: SchedulerTaskWorker';

    return $Self;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    # Check each 5 seconds.
    return 1 if $Self->{DiscardCount} % ( 5 / $Self->{SleepPost} );

    # Set running daemon cache.
    $Self->{CacheObject}->Set(
        Type           => 'DaemonRunning',
        Key            => $Self->{NodeID},
        Value          => 1,
        TTL            => 30,
        CacheInMemory  => 0,
        CacheInBackend => 1,
    );

    # Check if database is on-line.
    return 1 if $Self->{DBObject}->Ping();

    sleep 10;

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $StartTime = Time::HiRes::time();

    $Self->{CurrentWorkersCount} = scalar keys %{ $Self->{CurrentWorkers} };

    my @TaskList = $Self->{SchedulerDBObject}->TaskListUnlocked();

    if ( $Self->{Debug} && @TaskList ) {
        $Self->_Debug("unlocked tasks: ".join(',', @TaskList));
    }

    TASK:
    for my $TaskID (@TaskList) {

        if ( $Self->{Debug} ) {
            $Self->_Debug("handling TaskID: $TaskID");
            $Self->_Debug("current workers: $Self->{CurrentWorkersCount}/$Self->{MaximumWorkers}");
        }

        last TASK if $Self->{CurrentWorkersCount} >= $Self->{MaximumWorkers};

        # Disconnect database before fork.
        $Self->{DBObject}->Disconnect();

        # Create a fork of the current process
        #   parent gets the PID of the child
        #   child gets PID = 0
        my $PID = fork;

        # At the child, execute task.
        if ( !$PID ) {

            # make sure every child uses its own clean environment.
            local $Kernel::OM = Kernel::System::ObjectManager->new(
                'Kernel::System::Log' => {
                    LogPrefix => 'KIX-SchedulerTaskWorker-' . $$,
                },
            );

            # Disable in memory cache because many processes runs at the same time.
            $Kernel::OM->Get('Cache')->Configure(
                CacheInMemory  => 0,
                CacheInBackend => 1,
            );

            my $SchedulerDBObject = $Kernel::OM->Get('Daemon::SchedulerDB');

            # Try to lock the task.
            my $LockSucess = $SchedulerDBObject->TaskLock(
                TaskID => $TaskID,
                NodeID => $Self->{NodeID},
                PID    => $$,
            );

            exit 1 if !$LockSucess;

            my %Task = $SchedulerDBObject->TaskGet(
                TaskID => $TaskID,
            );

            # Do error handling.
            if ( !%Task || !$Task{Type} || !$Task{Data} || ref $Task{Data} ne 'HASH' ) {

                $SchedulerDBObject->TaskDelete(
                    TaskID => $TaskID,
                );

                my $TaskName = $Task{Name} || '';
                my $TaskType = $Task{Type} || '';

                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Task $TaskType $TaskName ($TaskID) was deleted due missing task data!",
                );

                exit 1;
            }

            my $TaskHandlerModule = $Kernel::OM->GetModuleFor('Daemon::DaemonModules::SchedulerTaskWorker::' . $Task{Type});

            my $TaskHandlerObject;
            eval {

                $Kernel::OM->ObjectParamAdd(
                    $TaskHandlerModule => {
                        Debug => $Self->{Debug},
                    },
                );

                $TaskHandlerObject = $Kernel::OM->Get($TaskHandlerModule);
            };

            # Do error handling.
            if ( !$TaskHandlerObject ) {

                $SchedulerDBObject->TaskDelete(
                    TaskID => $TaskID,
                );

                my $TaskName = $Task{Name} || '';
                my $TaskType = $Task{Type} || '';

                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Task $TaskType $TaskName ($TaskID) was deleted due missing handler object!",
                );

                exit 1;
            }

            if ( $Self->{Debug} ) {
                $Self->_Debug("running task \"$Task{Name}\" (TaskID: $TaskID, Type: $Task{Type})");
            }

            $TaskHandlerObject->Run(
                TaskID   => $TaskID,
                TaskName => $Task{Name} || '',
                Data     => $Task{Data},
            );

            # do everything that have to be done afterwards
            $Kernel::OM->CleanUp();

            $SchedulerDBObject->TaskDelete(
                TaskID => $TaskID,
            );

            if ( $Self->{Debug} ) {
                $Self->_Debug(sprintf "task \"$Task{Name}\" (TaskID: $TaskID, Type: $Task{Type}) finished in %i ms", (Time::HiRes::time() - $StartTime) * 1000);
            }

            exit 0;
        }

        # Check if fork was not possible.
        if ( $PID < 0 ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Could not create a child process (worker) for task id $TaskID!",
            );
            next TASK;
        }

        # Populate current workers hash to the parent knows witch task is executing each worker.
        $Self->{CurrentWorkers}->{$PID} = {
            PID       => $PID,
            TaskID    => $TaskID,
            StartTime => $Self->{TimeObject}->SystemTime(),
        };

        $Self->{CurrentWorkersCount}++;
    }

    return 1;
}

sub PostRun {
    my ( $Self, %Param ) = @_;

    sleep $Self->{SleepPost};

    # Check pid hash and pid file after sleep time to give the workers time to finish.
    return if !$Self->_WorkerPIDsCheck();

    $Self->{DiscardCount}--;

    # if ( $Self->{Debug} ) {
    #     print "  $Self->{DaemonName} Discard Count: $Self->{DiscardCount}\n";
    # }

    # Update task locks and remove expired each 60 seconds.
    if ( !int $Self->{DiscardCount} % ( 60 / $Self->{SleepPost} ) ) {

        # Extract current working task IDs.
        my @LockedTaskIDs = map { $Self->{CurrentWorkers}->{$_}->{TaskID} } sort keys %{ $Self->{CurrentWorkers} };

        # Update locks (only for this node).
        if (@LockedTaskIDs) {
            if ( $Self->{Debug} ) {
                $Self->_Debug("updating locks for task ids: ".join(',', @LockedTaskIDs));
            }
            $Self->{SchedulerDBObject}->TaskLockUpdate(
                TaskIDs => \@LockedTaskIDs,
            );
        }

        if ( $Self->{Debug} ) {
            $Self->_Debug("unlocking expired tasks");
        }

        # Unlock expired tasks (for all nodes).
        $Self->{SchedulerDBObject}->TaskUnlockExpired();
    }

    # Remove obsolete tasks before destroy.
    if ( $Self->{DiscardCount} == 0 ) {
        if ( $Self->{Debug} ) {
            $Self->_Debug("cleaning up tasks");
        }
        $Self->{SchedulerDBObject}->TaskCleanup();
    }

    return if $Self->{DiscardCount} <= 0;
    return 1;
}

sub Summary {
    my ( $Self, %Param ) = @_;

    return $Self->{SchedulerDBObject}->TaskSummary();
}

sub _WorkerPIDsCheck {
    my ( $Self, %Param ) = @_;

    # Check pid directory.
    if ( !-e $Self->{PIDDir} ) {

        File::Path::mkpath( $Self->{PIDDir}, 0, 0770 );    ## no critic

        if ( !-e $Self->{PIDDir} ) {

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Can't create directory '$Self->{PIDDir}': $!",
            );

            return;
        }
    }

    # Load current workers initially.
    if ( !defined $Self->{CurrentWorkers} ) {

        # read pid file
        if ( -e $Self->{PIDFile} ) {

            my $PIDFileContent = $Self->{MainObject}->FileRead(
                Location        => $Self->{PIDFile},
                Mode            => 'binmode',
                Type            => 'Local',
                Result          => 'SCALAR',
                DisableWarnings => 1,
            );

            # Deserialize the content of the PID file.
            if ($PIDFileContent) {

                my $WorkerPIDs = $Self->{StorableObject}->Deserialize(
                    Data => ${$PIDFileContent},
                ) || {};

                $Self->{CurrentWorkers} = $WorkerPIDs;
            }
        }

        $Self->{CurrentWorkers} ||= {};
    }

    # Check worker PIDs.
    WORKERPID:
    for my $WorkerPID ( sort keys %{ $Self->{CurrentWorkers} } ) {

        # Check if PID is still alive.
        next WORKERPID if kill 0, $WorkerPID;

        delete $Self->{CurrentWorkers}->{$WorkerPID};
    }

    $Self->{WrittenPids} //= 'REWRITE REQUIRED';

    my $PidsString = join '-', sort keys %{ $Self->{CurrentWorkers} };
    $PidsString ||= '';

    # Return if nothing has changed.
    return 1 if $PidsString eq $Self->{WrittenPids};

    # Update pid file.
    if ( %{ $Self->{CurrentWorkers} } ) {

        # Serialize the current worker hash.
        my $CurrentWorkersString = $Self->{StorableObject}->Serialize(
            Data => $Self->{CurrentWorkers},
        );

        # Write new pid file.
        my $Success = $Self->{MainObject}->FileWrite(
            Location   => $Self->{PIDFile},
            Content    => \$CurrentWorkersString,
            Mode       => 'binmode',
            Type       => 'Local',
            Permission => '600',
        );

        return if !$Success;
    }
    elsif ( -e $Self->{PIDFile} ) {

        # Remove empty file.
        return if !unlink $Self->{PIDFile};
    }

    # Save last written PIDs.
    $Self->{WrittenPids} = $PidsString;

    return 1;
}

sub DESTROY {
    my $Self = shift;

    return 1;
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
