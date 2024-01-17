# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::VirtualFS;

use strict;
use warnings;

our @ObjectDependencies = (
    'Config',
    'DB',
    'Log',
    'Main',
);

=head1 NAME

Kernel::System::VirtualFS - virtual fs lib

=head1 SYNOPSIS

All virtual fs functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $VirtualFSObject = $Kernel::OM->Get('VirtualFS');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # load backend
    $Self->{BackendDefault} = $Kernel::OM->Get('Config')->Get('VirtualFS::Backend')
        || 'Kernel::System::VirtualFS::DB';

    if ( !$Kernel::OM->Get('Main')->Require( $Self->{BackendDefault} ) ) {
        return;
    }

    $Self->{Backend}->{ $Self->{BackendDefault} } = $Self->{BackendDefault}->new();

    return $Self;
}

=item Read()

read a file from virtual file system

    my %File = $VirtualFSObject->Read(
        Filename => '/Object/some/name.txt',    # or ID
        ID       => 123,                        # or Filename
        Mode     => 'utf8',

        # optional
        DisableWarnings => 1,
    );

returns

    my %File = (
        Content  => $ContentSCALAR,

        # preferences data
        Preferences => {

            # generated automatically
            Filesize           => '12.4 KBytes',
            FilesizeRaw        => 12345,

            # optional
            ContentType        => 'text/plain',
            ContentID          => '<some_id@example.com>',
            ContentAlternative => 1,
            SomeCustomParams   => 'with our own value',
        },
    );

=cut

sub Read {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Mode)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }
    if ( !$Param{Filename} && !$Param{ID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Filename or ID!"
        );
        return;
    }

    # lookup
    my ( $FileID, $BackendKey, $Backend, $Filename ) = $Self->_FileLookup(%Param);
    if ( !$BackendKey ) {
        if ( !$Param{DisableWarnings} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No such file '" . ($Param{Filename} && !$Param{ID} ? $Param{Filename} : $Param{ID}) . "'!",
            );
        }
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # get preferences
    my %Preferences;
    return if !$DBObject->Prepare(
        SQL => 'SELECT preferences_key, preferences_value FROM '
            . 'virtual_fs_preferences WHERE virtual_fs_id = ?',
        Bind => [ \$FileID ],
    );

    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Preferences{ $Row[0] } = $Row[1];
    }

    # load backend (if not default)
    if ( !$Self->{Backend}->{$Backend} ) {

        return if !$Kernel::OM->Get('Main')->Require($Backend);

        $Self->{Backend}->{$Backend} = $Backend->new();

        return if !$Self->{Backend}->{$Backend};
    }

    # get file
    my $Content = $Self->{Backend}->{$Backend}->Read(
        %Param,
        Filename   => $Filename,
        BackendKey => $BackendKey,
    );
    return if !$Content;

    return (
        Preferences => \%Preferences,
        Content     => $Content,
        Filename    => $Filename,
    );
}

=item Write()

write a file to virtual file system and returns its id

    my $FileID = $VirtualFSObject->Write(
        Content  => \$Content,
        Filename => '/Object/SomeFileName.txt',
        Mode     => 'binary',            # (binary|utf8)

        # optional, preferences data
        Preferences => {
            ContentType        => 'text/plain',
            ContentID          => '<some_id@example.com>',
            ContentAlternative => 1,
            SomeCustomParams   => 'with our own value',
        },
    );

=cut

