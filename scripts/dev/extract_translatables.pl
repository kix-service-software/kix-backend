#!/usr/bin/perl
# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;

use Cwd;
use Encode;
use Getopt::Long;
use File::Basename;
use File::Copy;
use Locale::PO;
use Pod::Strip;
use Storable ();

STDOUT->autoflush(1);


my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime();
my $CURRENT_YEAR = $year + 1900;

my %Options;
GetOptions(
    'directory=s' => \$Options{Directory},
    'pot-file=s'  => \$Options{POTFile},
    'help'        => \$Options{Help},
);

# check if directory is given
if ( $Options{Help} ) {
    print "extract_translatables - Extract translatable patterns to a POT file.\n";
    print "Copyright (C) 2006-$CURRENT_YEAR KIX Service Software GmbH, https://www.kixdesk.com/\n";
    print "\n";
    print "Required Options:\n";
    print "  --directory - The base directory to extract from. If omitted, the current working directory will be used.\n";
    print "  --pot-file  - The POT file to write the extract to. If omitted <Directory>/locale/templates.pot will be used.\n";
    exit -1;
}

my $DisableWarnings = 0;
BEGIN { $SIG{'__WARN__'} = sub { warn $_[0] if !$DisableWarnings } }  # suppress warnings if not activated

my $Directory = $Options{Directory} || cwd();
my $POTFile   = $Options{POTFile} || "$Directory/locale/templates.pot";
my %Translatables;

print "extracting Translatables and updating $POTFile file...\n";

%Translatables = ( _ExtractFromTemplateFiles(
    Directory => $Directory
), %Translatables );
%Translatables = ( _ExtractFromPerlFiles(
    Directory => $Directory
), %Translatables );
%Translatables = ( _ExtractFromXMLFiles(
    Directory => "$Directory/scripts/database",
    Source    => "Database",
), %Translatables);
%Translatables = ( _ExtractFromXMLFiles(
    Directory => "$Directory/Kernel/Config/Files",
    Source    => "SysConfig",
), %Translatables);
%Translatables = ( _ExtractFromXMLFiles(
    Directory => "$Directory/update",
    Source    => "Update",
), %Translatables);

printf "\nextracted %i Translatables\n", scalar keys %Translatables;

{
    $DisableWarnings = 1;
    my $ManualItems = Locale::PO->load_file_ashash($POTFile . '.manual');
    $DisableWarnings = 0;

    my $Count = 0;

    # merge manual items into Translatables
    foreach my $MsgId ( sort keys %{$ManualItems} ) {
        next if $Translatables{$MsgId};

        my $String = $MsgId;
        $String =~ s/(?<!\\)"//g;
        $String =~ s/\\"/"/g;

        # it doesn't exist, add to list
        $Translatables{$String} = 'manual entry from '.basename $POTFile.'.manual';

        $Count++;
    }

    printf "added %i Translatables from $POTFile.manual\n", $Count;
}

WritePOTFile(
    TranslationStrings => \%Translatables,
    TargetPOTFile      => "$POTFile",
);

print "\nDone.\n";

exit 0;

sub WritePOTFile {
    my ( %Param ) = @_;

    my @POTEntries;

    my $Package = 'KIX';

    my ( $s, $m, $h, $D, $M, $Y, $WD, $YD, $DST ) = localtime( time() );    ## no critic
    my $CreationDate = sprintf "%i-%i-%i %02i:%02i+0000", $Y+1900, $M+1, $D, $h, $m;

    push @POTEntries, Locale::PO->new(
        -msgid => '',
        -msgstr =>
            "Project-Id-Version: $Package\n" .
            "POT-Creation-Date: $CreationDate\n" .
            "PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE\n" .
            "Last-Translator: \n" .
            "Language-Team: \n" .
            "Language: \n" .
            "MIME-Version: 1.0\n" .
            "Content-Type: text/plain; charset=UTF-8\n" .
            "Content-Transfer-Encoding: 8bit\n",
    );

    for my $Translatable ( sort { "$Param{TranslationStrings}->{$a}$a" cmp "$Param{TranslationStrings}->{$b}$b" } keys %{ $Param{TranslationStrings} } ) {
        my $String = $Translatable;
        $String =~ s/\\/\\\\/g;
        EncodeOutput( \$String );

        push @POTEntries, Locale::PO->new(
            -msgid     => $String,
            -msgstr    => '',
            -automatic => $Param{TranslationStrings}->{$Translatable},
        );
    }

    Locale::PO->save_file_fromarray( $Param{TargetPOTFile}, \@POTEntries )
        || die "Could not save file $Param{TargetPOTFile}: $!";

    return;
}

