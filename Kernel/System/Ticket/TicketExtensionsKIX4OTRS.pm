# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Ticket::TicketExtensionsKIX4OTRS;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

use Kernel::System::TemplateGenerator;
use Kernel::System::VariableCheck qw(:all);

=item CommonNextStates()

Returns a hash of common next states for multiple tickets (based on TicketStateWorkflow).

    my %StateHash = $TicketObject->TSWFCommonNextStates(
        TicketIDs => [ 1, 2, 3, 4], # required
        Action => 'SomeActionName', # optional
        UserID => 1,                # optional
    );

=cut

sub TSWFCommonNextStates {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketIDs} || ref( $Param{TicketIDs} ) ne 'ARRAY' ) {
        $Kernel::OM->Get('Kernel::System::Log')
            ->Log( Priority => 'error', Message => 'Need TicketIDs as array ref!' );
        return;
    }
    $Self->{TicketObject} = $Param{TicketObject} || $Kernel::OM->Get('Kernel::System::Ticket');

    my %Result = ();
    if ( $Param{StateType} ) {
        %Result = $Kernel::OM->Get('Kernel::System::State')->StateGetStatesByType(
            StateType => $Param{StateType},
            Result    => 'HASH',
            Action    => $Param{Action} || '',
            UserID    => $Param{UserID} || 1,
        );
    }
    else {
        %Result = $Kernel::OM->Get('Kernel::System::State')->StateList(
            UserID => $Param{UserID} || 1,
        );
    }

    my %NextStates = ();
    for my $CurrTID ( @{ $Param{TicketIDs} } ) {

        my %States = $Kernel::OM->Get('Kernel::System::Ticket')->TicketStateList(
            TicketID => $CurrTID,
            UserID => $Param{UserID} || 1,
        );

        my @CurrNextStatesArr;
        for my $ThisState ( keys %States ) {
            push( @CurrNextStatesArr, $States{$ThisState} );
        }

        # init next states set...
        if ( !%NextStates ) {
            %NextStates = map { $_ => 1 } @CurrNextStatesArr;
        }

        # check if current next states are common with previous next states...
        else {
            for my $CurrStateCheck ( keys(%NextStates) ) {

                #remove trailing or leading spaces...
                $CurrStateCheck =~ s/^\s+//g;
                $CurrStateCheck =~ s/\s+$//g;

                next if ( grep { $_ eq $CurrStateCheck } @CurrNextStatesArr );
                delete( $NextStates{$CurrStateCheck} )
            }
        }

        # end if no next states available at all..
        last if ( !%NextStates );
    }
    for my $CurrStateID ( keys(%Result) ) {
        next if ( $NextStates{ $Result{$CurrStateID} } );
        delete( $Result{$CurrStateID} );
    }

    return %Result;
}

=item TicketQueueLinkGet()

Returns a link to the queue of a given ticket.

    my $Result = $TicketObject->TicketQueueLinkGet(
        TicketID => 123,
        UserID   => 123,
    );

=cut

sub TicketQueueLinkGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketID} ) {
        $Kernel::OM->Get('Kernel::System::Log')
            ->Log( Priority => 'error', Message => 'Need TicketID!' );
        return;
    }

    my $SessionID = '';
    if ( !$Kernel::OM->Get('Kernel::Config')->Get('SessionUseCookie') && $Param{SessionID} ) {
        $SessionID = ';' . $Param{SessionName} . '=' . $Param{SessionID};
    }

    my $Output =
        '<a href="?Action=AgentTicketQueue;QueueID='
        . $Param{'QueueID'}
        . $SessionID . '">'
        . $Param{'Queue'} . '</a>';


    return $Output;
}

=item CountArticles()

Returns the number of articles of a given ticket.

    my $Result = $TicketObject->CountArticles(
        TicketID => 123,
        UserID   => 123,
    );

=cut

sub CountArticles {
    my ( $Self, %Param ) = @_;
    my $Result = 0;

    my @ArticleIndexList = $Self->ArticleIndex(
        TicketID => $Param{TicketID},
    );

    $Result = ( scalar(@ArticleIndexList) || 0 );

    return $Result;
}

=item CountAttachments()

Returns the number of attachments in all articles of a given ticket.

    my $Result = $TicketObject->CountAttachments(
        TicketID => 123,
        UserID   => 123,
    );

=cut

sub CountAttachments {
    my ( $Self, %Param ) = @_;
    my $Result = 0;

    my @ArticleList = $Self->ArticleContentIndex(
        TicketID                   => $Param{TicketID},
        StripPlainBodyAsAttachment => 1,
        UserID                     => $Param{UserID} || 1,
    );

    for my $Article (@ArticleList) {
        my %AtmIndex = %{ $Article->{Atms} };
        my @AtmKeys  = keys(%AtmIndex);
        $Result = $Result + ( scalar(@AtmKeys) || 0 );
    }

    return $Result;
}

