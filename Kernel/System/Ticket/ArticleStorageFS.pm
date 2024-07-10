# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::ArticleStorageFS;

use strict;
use warnings;

use File::Path qw();
use MIME::Base64 qw();
use Time::HiRes qw();
use Unicode::Normalize qw();

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

    # Check fs write permissions.
    # Generate a thread-safe article check directory.
    my ( $Seconds, $Microseconds ) = Time::HiRes::gettimeofday();
    my $PermissionCheckDirectory
        = "check_permissions_${$}_" . ( int rand 1_000_000_000 ) . "_${Seconds}_${Microseconds}";
    my $Path = "$Self->{ArticleDataDir}/$Self->{ArticleContentPath}/" . $PermissionCheckDirectory;
    if ( File::Path::mkpath( $Path, 0, 0770 ) ) {    ## no critic
        rmdir $Path;
    }
    else {
        my $Error = $!;
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "Can't create $Path: $Error!",
        );
        die "Can't create $Path: $Error!";
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    # get activated cache backend configuration
    my $CacheModule = $ConfigObject->Get('Cache::Module') || '';

    return 1 if !$ConfigObject->Get('Cache::ArticleStorageCache');

    $Self->{ArticleStorageCache} = 1;
    $Self->{ArticleStorageCacheTTL} = $ConfigObject->Get('Cache::ArticleStorageCache::TTL') || 60 * 60 * 24;

    return 1;
}

