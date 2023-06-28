# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::Installation::Migrate::KIX17::MigrateTicketAttachments;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Migration',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Migrate the ticket article attachments in filesystem.');

    $Self->AddOption(
        Name        => 'source-id',
        Description => "And identifier for this specific source.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    $Self->AddOption(
        Name        => 'directory',
        Description => "The directory where the ticket article attachments can be found.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    $Self->AddOption(
        Name        => 'workers',
        Description => "The number of parallel processes to use.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->{TimeObject} = $Kernel::OM->Get('Time');
    $Self->{MainObject} = $Kernel::OM->Get('Main');

    $Self->Print("<yellow>Migrating ticket article attachments...</yellow>\n");

    my $WorkerCount = $Self->GetOption('workers') || 1;
    $Self->{ArticleDir} = $Self->GetOption('directory');

    # get the list of migrated articles
    my $Success = $Kernel::OM->Get('DB')->Prepare(
        SQL => "SELECT m.source_object_id, m.object_id, a.create_time FROM migration m, article a WHERE object_type = 'article' AND cast(a.id as varchar) = m.object_id"
    );
    if ( !$Success ) {
        $Self->PrintError("DB error while retrieving the relevant articles\n");
    }
    my $ArticleList = $Kernel::OM->Get('DB')->FetchAllArrayRef(
        Columns => [ 'SourceObjectID', 'ObjectID', 'ArticleCreateTime' ],
    );

    if ( !IsArrayRefWithData($ArticleList) ) {
        $Self->Print("<green>No migrated articles found.</green>\n");
        return $Self->ExitCodeOk();
    }

    my $ArticleCount = scalar @{$ArticleList || []};

    $Self->Print("Articles: ".$ArticleCount."\n");

    my %WorkerList;
    my $Id;
    while( my @List = splice( @{$ArticleList}, 0, ($ArticleCount / $WorkerCount) ) ) {
        $WorkerList{++$Id} = \@List;
    }

    my @PIDs;
    foreach my $WorkerID ( 1..$WorkerCount ) {
        my $PID = $Self->StartWorker(
            ID          => $WorkerID,
            ArticleList => $WorkerList{$WorkerID},
        );
        if ( !$PID ) {
            $Self->PrintError("Unable to start worker #$WorkerID!\n");
        }
        else {
            push @PIDs, $PID;
        }
    }

    # wait for the workers to finish
    my $WorkersActive;
    do {
        $WorkersActive = waitpid -1, 0;
    } 
    while ($WorkersActive > 0);

    $Self->Print("<green>Done.</green>\n");

    return $Self->ExitCodeOk();
}

sub StartWorker {
    my ( $Self, %Param ) = @_;

    my $PID = fork;
    if ( !$PID ) {
        $Self->_Worker(
            %Param,
        );
        print STDERR "worker #$Param{ID} finished!\n";
        exit 0;
    }

    $Self->Print("started worker #$Param{ID} (PID: $PID)\n");

    return $PID;
}

sub _Worker {
    my ( $Self, %Param ) = @_;

    my $MigratedCount = 0;
    my $ArticleCount = scalar(@{$Param{ArticleList} || []});

    ITEM:
    foreach my $Article ( @{$Param{ArticleList} || []} ) {
        #print STDERR "#$Param{ID}: $Article->{SourceObjectID}, $Article->{ObjectID}\n";
        if ( ++$MigratedCount % 1000 == 0 || $MigratedCount == $ArticleCount ) {
            $Self->Print("<yellow>worker #$Param{ID}: $MigratedCount/$ArticleCount</yellow>\n");
        }

        my $CreateTimeUnix = $Self->{TimeObject}->TimeStamp2SystemTime(
            String => $Article->{ArticleCreateTime},
        );

        my ( $Sec, $Min, $Hour, $Day, $Month, $Year ) = $Self->{TimeObject}->SystemTime2Date(
            SystemTime => $CreateTimeUnix,
        );
        my $ArticleContentPath = $Self->{ArticleDir} . '/' . $Year . '/' . $Month . '/' . $Day;

        # ignore same ID
        next ITEM if $Article->{SourceObjectID} == $Article->{ObjectID};

        # check if we have article content
        next ITEM if ( !-d "$ArticleContentPath/$Article->{SourceObjectID}" );

        # ignore is already migrated
        next ITEM if ( -f "$ArticleContentPath/$Article->{SourceObjectID}/.migrated" );

        # rename the article directory (=ArticleID)
        `mv $ArticleContentPath/$Article->{SourceObjectID} $ArticleContentPath/$Article->{ObjectID}`;
        if ( $? ) {
            $Self->PrintError("Unable to rename article attachment directory $ArticleContentPath/$Article->{SourceObjectID}! (Error: $!)");
            next ITEM;
        }

        my $Content = $Article->{SourceObjectID}.'::'.$Self->{TimeObject}->CurrentTimestamp();

        my $Success = $Self->{MainObject}->FileWrite(
            Directory => "$ArticleContentPath/$Article->{ObjectID}",
            Filename  => '.migrated',
            Content   => \$Content,
        );
        if ( !$Success ) {
            $Self->PrintError("Unable to create .migrated file in $ArticleContentPath/$Article->{ObjectID}! (Error: $!)");
            next ITEM;
        }
    }
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
