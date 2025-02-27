# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::ArticleStorage;

use strict;
use warnings;

use CGI::Carp qw(cluck);
use File::Path;
use File::Basename;

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

sub ArticleStorageInit {
    my ( $Self, %Param ) = @_;

    # ArticleDataDir
    $Self->{ArticleDataDir} = $Kernel::OM->Get('Config')->Get('ArticleDir')
        || die 'Got no ArticleDir!';

    # get time object
    my $TimeObject = $Kernel::OM->Get('Time');

    # create ArticleContentPath
    my ( $Sec, $Min, $Hour, $Day, $Month, $Year ) = $TimeObject->SystemTime2Date(
        SystemTime => $TimeObject->SystemTime(),
    );
    $Self->{ArticleContentPath} = $Year . '/' . $Month . '/' . $Day;

    return 1;
}

sub ArticleDelete {
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

    # get Article
    my %Article = $Self->ArticleGet(
        ArticleID => $Param{ArticleID}
    );

    my $DynamicFieldListArticle = $Kernel::OM->Get('DynamicField')->DynamicFieldListGet(
        ObjectType => 'Article',
        Valid      => 0,
    );

    # get dynamic field backend object
    my $DynamicFieldBackendObject = $Kernel::OM->Get('DynamicField::Backend');

    # delete dynamicfield values for this article
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{$DynamicFieldListArticle} ) {

        next DYNAMICFIELD if !$DynamicFieldConfig;
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
        next DYNAMICFIELD if !$DynamicFieldConfig->{Name};
        next DYNAMICFIELD if !IsHashRefWithData( $DynamicFieldConfig->{Config} );

        $DynamicFieldBackendObject->ValueDelete(
            DynamicFieldConfig => $DynamicFieldConfig,
            ObjectID           => $Param{ArticleID},
            UserID             => $Param{UserID},
        );
    }

    # delete index
    $Self->ArticleIndexDelete(
        ArticleID => $Param{ArticleID},
        UserID    => $Param{UserID},
    );

    # delete time accounting
    $Self->ArticleAccountedTimeDelete(
        ArticleID => $Param{ArticleID},
        UserID    => $Param{UserID},
    );

    # delete attachments
    $Self->ArticleDeleteAttachments(
        ArticleID => $Param{ArticleID},
        UserID    => $Param{UserID},
    );

    # delete plain message
    $Self->ArticleDeletePlain(
        ArticleID => $Param{ArticleID},
        UserID    => $Param{UserID},
    );

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # delete article flags
    return if !$DBObject->Do(
        SQL  => 'DELETE FROM article_flag WHERE article_id = ?',
        Bind => [ \$Param{ArticleID} ],
    );

    # delete article history entries
    return if !$DBObject->Do(
        SQL  => 'DELETE FROM ticket_history WHERE article_id = ?',
        Bind => [ \$Param{ArticleID} ],
    );

    # delete storage directory
    $Self->_ArticleDeleteDirectory(
        ArticleID => $Param{ArticleID},
        UserID    => $Param{UserID},
    );

    # delete articles
    return if !$DBObject->Do(
        SQL  => 'DELETE FROM article WHERE id = ?',
        Bind => [ \$Param{ArticleID} ],
    );

    if ( !$Param{NoHistory} ) {
        $Self->HistoryAdd(
            Name         => "\%\%$Article{ArticleID}\%\%$Article{Subject}",
            HistoryType  => 'ArticleDelete',
            TicketID     => $Article{TicketID},
            CreateUserID => $Param{UserID}
        );
    }

    # clear ticket cache
    $Self->_TicketCacheClear(
        TicketID => $Article{TicketID}
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Ticket.Article',
        ObjectID  => $Article{TicketID}.'::'.$Param{ArticleID},
    );

    return 1;
}

sub ArticleDeletePlain {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ArticleID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    # get ticket id of article
    my $TicketID = $Self->ArticleGetTicketID(
        ArticleID => $Param{ArticleID}
    );

    # delete from fs
    my $ContentPath = $Self->ArticleGetContentPath(
        TicketID  => $TicketID,
        ArticleID => $Param{ArticleID}
    );
    my $File = "$Self->{ArticleDataDir}/$ContentPath/$Param{ArticleID}/plain.txt";
    if ( -f $File ) {
        if ( !unlink $File ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Can't remove: $File: $!!",
            );
            return;
        }
    }

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Ticket.Article.Plain',
        ObjectID  => $TicketID.'::'.$Param{ArticleID},
    );

    return 1;
}