sub Write {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Filename Content Mode)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # lookup
    my ($FileID) = $Self->_FileLookup( Name => $Param{Filename} );
    if ($FileID) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "File already exists '$Param{Filename}'!",
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # insert
    return if !$DBObject->Do(
        SQL => 'INSERT INTO virtual_fs (filename, backend_key, backend, create_time)'
            . ' VALUES ( ?, \'TMP\', ?, current_timestamp)',
        Bind => [ \$Param{Filename}, \$Self->{BackendDefault} ],
    );

    ($FileID) = $Self->_FileLookup( Filename => $Param{Filename} );

    if ( !$FileID ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to store '$Param{Filename}'!",
        );
        return;
    }

    # size calculation
    $Param{Preferences}->{FilesizeRaw} = bytes::length( ${ $Param{Content} } );
    my $Filesize = $Param{Preferences}->{FilesizeRaw};
    if ( $Filesize > ( 1024 * 1024 ) ) {
        $Filesize = sprintf "%.1f MBytes", ( $Filesize / ( 1024 * 1024 ) );
    }
    elsif ( $Filesize > 1024 ) {
        $Filesize = sprintf "%.1f KBytes", ( $Filesize / 1024 );
    }
    else {
        $Filesize = $Filesize . ' Bytes';
    }
    $Param{Preferences}->{Filesize} = $Filesize;

    # insert preferences
    for my $Key ( sort keys %{ $Param{Preferences} } ) {
        return if !$DBObject->Do(
            SQL => 'INSERT INTO virtual_fs_preferences '
                . '(virtual_fs_id, preferences_key, preferences_value) VALUES ( ?, ?, ?)',
            Bind => [ \$FileID, \$Key, \$Param{Preferences}->{$Key} ],
        );
    }

    # store file
    my $BackendKey = $Self->{Backend}->{ $Self->{BackendDefault} }->Write(%Param);
    if ( !$BackendKey ) {
        # cleanup data if file could not be stored in backend

        $DBObject->Do(
            SQL => 'DELETE FROM virtual_fs_preferences WHERE virtual_fs_id=?',
            Bind => [ \$FileID ],
        );

        $DBObject->Do(
            SQL => 'DELETE FROM virtual_fs WHERE id=?',
            Bind => [ \$FileID ],
        );
        
        return;
    }

    # update backend key
    return if !$DBObject->Do(
        SQL  => 'UPDATE virtual_fs SET backend_key = ? WHERE id = ?',
        Bind => [ \$BackendKey, \$FileID ],
    );

    return $FileID;
}

=item Delete()

delete a file from virtual file system

    my $Success = $VirtualFSObject->Delete(
        Filename => '/Object/some/name.txt',    # or ID
        ID       => 123,                        # or Filename

        # optional
        DisableWarnings => 1,
    );

=cut

sub Delete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Filename} && !$Param{ID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Filename or ID!"
        );
        return;
    }

    # lookup
    my ( $FileID, $BackendKey, $Backend, $Filename ) = $Self->_FileLookup(%Param);
    if ( !$FileID ) {
        if ( !$Param{DisableWarnings} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No such file '" . ($Param{Filename} ? $Param{Filename} : $Param{ID}) . "'!",
            );
        }
        return;
    }

    # load backend (if not default)
    if ( !$Self->{Backend}->{$Backend} ) {

        return if !$Kernel::OM->Get('Main')->Require($Backend);

        $Self->{Backend}->{$Backend} = $Backend->new();

        return if !$Self->{Backend}->{$Backend};
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # delete preferences
    return if !$DBObject->Do(
        SQL  => 'DELETE FROM virtual_fs_preferences WHERE virtual_fs_id = ?',
        Bind => [ \$FileID ],
    );

    # delete
    return if !$DBObject->Do(
        SQL  => 'DELETE FROM virtual_fs WHERE id = ?',
        Bind => [ \$FileID ],
    );

    # delete file
    return $Self->{Backend}->{$Backend}->Delete(
        %Param,
        Filename   => $Filename,
        BackendKey => $BackendKey,
    );
}

=item Find()

find files in virtual file system

only for file name

    my @List = $VirtualFSObject->Find(
        Filename  => '/Object/some_what/*.txt',
        ReturnIDs => 1|0                            # optional, default 0, use 1 if IDs should be returned
    );

only for preferences

    my @List = $VirtualFSObject->Find(
        Preferences => {
            ContentType => 'text/plain',
        },
        ReturnIDs => 1|0                            # optional, default 0, use 1 if IDs should be returned
    );

for file name and for preferences

    my @List = $VirtualFSObject->Find(
        Filename    => '/Object/some_what/*.txt',
        Preferences => {
            ContentType => 'text/plain',
        },
        ReturnIDs => 1|0                            # optional, default 0, use 1 if IDs should be returned
    );

Returns:

    my @List = (
      '/Object/some/file.txt',
      '/Object/my.pdf',
      ...
    );

    or if ReturnIDs = 1
    my @List = (
      1,
      3,
      ...
    );

=cut

