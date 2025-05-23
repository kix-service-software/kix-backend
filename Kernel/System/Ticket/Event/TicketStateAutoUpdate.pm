# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Ticket::Event::TicketStateAutoUpdate;

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

    # handle only events with given TicketID
    return 1 if ( !$Param{Data}->{TicketID} );

    my $TicketStateAutoUpdate = $Self->{ConfigObject}->Get('TicketStateAutoUpdate');
    my $TicketStateAutoUpdateExtended = $Self->{ConfigObject}->Get('TicketStateAutoUpdateExtension');

    if ( defined $TicketStateAutoUpdateExtended && ref $TicketStateAutoUpdateExtended eq 'HASH' ) {
        for my $Extension ( sort keys %{$TicketStateAutoUpdateExtended} ) {
            for my $ConfigOption (qw(NonOverridableTicketStateOnUnlock NonOverridableTicketStateOnLock DefaultTicketStateOnUnlock DefaultTicketStateOnLock)) {
                for my $Item ( keys %{ $TicketStateAutoUpdateExtended->{$Extension}->{$ConfigOption} } ) {
                    $TicketStateAutoUpdate->{$ConfigOption}->{$Item} = $TicketStateAutoUpdateExtended->{$Extension}->{$ConfigOption}->{$Item};
                }
            }
        }
    }

    if ( $Param{Event} eq 'TicketLockUpdate' ) {

        # get defaultticketstate...
        if ( $Self->{TicketObject}->TicketLockGet( TicketID => $Param{Data}->{TicketID} ) ) {

            $DefaultState           = $TicketStateAutoUpdate->{DefaultTicketStateOnLock};
            $NonOverrideTicketState = $TicketStateAutoUpdate->{NonOverridableTicketStateOnLock};

        }
        elsif ( !$Self->{TicketObject}->TicketLockGet( TicketID => $Param{Data}->{TicketID} ) ) {

            $DefaultState           = $TicketStateAutoUpdate->{DefaultTicketStateOnUnlock};
            $NonOverrideTicketState = $TicketStateAutoUpdate->{NonOverridableTicketStateOnUnlock};

        }

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

        #return if current state is already default state
        return 1
            if (
            ref($DefaultState) ne 'HASH'
            || ref($NonOverrideTicketState) ne 'HASH'
            || !$DefaultState->{ $TicketData{Type} }
            );

        my @NonOverrideState;
        if ( defined $NonOverrideTicketState->{ $TicketData{Type} } ) {
            @NonOverrideState = split( /,/, $NonOverrideTicketState->{ $TicketData{Type} } );
        }

        foreach my $State (@NonOverrideState) {

            # Blanks remove
            $State =~ s/^\s+|\s+$//g;
            return 1 if ( $TicketData{State} eq $State );
        }

        #update state if force state update is enabeled...
        if (
            ref($DefaultState) eq 'HASH'
            && $DefaultState->{ $TicketData{Type} }
            )
        {
            $Self->{TicketObject}->TicketStateSet(
                State    => $DefaultState->{ $TicketData{Type} },
                TicketID => $TicketData{TicketID},
                UserID   => $Self->{UserID} || 1,
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
