# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::LogFile;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DB',
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::LogFile - retrieve log files

=head1 SYNOPSIS

Log file functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item LogFileGet()

get LogFile

    my %LogFile = $LogFileObject->LogFileGet(
        ID        => '...'           # required
        NoContent => 0|1             # optional
    );

=cut

sub LogFileGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

    # get log files
    my %LogFileList = $Self->LogFileList();

    my $LogDir = $Kernel::OM->Get('Kernel::Config')->Get('Home') . '/var/log';
    my $Filename = $LogFileList{$Param{ID}};
    $Filename    =~ s/\//_/g;

    my $Stat = $Kernel::OM->Get('Kernel::System::Main')->FileStat(
        Location => $LogDir.'/'.$LogFileList{$Param{ID}},
    );

    if ( !$Stat ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Unable to read log file: $LogFileList{$Param{ID}} (ID: $Param{ID})!",
        );
        return;
    }

    my %LogFile = (
        ID             => $Param{ID},
        Filename       => $Filename,
        DisplayName    => $LogFileList{$Param{ID}},
        AccessTimeUnix => $Stat->atime(),
        AccessTime     => $TimeObject->SystemTime2TimeStamp( SystemTime => $Stat->atime()),
        CreateTimeUnix => $Stat->ctime(),
        CreateTime     => $TimeObject->SystemTime2TimeStamp( SystemTime => $Stat->ctime()),
        ModifyTimeUnix => $Stat->mtime(),
        ModifyTime     => $TimeObject->SystemTime2TimeStamp( SystemTime => $Stat->mtime()),
    );

    # rename Filesize to FilesizeRaw
    $LogFile{FilesizeRaw} = 0 + $Stat->size();

    # human readable file size
    if ( $LogFile{FilesizeRaw} ) {
        if ( $LogFile{FilesizeRaw} > ( 1024 * 1024 ) ) {
            $LogFile{Filesize} = sprintf "%.1f MBytes", ( $LogFile{FilesizeRaw} / ( 1024 * 1024 ) );
        }
        elsif ( $LogFile{FilesizeRaw} > 1024 ) {
            $LogFile{Filesize} = sprintf "%.1f KBytes", ( ( $LogFile{FilesizeRaw} / 1024 ) );
        }
        else {
            $LogFile{Filesize} = $LogFile{FilesizeRaw} . ' Bytes';
        }
    }

    if ( !$Param{NoContent} ) {
        my $Content = $Kernel::OM->Get('Kernel::System::Main')->FileRead(
            Location => $LogDir.'/'.$LogFileList{$Param{ID}},
        );

        if ( !$Content ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Unable to read log file: $LogFileList{$Param{LogFileID}} (ID: $Param{ID})!",
            );
            return;
        }

        $LogFile{Content} = $$Content;
    }

    return %LogFile;
}

=item LogFileList()

get list of log files

    my %List = $LogFileObject->LogFileList();

=cut

sub LogFileList {
    my ( $Self, %Param ) = @_;
    my %LogFileList;

    my $LogDir = $Kernel::OM->Get('Kernel::Config')->Get('Home') . '/var/log';

    my @Files = $Kernel::OM->Get('Kernel::System::Main')->DirectoryRead(
        Directory => $LogDir,
        Filter    => '*',
        Recursive => 1,
    );

    foreach my $File ( sort @Files ) {
        next if $File =~ /\.gitkeep/;        
        next if ! -f $File;

        my $Filename = $File;
        $Filename =~ s{$LogDir/}{}g;

        my $MD5sum = $Kernel::OM->Get('Kernel::System::Main')->MD5sum(
            String => $Filename
        );
        $LogFileList{$MD5sum} = $Filename;
    }

    return %LogFileList;
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
