# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Ticket::Event::TicketQueueMoveWorkflowState;

use strict;
use warnings;

our @ObjectDependencies = (
    'Config',
    'Log',
    'Ticket',
);

=item new()

create an object.

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # create needed objects
    $Self->{ConfigObject}        = $Kernel::OM->Get('Config');
    $Self->{LogObject}           = $Kernel::OM->Get('Log');
    $Self->{TicketObject}        = $Kernel::OM->Get('Ticket');

    return $Self;
}

=item Run()

Run - contains the actions performed by this event handler.

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check required params...
    for (qw(Event Config UserID)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # handle only events with given TicketID
    return 1 if ( !$Param{Data}->{TicketID} );

    # get ticket data...
    my %TicketData = $Self->{TicketObject}->TicketGet(
        TicketID => $Param{Data}->{TicketID},
        UserID   => 1,
    );

    if ( !scalar( keys(%TicketData) ) ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Event TicketQueueMoveWorkflowState: "
                . "no ticket data for ID <"
                . $Param{Data}->{TicketID}
                . ">!",
        );
        return 1;
    }

    # get config
    my $SetMode = $Self->{ConfigObject}->Get('Ticket::TicketQueueMoveWorkflowState');
    my $SetModeExtended
        = $Self->{ConfigObject}->Get('Ticket::TicketQueueMoveWorkflowStateExtension');
    if ( defined $SetModeExtended && ref $SetModeExtended eq 'HASH' ) {
        for my $Extension ( sort keys %{$SetModeExtended} ) {
            for my $QueueType ( keys %{ $SetModeExtended->{$Extension} } ) {
                $SetMode->{$QueueType} = $SetModeExtended->{$Extension}->{$QueueType};
            }
        }
    }

    # get new state from config hash
    my $NewState;
    if ( $SetMode && ref $SetMode eq 'HASH' ) {
        for my $QueueTicketType ( keys %{$SetMode} ) {
            next if $QueueTicketType !~ m/^$TicketData{Queue}:::$TicketData{Type}$/i;
            $NewState = $SetMode->{$QueueTicketType};
        }
    }

    # if workflow found
    if ( defined $NewState && $NewState ) {

        # get ticket state list
        my %NextStates = $Self->{TicketObject}->TicketStateList(
            TicketID => $TicketData{TicketID},
            UserID   => 1,
        );

        # check if given state is valid
        my $CurrentStateIsValid = 0;
        for my $StateValid (%NextStates) {
            next if $NewState !~ m/^$StateValid$/i;
            $CurrentStateIsValid = 1;
        }

        # set new ticket state
        if ($CurrentStateIsValid) {
            $Self->{TicketObject}->TicketStateSet(
                TicketID           => $Param{Data}->{TicketID},
                State              => $NewState,
                SendNoNotification => 1,
                UserID             => 1,
            );
        }
        else {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Event TicketQueueMoveWorkflowState: new state not valid!",
            );
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
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
