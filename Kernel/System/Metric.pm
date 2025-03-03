# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Metric;

use strict;
use warnings;

use Time::HiRes;

use base qw(Kernel::System::AsynchronousExecutor);

our @ObjectDependencies = (
    'Cache',
);

=head1 NAME

Kernel::System::Metric - metrics lib

=head1 SYNOPSIS

All metrics functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $MetricsObject = $Kernel::OM->Get('Metric');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{CacheType} = 'Metric';
    $Self->{CacheTTL}  = undef;

    $Self->{ActiveMetrics} = $Kernel::OM->Get('Config')->Get('Metrics::Active');
    $Self->{DaysToKeep}    = $Kernel::OM->Get('Config')->Get('Metrics::DaysToKeep');

    return $Self;
}

=item Init()

init a new metric

    my $Result = $MetricObject->Init(Type => '');

=cut

sub MetricInit {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Type)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return {};
        }
    }

    return if !$Self->{ActiveMetrics}->{$Param{Type}};

    my %Metric = (
        ProcessID  => $$,
        MetricType => $Param{Type},
        StartTime  => Time::HiRes::time(),
    );

    return \%Metric;
}


=item MetricAdd()

add a new metric

    my $Result = $MetricObject->MetricAdd(Metric => {});

=cut

sub MetricAdd {
    my ( $Self, %Param ) = @_;

    return if !${Param{Metric}};
    return if !$Self->{ActiveMetrics}->{$Param{Metric}->{MetricType}};

    $Param{Metric}->{Duration} = Time::HiRes::time() - $Param{Metric}->{StartTime};

    # store metric
    $Kernel::OM->Get('Cache')->Set(
        Type            => 'Metric',
        Key             => $$.Time::HiRes::time(),
        Value           => $Param{Metric},
        NoMetricsUpdate => 1,
    );

    return 1;
}

=item Export()

export metrics for prometheus

    my $Result = $MetricObject->Export();

=cut

sub Export {
    my ( $Self, %Param ) = @_;

    my $CacheObject = $Kernel::OM->Get('Cache');

    # get cached events
    my @Keys = $CacheObject->GetKeysForType(
        Type => 'Metric',
    );
    return 1 if !@Keys;

    my @MetricList = $CacheObject->GetMulti(
        Type           => 'Metric',
        Keys           => \@Keys,
        UseRawKey      => 1,
        NoMetricsUpdate => 1,
    );
    return 1 if !@MetricList;

    $Self->ExportWorker( MetricList => \@MetricList);

    # delete the cached events we sent
    foreach my $Key ( @Keys ) {
        $CacheObject->Delete(
            Type           => 'Metric',
            Key            => $Key,
            UseRawKey      => 1,
            NoMetricsUpdate => 1,
        );
    }

    return 1;
}

sub ExportWorker {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(MetricList)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my %Metrics;
    METRIC:
    foreach my $Metric ( @{$Param{MetricList}} ) {
        next METRIC if !$Metric->{MetricType} || !$Self->{ActiveMetrics}->{$Metric->{MetricType}};
        $Metrics{$Metric->{MetricType}} //= [];
        push @{$Metrics{$Metric->{MetricType}}}, $Metric;
    }

    my $Home = $Kernel::OM->Get('Config')->Get('Home');

    my $JSONObject = $Kernel::OM->Get('JSON');

    my $ExportDir = $Home.'/var/log/metrics/';
    if ( !-e $ExportDir ) {
        if ( !mkdir( $ExportDir, 0770 ) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Can't create matric export directory '$ExportDir': $!",
            );
        }
        return 1;
    }

    my $Today = (split / /, $Kernel::OM->Get('Time')->CurrentTimestamp())[0];

    TYPE:
    foreach my $Type ( sort keys %Metrics ) {
        next TYPE if !$Self->{ActiveMetrics}->{$Type};

        if ( !$Self->{Exporter}->{$Type} ) {
            $Self->{Exporter}->{$Type} = $Kernel::OM->Get('Metric::Exporter::'.$Type);
            if ( !$Self->{Exporter}->{$Type} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "No metric exporter for type \"$Type\"!"
                );
                next TYPE;
            }
        }
        open(HANDLE, '>>', $ExportDir.lc($Type).'_metrics.log.'.$Today);

        my $Output = $Self->{Exporter}->{$Type}->Export($Metrics{$Type});
        print HANDLE $Output;

        close(HANDLE);

        # keep max files
        if ( $Self->{DaysToKeep}->{$Type} ) {
            my $FileCount = `ls $ExportDir/api_metrics.log.* | wc -l`;
            my $DeleteCount = $FileCount - $Self->{DaysToKeep}->{$Type};
            if ( $DeleteCount > 0 ) {
                my @Files = split /\n/, `ls $ExportDir/api_metrics.log.* | sort -r | tail -n $DeleteCount`;
                foreach my $File ( @Files ) {
                    unlink($File);
                }
            }
        }
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
