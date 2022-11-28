# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ITSMConfigItem::XML::Type::Attachment;

use strict;
use warnings;

use MIME::Base64;

our @ObjectDependencies = (
    'ITSMConfigItem',
    'Log'
);

=head1 NAME

Kernel::System::ITSMConfigItem::XML::Type::Attachment - xml backend module

=head1 SYNOPSIS

All xml functions of Attachment objects

=over 4

=cut

=item new()

create a object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $BackendObject = $Kernel::OM->Get('ITSMConfigItem::XML::Type::Attachment');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item ValueLookup()

get the xml data of a version

    my $Value = $BackendObject->ValueLookup(
        Item => $ItemRef,
        Value => 1.1.1.1,
    );

=cut

sub ValueLookup {
    my ( $Self, %Param ) = @_;

    return if !$Param{Value};

    my $StoredAttachment = $Kernel::OM->Get('ITSMConfigItem')->AttachmentStorageGet(
        ID => $Param{Value},
    );

    if (!$StoredAttachment) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to find attachment with ID $Param{Value} in attachment storage!"
        );
        return;
    }

    my %Attachment = (
        AttachmentID => $Param{Value},
        Filename     => $StoredAttachment->{Filename},
        ContentType  => $StoredAttachment->{Preferences}->{Datatype},
        FilesizeRaw  => 0 + (bytes::length ${$StoredAttachment->{ContentRef}}),
    );

    # human readable file size
    if ( $Attachment{FilesizeRaw} ) {
        if ( $Attachment{FilesizeRaw} > ( 1024 * 1024 ) ) {
            $Attachment{Filesize} = sprintf "%.1f MBytes", ( $Attachment{FilesizeRaw} / ( 1024 * 1024 ) );
        }
        elsif ( $Attachment{FilesizeRaw} > 1024 ) {
            $Attachment{Filesize} = sprintf "%.1f KBytes", ( ( $Attachment{FilesizeRaw} / 1024 ) );
        }
        else {
            $Attachment{Filesize} = $Attachment{FilesizeRaw} . ' Bytes';
        }
    }

    return \%Attachment;
}

=item InternalValuePrepare()

prepare "external" value to "internal"

    my $AttachmentDirID = $BackendObject->InternalValuePrepare(
        Value => {
            Filename    => '...',
            ContentType => '...'
            Content     => '...'            # base64 coded
        }
    );

=cut

sub InternalValuePrepare {
    my ( $Self, %Param ) = @_;

    # return if AttachmentID is already given, because it's an existing attachment
    return $Param{Value}->{AttachmentID} if $Param{Value}->{AttachmentID};

    # check needed stuff
    foreach (qw(Filename ContentType Content)) {
        if ( !$Param{Value}->{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my $Content = MIME::Base64::decode_base64($Param{Value}->{Content});

    # store the attachment in the default storage backend....
    my $AttDirID = $Kernel::OM->Get('ITSMConfigItem')->AttachmentStorageAdd(
        DataRef         => \$Content,
        Filename        => $Param{Value}->{Filename},
        UserID          => 1,
        Preferences     => {
            Datatype => $Param{Value}->{ContentType},
        }
    );

    return $AttDirID;
}

=item StatsAttributeCreate()

create a attribute array for the stats framework

    my $Attribute = $BackendObject->StatsAttributeCreate(
        Key => 'Key::Subkey',
        Name => 'Name',
        Item => $ItemRef,
    );

=cut

sub StatsAttributeCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Name Item)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!"
            );
            return;
        }
    }

    # create arrtibute
    my $Attribute = [
        {
            Name             => $Param{Name},
            UseAsXvalue      => 0,
            UseAsValueSeries => 0,
            UseAsRestriction => 0,
            Element          => $Param{Key},
            Block            => 'InputField',
        },
    ];

    return $Attribute;
}

=item ExportSearchValuePrepare()

prepare search value for export

    my $ArrayRef = $BackendObject->ExportSearchValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ExportSearchValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};
    return $Param{Value};
}

=item ExportValuePrepare()

