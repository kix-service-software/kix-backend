# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ITSMConfigItem::Image;

use strict;
use warnings;

use File::Path qw(mkpath);
use File::Basename qw(fileparse);
use MIME::Base64;
use Time::HiRes;

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ITSMConfigItem::Image - module for ITSMConfigItem.pm with image functions

=head1 SYNOPSIS

All image functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item ImageGet()

    my %File = $ConfigItemObject->ImageGet(
        ConfigItemID => 123,                # required
        ImageID      => '20180817004645',   # required
        UserID       => 1,
    );

Returns:

    %Image = (
        Filename    => '20180817004645.jpg',
        ContentType => '...',
        Content     => '...'                    # file content, base64 coded
        Comment     => '...'
    );

=cut

sub ImageGet {
    my ( $Self, %Param ) = @_;
    my %Image;

    # check needed stuff
    for my $Needed (qw(ConfigItemID ImageID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my $CacheKey = 'ImageGet::'.$Param{ConfigItemID}.'::'.$Param{ImageID};
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    my $ImageFiles = $Self->_GetImageFileList(
        ConfigItemID => $Param{ConfigItemID},
        ImageID      => $Param{ImageID},
    );

    if (IsArrayRefWithData($ImageFiles)) {

        foreach my $File (@{$ImageFiles}) {
            next if ($File =~ /.*?\.(txt|content_type)$/g);

            my $Content = $Kernel::OM->Get('Main')->FileRead(
                Location => $File,
                Mode     => 'binmode',
            );

            if (!$Content) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unable to read image file $File!",
                );
                return;
            }

            my($Filename, $Dir, $Suffix) = fileparse($File, qr/\.[^.]*/);

            $Image{Filename}    = $Filename . $Suffix;
            $Image{Content}     = encode_base64($$Content);
            $Image{ContentType} = '';
            $Image{Comment}     = '';

            if ( -e $Dir.$Filename.'.content_type') {
                # read comment file
                my $ContentType = $Kernel::OM->Get('Main')->FileRead(
                    Directory => $Dir,
                    Filename  => $Filename . '.content_type',
                    Silent    => 1,
                );

                if ($ContentType) {
                    $Image{ContentType} = $$ContentType;
                }
            }

            if ( -e $Dir.$Filename.'.txt') {
                # read comment file
                $Content = $Kernel::OM->Get('Main')->FileRead(
                    Directory => $Dir,
                    Filename  => $Filename . '.txt',
                    Silent    => 1,
                );

                if ($Content) {
                    $Image{Comment} = $$Content;
                }
            }

            last;
        }
    }

    # cache the result
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Image,
    );

    return %Image;
}

=item ImageAdd()

Adds a single image to the config item.

    my $ImageID = $ConfigItemObject->ImageAdd(
        ConfigItemID  => 1234,          # required
        Filename      => '...',         # required
        ContentType   => '...',         # required
        Content       => '...'          # required, base64 coded
        Comment       => '...'
        UserID        => 1,
    );
=cut

sub ImageAdd {
    my ( $Self, %Param ) = @_;
    my $Filename;

    # check needed stuff
    for my $Needed (qw(ConfigItemID Filename ContentType Content)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my $Directory = $Self->_GetDirectory(
        ConfigItemID => $Param{ConfigItemID}
    );

    if ( -e $Directory ) {

        my $ImageTypes = $Self->_GetValidImageTypes();

        if ($Param{Filename} !~ m/\.($ImageTypes)$/i ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Image type not allowed!",
            );
            return;
        }

        my $FileType = $1;

        $Filename = sprintf('%.6f', Time::HiRes::time());

        my $ImageContent = decode_base64($Param{Content});

        my $FileLocation = $Kernel::OM->Get('Main')->FileWrite(
            Directory => $Directory,
            Filename  => $Filename . '.' . $FileType,
            Content   => \$ImageContent,
        );

        if (!$FileLocation) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to store image file $Directory/$Filename!",
            );
            return;
        }

        $FileLocation = $Kernel::OM->Get('Main')->FileWrite(
            Directory => $Directory,
            Filename  => $Filename . '.content_type',
            Content   => \$Param{ContentType},
        );

        if (!$FileLocation) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to store content type file $Directory/$Filename.content_type!",
            );
            return;
        }

        if ($Param{Comment}) {
            my $FileLocation = $Kernel::OM->Get('Main')->FileWrite(
                Directory => $Directory,
                Filename  => $Filename . '.txt',
                Content   => \$Param{Comment},
            );

            if (!$FileLocation) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unable to store comment file $Directory/$Filename.txt!",
                );
                return;
            }
        }
    }

    # clear cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{OSCacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'CMDB.ConfigItem.Image',
        ObjectID  => $Param{ConfigItemID}.'::'.$Filename,
    );

    return $Filename;
}

