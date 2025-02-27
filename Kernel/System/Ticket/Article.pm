# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Article;

use strict;
use warnings;

use POSIX qw(ceil);

use Kernel::System::EmailParser;

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::Ticket::Article - sub module of Kernel::System::Ticket

=head1 SYNOPSIS

All article functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item ArticleCreate()

create an article

    my $ArticleID = $TicketObject->ArticleCreate(
        TicketID         => 123,
        Channel          => 'note',                                 # ...
        CustomerVisible  => 0|1,                                    # optional
        SenderType       => 'agent',                                # agent|system|external
        From             => 'Some Agent <email@example.com>',       # not required but useful
        To               => 'Some Customer A <customer-a@example.com>', # not required but useful
        Cc               => 'Some Customer B <customer-b@example.com>', # not required but useful
        Bcc	             => 'Some Customer C <customer-b@example.com>', # not required but useful
        ReplyTo          => 'Some Customer B <customer-b@example.com>', # not required
        Subject          => 'some short description',               # required
        Body             => 'the message text',                     # required
        IncomingTime     => 'YYYY-MM-DD HH24:MI:SS',                # optional
        MessageID        => '<asdasdasd.123@example.com>',          # not required but useful
        InReplyTo        => '<asdasdasd.12@example.com>',           # not required but useful
        References       => '<asdasdasd.1@example.com> <asdasdasd.12@example.com>', # not required but useful
        DoNotSendEmail   => 0|1,                                    # optional, prevent system from sending an email
        PlainEmail       => 'plain email content',                  # optional, only used for channel 'email', when article is NOT send by the system
        ContentType      => 'text/plain; charset=ISO-8859-15',      # or optional Charset & MimeType
        HistoryType      => 'OwnerUpdate',                          # EmailCustomer|Move|AddNote|PriorityUpdate|...
        HistoryComment   => 'Some free text!',
        TimeUnit         => 123,                                    # optional
        UserID           => 123,
        Loop             => 0,                                      # 1|0 used for bulk emails
        Attachment => [
            {
                Content     => $Content,
                ContentType => $ContentType,
                Filename    => 'lala.txt',
            },
            {
                Content     => $Content,
                ContentType => $ContentType,
                Filename    => 'lala1.txt',
            },
        ],
        NoAgentNotify    => 0,                                      # if you don't want to send agent notifications

        ForceNotificationToUserID   => [ 1, 43, 56 ],               # if you want to force somebody
        ExcludeNotificationToUserID => [ 43,56 ],                   # if you want full exclude somebody from notfications,
                                                                    # will also be removed in To: line of article,
                                                                    # higher prio as ForceNotificationToUserID
        ExcludeMuteNotificationToUserID => [ 43,56 ],               # the same as ExcludeNotificationToUserID but only the
                                                                    # sending gets muted, agent will still shown in To:
                                                                    # line of article
    );

example with "Charset & MimeType" and no "ContentType"

    my $ArticleID = $TicketObject->ArticleCreate(
        TicketID         => 123,
        Channel          => 'note',                                 # Channel or
        ChannelID        => 1,                                      # ChannelID
        CustomerVisible  => 0|1,                                    # optional - will be set to 1 on special conditions (only if not given)
        SenderType       => 'agent',                                # agent|system|external
        From             => 'Some Agent <email@example.com>',       # not required but useful
        To               => 'Some Customer A <customer-a@example.com>', # not required but useful
        Cc               => 'Some Customer A <customer-a@example.com>', # optional
        Bcc              => 'Some Customer A <customer-a@example.com>', # optional
        Subject          => 'some short description',               # required
        Body             => 'the message text',                     # required
        IncomingTime     => 'YYYY-MM-DD HH24:MI:SS',                # optional
        Charset          => 'ISO-8859-15',
        MimeType         => 'text/plain',
        HistoryType      => 'OwnerUpdate',                          # EmailCustomer|Move|AddNote|PriorityUpdate|...
        HistoryComment   => 'Some free text!',
        UserID           => 123,
        UnlockOnAway     => 1,                                      # Unlock ticket if owner is away
        TimeUnit         => 123,                                    # optional
    );

Events:
    ArticleCreate

=cut

