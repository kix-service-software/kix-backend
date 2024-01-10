# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ITSMConfigItem::AttachmentStorage::FS;

use strict;
use warnings;

use MIME::Base64;
use File::stat;
use Digest::MD5 qw(md5_hex);

our @ObjectDependencies = (
    'Config',
    'DB',
    'Encode',
    'Log'
);

=head1 NAME

Kernel::System::ITSMConfigItem::AttachmentStorage::FS

=head1 SYNOPSIS

Provides attachment handling for file system backend.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create AttachmentStorageFS object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $AttachmentStorageObject = $Kernel::OM->Get('ITSMConfigItem::AttachmentStorage::FS');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item AttachmentAdd()

create a new std. attachment

    my $ID = $AttachmentObject->AttachmentAdd(
        AttDirID => 123,
        DataRef  => \$SomeContent,
    );

=cut

sub AttachmentAdd {
    my ( $Self, %Param ) = @_;
    my $retVal = 1;

    #check required stuff...
    foreach (qw(AttDirID DataRef)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    #build attachment data file path...
    $retVal = $Kernel::OM->Get('Config')->Get('Home') .
        $Kernel::OM->Get('Config')->Get('AttachmentStorageFS::StorageDirectory');

    #check if destination path exists...
    if ( !-d $retVal ) {
        if ( !File::Path::mkpath( [$retVal], 0, 0775 ) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message =>
                    "AttachmentStorageFS path does not exist neither I can create it ($retVal): $!"
            );
            return;
        }
    }

    #build attachment data file path...
    $retVal .= "/" . $Param{AttDirID} . ".dat";

    #write the attachment data file...
    if ( open( my $DATA, ">", "$retVal" ) ) {
        binmode($DATA);
        print $DATA ${ $Param{DataRef} };
        close($DATA);
        return $retVal;
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Can NOT write file ($retVal): $!",
        );
        return;
    }
}

=item AttachmentGet()

returns an entry in attachment_storage

    my %Data = $AttachmentObject->Attachment(
        AttDirID => 123, #(some attachment directory id)
        #..OR...
        FilePath => '/path/to/the/attachment/file.dat',
    );

=cut

sub AttachmentGet {
    my ( $Self, %Param ) = @_;
    my %Data     = ();
    my $FilePath = '';

    #check required stuff...
    if ( !$Param{AttDirID} && !$Param{FilePath} ) {
        $Kernel::OM->Get('Log')->Log( Priority => 'error', Message => "Need AttDirID or FilePath!" );
        return \%Data;
    }

    if ( defined( $Param{FilePath} ) && $Param{FilePath} ) {
        $FilePath = $Param{FilePath};
    }

    #check if ParamID is defined
    if ( defined( $Param{AttDirID} ) && $Param{AttDirID} ) {

        #db quoting...
        foreach (qw( AttDirID)) {
            $Param{$_} = $Kernel::OM->Get('DB')->Quote( $Param{$_}, 'Integer' );
        }

        #build sql...
        my $SQL = "SELECT file_path FROM attachment_directory "
            . "WHERE id=$Param{AttDirID}";

        $Kernel::OM->Get('DB')->Prepare(
            SQL => $SQL,
        );

        while ( my @Data = $Kernel::OM->Get('DB')->FetchrowArray() ) {
            $FilePath = $Data[0];
        }
    }

    if ( !$FilePath ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message =>
                "Could NOT find file path for given attachment directory id ($Param{AttDirID})!"
        );
        return \%Data;
    }

    #get the attachment data file...
    if ( open( my $DATA, "<", $FilePath ) ) {
        my $Counter = 0;
        my $Data    = "";
        binmode($DATA);
        while (<$DATA>) {
            $Data .= $_;
        }
        close($DATA);

        # set DataRef param
        $Data{DataRef} = \$Data;
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Could not open $FilePath: $! !",
        );
        return \%Data;
    }

    return \%Data;
}

=item AttachmentGetRealProperties()

returns the size of the attachment in the storage backend and the md5sum.

    my RealProperties = AttachmentStorageObject->AttachmentGetRealProperties(
        AttDirID => 123, #(some attachment directory id)
    );

=cut

sub AttachmentGetRealProperties {
    my ( $Self, %Param ) = @_;
    my %RealProperties;

    #check required stuff...
    if ( !$Param{AttDirID} ) {
        $Kernel::OM->Get('Log')->Log( Priority => 'error', Message => "Need AttDirID!" );
        return %RealProperties;
    }

    my $Data = $Self->AttachmentGet(
        AttDirID => $Param{AttDirID}
    );

    my $RealFileSize = 0;
    my $RealMD5Sum   = '';

    if (defined $Data && $Data->{DataRef}) {
        my $Content = ${ $Data->{DataRef} };
        $Kernel::OM->Get('Encode')->EncodeOutput( \$Content );

        $RealFileSize = bytes::length($Content);
        $RealMD5Sum   = md5_hex($Content);
    }

    $RealProperties{RealFileSize} = $RealFileSize;
    $RealProperties{RealMD5Sum}   = $RealMD5Sum;

    return %RealProperties;
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
