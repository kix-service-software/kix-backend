# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::Test;

use strict;
use warnings;

our @ObjectDependencies = (
    'Log',
    'Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Data Event Config)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # handle only events with given TicketID
    return 1 if ( !$Param{Data}->{TicketID} );

    if ( $Param{Event} eq 'TicketCreate' ) {

        # get ticket object
        my $TicketObject = $Kernel::OM->Get('Ticket');

        my %Ticket = $TicketObject->TicketGet(
            TicketID      => $Param{Data}->{TicketID},
            DynamicFields => 0,
        );

        if ( $Ticket{State} eq 'Test' ) {

            # do some stuff
            $TicketObject->HistoryAdd(
                TicketID     => $Param{Data}->{TicketID},
                CreateUserID => $Param{UserID},
                HistoryType  => 'Misc',
                Name         => 'Some Info about Changes!',
            );
        }
    }
    elsif ( $Param{Event} eq 'TicketQueueUpdate' ) {

        # get ticket object
        my $TicketObject = $Kernel::OM->Get('Ticket');

        my %Ticket = $TicketObject->TicketGet(
            TicketID      => $Param{Data}->{TicketID},
            DynamicFields => 0,
        );

        if ( $Ticket{Queue} eq 'Test' ) {

            # do some stuff
            $TicketObject->HistoryAdd(
                TicketID     => $Param{Data}->{TicketID},
                CreateUserID => $Param{UserID},
                HistoryType  => 'Misc',
                Name         => 'Some Info about Changes!',
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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
