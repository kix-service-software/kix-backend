# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Ticket::Delete;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Ticket',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Delete one or more tickets.');
    $Self->AddOption(
        Name        => 'ticket-number',
        Description => "Specify one or more ticket numbers of tickets to be deleted.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
        Multiple    => 1,
    );
    $Self->AddOption(
        Name        => 'ticket-id',
        Description => "Specify one or more ticket ids of tickets to be deleted.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+/smx,
        Multiple    => 1,
    );

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    my @TicketIDs     = @{ $Self->GetOption('ticket-id')     // [] };
    my @TicketNumbers = @{ $Self->GetOption('ticket-number') // [] };

    if ( !@TicketIDs && !@TicketNumbers ) {
        die "Please provide option --ticket-id or --ticket-number.\n";
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Deleting tickets...</yellow>\n");

    my @TicketIDs     = @{ $Self->GetOption('ticket-id')     // [] };
    my @TicketNumbers = @{ $Self->GetOption('ticket-number') // [] };

    my @DeleteTicketIDs;

    TICKETNUMBER:
    for my $TicketNumber (@TicketNumbers) {

        # lookup ticket id
        my $TicketID = $Kernel::OM->Get('Ticket')->TicketIDLookup(
            TicketNumber => $TicketNumber,
            UserID       => 1,
        );

        # error handling
        if ( !$TicketID ) {
            $Self->PrintError("Unable to find ticket number $TicketNumber.\n");
            next TICKETNUMBER;
        }

        push @DeleteTicketIDs, $TicketID;
    }

    TICKETID:
    for my $TicketID (@TicketIDs) {

        # lookup ticket number
        my $TicketNumber = $Kernel::OM->Get('Ticket')->TicketNumberLookup(
            TicketID => $TicketID,
            UserID   => 1,
        );

        # error handling
        if ( !$TicketNumber ) {
            $Self->PrintError("Unable to find ticket id $TicketID.\n");
            next TICKETID;
        }

        push @DeleteTicketIDs, $TicketID;
    }

    my $DeletedTicketCount = 0;

    TICKETID:
    for my $TicketID (@DeleteTicketIDs) {

        # delete the ticket
        my $True = $Kernel::OM->Get('Ticket')->TicketDelete(
            TicketID => $TicketID,
            UserID   => 1,
        );

        # error handling
        if ( !$True ) {
            $Self->PrintError("Unable to delete ticket with id $TicketID\n");
            next TICKETID;
        }

        $Self->Print("  $TicketID\n");

        # increase the deleted ticket count
        $DeletedTicketCount++;
    }

    if ( !$DeletedTicketCount ) {
        return $Self->ExitCodeError();
    }

    $Self->Print("<green>$DeletedTicketCount tickets have been deleted.</green>\n");
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
