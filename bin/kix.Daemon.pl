#!/usr/bin/perl
# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use Getopt::Long qw(GetOptions);
use File::Basename;
use Sys::Hostname;
use FindBin qw($RealBin);
use lib dirname($RealBin);
use lib dirname($RealBin) . '/Kernel/cpan-lib';
use lib dirname($RealBin) . '/plugins';

use File::Path qw(rmtree);
use Time::HiRes qw(sleep);
use Fcntl qw(:flock);

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);

print STDOUT "kix.Daemon.pl - the KIX daemon\n";

local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'kix.Daemon.pl',
    },
);

# Don't allow to run these scripts as root, except we are in a test run
if ( $> == 0 && !$ENV{UnitTest} ) {    # $EFFECTIVE_USER_ID
    print STDERR
        "Error: You cannot run kix.Daemon.pl as root.";
    exit 1;
}

my $Command = shift @ARGV;

my %Options;
GetOptions(
    'debug=s'      => \$Options{Debug},
    'force'        => \$Options{Force},
    'no-daemonize' => \$Options{NoDaemon},
    'help'         => \$Options{Help},
);

if ( !$Command || $Options{Help} ) {
    PrintUsage();
    exit 0;
}

# get pid directory
my $PIDDir  = $Kernel::OM->Get('Config')->Get('Home') . '/var/run/';
my $PIDFile = $PIDDir . "Daemon.pid";
my $PIDFH;

# get default log directory
my $LogDir = $Kernel::OM->Get('Config')->Get('Daemon::Log::LogPath') || $Kernel::OM->Get('Config')->Get('Home') . '/var/log/Daemon';

if ( !-d $LogDir ) {
    File::Path::mkpath( $LogDir, 0, 0770 );    ## no critic

    if ( !-d $LogDir ) {
        print STDERR "Failed to create path: $LogDir";
        exit 1;
    }
}

# tell everyone about the environment we're running in
$ENV{IsDaemon} = 1;

# to wait until all daemon stops (in seconds)
my $DaemonStopWait = 30;

# the child processes
my %DaemonModules;

# trigger a reload if needed
my $ReloadRequired = 0;

# check for debug mode
my %DebugDaemons;
my $Debug;
if ( $Options{Debug} ) {
    $Debug = 1;

    # if no more arguments, then use debug mode for all daemons
    if ( lc $Options{Debug} eq 'all' ) {
        $DebugDaemons{All} = 1;
    }

    # otherwise set debug mode specific for named daemons
    else {

        # remember debug mode for each daemon
        foreach my $Daemon ( split(/,/, $Options{Debug}) ) {
            $DebugDaemons{ $Daemon } = 1;
        }
    }
}

# check for action
if ( lc $Command eq 'start' ) {
    exit 1 if !Start();
    exit 0;
}
elsif ( lc $Command eq 'stop' ) {
    exit 1 if !Stop();
    exit 0;
}
elsif ( lc $Command eq 'status' ) {
    exit 1 if !Status();
    exit 0;
}
else {
    PrintUsage();
    exit 0;
}

sub PrintUsage {
    my $UsageText = "Usage:\n";
    $UsageText .= " kix.Daemon.pl <ACTION> [--debug=<SchedulerModules>] [--force] [--no-daemonize]\n";
    $UsageText .= "\nActions:\n";
    $UsageText .= sprintf " %-30s - %s", 'start', 'Starts the daemon process' . "\n";
    $UsageText .= sprintf " %-30s - %s", 'stop', 'Stops the daemon process' . "\n";
    $UsageText .= sprintf " %-30s - %s", 'status', 'Shows daemon process current state' . "\n";
    $UsageText .= "\nNote:\n";
    $UsageText
        .= " In debug mode if a daemon module is specified the debug mode will be activated only for that daemon.\n";
    $UsageText .= "\n kix.Daemon.pl start --debug=all|SchedulerTaskWorker,SchedulerCronTaskManager,...\n\n";
    $UsageText
        .= "\n A forced start cleans up everything a previous daemon crash or stop might have left before starting the daemon.\n";
    $UsageText .= "\n kix.Daemon.pl start --force\n\n";
    $UsageText
        .= "\n A forced stop reduces the time the main daemon waits other daemons to stop from normal 30 seconds to 5.\n";
    $UsageText .= "\n kix.Daemon.pl stop --force\n\n";
    print STDOUT "$UsageText\n";

    return 1;
}

