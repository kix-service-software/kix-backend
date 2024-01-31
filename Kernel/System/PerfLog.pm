# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::PerfLog;

use strict;
use warnings;
use Time::HiRes qw ( time );

our @ObjectDependencies = ();

use vars qw(@ISA $VERSION);
$VERSION = qw($Revision: 1.12 $) [1];

use Exporter qw(import);
our %EXPORT_TAGS = (    ## no critic
    all => [
        'TimeDiff',
    ],
);
Exporter::export_ok_tags('all');

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->Init();

    return $Self;
}

sub Init {
    my ($Self, %Param) = @_;

    $Self->{Store} = {};
}

sub Start {
    my ($Self, $Fnc) = @_;

    if (!exists($Self->{Store}->{FncStack})) {
        $Self->{Store}->{FncStack} = [];
    }
    if (!exists($Self->{Store}->{Index})) {
        $Self->{Store}->{Index} = 0;
    }

    if (!exists($Self->{Store}->{Functions}->{$Fnc}->{Index})) {
        $Self->{Store}->{Functions}->{$Fnc}->{Index} = $Self->{Store}->{Index}++;
    }
    $Self->{Store}->{Functions}->{$Fnc}->{Count}++;
    if (!exists($Self->{Store}->{Functions}->{$Fnc}->{Level})) {
       $Self->{Store}->{Functions}->{$Fnc}->{Level} = $Self->{Store}->{Level} || 0;
    }
    $Self->{Store}->{Functions}->{$Fnc}->{Starttime} = time() || 0;
    $Self->{Store}->{Level}++;

    push(@{$Self->{Store}->{FncStack}}, $Fnc);
}

sub Stop {
    my ($Self, $DeferOutput) = @_;
    return if !$Self->{Store}->{FncStack};

    my $Fnc = pop(@{$Self->{Store}->{FncStack}});
    $Self->{Store}->{Level}--;

    my $Time = time() || 0;
    my $TimeDiff = ($Time - $Self->{Store}->{Functions}->{$Fnc}->{Starttime}) * 1000;
    $Self->{Store}->{Functions}->{$Fnc}->{Time} += $TimeDiff;

    if (!exists($Self->{Store}->{Functions}->{$Fnc}->{MinTime}) || $TimeDiff < $Self->{Store}->{Functions}->{$Fnc}->{MinTime}) {
        $Self->{Store}->{Functions}->{$Fnc}->{MinTime} = $TimeDiff;
    }
    if (!exists($Self->{Store}->{Functions}->{$Fnc}->{MaxTime}) || $TimeDiff > $Self->{Store}->{Functions}->{$Fnc}->{MaxTime}) {
        $Self->{Store}->{Functions}->{$Fnc}->{MaxTime} = $TimeDiff;
    }

    if (!$DeferOutput) {
        $Self->Output();
        delete $Self->{Store}->{Functions}->{$Fnc};
    }
    else {
        $Self->{Store}->{Functions}->{$Fnc}->{Deferred} = 1;
    }
}

sub Output {
    my ($Self) = @_;
    my ($sec,$min,$hour,$day,$mon,$year) = localtime();
    my $datestr = sprintf("%i/%02i/%02i %02i:%02i:%02i", $year+1900, $mon+1, $day, $hour, $min, $sec);
    if (!$Self->{PerfLogFile}) {
        # fallback
        $Self->{PerfLogFile} = 'STDERR';
    }
    if ($Self->{PerfLogFile} ne 'STDERR') {
        open(HANDLE, '>>'.($Self->{PerfLogFile}||'/tmp/kix.perflog'));
    }

    foreach my $Fnc (sort {$Self->{Store}->{Functions}->{$a}->{Index} <=> $Self->{Store}->{Functions}->{$b}->{Index}} keys %{$Self->{Store}->{Functions}}) {
        my $FncHash = $Self->{Store}->{Functions}->{$Fnc};
        my $time = sprintf("%lu", ($FncHash->{Time}||0));
        my $LevelPadding = sprintf("%*s", $FncHash->{Level}*3, '');
        my $InfoStr;
        if (
            $FncHash->{Deferred}
            || $Self->{Store}->{Level} == $FncHash->{Level}
        ) {
            $InfoStr = sprintf("%s %s (%lu, %lu ms, %0.1f ms, %0.1f ms, %0.1f ms)", ($LevelPadding || ''), ($Fnc || ''), ($FncHash->{Count} || 1), ($time || 0), ($FncHash->{MinTime} || 0), ($FncHash->{MaxTime} || 0), $time/($FncHash->{Count} || 1));
        } else {
            $InfoStr = sprintf("%s %s", ($LevelPadding || ''), ($Fnc || ''));
        }
        my $Output = "$datestr ($$) [".($ENV{REMOTE_ADDR} ? $ENV{REMOTE_ADDR} : '<cron>')."]: ".$InfoStr;
        if ($FncHash->{Deferred}) {
           $Output .= " [deferred]";
        }
        if ($Self->{PerfLogFile} ne 'STDERR') {
            print HANDLE "$Output\n";
        }
        else {
            print STDERR "$Output\n";
        }

        if ($Self->{Store}->{Level} == $FncHash->{Level}) {
            if ($FncHash->{SQLCount}) {
                if ($Self->{PerfLogFile} ne 'STDERR') {
                    print HANDLE "SQL-Summary: $FncHash->{SQLCount}, $FncHash->{SQLTime} ms\n";
                }
                else {
                    print STDERR "SQL-Summary: $FncHash->{SQLCount}, $FncHash->{SQLTime} ms\n";
                }
            }

            if (
                $FncHash->{SQLLog}
                && ref($FncHash->{SQLLog}) eq 'ARRAY'
            ) {
                if ($Self->{PerfLogFile} ne 'STDERR') {
                    print HANDLE "SQLLog:\n";
                }
                else {
                    print STDERR "SQLLog:\n";
                }
                for my $LogEntry ( @{$FncHash->{SQLLog}} ) {
                    if ($Self->{PerfLogFile} ne 'STDERR') {
                        print HANDLE "$LogEntry\n";
                    }
                    else {
                        print STDERR "$LogEntry\n";
                    }
                }
            }
        }
    }
    if ($Self->{PerfLogFile} ne 'STDERR') {
        print HANDLE "-----\n";
        close(HANDLE);
    }

    # cleanup
    $Self->Init();
}

sub TimeDiff {
    my ($StartTime) = @_;

    return (Time::HiRes::time() - $StartTime) * 1000;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
