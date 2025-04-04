# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Main;

use strict;
use warnings;

use Bytes::Random::Secure;
use Digest::MD5 qw(md5_hex);
use Data::Dumper;
use Hash::Flatten;
use File::stat;
use Unicode::Normalize;
use List::Util qw();
use Storable;
use Fcntl qw(:flock);
use Time::HiRes;
use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Encode',
    'Log',
);

=head1 NAME

Kernel::System::Main - main object

=head1 SYNOPSIS

All main functions to load modules, die, and handle files.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create new object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $MainObject = $Kernel::OM->Get('Main');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item Require()

require/load a module

    my $Loaded = $MainObject->Require(
        'Example',
        Silent => 1,                # optional, no log entry if module was not found
    );

=cut

sub Require {
    my ( $Self, $Module, %Param ) = @_;

    if ( !$Module ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Need module!',
            );
        }
        return;
    }


    # prepare module
    $Module =~ s/::/\//g;
    $Module .= '.pm';

    # just return if it's already loaded
    return 1 if $INC{$Module};

    my $Result;
    my $File;

    # find full path of module
    PREFIX:
    for my $Prefix (@INC) {
        next PREFIX if !$Prefix;

        $File = $Prefix . '/' . $Module;

        next PREFIX if !-f $File;

        $Result = do $File;

        last PREFIX;
    }

    # if there was an error
    if ($@) {
        my $ErrorMessage = $@;

        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Caller   => 1,
                Priority => 'error',
                Message  => $ErrorMessage,
            );
        }

        return;
    }

    # check result value, should be true
    if ( !$Result ) {

        if ( !$Param{Silent} ) {
            my $Message = "Module $Module not found/could not be loaded";
            if ( !-f $File ) {
                $Message = "Module $Module not in \@INC (@INC)";
            }
            elsif ( !-r $File ) {
                $Message = "Module could not be loaded (no read permissions on $File)";
            }

            $Kernel::OM->Get('Log')->Log(
                Caller   => 1,
                Priority => 'error',
                Message  => $Message,
            );
        }

        return;
    }

    # add module
    $INC{$Module} = $File;

    return 1;
}

=item RequireBaseClass()

require/load a module and add it as a base class to the
calling package, if not already present (this check is needed
for persistent environments).

    my $Loaded = $MainObject->RequireBaseClass(
        'Example',
    );

=cut

sub RequireBaseClass {
    my ( $Self, $Module ) = @_;

    # Load the module, if not already loaded.
    return if !$Self->Require($Module);

    no strict 'refs';    ## no critic
    my $CallingClass = caller(0);

    # Check if the base class was already loaded.
    # This can happen in persistent environments as mod_perl (see bug#9686).
    if ( List::Util::first { $_ eq $Module } @{"${CallingClass}::ISA"} ) {
        return 1;    # nothing to do now
    }

    push @{"${CallingClass}::ISA"}, $Module;

    return 1;
}

=item Die()

to die

    $MainObject->Die('some message to die');

=cut

sub Die {
    my ( $Self, $Message ) = @_;

    $Message = $Message || 'Died!';

    # log message
    $Kernel::OM->Get('Log')->Log(
        Caller   => 1,
        Priority => 'error',
        Message  => $Message,
    );

    exit;
}

=item FilenameCleanUp()

to clean up filenames which can be used in any case (also quoting is done)

    my $Filename = $MainObject->FilenameCleanUp(
        Filename => 'me_to/alal.xml',
        Type     => 'Local', # Local|Attachment|MD5
    );

    my $Filename = $MainObject->FilenameCleanUp(
        Filename => 'some:file.xml',
        Type     => 'MD5', # Local|Attachment|MD5
    );

=cut

sub FilenameCleanUp {
    my ( $Self, %Param ) = @_;

    if ( !$Param{Filename} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Filename!',
        );
        return;
    }

    my $Type = lc( $Param{Type} || 'local' );

    if ( $Type eq 'md5' ) {
        $Kernel::OM->Get('Encode')->EncodeOutput( \$Param{Filename} );
        $Param{Filename} = md5_hex( $Param{Filename} );
    }

    # replace invalid token for attachment file names
    elsif ( $Type eq 'attachment' ) {

        # replace invalid token like < > ? " : ; | \ / or *
        $Param{Filename} =~ s/[ <>\?":\\\*\|\/;\[\]]/_/g;

        # replace utf8 and iso
        $Param{Filename} =~ s/(\x{00C3}\x{00A4}|\x{00A4})/ae/g;
        $Param{Filename} =~ s/(\x{00C3}\x{00B6}|\x{00B6})/oe/g;
        $Param{Filename} =~ s/(\x{00C3}\x{00BC}|\x{00FC})/ue/g;
        $Param{Filename} =~ s/(\x{00C3}\x{009F}|\x{00C4})/Ae/g;
        $Param{Filename} =~ s/(\x{00C3}\x{0096}|\x{0096})/Oe/g;
        $Param{Filename} =~ s/(\x{00C3}\x{009C}|\x{009C})/Ue/g;
        $Param{Filename} =~ s/(\x{00C3}\x{009F}|\x{00DF})/ss/g;
        $Param{Filename} =~ s/-+/-/g;

        # cut the string if too long
        if ( length( $Param{Filename} ) > 100 ) {
            my $Ext = '';
            if ( $Param{Filename} =~ /^.*(\.(...|....))$/ ) {
                $Ext = $1;
            }
            $Param{Filename} = substr( $Param{Filename}, 0, 95 ) . $Ext;
        }
    }
    else {

        # replace invalid token like [ ] * : ? " < > ; | \ /
        $Param{Filename} =~ s/[<>\?":\\\*\|\/;\[\]]/_/g;
    }

    return $Param{Filename};
}

=item FileRead()

to read files from file system

    my $ContentSCALARRef = $MainObject->FileRead(
        Directory => 'c:\some\location',
        Filename  => 'file2read.txt',
        # or Location
        Location  => 'c:\some\location\file2read.txt',
    );

    my $ContentARRAYRef = $MainObject->FileRead(
        Directory => 'c:\some\location',
        Filename  => 'file2read.txt',
        # or Location
        Location  => 'c:\some\location\file2read.txt',

        Result    => 'ARRAY', # optional - SCALAR|ARRAY
    );

    my $ContentSCALARRef = $MainObject->FileRead(
        Directory       => 'c:\some\location',
        Filename        => 'file2read.txt',
        # or Location
        Location        => 'c:\some\location\file2read.txt',

        Mode            => 'binmode', # optional - binmode|utf8
        Type            => 'Local',   # optional - Local|Attachment|MD5
        Result          => 'SCALAR',  # optional - SCALAR|ARRAY
        DisableWarnings => 1,         # optional
    );

=cut

sub FileRead {
    my ( $Self, %Param ) = @_;

    my $FH;
    if ( $Param{Filename} && $Param{Directory} ) {

        # filename clean up
        $Param{Filename} = $Self->FilenameCleanUp(
            Filename => $Param{Filename},
            Type     => $Param{Type} || 'Local',    # Local|Attachment|MD5
        );
        $Param{Location} = "$Param{Directory}/$Param{Filename}";
    }
    elsif ( $Param{Location} ) {

        # filename clean up
        $Param{Location} =~ s{//}{/}xmsg;
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Filename and Directory or Location!',
        );

    }

    # check if file exists
    if ( !-e $Param{Location} ) {
        if ( !$Param{DisableWarnings} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "File '$Param{Location}' doesn't exist!"
            );
        }
        return;
    }

    # set open mode
    my $Mode = '<';
    if ( $Param{Mode} && $Param{Mode} =~ m{ \A utf-?8 \z }xmsi ) {
        $Mode = '<:utf8';
    }

    # return if file can not open
    if ( !open $FH, $Mode, $Param{Location} ) {    ## no critic
        if ( !$Param{DisableWarnings} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Can't open '$Param{Location}': $!",
            );
        }
        return;
    }

    # lock file (Shared Lock)
    if ( !flock $FH, LOCK_SH ) {
        if ( !$Param{DisableWarnings} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Can't lock '$Param{Location}': $!",
            );
        }
    }

    # enable binmode
    if ( !$Param{Mode} || $Param{Mode} =~ m{ \A binmode }xmsi ) {
        binmode $FH;
    }

    # read file as array
    if ( $Param{Result} && $Param{Result} eq 'ARRAY' ) {

        # read file content at once
        my @Array = <$FH>;
        close $FH;

        return \@Array;
    }

    # read file as string
    my $String = do { local $/; <$FH> };
    close $FH;

    return \$String;
}