=item CountLinkedObjects()

Returns the number of objects linked with a given ticket.

    my $Result = $TicketObject->CountLinkedObjects(
        TicketID => 123,
        UserID   => 123,
    );

=cut

sub CountLinkedObjects {
    my ( $Self, %Param ) = @_;
    my $Result = 0;
    my $LinkObject = $Kernel::OM->Get('Kernel::System::LinkObject') || undef;

    if ( !$LinkObject ) {
        $LinkObject = Kernel::System::LinkObject->new( %{$Self} );
    }

    return '' if !$LinkObject;

    my %PossibleObjectsList = $LinkObject->PossibleObjectsList(
        Object => 'Ticket',
        UserID => 1,
    );

    # get user preferences
    my %UserPreferences
        = $Kernel::OM->Get('Kernel::System::User')->GetPreferences( UserID => $Param{UserID} );

    for my $CurrObject ( keys(%PossibleObjectsList) ) {
        my %LinkList = $LinkObject->LinkKeyList(
            Object1 => 'Ticket',
            Key1    => $Param{TicketID},
            Object2 => $CurrObject,
            State   => 'Valid',
            UserID  => 1,
        );

        # do not count merged tickets if user preference set
        my $LinkCount = 0;
        if ( $CurrObject eq 'Ticket' ) {
            foreach my $ObjectID ( keys %LinkList ) {
                my %Ticket = $Self->TicketGet( TicketID => $ObjectID );
                next
                    if (
                    (
                        !defined $UserPreferences{UserShowMergedTicketsInLinkedObjects}
                        || !$UserPreferences{UserShowMergedTicketsInLinkedObjects}
                    )
                    && $Ticket{StateType} eq 'merged'
                    );
                $LinkCount++;
            }
        }
        else {
            $LinkCount = scalar( keys(%LinkList) );
        }
        $Result = $Result + ( $LinkCount || 0 );
    }

    return $Result;
}

=item GetTotalNonEscalationRelevantBusinessTime()

Calculate non relevant time for escalation.

    my $Result = $TicketObject->GetTotalNonEscalationRelevantBusinessTime(
        TicketID => 123,  # required
        Type     => "",   # optional ( Response | Solution )
    );

=cut