sub Find {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Filename} && !$Param{Preferences} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Filename or/and Preferences!',
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # get like escape string needed for some databases (e.g. oracle)
    my $LikeEscapeString = $DBObject->GetDatabaseFunction('LikeEscapeString');

    # prepare file name search
    my $SQLResult = $Param{ReturnIDs} ? 'vfs.id' : 'vfs.filename';
    my $SQLTable  = 'virtual_fs vfs ';
    my $SQLWhere  = '';
    my @SQLBind;
    if ( $Param{Filename} ) {
        my $Like = $Param{Filename};
        $Like =~ s/\*/%/g;
        $Like = $DBObject->Quote( $Like, 'Like' );
        $SQLWhere .= "vfs.filename LIKE '$Like' $LikeEscapeString";
    }

    # prepare preferences search
    if ( $Param{Preferences} ) {
        $SQLResult .= ', vfsp.preferences_key, vfsp.preferences_value';
        $SQLTable  .= ', virtual_fs_preferences vfsp';
        if ($SQLWhere) {
            $SQLWhere .= ' AND ';
        }
        $SQLWhere .= 'vfs.id = vfsp.virtual_fs_id ';
        my $SQL = '';
        for my $Key ( sort keys %{ $Param{Preferences} } ) {
            if ($SQL) {
                $SQL .= ' OR ';
            }
            $SQL .= '(vfsp.preferences_key = ? AND ';
            push @SQLBind, \$Key;

            my $Value = $Param{Preferences}->{$Key};
            if ( $Value =~ /(\*|\%)/ ) {
                $Value =~ s/\*/%/g;
                $Value = $DBObject->Quote( $Value, 'Like' );
                $SQL .= "vfsp.preferences_value LIKE '$Value' $LikeEscapeString";
            }
            else {
                $SQL .= 'vfsp.preferences_value = ?';
                push @SQLBind, \$Value;
            }
            $SQL .= ')';
        }

        $SQLWhere .= " AND ($SQL)";
    }

    # search
    return if !$DBObject->Prepare(
        SQL  => "SELECT $SQLResult FROM $SQLTable WHERE $SQLWhere",
        Bind => \@SQLBind,
    );
    my @List;
    my %Result;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        if ( $Param{Preferences} ) {
            for my $Key ( sort keys %{ $Param{Preferences} } ) {
                $Result{ $Row[0] }->{ $Row[1] } = $Row[2];
            }
        }
        else {
            push @List, $Row[0];
        }
    }

    # check preferences search
    if ( $Param{Preferences} ) {
        FILE:
        for my $File ( sort keys %Result ) {
            for my $Key ( sort keys %{ $Param{Preferences} } ) {
                my $DB    = $Result{$File}->{$Key};
                my $Given = $Param{Preferences}->{$Key};
                next FILE if defined $DB  && !defined $Given;
                next FILE if !defined $DB && defined $Given;
                if ( $Given =~ /\*/ ) {
                    $Given =~ s/\*/.\*/g;
                    $Given =~ s/\//\\\//g;
                    next FILE if $DB !~ /$Given/;
                }
                else {
                    next FILE if $DB ne $Given;
                }
            }
            push @List, $File;
        }
    }

    # return result
    return @List;
}

=begin Internal:

returns internal meta information, unique file id, where and with what arguments the
file is stored (Filename or ID must be given)

    my ( $FileID, $BackendKey, $Backend ) = $Self->_FileLookup(
        Filename => '/Object/SomeFile.txt',
        ID       => 123
    );

=cut

sub _FileLookup {
    my ( $Self, %Param ) = @_;

    my $Where = $Param{ID} ? 'id' : 'filename';
    my $Value = $Param{ID} ? $Param{ID} : $Param{Filename};

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # lookup
    return if !$DBObject->Prepare(
        SQL  => 'SELECT id, backend_key, backend, filename FROM virtual_fs WHERE ' . $Where . ' = ?',
        Bind => [ \$Value ],
    );

    my $FileID;
    my $BackendKey;
    my $Backend;
    my $Filename;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $FileID     = $Row[0];
        $BackendKey = $Row[1];
        $Backend    = $Row[2];
        $Filename    = $Row[3];
    }

    return ( $FileID, $BackendKey, $Backend, $Filename );
}

=end Internal:

=cut

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
