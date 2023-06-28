# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Maint::Cache::ShowStats;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Cache',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Shows statistics about the systems cache.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get cache object
    my $CacheObject = $Kernel::OM->Get('Cache');

    my $CacheStats = $CacheObject->GetCacheStats();

    if (!IsHashRefWithData($CacheStats)) {
        $Self->Print("<yellow>No cache statistics are available.</yellow>\n");
        return $Self->ExitCodeOk();
    }

    my $Line = '-------------------------------------------------------------------------------------------';
    printf("%-50s %10s %10s %10s %10s %10s %10s\n", 'Cache Type', '#Cleanups', '#Deletes', '#Items', '#Access', '#Hits', 'Hitrate');
    printf("%.50s %.10s %.10s %.10s %.10s %.10s %.10s\n", $Line, $Line, $Line, $Line, $Line, $Line, $Line );

    my %Totals = (
        Cleanups => 0,
        Deletes => 0,
        Items => 0,
        Access => 0,
        Hits => 0,
    );
    foreach my $Type (sort keys %{$CacheStats}) {
        my $StatsItem = $CacheStats->{$Type};

        my $Hitrate = ($StatsItem->{AccessCount} && $StatsItem->{HitCount}) ? $StatsItem->{HitCount} / $StatsItem->{AccessCount} * 100 : 0;
        $Totals{Items}    += $StatsItem->{KeyCount};
        $Totals{Access}   += $StatsItem->{AccessCount} ? $StatsItem->{AccessCount} : 0;
        $Totals{Hits}     += $StatsItem->{HitCount} ? $StatsItem->{HitCount} : 0;
        $Totals{Cleanups} += $StatsItem->{CleanupCount} ? $StatsItem->{CleanupCount} : 0;
        $Totals{Deletes}  += $StatsItem->{DeleteCount} ? $StatsItem->{DeleteCount} : 0;

        printf("%-50s %10i %10i %10i %10i %10i %10i\n", $Type, $StatsItem->{CleanupCount}, $StatsItem->{DeleteCount}, $StatsItem->{KeyCount}, $StatsItem->{AccessCount} ? $StatsItem->{AccessCount} : 0, $StatsItem->{HitCount} ? $StatsItem->{HitCount} : 0, $Hitrate );
    }
    printf("%.50s %.10s %.10s %.10s %.10s %.10s %.10s\n", $Line, $Line, $Line, $Line, $Line, $Line, $Line );
    printf("%-50s %10i %10i %10i %10i %10i %10i\n\n", 'TOTAL', $Totals{Cleanups}, $Totals{Deletes}, $Totals{Items}, $Totals{Access}, $Totals{Hits}, $Totals{Access} ? $Totals{Hits} / $Totals{Access} * 100 : 0 );

    $Self->Print("<green>Done.</green>\n");

    return $Self->ExitCodeOk();
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
