# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Ticket::UnlockTimeout;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'DB',
    'Lock',
    'State',
    'Ticket',
    'Time',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Unlock tickets that are past their unlock timeout.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Unlocking tickets that are past their unlock timeout...</yellow>\n");

    my @UnlockStateIDs = $Kernel::OM->Get('State')->StateGetStatesByType(
        Type   => 'Unlock',
        Result => 'ID',
    );
    my @ViewableLockIDs = $Kernel::OM->Get('Lock')->LockViewableLock( Type => 'ID' );

    my @Tickets;

    $Kernel::OM->Get('DB')->Prepare(
        SQL => "
            SELECT st.tn, st.id, st.timeout, sq.unlock_timeout
            FROM ticket st, queue sq
            WHERE st.queue_id = sq.id
                AND sq.unlock_timeout != 0
                AND st.ticket_state_id IN ( ${\(join ', ', @UnlockStateIDs)} )
                AND st.ticket_lock_id NOT IN ( ${\(join ', ', @ViewableLockIDs)} ) ",
    );

    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        push @Tickets, \@Row;
    }

    TICKET:
    for (@Tickets) {
        my @Row = @{$_};

        # get used calendar
        my $Calendar = '';          # use main calendar as fallback

        my $CountedTime = $Kernel::OM->Get('Time')->WorkingTime(
            StartTime => $Row[2],
            StopTime  => $Kernel::OM->Get('Time')->SystemTime(),
            Calendar  => $Calendar,
        );
        next TICKET if $CountedTime < $Row[3] * 60;

        $Self->Print(" Unlocking ticket id $Row[0]... ");
        my $Unlock = $Kernel::OM->Get('Ticket')->TicketLockSet(
            TicketID => $Row[1],
            Lock     => 'unlock',
            UserID   => 1,
        );
        if ($Unlock) {
            $Self->Print("<green>done.</green>\n");
        }
        else {
            $Self->Print("<red>failed.</red>\n");
        }
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
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