sub Start {

    if ( !$Options{NoDaemon} ) {
        # create a fork of the current process
        # parent gets the PID of the child
        # child gets PID = 0
        my $DaemonPID = fork;

        # check if fork was not possible
        die "Cannot create daemon process: $!" if !defined $DaemonPID || $DaemonPID < 0;

        # close parent gracefully
        exit 0 if $DaemonPID;
    }

    if ( $Options{Force} ) {
        print "Executing forced start of daemon...\n";
        # kill processes
        my $PID = _ReadPID();
        if ( $PID ) {
            # stop the running daemon
            Stop();
            # cleanup the pid directory
            my $Directory = dirname($PIDFile) . '/Daemon';
            rmtree($Directory) or die "Cannot cleanup '$Directory' : $!";
        }
    }

    # lock PID
    my $LockSuccess = _PIDLock();

    if ( !$LockSuccess ) {
        print "Daemon already running!\n";
        exit 0;
    }

    # run child and repeat if a reload is required
    do {
        _Run();
    } while ( $ReloadRequired );

    # cleanup
    $Kernel::OM->Get('Cache')->Delete(
        Type  => 'Daemon',
        Key   => $$
    );

    return 1;
}

sub Stop {
    my %Param = @_;

    my $RunningDaemonPID = _PIDUnlock();

    if ($RunningDaemonPID) {

        if ($Options{Force}) {

            # send TERM signal to running daemon
            kill 15, $RunningDaemonPID;
        }
        else {
            # send INT signal to running daemon
            kill 2, $RunningDaemonPID;
        }

    }

    # wait for the main process to stop
    while ( $RunningDaemonPID && kill 0, $RunningDaemonPID ) { sleep 1 }

    # cleanup
    $Kernel::OM->Get('Cache')->Delete(
        Type  => 'Daemon',
        Key   => $$
    );

    print "Daemon stopped\n";

    return 1;
}

sub Status {
    my %Param = @_;

    if ( -e $PIDFile ) {

        # read existing PID file
        open my $FH, '<', $PIDFile;    ## no critic

        # try to lock the file exclusively
        if ( !flock( $FH, LOCK_EX | LOCK_NB ) ) {

            # if no exclusive lock, daemon might be running, send signal to the PID
            my $RegisteredPID = do { local $/; <$FH> };
            close $FH;

            if ($RegisteredPID) {

                # check if process is running
                my $RunningPID = kill 0, $RegisteredPID;

                if ($RunningPID) {
                    print "Daemon running\n";
                    return 1;
                }
            }
        }
        else {

            # if exclusive lock is granted, then it is not running
            close $FH;
        }
    }

    _PIDUnlock();

    print "Daemon not running\n";
    return;
}

sub _Run {

    # no reload triggert atm
    $ReloadRequired = 0;

    # discard cache object to get a new one
    $Kernel::OM->ObjectsDiscard(
        Objects => ['Cache']
    );

    # register the process - tell the system we are up and running
    $Kernel::OM->Get('Cache')->Set(
        Type  => 'Daemon',
        Key   => $$,
        Value => {
            PID  => $$,
            Host => hostname,
        }
    );

    # get daemon modules from SysConfig
    my $DaemonModuleConfig = $Kernel::OM->Get('Config')->Get('DaemonModules') || {};

    # create daemon module hash
    MODULE:
    for my $Module ( sort keys %{$DaemonModuleConfig} ) {

        next MODULE if !$Module;
        next MODULE if !$DaemonModuleConfig->{$Module};
        next MODULE if ref $DaemonModuleConfig->{$Module} ne 'HASH';
        next MODULE if !$DaemonModuleConfig->{$Module}->{Module};

        $DaemonModules{ $DaemonModuleConfig->{$Module}->{Module} } = {
            PID  => 0,
            Name => $Module,
        };
    }

    my $DaemonChecker = 1;
    local $SIG{INT} = sub { $DaemonChecker = 0; };
    local $SIG{TERM} = sub { $DaemonChecker = 0; $DaemonStopWait = 5; };
    local $SIG{CHLD} = "IGNORE";

    print "Daemon started\n";

    while ($DaemonChecker) {
        my $Cache = $Kernel::OM->Get('Cache')->Get(
            Type  => 'Daemon',
            Key   => $$
        );

        # check for reload (either triggert externally or we've los our registration in cache)
        if ( !IsHashRefWithData($Cache) || (IsHashRefWithData($Cache) && $Cache->{Reload}) ) {
            print "Reload triggered\n";
            $ReloadRequired = 1;
            last;
        }

        MODULE:
        for my $Module ( sort keys %DaemonModules ) {

            next MODULE if !$Module;

            # check if daemon is still alive
            my $RunningPID = kill 0, $DaemonModules{$Module}->{PID};

            if ( $DaemonModules{$Module}->{PID} && !$RunningPID ) {
                print "Module $Module not running (PID $DaemonModules{$Module}->{PID})\n";
                $DaemonModules{$Module}->{PID} = 0;
            }

            next MODULE if $DaemonModules{$Module}->{PID};

            # fork daemon process
            my $ChildPID = fork;

            if ( !$ChildPID ) {

                exit _RunModule(
                    Module     => $Module,
                    ModuleName => $DaemonModules{$Module}->{Name}
                );
            }
            else {

                if ($Debug) {
                    _Debug("Registered Daemon $Module with PID $ChildPID");
                }

                $DaemonModules{$Module}->{PID} = $ChildPID;
            }
        }

        # sleep 0.1 seconds to protect the system of a 100% CPU usage if one daemon
        # module is damaged and produces hard errors
        sleep 0.1;
    }

    # stop the child processes
    _StopChildren();

    # remove current log files without content
    _LogFilesCleanup();

    # unregister the process - tell the system we are no longer active
    print "Removing daemon registration...";
    $Kernel::OM->Get('Cache')->Delete(
        Type  => 'Daemon',
        Key   => $$
    );
    print "OK\n";

    return 1;
}

