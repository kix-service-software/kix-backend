# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Ticket::FulltextIndexRebuild;

use strict;
use warnings;

use Time::HiRes();

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = qw(
    Config
    Ticket
    ObjectSearch
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Completely rebuild the article search index.');
    $Self->AddOption(
        Name        => 'micro-sleep',
        Description => "Specify microseconds to sleep after every ticket to reduce system load (e.g. 1000).",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^\d+$/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Rebuilding article search index...</yellow>\n");

    # disable ticket events
    $Kernel::OM->Get('Config')->{'Ticket::EventModulePost'} = {};

    my $TicketObject = $Kernel::OM->Get('Ticket');

    # get all tickets
    my @TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Ticket',
        Result     => 'ARRAY',
        UserID     => 1,
        UserType   => 'Agent',
        Limit      => 100_000_000,
        Sort       => [
            {
                Field     => 'Age',
                Direction => 'DESCENDING'
            }
        ]
    );

    my $Count      = 0;
    my $MicroSleep = $Self->GetOption('micro-sleep');

    TICKETID:
    for my $TicketID (@TicketIDs) {

        $Count++;

        # get articles
        my @ArticleIndex = $TicketObject->ArticleIndex(
            TicketID => $TicketID,
            UserID   => 1,
        );

        for my $ArticleID (@ArticleIndex) {
            $TicketObject->ArticleIndexBuild(
                ArticleID => $ArticleID,
                UserID    => 1,
            );
        }

        if ( $Count % 2000 == 0 ) {
            my $Percent = int( $Count / ( $#TicketIDs / 100 ) );
            $Self->Print(
                "<yellow>$Count</yellow> of <yellow>$#TicketIDs</yellow> processed (<yellow>$Percent %</yellow> done).\n"
            );
        }

        if ( $MicroSleep ) {
            Time::HiRes::usleep($MicroSleep);
        }
    }

    $Self->Print("<green>Done.</green>\n");
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