sub ArticleDelete {
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
    $Self->ArticleDeleteAttachment(
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

    $Self->_TicketCacheClear( TicketID => $Article{TicketID} );

    # delete cache
    if ( $Self->{ArticleStorageCache} ) {

        $Kernel::OM->Get('Cache')->CleanUp(
            Type => 'ArticleStorageFS_' . $Param{ArticleID},
        );
    }

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

    # get Article
    my %Article = $Self->ArticleGet(
        ArticleID => $Param{ArticleID}
    );

    # delete from fs
    my $ContentPath = $Self->ArticleGetContentPath(
        TicketID  => $Article{TicketID},
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

    # delete cache
    if ( $Self->{ArticleStorageCache} ) {

        $Kernel::OM->Get('Cache')->Delete(
            Type => 'ArticleStorageFS_' . $Param{ArticleID},
            Key  => 'ArticlePlain',
        );
    }

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Ticket.Article.Plain',
        ObjectID  => $Article{TicketID}.'::'.$Param{ArticleID},
    );

    # return if only delete in my backend
    return 1 if $Param{OnlyMyBackend};

    # delete plain from db
    return if !$Kernel::OM->Get('DB')->Do(
        SQL  => 'DELETE FROM article_plain WHERE article_id = ?',
        Bind => [ \$Param{ArticleID} ],
    );

    return 1;
}

sub ArticleDeleteAttachment {
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

    # get Article
    my %Article = $Self->ArticleGet(
        ArticleID => $Param{ArticleID}
    );

    # delete from fs
    my $ContentPath = $Self->ArticleGetContentPath(
        TicketID  => $Article{TicketID},
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

                if ( !unlink "$File" ) {

                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => "Can't remove: $File: $!!",
                    );
                }
            }
        }
    }

    # delete cache
    if ( $Self->{ArticleStorageCache} ) {

        $Kernel::OM->Get('Cache')->CleanUp(
            Type => 'ArticleStorageFS_' . $Param{ArticleID},
        );
    }

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Ticket.Article.Attachment',
        ObjectID  => $Article{TicketID}.'::'.$Param{ArticleID},
    );

    # return if only delete in my backend
    return 1 if $Param{OnlyMyBackend};

    # delete attachments from db
    return if !$Kernel::OM->Get('DB')->Do(
        SQL  => 'DELETE FROM article_attachment WHERE article_id = ?',
        Bind => [ \$Param{ArticleID} ],
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
    my $ContentPath = $Self->ArticleGetContentPath( ArticleID => $Param{ArticleID} );
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

    # set cache
    if ( $Self->{ArticleStorageCache} ) {

        $Kernel::OM->Get('Cache')->Set(
            Type           => 'ArticleStorageFS_' . $Param{ArticleID},
            TTL            => $Self->{ArticleStorageCacheTTL},
            Key            => 'ArticlePlain',
            Value          => $Param{Email},
            CacheInMemory  => 0,
            CacheInBackend => 1,
        );
    }

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
                Message  => "Need $_!",
            );
            return;
        }
    }

    # get Article
    my %Article = $Self->ArticleGet(
        ArticleID => $Param{ArticleID}
    );

    # prepare/filter ArticleID
    $Param{ArticleID} = quotemeta( $Param{ArticleID} );
    $Param{ArticleID} =~ s/\0//g;
    my $ContentPath = $Self->ArticleGetContentPath(
        TicketID  => $Article{TicketID},
        ArticleID => $Param{ArticleID}
    );

    # define path
    $Param{Path} = $Self->{ArticleDataDir} . '/' . $ContentPath . '/' . $Param{ArticleID};

    # strip spaces from filenames
    $Param{Filename} =~ s/ /_/g;

    # strip dots from filenames
    $Param{Filename} =~ s/^\.//g;

    # get main object
    my $MainObject = $Kernel::OM->Get('Main');

    # Perform FilenameCleanup here already to check for
    #   conflicting existing attachment files correctly
    $Param{Filename} = $MainObject->FilenameCleanUp(
        Filename => $Param{Filename},
        Type     => 'Local',
    );

    my $NewFileName = $Param{Filename};
    my %UsedFile;
    my %Index = $Self->ArticleAttachmentIndex(
        ArticleID => $Param{ArticleID},
        UserID    => $Param{UserID},
    );

    # Normalize filenames to find file names which are identical but in a different unicode form.
    #   This is needed because Mac OS (HFS+) converts all filenames to NFD internally.
    #   Without this, the same file might be overwritten because the strings are not equal.
    for ( sort keys %Index ) {
        $UsedFile{ Unicode::Normalize::NFC( $Index{$_}->{Filename} ) } = 1;
    }
    for ( my $i = 1; $i <= 50; $i++ ) {
        if ( exists $UsedFile{ Unicode::Normalize::NFC($NewFileName) } ) {
            if ( $Param{Filename} =~ /^(.*)\.(.+?)$/ ) {
                $NewFileName = "$1-$i.$2";
            }
            else {
                $NewFileName = "$Param{Filename}-$i";
            }
        }
    }

    $Param{Filename} = $NewFileName;

    # write attachment to backend
    if ( !-d $Param{Path} ) {
        if ( !File::Path::mkpath( [ $Param{Path} ], 0, 0770 ) ) {    ## no critic
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Can't create $Param{Path}: $!",
            );
            return;
        }
    }

    # write attachment content type to fs
    my $SuccessContentType = $MainObject->FileWrite(
        Directory  => $Param{Path},
        Filename   => "$Param{Filename}.content_type",
        Mode       => 'binmode',
        Content    => \$Param{ContentType},
        Permission => 660,
    );
    return if !$SuccessContentType;

    # set content id in angle brackets
    if ( $Param{ContentID} ) {
        $Param{ContentID} =~ s/^([^<].*[^>])$/<$1>/;
    }

    # write attachment content id to fs
    if ( $Param{ContentID} ) {
        $MainObject->FileWrite(
            Directory  => $Param{Path},
            Filename   => "$Param{Filename}.content_id",
            Mode       => 'binmode',
            Content    => \$Param{ContentID},
            Permission => 660,
        );
    }

    # write attachment content alternative to fs
    if ( $Param{ContentAlternative} ) {
        $MainObject->FileWrite(
            Directory  => $Param{Path},
            Filename   => "$Param{Filename}.content_alternative",
            Mode       => 'binmode',
            Content    => \$Param{ContentAlternative},
            Permission => 660,
        );
    }

    # write attachment disposition to fs
    if ( $Param{Disposition} ) {

        my ( $Disposition, $FileName ) = split ';', $Param{Disposition};

        $MainObject->FileWrite(
            Directory  => $Param{Path},
            Filename   => "$Param{Filename}.disposition",
            Mode       => 'binmode',
            Content    => \$Disposition || '',
            Permission => 660,
        );
    }

    # write attachment content to fs
    my $SuccessContent = $MainObject->FileWrite(
        Directory  => $Param{Path},
        Filename   => $Param{Filename},
        Mode       => 'binmode',
        Content    => \($Param{Content} || ''),
        Permission => 660,
    );

    # update article data
    if ($Param{CountAsUpdate}) {
        $Kernel::OM->Get('DB')->Do(
            SQL => "UPDATE article SET change_time = current_timestamp, change_by = ? WHERE id = ?",
            Bind => [ \$Param{UserID}, \$Param{ArticleID} ],
        );
    }

    return if !$SuccessContent;

    # delete cache
    if ( $Self->{ArticleStorageCache} ) {

        $Kernel::OM->Get('Cache')->CleanUp(
            Type => 'ArticleStorageFS_' . $Param{ArticleID},
        );
    }

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'Ticket.Article.Attachment',
        ObjectID  => $Article{TicketID}.'::'.$Param{ArticleID}.'::'.$Param{Filename},
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

    # get cache object
    my $CacheObject = $Kernel::OM->Get('Cache');

    # read cache
    if ( $Self->{ArticleStorageCache} ) {

        my $Cache = $CacheObject->Get(
            Type           => 'ArticleStorageFS_' . $Param{ArticleID},
            Key            => 'ArticlePlain',
            CacheInMemory  => 0,
            CacheInBackend => 1,
        );

        return $Cache if $Cache;
    }

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

        # set cache
        if ( $Self->{ArticleStorageCache} ) {

            $CacheObject->Set(
                Type           => 'ArticleStorageFS_' . $Param{ArticleID},
                TTL            => $Self->{ArticleStorageCacheTTL},
                Key            => 'ArticlePlain',
                Value          => ${$Data},
                CacheInMemory  => 0,
                CacheInBackend => 1,
            );
        }

        return ${$Data};
    }

    # return if we only need to check one backend
    return if !$Self->{CheckAllBackends};

    # return if only delete in my backend
    return if $Param{OnlyMyBackend};

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # can't open article, try database
    return if !$DBObject->Prepare(
        SQL  => 'SELECT body FROM article_plain WHERE article_id = ?',
        Bind => [ \$Param{ArticleID} ],
    );

    my $Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data = $Row[0];
    }

    if ( !$Data ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message =>
                    "Can't open $Self->{ArticleDataDir}/$ContentPath/$Param{ArticleID}/plain.txt: $!",
            );
        }
        return;
    }

    # set cache
    if ( $Self->{ArticleStorageCache} ) {

        $CacheObject->Set(
            Type           => 'ArticleStorageFS_' . $Param{ArticleID},
            TTL            => $Self->{ArticleStorageCacheTTL},
            Key            => 'ArticlePlain',
            Value          => $Data,
            CacheInMemory  => 0,
            CacheInBackend => 1,
        );
    }

    return $Data;
}

