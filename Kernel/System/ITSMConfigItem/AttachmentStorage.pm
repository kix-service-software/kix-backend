# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ITSMConfigItem::AttachmentStorage;

use strict;
use warnings;

use MIME::Base64;
use Digest::MD5 qw(md5_hex);
use Encode qw(encode_utf8);

our @ObjectDependencies = qw(
    ClientRegistration
    Config
    DB
    Encode
    Log
    Main
);

=head1 NAME

Kernel::System::ITSMConfigItem::AttachmentStorage - std. attachment lib

=head1 SYNOPSIS

All attachment storage functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item AttachmentStorageGetDirectory()

get an attachment - returns attachment directory entry without attachment content

    my %Data = $AttachmentStorageObject->AttachmentStorageGetDirectory(
        ID => $ID,
    );

=cut

sub AttachmentStorageGetDirectory {
    my ( $Self, %Param ) = @_;
    my %Data = ();

    #check required stuff...
    if ( !$Param{ID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message => "Need ID!"
        );
        return;
    }

    #--------------------------
    # get attachment directory
    #--------------------------
    #db quoting...
    foreach (qw(ID)) {
        $Param{$_} = $Kernel::OM->Get('DB')->Quote( $Param{$_}, 'Integer' );
    }

    #build sql...
    my $SQL = "SELECT id, storage_backend, file_path, " .
        "file_name " .
        "FROM attachment_directory " .
        "WHERE id = ?";

    $Kernel::OM->Get('DB')->Prepare(
        SQL  => $SQL,
        Bind => [ \$Param{ID} ]
    );

    while ( my @Data = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        %Data = (
            AttDirID       => $Data[0],
            StorageBackend => $Data[1],
            FilePath       => $Data[2],
            Filename       => $Data[3],
        );
    }

    #-------------------------------------
    # get attachment directory preferences
    #-------------------------------------

    #build sql...
    $SQL = "SELECT preferences_key, preferences_value " .
        "FROM attachment_dir_preferences " .
        "WHERE attachment_directory_id = ?";

    $Kernel::OM->Get('DB')->Prepare(
        SQL  => $SQL,
        Bind => [ \$Param{ID} ]
    );

    my %Preferences;

    while ( my @Data = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        $Preferences{ $Data[0] } = $Data[1];
    }

    #add preferences
    $Data{Preferences} = \%Preferences;

    return %Data;
}

=item AttachmentStorageGet()

get an attachment

    my $Data = $AttachmentStorageObject->AttachmentStorageGet(
        ID => $ID,
    );

=cut

sub AttachmentStorageGet {
    my ( $Self, %Param ) = @_;
    my %Data = ();

    #check required stuff...
    if ( !$Param{ID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message => "Need ID!"
        );
        return \%Data;
    }

    #get directory data...
    %Data = $Self->AttachmentStorageGetDirectory( ID => $Param{ID} );

    if ( !defined( $Data{AttDirID} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message => "No attachment with this ID exists!"
        );
        return \%Data;
    }

    #get the actual attachment...
    my $AttachmentRef = $Kernel::OM->Get($Data{StorageBackend})->AttachmentGet(
        %Param,
        AttDirID => $Data{AttDirID},
    );

    #$Data{ContentType} = $AttachmentRef->{Datatype};

    # get ContentRef for DB backend
    if ( $AttachmentRef->{DataRef} ) {
        $Data{ContentRef} = $AttachmentRef->{DataRef};
    }

    # get ContentRef for FS backend
    elsif ( exists( $AttachmentRef->{Data} ) ) {
        $Data{ContentRef} = \$AttachmentRef->{Data};
    }

    $AttachmentRef = undef;
    $AttachmentRef = {};

    return \%Data;
}

=item  AttachmentStorageGetRealProperties()

get the attachment's size on disk and the md5sum

    my %Data = $AttachmentStorageObject->AttachmentStorageGetRealProperties(
       AttDirID      => $AttDirID,
       StorageBackend => "Kernel::System::ITSMConfigItem::AttachmentStorage::DB",
    );

=cut

sub AttachmentStorageGetRealProperties {
    my ( $Self, %Param ) = @_;
    my %RealProperties;

    # check required stuff...
    if ( !$Param{AttDirID} && !$Param{StorageBackend} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need AttDirID and StorageBackend!"
        );
        return %RealProperties;
    }

    if ( !( $Param{StorageBackend} ) ) {
        $Param{StorageBackend} =
            $Kernel::OM->Get('Config')->Get('AttachmentStorage::DefaultStorageBackendModule');
    }

    # get the actual attachment properties...
    my $StorageBackend = $Kernel::OM->Get($Param{StorageBackend});
    %RealProperties = $StorageBackend->AttachmentGetRealProperties(
        AttDirID => $Param{AttDirID},
    );

    return %RealProperties;
}

=item AttachmentStorageAdd()

create a new attachment directory entry and write attachment to the specified backend

    my $ID = $AttachmentStorageObject->AttachmentStorageAdd(
        StorageBackend => "Kernel::System::ITSMConfigItem::AttachmentStorage::DB",
        DataRef => $SomeContentReference,
        Filename => 'SomeFilename.zip',
        UserID => 123,
        Preferences  => {
            Datatype           => 'text/xml',
            SomeCustomParams   => 'with our own value',
        }
    );

=cut

