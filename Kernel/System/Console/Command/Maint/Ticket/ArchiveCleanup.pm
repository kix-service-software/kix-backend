# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Ticket::ArchiveCleanup;

use strict;
use warnings;

use Time::HiRes();

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Config',
    'DB',
    'Ticket',
    'Watcher',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Deletes ticket/article seen flags and ticket watcher entries for archived tickets.');
    $Self->AddOption(
        Name        => 'micro-sleep',
        Description => "Specify microseconds to sleep after every ticket to reduce system load (e.g. 1000).",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^\d+$/smx,
    );

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    if ( !$Kernel::OM->Get('Config')->Get('Ticket::ArchiveSystem') ) {
        die "Ticket::ArchiveSystem is not enabled!\n";
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Cleaning up ticket archive...</yellow>\n");

    my $ConfigObject = $Kernel::OM->Get('Config');
    my $DBObject     = $Kernel::OM->Get('DB');
    my $TicketObject = $Kernel::OM->Get('Ticket');
    my $MicroSleep   = $Self->GetOption('micro-sleep');

    if ( $ConfigObject->Get('Ticket::ArchiveSystem::RemoveSeenFlags') ) {

        $Self->Print("<yellow>Checking for archived tickets with seen flags...</yellow>\n");

        # Find all archived tickets which have ticket seen flags set
        return if !$DBObject->Prepare(
            SQL => "
                SELECT DISTINCT(ticket.id)
                FROM ticket
                    INNER JOIN ticket_flag ON ticket.id = ticket_flag.ticket_id
                WHERE ticket.archive_flag = 1
                    AND ticket_flag.ticket_key = 'Seen'",
            Limit => 1_000_000,
        );

        my @TicketIDs;
        while ( my @Row = $DBObject->FetchrowArray() ) {
            push @TicketIDs, $Row[0];
        }

        my $Count = 0;
        for my $TicketID (@TicketIDs) {
            $TicketObject->TicketFlagDelete(
                TicketID => $TicketID,
                Key      => 'Seen',
                AllUsers => 1,
            );
            $Count++;
            $Self->Print("    Removing seen flags of ticket $TicketID\n");
            Time::HiRes::usleep($MicroSleep) if $MicroSleep;
        }

        $Self->Print("<green>Done</green> (changed <yellow>$Count</yellow> tickets).\n");
        $Self->Print("<yellow>Checking for archived articles with seen flags...</yellow>\n");

        # Find all articles of archived tickets which have ticket seen flags set
        return if !$DBObject->Prepare(
            SQL => "
                SELECT DISTINCT(article.id)
                FROM article
                    INNER JOIN ticket ON ticket.id = article.ticket_id
                    INNER JOIN article_flag ON article.id = article_flag.article_id
                WHERE ticket.archive_flag = 1
                    AND article_flag.article_key = 'Seen'",
            Limit => 1_000_000,
        );

        my @ArticleIDs;
        while ( my @Row = $DBObject->FetchrowArray() ) {
            push @ArticleIDs, $Row[0];
        }

        $Count = 0;
        for my $ArticleID (@ArticleIDs) {
            $TicketObject->ArticleFlagDelete(
                ArticleID => $ArticleID,
                Key       => 'Seen',
                AllUsers  => 1,
            );
            $Count++;
            $Self->Print("    Removing seen flags of article $ArticleID\n");
            Time::HiRes::usleep($MicroSleep) if $MicroSleep;
        }

        $Self->Print("<green>Done</green> (changed <yellow>$Count</yellow> articles).\n");
    }

    if (
        $ConfigObject->Get('Ticket::ArchiveSystem::RemoveTicketWatchers')
        )
    {

        $Self->Print("<yellow>Checking for archived tickets with ticket watcher entries...</yellow>\n");

        # Find all archived tickets which have ticket seen flags set
        return if !$DBObject->Prepare(
            SQL => "
                SELECT DISTINCT(ticket.id)
                FROM ticket
                    INNER JOIN watcher ON ticket.id = watcher.object_id
                WHERE ticket.archive_flag = 1",
            Limit => 1_000_000,
        );

        my $Count = 0;
        ROW:
        while ( my @Row = $DBObject->FetchrowArray() ) {
            $Kernel::OM->Get('Watcher')->WatcherDelete(
                Object   => 'Ticket',
                ObjectID => $Row[0],
                AllUsers => 1,
                UserID   => 1,
            );

            $Self->Print("    Removing ticket watcher entries of ticket $Count\n");

            Time::HiRes::usleep($MicroSleep) if $MicroSleep;
        }

        $Self->Print("<green>Done</green> (changed <yellow>$Count</yellow> tickets).\n");
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