=item FileWrite()

to write data to file system

    my $FileLocation = $MainObject->FileWrite(
        Directory => 'c:\some\location',
        Filename  => 'file2write.txt',
        # or Location
        Location  => 'c:\some\location\file2write.txt',

        Content   => \$Content,
    );

    my $FileLocation = $MainObject->FileWrite(
        Directory  => 'c:\some\location',
        Filename   => 'file2write.txt',
        # or Location
        Location   => 'c:\some\location\file2write.txt',

        Content    => \$Content,
        Mode       => 'binmode', # binmode|utf8
        Type       => 'Local',   # optional - Local|Attachment|MD5
        Permission => '644',     # optional - unix file permissions
    );

Platform note: MacOS (HFS+) stores filenames as Unicode NFD internally,
and DirectoryRead() will also report them as NFD.

=cut

sub FileWrite {
    my ( $Self, %Param ) = @_;

    if ( $Param{Filename} && $Param{Directory} ) {

        # filename clean up
        $Param{Filename} = $Self->FilenameCleanUp(
            Filename => $Param{Filename},
            Type     => $Param{Type} || 'Local',    # Local|Attachment|MD5
        );
        $Param{Location} = "$Param{Directory}/$Param{Filename}";
    }
    elsif ( $Param{Location} ) {

        # filename clean up
        $Param{Location} =~ s/\/\//\//g;
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Filename and Directory or Location!',
        );
    }

    # set open mode (if file exists, lock it on open, done by '+<')
    my $Exists;
    if ( -f $Param{Location} ) {
        $Exists = 1;
    }
    my $Mode = '>';
    if ($Exists) {
        $Mode = '+<';
    }
    if ( $Param{Mode} && $Param{Mode} =~ /^(utf8|utf\-8)/i ) {
        $Mode = '>:utf8';
        if ($Exists) {
            $Mode = '+<:utf8';
        }
    }

    # return if file can not open
    my $FH;
    if ( !open $FH, $Mode, $Param{Location} ) {    ## no critic
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Can't write '$Param{Location}': $!",
        );
        return;
    }

    # lock file (Exclusive Lock)
    if ( !flock $FH, LOCK_EX ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Can't lock '$Param{Location}': $!",
        );
    }

    # empty file first (needed if file is open by '+<')
    truncate $FH, 0;

    # enable binmode
    if ( !$Param{Mode} || lc $Param{Mode} eq 'binmode' ) {

        # make sure, that no utf8 stamp exists (otherway perl will do auto convert to iso)
        $Kernel::OM->Get('Encode')->EncodeOutput( $Param{Content} );

        # set file handle to binmode
        binmode $FH;
    }

    # write file if content is not undef
    if ( defined ${ $Param{Content} } ) {
        print $FH ${ $Param{Content} };
    }

    # write empty file if content is undef
    else {
        print $FH '';
    }

    # close the filehandle
    close $FH;

    # set permission
    if ( $Param{Permission} ) {
        if ( length $Param{Permission} == 3 ) {
            $Param{Permission} = "0$Param{Permission}";
        }
        chmod( oct( $Param{Permission} ), $Param{Location} );
    }

    return $Param{Filename} if $Param{Filename};
    return $Param{Location};
}

=item FileDelete()

to delete a file from file system

    my $Success = $MainObject->FileDelete(
        Directory       => 'c:\some\location',
        Filename        => 'me_to/alal.xml',
        # or Location
        Location        => 'c:\some\location\me_to\alal.xml'

        Type            => 'Local',   # optional - Local|Attachment|MD5
        DisableWarnings => 1, # optional
    );

=cut

sub FileDelete {
    my ( $Self, %Param ) = @_;

    if ( $Param{Filename} && $Param{Directory} ) {

        # filename clean up
        $Param{Filename} = $Self->FilenameCleanUp(
            Filename => $Param{Filename},
            Type     => $Param{Type} || 'Local',    # Local|Attachment|MD5
        );
        $Param{Location} = "$Param{Directory}/$Param{Filename}";
    }
    elsif ( $Param{Location} ) {

        # filename clean up
        $Param{Location} =~ s/\/\//\//g;
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Filename and Directory or Location!',
        );
    }

    # check if file exists
    if ( !-e $Param{Location} ) {
        if ( !$Param{DisableWarnings} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "File '$Param{Location}' doesn't exist!"
            );
        }
        return;
    }

    # delete file
    if ( !unlink( $Param{Location} ) ) {
        if ( !$Param{DisableWarnings} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Can't delete '$Param{Location}': $!",
            );
        }
        return;
    }

    return 1;
}

=item FileGetMTime()

get timestamp of file change time

    my $FileMTime = $MainObject->FileGetMTime(
        Directory => 'c:\some\location',
        Filename  => 'me_to/alal.xml',
        # or Location
        Location  => 'c:\some\location\me_to\alal.xml'
    );

=cut