sub GetTotalNonEscalationRelevantBusinessTime {
    my ( $Self, %Param ) = @_;

    $Self->{StateObject} = $Kernel::OM->Get('Kernel::System::State');
    $Self->{TimeObject}  = $Kernel::OM->Get('Kernel::System::Time');

    return if !$Param{TicketID};

    # get optional parameter
    $Param{Type} ||= '';
    if ( $Param{StartTimestamp} ) {
        $Param{StartTime} = $Self->{TimeObject}->TimeStamp2SystemTime(
            String => $Param{StartTimestamp},
        );
    }
    if ( $Param{StopTimestamp} ) {
        $Param{StopTime} = $Self->{TimeObject}->TimeStamp2SystemTime(
            String => $Param{StopTimestamp},
        );
    }

    # get some config values if required...
    if ( !$Param{RelevantStates} ) {
        my $RelevantStateNamesArrRef =
            $Kernel::OM->Get('Kernel::Config')->Get('Ticket::EscalationDisabled::RelevantStates');
        if ( ref($RelevantStateNamesArrRef) eq 'ARRAY' ) {
            my $RelevantStateNamesArrStrg = join( ',', @{$RelevantStateNamesArrRef} );
            my %StateListHash = $Self->{StateObject}->StateList( UserID => 1 );
            for my $CurrStateID ( keys(%StateListHash) ) {
                if ( grep { $_ eq $StateListHash{$CurrStateID} } @{$RelevantStateNamesArrRef} ) {
                    $Param{RelevantStates}->{$CurrStateID} = $StateListHash{$CurrStateID};
                }
            }
        }
    }
    my %RelevantStates = ();
    if ( ref( $Param{RelevantStates} ) eq 'HASH' ) {
        %RelevantStates = %{ $Param{RelevantStates} };
    }

    # get esclation data...
    my %Ticket = $Self->TicketGet(
        TicketID => $Param{TicketID},
        UserID   => 1,
    );
    my %Escalation = $Self->TicketEscalationPreferences(
        Ticket => \%Ticket,
        UserID => 1,
    );

    # get all history lines...
    my @HistoryLines = $Self->HistoryGet(
        TicketID => $Param{TicketID},
        UserID   => 1,
    );

    my $PendStartTime = 0;
    my $PendTotalTime = 0;
    my $Solution      = 0;

    my %ClosedStateList = $Self->{StateObject}->StateGetStatesByType(
        StateType => ['closed'],
        Result    => 'HASH',
    );
    for my $HistoryHash (@HistoryLines) {
        my $CreateTime = $Self->{TimeObject}->TimeStamp2SystemTime(
            String => $HistoryHash->{CreateTime},
        );

        # skip not relevant history information
        next if ( $Param{StartTime} && $Param{StartTime} > $CreateTime );
        next if ( $Param{StopTime}  && $Param{StopTime} < $CreateTime );

        # proceed history information
        if (
            $HistoryHash->{HistoryType} eq 'StateUpdate'
            || $HistoryHash->{HistoryType} eq 'NewTicket'
            )
        {
            if ( $RelevantStates{ $HistoryHash->{StateID} } && $PendStartTime == 0 ) {

                # datetime to unixtime
                $PendStartTime = $CreateTime;
                next;
            }
            elsif ( $PendStartTime != 0 && !$RelevantStates{ $HistoryHash->{StateID} } ) {
                my $UnixEndTime = $CreateTime;
                my $WorkingTime = $Self->{TimeObject}->WorkingTime(
                    StartTime => $PendStartTime,
                    StopTime  => $UnixEndTime,
                    Calendar  => $Escalation{Calendar},
                );
                $PendTotalTime += $WorkingTime;
                $PendStartTime = 0;
            }
        }
        if (
            (
                $HistoryHash->{HistoryType}    eq 'SendAnswer'
                || $HistoryHash->{HistoryType} eq 'PhoneCallAgent'
                || $HistoryHash->{HistoryType} eq 'EmailAgent'
            )
            && $Param{Type} eq 'Response'
            )
        {
            if ( $PendStartTime != 0 ) {
                my $UnixEndTime = $CreateTime;
                my $WorkingTime = $Self->{TimeObject}->WorkingTime(
                    StartTime => $PendStartTime,
                    StopTime  => $UnixEndTime,
                    Calendar  => $Escalation{Calendar},
                );
                $PendTotalTime += $WorkingTime;
                $PendStartTime = 0;
            }
            return $PendTotalTime;
        }
        if ( $HistoryHash->{HistoryType} eq 'StateUpdate' && $Param{Type} eq 'Solution' ) {
            for my $State ( keys %ClosedStateList ) {
                if ( $HistoryHash->{StateID} == $State ) {
                    if ( $PendStartTime != 0 ) {
                        my $UnixEndTime = $CreateTime;
                        my $WorkingTime = $Self->{TimeObject}->WorkingTime(
                            StartTime => $PendStartTime,
                            StopTime  => $UnixEndTime,
                            Calendar  => $Escalation{Calendar},
                        );
                        $PendTotalTime += $WorkingTime;
                        $PendStartTime = 0;
                    }
                    return $PendTotalTime;
                }
            }
        }
    }
    return $PendTotalTime;
}

=item GetPreviousTicketState()

Returns the previous ticket state to the current one.

    my $Result = $TicketObject->GetPreviousTicketState(
        TicketID   => 123,                  # required
        ResultType => "StateName" || "ID",  # optional
    );

=cut

sub GetPreviousTicketState {
    my ( $Self, %Param ) = @_;
    my $Result = 0;

    # check needed stuff
    for (qw(TicketID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "Need $_!" );
            return 0;
        }
    }

    my $SelectValue = 'ts1.name';
    if ( $Param{ResultType} && $Param{ResultType} eq 'ID' ) {
        $SelectValue = 'ts1.id';
    }

    # following deprecated but kept for backward-compatibility...
    elsif ( $Param{ResultType} && $Param{ResultType} eq 'StateID' ) {
        $SelectValue = 'ts1.id';
    }

    my %Ticket = $Self->TicketGet(
        TicketID => $Param{TicketID},
    );
    return 0 if !%Ticket || !$Ticket{State};

    return 0 if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => "SELECT " . $SelectValue . " FROM ticket_history th1, ticket_state ts1 " .
            " WHERE " .
            "   th1.id = ( " .
            "     SELECT max(th2.id) FROM ticket_history th2, ticket_state ts2 WHERE " .
            "     th2.ticket_id = ? AND th2.create_time = th2.change_time " .
            "     AND th2.state_id = ts2.id AND ts2.name != ? " .
            "   ) " .
            "   AND ts1.id = th1.state_id ",
        Bind => [ \$Ticket{TicketID}, \$Ticket{State} ],
    );

    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        $Result = $Row[0];
    }

    return $Result;
}

=item ArticleMove()

Moves an article to another ticket

    my $Result = $TicketObject->ArticleMove(
        TicketID  => 123,
        ArticleID => 123,
        UserID    => 123,
    );

