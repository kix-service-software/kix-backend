# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::VirtualFS::DB;

use strict;
use warnings;

use MIME::Base64;

our @ObjectDependencies = (
    'DB',
    'Encode',
    'Log',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # config (not used right now)
    $Self->{Compress} = 0;
    $Self->{Crypt}    = 0;

    return $Self;
}

sub Read {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(BackendKey Mode)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my $Attributes = $Self->_BackendKeyParse(%Param);

    my $Encode = 1;
    if ( lc $Param{Mode} eq 'binary' ) {
        $Encode = 0;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    return if !$DBObject->Prepare(
        SQL    => 'SELECT content FROM virtual_fs_db WHERE id = ?',
        Bind   => [ \$Attributes->{FileID} ],
        Encode => [$Encode],
    );

    # get encode object
    my $EncodeObject = $Kernel::OM->Get('Encode');

    my $Content;
    while ( my @Row = $DBObject->FetchrowArray() ) {

        # decode attachment if it's e. g. a postgresql backend!!!
        if ( !$DBObject->GetDatabaseFunction('DirectBlob') ) {
            $Content = decode_base64( $Row[0] );
            if ($Encode) {
                $EncodeObject->EncodeInput( \$Content );
            }
        }
        else {
            $Content = $Row[0];
        }
    }

    return if !$Content;

    # uncompress (in case)
    if ( $Attributes->{Compress} ) {

        # $Content = ...
    }

    # decrypt (in case)
    if ( $Attributes->{Crypt} ) {

        # $Content = ...
    }

    return \$Content;
}

sub Write {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Content Filename Mode)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check if already exists
    my $Exists = $Self->_FileLookup( $Param{Filename} );
    return if $Exists;

    # compress (in case)
    if ( $Self->{Compress} ) {

        # $Param{Content} = ...
    }

    # crypt (in case)
    if ( $Self->{Crypt} ) {

        # $Param{Content} = ...
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # encode attachment if it's a postgresql backend!!!
    if ( !$DBObject->GetDatabaseFunction('DirectBlob') ) {

        $Kernel::OM->Get('Encode')->EncodeOutput( $Param{Content} );

        my $Content = encode_base64( ${ $Param{Content} } );
        $Param{Content} = \$Content;
    }

    my $Encode = 1;
    if ( lc $Param{Mode} eq 'binary' ) {
        $Encode = 0;
    }

    return if !$DBObject->Do(
        SQL => 'INSERT INTO virtual_fs_db (filename, content, create_time) '
            . 'VALUES ( ?, ?, current_timestamp )',
        Bind => [ \$Param{Filename}, $Param{Content} ],
    );

    my $FileID = $Self->_FileLookup( $Param{Filename} );
    return if !$FileID;

    my $BackendKey = $Self->_BackendKeyGenerate(
        FileID   => $FileID,
        Compress => $Self->{Compress},
        Crypt    => $Self->{Crypt},
        Mode     => $Param{Mode},
    );

    return $BackendKey;
}

sub Delete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(BackendKey)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my $Attributes = $Self->_BackendKeyParse(%Param);

    return if !$Kernel::OM->Get('DB')->Do(
        SQL  => 'DELETE FROM virtual_fs_db WHERE id = ?',
        Bind => [ \$Attributes->{FileID} ],
    );

    return 1;
}

sub _FileLookup {
    my ( $Self, $Filename ) = @_;

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # lookup
    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM virtual_fs_db WHERE filename = ?',
        Bind => [ \$Filename ],
    );

    my $FileID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $FileID = $Row[0];
    }

    return $FileID;
}

sub _BackendKeyGenerate {
    my ( $Self, %Param ) = @_;

    my $BackendKey = '';
    for my $Key ( sort keys %Param ) {
        $BackendKey .= "$Key=$Param{$Key};";
    }
    return $BackendKey;
}

sub _BackendKeyParse {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(BackendKey)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my %Attributes;
    my @Pairs = split /;/, $Param{BackendKey};
    for my $Pair (@Pairs) {
        my ( $Key, $Value ) = split /=/, $Pair;
        $Attributes{$Key} = $Value;
    }
    return \%Attributes;
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
