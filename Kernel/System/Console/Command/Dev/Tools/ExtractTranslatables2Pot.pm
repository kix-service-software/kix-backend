# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Dev::Tools::ExtractTranslatables2Pot;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

use File::Basename;
use File::Copy;
use Locale::PO;
use Pod::Strip;
use Storable ();

use Kernel::Language;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Encode',
    'Kernel::System::Main',
    'Kernel::System::SysConfig',
    'Kernel::System::Time',
);

our $DisableWarnings = 0;

BEGIN { $SIG{'__WARN__'} = sub { warn $_[0] if !$DisableWarnings } }  # suppress warnings if not activated

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Update the templates.pot file.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->{Home}    = $Kernel::OM->Get('Kernel::Config')->Get('Home');
    $Self->{POTFile} = "$Self->{Home}/locale/templates.pot";

    $Self->Print("<yellow>gathering Translatables and updating templates.pot file...</yellow>\n\n");

    my @Translatables;

    push(@Translatables, $Self->_ExtractFromTemplateFiles);
    push(@Translatables, $Self->_ExtractFromPerlFiles);
    push(@Translatables, $Self->_ExtractFromXMLFiles(
        Directory => "$Self->{Home}/scripts/database",
        Source    => "Database",
    ));
    push(@Translatables, $Self->_ExtractFromXMLFiles(
        Directory => "$Self->{Home}/Kernel/Config/Files",
        Source    => "SysConfig",
    ));

    $Self->Print(sprintf "\nextracted %i Translatables\n", (scalar @Translatables));

    my $Items;
    {
        $DisableWarnings = 1;
        $Items = Locale::PO->load_file_ashash($Self->{POTFile});
        my $ManualItems = Locale::PO->load_file_ashash($Self->{POTFile} . '.manual');
        $DisableWarnings = 0;

        my $Count = 0;

        # merge manual items into Translatables
        my %TranslatableHash = map { $_->{String} => 1 } @Translatables;
        foreach my $MsgId ( sort keys %{$ManualItems} ) {
            next if $TranslatableHash{$MsgId};

            my $String = $MsgId;
            $String =~ s/(?<!\\)"//g;
            $String =~ s/\\"/"/g;

            # it doesn't exist, add to list
            push @Translatables, {
                Location => 'manual entry from templates.pot.manual',
                String   => $String
            };

            $Count++;
        }

        $Self->Print(sprintf "added %i Translatables from $Self->{POTFile}.manual\n", $Count);
    }

    $Self->WritePOTFile(
        TranslationStrings => \@Translatables,
        TargetPOTFile      => "$Self->{Home}/locale/templates.pot",
    );

    $Self->Print("\n<green>Done.</green>\n");

    return $Self->ExitCodeOk();
}

sub WritePOTFile {
    my ( $Self, %Param ) = @_;

    my @POTEntries;

    my $Package = 'KIX';

    my $TimeObject   = $Kernel::OM->Get('Kernel::System::Time');
    my $CreationDate = $TimeObject->SystemTime2TimeStamp(
        SystemTime => $TimeObject->SystemTime(),
    );

    # only YEAR-MO-DA HO:MI is needed without seconds
    $CreationDate = substr( $CreationDate, 0, -3 ) . '+0000';

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

    for my $Translatable ( @{ $Param{TranslationStrings} } ) {
        my $String = $Translatable->{String};
        $String =~ s/\\/\\\\/g;
        $Kernel::OM->Get('Kernel::System::Encode')->EncodeOutput( \$String );

        push @POTEntries, Locale::PO->new(
            -msgid     => $String,
            -msgstr    => '',
            -automatic => $Translatable->{Location},
        );
    }

    Locale::PO->save_file_fromarray( $Param{TargetPOTFile}, \@POTEntries )
        || die "Could not save file $Param{TargetPOTFile}: $!";

    return;
}

# extract translatable strings from .tt files
sub _ExtractFromTemplateFiles {
    my ($Self, %Param) = @_;
    my @Translatables;

    my %UsedWords;
    my $Directory = "$Self->{Home}/Kernel/Output/HTML/Templates";

    my @TemplateList = $Kernel::OM->Get('Kernel::System::Main')->DirectoryRead(
        Directory => $Directory,
        Filter    => '*.tt',
        Recursive => 1,
    );

    $Self->Print("\n<yellow>extracting template files...</yellow>\n");

    for my $File (@TemplateList) {
        my $Count = 0;

        my $ContentRef = $Kernel::OM->Get('Kernel::System::Main')->FileRead(
            Location => $File,
            Mode     => 'utf8',
        );

        if ( !ref $ContentRef ) {
            die "Can't open $File: $!";
        }

        my $Content = ${$ContentRef};

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

                push @Translatables, {
                    Location => "Template: $File",
                    String => $Word,
                };

                $Count++;

            }

            '';
        }egx;

        $Self->Print(sprintf "%4i in %s\n", $Count, $File);
    }

    return @Translatables;
}

# extract translatable strings from Perl code
sub _ExtractFromPerlFiles {
    my ($Self, %Param) = @_;
    my @Translatables;

    $Self->Print("\n<yellow>extracting perl files...</yellow>\n");

    my @PerlModuleList = $Kernel::OM->Get('Kernel::System::Main')->DirectoryRead(
        Directory => "$Self->{Home}/Kernel",
        Filter    => '*.pm',
        Recursive => 1,
    );

    FILE:
    for my $File (@PerlModuleList) {
        my $Count = 0;

        next FILE if ( $File =~ m{cpan-lib}xms );

        my $ContentRef = $Kernel::OM->Get('Kernel::System::Main')->FileRead(
            Location => $File,
            Mode     => 'utf8',
        );

        if ( !ref $ContentRef ) {
            die "Can't open $File: $!";
        }

        $File =~ s{^.*/(Kernel/)}{$1}smx;

        my $Content = ${$ContentRef};

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

                push @Translatables, {
                    Location => "Perl Module: $File",
                    String => $Word,
                };

                $Count++;

            }
            '';
        }egx;

        $Self->Print(sprintf "%4i in %s\n", $Count, $File);
    }

    return @Translatables;
}

# extract translatable strings from XML files
sub _ExtractFromXMLFiles {
    my ($Self, %Param) = @_;
    my @Translatables;

    $Self->Print("\n<yellow>extracting $Param{Source} XML files...</yellow>\n");

    my @DBXMLFiles = $Kernel::OM->Get('Kernel::System::Main')->DirectoryRead(
        Directory => $Param{Directory},
        Filter    => '*.xml',
        Recursive => 1
    );

    FILE:
    for my $File (@DBXMLFiles) {
        my $Count = 0;

        my $ContentRef = $Kernel::OM->Get('Kernel::System::Main')->FileRead(
            Location => $File,
            Mode     => 'utf8',
        );

        if ( !ref $ContentRef ) {
            die "Can't open $File: $!";
        }

        $File =~ s{^.*/(scripts/)}{$1}smx;

        my $Content = ${$ContentRef};

        # do translation
        $Content =~ s{
            <Data[^>]+Translatable="1"[^>]*>(.*?)</Data>
        }
        {
            my $Word = $1 // '';

            if ($Word) {

                push @Translatables, {
                    Location => "$Param{Source}: $File",
                    String => $Word,
                };

                $Count++;

            }
            '';
        }egx;

        $Self->Print(sprintf "%4i in %s\n", $Count, $File);
    }

    return @Translatables;
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
