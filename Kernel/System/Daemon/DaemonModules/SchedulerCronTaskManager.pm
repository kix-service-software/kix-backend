# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Daemon::DaemonModules::SchedulerCronTaskManager;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Daemon::BaseDaemon);

our @ObjectDependencies = (
    'Config',
    'Cache',
    'DB',
    'Daemon::SchedulerDB',
    'Log',
);

=head1 NAME

Kernel::System::Daemon::DaemonModules::SchedulerCronTaskManager - daemon to manage scheduler cron tasks

=head1 SYNOPSIS

Scheduler cron task daemon

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

Create scheduler cron task manager object.

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # Allocate new hash for object.
    my $Self = {};
    bless $Self, $Type;

    # Get objects in constructor to save performance.
    $Self->{ConfigObject}      = $Kernel::OM->Get('Config');
    $Self->{CacheObject}       = $Kernel::OM->Get('Cache');
    $Self->{DBObject}          = $Kernel::OM->Get('DB');
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

    # Do not change the following values!
    $Self->{SleepPost} = 20;         # sleep 20 seconds after each loop
    $Self->{Discard}   = 60 * 60;    # discard every hour

    $Self->{DiscardCount} = $Self->{Discard} / $Self->{SleepPost};

    $Self->{Debug}      = $Param{Debug};
    $Self->{DaemonName} = 'Daemon: SchedulerCronTaskManager';

    return $Self;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    # Check if database is on-line.
    return 1 if $Self->{DBObject}->Ping();

    sleep 10;

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    return if !$Self->{SchedulerDBObject}->CronTaskToExecute(
        NodeID => $Self->{NodeID},
        PID    => $$,
        Silent => $Param{Silent},
    );

    return 1;
}

sub PostRun {
    my ( $Self, %Param ) = @_;

    sleep $Self->{SleepPost};

    $Self->{DiscardCount}--;

    # if ( $Self->{Debug} ) {
    #     print "  $Self->{DaemonName} Discard Count: $Self->{DiscardCount}\n";
    # }

    if ( $Self->{Debug} ) {
        $Self->_Debug("unlocking expired cron tasks");
    }

    # Unlock long locked tasks.
    $Self->{SchedulerDBObject}->RecurrentTaskUnlockExpired(
        Type => 'Cron',
    );

    # Remove obsolete tasks before destroy.
    if ( $Self->{DiscardCount} == 0 ) {
        if ( $Self->{Debug} ) {
            $Self->_Debug("cleaning up cron tasks");
        }
        $Self->{SchedulerDBObject}->CronTaskCleanup();
    }

    return if $Self->{DiscardCount} <= 0;
    return 1;
}

sub Summary {
    my ( $Self, %Param ) = @_;

    return $Self->{SchedulerDBObject}->CronTaskSummary();
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