sub ArticleCreate {
    my ( $Self, %Param ) = @_;

    # get time object
    my $TimeObject = $Kernel::OM->Get('Time');

    my $ValidID = $Param{ValidID} || 1;
    my $IncomingTime = $TimeObject->SystemTime();

    # create ArticleContentPath
    if ( !$Self->{ArticleContentPath} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need ArticleContentPath!'
        );
        return;
    }

    # lookups if no ids are passed
    if ( $Param{Channel} && !$Param{ChannelID} ) {
        $Param{ChannelID} = $Kernel::OM->Get('Channel')->ChannelLookup( Name => $Param{Channel} );
    } elsif ( !$Param{Channel} && $Param{ChannelID} ) {
        $Param{Channel} = $Kernel::OM->Get('Channel')->ChannelLookup( ID => $Param{ChannelID} );
    }
    if ( $Param{SenderType} && !$Param{SenderTypeID} ) {
        $Param{SenderTypeID} = $Self->ArticleSenderTypeLookup( SenderType => $Param{SenderType} );
    } elsif ( !$Param{SenderType} && $Param{SenderTypeID} ) {
        $Param{SenderType} = $Self->ArticleSenderTypeLookup( SenderTypeID => $Param{SenderTypeID} );
    }

    # check needed stuff
    for (qw(TicketID UserID ChannelID SenderTypeID HistoryType HistoryComment)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # correct charset if necessary
    if ($Param{Charset}) {
        $Param{Charset} =~ s/utf8/utf-8/i;
    }

    # check ContentType vs. Charset & MimeType
    if ( !$Param{ContentType} ) {
        for (qw(Charset MimeType)) {
            if ( !$Param{$_} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $_!"
                );
                return;
            }
        }
        $Param{ContentType} = "$Param{MimeType}; charset=$Param{Charset}";
    }
    else {
        if ( $Param{ContentType} =~ /charset=/i ) {

            # correct charset if necessary
            $Param{ContentType} =~ s/utf8/utf-8/i;

            my $Charset = $Param{ContentType};
            $Charset =~ s/.+?charset=("|'|)(\w+)/$2/gi;
            $Charset =~ s/"|'//g;
            $Charset =~ s/(.+?);.*/$1/g;

            # only change if we extracted a charset
            $Param{Charset} = $Charset || $Param{Charset};
        }

        if ( $Param{ContentType} =~ /^(\w+\/\w+)/i ) {
            my $MimeType = $1;
            $MimeType =~ s/"|'//g;

            # only change if we extracted a mime type
            $Param{MimeType} = $MimeType || $Param{MimeType};
        }
    }

    # fallback for Charset
    $Param{Charset} //= 'utf-8';

    # for the event handler, before any actions have taken place
    my %OldTicketData = $Self->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 1,
    );

    # get html utils object
    my $HTMLUtilsObject = $Kernel::OM->Get('HTMLUtils');

    # add 'no body' if there is no body there!
    my @AttachmentConvert;
    if ( !length $Param{Body} ) {    # allow '0' as body
        $Param{Body} = 'No body';
    } else {

        if (IsHashRefWithData($Param{OrigHeader}) && $Param{OrigHeader}->{Body}) {
            $Param{OrigHeader}->{Body} = $Param{Body};
        }

        # process html article
        if ( $Param{MimeType} =~ /text\/html/i ) {

            # add html article as attachment
            my $Attach = {
                Content     => $Param{Body},
                ContentType => "text/html; charset=\"$Param{Charset}\"",
                Filename    => 'file-2',
            };
            push @AttachmentConvert, $Attach;

            # save HTML body for later use
            $Param{HTMLBody} = $Param{Body};

            # get ascii body
            $Param{MimeType} = 'text/plain';
            $Param{ContentType} =~ s/html/plain/i;
            $Param{Body} = $HTMLUtilsObject->ToAscii(
                String            => $Param{Body},
                NoForcedLinebreak => 1
            );
        }
        elsif ( $Param{MimeType} && $Param{MimeType} eq "application/json" ) {

            # Keep JSON body unchanged
        }

        # if body isn't text, attach body as attachment (mostly done by OE) :-/
        elsif ( $Param{MimeType} && $Param{MimeType} !~ /\btext\b/i ) {

            # add non text as attachment
            my $FileName = 'unknown';
            if ( $Param{ContentType} =~ /name="(.+?)"/i ) {
                $FileName = $1;
            }
            my $Attach = {
                Content     => $Param{Body},
                ContentType => $Param{ContentType},
                Filename    => $FileName,
            };
            push @{ $Param{Attachment} }, $Attach;

            # set ascii body
            $Param{MimeType}    = 'text/plain';
            $Param{ContentType} = 'text/plain';
            $Param{Body}        = '- no text message => see attachment -';
        }

        # fix some bad stuff from some browsers (Opera)!
        else {
            $Param{Body} =~ s/(\n\r|\r\r\n|\r\n)/\n/g;
        }
    }

    # strip not wanted stuff
    for my $Attribute (qw(From To Cc Bcc Subject MessageID InReplyTo References ReplyTo)) {
        if ( defined $Param{$Attribute} ) {
            $Param{$Attribute} =~ s/\n|\r//g;
        }
        else {
            $Param{$Attribute} = '';
        }
    }
    ATTRIBUTE:
    for my $Attribute (qw(InReplyTo References)) {
        next ATTRIBUTE if !$Param{$Attribute};
        $Param{$Attribute} = substr( $Param{$Attribute}, 0, 3800 );
    }

    # second check after conversion to plain text (i.e. empty <body> tag in HTML mail)
    if ( !length $Param{Body} ) {
        $Param{Body} = 'No body';
    }

    # get From by agent preference
    if (!$Param{From} && $Param{SenderType} eq 'agent') {
        $Param{From} = $Self->_GetFromByUser(
            %Param,
            Ticket => \%OldTicketData
        )
    }

    # handle some special things for channel "email"
    if ( $Param{Channel} eq 'email' ) {

        # get From by ticket queue
        if (!$Param{From} && $Param{SenderType} eq 'system') {
            $Param{From} = $Self->_GetFromByQueue(
                %Param,
                Ticket => \%OldTicketData
            )
        }

        # check needed stuff
        for my $Needed (qw(TicketID UserID From Body Charset MimeType)) {
            if ( !$Param{$Needed} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!"
                );
                return;
            }
        }

        $Param{ToOrig} = $Param{To}   || '';
        $Param{Loop}   = $Param{Loop} || 0;

        # map ReplyTo into Reply-To if present
        if ( $Param{ReplyTo} ) {
            $Param{'Reply-To'} = $Param{ReplyTo};
        }

        # clean up
        $Param{Body} =~ s/(\r\n|\n\r)/\n/g;
        $Param{Body} =~ s/\r/\n/g;

        # create MessageID
        if ( !$Param{MessageID} ) {
            $Param{MessageID} = $Kernel::OM->Get('Email')->GenerateMessageID();
        }
    }

    if (
        !defined( $Param{CustomerVisible} )
        || $Param{CustomerVisible} eq ''
    ) {
        $Param{CustomerVisible} = 0;
    }

    # prepare IncomingTime if given
    if ( $Param{IncomingTime} ) {
        my $IncomingSystemTime = $TimeObject->TimeStamp2SystemTime(
            String => $Param{IncomingTime},
        );
        $IncomingTime = $IncomingSystemTime if $IncomingSystemTime;
    }

    # check if this is the first article (for notifications)
    my @Index = $Self->ArticleIndex( TicketID => $Param{TicketID} );
    my $IsFirstArticle = scalar @Index ? 0 : 1;

    # calculate MD5 of Message ID
    if ( $Param{MessageID} ) {
        $Param{MD5} = $Kernel::OM->Get('Main')->MD5sum( String => $Param{MessageID} );
    }

    # get database object
    my $RandomString = $Kernel::OM->Get('Main')->GenerateRandomString(
        Length => 32,
    );
    my $ArticleInsertFingerprint = $$ . '-' . $RandomString . '-' . ( $Param{MessageID} // '' );

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # if the original article body contains just one pasted picture and no text, at this point of
    # the code the body is an empty string, Oracle databases will transform the empty string value
    # to NULL and will try to insert a NULL value in a field that should not be NULL. see bug 7533.
    if (
        $DBObject->GetDatabaseFunction('Type') eq 'oracle'
        && defined $Param{Body}
        && !$Param{Body}
        )
    {
        $Param{Body} = ' ';
    }

    # init attachment count
    my $AttachmentCount = 0;

    # do db insert
    return if !$DBObject->Do(
        SQL => 'INSERT INTO article '
            . '(ticket_id, channel_id, customer_visible, article_sender_type_id, a_from, a_reply_to, a_to, '
            . 'a_cc, a_bcc, a_subject, a_message_id, a_message_id_md5, a_in_reply_to, a_references, a_body, a_content_type, '
            . 'content_path, attachment_count, valid_id, incoming_time, create_time, create_by, change_time, change_by) '
            . 'VALUES '
            . '(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{TicketID}, \$Param{ChannelID}, \$Param{CustomerVisible}, \$Param{SenderTypeID},
            \$Param{From},     \$Param{ReplyTo},       \$Param{To},
            \$Param{Cc},       \$Param{Bcc},           \$Param{Subject},
            \$ArticleInsertFingerprint,    # just for next search; will be updated with correct MessageID
            \$Param{MD5},
            \$Param{InReplyTo}, \$Param{References}, \$Param{Body},
            \$Param{ContentType}, \$Self->{ArticleContentPath}, \$AttachmentCount, \$ValidID,
            \$IncomingTime, \$Param{UserID}, \$Param{UserID},
        ],
    );

    # get article id
    my $ArticleID = $Self->_ArticleGetId(
        TicketID     => $Param{TicketID},
        MessageID    => $ArticleInsertFingerprint,
        From         => $Param{From},
        Subject      => $Param{Subject},
        IncomingTime => $IncomingTime
    );

    # return if there is not article created
    if ( !$ArticleID ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Can't get ArticleID from insert (TicketID=$Param{TicketID}, MessageID=$Param{MessageID})!",
        );
        return;
    }

    # Save correct Message-ID now.
    return if !$DBObject->Do(
        SQL  => 'UPDATE article SET a_message_id = ? WHERE id = ?',
        Bind => [ \$Param{MessageID}, \$ArticleID ],
    );

    # update change time of ticket
    return if !$DBObject->Do(
        SQL => 'UPDATE ticket SET change_time = current_timestamp, '
            . ' change_by = ? WHERE id = ?',
        Bind => [ \$Param{UserID}, \$Param{TicketID} ],
    );

    # check for base64 encoded images in html body and upload them
    for my $Attachment (@AttachmentConvert) {

        if (
            $Attachment->{ContentType} eq "text/html; charset=\"$Param{Charset}\""
            && $Attachment->{Filename} eq 'file-2'
            )
        {
            $HTMLUtilsObject->EmbeddedImagesExtract(
                DocumentRef    => \$Attachment->{Content},
                AttachmentsRef => \@AttachmentConvert,
            );
        }
    }

    # add converted attachments
    for my $Attachment (@AttachmentConvert) {
        $Self->ArticleWriteAttachment(
            %{$Attachment},
            ArticleID => $ArticleID,
            UserID    => $Param{UserID},
        );
    }

    # add attachments
    if ( $Param{Attachment} ) {
        for my $Attachment ( @{ $Param{Attachment} } ) {
            $Self->ArticleWriteAttachment(
                %{$Attachment},
                ContentType => $Attachment->{ContentType} || $Kernel::OM->Get('Config')->Get('Ticket::Article::Attachment::ContentType::Fallback'),
                ArticleID   => $ArticleID,
                UserID      => $Param{UserID},
            );
        }
    }

    # add accounted time if needed
    if ( $Param{TimeUnit} ) {
        my $UpdateSuccess = $Self->TicketAccountTime(
            TicketID  => $Param{TicketID},
            ArticleID => $ArticleID,
            TimeUnit  => $Param{TimeUnit},
            UserID    => $Param{UserID},
        );
    }

    # clear ticket cache
    $Self->_TicketCacheClear(
        TicketID => $Param{TicketID},
    );

    # add history row
    $Self->HistoryAdd(
        ArticleID    => $ArticleID,
        TicketID     => $Param{TicketID},
        CreateUserID => $Param{UserID},
        HistoryType  => $Param{HistoryType},
        Name         => $Param{HistoryComment},
    );

    # event
    $Self->EventHandler(
        Event => 'ArticleCreate',
        Data  => {
            ArticleID     => $ArticleID,
            TicketID      => $Param{TicketID},
            OldTicketData => \%OldTicketData,
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'Ticket.Article',
        UserID    => $Param{UserID},
        ObjectID  => $Param{TicketID}.'::'.$ArticleID,
    );

    # reset unlock if needed
    if ( !$Param{SenderType} ) {
        $Param{SenderType} = $Self->ArticleSenderTypeLookup( SenderTypeID => $Param{SenderTypeID} );
    }
    if ( !$Param{Channel} ) {
        $Param{Channel} = $Kernel::OM->Get('Channel')->ChannelLookup( ID => $Param{ChannelID} );
    }

    # reset unlock time if customer sent an update
    if ( $Param{SenderType} eq 'external' ) {

        # check if latest article comes from customer
        my $LastSender = '';
        return if !$DBObject->Prepare(
            SQL => 'SELECT ast.name FROM article art, article_sender_type ast WHERE '
                . ' art.ticket_id = ? AND art.id NOT IN (?) AND '
                . ' art.article_sender_type_id = ast.id ORDER BY art.create_time ASC',
            Bind => [ \$Param{TicketID}, \$ArticleID ],
        );
        while ( my @Row = $DBObject->FetchrowArray() ) {
            if ( $Row[0] ne 'system' ) {
                $LastSender = $Row[0];
            }
        }
        if ( $LastSender eq 'agent' ) {
            $Self->TicketUnlockTimeoutUpdate(
                UnlockTimeout => $TimeObject->SystemTime(),
                TicketID      => $Param{TicketID},
                UserID        => $Param{UserID},
            );
        }
    }

    # check if latest article is sent to customer
    elsif ( $Param{SenderType} eq 'agent' && $Param{CustomerVisible} ) {
        $Self->TicketUnlockTimeoutUpdate(
            UnlockTimeout => $TimeObject->SystemTime(),
            TicketID      => $Param{TicketID},
            UserID        => $Param{UserID},
        );
    }

    if ( !$Param{NoAgentNotify} ) {

        my %Ticket = $Self->TicketGet(
            TicketID      => $Param{TicketID},
            DynamicFields => 0,
        );

        # remember agent to exclude notifications
        my @SkipRecipients;
        if ( $Param{ExcludeNotificationToUserID} && ref $Param{ExcludeNotificationToUserID} eq 'ARRAY' )
        {
            for my $UserID ( @{ $Param{ExcludeNotificationToUserID} } ) {
                push @SkipRecipients, $UserID;
            }
        }

        # remember agent to exclude notifications / already sent
        my %DoNotSendMute;
        if (
            $Param{ExcludeMuteNotificationToUserID}
            && ref $Param{ExcludeMuteNotificationToUserID} eq 'ARRAY'
            )
        {
            for my $UserID ( @{ $Param{ExcludeMuteNotificationToUserID} } ) {
                push @SkipRecipients, $UserID;
            }
        }

        my $ExtraRecipients;
        if ( $Param{ForceNotificationToUserID} && ref $Param{ForceNotificationToUserID} eq 'ARRAY' ) {
            $ExtraRecipients = $Param{ForceNotificationToUserID};
        }

        # send agent notification on ticket create
        if ( $IsFirstArticle && ( $Param{HistoryType} =~ /^(EmailCustomer|SystemRequest)$/i || $Param{SenderType} ne 'system') ) {
            # trigger notification event
            $Self->EventHandler(
                Event => 'NotificationNewTicket',
                Data  => {
                    TicketID              => $Param{TicketID},
                    ArticleID             => $ArticleID,
                    Channel               => $Param{Channel},
                    CustomerVisible       => $Param{CustomerVisible},
                    Queue                 => $Param{Queue},
                    Recipients            => $ExtraRecipients,
                    SkipRecipients        => \@SkipRecipients,
                    CustomerMessageParams => {%Param},
                },
                UserID => $Param{UserID},
            );
        }

        # send agent notification on adding a note
        elsif (
            $Param{HistoryType} =~ /^AddArticle$/i
            || $Param{HistoryType} =~ /^AddNote$/i
        ) {

            # trigger notification event
            $Self->EventHandler(
                Event => 'NotificationAddNote',
                Data  => {
                    TicketID              => $Param{TicketID},
                    ArticleID             => $ArticleID,
                    Channel               => $Param{Channel},
                    CustomerVisible       => $Param{CustomerVisible},
                    Queue                 => $Param{Queue},
                    Recipients            => $ExtraRecipients,
                    SkipRecipients        => \@SkipRecipients,
                    CustomerMessageParams => {},
                },
                UserID => $Param{UserID},
            );
        }

        # send agent notification on follow up
        elsif ( $Param{HistoryType} =~ /^FollowUp$/i ) {

            # trigger notification event
            $Self->EventHandler(
                Event => 'NotificationFollowUp',
                Data  => {
                    TicketID              => $Param{TicketID},
                    ArticleID             => $ArticleID,
                    Channel               => $Param{Channel},
                    CustomerVisible       => $Param{CustomerVisible},
                    Queue                 => $Param{Queue},
                    Recipients            => $ExtraRecipients,
                    SkipRecipients        => \@SkipRecipients,
                    CustomerMessageParams => {%Param},
                },
                UserID => $Param{UserID},
            );
        }
    }

    # send article through email channel if it was created by an agent or the system
    if (
        !$Param{DoNotSendEmail}
        && $Param{Channel} eq 'email'
        && (
            $Param{SenderType} eq 'agent'
            || $Param{SenderType} eq 'system'
        )
    ) {

        # prepare body and charset
        my $Body = $Kernel::OM->Get('Output::HTML::Layout')->RichTextDocumentComplete(
            String => $Param{HTMLBody} || $Param{Body},
        );

        my $Charset = $Param{Charset};

        # send mail
        # If EncryptIfPossible is active, it should be 2 because 1 means it needs to be encrypted
        my $Send = $Kernel::OM->Get('Email')->Send(
            'Message-ID' => $Param{MessageID},
            %Param,
            MimeType => 'text/html',
            Charset  => $Charset,
            Body     => $Body,
            Encrypt  => $Param{EncryptIfPossible} ? 2 : 0
        );

        # return if no mail was able to send
        if (
            !$Send->{HeadRef}
            || !$Send->{BodyRef}
        ) {
            my $Error = $Kernel::OM->Get('Log')->GetLogEntry(
                Type => 'error',
                What => 'Message',
            );
            $Kernel::OM->Get('Log')->Log(
                Message  => "Impossible to send message to: $Param{'To'} (Error: $Error).",
                Priority => 'error',
            );
            # sets flag NotSentError, because article could not be sent
            $Self->ArticleFlagSet(
                ArticleID => $ArticleID,
                Key       => 'NotSentError',
                Value     => $Error,
                UserID    => $Param{UserID},
            );

            # Sets specific article flags
            for my $Flag ( @{$Send->{Flags}} ) {
                $Self->ArticleFlagSet(
                    ArticleID => $ArticleID,
                    Key       => $Flag->{Key},
                    Value     => $Flag->{Value},
                    UserID    => $Param{UserID} || 1,
                    Silent    => $Param{Silent}
                );
            }

            # return the ArticleID since we have created the article already but just not sent
            return $ArticleID;
        }

        # Sets specific article flags
        for my $Flag ( @{$Send->{Flags}} ) {
            $Self->ArticleFlagSet(
                ArticleID => $ArticleID,
                Key       => $Flag->{Key},
                Value     => $Flag->{Value},
                UserID    => $Param{UserID} || 1,
                Silent    => $Param{Silent}
            );
        }

        # write plain article to fs
        my $Plain = $Self->ArticleWritePlain(
            ArticleID => $ArticleID,
            Email     => ${$Send->{HeadRef}} . "\n" . ${$Send->{BodyRef}},
            UserID    => $Param{UserID}
        );
        if ( !$Plain ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to write plain article for ArticleID $ArticleID.",
            );
            return;
        }

        # log
        $Kernel::OM->Get('Log')->Log(
            Priority => 'info',
            Message  => "Sent email to '$Param{ToOrig}' from '$Param{From}'. HistoryType => $Param{HistoryType}, Subject => $Param{Subject};",
        );

        # event
        $Self->EventHandler(
            Event => 'ArticleSend',
            Data  => {
                TicketID  => $Param{TicketID},
                ArticleID => $ArticleID,
            },
            UserID => $Param{UserID},
        );
    }
    # handel plain email if provided
    elsif (
        $Param{PlainEmail}
        && $Param{Channel} eq 'email'
    ) {

        # write plain article to fs
        my $Plain = $Self->ArticleWritePlain(
            ArticleID => $ArticleID,
            Email     => $Param{PlainEmail},
            UserID    => $Param{UserID}
        );
        if ( !$Plain ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to write plain article for ArticleID $ArticleID.",
            );
            return;
        }
    }

    # return ArticleID
    return $ArticleID;
}