sub FileGetMTime {
    my ( $Self, %Param ) = @_;

    my $Stat = $Self->FileStat(
        %Param,
    );
    return if ( !$Stat );

    return $Stat->mtime();
}

=item FileStat()

get stat of given file

    my $FileStat = $MainObject->FileStat(
        Directory => 'c:\some\location',
        Filename  => 'me_to/alal.xml',
        # or Location
        Location  => 'c:\some\location\me_to\alal.xml'
    );

=cut

sub FileStat {
    my ( $Self, %Param ) = @_;

    my $FH;
    if ( $Param{Filename} && $Param{Directory} ) {

        # filename clean up
        $Param{Filename} = $Self->FilenameCleanUp(
            Filename => $Param{Filename},
            Type     => $Param{Type} || 'Local',    # Local|Attachment|MD5
        );
        $Param{Location} = "$Param{Directory}/$Param{Filename}";
    }
    elsif ( $Param{Location} ) {

        # filename clean up
        $Param{Location} =~ s{//}{/}xmsg;
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Filename and Directory or Location!',
        );

    }

    # check if file exists
    if ( !-e $Param{Location} ) {
        if ( !$Param{DisableWarnings} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "File '$Param{Location}' doesn't exist!"
            );
        }
        return;
    }

    # get file metadata
    my $Stat = stat( $Param{Location} );

    if ( !$Stat ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Cannot stat file '$Param{Location}': $!"
        );
        return;
    }

    return $Stat;
}

=item MD5sum()

get a md5 sum of a file or a string

    my $MD5Sum = $MainObject->MD5sum(
        Filename => '/path/to/me_to_alal.xml',
    );

    my $MD5Sum = $MainObject->MD5sum(
        String => \$SomeString,
    );

    # note: needs more memory!
    my $MD5Sum = $MainObject->MD5sum(
        String => $SomeString,
    );

=cut

sub MD5sum {
    my ( $Self, %Param ) = @_;

    if ( !$Param{Filename} && !$Param{String} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Filename or String!',
        );
        return;
    }

    # check if file exists
    if ( $Param{Filename} && !-e $Param{Filename} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "File '$Param{Filename}' doesn't exist!",
        );
        return;
    }

    # md5sum file
    if ( $Param{Filename} ) {

        # open file
        my $FH;
        if ( !open $FH, '<', $Param{Filename} ) {    ## no critic
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Can't read '$Param{Filename}': $!",
            );
            return;
        }

        binmode $FH;
        my $MD5sum = Digest::MD5->new()->addfile($FH)->hexdigest();
        close $FH;

        return $MD5sum;
    }

    # get encode object
    my $EncodeObject = $Kernel::OM->Get('Encode');

    # md5sum string
    if ( !ref $Param{String} ) {
        $EncodeObject->EncodeOutput( \$Param{String} );
        return md5_hex( $Param{String} );
    }

    # md5sum scalar reference
    if ( ref $Param{String} eq 'SCALAR' ) {
        $EncodeObject->EncodeOutput( $Param{String} );
        return md5_hex( ${ $Param{String} } );
    }

    $Kernel::OM->Get('Log')->Log(
        Priority => 'error',
        Message  => "Need a SCALAR reference like 'String => \$Content' in String param.",
    );

    return;
}

=item Dump()

dump variable to an string

    my $Dump = $MainObject->Dump(
        $SomeVariable,
    );

    my $Dump = $MainObject->Dump(
        {
            Key1 => $SomeVariable,
        },
    );

    dump only in ascii characters (> 128 will be marked as \x{..})

    my $Dump = $MainObject->Dump(
        $SomeVariable,
        'ascii', # ascii|binary - default is binary
    );

=cut

sub Dump {
    my ( $Self, $Data, $Type ) = @_;

    # check needed data
    if ( !defined $Data ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need \$String in Dump()!"
        );
        return;
    }

    # check type
    if ( !$Type ) {
        $Type = 'binary';
    }
    if ( $Type !~ /^ascii/ && $Type ne 'binary' ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Invalid Type '$Type'!"
        );
        return;
    }

    # mild pretty print
    $Data::Dumper::Indent = 1;

    # sort hash keys
    $Data::Dumper::Sortkeys = 1;

    # suppress indention if requests
    if ( $Type =~ /noindent$/ ) {
        $Data::Dumper::Indent = 0;
    }

    # This Dump() is using Data::Dumper with a utf8 workarounds to handle
    # the bug [rt.cpan.org #28607] Data::Dumper::Dumper is dumping utf8
    # strings as latin1/8bit instead of utf8. Use Storable module used for
    # workaround.
    # -> http://rt.cpan.org/Ticket/Display.html?id=28607
    if ( $Type eq 'binary' ) {

        my $DataNew;
        {
            # The store functions will croak if they run into such references
            # unless you set $Storable::forgive_me to some TRUE value.
            # In that case, the fatal message is converted to a warning
            # and some meaningless string is stored instead.
            local $Storable::forgive_me = 1;

            # Clone the data because we need to disable the utf8 flag in all
            # reference variables and do not to want to do this in the orig.
            # variables because they will still used in the system.
            $DataNew = Storable::dclone( \$Data );
        }

        # Disable utf8 flag.
        $Self->_Dump($DataNew);

        # Dump it as binary strings.
        my $String = Dumper( ${$DataNew} );

        # Enable utf8 flag.
        Encode::_utf8_on($String);

        return $String;
    }

    # fallback if Storable can not be loaded
    my $Result = Dumper($Data);

    # reset indention;
    $Data::Dumper::Indent = 1;

    return $Result;
}

=item Flatten()

flatten a hash

    my $FlatHashRef = $MainObject->Flatten(
        Data => $SomeHashRef,
    );

    my $FlatHashRef = $MainObject->Flatten(
        Data           => $SomeHashRef,
        ArrayDelimiter => '#',        # optional, default ":"
        HashDelimiter  => '->',       # optional, default "."
    );

=cut

sub Flatten {
    my ( $Self, %Param ) = @_;

    # check needed data
    if ( !defined $Param{Data} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Data in Flatten()!"
        );
        return;
    }

    return Hash::Flatten::flatten(
        $Param{Data},
        {
            HashDelimiter  => $Param{HashDelimiter} || '.',
            ArrayDelimiter => $Param{ArrayDelimiter} || ':'
        }
    );
}

=item Unflatten()

unflatten a hash

    my $HashRef = $MainObject->Unflatten(
        Data => $SomeFlatHashRef,
    );

    my $HashRef = $MainObject->Unflatten(
        Data           => $SomeFlatHashRef,
        ArrayDelimiter => '#',        # optional, default ":"
        HashDelimiter  => '->',       # optional, default "."
    );

=cut