sub ArticleDeleteAttachments {
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

    # get ticket id of article
    my $TicketID = $Self->ArticleGetTicketID(
        ArticleID => $Param{ArticleID}
    );

    # delete attachments
    return if !$Kernel::OM->Get('DB')->Do(
        SQL  => 'DELETE FROM article_attachment WHERE article_id = ?',
        Bind => [ \$Param{ArticleID} ],
    );

    # delete from fs
    my $ContentPath = $Self->ArticleGetContentPath(
        TicketID  => $TicketID,
        ArticleID => $Param{ArticleID}
    );
    my $Path = "$Self->{ArticleDataDir}/$ContentPath/$Param{ArticleID}";

    if ( -e $Path ) {

        my @List = $Kernel::OM->Get('Main')->DirectoryRead(
            Directory => $Path,
            Filter    => "*",
        );

        for my $File (@List) {

            if ( $File !~ /(\/|\\)plain.txt$/ ) {

                if ( !unlink $File ) {

                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => "Can't remove: $File: $!!",
                    );
                }
            }
        }
    }

    # update article attachment counter
    $Kernel::OM->Get('DB')->Do(
        SQL => "UPDATE article SET attachment_count = 0 WHERE id = ?",
        Bind => [ \$Param{ArticleID} ],
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Ticket.Article.Attachment',
        ObjectID  => $TicketID.'::'.$Param{ArticleID},
    );

    return 1;
}

sub ArticleDeleteAttachment {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(AttachmentID ArticleID UserID)) {
        if ( !$Param{ $Needed } ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # get attachment data
    my %Attachment = $Self->ArticleAttachment(
        ArticleID    => $Param{ArticleID},
        AttachmentID => $Param{AttachmentID},
        UserID       => $Param{UserID},
        NoContent    => 1,
    );

    # get ticket id of article
    my $TicketID = $Self->ArticleGetTicketID(
        ArticleID => $Param{ArticleID}
    );

    # delete attachments
    return if !$Kernel::OM->Get('DB')->Do(
        SQL  => 'DELETE FROM article_attachment WHERE id = ? AND article_id = ?',
        Bind => [ \$Param{AttachmentID}, \$Param{ArticleID} ],
    );

    # delete from fs
    my $ContentPath = $Self->ArticleGetContentPath(
        TicketID  => $TicketID,
        ArticleID => $Param{ArticleID}
    );
    my $Path = "$Self->{ArticleDataDir}/$ContentPath/$Param{ArticleID}";

    my $Success = $Kernel::OM->Get('Main')->FileDelete(
        Directory       => $Path,
        Filename        => $Attachment{Filename},
        Type            => 'Local',
        DisableWarnings => 1,
    );

    # update article attachment counter
    if ( $Attachment{Disposition} eq 'attachment' ) {
        $Kernel::OM->Get('DB')->Do(
            SQL => "UPDATE article SET attachment_count = attachment_count - 1 WHERE id = ?",
            Bind => [ \$Param{ArticleID} ],
        );
    }

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Ticket.Article.Attachment',
        ObjectID  => $TicketID.'::'.$Param{ArticleID},
    );

    $Self->EventHandler(
        Event => 'ArticleAttachmentDelete',
        Data  => {
            TicketID  => $TicketID,
            ArticleID => $Param{ArticleID},
        },
        UserID => $Param{UserID},
    );

    return 1;
}

sub ArticleWritePlain {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ArticleID Email UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    # prepare/filter ArticleID
    $Param{ArticleID} = quotemeta( $Param{ArticleID} );
    $Param{ArticleID} =~ s/\0//g;

    # define path
    my $ContentPath = $Self->ArticleGetContentPath(
        ArticleID => $Param{ArticleID}
    );
    my $Path = $Self->{ArticleDataDir} . '/' . $ContentPath . '/' . $Param{ArticleID};

    # debug
    if ( $Self->{Debug} > 1 ) {
        $Kernel::OM->Get('Log')->Log( Message => "->WriteArticle: $Path" );
    }

    # write article to fs 1:1
    File::Path::mkpath( [$Path], 0, 0770 );    ## no critic

    # write article to fs
    my $Success = $Kernel::OM->Get('Main')->FileWrite(
        Location   => "$Path/plain.txt",
        Mode       => 'binmode',
        Content    => \$Param{Email},
        Permission => '660',
    );

    return if !$Success;
    return 1;
}

