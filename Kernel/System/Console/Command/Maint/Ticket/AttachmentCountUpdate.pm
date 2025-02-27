# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Ticket::AttachmentCountUpdate;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Ticket',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Updates the attachment count of tickets (if neither ticket-number nor ticket-id are given, all tickets will be updated).');
    $Self->AddOption(
        Name        => 'ticket-number',
        Description => "Specify one or more ticket numbers of tickets to be updated.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
        Multiple    => 1,
    );
    $Self->AddOption(
        Name        => 'ticket-id',
        Description => "Specify one or more ticket ids of tickets to be updated.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+/smx,
        Multiple    => 1,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Updating ticket attachment counts...</yellow>\n");

    my @TicketIDs     = @{ $Self->GetOption('ticket-id')     // [] };
    my @TicketNumbers = @{ $Self->GetOption('ticket-number') // [] };

    my @UpdateTicketIDs;
    if (!@TicketIDs && !@TicketNumbers) {
        @UpdateTicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
            ObjectType => 'Ticket',
            Result     => 'ARRAY',
            UserID     => 1,
        );
    } else {
        for my $TicketNumber (@TicketNumbers) {
            my $TicketID = $Kernel::OM->Get('Ticket')->TicketIDLookup(
                TicketNumber => $TicketNumber,
                UserID       => 1,
            );
            if (!$TicketID) {
                $Self->PrintError("Unable to find ticket number $TicketNumber.\n");
                next;
            }
            push(@UpdateTicketIDs, $TicketID);
        }
        for my $TicketID (@TicketIDs) {
            my $TicketNumber = $Kernel::OM->Get('Ticket')->TicketNumberLookup(
                TicketID => $TicketID,
                UserID   => 1,
            );
            if (!$TicketNumber) {
                $Self->PrintError("Unable to find ticket id $TicketID.\n");
            }
            push(@UpdateTicketIDs, $TicketID);
        }
        @UpdateTicketIDs = $Kernel::OM->Get('Main')->GetUnique(@UpdateTicketIDs);
    }

    if (@UpdateTicketIDs) {
        for my $TicketID (@UpdateTicketIDs) {
            $Self->Print("  ticket: $TicketID\n");

            my $Success = $Kernel::OM->Get('Ticket')->TicketAttachmentCountUpdate(
                TicketID => $TicketID,
                UserID   => 1,
                Notify   => 1
            );

            if (!$Success) {
                $Self->PrintError("Unable to update attachment count of ticket with id '$TicketID'\n");
            }
        }
    }

    $Self->Print("<green>Attachment count(s) updated.</green>\n");
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