sub _RunModule {
    my (%Param) = @_;

    my $ChildRun = 1;
    local $SIG{INT}  = sub { $ChildRun = 0; };
    local $SIG{TERM} = sub { $ChildRun = 0; };
    local $SIG{CHLD} = "IGNORE";

    local $Kernel::OM = Kernel::System::ObjectManager->new(
        'Log' => {
            LogPrefix => "kix.Daemon.pl - Daemon $Param{Module}",
        },
    );

    # disable in memory cache because many processes run at the same time
    $Kernel::OM->Get('Cache')->Configure(
        CacheInMemory  => 0,
        CacheInBackend => 1,
    );

    # set daemon log files
    _LogFilesSet(
        Module => $Param{ModuleName}
    );

    my $DaemonObject;
    LOOP:
    while ($ChildRun) {
        # create daemon object if not exists
        eval {
            if (
                !$DaemonObject
                && ( $DebugDaemons{All} || $DebugDaemons{ $Param{ModuleName} } )
               )
            {
                $Kernel::OM->ObjectParamAdd(
                    $Param{Module} => {
                        Debug => 1,
                    },
                );
            }

            $DaemonObject ||= $Kernel::OM->Get($Param{Module});
        };

        # wait 10 seconds if creation of object is not possible
        if ( !$DaemonObject ) {
            sleep 10;
            last LOOP;
        }

        METHOD:
        for my $Method ( 'PreRun', 'Run', 'PostRun' ) {
            last LOOP if !eval { $DaemonObject->$Method() };
        }
    }

    return 0;
}

sub _StopChildren {
    my (%Param) = @_;

    print "Stopping child processes...\n";

    # send all daemon processes a stop signal
    MODULE:
    for my $Module ( sort keys %DaemonModules ) {

        next MODULE if !$Module;
        next MODULE if !$DaemonModules{$Module}->{PID};

        if ($Debug) {
            print "Sending stop signal to $Module with PID $DaemonModules{$Module}->{PID}\n";
        }

        kill 2, $DaemonModules{$Module}->{PID};
    }

    # wait for active daemon processes to stop (typically 30 secs, or just 5 if forced)
    WAITTIME:
    for my $WaitTime ( 1 .. $DaemonStopWait ) {

        my $ProcessesStillRunning;
        MODULE:
        for my $Module ( sort keys %DaemonModules ) {

            next MODULE if !$Module;
            next MODULE if !$DaemonModules{$Module}->{PID};

            # check if PID is still alive
            my $RunningPID = kill 0, $DaemonModules{$Module}->{PID};

            if ( !$RunningPID ) {

                # remove daemon pid from list
                $DaemonModules{$Module}->{PID} = 0;
            }
            else {

                $ProcessesStillRunning = 1;
                print "Waiting to stop $DaemonModules{$Module}->{Name} with PID $DaemonModules{$Module}->{PID}\n";
            }
        }

        last WAITTIME if !$ProcessesStillRunning;

        sleep 1;
    }

    # hard kill of all children which are not stopped after 30 seconds
    MODULE:
    for my $Module ( sort keys %DaemonModules ) {

        next MODULE if !$Module;
        next MODULE if !$DaemonModules{$Module}->{PID};

        print "Killing $Module with PID $DaemonModules{$Module}->{PID}\n";

        kill 9, $DaemonModules{$Module};
    }

    print "OK\n";

    return 1;
}

