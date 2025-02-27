# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Ticket::Event::TicketUnlockOnStateUpdate;

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
    my $NonOverrideTicketState;
    my $DefaultState;

    # check needed stuff
    if ( !$Param{Event} ) {
        $Self->{LogObject}->Log( Priority => 'error', Message => "Need Event!" );
        return;
    }

    if ( $Param{Event} eq 'TicketStateUpdate' ) {

        #check required param...
        return 1 if !$Param{Data}->{TicketID};

        # get configuration...
        my $ConfigRef = $Self->{ConfigObject}->Get('TicketUnlockOnStateUpdate');
        my $ConfigRefExtended = $Self->{ConfigObject}->Get('TicketUnlockOnStateUpdateExtension');
        if ( defined $ConfigRefExtended && ref $ConfigRefExtended eq 'HASH' ) {
            for my $Extension ( sort keys %{$ConfigRefExtended} ) {
                for my $TypeState ( keys %{ $ConfigRefExtended->{$Extension} } ) {
                    $ConfigRef->{$TypeState} = $ConfigRefExtended->{$Extension}->{$TypeState};
                }
            }
        }

        # get ticket is locked
        return 1 if ( !$Self->{TicketObject}->TicketLockGet( TicketID => $Param{Data}->{TicketID} ) );

        #get ticket data...
        my %TicketData = $Self->{TicketObject}->TicketGet(
            TicketID => $Param{Data}->{TicketID},
            UserID   => 1,
        );

        if ( !scalar( keys(%TicketData) ) ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Event:TicketStateAutoUpdate - "
                    . "no ticket data for ID <"
                    . $Param{Data}->{TicketID}
                    . ">!",
            );
            return 1;
        }

        #return if no automaticstates
        return 1 if ( ref($ConfigRef) ne 'HASH' );

        my @AutomaticStates;
        if ( defined $ConfigRef->{ValidStates}->{ $TicketData{Type} } ) {
            @AutomaticStates = split( /,/, $ConfigRef->{ValidStates}->{ $TicketData{Type} } );
        }

        foreach my $State (@AutomaticStates) {

            # Blanks remove
            $State =~ s/^\s+|\s+$//g;

            next if ( $TicketData{State} ne $State );

            if ( $TicketData{State} eq $State ) {

                # unlock Ticket
                $Self->{TicketObject}->TicketLockSet(
                    Lock               => 'unlock',
                    TicketID           => $Param{Data}->{TicketID},
                    SendNoNotification => 0,
                    UserID             => 1,
                );
            }
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
