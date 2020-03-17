# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::PerfLog;

use strict;
use warnings;
use Time::HiRes qw ( time );

use vars qw(@ISA $VERSION);
$VERSION = qw($Revision: 1.12 $) [1];

local $Kernel::System::PerfLog::Store;

sub Init {
    my ($Self, %Param) = @_;

    $Kernel::System::PerfLog::Store = {};
}

sub PerfLogStart {
    my ($Self, $Fnc) = @_;

    if (!exists($Kernel::System::PerfLog::Store->{FncStack})) {
        $Kernel::System::PerfLog::Store->{FncStack} = [];
    }
    if (!exists($Kernel::System::PerfLog::Store->{Index})) {
        $Kernel::System::PerfLog::Store->{Index} = 0;
    }

    if (!exists($Kernel::System::PerfLog::Store->{Functions}->{$Fnc}->{Index})) {
        $Kernel::System::PerfLog::Store->{Functions}->{$Fnc}->{Index} = $Kernel::System::PerfLog::Store->{Index}++;
    }
    $Kernel::System::PerfLog::Store->{Functions}->{$Fnc}->{Count}++;
    if (!exists($Kernel::System::PerfLog::Store->{Functions}->{$Fnc}->{Level})) {
       $Kernel::System::PerfLog::Store->{Functions}->{$Fnc}->{Level} = $Kernel::System::PerfLog::Store->{Level} || 0;
    }
    $Kernel::System::PerfLog::Store->{Functions}->{$Fnc}->{Starttime} = time() || 0;
    $Kernel::System::PerfLog::Store->{Level}++;

    push(@{$Kernel::System::PerfLog::Store->{FncStack}}, $Fnc);
}

sub PerfLogStop {
    my ($Self, $DeferOutput) = @_;
    return if !$Kernel::System::PerfLog::Store->{FncStack};

    my $Fnc = pop(@{$Kernel::System::PerfLog::Store->{FncStack}});
    $Kernel::System::PerfLog::Store->{Level}--;

    my $Time = time() || 0;
    my $TimeDiff = ($Time - $Kernel::System::PerfLog::Store->{Functions}->{$Fnc}->{Starttime}) * 1000;
    $Kernel::System::PerfLog::Store->{Functions}->{$Fnc}->{Time} += $TimeDiff;

    if (!exists($Kernel::System::PerfLog::Store->{Functions}->{$Fnc}->{MinTime}) || $TimeDiff < $Kernel::System::PerfLog::Store->{Functions}->{$Fnc}->{MinTime}) {
        $Kernel::System::PerfLog::Store->{Functions}->{$Fnc}->{MinTime} = $TimeDiff;
    }
    if (!exists($Kernel::System::PerfLog::Store->{Functions}->{$Fnc}->{MaxTime}) || $TimeDiff > $Kernel::System::PerfLog::Store->{Functions}->{$Fnc}->{MaxTime}) {
        $Kernel::System::PerfLog::Store->{Functions}->{$Fnc}->{MaxTime} = $TimeDiff;
    }

    if (!$DeferOutput) {
        $Self->PerfLogOutput();
        delete $Kernel::System::PerfLog::Store->{Functions}->{$Fnc};
    }
    else {
        $Kernel::System::PerfLog::Store->{Functions}->{$Fnc}->{Deferred} = 1;
    }
}