sub _PIDLock {

    # check pid directory
    if ( !-e $PIDDir ) {

        File::Path::mkpath( $PIDDir, 0, 0770 );    ## no critic

        if ( !-e $PIDDir ) {

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Can't create directory '$PIDDir': $!",
            );

            exit 1;
        }
    }
    if ( !-w $PIDDir ) {

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Don't have write permissions in directory '$PIDDir': $!",
        );

        exit 1;
    }

    if ( -e $PIDFile ) {

        # read existing PID file
        open my $FH, '<', $PIDFile;    ## no critic

        # try to get a exclusive of the pid file, if fails daemon is already running
        if ( !flock( $FH, LOCK_EX | LOCK_NB ) ) {
            close $FH;
            return;
        }

        my $RegisteredPID = do { local $/; <$FH> };
        close $FH;

        if ($RegisteredPID) {

            return 1 if $RegisteredPID eq $$;

            # check if another process is running
            my $AnotherRunningPID = kill 0, $RegisteredPID;

            return if $AnotherRunningPID;
        }
    }

    # create new PID file (set exclusive lock while writing the PIDFile)
    open my $FH, '>', $PIDFile || die "Cannot create PID file: $PIDFile\n";    ## no critic
    return if !flock( $FH, LOCK_EX | LOCK_NB );
    print $FH $$;
    close $FH;

    # keep PIDFile shared locked forever
    open $PIDFH, '<', $PIDFile || die "Cannot create PID file: $PIDFile\n";    ## no critic
    return if !flock( $PIDFH, LOCK_SH | LOCK_NB );

    return 1;
}

sub _PIDUnlock {

    return if !-e $PIDFile;

    # read existing PID file
    open my $FH, '<', $PIDFile;                                                 ## no critic

    # wait if PID is exclusively locked (and do a shared lock for reading)
    flock $FH, LOCK_SH;
    my $RegisteredPID = do { local $/; <$FH> };
    close $FH;

    unlink $PIDFile;

    return $RegisteredPID;
}

sub _LogFilesSet {
    my %Param = @_;

    # define log file names
    my $FileStdOut = "$LogDir/$Param{Module}OUT";
    my $FileStdErr = "$LogDir/$Param{Module}ERR";

    my $SystemTime = $Kernel::OM->Get('Time')->SystemTime();

    # backup old log files
    use File::Copy qw(move);
    if ( -e "$FileStdOut.log" ) {
        move( "$FileStdOut.log", "$FileStdOut-$SystemTime.log" );
    }
    if ( -e "$FileStdErr.log" ) {
        move( "$FileStdErr.log", "$FileStdErr-$SystemTime.log" );
    }

    my $RedirectSTDOUT = $Kernel::OM->Get('Config')->Get('Daemon::Log::STDOUT') || 0;
    my $RedirectSTDERR = $Kernel::OM->Get('Config')->Get('Daemon::Log::STDERR') || 0;

    # redirect STDOUT and STDERR
    if ($RedirectSTDOUT) {
        open STDOUT, '>>', "$FileStdOut.log";
    }
    if ($RedirectSTDERR) {
        open STDERR, '>>', "$FileStdErr.log";
    }

    # remove not needed log files
    my $DaysToKeep = $Kernel::OM->Get('Config')->Get('Daemon::Log::DaysToKeep') || 1;
    my $DaysToKeepTime = $SystemTime - $DaysToKeep * 24 * 60 * 60;

    my @LogFiles = glob "$LogDir/*.log";

    LOGFILE:
    for my $LogFile (@LogFiles) {

        # skip if is not a backup file
        next LOGFILE if ( $LogFile !~ m{(?: .* /)* $Param{Module} (?: OUT|ERR ) - (\d+) \.log}igmx );

        # do not delete files during keep period if they have content
        next LOGFILE if ( ( $1 > $DaysToKeepTime ) && -s $LogFile );

        # delete file
        if ( !unlink $LogFile ) {

            # log old backup file cannot be deleted
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Daemon: $Param{Module} could not delete old log file $LogFile! $!",
            );
        }
    }

    return 1;
}

sub _LogFilesCleanup {
    my %Param = @_;

    print "Cleaning up empty logfiles...";

    my @LogFiles = glob "$LogDir/*.log";

    LOGFILE:
    for my $LogFile (@LogFiles) {

        # skip if is not a backup file
        next LOGFILE if ( $LogFile !~ m{ (?: OUT|ERR ) (?: -\d+)* \.log}igmx );

        # do not delete files if they have content
        next LOGFILE if -s $LogFile;

        # delete file
        if ( !unlink $LogFile ) {

            # log old backup file cannot be deleted
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Daemon: could not delete empty log file $LogFile! $!",
            );
        }
    }

    print "OK\n";

    return 1;
}

sub _ReadPID {
    my $PID;
    if ( -e $PIDFile ) {

        # read existing PID file
        open my $FH, '<', $PIDFile;    ## no critic

        # try to get a exclusive of the pid file, if fails daemon is already running
        if ( !flock( $FH, LOCK_SH | LOCK_NB ) ) {
            close $FH;
            return;
        }

        $PID = do { local $/; <$FH> };
        close $FH;
    }
    return $PID;
}

sub _Debug {
    my ( $Message ) = @_;

    return if !$Debug;

    printf "%f (%5i) [%s] [%s] %s\n", Time::HiRes::time(), $$, "DEBUG", "Daemon", "$Message";
}

exit 0;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
