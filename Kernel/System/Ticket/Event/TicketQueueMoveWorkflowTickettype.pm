# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Ticket::Event::TicketQueueMoveWorkflowTickettype;

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
            Message  => "Event TicketQueueMoveWorkflowTickettype: "
                . "no ticket data for ID <"
                . $Param{Data}->{TicketID}
                . ">!",
        );
        return 1;
    }

    # get config
    my $SetMode = $Self->{ConfigObject}->Get('Ticket::TicketQueueMoveWorkflowTickettype');
    my $SetModeExtended
        = $Self->{ConfigObject}->Get('Ticket::TicketQueueMoveWorkflowTickettypeExtension');
    if ( defined $SetModeExtended && ref $SetModeExtended eq 'HASH' ) {
        for my $Extension ( sort keys %{$SetModeExtended} ) {
            for my $QueueType ( keys %{ $SetModeExtended->{$Extension} } ) {
                $SetMode->{$QueueType} = $SetModeExtended->{$Extension}->{$QueueType};
            }
        }
    }

    # get new ticket type from config hash
    my $NewTicketType;
    if ( $SetMode && ref $SetMode eq 'HASH' ) {
        for my $QueueTicketType ( keys %{$SetMode} ) {
            next if $QueueTicketType !~ m/^$TicketData{Queue}:::$TicketData{Type}$/i;
            $NewTicketType = $SetMode->{$QueueTicketType};
        }
    }

    # if workflow found
    if ( defined $NewTicketType && $NewTicketType ) {

        # get ticket state list
        my %TicketTypes = $Self->{TicketObject}->TicketTypeList(
            TicketID => $TicketData{TicketID},
            UserID   => 1,
        );

        # check if given state is valid
        my $CurrentTypeIsValid = 0;
        for my $Type (%TicketTypes) {
            next if $NewTicketType !~ m/^$Type$/i;
            $CurrentTypeIsValid = 1;
        }

        # set new ticket state
        if ($CurrentTypeIsValid) {
            $Self->{TicketObject}->TicketTypeSet(
                TicketID           => $Param{Data}->{TicketID},
                Type               => $NewTicketType,
                SendNoNotification => 1,
                UserID             => 1,
            );
        }
        else {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Event TicketQueueMoveWorkflowTickettype: new ticket type not valid!",
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