=item ArticleGetTicketIDOfMessageID()

get ticket id of given message id

    my $TicketID = $TicketObject->ArticleGetTicketIDOfMessageID(
        MessageID => '<13231231.1231231.32131231@example.com>',
    );

=cut

sub ArticleGetTicketIDOfMessageID {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{MessageID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need MessageID!'
        );
        return;
    }

    my @TicketIDs = $Self->ArticleGetTicketIDsOfMessageID(
        MessageID => $Param{MessageID},
    );
    my $Count = scalar(@TicketIDs) || 0;

    # no reference found
    return if $Count == 0;

    # one found
    return $TicketIDs[0] if $Count == 1;

    # more than one found! that should not be, a message_id should be unique!
    $Kernel::OM->Get('Log')->Log(
        Priority => 'notice',
        Message  => "The MessageID '$Param{MessageID}' is in your database "
            . "more than one time! That should not be, a message_id should be unique!",
    );
    return;
}

=item ArticleGetTicketIDsOfMessageID()

get ticket ids of given message id

    my @TicketIDs = $TicketObject->ArticleGetTicketIDsOfMessageID(
        MessageID => '<13231231.1231231.32131231@example.com>',
    );

=cut

sub ArticleGetTicketIDsOfMessageID {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{MessageID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need MessageID!'
        );
        return;
    }
    my $MD5 = $Kernel::OM->Get('Main')->MD5sum( String => $Param{MessageID} );

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # sql query
    return if !$DBObject->Prepare(
        SQL   => 'SELECT ticket_id FROM article WHERE a_message_id_md5 = ?',
        Bind  => [ \$MD5 ],
    );

    my @TicketIDs = ();
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push (@TicketIDs, $Row[0]);
    }

    return @TicketIDs;
}

=item ArticleGetContentPath()

get article content path

    my $Path = $TicketObject->ArticleGetContentPath(
        ArticleID => 123,
    );

=cut

sub ArticleGetContentPath {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ArticleID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need ArticleID!'
        );
        return;
    }

    if ( !$Param{TicketID} ) {
        # get ticket id of article
        my $TicketID = $Self->ArticleGetTicketID(
            ArticleID => $Param{ArticleID}
        );
        if (!$TicketID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No article found with id $Param{ArticleID}!"
            );
            return;
        }

        $Param{TicketID} = $TicketID;
    }

    # prepare cache key
    my $CacheKey = 'ArticleGetContentPath::' . $Param{ArticleID};

    # check cache
    my $Cache = $Self->_TicketCacheGet(
        TicketID => $Param{TicketID},
        Key      => $CacheKey,
    );
    return $Cache if $Cache;

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # sql query
    return if !$DBObject->Prepare(
        SQL  => 'SELECT content_path FROM article WHERE id = ?',
        Bind => [ \$Param{ArticleID} ],
    );

    my $Result;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Result = $Row[0];
    }

    # set cache
    $Self->_TicketCacheSet(
        TicketID => $Param{TicketID},
        Key      => $CacheKey,
        Value    => $Result,
    );

    # return
    return $Result;
}

=item ArticleGetTicketID()

get ticket id of article

    my $TicketID = $TicketObject->ArticleGetTicketID(
        ArticleID => 123,
    );

=cut

sub ArticleGetTicketID {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ArticleID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need ArticleID!'
        );
        return;
    }

    # prepare cache key
    my $CacheKey = 'ArticleGetTicketID::' . $Param{ArticleID};

    # check cache
    my $Cache = $Self->_TicketCacheGet(
        Key => $CacheKey,
    );
    return $Cache if $Cache;

    # sql query
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'SELECT ticket_id FROM article WHERE id = ?',
        Bind => [ \$Param{ArticleID} ],
    );

    my $TicketID;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        $TicketID = $Row[0];
    }

    # set cache
    $Self->_TicketCacheSet(
        Key   => $CacheKey,
        Value => $TicketID,
    );

    # return
    return $TicketID;
}

=item ArticleSenderTypeList()

get a article sender type list

    my @ArticleSenderTypeList = $TicketObject->ArticleSenderTypeList(
        Result => 'ARRAY', # optional, ARRAY|HASH
    );

=cut

sub ArticleSenderTypeList {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $DBObject    = $Kernel::OM->Get('DB');
    my $ValidObject = $Kernel::OM->Get('Valid');

    return if !$DBObject->Prepare(
        SQL => "SELECT id, name FROM article_sender_type WHERE "
            . "valid_id IN (${\(join ', ', $ValidObject->ValidIDsGet())})",
    );

    my @Array;
    my %Hash;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @Array, $Row[1];
        $Hash{ $Row[0] } = $Row[1];
    }

    if ( $Param{Result} && $Param{Result} eq 'HASH' ) {
        return %Hash;
    }

    return @Array;

}

=item ArticleSenderTypeLookup()

article sender lookup

    my $SenderTypeID = $TicketObject->ArticleSenderTypeLookup(
        SenderType => 'external', # external|system|agent
    );

    my $SenderType = $TicketObject->ArticleSenderTypeLookup(
        SenderTypeID => 1,
    );

=cut

sub ArticleSenderTypeLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{SenderType} && !$Param{SenderTypeID} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Need SenderType or SenderTypeID!',
            );
        }
        return;
    }

    # get key
    my $Key;
    my $CacheKey;
    if ( $Param{SenderType} ) {
        $Key      = $Param{SenderType};
        $CacheKey = 'ArticleSenderTypeLookup::' . $Param{SenderType};
    }
    else {
        $Key      = $Param{SenderTypeID};
        $CacheKey = 'ArticleSenderTypeLookup::' . $Param{SenderTypeID};
    }

    # check cache
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return $Cache if $Cache;

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # get data
    if ( $Param{SenderType} ) {
        return if !$DBObject->Prepare(
            SQL  => 'SELECT id FROM article_sender_type WHERE name = ?',
            Bind => [ \$Param{SenderType} ],
        );
    }
    else {
        return if !$DBObject->Prepare(
            SQL  => 'SELECT name FROM article_sender_type WHERE id = ?',
            Bind => [ \$Param{SenderTypeID} ],
        );
    }

    # store result
    my $Result;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Result = $Row[0];
    }

    # check if data exists
    if ( !$Result ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Found no SenderType(ID) for $Key!",
            );
        }
        return;
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => $Result,
    );

    return $Result;
}

=item ArticleLastCustomerArticle()

get last customer article

    my %Article = $TicketObject->ArticleLastCustomerArticle(
        TicketID      => 123,
        Extended      => 1,      # 0 or 1, see ArticleGet(),
        DynamicFields => 1,      # 0 or 1, see ArticleGet(),
    );

=cut

sub ArticleLastCustomerArticle {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need TicketID!"
        );
        return;
    }

    # get article index
    my @Index = $Self->ArticleIndex(
        TicketID   => $Param{TicketID},
        SenderType => 'external',
        CustomerVisible => 1,
    );

    # get article data
    if (@Index) {
        return $Self->ArticleGet(
            ArticleID     => $Index[-1],
            Extended      => $Param{Extended},
            DynamicFields => $Param{DynamicFields},
        );
    }

    # get whole article index
    @Index = $Self->ArticleIndex( TicketID => $Param{TicketID} );
    return if !@Index;

    # second try, return latest non internal article
    for my $ArticleID ( reverse @Index ) {
        my %Article = $Self->ArticleGet(
            ArticleID     => $ArticleID,
            Extended      => $Param{Extended},
            DynamicFields => $Param{DynamicFields},
        );
        if ( ( $Article{StateType} && $Article{StateType} eq 'merged' ) || $Article{CustomerVisible} ) {
            return %Article;
        }
    }

    # third try, if we got no internal article, return the latest one
    return $Self->ArticleGet(
        ArticleID     => $Index[-1],
        Extended      => $Param{Extended},
        DynamicFields => $Param{DynamicFields},
    );
}

=item ArticleFirstArticle()

get first article

    my %Article = $TicketObject->ArticleFirstArticle(
        TicketID      => 123,
        Extended      => 1,     # 0 or 1, see ArticleGet()
        DynamicFields => 1,     # 0 or 1, see ArticleGet()
    );

=cut

sub ArticleFirstArticle {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need TicketID!"
        );
        return;
    }

    # get article index
    my @Index = $Self->ArticleIndex( TicketID => $Param{TicketID} );

    # get article data
    return if !@Index;

    return $Self->ArticleGet(
        ArticleID     => $Index[0],
        Extended      => $Param{Extended},
        DynamicFields => $Param{DynamicFields},
    );
}

=item ArticleLastArticle()

get last article

    my %Article = $TicketObject->ArticleLastArticle(
        TicketID      => 123,
        Extended      => 1,     # 0 or 1, see ArticleGet()
        DynamicFields => 1,     # 0 or 1, see ArticleGet()
    );

=cut

sub ArticleLastArticle {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need TicketID!"
        );
        return;
    }

    # get article index
    my @Index = $Self->ArticleIndex( TicketID => $Param{TicketID} );

    # get article data
    return if !@Index;

    return $Self->ArticleGet(
        ArticleID     => $Index[-1],
        Extended      => $Param{Extended},
        DynamicFields => $Param{DynamicFields},
    );
}

=item ArticleIndex()

returns an array with article IDs

    my @ArticleIDs = $TicketObject->ArticleIndex(
        TicketID        => 123,
        SenderType      => 'external',                  # optional, to limit to a certain sender type
        CustomerVisible => 1|0                          # optional, to limit to only customer visible
    );

=cut

sub ArticleIndex {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need TicketID!'
        );
        return;
    }

    # Only cache known sender types, because the cache keys of
    #   unknown ones cannot be invalidated in _TicketCacheClear().
    my %CacheableSenderTypes = (
        'agent'    => 1,
        'external' => 1,
        'system'   => 1,
        'ALL'      => 1,
    );

    my $UseCache = $CacheableSenderTypes{ $Param{SenderType} || 'ALL' };

    # prepare cache key
    my $CacheKey = 'ArticleIndex::' . ( $Param{SenderType} || 'ALL' ) . ($Param{CustomerVisible} ? '::CustomerVisible' : '');

    # check cache
    if ($UseCache) {
        my $Cached = $Self->_TicketCacheGet(
            TicketID => $Param{TicketID},
            Key      => $CacheKey,
        );

        if ( ref $Cached eq 'ARRAY' ) {
            return @{$Cached};
        }

    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # db query
    if ( $Param{SenderType} ) {
        return if !$DBObject->Prepare(
            SQL => '
                    SELECT art.id FROM article art, article_sender_type ast
                    WHERE art.ticket_id = ?
                        AND art.article_sender_type_id = ast.id
                        AND ast.name = ?'
                    . ($Param{CustomerVisible} ? ' AND art.customer_visible = 1' : '') .
                    ' ORDER BY art.incoming_time, art.id',
            Bind => [ \$Param{TicketID}, \$Param{SenderType} ],
        );
    } else {
        return if !$DBObject->Prepare(
            SQL => '
                SELECT id
                FROM article
                WHERE ticket_id = ?'
                . ($Param{CustomerVisible} ? ' AND customer_visible = 1' : '') .
                ' ORDER BY incoming_time, id',
            Bind => [ \$Param{TicketID} ],
        );
    }

    my @Index;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @Index, $Row[0];
    }

    # set cache
    if ($UseCache) {
        $Self->_TicketCacheSet(
            TicketID => $Param{TicketID},
            Key      => $CacheKey,
            Value    => \@Index,
        );
    }

    return @Index;
}

=item ArticleContentIndex()

returns an array with hash ref (hash contains result of ArticleGet())

    my @ArticleBox = $TicketObject->ArticleContentIndex(
        TicketID      => 123,
        DynamicFields => 1,         # 0 or 1, default 1. To include or not the dynamic field values on the return structure.
        UserID        => 1,
        Order         => 'ASC',     # 'ASC' or 'DESC', default 'ASC'
    );

