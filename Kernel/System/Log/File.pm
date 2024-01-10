# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Log::File;

use strict;
use warnings;

use Date::Pcalc qw(Week_of_Year);
use File::Basename;
use File::stat;

our @ObjectDependencies = (
    'Config',
    'Encode',
);

our %DefaultLogFormats = (
    ''       => '[Error][${Module}] Priority: \'${Priority}\' not defined! Message: ${Message}',
    'debug'  => '[Debug][${Module}][${Line}] ${Message}',
    'info'   => '[Info][${Module}] ${Message}',
    'notice' => '[Notice][${Module}] ${Message}',
    'error'  => '[Error][${Module}][${Line}] ${Message}',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    # default log formats
    $Self->{LogFormats} = $Param{LogFormats} || \%DefaultLogFormats;

    # get logfile location
    $Self->{LogFile} = $Param{LogFile} || $ConfigObject->Get('LogModule::LogFile')
        || die 'Need LogModule::LogFile config';

    # get log file rotation
    my $Rotation = $ConfigObject->Get('LogModule::LogFile::Rotate') || 'never';

    if ( $Rotation eq 'hourly' ) {
        my ( $s, $m, $h, $D, $M, $Y, $WD, $YD, $DST ) = localtime( time() );    ## no critic
        $Y = $Y + 1900;
        $M = sprintf '%02d', ++$M;
        $D = sprintf '%02d', $D;
        $h = sprintf '%02d', $h;
        $Self->{LogFile} .= ".$Y-$M-$D-$h";
    }
    elsif ( $Rotation eq 'daily' ) {
        my ( $s, $m, $h, $D, $M, $Y, $WD, $YD, $DST ) = localtime( time() );    ## no critic
        $Y = $Y + 1900;
        $M = sprintf '%02d', ++$M;
        $D = sprintf '%02d', $D;
        $Self->{LogFile} .= ".$Y-$M-$D";
    }
    if ( $Rotation eq 'weekly' ) {
        my ( $s, $m, $h, $D, $M, $Y, $WD, $YD, $DST ) = localtime( time() );    ## no critic
        $Y = $Y + 1900;
        my ($Week, $Year) = Week_of_Year($Y, $M+1, $D);
        $Week = sprintf '%02d', $Week;
        $Self->{LogFile} .= ".$Y-cw$Week";
    }
    elsif ( $Rotation eq 'monthly' ) {
        my ( $s, $m, $h, $D, $M, $Y, $WD, $YD, $DST ) = localtime( time() );    ## no critic
        $Y = $Y + 1900;
        $M = sprintf '%02d', ++$M;
        $Self->{LogFile} .= ".$Y-$M";
    }

    # determine max file size
    $Self->{LogFileMaxSize} = uc($ConfigObject->Get('LogModule::LogFile::MaxSize')) || 0;

    if ( $Self->{LogFileMaxSize} =~ /^(\d+)(|K|M|G)$/ ) {
        my $Size = $1;
        if ( $2 ) {
            $Size *= 1024 if ( $2 eq 'K' );
            $Size *= 1024 * 1024 if ( $2 eq 'M' );
            $Size *= 1024 * 1024 * 1024 if ( $2 eq 'G' );
        }
        $Self->{LogFileMaxSize} = $Size;
    }

    # cleanup old file not to keep
    my $Keep = $ConfigObject->Get('LogModule::LogFile::Keep') || 0;

    if ( $Keep ) {
        my $LogDir   = dirname($Self->{LogFile});
        my $Basename = basename($Self->{LogFile});

        my @Files = $Kernel::OM->Get('Main')->DirectoryRead(
            Directory => $LogDir,
            Filter    => $Basename.'*',
            Silent    => 1,
        );

        # rotate all other log files
        my %FileModTime;
        foreach my $File ( @Files ) {
            $FileModTime{$File} = stat($File)->mtime;
        }

        @Files = sort { $FileModTime{$a} cmp $FileModTime{$b} } keys %FileModTime;
        my $FileCount = @Files;
        foreach my $File ( @Files ) {
            last if $FileCount <= $Keep;
            unlink($File);
            $FileCount--;
        }
    }

    return $Self;
}

sub Log {
    my ( $Self, %Param ) = @_;

    my $FH;

    my $LogMessage = '[' . localtime() . ']'.$Self->{LogFormats}->{lc $Param{Priority}}."\n";

    $LogMessage =~ s/\$\{(.*?)\}/$Param{$1}/g;

    if ( lc $Param{Priority} eq 'error' ) {
        # print error messages to STDERR
        print STDERR $LogMessage;
    }

    # get log file max size
    if ( $Self->{LogFileMaxSize} ) {
        my $FileStats = stat($Self->{LogFile});

        if ( $Self->{LogFileMaxSize} && $FileStats && $Self->{LogFileMaxSize} <= $FileStats->size + length $LogMessage ) {
            my $LogDir   = dirname($Self->{LogFile});
            my $Filename = basename($Self->{LogFile});

            my @Files = $Kernel::OM->Get('Main')->DirectoryRead(
                Directory => $LogDir,
                Filter    => $Filename.'_*',
                Silent    => 1,
            );

            # rotate all other log files
            foreach my $File ( reverse sort @Files ) {
                if ( $File =~ /^(.*?)_(\d+)$/ ) {
                    my $Basename   = $1;
                    my $NewCounter = $2;
                    rename($File, $Basename . '_' . ++$NewCounter);
                }
            }

            # rotate the first file
            rename($Self->{LogFile}, "$Self->{LogFile}_1");
        }
    }

    # check and create target directory
    my $LogDir = dirname($Self->{LogFile});
    if ( !-e $LogDir ) {
        if ( !mkdir( $LogDir, 0770 ) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Can't create directory '$LogDir': $!",
            );
        }
    }

    # open logfile
    ## no critic
    if ( !open $FH, '>>', $Self->{LogFile} ) {
        ## use critic

        # print error screen
        print STDERR "\n";
        print STDERR " >> Can't write $Self->{LogFile}: $! <<\n";
        print STDERR "\n";
        return;
    }

    # write log file
    $Kernel::OM->Get('Encode')->SetIO($FH);

    print $FH $LogMessage;

    # close file handle
    close $FH;

    return 1;
}

=item CleanUp()

delete all log files

    $LogObject->CleanUp();

=cut

sub CleanUp {
    my ( $Self, %Param ) = @_;

    my @Files = $Kernel::OM->Get('Main')->DirectoryRead(
        Directory => dirname($Self->{LogFile}),
        Filter    => '*',
        Recursive => 1,
        Silent    => 1,
    );
    foreach my $File ( sort @Files ) {
        next if $File =~ /TicketCounter\.log$/;

        $Kernel::OM->Get('Main')->FileDelete(
            Location        => $File,
            DisableWarnings => 1,
        );
    }

    return 1;
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
