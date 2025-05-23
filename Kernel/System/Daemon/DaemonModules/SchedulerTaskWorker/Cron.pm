# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Daemon::DaemonModules::SchedulerTaskWorker::Cron;

use strict;
use warnings;

use IPC::Open3;
use Symbol;
use Time::HiRes;

use base qw(Kernel::System::Daemon::DaemonModules::BaseTaskWorker);

our @ObjectDependencies = (
    'Config',
    'Daemon::SchedulerDB',
    'Email',
    'Log',
    'Time',
);

=head1 NAME

Kernel::System::Daemon::DaemonModules::SchedulerTaskWorker::Cron - Scheduler daemon task handler module for cron like jobs

=head1 SYNOPSIS

This task handler executes scheduler tasks based in cron notation.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $TaskHandlerObject = $Kernel::OM-Get('Daemon::DaemonModules::SchedulerTaskWorker::Cron');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    $Self->{Debug}      = $Param{Debug};
    $Self->{WorkerName} = 'Worker: Cron';

    return $Self;
}

=item Run()

Performs the selected Cron task.

    my $Success = $TaskHandlerObject->Run(
        TaskID   => 123,
        TaskName => 'some name',                                        # optional
        Data     => {
            Module   => ':Console:Command::Help',
            Function => 'Execute',
            Params   => [                                               # parameters array reference
             '--force',
             '--option',
             'my option',
            ],
        },
    );

Returns:

    $Success => 1,  # or fail in case of an error

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $StartTime = Time::HiRes::time();

    # Check task params.
    my $CheckResult = $Self->_CheckTaskParams(
        %Param,
        NeededDataAttributes => [ 'Module', 'Function' ],
        DataParamsRef        => 'ARRAY',
    );

    # Stop execution if an error in params is detected.
    return if !$CheckResult;

    my $StartSystemTime = $Kernel::OM->Get('Time')->SystemTime();

    my $ModuleObject;
    eval {
        $ModuleObject = $Kernel::OM->Get( $Param{Data}->{Module} );
    };
    if ( !$ModuleObject ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Cannot create a new Object for Module: '$Param{Data}->{Module}'! - Task: $Param{TaskName}",
            );
        }
        return;
    }

    my $Function = $Param{Data}->{Function};

    # Check if the module provide the required function.
    return if !$ModuleObject->can($Function);

    my @Parameters = @{ $Param{Data}->{Params} || [] };

    # To capture the standard error.
    my $ErrorMessage;

    my $Result;

    if ( $Self->{Debug} ) {
        $Self->_Debug("executes task: $Param{TaskName}");
    }

    eval {

        # Restore child signal to default, main daemon set it to 'IGNORE' to be able to create
        #   multiple process at the same time, but in workers this causes problems if function does
        #   system calls (on linux), since system calls returns -1. See bug#12126.
        local $SIG{CHLD} = 'DEFAULT';

        # Localize the standard error, everything will be restored after the eval block.
        local *STDERR;

        # Redirect the standard error to a variable.
        open STDERR, ">>", \$ErrorMessage;

        # Disable ANSI terminal colors for console commands, then in case of an error the output
        #   will be clean.
        # Prevent used once warning, setting the variable as local and then assign the value
        #   in the next statement.
        local $Kernel::System::Console::BaseCommand::SuppressANSI;
        $Kernel::System::Console::BaseCommand::SuppressANSI = 1;

        # Run function on the module with the specified parameters in Data->{Params}
        $Result = $ModuleObject->$Function(
            @Parameters,
        );
    };

    # Get current system time (as soon as the method has been called).
    my $EndSystemTime = $Kernel::OM->Get('Time')->SystemTime();

    my $IsConsoleCommand;
    if (
        substr( $Param{Data}->{Module}, 0, length 'Console' ) eq 'Console'
        && $Function eq 'Execute'
        )
    {
        $IsConsoleCommand = 1;
    }

    my $ConsoleCommandFailure;

    # Console commands send 1 as result if fail.
    if ( $IsConsoleCommand && $Result ) {
        $ConsoleCommandFailure = 1;
    }

    my $Success = 1;

    # Check if there are errors.
    if ( $ErrorMessage || $ConsoleCommandFailure ) {

        $ErrorMessage //= '';

        $Self->_HandleError(
            TaskName     => $Param{TaskName},
            TaskType     => 'Cron',
            LogMessage   => "There was an error executing $Function() in $Param{Data}->{Module}: $ErrorMessage",
            ErrorMessage => $ErrorMessage,
        );

        $Success = 0;
    }

    # Update worker task.
    $Kernel::OM->Get('Daemon::SchedulerDB')->RecurrentTaskWorkerInfoSet(
        LastWorkerTaskID      => $Param{TaskID},
        LastWorkerStatus      => $Success,
        LastWorkerRunningTime => $EndSystemTime - $StartSystemTime,
    );

    if ( $Self->{Debug} ) {
        $Self->_Debug(sprintf "execution finished in %i ms", (Time::HiRes::time() - $StartTime) * 1000);
    }

    return $Success;
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