or with "StripPlainBodyAsAttachment => 1" feature to not include first
attachment / body and html body as attachment

    my @ArticleBox = $TicketObject->ArticleContentIndex(
        TicketID                   => 123,
        UserID                     => 1,
        StripPlainBodyAsAttachment => 1,
    );

or with "StripPlainBodyAsAttachment => 2" feature to not include first
attachment / body as attachment (html body will be shown as attachment)

    my @ArticleBox = $TicketObject->ArticleContentIndex(
        TicketID                   => 123,
        UserID                     => 1,
        StripPlainBodyAsAttachment => 2,
    );

returns an array with hash ref (hash contains result of ArticleGet())
only with given channels

    my @ArticleBox = $TicketObject->ArticleContentIndex(
        TicketID    => 123,
        UserID      => 1,
        Channel     => [ $Channel1, $Channel2 ],
        # or
        ChannelID   => [ $ChannelID1, $ChannelID2 ],
    );

returns an array with hash ref (hash contains result of ArticleGet())
only visible for the customer

    my @ArticleBox = $TicketObject->ArticleContentIndex(
        TicketID        => 123,
        UserID          => 1,
        CustomerVisible => 1
    );

Likewise C<ArticleSenderTypeID> allows filtering of only articles with
the given sender type IDs.

example of how to access the hash ref

    for my $Article (@ArticleBox) {
        print "From: $Article->{From}\n";
    }

Note: If an attachment with html body content is available, the attachment id
is returned as 'AttachmentIDOfHTMLBody' in hash ref.

You can limit the list of returned elements with the C<Page> and C<Limit>
parameters:

    my @ArticleBox = $TicketObject->ArticleContentIndex(
        TicketID    => 123,
        UserID      => 1,
        Limit       => 5,
        Page        => 3,   # get 11th to 16th element
    );

=cut

sub ArticleContentIndex {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(TicketID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my @ArticleBox = $Self->ArticleGet(
        TicketID            => $Param{TicketID},
        Channel             => $Param{Channel},
        UserID              => $Param{UserID},
        DynamicFields       => $Param{DynamicFields},
        Page                => $Param{Page},
        Limit               => $Param{Limit},
        ChannelID           => $Param{ChannelID},
        CustomerVisible     => $Param{CustomerVisible},
        ArticleSenderTypeID => $Param{ArticleSenderTypeID},
        Order               => $Param{Order},
    );

    # article attachments of each article
    for my $Article (@ArticleBox) {

        # get attachment index (without attachments)
        my %AtmIndex = $Self->ArticleAttachmentIndex(
            ContentPath                => $Article->{ContentPath},
            ArticleID                  => $Article->{ArticleID},
            StripPlainBodyAsAttachment => $Param{StripPlainBodyAsAttachment},
            Article                    => $Article,
            UserID                     => $Param{UserID},
        );
        $Article->{Atms} = \%AtmIndex;
    }
    return @ArticleBox;
}

=item ArticleGet()

returns article data

    my %Article = $TicketObject->ArticleGet(
        ArticleID     => 123,
        DynamicFields => 1,      # Optional. To include the dynamic field values for this article on the return structure.
        UserID        => 123,
    );

Article:
    ArticleID
    From
    To
    Cc
    Bcc
    Subject
    Body
    ReplyTo
    MessageID
    InReplyTo
    References
    SenderType
    SenderTypeID
    Channel
    ChannelID
    ContentType
    Charset
    MimeType
    IncomingTime
    TimeUnit

    # If DynamicFields => 1 was passed, you'll get an entry like this for each dynamic field:
    DynamicField_X     => 'value_x',

Ticket:
    - see TicketGet() for ticket attributes -

returns articles in array / hash by given ticket id

    my @ArticleIndex = $TicketObject->ArticleGet(
        TicketID => 123,
        UserID   => 123,
    );

returns articles in array / hash by given ticket id but
only requested channel(s)

    my @ArticleIndex = $TicketObject->ArticleGet(
        TicketID      => 123,
        Channel       => [ $Channel1, $Channel2 ],
        # or
        ChannelID     => [ $ChannelID1, $ChannelID2 ],
        UserID        => 123,
    );

returns articles in array / hash by given ticket id but
only articles visible for the customer

    my @ArticleIndex = $TicketObject->ArticleGet(
        TicketID        => 123,
        CustomerVisible => 1,
        UserID          => 123,
    );

returns articles in array / hash by given ticket id but
only requested article sender types (could be useful when
trying to exclude autoreplies sent by system sender from
certain views)

    my @ArticleIndex = $TicketObject->ArticleGet(
        TicketID            => 123,
        ArticleSenderType   => [ $ArticleSenderType1, $ArticleSenderType2 ],
        # or
        ArticleSenderTypeID => [ $ArticleSenderTypeID1, $ArticleSenderTypeID2 ],
        UserID              => 123,
    );

returns articles in array / hash by given ticket id but
only requested message-ids

    my @ArticleIndex = $TicketObject->ArticleGet(
        TicketID  => 123,
        MessageID => \@MessageIDs,
        UserID    => 123,
    );

to get extended ticket attributes, use param Extended - see TicketGet() for extended attributes -

    my @ArticleIndex = $TicketObject->ArticleGet(
        TicketID => 123,
        UserID   => 123,
        Extended => 1,
    );

to get only a dedicated count you can use Limit and Order attributes

    my @ArticleIndex = $TicketObject->ArticleGet(
        TicketID => 123,
        UserID   => 123,
        Order    => 'DESC', # DESC,ASC - default is ASC
        Limit    => 5,
    );

You can also provide an offset by passing the C<Page> argument. To get the
6th to 10th article, you can say

    my @ArticleIndex = $TicketObject->ArticleGet(
        TicketID => 123,
        UserID   => 123,
        Limit    => 5,
        Page     => 2,
    );

Page numbers start with 1.

=cut

sub ArticleGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ArticleID} && !$Param{TicketID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need ArticleID or TicketID!'
        );
        return;
    }

    my $FetchDynamicFields = $Param{DynamicFields} ? 1 : 0;

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # channel lookup
    my $ChannelSQL = '';
    if ( $Param{Channel} && ref $Param{Channel} eq 'ARRAY' ) {
        for ( @{ $Param{Channel} } ) {
            if ( $Kernel::OM->Get('Channel')->ChannelLookup( Name => $_ ) ) {
                if ($ChannelSQL) {
                    $ChannelSQL .= ',';
                }
                $ChannelSQL .= $DBObject->Quote(
                    $Kernel::OM->Get('Channel')->ChannelLookup( Name => $_ ),
                    'Integer',
                );
            }
        }
        if ($ChannelSQL) {
            $ChannelSQL = " AND sa.channel_id IN ($ChannelSQL)";
        }
    }
    my $ChannelIDSQL = '';
    if ( IsArrayRefWithData( $Param{ChannelID} ) ) {
        my $QuotedIDs = join ', ',
            map { $DBObject->Quote( $_, 'Integer' ) }
            @{ $Param{ChannelID} };
        $ChannelIDSQL = " AND sa.channel_id IN ($QuotedIDs)";
    }

    my $CustomerVisibleSQL = '';
    if ( $Param{CustomerVisible} ) {
        $CustomerVisibleSQL = " AND sa.customer_visible = 1";
    }
    elsif ( defined( $Param{CustomerVisible} ) ) {
        $CustomerVisibleSQL = " AND sa.customer_visible = 0";
    }

    # sender type lookup
    my $SenderTypeSQL = '';
    if ( $Param{ArticleSenderType} && ref $Param{ArticleSenderType} eq 'ARRAY' ) {
        for ( @{ $Param{ArticleSenderType} } ) {
            if ( $Self->ArticleSenderTypeLookup( SenderType => $_ ) ) {
                if ($SenderTypeSQL) {
                    $SenderTypeSQL .= ',';
                }
                $SenderTypeSQL .= $DBObject->Quote(
                    $Self->ArticleSenderTypeLookup( SenderType => $_ ),
                    'Integer',
                );
            }
        }
        if ($SenderTypeSQL) {
            $SenderTypeSQL = " AND sa.article_sender_type_id IN ($SenderTypeSQL)";
        }
    }

    my $SenderTypeIDSQL;
    if ( IsArrayRefWithData( $Param{ArticleSenderTypeID} ) ) {
        my $QuotedIDs = join ', ',
            map { $DBObject->Quote( $_, 'Integer' ) }
            @{ $Param{ArticleSenderTypeID} };
        $SenderTypeIDSQL = " AND sa.article_sender_type_id IN ($QuotedIDs)";
    }

    # sql query
    my @Content;
    my @Bind;
    my $SQL = '
        SELECT sa.ticket_id, sa.a_from, sa.a_to, sa.a_cc, sa.a_bcc, sa.a_subject,
            sa.a_reply_to, sa.a_message_id, sa.a_in_reply_to, sa.a_references, sa.a_body,
            sa.create_time, sa.a_content_type, sa.create_by, article_sender_type_id,
            sa.channel_id, sa.incoming_time, sa.id, sa.change_time, sa.change_by, sa.customer_visible, sa.attachment_count
        FROM article sa
        WHERE ';

    if ( $Param{ArticleID} ) {
        $SQL .= 'sa.id = ?';
        push @Bind, \$Param{ArticleID};
    }
    else {
        $SQL .= 'sa.ticket_id = ?';
        push @Bind, \$Param{TicketID};
    }

    # add channels
    if ($ChannelSQL) {
        $SQL .= $ChannelSQL;
    }
    if ($ChannelIDSQL) {
        $SQL .= $ChannelIDSQL;
    }

    # add customer visibility
    if ($CustomerVisibleSQL) {
        $SQL .= $CustomerVisibleSQL;
    }

    # add sender types
    if ($SenderTypeSQL) {
        $SQL .= $SenderTypeSQL;
    }
    if ($SenderTypeIDSQL) {
        $SQL .= $SenderTypeIDSQL;
    }

    # add message id
    my $MessageIDSQL;
    if ( IsArrayRefWithData( $Param{MessageID} ) ) {
        $SQL .= ' AND sa.a_message_id_md5 IN (' . join( ',', map {'?'} @{ $Param{MessageID} } ) . ')';

        for my $MessageID ( @{ $Param{MessageID} } ) {
            my $MD5 = $Kernel::OM->Get('Main')->MD5sum( String => $MessageID );
            push( @Bind, \$MD5 );
        }

        $MessageIDSQL = 1;
    }

    # set order
    if ( $Param{Order} && $Param{Order} eq 'DESC' ) {
        $SQL .= ' ORDER BY sa.create_time DESC, sa.id DESC';
    }
    else {
        $SQL .= ' ORDER BY sa.create_time, sa.id ASC';
    }

    my $Start;

    if ( $Param{Page} ) {
        $Start = $Param{Limit} * ( $Param{Page} - 1 );
    }

    # get time object
    my $TimeObject = $Kernel::OM->Get('Time');

    return if !$DBObject->Prepare(
        SQL   => $SQL,
        Bind  => \@Bind,
        Limit => $Param{Limit},
        Start => $Start,
    );

    my %Ticket;
    while ( my @Row = $DBObject->FetchrowArray() ) {

        my %Data;
        $Data{TicketID}         = $Row[0];
        $Data{From}             = $Row[1];
        $Data{To}               = $Row[2];
        $Data{Cc}               = $Row[3];
        $Data{Bcc}              = $Row[4];
        $Data{Subject}          = $Row[5];
        $Data{ReplyTo}          = $Row[6];
        $Data{MessageID}        = $Row[7];
        $Data{InReplyTo}        = $Row[8];
        $Data{References}       = $Row[9];
        $Data{Body}             = $Row[10];
        $Data{CreateTime}       = $Row[11];
        $Data{ContentType}      = $Row[12];
        $Data{CreatedBy}        = $Row[13];
        $Data{SenderTypeID}     = $Row[14];
        $Data{ChannelID}        = $Row[15];
        $Data{IncomingTime}     = $Row[16];
        $Data{ArticleID}        = $Row[17];
        $Data{ChangeTime}       = $Row[18];
        $Data{ChangedBy}        = $Row[19];
        $Data{CustomerVisible}  = $Row[20];
        $Data{AttachmentCount}  = $Row[21];

        if ( $Data{ContentType} && $Data{ContentType} =~ /charset=/i ) {
            $Data{Charset} = $Data{ContentType};
            $Data{Charset} =~ s/.+?charset=("|'|)(\w+)/$2/gi;
            $Data{Charset} =~ s/"|'//g;
            $Data{Charset} =~ s/(.+?);.*/$1/g;

        }
        else {
            $Data{Charset} = '';
        }

        # compat.
        $Data{ContentCharset} = $Data{Charset};

        if ( $Data{ContentType} && $Data{ContentType} =~ /^(\w+\/\w+)/i ) {
            $Data{MimeType} = $1;
            $Data{MimeType} =~ s/"|'//g;
        }
        else {
            $Data{MimeType} = '';
        }

        # strip not wanted stuff
        RECIPIENT:
        for my $Key (qw(From To Cc Bcc Subject)) {
            next RECIPIENT if !$Data{$Key};
            $Data{$Key} =~ s/\n|\r//g;
        }

        push @Content, { %Ticket, %Data };
    }

    # check if need to return dynamic fields
    if ($FetchDynamicFields) {

        # get dynamic field objects
        my $DynamicFieldObject        = $Kernel::OM->Get('DynamicField');
        my $DynamicFieldBackendObject = $Kernel::OM->Get('DynamicField::Backend');

        my $DynamicFieldArticleList = $DynamicFieldObject->DynamicFieldListGet(
            ObjectType => 'Article'
        );

        for my $Article (@Content) {
            DYNAMICFIELD:
            for my $DynamicFieldConfig ( @{$DynamicFieldArticleList} ) {

                # validate each dynamic field
                next DYNAMICFIELD if !$DynamicFieldConfig;
                next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
                next DYNAMICFIELD if !$DynamicFieldConfig->{Name};

                # get the current value for each dynamic field
                my $Value = $DynamicFieldBackendObject->ValueGet(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    ObjectID           => $Article->{ArticleID},
                );

                # set the dynamic field name and value into the ticket hash
                $Article->{ 'DynamicField_' . $DynamicFieldConfig->{Name} } = $Value;
            }
        }
    }

    # return if content is empty
    if ( !@Content ) {

        # Log an error only if a specific article was requested and there is no filter active.
        if (
            $Param{ArticleID}
            && !$ChannelSQL
            && !$SenderTypeSQL
            && !$CustomerVisibleSQL
            && !$MessageIDSQL
        ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No such article for ArticleID ($Param{ArticleID})!",
            );
        }

        return;
    }

    # create email parser object
    my $EmailParser = Kernel::System::EmailParser->new(
        Mode => 'Standalone',
    );

    # article stuff
    for my $Part (@Content) {

        # get sender type
        $Part->{SenderType} = $Self->ArticleSenderTypeLookup(
            SenderTypeID => $Part->{SenderTypeID},
        );

        # get article type
        $Part->{Channel} = $Kernel::OM->Get('Channel')->ChannelLookup(
            ID => $Part->{ChannelID},
        );

        # add real name lines
        RECIPIENT:
        for my $Key (qw( From To Cc Bcc)) {
            if (!$Part->{$Key}) {
                $Part->{ $Key . 'Realname' } = undef;
                next RECIPIENT;
            }

            # check if it's a queue
            if ( $Part->{$Key} !~ /@/ ) {
                $Part->{ $Key . 'Realname' } = $Part->{$Key};
                next RECIPIENT;
            }

            # strip out real names
            my $Realname = '';
            EMAILADDRESS:
            for my $EmailSplit ( $EmailParser->SplitAddressLine( Line => $Part->{$Key} ) ) {
                my $Name = $EmailParser->GetRealname( Email => $EmailSplit );
                if ( !$Name ) {
                    $Name = $EmailParser->GetEmailAddress( Email => $EmailSplit );
                }
                next EMAILADDRESS if !$Name;
                if ($Realname) {
                    $Realname .= ', ';
                }
                $Realname .= $Name;
            }

            $Part->{ $Key . 'Realname' } = $Realname;
        }

        # add TimeUnit
        $Part->{TimeUnit} = $Self->ArticleAccountedTimeGet(
            ArticleID => $Part->{ArticleID},
        );
    }

    if ( $Param{ArticleID} ) {
        return %{ $Content[0] };
    }
    return @Content;
}