Result:
    1
    MoveFailed
    AccountFailed

Events:
    ArticleMove

=cut

sub ArticleMove {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ArticleID TicketID UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "ArticleMove: Need $Needed!" );
            return;
        }
    }

    # get Article
    my %Article = $Self->ArticleGet(
        ArticleID => $Param{ArticleID}
    );

    # update article data
    return 'MoveFailed' if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => "UPDATE article SET ticket_id = ?, "
            . "change_time = current_timestamp, change_by = ? WHERE id = ?",
        Bind => [ \$Param{TicketID}, \$Param{UserID}, \$Param{ArticleID} ],
    );

    # update time accounting data
    return 'AccountFailed' if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'UPDATE time_accounting SET ticket_id = ?, '
            . "change_time = current_timestamp, change_by = ? WHERE article_id = ?",
        Bind => [ \$Param{TicketID}, \$Param{UserID}, \$Param{ArticleID} ],
    );

    # clear ticket cache
    delete $Self->{ 'Cache::GetTicket' . $Param{TicketID} };

    # event
    $Self->EventHandler(
        Event => 'ArticleMove',
        Data  => {
            TicketID  => $Param{TicketID},
            ArticleID => $Param{ArticleID},
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Ticket.Article',
        ObjectID  => $Article{TicketID}.'::'.$Param{ArticleID},
    );

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'Ticket.Article',
        ObjectID  => $Param{TicketID}.'::'.$Param{ArticleID},
    );

    return 1;
}

=item ArticleCopy()

Copies an article to another ticket including all attachments

    my $Result = $TicketObject->ArticleCopy(
        TicketID  => 123,
        ArticleID => 123,
        UserID    => 123,
    );

Result:
    NewArticleID
    'NoOriginal'
    'CopyFailed'
    'UpdateFailed'

Events:
    ArticleCopy

=cut

sub ArticleCopy {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ArticleID TicketID UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "ArticleCopy: Need $Needed!" );
            return;
        }
    }

    # get original article content
    my %Article = $Self->ArticleGet(
        ArticleID => $Param{ArticleID},
    );
    return 'NoOriginal' if !%Article;

    # copy original article
    my $CopyArticleID = $Self->ArticleCreate(
        %Article,
        TicketID       => $Param{TicketID},
        UserID         => $Param{UserID},
        HistoryType    => 'Misc',
        HistoryComment => "Copied article $Param{ArticleID} from "
            . "ticket $Article{TicketID} to ticket $Param{TicketID}",
    );
    return 'CopyFailed' if !$CopyArticleID;

    # set article times from original article
    return 'UpdateFailed' if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL =>
            'UPDATE article SET create_time = ?, change_time = ?, incoming_time = ? WHERE id = ?',
        Bind => [
            \$Article{Created},      \$Article{Changed},
            \$Article{IncomingTime}, \$CopyArticleID
        ],
    );

    # copy attachments from original article
    my %ArticleIndex = $Self->ArticleAttachmentIndex(
        ArticleID => $Param{ArticleID},
        UserID    => $Param{UserID},
    );
    for my $Index ( keys %ArticleIndex ) {
        my %Attachment = $Self->ArticleAttachment(
            ArticleID => $Param{ArticleID},
            FileID    => $Index,
            UserID    => $Param{UserID},
        );
        $Self->ArticleWriteAttachment(
            %Attachment,
            ArticleID => $CopyArticleID,
            UserID    => $Param{UserID},
        );
    }

    # clear ticket cache
    delete $Self->{ 'Cache::GetTicket' . $Param{TicketID} };

    # copy plain article if exists
    if ( $Article{Channel} =~ /email/i ) {
        my $Data = $Self->ArticlePlain(
            ArticleID => $Param{ArticleID}
        );
        if ($Data) {
            $Self->ArticleWritePlain(
                ArticleID => $CopyArticleID,
                Email     => $Data,
                UserID    => $Param{UserID},
            );
        }
    }

    # event
    $Self->EventHandler(
        Event => 'ArticleCopy',
        Data  => {
            TicketID     => $Param{TicketID},
            ArticleID    => $CopyArticleID,
            OldArticleID => $Param{ArticleID},
        },
        UserID => $Param{UserID},
    );

    return $CopyArticleID;
}

=item ArticleFullDelete()

Delete an article, its history, its plain message, and all attachments

    my $Success = $TicketObject->ArticleFullDelete(
        ArticleID => 123,
        UserID    => 123,
    );

ATTENTION:
    sub ArticleDelete is used in this sub, but this sub does not delete
    article history

Events:
    ArticleFullDelete

=cut

