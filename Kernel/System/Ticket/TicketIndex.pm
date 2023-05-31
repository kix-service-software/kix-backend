# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
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
    my %Ticket = $Self->TicketGet(
        %Param,
        DynamicFields => 0,
    );

    my %IndexData = $Self->TicketIndexGetTicket(%Param);

    if ( %IndexData && $Ticket{LockID} eq $IndexData{LockID} && $Ticket{StateID} eq $IndexData{StateID} && $Ticket{QueueID} eq $IndexData{QueueID} ) {
        # no lock, state or queue changed...
        return 1;
    }

    # check if this ticket is still viewable
    my %ViewableStates = $Kernel::OM->Get('State')->StateGetStatesByType(
        Type   => 'Viewable',
        Result => 'HASH',
    );

    if ( !$ViewableStates{$Ticket{StateID}} || $Ticket{ArchiveFlag} eq 'y' ) {
        # remove the ticket from the index if it's archived or no longer viewable
        return $Self->TicketIndexDelete(%Param);
    }

    # update the index
    if ( $IndexData{TicketID} ) {
        # update the existing index entry
        $Kernel::OM->Get('DB')->Do(
            SQL  => 'UPDATE ticket_index'
                    . ' SET queue_id = ?, lock_id = ?, state_id = ?'
                    . ' WHERE ticket_id = ?',
            Bind => [
                \$Ticket{QueueID}, \$Ticket{LockID},
                \$Ticket{StateID}, \$Param{TicketID},
            ],
        );
    }
    else {
        # add a new index entry for this ticket
        $Self->TicketIndexAdd(%Ticket);
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
    my %Ticket = $Self->TicketGet(
        %Param,
        DynamicFields => 0,
    );

    # check if this ticket is still viewable
    my %ViewableStates = $Kernel::OM->Get('State')->StateGetStatesByType(
        Type   => 'Viewable',
        Result => 'HASH',
    );

    if ( !$ViewableStates{$Ticket{StateID}} || $Ticket{ArchiveFlag} eq 'y' ) {
        # do nothing if the ticket isn't viewable or archived
        return;
    }

    return if !$Kernel::OM->Get('DB')->Do(
        SQL  => 'INSERT INTO ticket_index (ticket_id, queue_id, lock_id, state_id, create_time_unix)'
              . ' VALUES (?, ?, ?, ?, ?)',
        Bind => [
            \$Param{TicketID}, \$Ticket{QueueID}, \$Ticket{LockID},
            \$Ticket{StateID}, \$Ticket{CreateTimeUnix},
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
        Type => 'TicketIndex',
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
             . 'FROM ticket_index ti GROUP BY queue_id',
    );

    my $Result = $DBObject->FetchAllArrayRef(
        Columns => ['QueueID', 'TotalCount', 'LockCount']
    );

    my %Data = map { $_->{QueueID} => { TotalCount => $_->{TotalCount}, LockCount => $_->{LockCount} } } @{$Result || []};

    $Kernel::OM->Get('Cache')->Set(
        Type  => 'TicketIndex',
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