sub Unflatten {
    my ( $Self, %Param ) = @_;

    # check needed data
    if ( !defined $Param{Data} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Data in Unflatten()!"
        );
        return;
    }

    return Hash::Flatten::unflatten(
        $Param{Data},
        {
            HashDelimiter  => $Param{HashDelimiter} || '.',
            ArrayDelimiter => $Param{ArrayDelimiter} || ':'
        }
    );
}

=item DirectoryRead()

reads a directory and returns an array with results.

    my @FilesInDirectory = $MainObject->DirectoryRead(
        Directory => '/tmp',
        Filter    => 'Filenam*',
    );

    my @FilesInDirectory = $MainObject->DirectoryRead(
        Directory => $Path,
        Filter    => '*',
    );

read all files in subdirectories as well (recursive):

    my @FilesInDirectory = $MainObject->DirectoryRead(
        Directory => $Path,
        Filter    => '*',
        Recursive => 1,
    );

You can pass several additional filters at once:

    my @FilesInDirectory = $MainObject->DirectoryRead(
        Directory => '/tmp',
        Filter    => \@MyFilters,
    );

The result strings are absolute paths, and they are converted to utf8.

Use the 'Silent' parameter to suppress log messages when a directory
does not have to exist:

    my @FilesInDirectory = $MainObject->DirectoryRead(
        Directory => '/special/optional/directory/',
        Filter    => '*',
        Silent    => 1,     # will not log errors if the directory does not exist
    );

Platform note: MacOS (HFS+) stores filenames as Unicode NFD internally,
and DirectoryRead() will also report them as NFD.

=cut

sub DirectoryRead {
    my ( $Self, %Param ) = @_;

    # check needed params
    for my $Needed (qw(Directory Filter)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Message  => "Needed $Needed: $!",
                Priority => 'error',
            );
            return;
        }
    }

    # if directory doesn't exists stop
    if ( !-d $Param{Directory} && !$Param{Silent} ) {
        $Kernel::OM->Get('Log')->Log(
            Message  => "Directory doesn't exist: $Param{Directory}: $!",
            Priority => 'error',
        );
        return;
    }

    # check Filter param
    if ( ref $Param{Filter} ne '' && ref $Param{Filter} ne 'ARRAY' ) {
        $Kernel::OM->Get('Log')->Log(
            Message  => 'Filter param need to be scalar or array ref!',
            Priority => 'error',
        );
        return;
    }

    # prepare non array filter
    if ( ref $Param{Filter} ne 'ARRAY' ) {
        $Param{Filter} = [ $Param{Filter} ];
    }

    # executes glob for every filter
    my @GlobResults;
    my %Seen;

    for my $Filter ( @{ $Param{Filter} } ) {
        my @Glob = glob "$Param{Directory}/$Filter";

        # look for repeated values
        NAME:
        for my $GlobName (@Glob) {

            next NAME if !-e $GlobName;
            if ( !$Seen{$GlobName} ) {
                push @GlobResults, $GlobName;
                $Seen{$GlobName} = 1;
            }
        }
    }

    if ( $Param{Recursive} ) {

        # loop protection to prevent symlinks causing lockups
        $Param{LoopProtection}++;
        return if $Param{LoopProtection} > 100;

        # check all files in current directory
        my @Directories = glob "$Param{Directory}/*";

        DIRECTORY:
        for my $Directory (@Directories) {

            # return if file is not a directory
            next DIRECTORY if !-d $Directory;

            # repeat same glob for directory
            my @SubResult = $Self->DirectoryRead(
                %Param,
                Directory => $Directory,
            );

            # add result to hash
            for my $Result (@SubResult) {
                if ( !$Seen{$Result} ) {
                    push @GlobResults, $Result;
                    $Seen{$Result} = 1;
                }
            }
        }
    }

    # if no results
    return if !@GlobResults;

    # get encode object
    my $EncodeObject = $Kernel::OM->Get('Encode');

    # compose normalize every name in the file list
    my @Results;
    for my $Filename (@GlobResults) {

        # first convert filename to utf-8 if utf-8 is used internally
        $Filename = $EncodeObject->Convert2CharsetInternal(
            Text => $Filename,
            From => 'utf-8',
        );

        push @Results, $Filename;
    }

    # always sort the result
    @Results = sort @Results;

    return @Results;
}

=item GenerateRandomString()

generate a random string of defined length, and of a defined alphabet.
defaults to a length of 16 and alphanumerics ( 0..9, A-Z and a-z).

    my $String = $MainObject->GenerateRandomString();

    returns

    $String = 'mHLOx7psWjMe5Pj7';

    with specific length:

    my $String = $MainObject->GenerateRandomString(
        Length => 32,
    );

    returns

    $String = 'azzHab72wIlAXDrxHexsI5aENsESxAO7';

    with specific length and alphabet:

    my $String = $MainObject->GenerateRandomString(
        Length     => 32,
        Dictionary => [ 0..9, 'a'..'f' ], # hexadecimal
    );

    returns

    $String = '9fec63d37078fe72f5798d2084fea8ad';


=cut

sub GenerateRandomString {
    my ( $Self, %Param ) = @_;

    # get CSPRNG
    my $CSPRNGObject = Bytes::Random::Secure->new(
        Bits        => 256,
        NonBlocking => 1,
    );

    # init length for string
    my $Length = $Param{Length} || 16;

    # prepare default dictionary
    my @DictionaryChars = ( 0 .. 9, 'A' .. 'Z', 'a' .. 'z' );

    # override dictionary with custom list if given
    if ( IsArrayRefWithData( $Param{Dictionary} ) ) {
        @DictionaryChars = @{ $Param{Dictionary} };
    }

    # init dictionary string
    my $DictionaryString = join('', @DictionaryChars);

    # generate the string
    my $String = $CSPRNGObject->string_from($DictionaryString, $Length);

    return $String;
}

=item ResolveValueByKey()

resolve a value from a complex data structure

    my $Value = $MainObject->ResolveValueByKey(
        Data     => {} || [],
        Key      => '...',
        Resolver => {},            # optional, used by RuleSet
    );
=cut

