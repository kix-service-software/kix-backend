# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Daemon::DaemonModules::SchedulerAutomationTaskManager;

use strict;
use warnings;
use utf8;

use base qw(Kernel::System::Daemon::BaseDaemon);

our @ObjectDependencies = (
    'Config',
    'Cache',
    'CronEvent',
    'DB',
    'Daemon::SchedulerDB',
    'Automation',
    'Log',
    'Time',
);

=head1 NAME

Kernel::System::Daemon::DaemonModules::SchedulerAutomationTaskManager - daemon to manage scheduler automation tasks

=head1 SYNOPSIS

Scheduler automation task daemon

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

Create scheduler automation manager object.

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # Allocate new hash for object.
    my $Self = {};
    bless $Self, $Type;

    # Get objects in constructor to save performance.
    $Self->{CacheObject}        = $Kernel::OM->Get('Cache');
    $Self->{AutomationObject}   = $Kernel::OM->Get('Automation');
    $Self->{DBObject}           = $Kernel::OM->Get('DB');
    $Self->{SchedulerDBObject}  = $Kernel::OM->Get('Daemon::SchedulerDB');

    # Disable in memory cache to be clusterable.
    $Self->{CacheObject}->Configure(
        CacheInMemory  => 0,
        CacheInBackend => 1,
    );

    # Get the NodeID from the SysConfig settings, this is used on High Availability systems.
    $Self->{NodeID} = $Kernel::OM->Get('Config')->Get('NodeID') || 1;

    # Check NodeID, if does not match is impossible to continue.
    if ( $Self->{NodeID} !~ m{ \A \d+ \z }xms && $Self->{NodeID} > 0 && $Self->{NodeID} < 1000 ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "NodeID '$Self->{NodeID}' is invalid!",
        );
        return;
    }

    # Do not change the following values!
    $Self->{SleepPost} = 5;          # sleep 5 seconds after each loop
    $Self->{Discard}   = 60 * 60;    # discard every hour

    $Self->{DiscardCount} = $Self->{Discard} / $Self->{SleepPost};

    $Self->{Debug}      = $Param{Debug};
    $Self->{DaemonName} = 'Daemon: SchedulerAutomationTaskManager';

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

    return if !$Self->{SchedulerDBObject}->AutomationTaskToExecute(
        NodeID => $Self->{NodeID},
        PID    => $$,
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
        $Self->_Debug("unlocking expired automation tasks");
    }

    # Unlock long locked tasks.
    $Self->{SchedulerDBObject}->RecurrentTaskUnlockExpired(
        Type => 'Automation',
    );

    # Remove obsolete tasks before destroy.
    if ( $Self->{DiscardCount} == 0 ) {
        if ( $Self->{Debug} ) {
            $Self->_Debug("cleaning up automation tasks");
        }
        $Self->{SchedulerDBObject}->AutomationTaskCleanup();
    }

    return if $Self->{DiscardCount} <= 0;
    return 1;
}

sub Summary {
    my ( $Self, %Param ) = @_;

    return $Self->{SchedulerDBObject}->AutomationTaskSummary();
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
