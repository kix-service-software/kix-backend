# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Daemon::DaemonModules::SchedulerTaskWorker::AsynchronousExecutor;

use strict;
use warnings;

use Time::HiRes;

use base qw(Kernel::System::Daemon::DaemonModules::BaseTaskWorker);

our @ObjectDependencies = (
    'Log',
);

=head1 NAME

Kernel::System::Daemon::DaemonModules::SchedulerTaskWorker::AsynchronousExecutor - Scheduler daemon task handler module for generic asynchronous tasks

=head1 SYNOPSIS

This task handler executes scheduler generic asynchronous tasks.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $TaskHandlerObject = $Kernel::OM->Get('Daemon::DaemonModules::SchedulerTaskWorker::AsynchronousExecutor');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    $Self->{Debug}      = $Param{Debug};
    $Self->{WorkerName} = 'Worker: AsynchronousExecutor';

    return $Self;
}

=item Run()

Performs the selected asynchronous task.

    my $Success = $TaskHandlerObject->Run(
        TaskID   => 123,
        TaskName => 'some name',                # optional
        Data     => {
            Object   => 'Some::Object::Name',
            Function => 'SomeFunctionName',
            Params   => $Params ,               # HashRef with the needed parameters
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
        NeededDataAttributes => [ 'Object', 'Function' ],
    );

    # Stop execution if an error in params is detected.
    return if !$CheckResult;

    # Stop execution if invalid params ref is detected.
    return if !ref $Param{Data}->{Params};

    my $LocalObject;
    eval {
        $LocalObject = $Kernel::OM->Get( $Param{Data}->{Object} );
    };
    if ( !$LocalObject ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Could not create a new object $Param{Data}->{Object}! - Task: $Param{TaskName}",
            );
        }
        return;
    }

    # Check if the module provide the required function().
    if ( !$LocalObject->can( $Param{Data}->{Function} ) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "$Param{Data}->{Object} does not provide $Param{Data}->{Function}()! - Task: $Param{TaskName}",
            );
        }
        return;
    }

    my $Function = $Param{Data}->{Function};

    my $ErrorMessage;

    if ( $Self->{Debug} ) {
        $Self->_Debug("executing task: $Param{TaskName}");
    }

    # Run given function on the object with the specified parameters in Data->{Params}
    eval {

        # Restore child signal to default, main daemon set it to 'IGNORE' to be able to create
        #   multiple process at the same time, but in workers this causes problems if function does
        #   system calls (on linux), since system calls returns -1. See bug#12126.
        local $SIG{CHLD} = 'DEFAULT';

        # Localize the standard error, everything will be restored after the eval block.
        local *STDERR;

        # Redirect the standard error to a variable.
        open STDERR, ">>", \$ErrorMessage;

        if ( ref $Param{Data}->{Params} eq 'ARRAY' ) {
            $LocalObject->$Function(
                @{ $Param{Data}->{Params} },
            );
        }
        else {
            $LocalObject->$Function(
                %{ $Param{Data}->{Params} // {} },
            );
        }

    };

    if ( $Self->{Debug} ) {
        $Self->_Debug(sprintf "execution finished in %i ms", (Time::HiRes::time() - $StartTime) * 1000);
    }

    # Check if there are errors.
    if ($ErrorMessage) {

        $Self->_HandleError(
            TaskName     => $Param{TaskName},
            TaskType     => 'AsynchronousExecutor',
            LogMessage   => "There was an error executing $Function() in $Param{Data}->{Object}: $ErrorMessage",
            ErrorMessage => $ErrorMessage,
        );

        return;
    }

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