sub ArticleWriteAttachment {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Filename ContentType ArticleID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # cleanup filename
    $Param{Filename} =~ s/ /_/g;
    $Param{Filename} =~ s/^\.//g;
    $Param{Filename} = $Kernel::OM->Get('Main')->FilenameCleanUp(
        Filename => $Param{Filename},
        Type     => 'Local',
    );

    # get attachment index of article
    my %Index = $Self->ArticleAttachmentIndex(
        ArticleID => $Param{ArticleID},
        UserID    => $Param{UserID},
    );

    # map already used filenames
    my %UsedFile;
    for my $Key ( keys( %Index ) ) {
        $UsedFile{ $Index{ $Key }->{Filename} } = 1;
    }

    # prepare unique filename for article
    my $Filename  = $Param{Filename};
    my $Extension = '';
    if ( $Param{Filename} =~ /^(.*)(\..+?)$/ ) {
        $Filename  = $1;
        $Extension = $2;
    }
    my $SuffixCounter = 0;
    while ( $UsedFile{ $Param{Filename} } ) {
        # increment counter
        $SuffixCounter += 1;

        # prevent endless loop
        if ( $SuffixCounter > 1000 ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to prepare unique filename for \"$Filename$Extension\" (ArticleID $Param{ArticleID})!",
            );
            return;
        }

        # prepare new filename
        $Param{Filename} = $Filename . '-' . $SuffixCounter . $Extension;
    }

    # get ticket id of article
    my $TicketID = $Self->ArticleGetTicketID(
        ArticleID => $Param{ArticleID}
    );

    my $Content = $Param{Content} || '';

    # get attachment size
    $Param{Filesize} = bytes::length( $Content );

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # set content id in angle brackets
    if ( $Param{ContentID} ) {
        $Param{ContentID} =~ s/^([^<].*[^>])$/<$1>/;
    }

    my $Disposition;
    my $FilenamePart;
    if ( $Param{Disposition} ) {
        ( $Disposition, $FilenamePart ) = split ';', $Param{Disposition};
    }
    $Disposition //= '';

    # write attachment to db
    return if !$DBObject->Do(
        SQL => '
            INSERT INTO article_attachment (article_id, filename, content_type, content_size,
                content_id, content_alternative, disposition, create_time, create_by,
                change_time, change_by)
            VALUES (?, ?, ?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{ArticleID}, \$Param{Filename}, \$Param{ContentType}, \$Param{Filesize},
            \$Param{ContentID}, \$Param{ContentAlternative}, \$Disposition,
            \$Param{UserID}, \$Param{UserID},
        ],
    );

    # write attachment content to fs
    my $ContentPath = $Self->ArticleGetContentPath(
        TicketID  => $TicketID,
        ArticleID => $Param{ArticleID}
    );
    my $Path = "$Self->{ArticleDataDir}/$ContentPath/$Param{ArticleID}";

    # write article to fs
    File::Path::mkpath( [$Path], 0, 0770 );    ## no critic

    my $Success = $Kernel::OM->Get('Main')->FileWrite(
        Directory  => $Path,
        Filename   => $Param{Filename},
        Mode       => 'binmode',
        Content    => \($Param{Content} || ''),
        Permission => 660,
    );
    if ( !$Success ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message =>
                "Unable to store article attachment \"$Param{Filename}\" (ArticleID $Param{ArticleID}) in $Path!",
        );
        return;
    }

    # update article attachment counter
    if ( $Disposition eq 'attachment' ) {
        $Kernel::OM->Get('DB')->Do(
            SQL => "UPDATE article SET attachment_count = attachment_count + 1 WHERE id = ?",
            Bind => [ \$Param{ArticleID} ],
        );
    }

    # update article data
    if ($Param{CountAsUpdate}) {
        $Kernel::OM->Get('DB')->Do(
            SQL => "UPDATE article SET change_time = current_timestamp, change_by = ? WHERE id = ?",
            Bind => [ \$Param{UserID}, \$Param{ArticleID} ],
        );
    }

    $Self->EventHandler(
        Event => 'ArticleAttachmentAdd',
        Data  => {
            TicketID  => $TicketID,
            ArticleID => $Param{ArticleID},
            FileName  => $Param{Filename}
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'Ticket.Article.Attachment',
        ObjectID  => $TicketID.'::'.$Param{ArticleID}.'::'.$Param{Filename},
    );

    $Self->EventHandler(
        Event => 'ArticleAttachmentDelete',
        Data  => {
            TicketID  => $TicketID,
            ArticleID => $Param{ArticleID},
            Filename  => $Param{Filename},
        },
        UserID => $Param{UserID},
    );


    return 1;
}