=item ArticleCount()

Returns the number of articles for a ticket, possibly filtered by
ArticleSenderTypeID and ChannelID

    my $ArticleCount = $TicketID->ArticleCount(
        TicketID            => 123,
        ChannelID           => [1, 2], # optional
        ArticleSenderTypeID => [1, 2], # optional
    );

If the argument C<UpToArticleID> is given, only articles that would normally
shown before (and including) this article are shown; C<Order> (which can
be C<ASC> or C<DESC>) controls whether ascending or descending order is used.

=cut

sub ArticleCount {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need TicketID!'
        );
        return;
    }

    my $SQL  = 'SELECT COUNT(id) FROM article WHERE ticket_id = ?';
    my @Bind = ( \$Param{TicketID} );
    if ( IsArrayRefWithData( $Param{ChannelID} ) ) {
        $SQL .= sprintf ' AND channel_id IN (%s) ',
            join ', ', ('?') x @{ $Param{ChannelID} };
        push @Bind, map { \$_ } @{ $Param{ChannelID} };
    }
    if ( IsArrayRefWithData( $Param{ArticleSenderTypeID} ) ) {
        $SQL .= sprintf ' AND article_sender_type_id IN (%s) ',
            join ', ', ('?') x @{ $Param{ArticleSenderTypeID} };
        push @Bind, map { \$_ } @{ $Param{ArticleSenderTypeID} };
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    if ( defined $Param{UpToArticleID} ) {

        $DBObject->Prepare(
            SQL  => 'SELECT create_time FROM article WHERE id = ?',
            Bind => [ \$Param{UpToArticleID} ],
        );

        my $CreateTime;

        while ( my @Row = $DBObject->FetchrowArray() ) {
            $CreateTime = $Row[0];
        }

        if ( !defined $CreateTime ) {
            return 0;
        }

        my $Op = ( $Param{Order} // 'ASC' ) eq 'DESC' ? '>' : '<';

        $SQL .= " AND (create_time $Op ? OR (create_time = ? AND id $Op= ?))";
        push @Bind, \$CreateTime, \$CreateTime, \$Param{UpToArticleID};
    }

    return if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => \@Bind
    );

    my $Count;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Count = $Row[0];
    }

    return $Count;
}

=item ArticlePage()

Get the page number of a given article when pagination is active

    my $Page = $TicketObject->ArticlePage(
        TicketID            => 123,
        ArticleID           => 4242,
        RowsPerPage         => 20,
        ChannelID           => [1, 2], # optional
        ArticleSenderTypeID => [1],    # optional
        Order               => 'DESC', # optional, 'ASC' or 'DESC'
    );

=cut

sub ArticlePage {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(ArticleID TicketID RowsPerPage)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my $Count = $Self->ArticleCount(
        TicketID            => $Param{TicketID},
        UpToArticleID       => $Param{ArticleID},
        ArticleSenderTypeID => $Param{ArticleSenderTypeID},
        ChannelID           => $Param{ChannelID},
        Order               => $Param{Order},
    );

    return ceil( $Count / $Param{RowsPerPage} );
}

=begin Internal:

=cut

sub _ArticleGetId {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(TicketID MessageID From Subject IncomingTime)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # sql query
    my @Bind = ( \$Param{TicketID} );
    my $SQL  = 'SELECT id FROM article WHERE ticket_id = ? AND ';
    if ( $Param{MessageID} ) {
        $SQL .= 'a_message_id = ? AND ';
        push @Bind, \$Param{MessageID};
    }
    if ( $Param{From} ) {
        $SQL .= 'a_from = ? AND ';
        push @Bind, \$Param{From};
    }
    if ( $Param{Subject} ) {
        $SQL .= 'a_subject = ? AND ';
        push @Bind, \$Param{Subject};
    }
    $SQL .= ' incoming_time = ? ORDER BY id DESC';
    push @Bind, \$Param{IncomingTime};

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # start query
    return if !$DBObject->Prepare(
        SQL   => $SQL,
        Bind  => \@Bind,
        Limit => 1,
    );

    my $ID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ID = $Row[0];
    }

    return $ID;
}

=end Internal:

=item ArticleUpdate()

update an article

    my $Success = $TicketObject->ArticleUpdate(
        ArticleID       => 123,
        Body            => '...',           # optional
        Subject         => '...',           # optional
        From            => '...',           # optional
        To              => '...',           # optional
        Cc              => '...',           # optional
        Bcc             => '...',           # optional
        ReplyTo         => '...',           # optional
        CustomerVisible => 0|1,             # optional
        SenderType      => '...',           # optional
        SenderTypeID    => '...',           # optional, Prio over SenderType
        IncomingTime    => '...',           # optional
        ContentType     => '...',           # optional
        UserID          => 123,
    );

Events:
    ArticleUpdate

=cut

sub ArticleUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ArticleID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # do not use given TicketID
    delete( $Param{TicketID} );

    # check for defined values of required database columns
    for my $Key ( qw(Body IncomingTime SenderType SenderTypeID) ) {
        if (
            exists( $Param{ $Key } )
            && !defined( $Param{ $Key } )
        ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Parameter '$Key' does not allow undefined values!",
            );
            return;
        }
    }

    my %Article = $Self->ArticleGet(ArticleID => $Param{ArticleID});
    if ( !%Article ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No such article for ArticleID ($Param{ArticleID})!"
        );
        return;
    }

    # check if update is required
    my $ChangeRequired;
    KEY:
    for my $Key ( qw(Subject Body From To Cc Bcc IncomingTime ReplyTo CustomerVisible SenderType SenderTypeID ContentType) ) {
        next KEY if (
            !exists( $Param{ $Key } )
            || (
                defined( $Article{ $Key } )
                && defined( $Param{ $Key } )
                && $Article{ $Key } eq $Param{ $Key }
            )
        );
        $ChangeRequired = 1;
        last KEY;
    }

    # merge
    %Article = (
        %Article,
        %Param,
    );

    # lookup for SenderType
    if ( defined $Param{SenderType} && !defined $Param{SenderTypeID} ) {
        $Article{SenderTypeID} = $Self->ArticleSenderTypeLookup(
            SenderType => $Param{SenderType},
        );

        if ( !$Article{SenderTypeID} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Couldn't update article for ticket $Article{TicketID}. Can't find sender type with name \"$Param{SenderType}\"!",
            );
            return;
        }
    }

    # prepare IncomingTime if given
    if ( defined $Param{IncomingTime} ) {
        my $IncomingSystemTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
            String => $Param{IncomingTime},
        );
        $Article{IncomingTime} = $IncomingSystemTime if $IncomingSystemTime;
    }

    # db update
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => "UPDATE article SET a_body = ?, a_subject = ?, a_from = ?, a_to = ?, a_cc = ?, a_bcc = ?, a_reply_to = ?, "
            . "customer_visible = ?, article_sender_type_id = ?, incoming_time = ?, a_content_type = ?, "
            . "change_time = current_timestamp, change_by = ? WHERE id = ?",
        Bind => [
            \$Article{Body}, \$Article{Subject}, \$Article{From}, \$Article{To}, \$Article{Cc}, \$Article{Bcc}, \$Article{ReplyTo},
            \$Article{CustomerVisible}, \$Article{SenderTypeID}, \$Article{IncomingTime}, \$Article{ContentType}, \$Article{UserID},
            \$Param{ArticleID}
        ],
    );

    # clear ticket cache
    $Self->_TicketCacheClear(
        TicketID => $Article{TicketID},
    );

    # event
    $Self->EventHandler(
        Event => 'ArticleUpdate',
        Data  => {
            TicketID  => $Article{TicketID},
            ArticleID => $Param{ArticleID},
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Ticket.Article',
        UserID    => $Param{UserID},
        ObjectID  => $Article{TicketID}.'::'.$Param{ArticleID},
    );

    return 1;
}

=item ArticleBounce()

bounce an article

    my $Success = $TicketObject->ArticleBounce(
        From      => 'some@example.com',
        To        => 'webmaster@example.com',
        TicketID  => 123,
        ArticleID => 123,
        UserID    => 123,
    );

Events:
    ArticleBounce

=cut

