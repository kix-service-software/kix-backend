#!/usr/bin/perl
# --
# Copyright (C) 2006-2020, KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use File::Basename;

my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime();
my $CURRENT_YEAR = $year + 1900;

# check if directory is given
if ( scalar(@ARGV) < 1 ) {
    print "kix.ModifyCopyright.pl\n";
    print "Copyright (C) 2006-$CURRENT_YEAR KIX Service Software GmbH, https://www.kixdesk.com/\n";
    print "USAGE: kix.ModifyCopyright.pl <otrs archive file> <directory>\n";
    exit -1;
}

my $OTRSArchiveFile = $ARGV[0];
my $Directory = $ARGV[1];

# read OTRS archive file
my %OTRSArchive;
open(FILE, "$OTRSArchiveFile") || die "File not found";
my @Lines = <FILE>;
close(FILE);
foreach my $Line ( @Lines ) {
    chomp $Line;
    my ($MD5, $Filename) = split(/::/, $Line);
    $OTRSArchive{$Filename} = $MD5;
}

# get pm-files and modify
my $FileList = `find $Directory -name "*.pm"`;
_ModifyPerl($FileList);

# get t-files and modify
$FileList = `find $Directory -name "*.t"`;
_ModifyPerl($FileList);

# get pl-files and modify
$FileList = `find $Directory -name "*.pl"`;
_ModifyPerl($FileList);

# get tt-files and modify
$FileList = `find $Directory -name "*.tt"`;
_ModifyTemplate($FileList);

# get js-files and modify
$FileList = `find $Directory -name "*.js"`;
_ModifyJS($FileList);

# get css-files and modify
$FileList = `find $Directory -name "*.css"`;
_ModifyCSS($FileList);

## Internal methods
# modify perl-files
sub _ModifyPerl {
    my ( $FileList ) = @_;

    my $OTRSHEADER = "# --
# Modified version of the work: Copyright (C) 2006-$CURRENT_YEAR KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --
";

    my $KIXHEADER = "# --
# Copyright (C) 2006-$CURRENT_YEAR KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --
";

    my $FOOTER = "
=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
";

    FILE:
    foreach my $File (split(/\n/, $FileList)) {
        next FILE if ( $File =~ m{(/cpan-lib/|\.git)} );

        my $OTRSFile = _IsOTRSFile($File);

        print STDOUT "(".($OTRSFile ? "OTRS" : "KIX").") $File\n";

        open(FILE, "<$File") || die "File not found";
        my @Lines = <FILE>;
        close(FILE);

        my $IsContent = 0;
        my $Shebang;
        my @ContentLines;
        for my $Line ( @Lines ) {
            if (!$IsContent && $Line =~ /#!\// ) {
               $Shebang = $Line;
            }
            if ( !$IsContent && $Line !~ m/^#/ ) {
               $IsContent = 1
            }
            if ( $IsContent && $Line =~ m/^=back/ && $File !~ /modify_copyrights\.pl$/ ) {
               last;
            }
            next if !$IsContent;
            push(@ContentLines, $Line);
        }

        open(FILE, ">$File") || die "File not found";

        # print Shebang line, if needed
        if ( $Shebang ) {
            print FILE $Shebang;
        }

        # print header
        if ( !$OTRSFile ) {
            print FILE $KIXHEADER;
        } else {
            print FILE $OTRSHEADER;
        }

        # print content
        print FILE @ContentLines;

        # print footer
        print FILE $FOOTER;

        close(FILE);
    }

    return 1;
}

sub _ModifyTemplate {
    my ( $FileList ) = @_;

    my $OTRSHEADER = "# --
# Modified version of the work: Copyright (C) 2006-$CURRENT_YEAR KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --
";

    my $CAPEHEADER = "# --
# Copyright (C) 2006-$CURRENT_YEAR KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --
";

    FILE:
    foreach my $File (split(/\n/, $FileList)) {
        next FILE if ( $File =~ m{(/cpan-lib/|\.git)} );

        my $OTRSFile = _IsOTRSFile($File);

        print STDOUT "(".($OTRSFile ? "OTRS" : "KIX").") $File\n";

        open(FILE, "<$File") || die "File not found";
        my @Lines = <FILE>;
        close(FILE);

        my $IsContent = 0;
        my @ContentLines;
        for my $Line ( @Lines ) {
            if (!$IsContent && $Line !~ m/^#/ ) {
               $IsContent = 1
            }
            next if !$IsContent;
            push(@ContentLines, $Line);
        }

        open(FILE, ">$File") || die "File not found";

        # print header
        if ( !$OTRSFile ) {
            print FILE $CAPEHEADER;
        } else {
            print FILE $OTRSHEADER;
        }

        # print content
        print FILE @ContentLines;

        close(FILE);
    }

    return 1;
}

