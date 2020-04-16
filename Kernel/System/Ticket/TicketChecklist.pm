# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Ticket::TicketChecklist;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::Ticket::TicketChecklist - ticket checklist lib

=head1 SYNOPSIS

All ticket ACL functions.

=over 4

=cut

=item obsolete__TicketChecklistUpdate()

Creates new tasks

    my $HashRef = $TicketObject->obsolete__TicketChecklistUpdate(
        TicketID => 123,
        ItemString => String,
        State => 'open',
    );

=cut

sub obsolete__TicketChecklistUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ItemString TicketID State)) {
        if ( !defined( $Param{$Needed} ) ) {
            $Kernel::OM->Get('Log')
                ->Log( Priority => 'error', Message => "TicketChecklistUpdate: Need $Needed!" );
            return;
        }
    }

    # get single tasks
    my @Items        = split /\n/, $Param{ItemString};
    my %ItemHash     = ();
    my %ItemPosition = ();

    # get old task hash
    my $Checklist = $Self->TicketChecklistGet(
        TicketID => $Param{TicketID},
        Result   => 'Item',
    );

    # db quote
    $Param{TicketID} = $Kernel::OM->Get('DB')->Quote( $Param{TicketID}, 'Integer' );
    $Param{State} = $Kernel::OM->Get('DB')->Quote( $Param{State} );

    my $Position = 1;
    my %NewItemDataHash;
    for my $Item (@Items) {

        # if task already exists
        if ( defined $Checklist->{Data}->{$Item} ) {

            # update position if changed
            if ( $Position != $Checklist->{Data}->{$Item}->{Position} ) {

                $Checklist->{Data}->{$Item}->{Position} = $Position;
                $Self->TicketChecklistItemUpdate(
                    ItemID   => $Checklist->{Data}->{$Item}->{ID},
                    Item     => $Item,
                    Position => $Position
                );
            }

            # add data to new task hash
            my %TempItemHash = %{ $Checklist->{Data}->{$Item} };
            $NewItemDataHash{$Position} = \%TempItemHash;
            $ItemHash{$Item}            = 1;
            delete $Checklist->{Data}->{$Item};
        }

        # check if similar task exists
        else {
            my $Distance = 10;
            my $ChangedItemID;
            my $ChangedItem;
            for my $NewItemKey ( keys %{ $Checklist->{Data} } ) {

                # get distance
                my $NewDistance = $Self->_CalcStringDistance( $NewItemKey, $Item );

                # take lowest distance
                next if $NewDistance >= $Distance;

                $Distance      = $NewDistance;
                $ChangedItemID = $Checklist->{Data}->{$NewItemKey}->{ID};
                $ChangedItem   = $NewItemKey;

                last if $Distance == 1;
            }

            # similar task found - update data
            if ( $Distance < 10 ) {

                $Self->TicketChecklistItemUpdate(
                    ItemID   => $ChangedItemID,
                    Item     => $Item,
                    Position => $Position
                );
                $Checklist->{Data}->{$ChangedItem}->{Item} = $Item,
                my %TempItemHash = %{ $Checklist->{Data}->{$ChangedItem} };
                $NewItemDataHash{$Position} = \%TempItemHash;
                delete $Checklist->{Data}->{$ChangedItem};
            }

            # no similar task found - create new task
            else {
                if ( !defined $ItemHash{$Item} ) {
                    my $ItemID = $Self->TicketChecklistItemCreate(
                        Item     => $Item,
                        State    => $Param{State},
                        TicketID => $Param{TicketID},
                        Position => $Position,
                    );
                    my %TempHash;
                    $TempHash{ID}               = $ItemID;
                    $TempHash{Position}         = $Position;
                    $TempHash{Item}             = $Item;
                    $TempHash{State}            = $Param{State};
                    $NewItemDataHash{$Position} = \%TempHash;

                    $ItemHash{$Item} = 1;
                }
            }
        }
        $Position++;
    }

    # delete obsolete tasks
    for my $ObsoleteItem ( keys %{ $Checklist->{Data} } ) {
        $Self->TicketChecklistItemDelete(
            ItemID => $Checklist->{Data}->{$ObsoleteItem}->{ID},
        );
    }

    return \%NewItemDataHash;
}

=item TicketChecklistItemStateUpdate()

Sets new state to a tasks

    my $Success = $TicketObject->TicketChecklistItemStateUpdate(
        ItemID => 123,
        State => 'open',
    );

=cut

sub TicketChecklistItemStateUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ItemID State)) {
        if ( !defined( $Param{$Needed} ) ) {
            $Kernel::OM->Get('Log')
                ->Log(
                Priority => 'error',
                Message  => "TicketChecklistItemStateUpdate: Need $Needed!"
                );
            return;
        }
    }

    # get ChecklistItem
    my %ChecklistItem = $Self->TicketChecklistItemGet(
        ItemID => $Param{ItemID}
    );

    # db quote
    $Param{ItemID} = $Kernel::OM->Get('DB')->Quote( $Param{ItemID}, 'Integer' );
    $Param{State} = $Kernel::OM->Get('DB')->Quote( $Param{State} );

    # update
    return 0 if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE kix_ticket_checklist SET state = ? WHERE id = ?',
        Bind => [ \$Param{State}, \$Param{ItemID} ],
    );

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Ticket.Checklist',
        ObjectID  => $ChecklistItem{TicketID}.'::'.$Param{ItemID},
    );

    return 1;
}

=item TicketChecklistItemUpdate()

Updates a tasks

    my $Success = $TicketObject->TicketChecklistItemUpdate(
        ItemID => 123,
        Item => 'text'
    );

=cut