sub ArticleFullDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ArticleID UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "ArticleFullDelete: Need $Needed!" );
            return;
        }
    }

    # get article content
    my %Article = $Self->ArticleGet(
        ArticleID => $Param{ArticleID},
    );
    return if !%Article;

    # clear ticket cache
    delete $Self->{ 'Cache::GetTicket' . $Article{TicketID} };

    # delete article history
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL  => 'DELETE FROM ticket_history WHERE article_id = ?',
        Bind => [ \$Param{ArticleID} ],
    );

    # delete article, attachments and plain emails
    return if !$Self->ArticleDelete(
        ArticleID => $Param{ArticleID},
        UserID    => $Param{UserID},
    );

    # event
    $Self->EventHandler(
        Event => 'ArticleFullDelete',
        Data  => {
            TicketID  => $Article{TicketID},
            ArticleID => $Param{ArticleID},
        },
        UserID => $Param{UserID},
    );

    return 1;
}

=item ArticleCreateDateUpdate()

Manipulates the article create date

    my $Result = $TicketObject->ArticleCreateDateUpdate(
        ArticleID => 123,
        UserID    => 123,
    );

Events:
    ArticleUpdate

=cut

sub ArticleCreateDateUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID ArticleID UserID Created IncomingTime)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "ArticleCreateDateUpdate: Need $Needed!" );
            return;
        }
    }

    # db update
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => "UPDATE article SET incoming_time = ?, create_time = ?,"
            . "change_time = current_timestamp, change_by = ? WHERE id = ?",
        Bind => [ \$Param{IncomingTime}, \$Param{Created}, \$Param{UserID}, \$Param{ArticleID} ],
    );

    # event
    $Self->EventHandler(
        Event => 'ArticleUpdate',
        Data  => {
            TicketID  => $Param{TicketID},
            ArticleID => $Param{ArticleID},
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Ticket.Article',
        ObjectID  => $Param{TicketID}.'::'.$Param{ArticleID},
    );

    return 1;
}

=item ArticleFlagDataSet()

set ....

    my $Success = $TicketObject->ArticleFlagDataSet(
            ArticleID   => 1,
            Key         => 'ToDo', // ArticleFlagKey
            Keywords    => Keywords,
            Subject     => Subject,
            Note        => Note,
        );
=cut

sub ArticleFlagDataSet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ArticleID Key UserID)) {
        if ( !defined( $Param{$Needed} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "ArticleFlagDataSet: Need $Needed!" );
            return;
        }
    }

    # get Article
    my %Article = $Self->ArticleGet(
        ArticleID => $Param{ArticleID}
    );

    # db quote
    for my $Quote (qw(Notes Subject Keywords Key)) {
        $Param{$Quote} = $Kernel::OM->Get('Kernel::System::DB')->Quote( $Param{$Quote} );
    }
    for my $Quote (qw(ArticleID)) {
        $Param{$Quote} = $Kernel::OM->Get('Kernel::System::DB')->Quote( $Param{$Quote}, 'Integer' );
    }

    # check if update is needed
    my %ArticleFlagData = $Self->ArticleFlagDataGet(
        ArticleID      => $Param{ArticleID},
        ArticleFlagKey => $Param{Key},
        UserID         => $Param{UserID},
    );

    # return 1 if ( %ArticleFlagData && $ArticleFlagData{ $Param{TicketID} } eq $Param{Notes} );

    # update action
    if (
        defined( $ArticleFlagData{ $Param{ArticleID} } )
        && defined( $ArticleFlagData{ $Param{Key} } )
        )
    {
        return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
            SQL =>
                'UPDATE kix_article_flag SET note = ?, subject = ?, keywords = ? '
                . 'WHERE article_id = ? AND article_key = ? AND create_by = ? ',
            Bind => [
                \$Param{Note},      \$Param{Subject}, \$Param{Keywords},
                \$Param{ArticleID}, \$Param{Key},     \$Param{UserID}
            ],
        );

        # push client callback event
        $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
            Event     => 'UPDATE',
            Namespace => 'Ticket.Article.Flag',
            ObjectID  => $Article{TicketID}.'::'.$Param{ArticleID}.'::'.$Param{Key},
        );
    }

    # insert action
    else {
        return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
            SQL =>
                'INSERT INTO kix_article_flag (article_id, article_key, keywords, subject, note, create_by) '
                . ' VALUES (?, ?, ?, ?, ?, ?)',
            Bind => [
                \$Param{ArticleID}, \$Param{Key},  \$Param{Keywords},
                \$Param{Subject},   \$Param{Note}, \$Param{UserID}
            ],
        );

        # push client callback event
        $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
            Event     => 'CREATE',
            Namespace => 'Ticket.Article.Flag',
            ObjectID  => $Article{TicketID}.'::'.$Param{ArticleID}.'::'.$Param{Key},
        );
    }

    return 1;
}

