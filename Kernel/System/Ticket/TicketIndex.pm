# --
# Modified version of the work: Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::TicketIndex;

use strict;
use warnings;

our @ObjectDependencies = (
    'Config',
    'DB',
    'Lock',
    'Log',
    'State',
    'Time',
);

sub TicketIndexUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(TicketID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check if ticket is shown or not
    my $IndexUpdateNeeded = 0;
    my $IndexSelected     = 0;
    my %TicketData        = $Self->TicketGet(
        %Param,
        DynamicFields => 0,
    );

    my %IndexTicketData = $Self->TicketIndexGetTicket(%Param);

    if ( !%IndexTicketData ) {
        $IndexUpdateNeeded = 1;
    }
    else {

        # check if we need to update
        if ( $TicketData{LockID} ne $IndexTicketData{LockID} ) {
            $IndexUpdateNeeded = 1;
        }
        elsif ( $TicketData{StateID} ne $IndexTicketData{StateID} ) {
            $IndexUpdateNeeded = 1;
        }
        elsif ( $TicketData{QueueID} ne $IndexTicketData{QueueID} ) {
            $IndexUpdateNeeded = 1;
        }
    }

    # check if this ticket is still viewable
    my @ViewableStates = $Kernel::OM->Get('State')->StateGetStatesByType(
        Type   => 'Viewable',
        Result => 'ID',
    );

    my $ViewableStatesHit = 0;

    for (@ViewableStates) {

        if ( $_ != $TicketData{StateID} ) {
            $ViewableStatesHit = 1;
        }
    }

    my @ViewableLocks = $Kernel::OM->Get('Lock')->LockViewableLock(
        Type => 'ID',
    );

    my $ViewableLocksHit = 0;

    for (@ViewableLocks) {

        if ( $_ != $TicketData{LockID} ) {
            $ViewableLocksHit = 1;
        }
    }

    if ($ViewableStatesHit) {
        $IndexSelected = 1;
    }

    if ( $TicketData{ArchiveFlag} eq 'y' ) {
        $IndexSelected = 0;
    }

    # write index back
    if ($IndexUpdateNeeded) {

        if ($IndexSelected) {

            if ( $IndexTicketData{TicketID} ) {

                $Kernel::OM->Get('DB')->Do(
                    SQL  => 'UPDATE ticket_index'
                          . ' SET queue_id = ?, lock_id = ?, state_id = ?'
                          . ' WHERE ticket_id = ?',
                    Bind => [
                        \$TicketData{QueueID}, \$TicketData{LockID},
                        \$TicketData{StateID}, \$Param{TicketID},
                    ],
                );
            }
            else {
                $Self->TicketIndexAdd(%TicketData);
            }
        }
        else {
            $Self->TicketIndexDelete(%Param);
        }
    }

    return 1;
}

sub TicketIndexDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(TicketID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    return if !$Kernel::OM->Get('DB')->Do(
        SQL  => 'DELETE FROM ticket_index WHERE ticket_id = ?',
        Bind => [ \$Param{TicketID} ],
    );

    return 1;
}

sub TicketIndexCleanup {
    my ( $Self, %Param ) = @_;

    return if !$Kernel::OM->Get('DB')->Do(
        SQL  => 'DELETE FROM ticket_index',
    );

    return 1;
}