sub ArticlePlain {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ArticleID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need ArticleID!',
        );
        return;
    }

    # prepare/filter ArticleID
    $Param{ArticleID} = quotemeta( $Param{ArticleID} );
    $Param{ArticleID} =~ s/\0//g;

    # get content path
    my $ContentPath = $Self->ArticleGetContentPath( ArticleID => $Param{ArticleID} );

    # open plain article
    if ( -f "$Self->{ArticleDataDir}/$ContentPath/$Param{ArticleID}/plain.txt" ) {

        # read whole article
        my $Data = $Kernel::OM->Get('Main')->FileRead(
            Directory => "$Self->{ArticleDataDir}/$ContentPath/$Param{ArticleID}/",
            Filename  => 'plain.txt',
            Mode      => 'binmode',
        );
        return if !$Data;

        return ${$Data};
    }

    return;
}

sub ArticleAttachmentIndexRaw {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ArticleID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need ArticleID!'
        );
        return;
    }

    # make sure the attachment metadata is in the DB
    $Self->_CheckAndSwitchArticleAttachmentMeta(ArticleID => $Param{ArticleID});

    my %Index;

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # try database
    return if !$DBObject->Prepare(
        SQL => '
            SELECT id, filename, content_type, content_size, content_id, content_alternative, disposition
            FROM article_attachment
            WHERE article_id = ?
            ORDER BY filename, id',
        Bind => [ \$Param{ArticleID} ],
    );

    while ( my @Row = $DBObject->FetchrowArray() ) {

        # human readable file size
        my $FileSizeRaw = $Row[3] || 0;
        if ( $Row[3] > ( 1024 * 1024 ) ) {
            $Row[3] = sprintf "%.1f MBytes", ( $Row[3] / ( 1024 * 1024 ) );
        }
        elsif ( $Row[3] > 1024 ) {
            $Row[3] = sprintf "%.1f KBytes", ( ( $Row[3] / 1024 ) );
        }
        else {
            $Row[3] = $Row[3] . ' Bytes';
        }

        my $Disposition = $Row[6];
        if ( !$Disposition ) {

            # if no content disposition is set images with content id should be inline
            if ( $Row[4] && $Row[2] =~ m{image}i ) {
                $Disposition = 'inline';
            }

            # converted article body should be inline
            elsif ( $Row[1] =~ m{file-[12]} ) {
                $Disposition = 'inline'
            }

            # all others including attachments with content id that are not images
            #   should NOT be inline
            else {
                $Disposition = 'attachment';
            }
        }

        # add the info the the hash
        $Index{$Row[0]} = {
            ID                 => $Row[0],
            Filename           => $Row[1],
            ContentType        => $Row[2],
            Filesize           => $Row[3] || '',
            FilesizeRaw        => 0 + $FileSizeRaw || 0,
            ContentID          => $Row[4] || '',
            ContentAlternative => $Row[5] || '',
            Disposition        => $Disposition,
        };
    }

    return %Index;
}

