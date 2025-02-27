# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Cache::FileStorable;

use strict;
use warnings;

use POSIX;
use Storable qw();
use Digest::MD5 qw();
use File::Path qw();
use File::Find qw();
use File::Basename;

our @ObjectDependencies = (
    'Config',
    'Encode',
    'Log',
    'Main',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    my $TempDir = $ConfigObject->Get('TempDir') || $ConfigObject->Get('Home').'/var/tmp';
    $Self->{CacheDirectory} = $TempDir . '/CacheFileStorable';

    # check if cache directory exists and in case create one
    for my $Directory ( $TempDir, $Self->{CacheDirectory} ) {
        if ( !-e $Directory ) {
            ## no critic
            if ( !mkdir( $Directory, 0770 ) ) {
                ## use critic
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Can't create directory '$Directory': $!",
                );
            }
        }
    }

    # Specify how many levels of subdirectories to use, can be 0, 1 or more.
    $Self->{'Cache::SubdirLevels'} = $ConfigObject->Get('Cache::SubdirLevels');
    $Self->{'Cache::SubdirLevels'} //= 2;

    return $Self;
}

sub Set {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(Type Key Value)) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my $Dump = Storable::nfreeze(
        {
            TTL   => $Param{TTL} ? time() + $Param{TTL} : 0,
            Value => $Param{Value},
        }
    );

    my ( $Filename, $CacheDirectory ) = $Self->_GetFilenameAndCacheDirectory(%Param);

    if ( !-e $CacheDirectory ) {

        # Create directory. This could fail if another process creates the
        #   same directory, so don't use the return value.
        File::Path::mkpath( $CacheDirectory, 0, 0770 );    ## no critic

        if ( !-e $CacheDirectory ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Can't create directory '$CacheDirectory': $!",
            );
            return;
        }
    }
    my $FileLocation = $Kernel::OM->Get('Main')->FileWrite(
        Directory  => $CacheDirectory,
        Filename   => $Filename,
        Content    => \$Dump,
        Type       => 'Local',
        Mode       => 'binmode',
        Permission => '660',
    );

    return if !$FileLocation;
    return 1;
}

sub Get {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Type Key)) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my ( $Filename, $CacheDirectory ) = $Self->_GetFilenameAndCacheDirectory(%Param);

    my $Content = $Kernel::OM->Get('Main')->FileRead(
        Directory       => $CacheDirectory,
        Filename        => $Filename,
        Type            => 'Local',
        Mode            => 'binmode',
        DisableWarnings => 1,
    );

    # check if cache exists
    return if !$Content;

    # read data structure back from file dump, use block eval for safety reasons
    my $Storage = eval { Storable::thaw( ${$Content} ) };
    if ( ref $Storage ne 'HASH' || ( $Storage->{TTL} && $Storage->{TTL} < time() ) ) {
        $Self->Delete(%Param);
        return;
    }

    return $Storage->{Value};
}

sub GetMulti {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Type Keys)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    my @Values;
    foreach my $Key ( @{$Param{Keys}} ) {
        push @Values, $Self->Get(%Param, Key => $Key);
    }
    return @Values;
}

sub Delete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Type Key)) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my ( $Filename, $CacheDirectory ) = $Self->_GetFilenameAndCacheDirectory(%Param);

    return $Kernel::OM->Get('Main')->FileDelete(
        Directory       => $CacheDirectory,
        Filename        => $Filename,
        Type            => 'Local',
        DisableWarnings => 1,
    );
}

sub CleanUp {
    my ( $Self, %Param ) = @_;

    # get main object
    my $MainObject = $Kernel::OM->Get('Main');

    my @TypeList = $MainObject->DirectoryRead(
        Directory => $Self->{CacheDirectory},
        Filter    => $Param{Type} || '*',
    );

    if ( $Param{KeepTypes} ) {
        my %KeepTypes = map { $_ => 1 } @{$Param{KeepTypes}};
        my @RealTypeList;
        foreach my $Directory (sort @TypeList) {
            my $Type = basename($Directory);
            next if $KeepTypes{$Type};
            push(@RealTypeList, $Directory);
        }
        @TypeList = @RealTypeList;
    }

    return 1 if !@TypeList;

    my $FileCallback = sub {

        my $CacheFile = $File::Find::name;

        # Remove directory if it is empty
        if ( -d $CacheFile ) {
            rmdir $CacheFile;
            return;
        }

        # For expired filed, check the content and TTL
        if ( $Param{Expired} ) {
            my $Content = $MainObject->FileRead(
                Location        => $CacheFile,
                Mode            => 'binmode',
                DisableWarnings => 1,
            );

            if ( ref $Content eq 'SCALAR' ) {
                my $Storage = eval { Storable::thaw( ${$Content} ); };
                return if ( ref $Storage eq 'HASH' && ( !$Storage->{TTL} || $Storage->{TTL} > time() ) );
            }
        }

        # Delete all cache files; don't error out when the file doesn't
        # exist anymore, it was probably just another process deleting it.
        my $Success = unlink $CacheFile;
        if ( !$Success && $! != POSIX::ENOENT ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Can't remove file $CacheFile: $!",
            );
        }
    };

    # We use finddepth so that the most deeply nested files will be deleted first,
    #   and then the directories above are already empty and can just be removed.
    File::Find::finddepth(
        {
            wanted   => $FileCallback,
            no_chdir => 1,
        },
        @TypeList
    );

    return 1;
}

sub GetKeysForType {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Type)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    my $CacheDirectory = $Self->{CacheDirectory} . '/' . $Param{Type};

    my @FileList = $Kernel::OM->Get('Main')->DirectoryRead(
        Directory => $CacheDirectory,
        Filter    => '*',
        Recursive => 1,
        Silent    => 1,
    );

    return @FileList;
}

sub _GetFilenameAndCacheDirectory {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(Type Key)) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my $Filename = $Param{Key};
    $Kernel::OM->Get('Encode')->EncodeOutput( \$Filename );
    $Filename = Digest::MD5::md5_hex($Filename);

    my $CacheDirectory = $Self->{CacheDirectory} . '/' . $Param{Type};

    for my $Level ( 1 .. $Self->{'Cache::SubdirLevels'} ) {
        $CacheDirectory .= '/' . substr( $Filename, $Level - 1, 1 )
    }

    return $Filename, $CacheDirectory;
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