prepare value for export

    my $Value = $BackendObject->ExportValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ExportValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};

    my $RetVal       = "";
    my $SizeNote     = "";
    my $RealFileSize = 0;
    my $MD5Note      = "";
    my $RealMD5Sum   = "";

    # get saved properties (attachment directory info)
    my %AttDirData = $Kernel::OM->Get('ITSMConfigItem')->AttachmentStorageGetDirectory(
        ID => $Param{Value},
    );

    if (
        $AttDirData{Preferences}->{FileSizeBytes}
        &&
        $AttDirData{Preferences}->{MD5Sum}
        )
    {

        my %RealProperties =
            $Kernel::OM->Get('ITSMConfigItem')->AttachmentStorageGetRealProperties(
            %AttDirData,
            );

        $RetVal       = "(size " . $AttDirData{Preferences}->{FileSizeBytes} . ")";
        $RealMD5Sum   = $RealProperties{RealMD5Sum};
        $RealFileSize = $RealProperties{RealFileSize};

        if ( $RealFileSize != $AttDirData{Preferences}->{FileSizeBytes} ) {
            $SizeNote = " Invalid content - file size on disk has been changed";

            if ( $RealFileSize > ( 1024 * 1024 ) ) {
                $RealFileSize = sprintf "%.1f MBytes", ( $RealFileSize / ( 1024 * 1024 ) );
            }
            elsif ( $RealFileSize > 1024 ) {
                $RealFileSize = sprintf "%.1f KBytes", ( ( $RealFileSize / 1024 ) );
            }
            else {
                $RealFileSize = $RealFileSize . ' Bytes';
            }

            $RetVal = "(real size " . $RealFileSize . $SizeNote . ")";
        }
        elsif ( $RealMD5Sum ne $AttDirData{Preferences}->{MD5Sum} ) {
            $MD5Note = " Invalid md5sum - The file might have been changed.";
            $RetVal =~ s/\)/$MD5Note\)/g;
        }

    }
    $RetVal = $AttDirData{FileName};

    #return file information...
    return $RetVal;
}

=item ImportSearchValuePrepare()

prepare search value for import

    my $ArrayRef = $BackendObject->ImportSearchValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ImportSearchValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};

    # this attribute is not intended for import yet...
    $Param{Value} = "";

    return $Param{Value};
}

=item ImportValuePrepare()

prepare value for import

    my $Value = $BackendObject->ImportValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ImportValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};

    # this attribute is not intended for import yet...
    $Param{Value} = "";

    return $Param{Value};
}

=item ValidateValue()

validate given value for this particular attribute type

    my $Value = $BackendObject->ValidateValue(
        Value => {
            Filename    => '...'
            ContentType => '...'
            Content     => '...'
        }
    );

=cut

sub ValidateValue {
    my ( $Self, %Param ) = @_;

    # return if AttachmentID is already set
    return 1 if $Param{Value}->{AttachmentID};

    my $Value = $Param{Value};

    my $Valid = $Value->{Filename} && $Value->{Content};

    if (!$Valid) {
        return 'not a valid attachment'
    }

    $Value->{ContentType} //= $Kernel::OM->Get('Config')->Get('ITSMConfigItem::Attachment::ContentType::Fallback');

    my $ConfigObject = $Kernel::OM->Get('Config');

    my $ForbiddenExtensions   = $ConfigObject->Get('FileUpload::ForbiddenExtensions');
    my $ForbiddenContentTypes = $ConfigObject->Get('FileUpload::ForbiddenContentTypes');
    my $AllowedExtensions     = $ConfigObject->Get('FileUpload::AllowedExtensions');
    my $AllowedContentTypes   = $ConfigObject->Get('FileUpload::AllowedContentTypes');

    # check allowed size
    if ( $Value->{Content} && bytes::length($Value->{Content}) > $ConfigObject->Get('FileUpload::MaxAllowedSize') ) {
        return "size of attachment exceeds maximum allowed size (attachment: $Value->{Filename})";
    }

    # check forbidden file extension
    if ( $ForbiddenExtensions && $Value->{Filename} =~ /$ForbiddenExtensions/ ) {
        return "file type not allowed (attachment: $Value->{Filename})";
    }

    # check forbidden content type
    if ( $ForbiddenContentTypes && $Value->{ContentType} =~ /$ForbiddenContentTypes/ ) {
        return "content type not allowed (attachment: $Value->{Filename})";
    }

    # check allowed file extension
    if ( $AllowedExtensions && $Value->{Filename} !~ /$AllowedExtensions/ ) {
        # check allowed content type as fallback
        if ( $AllowedContentTypes && $Value->{ContentType} !~ /$AllowedContentTypes/ ) {
            return "content type not allowed (attachment: $Value->{Filename})";
        }
        elsif ( !$AllowedContentTypes ) {
            return "file type not allowed (attachment: $Value->{Filename})";
        }
    }

    # check allowed content type
    if ( $AllowedContentTypes && $Value->{ContentType} !~ /$AllowedContentTypes/ ) {
        return "file type not allowed (attachment: $Value->{Filename})";
    }

    return 1;
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