sub ArticleBounce {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(TicketID ArticleID From To UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # create message id
    my $NewMessageID = $Kernel::OM->Get('Email')->GenerateMessageID();
    my $Email        = $Self->ArticlePlain( ArticleID => $Param{ArticleID} );

    # check if plain email exists
    if ( !$Email ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No such plain article for ArticleID ($Param{ArticleID})!",
        );
        return;
    }

    # pipe all into sendmail
    return if !$Kernel::OM->Get('Email')->Bounce(
        'Message-ID' => $NewMessageID,
        From         => $Param{From},
        To           => $Param{To},
        Email        => $Email,
    );

    # write history
    my $HistoryType = $Param{HistoryType} || 'Bounce';
    $Self->HistoryAdd(
        TicketID     => $Param{TicketID},
        ArticleID    => $Param{ArticleID},
        HistoryType  => $HistoryType,
        Name         => "\%\%$Param{To}",
        CreateUserID => $Param{UserID},
    );

    # event
    $Self->EventHandler(
        Event => 'ArticleBounce',
        Data  => {
            TicketID  => $Param{TicketID},
            ArticleID => $Param{ArticleID},
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Ticket.Article',
        ObjectID  => $Param{TicketID}.'::'.$Param{ArticleID},
    );

    return 1;
}

=item ArticleFlagSet()

set article flags

    my $Success = $TicketObject->ArticleFlagSet(
        ArticleID => 123,
        Key       => 'Seen',
        Value     => 1,
        UserID    => 123,
        Silent    => 1,       # optional - if set, no client notification will be triggered
        NoEvents  => 1,       # optional - trigger no events
        TicketID  => 123      # optional
    );

Events:
    ArticleFlagSet

=cut

sub ArticleFlagSet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ArticleID Key Value UserID)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    if (!$Param{TicketID}) {
        # get ticket id of article
        my $TicketID = $Self->ArticleGetTicketID(
            ArticleID => $Param{ArticleID}
        );
        if (!$TicketID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No article found with id $Param{ArticleID}!"
            );
            return;
        }

        $Param{TicketID} =$TicketID;
    }

    my %Flag = $Self->ArticleFlagGet(
        TicketID => $Param{TicketID},
        %Param,
    );

    # check if set is needed
    return 1 if defined $Flag{ $Param{Key} } && $Flag{ $Param{Key} } eq $Param{Value};

    my $UserID = $Param{UserID};
    if ( $Param{Key} =~ /^(?:SMIME|NotSend|RetryEncrypt)/smx ) {
        $UserID = 1;
    }

    # set flag
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => '
            DELETE FROM article_flag
            WHERE article_id = ?
                AND article_key = ?
                AND create_by = ?',
        Bind => [ \$Param{ArticleID}, \$Param{Key}, \$UserID ],
    );

    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'INSERT INTO article_flag
            (article_id, article_key, article_value, create_time, create_by)
            VALUES (?, ?, ?, current_timestamp, ?)',
        Bind => [ \$Param{ArticleID}, \$Param{Key}, \$Param{Value}, \$UserID ],
    );

    # check if we have to set the ticket Seen flag as well
    if ( $Param{Key} eq 'Seen' ) {
        my $ArticleCount = $Self->ArticleCount(
            TicketID => $Param{TicketID},
        );

        $Kernel::OM->Get('DB')->Prepare(
            SQL   => 'SELECT count(*) FROM article a, article_flag af WHERE a.ticket_id = ? AND
                af.article_id = a.id AND article_key = ? AND af.create_by = ?',
            Bind  => [ \$Param{TicketID}, \$Param{Key}, \$Param{UserID} ],
            Limit => 1,
        );

        my $SeenCount;
        while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
            $SeenCount = $Row[0];
        }
        if ( $SeenCount == $ArticleCount ) {
            my $Result = $Self->TicketFlagSet(
                TicketID => $Param{TicketID},
                Key      => 'Seen',
                Value    => 1,
                UserID   => $Param{UserID}
            );
            if ( !$Result ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unable to set Seen flag for TicketID $Param{TicketID}!"
                );
            }
        }
    }

    # check if we have to set the ticket Seen flag as well
    if ( $Param{Key} eq 'Seen' ) {
        my $ArticleCount = $Self->ArticleCount(
            TicketID => $Param{TicketID},
        );

        $Kernel::OM->Get('DB')->Prepare(
            SQL   => 'SELECT count(*) FROM article a, article_flag af WHERE a.ticket_id = ? AND
                af.article_id = a.id AND article_key = ? AND af.create_by = ?',
            Bind  => [ \$Param{TicketID}, \$Param{Key}, \$Param{UserID} ],
            Limit => 1,
        );

        my $SeenCount;
        while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
            $SeenCount = $Row[0];
        }
        if ( $SeenCount == $ArticleCount ) {
            my $Result = $Self->TicketFlagSet(
                TicketID => $Param{TicketID},
                Key      => 'Seen',
                Value    => 1,
                UserID   => $Param{UserID}
            );
            if ( !$Result ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unable to set Seen flag for TicketID $Param{TicketID}!"
                );
            }
        }
    }

    # clear ticket cache
    $Self->_TicketCacheClear(
        TicketID => $Param{TicketID}
    );

    if ( !$Param{NoEvents} ) {
        $Self->EventHandler(
            Event => 'ArticleFlagSet',
            Data  => {
                TicketID  => $Param{TicketID},
                ArticleID => $Param{ArticleID},
                Key       => $Param{Key},
                Value     => $Param{Value},
                UserID    => $UserID,
            },
            UserID => $Param{UserID},
        );
    }

    # push client callback event
    if (!$Param{Silent}) {
        $Kernel::OM->Get('ClientNotification')->NotifyClients(
            Event     => 'CREATE',
            Namespace => 'Ticket.Article.Flag',
            UserID    => $Param{UserID},
            ObjectID  => $Param{TicketID}.'::'.$Param{ArticleID}.'::'.$Param{Key},
        );
    }

    return 1;
}

=item ArticleFlagDelete()

delete article flag

    my $Success = $TicketObject->ArticleFlagDelete(
        ArticleID => 123,
        Key       => 'seen',
        UserID    => 123,
    );

    my $Success = $TicketObject->ArticleFlagDelete(
        ArticleID => 123,
        Key       => 'seen',
        AllUsers  => 1,         # delete for all users
    );

Events:
    ArticleFlagDelete

=cut

sub ArticleFlagDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ArticleID Key)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    if ( !$Param{AllUsers} && !$Param{UserID} ) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need AllUsers or UserID!"
            );
            return;
        }
    }

    # get ticket id of article
    my $TicketID = $Self->ArticleGetTicketID(
        ArticleID => $Param{ArticleID}
    );

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    if ( $Param{AllUsers} ) {
        return if !$DBObject->Do(
            SQL => '
                DELETE FROM article_flag
                WHERE article_id = ?
                    AND article_key = ?',
            Bind => [ \$Param{ArticleID}, \$Param{Key} ],
        );
    }
    else {
        return if !$DBObject->Do(
            SQL => '
                DELETE FROM article_flag
                WHERE article_id = ?
                    AND create_by = ?
                    AND article_key = ?',
            Bind => [ \$Param{ArticleID}, \$Param{UserID}, \$Param{Key} ],
        );

        $Self->EventHandler(
            Event => 'ArticleFlagDelete',
            Data  => {
                TicketID  => $TicketID,
                ArticleID => $Param{ArticleID},
                Key       => $Param{Key},
                UserID    => $Param{UserID},
            },
            UserID => $Param{UserID},
        );
    }

    # clear ticket cache
    $Self->_TicketCacheClear(
        TicketID => $TicketID
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Ticket.Article.Flag',
        UserID    => $Param{UserID},
        ObjectID  => $TicketID.'::'.$Param{ArticleID}.'::'.$Param{Key},
    );

    return 1;
}

=item ArticleFlagGet()

get article flags

    my %Flags = $TicketObject->ArticleFlagGet(
        TicketID  => 123,
        ArticleID => 123,
        UserID    => 123,
    );

=cut

sub ArticleFlagGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(TicketID ArticleID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # prepare cache key
    my $CacheKey = 'ArticleFlagGet::' . $Param{ArticleID} . '::' . $Param{UserID};

    # check cache
    my $Cached = $Self->_TicketCacheGet(
        TicketID => $Param{TicketID},
        Key      => $CacheKey,
    );
    return %{$Cached} if ref $Cached eq 'HASH';

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # sql query
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL => '
            SELECT article_key, article_value
            FROM article_flag
            WHERE article_id = ?
                AND create_by = ?',
        Bind  => [ \$Param{ArticleID}, \$Param{UserID} ],
        Limit => 1500,
    );

    my %Flag;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Flag{ $Row[0] } = $Row[1];
    }

    if ( $Param{UserID} ne '1' ) {
        my $UserID = 1;
        # sql query
        return if !$Kernel::OM->Get('DB')->Prepare(
            SQL => '
                SELECT article_key, article_value
                FROM article_flag
                WHERE article_id = ?
                    AND create_by = ?',
            Bind  => [ \$Param{ArticleID}, \$UserID ],
            Limit => 1500,
        );

        while ( my @Row = $DBObject->FetchrowArray() ) {
            next if ( $Row[0] !~ /^(?:SMIME|NotSend|RetryEncrypt)/smx );
            $Flag{ $Row[0] } = $Row[1];
        }
    }

    # set cache
    $Self->_TicketCacheSet(
        TicketID => $Param{TicketID},
        Key      => $CacheKey,
        Value    => \%Flag,
    );

    return %Flag;
}

=item ArticleUserFlagExists()

check if the given flag exists for the given user

    my $Exists = $TicketObject->ArticleUserFlagExists(
        ArticleID => 123,
        Flag      => 'Seen',
        Value     => ...,           # optional
        UserID    => 123,
    );

=cut

sub ArticleUserFlagExists {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ArticleID Flag UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # get cache object
    my $CacheObject = $Kernel::OM->Get('Cache');

    # check cache
    my $CacheKey = 'ArticleFlagExists::' . $Param{TicketID} . '::' . $Param{UserID} . '::' . $Param{Flag} . '::' . ($Param{Value}||'');
    my $Flags = $CacheObject->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    if ( exists $Param{Value} ) {
        return if !$DBObject->Prepare(
            SQL   => 'SELECT id FROM article_flag WHERE article_id = ? AND article_key = ? AND article_value = ? AND create_by = ?',
            Bind  => [
                \$Param{ArticleID}, \$Param{Flag}, \$Param{Value}, \$Param{UserID}
            ],
            Limit => 1,
        );
    }
    else {
        return if !$DBObject->Prepare(
            SQL   => 'SELECT id FROM article_flag WHERE article_id = ? AND article_key = ? AND create_by = ?',
            Bind  => [
                \$Param{ArticleID}, \$Param{Flag}, \$Param{UserID}
            ],
            Limit => 1,
        );
    }

    # fetch the result
    my $Exists = 0;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Exists = $Row[0];
    }

    # set cache
    $CacheObject->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => $Exists,
    );

    return $Exists;
}

=item ArticleFlagsOfTicketGet()

get all article flags of a ticket

    my %Flags = $TicketObject->ArticleFlagsOfTicketGet(
        TicketID  => 123,
        UserID    => 123,
    );

    returns (
        123 => {                    # ArticleID
            'Seen'  => 1,
            'Other' => 'something',
        },
    )

=cut

sub ArticleFlagsOfTicketGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(TicketID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # prepare cache key
    my $CacheKey = 'ArticleFlagsOfTicketGet::' . $Param{UserID};

    # check cache
    my $Cached = $Self->_TicketCacheGet(
        TicketID => $Param{TicketID},
        Key      => $CacheKey,
    );
    return %{$Cached} if ref $Cached eq 'HASH';

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # sql query
    return if !$DBObject->Prepare(
        SQL => '
            SELECT article.id, article_flag.article_key, article_flag.article_value
            FROM article_flag, article
            WHERE article.id = article_flag.article_id
                AND article.ticket_id = ?
                AND article_flag.create_by = ?',
        Bind  => [ \$Param{TicketID}, \$Param{UserID} ],
    );

    my %Flag;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Flag{ $Row[0] }->{ $Row[1] } = $Row[2];
    }

    # set cache
    $Self->_TicketCacheSet(
        TicketID => $Param{TicketID},
        Key      => $CacheKey,
        Value    => \%Flag,
    );

    return %Flag;
}

=item ArticleAccountedTimeGet()

returns the accounted time of a article.

    my $AccountedTime = $TicketObject->ArticleAccountedTimeGet(
        ArticleID => $ArticleID,
    );

=cut

sub ArticleAccountedTimeGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ArticleID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need ArticleID!'
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # db query
    return if !$DBObject->Prepare(
        SQL  => 'SELECT time_unit FROM time_accounting WHERE article_id = ?',
        Bind => [ \$Param{ArticleID} ],
    );

    my $AccountedTime = 0;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Row[0] =~ s/,/./g;
        $AccountedTime = $AccountedTime + $Row[0];
    }

    return $AccountedTime;
}

