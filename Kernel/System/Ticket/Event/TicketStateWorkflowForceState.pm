# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Ticket::Event::TicketStateWorkflowForceState;

use strict;
use warnings;

our @ObjectDependencies = (
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
    $Self->{LogObject}           = $Kernel::OM->Get('Log');
    $Self->{TicketObject}        = $Kernel::OM->Get('Ticket');

    return $Self;
}

=item Run()

Run - contains the actions performed by this event handler.

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Event Config)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    if ( !$Param{Data}->{TicketID} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Need TicketID!"
        );
        return;
    }

    my %Ticket = $Self->{TicketObject}->TicketGet(
        TicketID => $Param{Data}->{TicketID},
        UserID   => $Param{UserID},
    );

    # should I unlock a ticket after move?
    if ( $Ticket{Lock} =~ /^lock$/i ) {
        if (
            $Param{Config}->{ $Ticket{Type} . ':::' . $Ticket{State} }
            || $Param{Config}->{ $Ticket{State} }
            )
        {
            $Self->{TicketObject}->TicketStateSet(
                TicketID => $Param{Data}->{TicketID},
                State    => $Param{Config}->{ $Ticket{Type} . ':::' . $Ticket{State} }
                    || $Param{Config}->{ $Ticket{State} },
                SendNoNotification => 1,
                UserID             => 1,
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