sub ResolveValueByKey {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Key)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # return undef if we have no data to work through
    return if !$Param{Data};

    my $Data = $Param{Data};

    # handle comma separated variables and merge to array
    my @Keys = split( /,/, $Param{Key} );
    if ( scalar( @Keys ) > 1 ) {
        my @Result = ();

        for my $Key ( @Keys ) {
            my $KeyResult = $Self->ResolveValueByKey(
                Key      => $Key,
                Data     => $Data,
                Resolver => $Param{Resolver}
            );

            if ( ref( $KeyResult ) eq 'ARRAY' ) {
                push( @Result, @{ $KeyResult } );
            }
            else {
                push( @Result, $KeyResult );
            }
        }

        return \@Result;
    }

    my @Parts = split( /\./, $Param{Key});
    my $Attribute = shift @Parts;
    my $ArrayIndex;

    if ( $Attribute =~ /(.*?):(\d+)/ ) {
        $Attribute = $1;
        $ArrayIndex = $2;
    }

    # get the value of $Attribute
    if (exists $Data->{$Attribute} ) {
        $Data = $Data->{$Attribute};
    }
    # if not, look if there is a reverse resolver available
    elsif ( $Param{Resolver} && exists $Data->{$Param{Resolver}->{Resolves}} ) {
        $Data = $Param{Resolver}->{Handler}(
            $Param{Resolver}->{HandlerObject},
            Data => $Data->{$Param{Resolver}->{Resolves}},
        );
    }
    else {
        return;
    }

    if ( defined $ArrayIndex && IsArrayRef($Data) ) {
        $Data = $Data->[$ArrayIndex];
    }

    if ( @Parts ) {
        return $Self->ResolveValueByKey(
            Key      => join('.', @Parts),
            Data     => $Data,
            Resolver => $Param{Resolver}
        );
    }

    return $Data;
}

sub FilterObjectList {
    my ($Self, %Param) = @_;
    my @FilteredResult;

    # without useful data, we've got nothing to do
    return @FilteredResult if !IsArrayRefWithData($Param{Data});

    my $Filter = $Param{Filter} || {};

    OBJECTITEM:
    foreach my $ObjectItem ( @{$Param{Data}} ) {

        if ( IsHashRef($ObjectItem) ) {
            my $Match = 1;

            BOOLOPERATOR:
            foreach my $BoolOperator ( keys %{ $Filter } ) {
                my $BoolOperatorMatch = 1;

                FILTERITEM:
                foreach my $FilterItem ( @{ $Filter->{$BoolOperator} } ) {
                    my $FilterMatch = 1;

                    if ( !$FilterItem->{AlwaysTrue} ) {
                        # if filter attributes are not contained in the response, check if it references a sub-structure
                        if ( !exists( $ObjectItem->{ $FilterItem->{Field} } ) ) {

                            if ( $FilterItem->{Field} =~ /\./ ) {

                                # yes it does, filter sub-structure
                                my ( $SubObject, $SubField ) = split( /\./, $FilterItem->{Field}, 2 );
                                my $SubData = IsArrayRefWithData( $ObjectItem->{$SubObject} ) ? $ObjectItem->{$SubObject} : [ $ObjectItem->{$SubObject} ];
                                my %SubFilter = %{$FilterItem};
                                $SubFilter{Field} = $SubField;

                                # continue if the sub-structure attribute exists
                                if ( exists( $ObjectItem->{$SubObject} ) ) {

                                    # execute filter on sub-structure
                                    my @FilteredData = $Self->FilterObjectList(
                                        Data   => $SubData,
                                        Filter => {
                                            OR => [
                                                \%SubFilter
                                            ]
                                        }
                                    );

                                    # check filtered SubData
                                    if ( !IsArrayRefWithData( \@FilteredData ) ) {
                                        # the filter didn't match the sub-structure
                                        $FilterMatch = 0;
                                    }
                                }
                                else {
                                    # the sub-structure attribute doesn't exist, ignore this item
                                    $FilterMatch = 0;
                                }
                            }
                            else {
                                # filtered attribute not found, ignore this item
                                $FilterMatch = 0;
                            }
                        }
                        else {
                            my $FieldValue  = $ObjectItem->{ $FilterItem->{Field} } || '';
                            my $FilterValue = $FilterItem->{Value};
                            my $Type        = $FilterItem->{Type} || 'STRING';

                            # check if the value references a field in our hash and take its value in this case
                            if ( $FilterValue && $FilterValue =~ /^\$(.*?)$/ ) {
                                $FilterValue = exists( $ObjectItem->{$1} ) ? $ObjectItem->{$1} : undef;
                            }
                            elsif ($FilterValue) {
                                if ( IsStringWithData($FilterValue) && $FilterItem->{Operator} eq 'LIKE' ) {
                                    # make non word characters literal to prevent invalid regex (e.g. only opened brackets "[some*test" ==> "\[some*test")
                                    $FilterValue =~ s/([^\w\s\*\\])/\\$1/g;
                                    # remove possible unnecessary added backslash
                                    $FilterValue =~ s/\\\\/\\/g;
                                }
                                # replace wildcards with valid RegEx in FilterValue
                                $FilterValue =~ s/\*/.*?/g;
                            }
                            else {
                                $FilterValue = undef;
                            }

                            my @FieldValues = ($FieldValue);
                            if ( IsArrayRef($FieldValue) ) {
                                if (IsArrayRefWithData($FieldValue)) {
                                    @FieldValues = @{$FieldValue}
                                } else {
                                    @FieldValues = (undef);
                                }
                            }

                            # handle multiple FieldValues (array)
                            FIELDVALUE:
                            foreach my $FieldValue (@FieldValues) {
                                $FilterMatch = 1;

                                # prepare date compare
                                if ( $Type eq 'DATE' ) {

                                    # convert values to unixtime
                                    my ( $DatePart, $TimePart ) = split( /\s+/, $FieldValue );
                                    $FieldValue = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
                                        String => $DatePart . ' 12:00:00',
                                    );
                                    my ( $FilterDatePart, $FilterTimePart, $Calculations ) = split( /\s+/, $FilterValue, 3 );
                                    $FilterValue = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
                                        String => $FilterDatePart . ' 12:00:00 ' . $Calculations,
                                    );

                                    # handle this as a numeric compare
                                    $Type = 'NUMERIC';
                                }

                                # prepare datetime compare
                                elsif ( $Type eq 'DATETIME' ) {

                                    # convert values to unixtime
                                    $FieldValue = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
                                        String => $FieldValue,
                                    );
                                    $FilterValue = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
                                        String => $FilterValue,
                                    );

                                    # handle this as a numeric compare
                                    $Type = 'NUMERIC';
                                }

                                # equal (=)
                                if ( $FilterItem->{Operator} eq 'EQ' ) {
                                    if ( !$FilterValue && $FieldValue ) {
                                        $FilterMatch = 0
                                    }
                                    elsif ( $Type eq 'STRING' && ( $FieldValue || '' ) ne ( $FilterValue || '' ) ) {
                                        $FilterMatch = 0;
                                    }
                                    elsif ( $Type eq 'NUMERIC' && ( $FieldValue || 0 ) != ( $FilterValue || 0 ) ) {
                                        $FilterMatch = 0;
                                    }
                                }

                                # not equal (!=)
                                elsif ( $FilterItem->{Operator} eq 'NE' ) {
                                    if ( !$FilterValue && !$FieldValue ) {
                                        $FilterMatch = 0
                                    }
                                    elsif ( $Type eq 'STRING' && ( $FieldValue || '' ) eq ( $FilterValue || '' ) ) {
                                        $FilterMatch = 0;
                                    }
                                    elsif ( $Type eq 'NUMERIC' && ( $FieldValue || 0 ) == ( $FilterValue || 0 ) ) {
                                        $FilterMatch = 0;
                                    }
                                }

                                # less than (<)
                                elsif ( $FilterItem->{Operator} eq 'LT' ) {
                                    if ( $Type eq 'NUMERIC' && ( $FieldValue || 0 ) >= ( $FilterValue || 0 ) ) {
                                        $FilterMatch = 0;
                                    }
                                }

                                # greater than (>)
                                elsif ( $FilterItem->{Operator} eq 'GT' ) {
                                    if ( $Type eq 'NUMERIC' && ( $FieldValue || 0 ) <= ( $FilterValue || 0 ) ) {
                                        $FilterMatch = 0;
                                    }
                                }

                                # less than or equal (<=)
                                elsif ( $FilterItem->{Operator} eq 'LTE' ) {
                                    if ( $Type eq 'NUMERIC' && ( $FieldValue || 0 ) > ( $FilterValue || 0 ) ) {
                                        $FilterMatch = 0;
                                    }
                                }

                                # greater than or equal (>=)
                                elsif ( $FilterItem->{Operator} eq 'GTE' ) {
                                    if ( $Type eq 'NUMERIC' && ( $FieldValue || 0 ) < ( $FilterValue || 0 ) ) {
                                        $FilterMatch = 0;
                                    }
                                }

                                # value is contained in an array or values
                                elsif ( $FilterItem->{Operator} eq 'IN' ) {
                                    $FilterMatch = 0;
                                    foreach $FilterValue ( @{$FilterValue} ) {
                                        if ( $Type eq 'NUMERIC' ) {
                                            next if ( $FilterValue || 0 ) != ( $FieldValue || 0 );
                                        }
                                        next if $FilterValue ne $FieldValue;
                                        $FilterMatch = 1;
                                    }
                                }

                                # the string contains a part
                                elsif ( $FilterItem->{Operator} eq 'CONTAINS' ) {
                                    my $FilterValueQuoted = quotemeta $FilterValue;
                                    if ( $Type eq 'STRING' && $FieldValue !~ /$FilterValueQuoted/i ) {
                                        $FilterMatch = 0;
                                    }
                                }

                                # the string starts with the part
                                elsif ( $FilterItem->{Operator} eq 'STARTSWITH' ) {
                                    my $FilterValueQuoted = quotemeta $FilterValue;
                                    if ( $Type eq 'STRING' && $FieldValue !~ /^$FilterValueQuoted/i ) {
                                        $FilterMatch = 0;
                                    }
                                }

                                # the string ends with the part
                                elsif ( $FilterItem->{Operator} eq 'ENDSWITH' ) {
                                    my $FilterValueQuoted = quotemeta $FilterValue;
                                    if ( $Type eq 'STRING' && $FieldValue !~ /$FilterValueQuoted$/i ) {
                                        $FilterMatch = 0;
                                    }
                                }

                                # the string matches the pattern
                                elsif ( $FilterItem->{Operator} eq 'LIKE' ) {
                                    if ( $Type eq 'STRING' && $FieldValue !~ /^$FilterValue$/im ) {
                                        $FilterMatch = 0;
                                    }
                                }

                                last FIELDVALUE if $FilterMatch;
                            }
                        }
                    }

                    if ( $FilterItem->{Not} ) {

                        # negate match result
                        $FilterMatch = !$FilterMatch;
                    }

                    # abort filters for this bool operator, if we have a non-match
                    if ( $BoolOperator eq 'AND' && !$FilterMatch ) {

                        # signal the operator that it didn't match
                        $BoolOperatorMatch = 0;
                        last FILTERITEM;
                    }
                    elsif ( $BoolOperator eq 'OR' && $FilterMatch ) {

                        # we don't need to check more filters in this case
                        $BoolOperatorMatch = 1;
                        last FILTERITEM;
                    }
                    elsif ( $BoolOperator eq 'OR' && !$FilterMatch ) {
                        $BoolOperatorMatch = 0;
                    }

                    last FILTERITEM if $FilterItem->{StopAfterMatch};
                }

                # abort filters for this object, if we have a non-match in the operator filters
                if ( !$BoolOperatorMatch ) {
                    $Match = 0;
                    last BOOLOPERATOR;
                }
            }

            # all filter criteria match, add to result
            if ($Match) {
                push @FilteredResult, $ObjectItem;
            }
        }
    }

    return @FilteredResult;
}