=item ImageDelete()

Deletes a image for a given config item

    $ConfigItemObject->ImageDelete(
        ConfigItemID => 123,
        ImageID      => '...',
    );

=cut

sub ImageDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ConfigItemID ImageID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my $ImageFiles = $Self->_GetImageFileList(
        ConfigItemID => $Param{ConfigItemID},
        ImageID      => $Param{ImageID},
    );

    if (IsArrayRefWithData($ImageFiles)) {

        foreach my $File (@{$ImageFiles}) {
            my $OK = $Kernel::OM->Get('Main')->FileDelete(
                Location  => $File,
            );
            if (!$OK) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unable to delete image file $File!",
                );
                return;
            }
        }
    }

    # clear cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{OSCacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'CMDB.ConfigItem.Image',
        ObjectID  => $Param{ConfigItemID}.'::'.$Param{ImageID},
    );

    return 1;
}

=item ImageList()

Returns a list of all ImageIDs for the given config item.

    $ConfigItemObject->ImageList(
        ConfigItemID => 123,
    );

=cut

sub ImageList {
    my ( $Self, %Param ) = @_;
    my @Result;

    # check needed stuff
    for my $Needed (qw(ConfigItemID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my $CacheKey = 'ImageList::'.$Param{ConfigItemID};
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return $Cache if $Cache;

    my $ImageFiles = $Self->_GetImageFileList(
        ConfigItemID => $Param{ConfigItemID},
    );

    if (IsArrayRefWithData($ImageFiles)) {

        my %ImageIDs;
        foreach my $File (@{$ImageFiles}) {
            next if ($File =~ /.*?\.(txt|content_type)$/g);
            my($Filename, $Dirs, $Suffix) = fileparse($File, qr/\.[^.]*/);
            $ImageIDs{$Filename} = 1;
        }

        @Result = (sort keys %ImageIDs);
    }

    # cache the result
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \@Result,
    );

    return \@Result;
}

=begin Internal:

=item _GetDirectory()

get the relevant directory path for the given ConfigItemID

    my $Directory = $ConfigItemObject->_GetDirectory(
        ConfigItemID => $ConfigItemID,
    );

=cut

sub _GetDirectory {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ConfigItemID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my $Directory = $Kernel::OM->Get('Config')->Get('Home') . '/var/ITSMConfigItem/' . $Param{ConfigItemID};

    if ( !( -e $Directory ) ) {
        if ( !mkpath( $Directory, 0, 0775 ) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Can't create directory '$Directory'!",
            );
            return;
        }
    }

    return $Directory;
}

=item _GetImageFileList()

get the images files for the given ConfigItemID and optionally the given ImageID

    my $ImageFiles = $ConfigItemObject->_GetImageFileList(
        ConfigItemID => $ConfigItemID,      # required
        ImageID      => '...',              # optional
    );

=cut

sub _GetImageFileList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ConfigItemID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my $Directory = $Self->_GetDirectory(
        ConfigItemID => $Param{ConfigItemID}
    );

    my $Filter = '*';
    if ($Param{ImageID}) {
        $Filter = $Param{ImageID} . '.*';
    }

    my @ImageFiles = $Kernel::OM->Get('Main')->DirectoryRead(
        Directory => $Directory,
        Filter    => $Filter,
    );

    return \@ImageFiles;
}

=item _GetValidImageTypes()

get the the list of supported images types (extensions)

    my $ValidImagesTypes = $ConfigItemObject->_GetValidImageTypes();

=cut

sub _GetValidImageTypes {
    my ( $Self, %Param ) = @_;

    return '(jpg|jpeg|png|gif|tif|bmp)';
}

1;

=end Internal:



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