sub ArticleAttachment {
    my ( $Self, %Param ) = @_;

    # check ArticleDataDir
    if ( !$Self->{ArticleDataDir} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need ArticleDataDir!'
        );
        return;
    }

    # fallback
    if ( !$Param{AttachmentID} ) {
        $Param{AttachmentID} = $Param{FileID};
        print STDERR "ArticleAttachment: obsolete parameter FileID instead of AttachmentID given!\n";
        cluck();
    }

    # check needed stuff
    for (qw(ArticleID AttachmentID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # make sure the attachment metadata is in the DB
    $Self->_CheckAndSwitchArticleAttachmentMeta(ArticleID => $Param{ArticleID});

    # prepare/filter ArticleID
    $Param{ArticleID} = quotemeta( $Param{ArticleID} );
    $Param{ArticleID} =~ s/\0//g;

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # try database
    return if !$DBObject->Prepare(
        SQL => '
            SELECT id, filename, content_type, content_size, content_id, content_alternative, disposition
            FROM article_attachment
            WHERE id = ?',
        Bind => [ \$Param{AttachmentID} ],
    );

    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {

        # human readable file size
        my $FileSizeRaw = $Row[3] || 0;
        if ( $Row[3] > ( 1024 * 1024 ) ) {
            $Row[3] = sprintf "%.1f MBytes", ( $Row[3] / ( 1024 * 1024 ) );
        }
        elsif ( $Row[3] > 1024 ) {
            $Row[3] = sprintf "%.1f KBytes", ( ( $Row[3] / 1024 ) );
        }
        else {
            $Row[3] = $Row[3] . ' Bytes';
        }

        my $Disposition = $Row[6];
        if ( !$Disposition ) {

            # if no content disposition is set images with content id should be inline
            if ( $Row[4] && $Row[2] =~ m{image}i ) {
                $Disposition = 'inline';
            }

            # converted article body should be inline
            elsif ( $Row[1] =~ m{file-[12]} ) {
                $Disposition = 'inline'
            }

            # all others including attachments with content id that are not images
            #   should NOT be inline
            else {
                $Disposition = 'attachment';
            }
        }

        # add the info the the hash
        %Data = (
            ID                 => $Row[0],
            Filename           => $Row[1],
            ContentType        => $Row[2],
            Filesize           => $Row[3] || '',
            FilesizeRaw        => 0 + $FileSizeRaw || 0,
            ContentID          => $Row[4] || '',
            ContentAlternative => $Row[5] || '',
            Disposition        => $Disposition,
        );
    }

    return %Data if ( $Param{NoContent} );

    # load content from FS
    my $ContentPath = $Self->ArticleGetContentPath( ArticleID => $Param{ArticleID} );
    my $Path = "$Self->{ArticleDataDir}/$ContentPath/$Param{ArticleID}";

    my $Content = $Kernel::OM->Get('Main')->FileRead(
        Directory => $Path,
        Filename  => $Data{Filename},
        Mode      => 'binmode',
        Silent    => 1,
    );
    return if !$Content;

    $Data{Content} = $$Content;

    if (
        $Data{ContentType} =~ /plain\/text/i
        && $Data{ContentType} =~ /(utf\-8|utf8)/i
        )
    {
        $Kernel::OM->Get('Encode')->EncodeInput( \$Data{Content} );
    }

    if ( !$Data{Content} && $Data{Content} ne '') {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message =>
                "No article attachment \"$Data{Filename}\" (article id $Param{ArticleID}) in $Path!",
        );
        return;
    }

    return %Data;
}

=item ArticleStorageSwitch()

migrate article attachments metadata from FS to DB. Leave attachment content in FS. Only look at unmigrated articles (prop "article_count" is undef)

    my $Success = $TicketObject->ArticleStorageSwitch(
        ForcePID => 1           # optional
    );

=cut

sub ArticleStorageSwitch {
    my ( $Self, %Param ) = @_;

    my $PIDCreated = $Kernel::OM->Get('PID')->PIDCreate(
        Name  => 'ArticleStorageSwitch',
        Force => $Param{ForcePID},
        TTL   => 60 * 60 * 24 * 3,
    );
    return -1 if !$PIDCreated;

    my $Success = $Self->AsyncCall(
        ObjectName               => $Kernel::OM->GetModuleFor('Ticket'),
        FunctionName             => '_ArticleStorageSwitchAsyncWorker',
        FunctionParams           => {},
        MaximumParallelInstances => 1,
    );

    return $Success;
}

sub _ArticleStorageSwitchAsyncWorker {
    my ( $Self, %Param ) = @_;

    # get articles with undefined article count (latest ones at first)
    my $Success = $Kernel::OM->Get('DB')->Prepare(
        SQL => 'SELECT id FROM article WHERE attachment_count IS NULL ORDER BY id DESC'
    );
    if ( !$Success ) {
        return $Kernel::OM->Get('PID')->PIDDelete( Name => 'ArticleStorageSwitch' );
    }

    my $ArticleIndex = $Kernel::OM->Get('DB')->FetchAllArrayRef(
        Columns => [ 'ID' ]
    );
    my $TotalCount = @{$ArticleIndex||[]};

    $Kernel::OM->Get('Log')->Log(
        Priority => 'info',
        Message  => "ArticleStorageSwitch: found $TotalCount articles to migrate"
    );

    if ( $TotalCount ) {
        my $Count = 0;
        ARTICLE:
        for my $ArticleIndexRef (@{$ArticleIndex||[]}) {
            # check if the article has already been migrated in the meantime
            my $Success = $Kernel::OM->Get('DB')->Prepare(
                SQL  => 'SELECT attachment_count FROM article WHERE id = ?',
                Bind => $ArticleIndexRef->{ID}
            );
            my $AttachmentCount;
            while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
                $AttachmentCount = $Row[0];
            }

            if ( !defined $AttachmentCount ) {
                # do the migration
                $Self->_ArticleStorageSwitch(
                    ArticleID => $ArticleIndexRef->{ID}
                );
            }

            $Count++;
            if ( $Count % 1000 == 0 ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'info',
                    Message  => "ArticleStorageSwitch: migrated $Count/$TotalCount articles"
                );
            }
        }

        if ( $Count % 1000 != 0 ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'info',
                Message  => "ArticleStorageSwitch: migrated $Count/$TotalCount articles"
            );
        }
    }

    return $Kernel::OM->Get('PID')->PIDDelete( Name => 'ArticleStorageSwitch' );
}

