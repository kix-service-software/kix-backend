# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::Article::StorageSwitch;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = qw(
    Config
    PID
    Ticket
    Time
    ObjectSearch
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Migrate article files from one storage backend to another on the fly.');
    $Self->AddOption(
        Name        => 'target',
        Description => "Specify the target backend to migrate to (ArticleStorageDB|ArticleStorageFS).",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/^(?:ArticleStorageDB|ArticleStorageFS)$/smx,
    );
    $Self->AddOption(
        Name        => 'tickets-closed-before-date',
        Description => "Only process tickets closed before given ISO date.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^\d{4}-\d{2}-\d{2}[ ]\d{2}:\d{2}:\d{2}$/smx,
    );
    $Self->AddOption(
        Name        => 'tickets-closed-before-days',
        Description => "Only process tickets closed more than ... days ago.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^\d+$/smx,
    );
    $Self->AddOption(
        Name        => 'tolerant',
        Description => "Continue after failures.",
        Required    => 0,
        HasValue    => 0,
    );
    $Self->AddOption(
        Name        => 'micro-sleep',
        Description => "Specify microseconds to sleep after every ticket to reduce system load (e.g. 1000).",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^\d+$/smx,
    );
    $Self->AddOption(
        Name        => 'force-pid',
        Description => "Start even if another process is still registered in the database.",
        Required    => 0,
        HasValue    => 0,
    );

    my $Name = $Self->Name();

    $Self->AdditionalHelp(<<"EOF");
The <green>$Name</green> command migrates article data from one storage backend to another on the fly, for example from DB to FS:

 <green>kix.Console.pl $Self->{Name} --target ArticleStorageFS</green>

You can specify limits for the tickets migrated with <yellow>--tickets-closed-before-date</yellow> and <yellow>--tickets-closed-before-days</yellow>.

To reduce load on the database for a running system, you can use the <yellow>--micro-sleep</yellow> parameter. The command will pause for the specified amount of microseconds after each ticket.

 <green>kix.Console.pl $Self->{Name} --target ArticleStorageFS --micro-sleep 1000</green>
EOF
    return;
}

sub PreRun {
    my ($Self) = @_;

    my $PIDCreated = $Kernel::OM->Get('PID')->PIDCreate(
        Name  => $Self->Name(),
        Force => $Self->GetOption('force-pid'),
        TTL   => 60 * 60 * 24 * 3,
    );
    if ( !$PIDCreated ) {
        my $Error = "Unable to register the process in the database. Is another instance still running?\n";
        $Error .= "You can use --force-pid to override this check.\n";
        die $Error;
    }

    return;
}

sub Run {
    my ($Self) = @_;

    # disable ticket events
    $Kernel::OM->Get('Config')->{'Ticket::EventModulePost'} = {};

    # extended input validation
    my %SearchParams;

    if ( $Self->GetOption('tickets-closed-before-date') ) {
        $SearchParams{Search}->{AND} = [
            {
                Field    => 'StateType',
                Operator => 'EQ',
                Type     => 'STRING',
                Value    => 'Closed'
            },
            {
                Field    => 'CloseTime',
                Operator => 'LTE',
                Type     => 'STRING',
                Value    => $Self->GetOption('tickets-closed-before-date')
            }
        ];
    }
    elsif ( $Self->GetOption('tickets-closed-before-days') ) {
        my $Seconds = $Self->GetOption('tickets-closed-before-days') * 60 * 60 * 24;

        my $TimeStamp = $Kernel::OM->Get('Time')->SystemTime() - $Seconds;
        $TimeStamp = $Kernel::OM->Get('Time')->SystemTime2TimeStamp(
            SystemTime => $TimeStamp,
        );
        $SearchParams{Search}->{AND} = [
            {
                Field    => 'StateType',
                Operator => 'EQ',
                Type     => 'STRING',
                Value    => 'Closed'
            },
            {
                Field    => 'CloseTime',
                Operator => 'LTE',
                Type     => 'STRING',
                Value    => $TimeStamp
            }
        ];
    }

    my @TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Ticket',
        Result     => 'ARRAY',
        UserID     => 1,
        UserType   => 'Agent',
        %SearchParams
    );

    my $Count      = 0;
    my $CountTotal = scalar @TicketIDs;

    my $Target        = $Self->GetOption('target');
    my %Target2Source = (
        ArticleStorageFS => 'ArticleStorageDB',
        ArticleStorageDB => 'ArticleStorageFS',
    );

    my $MicroSleep = $Self->GetOption('micro-sleep');
    my $Tolerant   = $Self->GetOption('tolerant');

    TICKETID:
    for my $TicketID (@TicketIDs) {

        $Count++;

        $Self->Print("$Count/$CountTotal (TicketID:$TicketID)\n");

        my $Success = $Kernel::OM->Get('Ticket')->TicketArticleStorageSwitch(
            TicketID    => $TicketID,
            Source      => $Target2Source{$Target},
            Destination => $Target,
            UserID      => 1,
        );

        return $Self->ExitCodeError() if !$Tolerant && !$Success;

        if ( $MicroSleep ) {
            Time::HiRes::usleep($MicroSleep);
        }
    }

    $Self->Print("<green>Done.</green>\n");

    return $Self->ExitCodeOk();

}

sub PostRun {
    my ($Self) = @_;

    return $Kernel::OM->Get('PID')->PIDDelete( Name => $Self->Name() );
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