=item ArticleAccountedTimeDelete()

delete accounted time of article

    my $Success = $TicketObject->ArticleAccountedTimeDelete(
        ArticleID => $ArticleID,
        UserID    => 1
    );

=cut

sub ArticleAccountedTimeDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ArticleID UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"

            );
            return;
        }
    }

    # db query
    return if !$Kernel::OM->Get('DB')->Do(
        SQL  => 'DELETE FROM time_accounting WHERE article_id = ?',
        Bind => [ \$Param{ArticleID} ],
    );

    # get ticket id of article
    my $TicketID = $Self->ArticleGetTicketID(
        ArticleID => $Param{ArticleID}
    );

    # update ticket data
    my $AccountedTime = $Self->TicketAccountedTimeGet( TicketID => $TicketID );
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE ticket SET change_time = current_timestamp, '
            . ' change_by = ?, accounted_time = ? WHERE id = ?',
        Bind => [ \$Param{UserID}, \$AccountedTime, \$TicketID ],
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Ticket.Article.AccountedTime',
        ObjectID  => $TicketID.'::'.$Param{ArticleID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Ticket',
        ObjectID  => $TicketID,
    );

    return 1;
}

1;

# the following is the pod for Kernel/System/Ticket/ArticleStorage*.pm

=item ArticleDelete()

delete an article, its plain message, and all attachments

    my $Success = $TicketObject->ArticleDelete(
        ArticleID => 123,
        UserID    => 123,
        NoHistory => 1         # optional, if given, no history entry will added
    );

=item ArticleDeletePlain()

delete a plain article

    my $Success = $TicketObject->ArticleDeletePlain(
        ArticleID => 123,
        UserID    => 123,
    );

=item ArticleDeleteAttachments()

delete all attachments of an article

    my $Success = $TicketObject->ArticleDeleteAttachments(
        ArticleID => 123,
        UserID    => 123,
    );

=item ArticleWritePlain()

write a plain email to storage

    my $Success = $TicketObject->ArticleWritePlain(
        ArticleID => 123,
        Email     => $EmailAsString,
        UserID    => 123,
    );

=item ArticlePlain()

get plain article/email

    my $PlainMessage = $TicketObject->ArticlePlain(
        ArticleID => 123,
        UserID    => 123,
    );

=item ArticleWriteAttachment()

write an article attachment to storage

    my $Success = $TicketObject->ArticleWriteAttachment(
        Content            => $ContentAsString,                     # optional
        ContentType        => 'text/html; charset="iso-8859-15"',
        Filename           => 'lala.html',
        ContentID          => 'cid-1234',                           # optional
        ContentAlternative => 0,                                    # optional, alternative content to shown as body
        Disposition        => 'attachment',                         # or 'inline'
        ArticleID          => 123,
        UserID             => 123,
        CountAsUpdate      => 1|0                                   # optional, default 0 - use 1 if e.g. new attachment should count as article update (change time/by update)
    );

=item ArticleAttachment()

get article attachment (Content, ContentType, Filename and optional ContentID, ContentAlternative)

    my %Attachment = $TicketObject->ArticleAttachment(
        ArticleID    => 123,
        AttachmentID => 1,   # as returned by ArticleAttachmentIndex
        UserID       => 123,
    );

returns:

    my %Attachment = (
        Content            => "xxxx",     # actual attachment contents
        ContentAlternative => "",
        ContentID          => "",
        ContentType        => "application/pdf",
        Filename           => "StdAttachment-Test1.pdf",
        Filesize           => "4.6 KBytes",
        FilesizeRaw        => 4722,
        Disposition        => 'attachment',
    );

=item ArticleAttachmentIndex()

get article attachment index as hash

 (ID => hashref (Filename, Filesize, ContentID (if exists), ContentAlternative(if exists) ))

    my %Index = $TicketObject->ArticleAttachmentIndex(
        ArticleID => 123,
        UserID    => 123,
    );

or with "StripPlainBodyAsAttachment => 1" feature to not include first
attachment (not include text body, html body as attachment and inline attachments)

    my %Index = $TicketObject->ArticleAttachmentIndex(
        ArticleID                  => 123,
        UserID                     => 123,
        Article                    => \%Article,
        StripPlainBodyAsAttachment => 1,
    );

or with "StripPlainBodyAsAttachment => 2" feature to not include first
attachment (not include text body as attachment)

    my %Index = $TicketObject->ArticleAttachmentIndex(
        ArticleID                  => 123,
        UserID                     => 123,
        Article                    => \%Article,
        StripPlainBodyAsAttachment => 2,
    );

or with "StripPlainBodyAsAttachment => 3" feature to not include first
attachment (not include text body and html body as attachment)

    my %Index = $TicketObject->ArticleAttachmentIndex(
        ArticleID                  => 123,
        UserID                     => 123,
        Article                    => \%Article,
        StripPlainBodyAsAttachment => 3,
    );

returns:

    my %Index = {
        '1' => {
            ContentAlternative => '',
            ContentID          => '',
            Filesize           => '4.6 KBytes',
            ContentType        => 'application/pdf',
            Filename           => 'StdAttachment-Test1.pdf',
            FilesizeRaw        => 4722,
            Disposition        => attachment,
        },
        '2' => {
            ContentAlternative => '',
            ContentID          => '',
            Filesize           => '183 Bytes',
            ContentType        => 'text/html; charset="utf-8"',
            Filename           => 'file-2',
            FilesizeRaw        => 183,
            Disposition        => attachment,
        },
    };

=cut

sub ArticleAttachmentIndex {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ArticleID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get attachment index from backend
    my %Attachments = $Self->ArticleAttachmentIndexRaw(%Param);

    # stript plain attachments and e. g. html attachments
    if ( $Param{StripPlainBodyAsAttachment} && $Param{Article} ) {

        # plain attachment mime type vs. html attachment mime type check
        # remove plain body, rename html attachment
        my $AttachmentIDPlain = 0;
        my $AttachmentIDHTML  = 0;
        for my $AttachmentID ( sort keys %Attachments ) {
            my %File = %{ $Attachments{$AttachmentID} };

            # find plain attachment
            if (
                !$AttachmentIDPlain
                &&
                $File{Filename} eq 'file-1'
                && $File{ContentType} =~ /text\/plain/i
                )
            {
                $AttachmentIDPlain = $AttachmentID;
            }

            # find html attachment
            #  o file-[12], is plain+html attachment
            #  o file-1.html, is only html attachment
            if (
                !$AttachmentIDHTML
                &&
                ( $File{Filename} =~ /^file-[12]$/ || $File{Filename} eq 'file-1.html' )
                && $File{ContentType} =~ /text\/html/i
                )
            {
                $AttachmentIDHTML = $AttachmentID;
            }
        }
        if ($AttachmentIDHTML) {
            delete $Attachments{$AttachmentIDPlain};

            # remove any files with content-id from attachment list and listed in html body
            if ( $Param{StripPlainBodyAsAttachment} eq 1 ) {

                # get html body
                my %Attachment = $Self->ArticleAttachment(
                    ArticleID    => $Param{ArticleID},
                    AttachmentID => $AttachmentIDHTML,
                    UserID       => $Param{UserID},
                );

                ATTACHMENT:
                for my $AttachmentID ( sort keys %Attachments ) {
                    my %File = %{ $Attachments{$AttachmentID} };
                    next ATTACHMENT if !$File{ContentID};

                    # content id cleanup
                    $File{ContentID} =~ s/^<//;
                    $File{ContentID} =~ s/>$//;
                    if (
                        $File{ContentID}
                        && $Attachment{Content} =~ /\Q$File{ContentID}\E/i
                        && $File{Disposition} eq 'inline'
                        )
                    {
                        delete $Attachments{$AttachmentID};
                    }
                }
            }

            # only strip html body attachment by "1" or "3"
            if (
                $Param{StripPlainBodyAsAttachment} eq 1
                || $Param{StripPlainBodyAsAttachment} eq 3
                )
            {
                delete $Attachments{$AttachmentIDHTML};
            }
            $Param{Article}->{AttachmentIDOfHTMLBody} = $AttachmentIDHTML;
        }

        # plain body size vs. attched body size check
        # and remove attachment if it's email body
        if ( !$AttachmentIDHTML ) {
            my $AttachmentIDPlain = 0;
            my %AttachmentFilePlain;
            ATTACHMENT_ID:
            for my $AttachmentID ( sort keys %Attachments ) {
                my %File = %{ $Attachments{$AttachmentID} };

                # remember, file-1 got defined by parsing if no filename was given
                if (
                    $File{Filename} eq 'file-1'
                    && $File{ContentType} =~ /text\/plain/i
                    )
                {
                    $AttachmentIDPlain   = $AttachmentID;
                    %AttachmentFilePlain = %File;
                    last ATTACHMENT_ID;
                }
            }

            # plain attachment detected and remove it from attachment index
            if (%AttachmentFilePlain) {

                # check body size vs. attachment size to be sure
                my $BodySize = bytes::length( $Param{Article}->{Body} );

                # check size by tolerance of 1.1 factor (because of charset difs)
                if (
                    $BodySize / 1.1 < $AttachmentFilePlain{FilesizeRaw}
                    && $BodySize * 1.1 > $AttachmentFilePlain{FilesizeRaw}
                    )
                {
                    delete $Attachments{$AttachmentIDPlain};
                }
            }
        }
    }

    return %Attachments;
}

=item ArticleExists()

check if article exists

    my $Exists = $TicketObject->ArticleExists( ArticleID => $ArticleID );

=cut

sub ArticleExists {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ArticleID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need ArticleID!'
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # db query
    return if !$DBObject->Prepare(
        SQL   => 'SELECT id FROM article WHERE id = ?',
        Bind  => [ \$Param{ArticleID} ],
        Limit => 1,
    );

    my $Exists = 0;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Exists = 1;
    }

    return $Exists;
}

=item GetAssignedArticlesForObject()

return all assigned article IDs

    my $TicketIDList = $TicketObject->GetAssignedArticlesForObject(
        TicketID   => 123,
        ObjectType => 'Contact',
        Object     => $ContactHashRef,      # (optional)
        UserID     => 1
    );

=cut

sub GetAssignedArticlesForObject {
    my ( $Self, %Param ) = @_;

    my @AssignedArticleIDs = ();
    my $TicketID = IsArrayRefWithData($Param{TicketID}) ? $Param{TicketID}->[0] : $Param{TicketID};

    # based on ticket
    if ($Param{TicketID}) {
        my $AssignedTicketIDList = $Kernel::OM->Get('Ticket')->GetAssignedTicketsForObject(
            %Param,
            ObjectIDList => [$TicketID]
        );

        if (
            IsArrayRefWithData($AssignedTicketIDList) &&
            scalar(@{$AssignedTicketIDList}) == 1 &&
            $AssignedTicketIDList->[0] == $TicketID
        ) {
            my %SearchData = $Self->_GetAssignedSearchParams(
                %Param,
                AssignedObjectType => 'TicketArticle'
            );

            # TODO: extend "search", currently only CustomerVisible is possible
            # (and it is used as only customer visible (1) or all (0) articles - 'not visible' is not possible)
            if (IsHashRefWithData(\%SearchData) && IsArrayRefWithData($SearchData{CustomerVisible})) {

                my $CustomerVisible = 1;
                for my $VisibleValue ( @{ $SearchData{CustomerVisible} } ) {
                    if (!$VisibleValue) {
                        $CustomerVisible = 0;
                    }
                }

                @AssignedArticleIDs = $Self->ArticleIndex(
                    TicketID        => $TicketID,
                    CustomerVisible => $CustomerVisible,
                    UserID          => $Param{UserID},
                );

                if ( IsArrayRefWithData(\@AssignedArticleIDs) ) {
                    @AssignedArticleIDs = map { 0 + $_ } @AssignedArticleIDs;
                }
            }
        }
    }

    return \@AssignedArticleIDs;
}

# TODO: move to a "common" module (used in other modules too)
=item _GetAssignedSearchParams()

prepares and transform config from AssignedObjectsMapping to a simple hash

    my %SearchData = $Self->_GetAssignedSearchParams(
        ObjectType         => 'Contact',
        Object             => $ContactHash,         # (optional)
        AssignedObjectType => 'Ticket'
    );

    e.g. if AssignedObjectType is 'Ticket'

    %SearchData = (
        ContactID      => 1,
        OrganisationID => 2,
        ...
    );

=cut

