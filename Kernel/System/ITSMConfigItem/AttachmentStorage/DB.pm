# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ITSMConfigItem::AttachmentStorage::DB;

use strict;
use warnings;

use MIME::Base64;
use Digest::MD5 qw(md5_hex);

our @ObjectDependencies = (
    'DB',
    'Encode',
    'Log'
);

=head1 NAME

Kernel::System::ITSMConfigItem::AttachmentStorage::DB

=head1 SYNOPSIS

Provides attachment handling for data base backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create AttachmentStorageDB object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $AttachmentStorageObject = $Kernel::OM->Get('ITSMConfigItem::AttachmentStorage::DB');

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
    my $ID = 0;

    #check required stuff...
    foreach (qw(AttDirID DataRef)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    #encode attachment if it's a postgresql backend...
    if ( !$Kernel::OM->Get('DB')->GetDatabaseFunction('DirectBlob') ) {
        $Kernel::OM->Get('Encode')->EncodeOutput( $Param{DataRef} );

        #overwrite existing value instead of using another filesize of memory...
        ${ $Param{DataRef} } = encode_base64( ${ $Param{DataRef} } );
    }

    #db quoting...
    foreach (qw( AttDirID)) {
        $Param{$_} = $Kernel::OM->Get('DB')->Quote( $Param{$_}, 'Integer' );
    }

    #build sql...
    my $SQL = "";
    if ( $Kernel::OM->Get('DB')->{Backend}->{'DB::Type'} =~ /oracle/ ) {
        $SQL = "INSERT INTO attachment_storage " .
            " (attachment_directory_id, data) " .
            " VALUES " .
            " ( $Param{AttDirID}, EMPTY_CLOB())";

    }
    else {
        $SQL = "INSERT INTO attachment_storage " .
            " (attachment_directory_id, data) " .
            " VALUES " .
            " ( $Param{AttDirID}, ?)";
    }

    #run sql...
    my $DoResult = 0;
    $DoResult = $Kernel::OM->Get('DB')->Do(
        SQL => $SQL, Bind => [ $Param{DataRef} ],    # AttDirID => $Param{AttDirID}
    );

    if ($DoResult) {

        #return ID...
        $Kernel::OM->Get('DB')->Prepare(
            SQL => "SELECT id FROM attachment_storage WHERE " .
                "attachment_directory_id = $Param{AttDirID}",
        );
        while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
            $ID = $Row[0];
        }
        return $ID;
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message => "Failed to insert attachment data!"
        );
        return;
    }
}

=item AttachmentGet()

returns an entry in attachment_storage

    my %Data = $AttachmentObject->AttachmentGet(
        ID => 123, #(some attachment storage id)
        # ...OR...
        AttDirID => 123 #(some attachment directory id),
    );
=cut

sub AttachmentGet {
    my ( $Self, %Param ) = @_;
    my %Data  = ();
    my $WHERE = "";

    #check required stuff...
    if ( !$Param{ID} && !$Param{AttDirID} ) {
        $Kernel::OM->Get('Log')->Log( Priority => 'error', Message => "Need AttDirID or ID!" );
        return \%Data;
    }

    #db quoting...
    foreach (qw( AttDirID ID)) {
        $Param{$_} = $Kernel::OM->Get('DB')->Quote( $Param{$_}, 'Integer' );
    }

    #build sql...
    if ( defined( $Param{AttDirID} ) && $Param{AttDirID} ) {
        $WHERE = " WHERE attachment_directory_id = $Param{AttDirID}";
    }
    else {
        $WHERE = " WHERE id = $Param{ID}";
    }

    my $SQL = "SELECT id, attachment_directory_id FROM attachment_storage " . $WHERE;

    if ( !$Kernel::OM->Get('DB')->Prepare( SQL => $SQL, Encode => [ 0, 0, 1 ] ) ) {
        return \%Data;
    }

    my @Data = $Kernel::OM->Get('DB')->FetchrowArray();

    if (@Data) {
        my $SQL = "SELECT data FROM attachment_storage " . $WHERE;

        if ( !$Kernel::OM->Get('DB')->Prepare( SQL => $SQL, Encode => [ 0 ] ) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Failed to prepare SQL for FetchrowArray!"
            );
            return \%Data;
        }

        my @AttachData = $Kernel::OM->Get('DB')->FetchrowArray();

        my $AttachDataRef = \$AttachData[0];

        if ( !$AttachDataRef ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Failed to FetchrowArray!"
            );
            return \%Data;
        }

        #decode attachment if it's a postgresql backend...
        if ( !$Kernel::OM->Get('DB')->GetDatabaseFunction('DirectBlob') ) {
            ${$AttachDataRef} = decode_base64( ${$AttachDataRef} );
        }

        %Data = (
            ID       => $Data[0],
            AttDirID => $Data[1],

            DataRef => $AttachDataRef,
        );

        $AttachDataRef = undef;
    }

    return \%Data;
}

=item AttachmentGetRealProperties()

returns the size of the attachment in the storage backend and the md5sum.

    my RealProperties = AttachmentStorageObject->AttachmentGetRealProperties(
        AttDirID => 123, #(some attachment directory id)
        #..OR...
        ID => 123, #(some attachment storage id)
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

    if ( defined $Data && $Data->{DataRef} ) {
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