=item ArticleFlagDataDelete()

delete ....

    my $Success = $TicketObject->ArticleFlagDataDelete(
            ArticleID   => 1,
            Key         => 'ToDo',
            UserID      => $UserID,  # use either UserID or AllUsers
        );

    my $Success = $TicketObject->ArticleFlagDataDelete(
            ArticleID   => 1,
            Key         => 'ToDo',
            AllUsers    => 1,        # delete flag data from all users for this article
        );
=cut

sub ArticleFlagDataDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ArticleID Key)) {
        if ( !defined( $Param{$Needed} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "ArticleFlagDataDelete: Need $Needed!" );
            return;
        }
    }
    if ( !defined $Param{UserID} && !defined $Param{AllUsers} ) {
        $Kernel::OM->Get('Kernel::System::Log')
            ->Log(
            Priority => 'error',
            Message  => "ArticleFlagDataDelete: Need either UserID or AllUsers!"
            );
        return;
    }

    # get Article
    my %Article = $Self->ArticleGet(
        ArticleID => $Param{ArticleID}
    );

    # check if UserID or AllUsers set
    if ( $Param{UserID} ) {

        # insert action
        return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
            SQL =>
                'DELETE FROM kix_article_flag'
                . ' WHERE article_id = ? AND article_key = ? AND create_by = ? ',
            Bind => [ \$Param{ArticleID}, \$Param{Key}, \$Param{UserID} ],
        );
    }
    else {

        # insert action
        return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
            SQL =>
                'DELETE FROM kix_article_flag'
                . ' WHERE article_id = ? AND article_key = ? ',
            Bind => [ \$Param{ArticleID}, \$Param{Key} ],
        );
    }

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Ticket.Article.Flag',
        ObjectID  => $Article{TicketID}.'::'.$Param{ArticleID},
    );

    return 1;
}

=item ArticleFlagDataGet()

get ....

    my $Success = $TicketObject->ArticleFlagDataGet(
            ArticleID      => 1,
            ArticleFlagKey => 'ToDo',
            UserID         => 1
        );
=cut

sub ArticleFlagDataGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ArticleID ArticleFlagKey UserID)) {
        if ( !defined( $Param{$Needed} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "ArticleFlagGet: Need $Needed!" );
            return;
        }
    }

    # fetch the result
    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => 'SELECT article_id, article_key, subject, keywords, note, create_by'
            . ' FROM kix_article_flag'
            . ' WHERE article_id = ? AND article_key = ? AND create_by = ?',
        Bind => [ \$Param{ArticleID}, \$Param{ArticleFlagKey}, \$Param{UserID} ],
        Limit => 1,
    );

    my %ArticleFlagData;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        $ArticleFlagData{ArticleID} = $Row[0];
        $ArticleFlagData{Key}       = $Row[1];
        $ArticleFlagData{Subject}   = $Row[2];
        $ArticleFlagData{Keywords}  = $Row[3];
        $ArticleFlagData{Note}      = $Row[4];
        $ArticleFlagData{CreateBy}  = $Row[5];
    }

    return %ArticleFlagData;
}

=item SendLinkedPersonNotification()

send linked person notification via email

    my $Success = $TicketObject->SendLinkedPersonNotification(
        TicketID    => 123,
        ArticleID   => 123,
        CustomerMessageParams => {
            SomeParams => 'For the message!',
        },
        Type       => 'LinkedPersonPhoneNotification' || 'LinkedPersonNoteNotification',
        Recipients => $UserID,
        UserID     => 123,
    );

Events:
    ArticleLinkedPersonNotification

=cut

