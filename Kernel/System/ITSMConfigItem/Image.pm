# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ITSMConfigItem::Image;

use strict;
use warnings;

use File::Path qw(mkpath);
use File::Basename qw(fileparse);

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
        ConfigItemID => 123,
        ImageID      => '...',
        UserID       => 1,
    );

Returns:

    %Image = (
        Filesize    => '540286',                # file size in bytes
        Filename    => 'Error.jpg',
        Content     => '...'                    # file binary content
    );

=cut

sub ImageGet {
    my ( $Self, %Param ) = @_;
    my %Image;

    # check needed stuff
    for my $Needed (qw(ConfigItemID ImageID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
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
            next if ($File =~ /.*?\.txt$/g);

            my $Content = $Kernel::OM->Get('Kernel::System::Main')->FileRead(
                Location => $File,
                Mode     => 'binmode',
            );

            if (!$Content) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Unable to read image file $File!",
                );
                return;               
            }

            my($Filename, $Dir, $Suffix) = fileparse($File, qr/\.[^.]*/);

            $Image{Filename} = $Filename . $Suffix;
            $Image{Content}  = $$Content;
            $Image{Comment}  = '';

            if ( -e $Dir.$Filename.'.txt') {
                # read comment file
                $Content = $Kernel::OM->Get('Kernel::System::Main')->FileRead(
                    Directory => $Dir,
                    Filename  => $Filename . '.txt',
                    Silent    => 1,
                );

                if ($Content) {
                    $Image{Comment}  = $$Content;
                }
            }

            last;
        }
    }

    return %Image;
}

=item ImageAdd()

Adds a single image to the config item.

    my $ImageID = $ConfigItemObject->ImageAdd(
        ConfigItemID  => 1234,          # required
        Filename      => '...',         # required
        Content       => '...'          # required
        Comment       => '...'
        UserID        => 1,
    );
=cut

sub ImageAdd {
    my ( $Self, %Param ) = @_;
    my $Filename;

    # check needed stuff
    for my $Needed (qw(ConfigItemID Filename Content)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
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
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Image type not allowed!",
            );
            return;
        }

        my $FileType = $1;
        my ( $Sec, $Min, $Hour, $Day, $Month, $Year, $WeekDay )= $Kernel::OM->Get('Kernel::System::Time')->SystemTime2Date(
            SystemTime => $Kernel::OM->Get('Kernel::System::Time')->SystemTime(),
        );
        
        $Filename = $Year . $Month . $Day . $Hour . $Min . $Sec;

        my $FileLocation = $Kernel::OM->Get('Kernel::System::Main')->FileWrite(
            Directory => $Directory,
            Filename  => $Filename . '.' . $FileType,
            Content   => \$Param{Content},
        );

        if (!$FileLocation) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Unable to store image file $Directory/$Filename!",
            );
            return;            
        }

        if ($Param{Comment}) {
            my $FileLocation = $Kernel::OM->Get('Kernel::System::Main')->FileWrite(
                Directory => $Directory,
                Filename  => $Filename . '.txt',
                Content   => \$Param{Comment},
            );

            if (!$FileLocation) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Unable to store comment file $Directory/$Filename.txt!",
                );
                return;            
            }    
        }   
    }

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
            $Kernel::OM->Get('Kernel::System::Log')->Log(
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
            my $OK = $Kernel::OM->Get('Kernel::System::Main')->FileDelete(
                Location  => $File,
            );
            if (!$OK) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Unable to delete image file $File!",
                );
                return;
            }
        }
    }

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
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my $ImageFiles = $Self->_GetImageFileList(
        ConfigItemID => $Param{ConfigItemID},
    );

    if (IsArrayRefWithData($ImageFiles)) {

        my %ImageIDs;
        foreach my $File (@{$ImageFiles}) {
            next if ($File =~ /.*?\.txt$/g);
            my($Filename, $Dirs, $Suffix) = fileparse($File, qr/\.[^.]*/);
            $ImageIDs{$Filename} = 1;
        }
    
        @Result = (sort keys %ImageIDs);
    }

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
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my $Directory = $Kernel::OM->Get('Kernel::Config')->Get('Home') . '/var/ITSMConfigItem/' . $Param{ConfigItemID};

    if ( !( -e $Directory ) ) {
        if ( !mkpath( $Directory, 0, 0755 ) ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
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
            $Kernel::OM->Get('Kernel::System::Log')->Log(
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

    my @ImageFiles = $Kernel::OM->Get('Kernel::System::Main')->DirectoryRead(
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
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