=item GetUnique()

returns an array with unique values
keeps original order of kept elements

    my @UniqueValuesArray = $MainObject->GetUnique(@NonUniqueValuesArray);

=cut

sub GetUnique {
    my ( $Self, @Array ) = @_;
    my %Known;
    return grep { !$Known{$_}++ } @Array;
}

=item GetCombinedList()

returns combined array of two lists - value order may be changed

    my @CombinedList = $MainObject->GetCombinedList(
        ListA => \@Array,
        ListB => \@Array,
        Union => 0|1                # Default: 0
    );

    e.g.
        ListA = [ 1, 2, 3, 4 ]
        ListB = [ 2, 4, 5 ]

        as union = [1, 2, 3, 4, 5 ]
        as intersect = [ 2, 4 ]


=cut

sub GetCombinedList {
    my ( $Self, %Param ) = @_;

    my %Union;
    my %Isect;
    for my $E ( $Self->GetUnique( @{ $Param{ListA} } ), $Self->GetUnique( @{ $Param{ListB} } ) ) {
        $Union{$E}++ && $Isect{$E}++
    }

    return $Param{Union} ? keys %Union : keys %Isect;
}

=item GetCombinedListKeepOrder()

returns combined array of two lists and keeps order (ListA is crucial)

    my @CombinedList = $MainObject->GetCombinedListKeepOrder(
        ListA     => \@Array,
        ListB     => \@Array,
        Union     => 0|1                # Default: 0
    );

    e.g.
        ListA = [ 1, 2, 3, 4 ]
        ListB = [ 2, 4, 5 ]

        as union = [1, 2, 3, 4, 5 ]
        as intersect = [ 2, 4 ]


=cut

sub GetCombinedListKeepOrder {
    my ( $Self, %Param ) = @_;

    my (%Known, @Union, @Isect);

    # switch lists if necessary (last list defines order on intersection)
    my @List = $Param{Union} ?
        ( $Self->GetUnique( @{ $Param{ListA} } ), $Self->GetUnique( @{ $Param{ListB} } ) ) :
        ( $Self->GetUnique( @{ $Param{ListB} } ), $Self->GetUnique( @{ $Param{ListA} } ) );

    for my $E ( @List ) {
        if($Known{$E}) {
            push(@Isect,$E);
        } else {
            push(@Union,$E);
            $Known{$E} = 1;
        }
    }

    return $Param{Union} ? @Union : @Isect;
}