sub _GetAssignedSearchParams {
    my ( $Self, %Param ) = @_;

    for my $Needed ( qw(AssignedObjectType ObjectType) ) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my $MappingString = $Kernel::OM->Get('Config')->Get('AssignedObjectsMapping') || '';

    my %SearchData;
    if ( IsStringWithData($MappingString) ) {

        my $Mapping = $Kernel::OM->Get('JSON')->Decode(
            Data   => $MappingString,
            Silent => $Param{Silent} || 0
        );

        if ( !IsHashRefWithData($Mapping) ) {
            if (
                !defined $Param{Silent}
                || !$Param{Silent}
            ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Invalid JSON for sysconfig option 'AssignedObjectsMapping'."
                );
            }
        } elsif (
            IsHashRefWithData( $Mapping->{ $Param{ObjectType} } ) &&
            IsHashRefWithData( $Mapping->{ $Param{ObjectType} }->{ $Param{AssignedObjectType} } )
        ) {
            my %SearchAttributes = %{ $Mapping->{ $Param{ObjectType} }->{ $Param{AssignedObjectType} } };

            # prepare search data
            for my $SearchAttribute ( keys %SearchAttributes ) {
                next if (!$SearchAttribute);

                next if ( !IsHashRefWithData( $SearchAttributes{$SearchAttribute} ) );
                my $ObjectSearchAttributes = $SearchAttributes{$SearchAttribute}->{SearchAttributes};
                my $SearchStatics          = $SearchAttributes{$SearchAttribute}->{SearchStatic};
                next if ( !IsArrayRefWithData( $ObjectSearchAttributes ) && !IsArrayRefWithData($SearchStatics) );

                $SearchAttribute =~ s/^\s+//g;
                $SearchAttribute =~ s/\s+$//g;

                next if (!$SearchAttribute);

                $SearchData{$SearchAttribute} = [];

                # get attributes search data
                if (IsHashRefWithData( $Param{Object} )) {
                    for my $ObjectSearchAttribute ( @{$ObjectSearchAttributes} ) {
                        my $Value;

                        # check if value from sub-object (e.g. User of Contact)
                        if ( $ObjectSearchAttribute =~ /.+\..+/ ) {
                            my @AttributStructure = split(/\./, $ObjectSearchAttribute);
                            next if ( !$AttributStructure[0] || !$AttributStructure[1] || !IsHashRefWithData( $Param{Object}->{$AttributStructure[0]} ) );
                            $Value = $Param{Object}->{$AttributStructure[0]}->{$AttributStructure[1]}
                        } else {
                            $Value = $Param{Object}->{$ObjectSearchAttribute};
                        }

                        next if ( !defined $Value );

                        push (
                            @{ $SearchData{$SearchAttribute} },
                            IsArrayRefWithData($Value) ? @{$Value} : $Value
                        );
                    }
                }

                # get static search data
                for my $SearchStatic ( @{$SearchStatics} ) {
                    next if ( !defined $SearchStatic );
                    push ( @{ $SearchData{$SearchAttribute} }, $SearchStatic );
                }

                if (!scalar(@{ $SearchData{$SearchAttribute} })) {
                    delete $SearchData{$SearchAttribute};
                }
            }
        } else {
            if (
                !defined $Param{Silent}
                || !$Param{Silent}
            ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'info',
                    Message  => "type '$Param{ObjectType}' or sub-type '$Param{AssignedObjectType}' not contained in 'AssignedObjectsMapping'."
                );
            }
        }
    }

    return %SearchData;
}

sub PrepareArticle {
    my ( $Self, %Param ) = @_;

    $Param{CustomerVisible} = $Param{CustomerVisible} // 0;
    $Param{Channel} = $Param{Channel} || 'note';
    $Param{SenderType} = $Param{SenderType} || 'agent';
    $Param{Charset} = $Param{Charset} || 'utf-8';
    $Param{MimeType} = $Param{MimeType} || 'text/html';
    $Param{HistoryType} = $Param{HistoryType} || 'AddArticle';
    $Param{HistoryComment} = $Param{HistoryComment} || '%%';

    # replace placeholders in non-richtext attributes
    for my $Attribute ( qw(Channel SenderType To From Cc Bcc AccountTime) ) {
        next if !defined $Param{$Attribute};

        $Param{$Attribute} = $Self->_ReplaceValuePlaceholder(
            %Param,
            Value       => $Param{$Attribute},
            TicketID    => $Param{TicketID},
            UserID      => $Param{UserID}
        );
    }

    if ( !$Param{ChannelID} && $Param{Channel} ) {
        my $ChannelID = $Kernel::OM->Get('Channel')->ChannelLookup( Name => $Param{Channel} );

        if ( !$ChannelID ) {
            $Kernel::OM->Get('Automation')->LogError(
                Referrer => $Self,
                Message  => "Couldn't create article for ticket $Param{TicketID}. Can't find channel with name \"$Param{Channel}\"!",
                UserID   => $Param{UserID}
            );
            return;
        }

        $Param{ChannelID} = $ChannelID;
    }

    if ( !$Param{SenderTypeID} && $Param{SenderType} ) {
        my $SenderTypeID = $Kernel::OM->Get('Ticket')->ArticleSenderTypeLookup( SenderType => $Param{SenderType} );

        if ( !$SenderTypeID ) {
            $Kernel::OM->Get('Automation')->LogError(
                Referrer => $Self,
                Message  => "Couldn't create article for ticket $Param{TicketID}. Can't find sender type with name \"$Param{SenderType}\"!",
                UserID   => $Param{UserID}
            );
            return;
        }

        $Param{SenderTypeID} = $SenderTypeID;
    }

    # FIXME: needed?
    # convert scalar items into array references
    for my $Attribute ( qw(ForceNotificationToUserID ExcludeNotificationToUserID ExcludeMuteNotificationToUserID) ) {
        if ( IsStringWithData( $Param{$Attribute} ) ) {
            $Param{$Attribute} = $Self->_ConvertScalar2ArrayRef(
                Data => $Param{$Attribute},
            );
        }
    }

    # if "From" is not set use current user
    if ( !$Param{From} ) {
        my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
            UserID => $Param{UserID},
        );
        if (IsHashRefWithData(\%Contact)) {
            $Param{From} = $Contact{Fullname} . ' <' . $Contact{Email} . '>';
        }
    }

    # replace placeholders in attachment attributes
    for my $ID ( 1..5 ) {
        next if !defined $Param{"AttachmentObject$ID"};

        $Param{"AttachmentObject$ID"} = $Self->_ReplaceValuePlaceholder(
            %Param,
            Value       => $Param{"AttachmentObject$ID"},
            TicketID    => $Param{TicketID},
            UserID      => $Param{UserID}
        );
    }

    $Param{Subject} = $Self->_ReplaceValuePlaceholder(
        %Param,
        Value       => $Param{Subject},
        Translate   => 1,
        TicketID    => $Param{TicketID},
        UserID      => $Param{UserID}
    );

    $Param{Body} = $Self->_ReplaceValuePlaceholder(
        %Param,
        Value       => $Param{Body},
        Translate   => 1,
        Richtext    => 1,
        TicketID    => $Param{TicketID},
        UserID      => $Param{UserID}
    );

    # prepare subject if necessary
    if ( $Param{Channel} && $Param{Channel} eq 'email' ) {
        my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
            TicketID => $Param{TicketID},
        );
        if (IsHashRefWithData(\%Ticket)) {
            $Param{Subject} = $Kernel::OM->Get('Ticket')->TicketSubjectBuild(
                TicketNumber => $Ticket{TicketNumber},
                Subject      => $Param{Subject},
                Type         => 'New'
            );
        }
    }

    # prepare attachments
    my @Attachments = ();
    foreach my $ID ( 1..5 ) {
        next if !$Param{"AttachmentObject$ID"} || !IsObject($Param{"AttachmentObject$ID"}, $Kernel::OM->GetModuleFor('Automation::Helper::Object'));

        my $Attachment = $Param{"AttachmentObject$ID"}->AsObject();
        if ( IsBase64($Attachment->{Content}) ) {
            $Attachment->{Content} = MIME::Base64::decode_base64($Attachment->{Content});
        }
        # convert back from byte sequence to prevent double encoding when storing the attachment
        utf8::decode($Attachment->{Content});

        push @Attachments, $Attachment;
    }

    $Param{TimeUnit} = $Param{AccountTime};

    if ( IsArrayRefWithData($Param{Attachment}) ) {
        push (@{$Param{Attachment}}, @Attachments);
    } else {
        $Param{Attachment}  = \@Attachments;
    }

    return %Param;
}

sub _ReplaceValuePlaceholder {
    my ( $Self, %Param ) = @_;

    return $Param{Value} if (!$Param{Value} || $Param{Value} !~ m/(<|&lt;)KIX_/);

    return $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
        Text            => $Param{Value},
        RichText        => $Param{Richtext} || 0,
        Translate       => $Param{Translate} || 0,
        UserID          => $Param{UserID} || 1,
        Data            => $Param{Data},
        ReplaceNotFound => $Param{ReplaceNotFound}
    );
}

sub _GetFromByUser {
    my ( $Self, %Param ) = @_;

    for my $Needed ( qw(UserID Ticket) ) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my $FromFormat = 'SystemAddress';

    my %UserData = $Kernel::OM->Get('User')->GetUserData(
        UserID => $Param{UserID}
    );
    if (
        IsHashRefWithData(\%UserData) && IsHashRefWithData($UserData{Preferences}) &&
        $UserData{Preferences}->{ArticleFromFormat}
    ) {
        $FromFormat = $UserData{Preferences}->{ArticleFromFormat};
    }

    my %Address = $Kernel::OM->Get('Queue')->GetSystemAddress(
        QueueID => $Param{Ticket}->{QueueID},
        UserID  => $Param{UserID}
    );
    if (!IsHashRefWithData(\%Address)) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Cannot prepare "From" value, could not load system address!'
        );
    }

    my %Contact;
    if ($FromFormat =~ m/^Agent/) {
        %Contact = $Kernel::OM->Get('Contact')->ContactGet(
            UserID => $Param{UserID}
        );
        if (!IsHashRefWithData(\%Contact)) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Cannot prepare "From" value, could not load contact data of user!'
            );
            return;
        }
    }

    my $Realname = '';
    if ($FromFormat eq 'Agent') {
        $Realname .= "$Contact{Firstname} $Contact{Lastname}";
    } elsif ($FromFormat eq 'AgentViaSystemAddress') {
        my $Separator = $Kernel::OM->Get('Config')->Get('Ticket::DefineEmailFromSeparator') || '';
        $Realname .= "$Contact{Firstname} $Contact{Lastname} $Separator $Address{RealName}";
    } else {
        $Realname .= $Address{RealName};
    }

    if ($Realname =~ m/[äÄöÖüÜß]/) {
        $Realname =~ s/ä/ae/g;
        $Realname =~ s/Ä/Ae/g;
        $Realname =~ s/ö/oe/g;
        $Realname =~ s/Ö/Oe/g;
        $Realname =~ s/ü/ue/g;
        $Realname =~ s/Ü/Ue/g;
        $Realname =~ s/ß/ss/g;
    }

    return "\"$Realname\" <$Address{Email}>";
}

sub _GetFromByQueue {
    my ( $Self, %Param ) = @_;

    for my $Needed ( qw(UserID Ticket) ) {
        if ( !$Param{ $Needed } ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my %Address = $Kernel::OM->Get('Queue')->GetSystemAddress(
        QueueID => $Param{Ticket}->{QueueID},
        UserID  => $Param{UserID}
    );
    if (!IsHashRefWithData(\%Address)) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Cannot prepare "From" value, could not load system address!'
        );
    }

    my $Realname = $Address{RealName};

    if ($Realname =~ m/[äÄöÖüÜß]/) {
        $Realname =~ s/ä/ae/g;
        $Realname =~ s/Ä/Ae/g;
        $Realname =~ s/ö/oe/g;
        $Realname =~ s/Ö/Oe/g;
        $Realname =~ s/ü/ue/g;
        $Realname =~ s/Ü/Ue/g;
        $Realname =~ s/ß/ss/g;
    }

    return "\"$Realname\" <$Address{Email}>";
}

sub _ConvertScalar2ArrayRef {
    my ( $Self, %Param ) = @_;

    my @Data = split( /,/, $Param{Data} );

    # remove any possible heading and tailing white spaces
    for my $Item (@Data) {
        $Item =~ s{\A\s+}{};
        $Item =~ s{\s+\z}{};
    }

    return \@Data;
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
