# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Daemon::DaemonModules::BaseTaskWorker;

use strict;
use warnings;

our @ObjectDependencies = (
    'Config',
    'Email',
    'Log',
);

=head1 NAME

Kernel::System::Daemon::DaemonModules::BaseTaskWorker - scheduler task worker base class

=head1 SYNOPSIS

Base class for scheduler daemon task worker modules.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item _HandleError()

Creates a system error message and sends an email with the error messages form a task execution.

    my $Success = $TaskWorkerObject->_HandleError(
        TaskName     => 'some name',
        TaksTye      => 'some type',
        LogMessage   => 'some message',       # message to set in the KIX error log
        ErrorMessage => 'some message',       # message to be sent ad a body of the email, usually contains
                                              #     all messages from STDERR including tracebacks
    );

=cut

sub _HandleError {
    my ( $Self, %Param ) = @_;

    $Kernel::OM->Get('Log')->Log(
        Priority => 'error',
        Message  => $Param{LogMessage},
    );

    my $ConfigObject = $Kernel::OM->Get('Config');

    my $From = $ConfigObject->Get('NotificationSenderName') . ' <'
        . $ConfigObject->Get('NotificationSenderEmail') . '>';

    my $To = $ConfigObject->Get('Daemon::SchedulerTaskWorker::NotificationRecipientEmail') || '';

    if ( $From && $To ) {

        my $Sent = $Kernel::OM->Get('Email')->Send(
            From     => $From,
            To       => $To,
            Subject  => "KIX Scheduler Daemon $Param{TaskType}: $Param{TaskName}",
            Charset  => 'utf-8',
            MimeType => 'text/plain',
            Body     => $Param{ErrorMessage},
        );

        return $Sent;
    }

    return;
}

=item _CheckTaskParams()

Performs basic checks for common task parameters.

    my $Success = $TaskWorkerObject->_CheckTaskParams(
        TaskID               => 123,
        TaskName             => 'some name',                # optional
        Data                 => $TaskDataHasRef,
        NeededDataAttributes => ['Object', 'Function'],     # optional, list of attributes that task needs in Data hash
        DataParamsRef        => 'HASH',                     # optional, 'HASH' or 'ARRAY', kind of reference of Data->Params
    );

=cut

sub _CheckTaskParams {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(TaskID Data)) {
        if ( !$Param{$Needed} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed! - Task: " . ( $Param{TaskName} || 'undefined' ),
                );
            }
            return;
        }
    }

    # Check data.
    if ( ref $Param{Data} ne 'HASH' ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Got no valid Data! - Task: $Param{TaskName}",
            );
        }
        return;
    }

    # Check mandatory attributes in Data.
    if ( $Param{NeededDataAttributes} && ref $Param{NeededDataAttributes} eq 'ARRAY' ) {

        for my $Needed ( @{ $Param{NeededDataAttributes} } ) {
            if ( !$Param{Data}->{$Needed} ) {
                if ( !$Param{Silent} ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => "Need Data->$Needed! - Task: $Param{TaskName}",
                    );
                }
                return;
            }
        }
    }

    # Check the structure of Data params.
    if ( $Param{DataParamsRef} ) {

        if ( $Param{Data}->{Params} && ref $Param{Data}->{Params} ne uc $Param{DataParamsRef} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Data->Params is invalid, reference is not $Param{DataParamsRef}! - Task: $Param{TaskName}",
                );
            }
            return;
        }
    }

    return 1;
}

sub _Debug {
    my ( $Self, $Message ) = @_;

    return if !$Self->{Debug};

    printf "%f (%5i) [%s] [%s] %s\n", Time::HiRes::time(), $$, "DEBUG", $Self->{WorkerName}, "$Message";
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