sub SendLinkedPersonNotification {
    my ( $Self, %Param ) = @_;
    my @Cc;

    # check needed stuff
    for (qw(CustomerMessageParams TicketID Type Recipients UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "SendLinkedPersonNotification: Need $_!" );
            return;
        }
    }

    # return if no notification is active
    return 1 if $Self->{SendNoNotification};

    # proceed selected linked persons
    return if ref $Param{Recipients} ne 'ARRAY';
    for my $RecipientStr ( @{ $Param{Recipients} } ) {
        my ( $RecipientType, $RecipientID ) = split( ':::', $RecipientStr );

        my %User;
        if ( $RecipientType eq 'Agent' ) {
            %User = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
                UserID => $RecipientID,
            );
        }
        else {
            %User = $Kernel::OM->Get('Kernel::System::Contact')->ContactGet(
                ID => $RecipientID,
            );
        }
        next if !$User{UserEmail} || $User{UserEmail} !~ /@/;

        my $TemplateGeneratorObject = $Kernel::OM->Get('Kernel::System::TemplateGenerator');
        my %Notification = $TemplateGeneratorObject->NotificationLinkedPerson(
            Type                  => $Param{Type},
            TicketID              => $Param{TicketID},
            ArticleID             => $Param{ArticleID} || '',
            CustomerMessageParams => $Param{CustomerMessageParams},
            RecipientID           => $RecipientID,
            RecipientType         => $RecipientType,
            RecipientData         => \%User,
            UserID                => $Param{UserID},
        );
        next if !%Notification || !$Notification{Subject} || !$Notification{Body};

        # send notify
        $Kernel::OM->Get('Kernel::System::Email')->Send(
            From => $Kernel::OM->Get('Kernel::Config')->Get('NotificationSenderName') . ' <'
                . $Kernel::OM->Get('Kernel::Config')->Get('NotificationSenderEmail') . '>',
            To       => $User{UserEmail},
            Subject  => $Notification{Subject},
            MimeType => $Notification{ContentType} || 'text/plain',
            Charset  => $Notification{Charset},
            Body     => $Notification{Body},
            Loop     => 1,
        );

        # save person name for Cc update
        push( @Cc, $User{UserEmail} );

        # write history
        $Param{HistoryName} = 'Involved Person Phone';
        if ( $Param{Type} eq 'InvolvedNoteNotification' ) {
            $Param{HistoryName} = 'Involved Person Note';
        }
        $Self->HistoryAdd(
            TicketID     => $Param{TicketID},
            HistoryType  => 'SendLinkedPersonNotification',
            Name         => "$Param{HistoryName}: $User{UserEmail}",
            CreateUserID => $Param{UserID},
        );

        # log event
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => "Sent '$Param{Type}' notification to $RecipientType '$RecipientID'.",
        );

        # event
        $Self->EventHandler(
            Event => 'ArticleLinkedPersonNotification',
            Data  => {
                RecipientID => $RecipientID,
                TicketID    => $Param{TicketID},
                ArticleID   => $Param{ArticleID},
            },
            UserID => $Param{UserID},
        );
    }

    # update article Cc
    if (@Cc) {
        $Self->ArticleUpdate(
            ArticleID => $Param{ArticleID},
            TicketID  => $Param{TicketID},
            Key       => 'Cc',
            Value     => join( ',', @Cc ),
            UserID    => $Param{UserID},
        );
    }

    return 1;
}

=item TicketOwnerName()

returns the ticket owner name for ticket info sidebar

    my $OwnerStrg = $TicketObject->TicketOwnerName(
        OwnerID => 123,
        %{ $Self }
    );

=cut

sub TicketOwnerName {
    my ( $Self, %Param ) = @_;

    my %User = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
        UserID => $Param{OwnerID},
    );
    return if !%User;
    return $Self->_GetUserInfoString(
        %{$Self},
        %Param,
        UserType => 'Owner',
        User     => \%User,
    );
}

=item TicketResponsibleName()

returns the ticket Responsible name for ticket info sidebar

    my $ResponsibleStrg = $TicketObject->TicketResponsibleName(
        ResponsibleID => 123,
        %{ $Self }
    );

=cut

sub TicketResponsibleName {
    my ( $Self, %Param ) = @_;

    my %UserContact = $Kernel::OM->Get('Kernel::System::User')->ContactGet(
        UserID => $Param{ResponsibleID},
    );
    return if !%UserContact;

    return $Self->_GetUserInfoString(
        %{$Self},
        %Param,
        UserType => 'Responsible',
        User     => \%UserContact,
    );

}