sub TicketChecklistItemUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ItemID Text State Position)) {
        if ( !defined( $Param{$Needed} ) ) {
            $Kernel::OM->Get('Log')
                ->Log( Priority => 'error', Message => "TicketChecklistItemUpdate: Need $Needed!" );
            return;
        }
    }

    # get ChecklistItem
    my %ChecklistItem = $Self->TicketChecklistItemGet(
        ItemID => $Param{ItemID}
    );

    # db quote
    $Param{ItemID}   = $Kernel::OM->Get('DB')->Quote( $Param{ItemID},   'Integer' );
    $Param{Position} = $Kernel::OM->Get('DB')->Quote( $Param{Position}, 'Integer' );
    $Param{State}    = $Kernel::OM->Get('DB')->Quote( $Param{State} );
    $Param{Text}     = $Kernel::OM->Get('DB')->Quote( $Param{Text} );

    # update
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL => 'UPDATE kix_ticket_checklist SET task = ?, position = ?, state = ? WHERE id = ?',
        Bind => [ \$Param{Text}, \$Param{Position}, \$Param{State}, \$Param{ItemID} ],
    );

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Ticket.Checklist',
        ObjectID  => $ChecklistItem{TicketID}.'::'.$Param{ItemID},
    );

    return 1;
}

=item TicketChecklistItemCreate()

Inserts a tasks

    my $ItemID = $TicketObject->TicketChecklistItemCreate(
        Text        => 123,
        State       => 'open',
        TicketID    => 123,
    );

=cut

sub TicketChecklistItemCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID State Text)) {
        if ( !defined( $Param{$Needed} ) ) {
            $Kernel::OM->Get('Log')
                ->Log( Priority => 'error', Message => "TicketChecklistItemCreate: Need $Needed!" );
            return;
        }
    }

    # db quote
    $Param{Item} = $Kernel::OM->Get('DB')->Quote( $Param{Item} );

    # insert action
    return if !$Kernel::OM->Get('DB')->Do(
        SQL =>
            'INSERT INTO kix_ticket_checklist (ticket_id, task, state, position) '
            . ' VALUES (?, ?, ?, ?)',
        Bind => [ \$Param{TicketID}, \$Param{Text}, \$Param{State}, \$Param{Position} ],
    );

    # get inserted id
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL   => 'SELECT id FROM kix_ticket_checklist WHERE task = ?',
        Bind  => [ \$Param{Text} ],
        Limit => 1,
    );

    my $ID;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        $ID = $Row[0];
    }

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'Ticket.Checklist',
        ObjectID  => $Param{TicketID}.'::'.$ID,
    );

    return $ID;
}

=item TicketChecklistItemDelete()

Deletes an item

    my $Success = $TicketObject->TicketChecklistItemDelete(
        ItemID => 123,
    );

=cut

sub TicketChecklistItemDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !defined( $Param{ItemID} ) ) {
        $Kernel::OM->Get('Log')
            ->Log( Priority => 'error', Message => "TicketChecklistItemDelete: Need ItemID!" );
        return;
    }

    # get ChecklistItem
    my %ChecklistItem = $Self->TicketChecklistItemGet(
        ItemID => $Param{ItemID}
    );

    # db quote
    $Param{ItemID} = $Kernel::OM->Get('DB')->Quote( $Param{ItemID}, 'Integer' );

    # update
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'DELETE FROM kix_ticket_checklist WHERE id = ?',
        Bind => [ \$Param{ItemID} ],
    );

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Ticket.Checklist',
        ObjectID  => $ChecklistItem{TicketID}.'::'.$Param{ItemID},
    );

    return 1;
}

=item TicketChecklistGet()

Returns a hash of items

    my $HashRef = $TicketObject->TicketChecklistGet(
        TicketID => 123,
    );

=cut

sub TicketChecklistGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID)) {
        if ( !defined( $Param{$Needed} ) ) {
            $Kernel::OM->Get('Log')
                ->Log( Priority => 'error', Message => "TicketChecklistGet: Need $Needed!" );
            return;
        }
    }

    # fetch the result
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL => 'SELECT id, task, state, position'
            . ' FROM kix_ticket_checklist'
            . ' WHERE ticket_id = ? ORDER BY position',
        Bind => [ \$Param{TicketID} ],
    );

    # get checklist items
    my %Checklist;

    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        my %TempHash;
        $TempHash{ID}       = $Row[0];
        $TempHash{Text}     = $Row[1];
        $TempHash{State}    = $Row[2];
        $TempHash{Position} = $Row[3] || 0;

        $Checklist{ $Row[0] } = \%TempHash;
    }

    # return hash
    return \%Checklist;
}

=item TicketChecklistItemGet()

Returns a specific item

    my $HashRef = $TicketObject->TicketChecklistItemGet(
        ItemID => 123,
    );

=cut

sub TicketChecklistItemGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ItemID)) {
        if ( !defined( $Param{$Needed} ) ) {
            $Kernel::OM->Get('Log')
                ->Log( Priority => 'error', Message => "TicketChecklistItemGet: Need $Needed!" );
            return;
        }
    }

    # fetch the result
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL => 'SELECT id, ticket_id, task, state, position'
            . ' FROM kix_ticket_checklist'
            . ' WHERE id = ?',
        Bind => [ \$Param{ItemID} ],
    );

    # get checklist item
    my %ChecklistItem;

    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        $ChecklistItem{ID}       = $Row[0];
        $ChecklistItem{TicketID} = $Row[1];
        $ChecklistItem{Text}     = $Row[2];
        $ChecklistItem{State}    = $Row[3];
        $ChecklistItem{Position} = $Row[4] || 0;
    }

    # return hash
    return \%ChecklistItem;
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