sub TicketIndexAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(TicketID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get ticket data
    my %TicketData = $Self->TicketGet(
        %Param,
        DynamicFields => 0,
    );

    # check if this ticket is still viewable
    my @ViewableStates = $Kernel::OM->Get('State')->StateGetStatesByType(
        Type   => 'Viewable',
        Result => 'ID',
    );

    my $ViewableStatesHit = 0;

    for (@ViewableStates) {
        if ( $_ != $TicketData{StateID} ) {
            $ViewableStatesHit = 1;
        }
    }

    # do nothing if state is not viewable
    if ( !$ViewableStatesHit ) {
        return 1;
    }

    # do nothing if ticket is archived
    if ( $TicketData{ArchiveFlag} eq 'y' ) {
        return 1;
    }

    return if !$Kernel::OM->Get('DB')->Do(
        SQL  => 'INSERT INTO ticket_index (ticket_id, queue_id, lock_id, state_id, create_time_unix)'
              . ' VALUES (?, ?, ?, ?, ?)',
        Bind => [
            \$Param{TicketID}, \$TicketData{QueueID}, \$TicketData{LockID},
            \$TicketData{StateID}, \$TicketData{CreateTimeUnix},
        ],
    );

    return 1;
}

sub TicketIndexRebuild {
    my ( $Self, %Param ) = @_;

    my @ViewableStateIDs = $Kernel::OM->Get('State')->StateGetStatesByType(
        Type   => 'Viewable',
        Result => 'ID',
    );

    my @ViewableLockIDs = $Kernel::OM->Get('Lock')->LockViewableLock( Type => 'ID' );

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # get all viewable tickets
    my $SQL = "SELECT st.id, st.queue_id, st.ticket_lock_id, st.ticket_state_id, st.create_time_unix"
            . " FROM ticket st"
            . "  JOIN queue sq             ON st.queue_id = sq.id"
            . "  JOIN ticket_state tsd     ON st.ticket_state_id = tsd.id"
            . " WHERE st.ticket_state_id IN ( ${\(join ', ', @ViewableStateIDs)} )"
            . "   AND st.archive_flag = 0";

    return if !$DBObject->Prepare( SQL => $SQL );

    my $RowBuffer = $DBObject->FetchAllArrayRef(
        Columns => ['TicketID', 'QueueID', 'LockID', 'StateID', 'CreateTimeUnix']
    );

    # write index
    return if !$DBObject->Do( SQL => 'DELETE FROM ticket_index' );

    for ( @{$RowBuffer} ) {

        my %Data = %{$_};

        $DBObject->Do(
            SQL  => 'INSERT INTO ticket_index (ticket_id, queue_id, lock_id, state_id, create_time_unix)'
                  . ' VALUES (?, ?, ?, ?, ?)',
            Bind => [
                \$Data{TicketID}, \$Data{QueueID}, \$Data{LockID}, 
                \$Data{StateID}, \$Data{CreateTimeUnix},
            ],
        );
    }

    return 1;
}

sub TicketIndexGetTicket {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(TicketID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # sql query
    return if !$DBObject->Prepare(
        SQL  => 'SELECT ticket_id, queue_id, lock_id, state_id, create_time_unix'
              . ' FROM ticket_index'
              . ' WHERE ticket_id = ?',
        Bind => [ \$Param{TicketID} ]
    );

    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{TicketID}       = $Row[0];
        $Data{QueueID}        = $Row[1];
        $Data{LockID}         = $Row[2];
        $Data{StateID}        = $Row[3];
        $Data{CreateTimeUnix} = $Row[4];
    }

    return %Data;
}

sub TicketIndexGetQueueStats {
    my ( $Self, %Param ) = @_;

    my $CacheKey = 'TicketIndexGetQueueStats';
    my $Cached = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cached} if $Cached;

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # sql query
    return if !$DBObject->Prepare(
        SQL => 'SELECT queue_id, '
             . '(SELECT COUNT(*) FROM ticket_index WHERE queue_id = ti.queue_id), '
             . '(SELECT COUNT(*) FROM ticket_index WHERE queue_id = ti.queue_id AND lock_id = 2) '
             . 'FROM ticket_index ti',
    );

    my %Data = map { $_->{QueueID} => { TotalCount => $_->{TotalCount}, LockCount => $_->{LockCount}} } @{$DBObject->FetchAllArrayRef(
        Columns => ['QueueID', 'TotalCount', 'LockCount']
    )};

    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Data,
    );

    return %Data;
}


1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
