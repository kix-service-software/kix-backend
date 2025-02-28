#!/usr/bin/perl
# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use File::Find;

# prepare current year
my $CURRENT_YEAR = ( localtime() )[5] + 1900;

# Check if directory argument is provided
if ( @ARGV < 1 ) {
    print "update_copyright_year.pl\n";
    print "Copyright (C) 2006-$CURRENT_YEAR KIX Service Software GmbH, https://www.kixdesk.com/\n";
    print "USAGE: update_copyright_year.pl <directory>\n";
    exit -1;
}

my $Directory = $ARGV[0];

# Define file extensions and their comment styles
my %FileTypes = (
    '.pm'   => '#',
    '.psgi' => '#',
    '.t'    => '#',
    '.pl'   => '#',
    '.tt'   => '##',
    '.js'   => '//',
    '.sh'   => '#',
    '/api'  => '#',
    '.css'  => '',
    '.html' => '//',
);

# Define some copyright lines for checks and replacements
my $CurrentCopyrightLine  = "Copyright (C) 2006-$CURRENT_YEAR KIX Service Software GmbH, https://www.kixdesk.com/";
my $PreYearCopyrightLine  = 'Copyright (C) 2006-';
my $PostYearCopyrightLine = ' KIX Service Software GmbH, https://www.kixdesk.com';

# Process files in the given directory
find(\&process_file, $Directory);

sub process_file {
    my $File = $File::Find::name;  # Get complete pathname to the file

    return if ( -d $File );                         # Skip directories
    return if ( $File =~ m/\/cpan-lib\/|\.git/ );   # Skip files in specific directories

    EXTENSION:
    for my $Extension ( keys( %FileTypes ) ) {
        if ( $File =~ m/\Q$Extension\E$/ ) {
            update_copyright( $File, $Extension );

            last EXTENSION;
        }
    }

    return;
}

sub update_copyright {
    my ( $File, $Extension ) = @_;

    # read file
    open my $fh_in, '<', $File or die "Cannot open file $File: $!";
    my @Lines = <$fh_in>;
    close $fh_in;

    # get CommentStyle
    my $CommentStyle = $FileTypes{ $Extension };

    # check file for existing header
    my $Modified = 0;
    LINE:
    for my $Line ( @Lines ) {
        # file starts with comment lines
        if (
            (
                $Extension eq '.css'
                && (
                    $Line =~ m/^\/\*\*/
                    || $Line =~ m/^\s\*/
                )
            )
            || (
                $Extension eq '.html'
                && $Line =~ m/^<!DOCTYPE/
            )
            || (
                $Extension ne '.css'
                && $Line =~ m/^\Q$CommentStyle\E/
            )
        ) {
            # remember line before substitution
            my $OriginalLine = $Line;

            # check for matching copyright line
            if ( $Line =~ s/\Q$PreYearCopyrightLine\E\d{4}\Q$PostYearCopyrightLine\E\/?/$CurrentCopyrightLine/ ) {
                # file need update for existing copyright line
                if ( $OriginalLine ne $Line ) {
                    $Modified = 1;
                }
                # file has correct copyright line
                else {
                    return;
                }

                last LINE;
            }
        }
        # reached below header, no copyright line found
        else {
            last LINE;
        }
    }

    # no copyright line found that has to be updated, add header
    if ( !$Modified ) {
        # prepare copyright header
        my $KIXHEADER;
        # special preparation for CSS copyright header
        if ( $Extension eq '.css' ) {
            $KIXHEADER = <<"END";
/** --
 * Copyright (C) 2006-$CURRENT_YEAR KIX Service Software GmbH, https://www.kixdesk.com
 * --
 * This software comes with ABSOLUTELY NO WARRANTY. For details, see
 * the enclosed file LICENSE-AGPL for license information (AGPL). If you
 * did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
 * --
 */
END
        }
        # default preparation for copyright header
        else {
            $KIXHEADER = <<"END";
$CommentStyle --
$CommentStyle Copyright (C) 2006-$CURRENT_YEAR KIX Service Software GmbH, https://www.kixdesk.com
$CommentStyle --
$CommentStyle This software comes with ABSOLUTELY NO WARRANTY. For details, see
$CommentStyle the enclosed file LICENSE-AGPL for license information (AGPL). If you
$CommentStyle did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
$CommentStyle --
END
        }

        # Check for special fist line (shebang and doctype)
        my $FirstLine;
        if ( $Extension =~ /^(?:\.pl|\.pm|\.t)$/ ) {
            $FirstLine = $Lines[0] if ( $Lines[0] =~ /^#!/ );
        }
        elsif ( $Extension eq '.html' ) {
            $FirstLine = $Lines[0] if ( $Lines[0] =~ /^<!DOCTYPE/ );
        }

        # remove first line if special line was detected
        if ( $FirstLine ) {
            shift( @Lines );
        }

        # add default copyright header
        unshift( @Lines, ( $KIXHEADER ) );

        # restore first line if special line was detected
        if ( $FirstLine ) {
            unshift( @Lines, $FirstLine );
        }
    }

    # update file
    open my $fh_out, '>', $File or die "Cannot write to file $File: $!";
    print $fh_out @Lines;
    close $fh_out;

    return;
}