sub AttachmentStorageAdd {
    my ( $Self, %Param ) = @_;
    my $ID     = 0;
    my $MD5sum = '';

    #check required stuff...
    foreach (qw(DataRef Filename UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message => "Need $_!"
            );
            return;
        }
    }

    if ( !( $Param{StorageBackend} ) ) {
        $Param{StorageBackend} =
            $Kernel::OM->Get('Config')->Get('AttachmentStorage::DefaultStorageBackendModule');
    }

    #-----------------------------------------------------------------
    # (1) create attachment directory entry...
    #-----------------------------------------------------------------
    #db quoting...
    foreach (qw( StorageBackend Filename)) {
        $Param{$_} = $Kernel::OM->Get('DB')->Quote( $Param{$_} );
    }
    foreach (qw( UserID )) {
        $Param{$_} = $Kernel::OM->Get('DB')->Quote( $Param{$_}, 'Integer' );
    }

    #build sql...
    my $SQL = "INSERT INTO attachment_directory (" .
        " storage_backend, " .
        " file_path, file_name,  " .
        " create_time, create_by, change_time, change_by) " .
        " VALUES (" .
        " ?, " .
        " '', ?, " .
        " current_timestamp, ?, current_timestamp, ?)";

    #run SQL...
    if ( $Kernel::OM->Get('DB')->Do(
            SQL  => $SQL,
            Bind => [ \$Param{StorageBackend}, \$Param{Filename}, \$Param{UserID}, \$Param{UserID} ]
        ) ) {

        #...and get the ID...
        $Kernel::OM->Get('DB')->Prepare(
            SQL => "SELECT max(id) FROM attachment_directory WHERE " .
                "file_name = ? AND " .
                "storage_backend = ? AND " .
                "create_by = ?",
            Bind => [ \$Param{Filename}, \$Param{StorageBackend}, \$Param{UserID} ]
        );
        while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
            $ID = $Row[0];
        }

    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Could NOT insert attachment in attachment directory!",
        );
        return;
    }

    #-----------------------------------------------------------------
    # (2) save attachment directory preferences ...
    #-----------------------------------------------------------------

    # md5sum calculation
    $Kernel::OM->Get('Encode')->EncodeOutput( ${ $Param{DataRef} } );
    $Param{Preferences}->{MD5Sum} = md5_hex( ${ $Param{DataRef} } );

    # size calculation
    $Param{Preferences}->{FileSizeBytes} = bytes::length( ${ $Param{DataRef} } );

    my $FileSize = $Param{Preferences}->{FileSizeBytes};
    if ( $FileSize > ( 1024 * 1024 ) ) {
        $FileSize = sprintf "%.1f MBytes", ( $FileSize / ( 1024 * 1024 ) );
    }
    elsif ( $FileSize > 1024 ) {
        $FileSize = sprintf "%.1f KBytes", ( $FileSize / 1024 );
    }
    else {
        $FileSize = $FileSize . ' Bytes';
    }
    $Param{Preferences}->{FileSize} = $FileSize;

    # insert preferences
    for my $Key ( sort keys %{ $Param{Preferences} } ) {
        return if !$Kernel::OM->Get('DB')->Do(
            SQL => 'INSERT INTO attachment_dir_preferences '
                . '(attachment_directory_id, preferences_key, preferences_value) VALUES ( ?, ?, ?)',
            Bind => [ \$ID, \$Key, \$Param{Preferences}->{$Key} ],
        );
    }

    #-----------------------------------------------------------------
    # (3) create attachment storage entry ( = save file)...
    #-----------------------------------------------------------------

    my $StorageBackend = $Kernel::OM->Get($Param{StorageBackend});
    my $AttID = $StorageBackend->AttachmentAdd(
        AttDirID => $ID,
        DataRef  => $Param{DataRef},
    );

    if ( !$AttID ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Could NOT store attachment in storage ($Param{StorageBackend})!",
        );
        return;
    }

    #-----------------------------------------------------------------
    # (4) update attachment directory (i.e. file path)...
    #-----------------------------------------------------------------

    $AttID = $Kernel::OM->Get('DB')->Quote($AttID);
    $SQL   = "UPDATE attachment_directory SET " .
        " file_path = ? " .
        " WHERE id = ?";

    if ( $Kernel::OM->Get('DB')->Do(
            SQL  => $SQL,
            Bind => [ \$AttID, \$ID ]
        ) ) {

        # push client callback event
        $Kernel::OM->Get('ClientRegistration')->NotifyClients(
            Event     => 'CREATE',
            Namespace => 'CMDB.ConfigItem.Attachment',
            ObjectID  => $ID,
        );

        return $ID;
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Could NOT update attachment directory (ID=$ID, file_path=$AttID)!",
        );
        return;
    }
}

=item AttachmentStorageSearch()

returns attachment directory IDs for the given Filename

    my @Data = $AttachmentStorageObject->AttachmentStorageSearch(
        Filename => 'SomeFilename.zip',
        UsingWildcards => 1, (1 || 0, optional)
    );

=cut

sub AttachmentStorageSearch {
    my ( $Self, %Param ) = @_;
    my @Result = ();
    my @BindObjects;
    my $WHERE  = "(id > 0)";

    #check required stuff...
    if ( !$Param{Filename} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Filename!"
        );
        return;
    }

    #db quoting...
    foreach (qw( Filename )) {
        if ( defined( $Param{$_} ) && ( $Param{$_} ) ) {
            $Param{$_} = $Kernel::OM->Get('DB')->Quote( $Param{$_} );
        }
    }

    #build WHERE-clause...
    if ( $Param{UsingWildcards} ) {
        $WHERE .= " AND (file_name LIKE ?)";
        push(@BindObjects, \$Param{Filename});
    }
    else {
        $WHERE .= " AND (file_name = ?)";
        push(@BindObjects, \$Param{Filename});
    }

    #build sql...
    my $SQL = "SELECT id FROM attachment_directory " .
        "WHERE " . $WHERE;

    $Kernel::OM->Get('DB')->Prepare(
        SQL  => $SQL,
        Bind => \@BindObjects
    );

    while ( my @Data = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        push( @Result, $Data[0] );
    }

    return @Result;
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