# extract translatable strings from .tt files
sub _ExtractFromTemplateFiles {
    my (%Param) = @_;
    my %Translatables;

    my %UsedWords;
    my $Directory = "$Param{Directory}/Kernel/Output/HTML/Templates";

    my @TemplateList = `find $Param{Directory} -name *.tt`;

    print "\nscanning template files...\n";

    FILE:
    for my $File (@TemplateList) {
        chomp($File);

        # ignore plugins if not given
        next if $File =~ /\/plugins\// && $Param{Directory} !~ /\/plugins/;

        my $Count = 0;

        my $Content = FileRead(
            Location => $File,
            Mode     => 'utf8',
        );

        if ( !$Content ) {
            die "Can't read $File: $!";
        }

        $File =~ s{^.*/(.+?)\.tt}{$1}smx;

        # do translation
        $Content =~ s{
            Translate\(
                \s*
                (["'])(.*?)(?<!\\)\1
        }
        {
            my $Word = $2 // '';

            # unescape any \" or \' signs
            $Word =~ s{\\"}{"}smxg;
            $Word =~ s{\\'}{'}smxg;

            if ($Word) {
                $Translatables{$Word} = "Template: $File";
                $Count++;
            }

            '';
        }egx;

        printf "%4i in %s\n", $Count, $File;
    }

    return %Translatables;
}

# extract translatable strings from Perl code
sub _ExtractFromPerlFiles {
    my (%Param) = @_;
    my %Translatables;

    print "\nscanning perl files...\n";

    my @PerlModuleList = `find $Param{Directory}/Kernel -name *.pm`;

    @PerlModuleList = (
        @PerlModuleList,
        `find $Param{Directory}/update -name *.pl`
    );

    FILE:
    for my $File (@PerlModuleList) {
        chomp($File);

        # ignore plugins if not given
        next if $File =~ /\/plugins\// && $Param{Directory} !~ /\/plugins/;

        my $Count = 0;

        next FILE if ( $File =~ m{cpan-lib}xms );

        my $Content = FileRead(
            Location => $File,
            Mode     => 'utf8',
        );

        if ( !$Content ) {
            die "Can't read $File: $!";
        }

        $File =~ s{^.*/(Kernel/|update/)}{$1}smx;

        # Remove POD
        my $PodStrip = Pod::Strip->new();
        $PodStrip->replace_with_comments(1);
        my $Code;
        $PodStrip->output_string( \$Code );
        $PodStrip->parse_string_document($Content);

        # Purge all comments
        $Code =~ s{^ \s* # .*? \n}{\n}xmsg;

        # do translation
        $Code =~ s{
            (?:
                ->Translate | Translatable
            )
            \(
                \s*
                (["'])(.*?)(?<!\\)\1
        }
        {
            my $Word = $2 // '';

            # unescape any \" or \' signs
            $Word =~ s{\\"}{"}smxg;
            $Word =~ s{\\'}{'}smxg;

            # Ignore strings containing variables
            my $SkipWord;
            $SkipWord = 1 if $Word =~ m{\$}xms;

            if ($Word && !$SkipWord) {
                $Translatables{$Word} = "Perl Module: $File";
                $Count++;
            }
            '';
        }egx;

        printf "%4i in %s\n", $Count, $File;
    }

    return %Translatables;
}

# extract translatable strings from XML files
sub _ExtractFromXMLFiles {
    my (%Param) = @_;
    my %Translatables;

    print "\nscanning $Param{Source} XML files...\n";

    my @DBXMLFiles = `find $Param{Directory} -name *.xml`;

    FILE:
    for my $File (@DBXMLFiles) {
        chomp($File);

        # ignore plugins if not given
        next if $File =~ /\/plugins\// && $Param{Directory} !~ /\/plugins/;

        my $Count = 0;

        my $Content = FileRead(
            Location => $File,
            Mode     => 'utf8',
        );

        if ( !$Content ) {
            die "Can't read $File: $!";
        }

        $File =~ s{^.*/(scripts/|Kernel/|update/)}{$1}smx;

        # do translation
        $Content =~ s{
            <(Data|Description|Item)[^>]+Translatable="1"[^>]*>(.*?)</(Data|Description|Item)>
        }
        {
            my $Word = $2 // '';

            if ($Word) {
                $Translatables{$Word} = "$Param{Source}: $File";
                $Count++;
            }
            '';
        }egx;

        printf "%4i in %s\n", $Count, $File;
    }

    return %Translatables;
}

sub FileRead {
    my %Param = @_;
    my $Content;

    my $Location = $Param{Location} || $Param{Directory}.'/'.$Param{Filename};
    chomp $Location;

    if ( !open(HANDLE, '<', $Location) ) {
        return;
    }

    $Content = do { local $/; <HANDLE> };
    close(HANDLE);

    return $Content;
}

sub EncodeOutput {
    my ( $Self, $What ) = @_;

    if ( ref $What eq 'SCALAR' ) {
        return $What if !defined ${$What};
        return $What if !Encode::is_utf8( ${$What} );
        ${$What} = Encode::encode_utf8( ${$What} );
        return $What;
    }

    if ( ref $What eq 'ARRAY' ) {

        ROW:
        for my $Row ( @{$What} ) {
            next ROW if !defined $Row;
            next ROW if !Encode::is_utf8( ${$Row} );
            ${$Row} = Encode::encode_utf8( ${$Row} );
        }
        return $What;
    }

    return $What if !Encode::is_utf8( \$What );
    Encode::encode_utf8( \$What );
    return $What;
}

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