# modify js-files
sub _ModifyJS {
    my ( $FileList ) = @_;

    my $OTRSHEADER = "// --
// Modified version of the work: Copyright (C) 2006-$CURRENT_YEAR KIX Service Software GmbH, https://www.kixdesk.com
// based on the original work of:
// Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file LICENSE-AGPL for license information (AGPL). If you
// did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
// --
";

    my $CAPEHEADER = "// --
// Copyright (C) 2006-$CURRENT_YEAR KIX Service Software GmbH, https://www.kixdesk.com
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file LICENSE-AGPL for license information (AGPL). If you
// did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
// --
";

    FILE:
    foreach my $File (split(/\n/, $FileList)) {
        next FILE if ( $File =~ m{(thirdparty|\.git)} );

        my $OTRSFile = _IsOTRSFile($File);

        print STDOUT "(".($OTRSFile ? "OTRS" : "KIX").") $File\n";

        open(FILE, "<$File") || die "File not found";
        my @Lines = <FILE>;
        close(FILE);

        my $IsContent = 0;
        my @ContentLines;
        for my $Line ( @Lines ) {
            if (!$IsContent && $Line !~ m/^\/\// ) {
               $IsContent = 1
            }
            next if !$IsContent;
            push(@ContentLines, $Line);
        }

        open(FILE, ">$File") || die "File not found";

        # print header
        if ( !$OTRSFile ) {
            print FILE $CAPEHEADER;
        } else {
            print FILE $OTRSHEADER;
        }

        # print content
        print FILE @ContentLines;

        close(FILE);
    }

    return 1;
}

# modify js-files
sub _ModifyCSS {
    my ( $FileList ) = @_;

    my $OTRSHEADER = "/**
 * This software is part of the KIX project, https://www.kixdesk.com/
 *  Modified version of the work: Copyright (C) 2006-$CURRENT_YEAR KIX Service Software GmbH, https://www.kixdesk.com
 *  based on the original work of:
 *  Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
 *  --
 * \@project OTRS (https://www.otrs.org) <https://www.otrs.org> - Agent Frontend
 * \@copyright OTRS AG
 * \@license AGPL (https://www.gnu.org/licenses/agpl.txt) <https://www.gnu.org/licenses/agpl.txt>
 *  --
 *  This software comes with ABSOLUTELY NO WARRANTY. For details, see
 *  the enclosed file LICENSE-AGPL for license information (AGPL). If you
 *  did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
 *
 */

";

    my $CAPEHEADER = "/**
 * This software is part of the KIX project, https://www.kixdesk.com/
 * Copyright (C) 2006-$CURRENT_YEAR KIX Service Software GmbH, https://www.kixdesk.com
 * --
 * \@project KIX (https://www.kixdesk.com) <https://www.kixdesk.com> - Agent Frontend
 * \@copyright KIX Service Software GmbH
 * \@license GPL3 (https://www.gnu.org/licenses/agpl.txt) <https://www.gnu.org/licenses/agpl.txt>
 * --
 * This software comes with ABSOLUTELY NO WARRANTY. For details, see
 * the enclosed file LICENSE-AGPL for license information (AGPL). If you
 * did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
 *
 */

";

    FILE:
    foreach my $File (split(/\n/, $FileList)) {
        next FILE if ( $File =~ m/\/thirdparty\// );

        print STDOUT $File . "\n";

        open(FILE, "<$File") || die "File not found";
        my @Lines = <FILE>;
        close(FILE);

        my $OTRSFile = _IsOTRSFile($File);

        my @OldHeader = ();
        while ( defined($Lines[0]) && $Lines[0] =~ m/^(\/\*|\s\*|$)/ ) {
            my $Line = shift( @Lines );
            push (@OldHeader, $Line);

            if ( $Line =~ m/^\s\*\sThis\ssoftware\sis\spart\sof\sthe\sKIX\sproject.*$/i ) {
                return 1;
            }
        }

        if (
            !$OTRSFile
        ) {
            unshift( @Lines, $CAPEHEADER );
        } else {
            unshift( @Lines, @OldHeader );
            unshift( @Lines, $OTRSHEADER );
        }

        open(FILE, ">$File") || die "File not found";
        print FILE @Lines;
        close(FILE);
    }

    return 1;
}

sub _IsOTRSFile {
    my ( $File ) = @_;

    $File =~ s{^\./}{};

    # some special handling for moved files
    $File =~ s{^scripts/test/system/}{scripts/test/}g;

    my $Found = 0;
    foreach my $OTRSFile ( sort keys %OTRSArchive ) {
       if ( $File =~ m{$OTRSFile$} ) {
          $Found = 1;
          last;
       }
    }

    return $Found;
}

## EO Internal methods

1;