sub ArticleAttachmentIndexRaw {
    my ( $Self, %Param ) = @_;

    # check ArticleContentPath
    if ( !$Self->{ArticleContentPath} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need ArticleContentPath!',
        );
        return;
    }

    # check needed stuff
    if ( !$Param{ArticleID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need ArticleID!',
        );
        return;
    }

    # get cache object
    my $CacheObject = $Kernel::OM->Get('Cache');

    # read cache
    if ( $Self->{ArticleStorageCache} ) {

        my $Cache = $CacheObject->Get(
            Type           => 'ArticleStorageFS_' . $Param{ArticleID},
            Key            => 'ArticleAttachmentIndexRaw',
            CacheInMemory  => 0,
            CacheInBackend => 1,
        );

        return %{$Cache} if $Cache;
    }

    my $ContentPath = $Self->ArticleGetContentPath( ArticleID => $Param{ArticleID} );
    my %Index;
    my $Counter = 0;

    # get main object
    my $MainObject = $Kernel::OM->Get('Main');

    # try fs
    my @List = $MainObject->DirectoryRead(
        Directory => "$Self->{ArticleDataDir}/$ContentPath/$Param{ArticleID}",
        Filter    => "*",
        Silent    => 1,
    );

    FILENAME:
    for my $Filename ( sort @List ) {
        # do not use control file
        next FILENAME if $Filename =~ /\.content_alternative$/;
        next FILENAME if $Filename =~ /\.content_id$/;
        next FILENAME if $Filename =~ /\.content_type$/;
        next FILENAME if $Filename =~ /\.disposition$/;
        next FILENAME if $Filename =~ /\/plain.txt$/;

        # human readable file size
        my $FileSize    = -s $Filename || 0;
        my $FileSizeRaw = $FileSize;

        if ( $FileSize > ( 1024 * 1024 ) ) {
            $FileSize = sprintf "%.1f MBytes", ( $FileSize / ( 1024 * 1024 ) );
        }
        elsif ( $FileSize > 1024 ) {
            $FileSize = sprintf "%.1f KBytes", ( ( $FileSize / 1024 ) );
        }
        else {
            $FileSize = $FileSize . ' Bytes';
        }

        # read content type
        my $ContentType = '';
        my $ContentID   = '';
        my $Alternative = '';
        my $Disposition = '';
        if ( -e "$Filename.content_type" ) {
            my $Content = $MainObject->FileRead(
                Location => "$Filename.content_type",
            );
            return if !$Content;
            $ContentType = ${$Content};

            # content id (optional)
            if ( -e "$Filename.content_id" ) {
                my $Content = $MainObject->FileRead(
                    Location => "$Filename.content_id",
                );
                if ($Content) {
                    $ContentID = ${$Content};
                }
            }

            # alternative (optional)
            if ( -e "$Filename.content_alternative" ) {
                my $Content = $MainObject->FileRead(
                    Location => "$Filename.content_alternative",
                );
                if ($Content) {
                    $Alternative = ${$Content};
                }
            }

            # disposition
            if ( -e "$Filename.disposition" ) {
                my $Content = $MainObject->FileRead(
                    Location => "$Filename.disposition",
                );
                if ($Content) {
                    $Disposition = ${$Content};
                }
            }

            # if no content disposition is set images with content id should be inline
            elsif ( $ContentID && $ContentType =~ m{image}i ) {
                $Disposition = 'inline';
            }

            # converted article body should be inline
            elsif ( $Filename =~ m{file-[12]} ) {
                $Disposition = 'inline'
            }

            # all others including attachments with content id that are not images
            #   should NOT be inline
            else {
                $Disposition = 'attachment';
            }
        }

        # read content type (old style)
        else {
            my $Content = $MainObject->FileRead(
                Location => $Filename,
                Result   => 'ARRAY',
            );
            if ( !$Content ) {
                return;
            }
            $ContentType = $Content->[0];
        }

        # strip filename
        $Filename =~ s!^.*/!!;

        # add the info the the hash
        $Counter++;
        $Index{$Counter} = {
            Filename           => $Filename,
            Filesize           => $FileSize,
            FilesizeRaw        => 0 + $FileSizeRaw,
            ContentType        => $ContentType,
            ContentID          => $ContentID,
            ContentAlternative => $Alternative,
            Disposition        => $Disposition,
        };
    }

    # set cache
    if ( $Self->{ArticleStorageCache} ) {

        $CacheObject->Set(
            Type           => 'ArticleStorageFS_' . $Param{ArticleID},
            TTL            => $Self->{ArticleStorageCacheTTL},
            Key            => 'ArticleAttachmentIndexRaw',
            Value          => \%Index,
            CacheInMemory  => 0,
            CacheInBackend => 1,
        );
    }

    return %Index if %Index;

    # return if we only need to check one backend
    return if !$Self->{CheckAllBackends};

    # return if only delete in my backend
    return %Index if $Param{OnlyMyBackend};

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # try database (if there is no index in fs)
    return if !$DBObject->Prepare(
        SQL => '
            SELECT filename, content_type, content_size, content_id, content_alternative,
                disposition
            FROM article_attachment
            WHERE article_id = ?
            ORDER BY filename, id',
        Bind => [ \$Param{ArticleID} ],
    );

    while ( my @Row = $DBObject->FetchrowArray() ) {

        # human readable file size
        my $FileSizeRaw = $Row[2] || 0;
        if ( $Row[2] > ( 1024 * 1024 ) ) {
            $Row[2] = sprintf "%.1f MBytes", ( $Row[2] / ( 1024 * 1024 ) );
        }
        elsif ( $Row[2] > 1024 ) {
            $Row[2] = sprintf "%.1f KBytes", ( ( $Row[2] / 1024 ) );
        }
        else {
            $Row[2] = $Row[2] . ' Bytes';
        }

        my $Disposition = $Row[5];
        if ( !$Disposition ) {

            # if no content disposition is set images with content id should be inline
            if ( $Row[3] && $Row[1] =~ m{image}i ) {
                $Disposition = 'inline';
            }

            # converted article body should be inline
            elsif ( $Row[0] =~ m{file-[12]} ) {
                $Disposition = 'inline';
            }

            # all others including attachments with content id that are not images
            #   should NOT be inline
            else {
                $Disposition = 'attachment';
            }
        }

        # add the info the the hash
        $Counter++;
        $Index{$Counter} = {
            Filename           => $Row[0],
            Filesize           => $Row[2] || '',
            FilesizeRaw        => 0 + $FileSizeRaw || 0,
            ContentType        => $Row[1],
            ContentID          => $Row[3] || '',
            ContentAlternative => $Row[4] || '',
            Disposition        => $Disposition,
        };
    }

    # set cache
    if ( $Self->{ArticleStorageCache} ) {

        $CacheObject->Set(
            Type           => 'ArticleStorageFS_' . $Param{ArticleID},
            TTL            => $Self->{ArticleStorageCacheTTL},
            Key            => 'ArticleAttachmentIndexRaw',
            Value          => \%Index,
            CacheInMemory  => 0,
            CacheInBackend => 1,
        );
    }

    return %Index;
}