=item ReplaceVariables()

recursively replace variables with values

    my $Result = $MainObject->ReplaceVariables(
        Data      => {...},
        Variables => {...},
    );

returns: the "Data" parameter with replaced variables

=cut

sub ReplaceVariables {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Data};

    $Param{Variables} //= {};

    if ( IsHashRefWithData($Param{Data}) ) {
        foreach my $Key ( sort keys %{$Param{Data}} ) {
            $Param{Data}->{$Key} = $Self->ReplaceVariables(
                Data      => $Param{Data}->{$Key},
                Variables => $Param{Variables}
            );
        }
    }
    elsif ( IsArrayRefWithData($Param{Data}) ) {
        foreach my $Item ( @{$Param{Data}} ) {
            $Item = $Self->ReplaceVariables(
                Data      => $Item,
                Variables => $Param{Variables}
            );
        }
    }
    else {
        # init index for temp variables
        my $VariableFilterValueIndex = 0;

        # let leading be greedy - start with innermost variable
        while ( $Param{Data} =~ /^(.*)(\$\{([-a-zA-Z0-9_.,: ]+)(?:\|((?:[^\{\}]+|\{(?-1)\})*))?\})(.*?)$/xs ) {
            my $Leading    = $1;
            my $Expression = $2;
            my $Variable   = $3;
            my $Filter     = $4;
            my $Trailing   = $5;

            my $Value = $Self->ResolveValueByKey(
                Key  => $Variable,
                Data => $Param{Variables},
            );

            if ( $Filter ) {
                $Value = $Self->ApplyVariableFilters(
                    Data             => $Value,
                    FilterExpression => $Filter,
                );
            }

            # variable is part of a string, we have to do a string replace
            if ( $Leading || $Trailing ) {
                # value is a data structure, replace with temp variable
                if ( ref( $Value ) ) {
                    # increment index
                    $VariableFilterValueIndex += 1;

                    # store value in variables
                    $Self->{VariableFilterValue}->{ $VariableFilterValueIndex } = $Value;

                    # replace current variable with variable filter value
                    $Param{Data} =~ s/\Q$Expression\E/<VariableFilterValue$VariableFilterValueIndex>/gxs;
                }
                # replace value as string
                else {
                    $Param{Data} =~ s/\Q$Expression\E/$Value/gxs;
                }
            }
            else {
                # variable is an assignment, we can replace it with the actual value (i.e. Object)
                $Param{Data} = $Value;
            }
        }
    }

    return $Param{Data};
}

=item ApplyVariableFilters()

apply the given variable filters to the data

    my $Result = $MainObject->ApplyVariableFilters(
        Data             => {...},
        FilterExpression => {...},
    );

=cut

sub ApplyVariableFilters {
    my ( $Self, %Param ) = @_;

    return $Param{Data} if !$Param{FilterExpression};

    my @Filters = split(/\|/, $Param{FilterExpression});

    my $Value = $Param{Data};

    foreach my $Filter ( @Filters ) {
        # cleanup leading and trailing spaces
        $Filter =~ s/^\s+|\s+$//;

        # skip empty filter
        next if !$Filter;

        if ( $Filter =~ /^(?:JSON|ToJSON)$/i ) {
            if ( defined( $Value ) ) {
                $Value = $Kernel::OM->Get('JSON')->Encode(
                    Data => $Value
                );
                $Value =~ s/^"//;
                $Value =~ s/"$//;
            }
            else {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "\"$Filter\" need defined data!"
                );
            }
        }
        elsif ( $Filter =~ /^FromJSON$/i ) {
            if ( IsStringWithData( $Value ) ) {
                $Value = $Kernel::OM->Get('JSON')->Decode(
                    Data => $Value
                );
            }
            else {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "\"$Filter\" need string with data!"
                );
            }
        }
        elsif ( $Filter =~ /^jq\((.*)\)$/i ) {
            my $JqExpression = $1;
            if ( $JqExpression ) {
                if ( IsStringWithData( $Value ) ) {
                    $JqExpression =~ s/\s+::\s+/|/g;
                    $JqExpression =~ s/&quot;/"/g;

                    $Value = $Kernel::OM->Get('JSON')->Jq(
                        Data   => $Value,
                        Filter => $JqExpression,
                    );
                }
                else {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => "\"$Filter\" need string with data!"
                    );
                }
            }
            else {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "\"$Filter\" has no jq expression!"
                );
            }
        }
        elsif ( $Filter =~ /^(?:base64|ToBase64)$/i ) {
            if ( defined( $Value ) ) {
                $Value = MIME::Base64::encode_base64($Value);
                $Value =~ s/\n//g;
            }
            else {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "\"$Filter\" need defined data!"
                );
            }
        }
        elsif ( $Filter =~ /^FromBase64$/i ) {
            if ( IsStringWithData( $Value ) ) {
                $Value = MIME::Base64::decode_base64($Value);
            }
            else {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "\"$Filter\" need string with data!"
                );
            }
        }
        else {
            $Filter =~ s/(?<filter>.+?)\((?<parameter>.+)\)/$+{filter}/;
            my $Parameter = $+{parameter};

            # check for stored variable filter value
            if ( $Parameter && $Parameter =~ m/^<VariableFilterValue([1-9][0-9]*)>$/xms ) {
                my $VariableFilterValueIndex = $1;
                $Parameter = $Self->ResolveValueByKey(
                    Key  => $VariableFilterValueIndex,
                    Data => $Self->{VariableFilterValue},
                );
            }

            if ( !$Self->{VariableFilters}->{$Filter} ) {
                # try to load the filter handler
                $Self->_LoadVariableFilterHandler(
                    Name => $Filter
                );
            }
            if ( !$Self->{VariableFilters}->{$Filter} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unknown filter \"$Filter\"!"
                );
                return $Value;
            }

            $Value = $Self->{VariableFilters}->{$Filter}->(
                $Self,
                Value     => $Value,
                Parameter => $Parameter
            )
        }
    }

    return $Value;
}

=item GetAssignedSearchParams()

prepares and transform config from AssignedObjectsMapping to a simple hash

    my %SearchData = $Self->_GetAssignedSearchParams(
        ObjectType         => 'Contact',
        Object             => $ContactHash,         # (optional)
        AssignedObjectType => 'Ticket'
    );

    e.g. if AssignedObjectType is 'Ticket'

    %SearchData = (
        ContactID      => 1,
        OrganisationID => 2,
        ...
    );

=cut