sub PerfLogOutput {
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

    foreach my $Fnc (sort {$Kernel::System::PerfLog::Store->{Functions}->{$a}->{Index} <=> $Kernel::System::PerfLog::Store->{Functions}->{$b}->{Index}} keys %{$Kernel::System::PerfLog::Store->{Functions}}) {
        my $FncHash = $Kernel::System::PerfLog::Store->{Functions}->{$Fnc};
        my $time = sprintf("%lu", ($FncHash->{Time}||0));
        my $LevelPadding = sprintf("%*s", $FncHash->{Level}*3, '');
        my $InfoStr;
        if (
            $FncHash->{Deferred}
            || $Kernel::System::PerfLog::Store->{Level} == $FncHash->{Level}
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

        if ($Kernel::System::PerfLog::Store->{Level} == $FncHash->{Level}) {
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

sub SQLLogSetMinTime {
    my ($Self, $MinTime) = @_;

    if (defined ($MinTime)) {
        $Kernel::System::PerfLog::Store->{SQLLogMinTime} = $MinTime;
    }
}

sub SQLLogActivate {
    $Kernel::System::PerfLog::Store->{SQLLog} = 1;
    if(!defined ($Kernel::System::PerfLog::Store->{SQLLogMinTime})) {
        $Kernel::System::PerfLog::Store->{SQLLogMinTime} = 1000;
    }
}

sub SQLLogDeactivate {
    $Kernel::System::PerfLog::Store->{SQLLog} = 0;
}

# disable redefine warnings in this scope
{
    no warnings 'redefine';

    # Override Kernel::System::DB::Prepare() method to intercept database calls
    if ( Kernel::System::DB->can('Prepare') && !Kernel::System::DB->can('PrepareOriginal') ) {
        *Kernel::System::DB::PrepareOriginal = \&Kernel::System::DB::Prepare;
        *Kernel::System::DB::Prepare = sub {
            my ( $Self, %Param ) = @_;

            my $Time = 0;
            if (
                $Kernel::System::PerfLog::Store->{SQLLog}
                && $Kernel::System::PerfLog::Store->{FncStack}
                && $Kernel::System::PerfLog::Store->{FncStack}->[-1]
            ) {
                $Time = time();
            }

            my $Result = $Self->PrepareOriginal(%Param);

            if (
                $Kernel::System::PerfLog::Store->{SQLLog}
                && $Kernel::System::PerfLog::Store->{FncStack}
                && $Kernel::System::PerfLog::Store->{FncStack}->[-1]
            ) {
                my $Fnc = $Kernel::System::PerfLog::Store->{FncStack}->[-1];

                # count queries for SQL
                if (!defined($Kernel::System::PerfLog::Store->{Functions}->{$Fnc}->{SQLCount})) {
                    $Kernel::System::PerfLog::Store->{Functions}->{$Fnc}->{SQLCount} = 0;
                }
                $Kernel::System::PerfLog::Store->{Functions}->{$Fnc}->{SQLCount} ++;

                my $DiffTime = (time() - $Time) * 1000;

                # sum time for SQL
                if (!defined($Kernel::System::PerfLog::Store->{Functions}->{$Fnc}->{SQLTime})) {
                    $Kernel::System::PerfLog::Store->{Functions}->{$Fnc}->{SQLTime} = 0;
                }
                $Kernel::System::PerfLog::Store->{Functions}->{$Fnc}->{SQLTime} += $DiffTime;

                # check MinTime
                if ($DiffTime >= $Kernel::System::PerfLog::Store->{SQLLogMinTime}) {

                    # Prepare BindString
                    my @Array = map { defined $_ ? ${$_} : 'undef' } @{ $Param{Bind} || [] };
                    @Array = map { $_ =~ s{\r?\n}{[\\n]}smxg; $_; } @Array;
                    @Array = map { length($_) > 100 ? ( substr( $_, 0, 100 ) . '[...]' ) : $_ } @Array;
                    my $BindString = @Array ? join ', ', @Array : '';

                    # Prepare StackTrace
                    my @StackTrace;
                    COUNT:
                    for ( my $Count = 1; $Count < 30; $Count++ ) {
                        my ( $Package1, $Filename1, $Line1, $Subroutine1 ) = caller($Count);
                        last COUNT if !$Line1;
                        my ( $Package2, $Filename2, $Line2, $Subroutine2 ) = caller( 1 + $Count );
                        $Subroutine2 ||= $0;    # if there is no caller module use the file name
                        $Subroutine2 =~ s/Kernel::System/K::S/;
                        $Subroutine2 =~ s/Kernel::Modules/K::M/;
                        $Subroutine2 =~ s/Kernel::Output::HTML/K::O::H/;
                        push @StackTrace, "$Subroutine2:$Line1";
                    }

                    # Prepare Message
                    my $Message = "Statement: " . $Param{SQL} . "\n"
                                . "Bind: " . $BindString . "\n"
                                . "Time: " . $DiffTime . "ms\n"
                                . "StackTrace: \n\t" . join( "\n\t", @StackTrace ) . "\n"
                                . "---";

                    push(@{$Kernel::System::PerfLog::Store->{Functions}->{$Fnc}->{SQLLog}}, $Message);
                }
            }

            return $Result;
       };
    }

    # Override Kernel::System::DB::Do() method to intercept database calls
    if ( Kernel::System::DB->can('Do') && !Kernel::System::DB->can('DoOriginal') ) {
        *Kernel::System::DB::DoOriginal = \&Kernel::System::DB::Do;
        *Kernel::System::DB::Do = sub {
            my ( $Self, %Param ) = @_;

            my $Time = 0;
            if (
                $Kernel::System::PerfLog::Store->{SQLLog}
                && $Kernel::System::PerfLog::Store->{FncStack}
                && $Kernel::System::PerfLog::Store->{FncStack}->[-1]
            ) {
                $Time = time();
            }

            my $Result = $Self->DoOriginal(%Param);

            if (
                $Kernel::System::PerfLog::Store->{SQLLog}
                && $Kernel::System::PerfLog::Store->{FncStack}
                && $Kernel::System::PerfLog::Store->{FncStack}->[-1]
            ) {
                my $Fnc = $Kernel::System::PerfLog::Store->{FncStack}->[-1];

                # count queries for SQL
                if (!defined($Kernel::System::PerfLog::Store->{Functions}->{$Fnc}->{SQLCount})) {
                    $Kernel::System::PerfLog::Store->{Functions}->{$Fnc}->{SQLCount} = 0;
                }
                $Kernel::System::PerfLog::Store->{Functions}->{$Fnc}->{SQLCount} ++;

                my $DiffTime = (time() - $Time) * 1000;

                # sum time for SQL
                if (!defined($Kernel::System::PerfLog::Store->{Functions}->{$Fnc}->{SQLTime})) {
                    $Kernel::System::PerfLog::Store->{Functions}->{$Fnc}->{SQLTime} = 0;
                }
                $Kernel::System::PerfLog::Store->{Functions}->{$Fnc}->{SQLTime} += $DiffTime;

                # check MinTime
                if ($DiffTime >= $Kernel::System::PerfLog::Store->{SQLLogMinTime}) {

                    # Prepare BindString
                    my @Array = map { defined $_ ? ${$_} : 'undef' } @{ $Param{Bind} || [] };
                    @Array = map { $_ =~ s{\r?\n}{[\\n]}smxg; $_; } @Array;
                    @Array = map { length($_) > 100 ? ( substr( $_, 0, 100 ) . '[...]' ) : $_ } @Array;
                    my $BindString = @Array ? join ', ', @Array : '';

                    # Prepare StackTrace
                    my @StackTrace;
                    COUNT:
                    for ( my $Count = 1; $Count < 30; $Count++ ) {
                        my ( $Package1, $Filename1, $Line1, $Subroutine1 ) = caller($Count);
                        last COUNT if !$Line1;
                        my ( $Package2, $Filename2, $Line2, $Subroutine2 ) = caller( 1 + $Count );
                        $Subroutine2 ||= $0;    # if there is no caller module use the file name
                        $Subroutine2 =~ s/Kernel::System/K::S/;
                        $Subroutine2 =~ s/Kernel::Modules/K::M/;
                        $Subroutine2 =~ s/Kernel::Output::HTML/K::O::H/;
                        push @StackTrace, "$Subroutine2:$Line1";
                    }

                    # Prepare Message
                    my $Message = "Statement: " . $Param{SQL} . "\n"
                                . "Bind: " . $BindString . "\n"
                                . "Time: " . $DiffTime . "ms\n"
                                . "StackTrace: \n\t" . join( "\n\t", @StackTrace ) . "\n"
                                . "---";

                    push(@{$Kernel::System::PerfLog::Store->{Functions}->{$Fnc}->{SQLLog}}, $Message);
                }
            }

            return $Result;
       };
    }

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