sub ArticleAttachment {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ArticleID FileID UserID)) {
        if ( !$Param{ $Needed } ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    # prepare/filter ArticleID
    $Param{ArticleID} = quotemeta( $Param{ArticleID} );
    $Param{ArticleID} =~ s/\0//g;

    # get content path
    my $ContentPath = $Self->ArticleGetContentPath( ArticleID => $Param{ArticleID} );

    # init data variable
    my %Data = ();

    # get file list from directory
    my @FileList = $Kernel::OM->Get('Main')->DirectoryRead(
        Directory => "$Self->{ArticleDataDir}/$ContentPath/$Param{ArticleID}",
        Filter    => "*",
        Silent    => 1,
    );

    # check if directory has file entries
    if ( @FileList ) {

        # init counter, used as FileID
        my $FileID = 0;

        # process file list
        FILENAME:
        for my $Filename ( @FileList ) {
            # skip meta data files
            next FILENAME if (
                $Filename =~ /\.content_alternative$/
                || $Filename =~ /\.content_id$/
                || $Filename =~ /\.content_type$/
                || $Filename =~ /\/plain.txt$/
                || $Filename =~ /\.disposition$/
            );

            # increment counter
            $FileID += 1;

            # check for relevant file
            if ( $FileID == $Param{FileID} ) {

                # prepare general meta data
                if ( !$Param{NoMeta} ) {
                    # get filename and strip path
                    $Data{Filename} = $Filename;
                    $Data{Filename} =~ s!^.*/!!;

                    # human readable file size
                    my $FileSize    = -s $Filename || 0;
                    if ( $FileSize > ( 1024 * 1024 ) ) {
                        $Data{FileSize} = sprintf "%.1f MBytes", ( $FileSize / ( 1024 * 1024 ) );
                    }
                    elsif ( $FileSize > 1024 ) {
                        $Data{FileSize} = sprintf "%.1f KBytes", ( ( $FileSize / 1024 ) );
                    }
                    else {
                        $Data{FileSize} = $FileSize . ' Bytes';
                    }
                    $Data{FileSizeRaw} = $FileSize;
                }

                # check if meta file '.content_type' is avaiable
                if ( -e "$Filename.content_type" ) {

                    # check if content is requested
                    # always get content-type for encoding together with content
                    if ( !$Param{NoContent} ) {
                        # read content
                        my $Content1 = $Kernel::OM->Get('Main')->FileRead(
                            Location => $Filename,
                            Mode     => 'binmode',
                        );
                        return if !$Content1;
                        $Data{Content} = ${ $Content1 };

                        # read content-type
                        my $Content2 = $Kernel::OM->Get('Main')->FileRead(
                            Location => "$Filename.content_type",
                        );
                        return if !$Content2;
                        $Data{ContentType} = ${ $Content2 };
                    }

                    # check if meta data is requested
                    if ( !$Param{NoMeta} ) {
                        # check if content-type is already set
                        if ( !$Data{ContentType} ) {
                            # read content type
                            my $Content = $Kernel::OM->Get('Main')->FileRead(
                                Location => "$Filename.content_type",
                            );
                            return if !$Content;
                            $Data{ContentType} = ${ $Content };
                        }

                        # init mapping for optional meta data
                        my %MetaMap = (
                            ContentID          => 'content_id',
                            ContentAlternative => 'content_alternative',
                            Disposition        => 'disposition',
                        );

                        # process optional meta data
                        for my $MetaAttribute ( keys( %MetaMap ) ) {
                            # prepare file name
                            my $MetaFilename = $Filename . '.' . $MetaMap{ $MetaAttribute };

                            # init attribute with empty value
                            $Data{ $MetaAttribute } = '';

                            # check meta file existance
                            if ( -e $MetaFilename ) {
                                # read meta file content
                                my $Content = $Kernel::OM->Get('Main')->FileRead(
                                    Location => $MetaFilename,
                                );

                                # set attribut if meta file has content
                                if ($Content) {
                                    $Data{ $MetaAttribute } = ${ $Content };
                                }
                            }
                        }

                        # if no content disposition is set
                        if ( !$Data{Disposition} ) {
                            # images with content id should be inline
                            if (
                                $Data{ContentID}
                                && $Data{ContentType} =~ m{image}i
                            ) {
                                $Data{Disposition} = 'inline';
                            }

                            # converted article body should be inline
                            elsif ( $Filename =~ m{file-[12]} ) {
                                $Data{Disposition} = 'inline'
                            }

                            # all others including attachments with content id that are not images
                            #   should NOT be inline
                            else {
                                $Data{Disposition} = 'attachment';
                            }
                        }
                    }
                }
                # no meta file '.content_type' is avaiable
                # get content if requested
                elsif ( !$Param{NoContent} ) {
                    # read content
                    my $Content = $Kernel::OM->Get('Main')->FileRead(
                        Location => $Filename,
                        Mode     => 'binmode',
                        Result   => 'ARRAY',
                    );
                    return if !$Content;

                    # get content-type from first line of file
                    $Data{ContentType} = $Content->[0];
                    my $Counter = 0;
                    for my $Line ( @{$Content} ) {
                        if ($Counter) {
                            $Data{Content} .= $Line;
                        }
                        $Counter++;
                    }
                }

                # remove new line character from end of content-type
                if ( $Data{ContentType} ) {
                    chomp( $Data{ContentType} );
                }

                # encode plain text
                if (
                    !$Param{NoContent}
                    && $Data{ContentType} =~ /plain\/text/i
                    && $Data{ContentType} =~ /(?:utf\-8|utf8)/i
                ) {
                    $Kernel::OM->Get('Encode')->EncodeInput( \$Data{Content} );
                }

                return %Data;
            }
        }
    }

    # return if we only need to check one backend
    return if !$Self->{CheckAllBackends};

    # return if only delete in my backend
    return if $Param{OnlyMyBackend};

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # try database, if no content is found
    return if !$DBObject->Prepare(
        SQL => '
            SELECT id
            FROM article_attachment
            WHERE article_id = ?
            ORDER BY filename, id',
        Bind  => [ \$Param{ArticleID} ],
        Limit => $Param{FileID},
    );

    my $AttachmentID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $AttachmentID = $Row[0];
    }

    return if !$DBObject->Prepare(
        SQL => '
            SELECT content_type, content, content_id, content_alternative, disposition, filename
            FROM article_attachment
            WHERE id = ?',
        Bind   => [ \$AttachmentID ],
        Encode => [ 1, 0, 0, 0, 1, 1 ],
    );
    while ( my @Row = $DBObject->FetchrowArray() ) {

        $Data{ContentType} = $Row[0];

        # decode attachment if it's e. g. a postgresql backend!!!
        if ( !$DBObject->GetDatabaseFunction('DirectBlob') ) {
            $Data{Content} = MIME::Base64::decode_base64( $Row[1] );
        }
        else {
            $Data{Content} = $Row[1];
        }
        $Data{ContentID}          = $Row[2] || '';
        $Data{ContentAlternative} = $Row[3] || '';
        $Data{Disposition}        = $Row[4];
        $Data{Filename}           = $Row[5];
    }

    if ( !$Data{Disposition} ) {

        # if no content disposition is set images with content id should be inline
        if ( $Data{ContentID} && $Data{ContentType} =~ m{image}i ) {
            $Data{Disposition} = 'inline';
        }

        # converted article body should be inline
        elsif ( $Data{Filename} =~ m{file-[12]} ) {
            $Data{Disposition} = 'inline'
        }

        # all others including attachments with content id that are not images
        #   should NOT be inline
        else {
            $Data{Disposition} = 'attachment';
        }
    }

    if ( !$Data{Content} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "$!: $Self->{ArticleDataDir}/$ContentPath/$Param{ArticleID}/$Data{Filename}!",
        );
        return;
    }

    return %Data;
}

sub _ArticleDeleteDirectory {
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

    # delete directory from fs
    my $ContentPath = $Self->ArticleGetContentPath( ArticleID => $Param{ArticleID} );
    my $Path = "$Self->{ArticleDataDir}/$ContentPath/$Param{ArticleID}";
    if ( -d $Path ) {
        if ( !rmdir($Path) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Can't remove: $Path: $!!",
            );
            return;
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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