sub GetAssignedSearchParams {
    my ( $Self, %Param ) = @_;

    for my $Needed ( qw(AssignedObjectType ObjectType) ) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my $MappingString = $Kernel::OM->Get('Config')->Get('AssignedObjectsMapping') || '';

    my %SearchData;
    if ( IsStringWithData($MappingString) ) {

        my $Mapping = $Kernel::OM->Get('JSON')->Decode(
            Data   => $MappingString,
            Silent => $Param{Silent} || 0
        );

        if ( !IsHashRefWithData($Mapping) ) {
            if (
                !defined $Param{Silent}
                || !$Param{Silent}
            ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Invalid JSON for sysconfig option 'AssignedObjectsMapping'."
                );
            }
        } elsif (
            IsHashRefWithData( $Mapping->{ $Param{ObjectType} } ) &&
            IsHashRefWithData( $Mapping->{ $Param{ObjectType} }->{ $Param{AssignedObjectType} } )
        ) {
            my %SearchAttributes = %{ $Mapping->{ $Param{ObjectType} }->{ $Param{AssignedObjectType} } };

            # prepare search data
            for my $SearchAttribute ( keys %SearchAttributes ) {
                next if (!$SearchAttribute);

                next if ( !IsHashRefWithData( $SearchAttributes{$SearchAttribute} ) );
                my $ObjectSearchAttributes = $SearchAttributes{$SearchAttribute}->{SearchAttributes};
                my $SearchStatics          = $SearchAttributes{$SearchAttribute}->{SearchStatic};
                next if ( !IsArrayRefWithData( $ObjectSearchAttributes ) && !IsArrayRefWithData($SearchStatics) );

                $SearchAttribute =~ s/^\s+//g;
                $SearchAttribute =~ s/\s+$//g;

                next if (!$SearchAttribute);

                $SearchData{$SearchAttribute} = [];

                # get attributes search data
                if (IsHashRefWithData( $Param{Object} )) {
                    for my $ObjectSearchAttribute ( @{$ObjectSearchAttributes} ) {
                        my $Value;

                        # check if value from sub-object (e.g. User of Contact)
                        if ( $ObjectSearchAttribute =~ /.+\..+/ ) {
                            my @AttributStructure = split(/\./, $ObjectSearchAttribute);
                            next if ( !$AttributStructure[0] || !$AttributStructure[1] || !IsHashRefWithData( $Param{Object}->{$AttributStructure[0]} ) );
                            $Value = $Param{Object}->{$AttributStructure[0]}->{$AttributStructure[1]}
                        } else {
                            $Value = $Param{Object}->{$ObjectSearchAttribute};
                        }

                        next if ( !defined $Value );

                        push (
                            @{ $SearchData{$SearchAttribute} },
                            IsArrayRefWithData($Value) ? @{$Value} : $Value
                        );
                    }
                }

                # get static search data
                for my $SearchStatic ( @{$SearchStatics} ) {
                    next if ( !defined $SearchStatic );
                    push ( @{ $SearchData{$SearchAttribute} }, $SearchStatic );
                }

                if (!scalar(@{ $SearchData{$SearchAttribute} })) {
                    delete $SearchData{$SearchAttribute};
                }
            }
        } else {
            if (
                !defined $Param{Silent}
                || !$Param{Silent}
            ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'info',
                    Message  => "type '$Param{ObjectType}' or sub-type '$Param{AssignedObjectType}' not contained in 'AssignedObjectsMapping'."
                );
            }
        }
    }

    return %SearchData;
}

=begin Internal:

=cut

sub _LoadVariableFilterHandler {
    my ( $Self, %Param ) = @_;

    $Self->{VariableFilters} //= {};

    my $VariableFilters = $Kernel::OM->Get('Config')->Get('Automation::VariableFilter');
    if ( !IsHashRefWithData($VariableFilters) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No variable filter handlers registered!"
        );
        next;
    }

    my $Name = (split('\.', $Param{Name}, 2))[0];

    if (!$VariableFilters->{$Name}) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No filter handler for filter \"$Param{Name}\" registered!"
        );
        next;
    }
    return if !$Self->Require($VariableFilters->{$Name});

    my $Module = $VariableFilters->{$Name}->new( %{$Self} );
    if ( !$Module ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to create instance of $VariableFilters->{Name}!"
        );
        return;
    }

    if ( !$Module->can('GetFilterHandler') ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Module \"$VariableFilters->{$Name}\" cannot \"GetFilterHandler\"!"
        );
        next;
    }

    my %Handler = $Module->GetFilterHandler();

    for my $HandlerName ( keys %Handler ) {
        next if (!$HandlerName);
        if (
            !$Handler{$HandlerName} ||
            ref $Handler{$HandlerName} ne 'CODE'
        ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "$HandlerName is no function!"
            );
            next;
        }
        $Self->{VariableFilters}->{$HandlerName} = $Handler{$HandlerName};

        # TODO: better solution needed for filtername with mismatching name
        # check filtername
        if (
            $HandlerName ne $Param{Name}
            && lc( $HandlerName ) eq lc( $Param{Name} )
        ) {
            $Self->{VariableFilters}->{ $Param{Name} } = $Handler{ $HandlerName };
        }
    }
}

sub _Dump {
    my ( $Self, $Data ) = @_;

    # data is not a reference
    if ( !ref ${$Data} ) {
        Encode::_utf8_off( ${$Data} );

        return;
    }

    # data is a scalar reference
    if ( ref ${$Data} eq 'SCALAR' ) {

        # start recursion
        $Self->_Dump( ${$Data} );

        return;
    }

    # data is a hash reference
    if ( ref ${$Data} eq 'HASH' ) {
        KEY:
        for my $Key ( sort keys %{ ${$Data} } ) {
            next KEY if !defined ${$Data}->{$Key};

            # start recursion
            $Self->_Dump( \${$Data}->{$Key} );

            my $KeyNew = $Key;

            $Self->_Dump( \$KeyNew );

            if ( $Key ne $KeyNew ) {

                ${$Data}->{$KeyNew} = ${$Data}->{$Key};
                delete ${$Data}->{$Key};
            }
        }

        return;
    }

    # data is a array reference
    if ( ref ${$Data} eq 'ARRAY' ) {
        KEY:
        for my $Key ( 0 .. $#{ ${$Data} } ) {
            next KEY if !defined ${$Data}->[$Key];

            # start recursion
            $Self->_Dump( \${$Data}->[$Key] );
        }

        return;
    }

    # data is a ref reference
    if ( ref ${$Data} eq 'REF' ) {

        # start recursion
        $Self->_Dump( ${$Data} );

        return;
    }

    $Kernel::OM->Get('Log')->Log(
        Priority => 'error',
        Message  => "Unknown ref '" . ref( ${$Data} ) . "'!",
    );

    return;
}


1;

=end Internal:





=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
