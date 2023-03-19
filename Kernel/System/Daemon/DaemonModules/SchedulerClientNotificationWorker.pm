# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Daemon::DaemonModules::SchedulerClientNotificationWorker;

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

Kernel::System::Daemon::DaemonModules::SchedulerClientNotificationWorker - daemon to handle client notifications

=head1 SYNOPSIS

Scheduler client notification task daemon

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

Create scheduler worker object.

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # Allocate new hash for object.
    my $Self = {};
    bless $Self, $Type;

    # Get objects in constructor to save performance.
    $Self->{CacheObject}              = $Kernel::OM->Get('Cache');
    $Self->{ClientRegistrationObject} = $Kernel::OM->Get('ClientRegistration');

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

    $Self->{Debug}      = $Param{Debug};
    $Self->{DaemonName} = 'Daemon: SchedulerClientNotificationWorker';

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check if we have something todo
    my @Keys = $Self->{CacheObject}->GetKeysForType(
        Type => 'ClientNotificationToSend',
    );
    return 1 if !@Keys;

    my @Jobs = $Self->{CacheObject}->GetMulti(
        Type          => 'ClientNotificationToSend',
        Keys          => \@Keys,
        UseRawKey     => 1,
        NoStatsUpdate => 1,
    );
    return 1 if !@Jobs;

    foreach my $Key ( @Keys ) {
        $Self->{CacheObject}->Delete(
            Type          => 'ClientNotificationToSend',
            Key           => $Key,
            UseRawKey     => 1,
            NoStatsUpdate => 1,
        );
    }

    foreach my $Job ( @Jobs ) {
        # send the notifications
        $Self->{ClientRegistrationObject}->NotificationSendWorker(
            %{$Job}
        );
    }

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