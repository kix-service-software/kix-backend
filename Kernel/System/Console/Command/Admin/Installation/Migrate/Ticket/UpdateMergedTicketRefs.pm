# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::Installation::Migrate::Ticket::UpdateMergedTicketRefs;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'DB',
    'Ticket',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Update the ticket refs in the history of merged tickets.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Migrating merged ticket refs...</yellow>\n");

    my $SQL = <<END;
        SELECT th.id,
               th.name,
               th.ticket_id 
          FROM ticket_history th, 
               ticket_history_type tht
         WHERE th.history_type_id = tht.id 
           AND tht.name = 'Merged' 
END

    # get the list of history entries of merged tickets from the given migration
    my $Success = $Kernel::OM->Get('DB')->Prepare(
        SQL => $SQL
    );
    if ( !$Success ) {
        $Self->PrintError("DB error while retrieving the relevant ticket history items\n");
    }
    my $HistoryList = $Kernel::OM->Get('DB')->FetchAllArrayRef(
        Columns => [ 'ID', 'Name', 'TicketID' ],
    );

    if ( !IsArrayRefWithData($HistoryList) ) {
        $Self->Print("<green>No relevant history items found.</green>\n");
        return $Self->ExitCodeOk();
    }

    my $HistoryCount = scalar @{$HistoryList || []};

    $Self->Print("History Items: ".$HistoryCount."\n");

    $Self->_Worker(
        HistoryList => $HistoryList
    );

    $Self->Print("<green>Done.</green>\n");

    return $Self->ExitCodeOk();
}

sub _Worker {
    my ( $Self, %Param ) = @_;

    my $MigratedCount = 0;
    my $HistoryCount = scalar(@{$Param{HistoryList} || []});

    my $TicketObject = $Kernel::OM->Get('Ticket');

    ITEM:
    foreach my $Item ( @{$Param{HistoryList} || []} ) {
        if ( ++$MigratedCount % 1000 == 0 || $MigratedCount == $HistoryCount ) {
            $Self->Print("<yellow>$MigratedCount/$HistoryCount</yellow>\n");
        }

        if ( $Item->{Name} =~ /^Merged Ticket \((\w+)\/(\d+)\) to \((\w+)\/(\d+)\)$/ ) {
            my $TicketNumber1 = $1;
            my $TicketID1     = $2;
            my $TicketNumber2 = $3;
            my $TicketID2     = $4;

            my $LookupTicketID1 = $TicketObject->TicketIDLookup(
                TicketNumber => $TicketNumber1,
                UserID       => 1,
            );
            if ( !$LookupTicketID1 ) {
                $Self->PrintError("Ticket $TicketNumber1 not found!. Skipping history item $Item->{ID}.\n");
                next ITEM;
            }

            my $LookupTicketID2 = $TicketObject->TicketIDLookup(
                TicketNumber => $TicketNumber2,
                UserID       => 1,
            );
            if ( !$LookupTicketID2 ) {
                $Self->PrintError("Ticket $TicketNumber2 not found! Skipping history item $Item->{ID}.\n");
                next ITEM;
            }

            if ( $TicketID1 ne $LookupTicketID1 || $TicketID2 ne $LookupTicketID2 ) {
                my $UpdateText = "Merged Ticket ($TicketNumber1/$LookupTicketID1) to ($TicketNumber2/$LookupTicketID2)";

                my $Success = $Kernel::OM->Get('DB')->Do(
                    SQL => 'UPDATE ticket_history SET name = ? WHERE id = ?',
                    Bind => [ \$UpdateText, \$Item->{ID} ],
                );
                if ( !$Success ) {
                    $Self->PrintError("Unable to update history item $Item->{ID}\n");
                    next ITEM;
                }

                # clear caches of ticket
                $TicketObject->_TicketCacheClear(
                    TicketID => $Item->{TicketID}
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