sub _GetUserInfoString {
    my ( $Self, %Param ) = @_;

    return '' if !$Param{UserType};
    my %UserContact = %{ $Param{User} };

    my %Contacts = $Kernel::OM->Get('Kernel::System::Contact')->ContactSearch(
        Login => $UserContact{UserLogin},
        Limit => 1,
        Valid => 0
    );
    my %ContactData;
    if (IsHashRefWithData(\%Contacts)) {
        for my $ID (keys %Contacts) {
            %ContactData = $Kernel::OM->Get('Kernel::System::Contact')->ContactGet(
                ID => $ID,
            );
        }
    }

    # if no customer data found use agent data
    if ( !%ContactData ) {
        my @EmptyArray = ();
        %ContactData = %UserContact;
        $ContactData{Config}->{Map} = \@EmptyArray;

        my $AgentConfig
            = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Frontend::KIXSidebarTicketInfo');
        for my $Attribute ( keys %{ $AgentConfig->{DisplayAttributes} } ) {
            next if !$AgentConfig->{DisplayAttributes}->{$Attribute};

            $Attribute =~ m/^User(.*)$/;
            my @TempArray = ();
            push @TempArray, $Attribute;
            push @TempArray, $1 || $Attribute;
            push @TempArray, '';
            push @TempArray, 1;
            push @TempArray, 0;
            push @{ $ContactData{Config}->{Map} }, \@TempArray;
        }
    }

    $Self->{LayoutObject} = $Param{LayoutObject};
    my $DetailsTable = $Self->{LayoutObject}->AgentCustomerDetailsViewTable(
        Data   => \%ContactData,
        Ticket => $Param{Ticket},
        Max =>
            $Kernel::OM->Get('Kernel::Config')
            ->Get('Ticket::Frontend::CustomerInfoComposeMaxSize'),
    );

    my $Title
        = $Self->{LayoutObject}->{LanguageObject}
        ->Translate( $Param{UserType} . ' Information' );
    my $Output
        = $UserContact{Firstname} . ' '
        . $UserContact{Lastname}
        . '<span class="' . $Param{UserType} . 'DetailsMagnifier">'
        . ' <i class="fa fa-search"></i>'
        . '</span>'
        . '<div class="WidgetPopup" id="' . $Param{UserType} . 'Details">'
        . '<div class="Header"><h2>' . $Title . '</h2></div>'
        . '<div class="Content"><div class="Spacing">'
        . $DetailsTable
        . '</div>'
        . '</div>'
        . '</div>';

    return $Output;
}


=item Kernel::System::Ticket::TicketAclFormData()

return the current ACL form data hash after TicketAcl()

    my %AclForm = Kernel::System::Ticket::TicketAclFormData();

=cut

sub Kernel::System::Ticket::TicketAclFormData {
    my ( $Self, %Param ) = @_;

    if ( IsHashRefWithData( $Self->{TicketAclFormData} ) ) {
        return %{ $Self->{TicketAclFormData} };
    }
    else {
        return ();
    }
}

=item TicketAccountedTimeDelete()

deletes the accounted time of a ticket.

    my $Success = $TicketObject->TicketAccountedTimeDelete(
        TicketID    => 1234,
        ArticleID   => 1234
    );

=cut

sub TicketAccountedTimeDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "Need $Needed!" );
            return;
        }
    }

    # db query
    if ( $Param{ArticleID} ) {
        return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
            SQL => 'DELETE FROM time_accounting WHERE ticket_id = ? AND article_id = ?',
            Bind => [ \$Param{TicketID}, \$Param{ArticleID} ],
        );
    }
    else {
        return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
            SQL  => 'DELETE FROM time_accounting WHERE ticket_id = ?',
            Bind => [ \$Param{TicketID} ],
        );
    }

    return 1;
}

sub GetLinkedTickets {
    my ( $Self, %Param ) = @_;

    my $SQL = 'SELECT DISTINCT target_key FROM link_relation WHERE source_key = ?';

    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL  => $SQL,
        Bind => [ \$Param{Customer} ],
    );
    my @TicketIDs;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        push @TicketIDs, $Row[0];
    }
    return @TicketIDs;
}

# Levenshtein algorithm taken from
# http://en.wikibooks.org/wiki/Algorithm_implementation/Strings/Levenshtein_distance#Perl
sub _CalcStringDistance {
    my ( $Self, $StringA, $StringB ) = @_;
    my ( $len1, $len2 ) = ( length $StringA, length $StringB );
    return $len2 if ( $len1 == 0 );
    return $len1 if ( $len2 == 0 );
    my %d;
    for ( my $i = 0; $i <= $len1; ++$i ) {
        for ( my $j = 0; $j <= $len2; ++$j ) {
            $d{$i}{$j} = 0;
            $d{0}{$j} = $j;
        }
        $d{$i}{0} = $i;
    }

    # Populate arrays of characters to compare
    my @ar1 = split( //, $StringA );
    my @ar2 = split( //, $StringB );
    for ( my $i = 1; $i <= $len1; ++$i ) {
        for ( my $j = 1; $j <= $len2; ++$j ) {
            my $cost = ( $ar1[ $i - 1 ] eq $ar2[ $j - 1 ] ) ? 0 : 1;
            my $min1 = $d{ $i - 1 }{$j} + 1;
            my $min2 = $d{$i}{ $j - 1 } + 1;
            my $min3 = $d{ $i - 1 }{ $j - 1 } + $cost;
            if ( $min1 <= $min2 && $min1 <= $min3 ) {
                $d{$i}{$j} = $min1;
            }
            elsif ( $min2 <= $min1 && $min2 <= $min3 ) {
                $d{$i}{$j} = $min2;
            }
            else {
                $d{$i}{$j} = $min3;
            }
        }
    }
    return $d{$len1}{$len2};
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