sub _ArticleStorageSwitch {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ArticleID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my %Metadata;

    my $ContentPath = $Self->ArticleGetContentPath( ArticleID => $Param{ArticleID} );

    my $Path = "$Self->{ArticleDataDir}/$ContentPath/$Param{ArticleID}";

    # get attachment files
    my @List = $Kernel::OM->Get('Main')->DirectoryRead(
        Directory => $Path,
        Filter    => "*",
        Silent    => 1,
    );

    FILE:
    for my $File ( sort @List ) {
        # use only metadata files
        next FILE if $File =~ /\/plain.txt$/;
        next FILE if $File !~ /(.*?)\.(content_alternative|content_id|content_type|disposition)$/;

        my $AttachmentFile = $1;
        my $Filename       = basename($1);
        my $MetaProperty   = $2;

        # read control file
        my $Content = $Kernel::OM->Get('Main')->FileRead(
            Location => $File,
        );
        if ( !$Content ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to read metadata file $File!"
            );
            next FILENAME;
        }

        $Metadata{$Filename} //= { map { $_ => undef } qw(content_alternative content_id content_type disposition) };
        $Metadata{$Filename}->{$MetaProperty} = ${$Content};

        if ( !exists $Metadata{$Filename}->{content_size} ) {
            $Metadata{$Filename}->{content_size} = -s $AttachmentFile || 0;
        }
        if ( !exists $Metadata{$Filename}->{create_time} ) {
            $Metadata{$Filename}->{create_time} = $Kernel::OM->Get('Time')->SystemTime2TimeStamp(
                SystemTime => (stat $AttachmentFile)[9]
            )
        }
    }

    my $AttachmentCount = 0;
    foreach my $Filename ( sort keys %Metadata ) {

        # store attachment metadata in DB
        next if !$Kernel::OM->Get('DB')->Do(
            SQL => '
                INSERT INTO article_attachment (article_id, filename, content_type, content_size,
                    content_id, content_alternative, disposition, create_time, create_by,
                    change_time, change_by)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, 1)',
            Bind => [
                \$Param{ArticleID}, \$Filename, \$Metadata{$Filename}->{content_type}, \$Metadata{$Filename}->{content_size},
                \$Metadata{$Filename}->{content_id}, \$Metadata{$Filename}->{content_alternative},
                \$Metadata{$Filename}->{disposition}, \$Metadata{$Filename}->{create_time},
                \$Metadata{$Filename}->{create_time},
            ],
        );

        $AttachmentCount++ if ( $Metadata{$Filename}->{disposition} && $Metadata{$Filename}->{disposition} eq 'attachment' );
    }

    # update attachment count on article
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE article SET attachment_count = ? WHERE id = ?',
        Bind => [
            \$AttachmentCount, \$Param{ArticleID},
        ],
    );

    $Self->{AttachmentCount}->{$Param{ArticleID}} = $AttachmentCount;

    return 1;
}

sub _ArticleDeleteDirectory {
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

    # delete directory from fs
    my $ContentPath = $Self->ArticleGetContentPath( ArticleID => $Param{ArticleID} );
    my $Path = "$Self->{ArticleDataDir}/$ContentPath/$Param{ArticleID}";
    if ( -d $Path ) {
        if ( !rmdir $Path ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Can't remove: $Path: $!!",
            );
            return;
        }
    }
    return 1;
}

sub _CheckAndSwitchArticleAttachmentMeta {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ArticleID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    return if defined $Self->{AttachmentCount}->{$Param{ArticleID}};

    # check if article attachments are still in FS
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL => 'SELECT attachment_count FROM article WHERE id = ?',
        Bind   => [ \$Param{ArticleID} ],
    );

    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        $Self->{AttachmentCount}->{$Param{ArticleID}} = $Row[0];
    }

    if ( !defined $Self->{AttachmentCount}->{$Param{ArticleID}} ) {
        # switch metadata storage from FS to DB
        $Self->_ArticleStorageSwitch(ArticleID => $Param{ArticleID});
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
