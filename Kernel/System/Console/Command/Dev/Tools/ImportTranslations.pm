# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Dev::Tools::ImportTranslations;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

use File::Basename;
use File::Copy;
use Lingua::Translit;
use Pod::Strip;
use Storable ();

use Kernel::Language;
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Encode',
    'Kernel::System::Main',
    'Kernel::System::SysConfig',
    'Kernel::System::Time',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Update the translation database from the PO files.');

    $Self->AddOption(
        Name        => 'language',
        Description => "Which language to import, omit to update all languages.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'locale-directory',
        Description => "The directory where the PO files are located. If omitted <KIX home>/locale will be used.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    my $Name = $Self->Name();

    return;
}

my $BreakLineAfterChars = 60;

sub Run {
    my ( $Self, %Param ) = @_;

    my $Home      = $Kernel::OM->Get('Kernel::Config')->Get('Home');

    my $Language  = $Self->GetOption('language') || '';
    my $LocaleDir = $Self->GetOption('locale-directory') || $Home.'/locale';

    $Self->Print("<yellow>Starting import...</yellow>\n\n");

    my @POFiles = $Kernel::OM->Get('Kernel::System::Main')->DirectoryRead(
        Directory => $LocaleDir,
        Filter    => $Language ? "$Language.po" : '*.po'
    );

    foreach my $File ( sort @POFiles ) {
        my $Filename = basename $File;
        my ($Language) = split(/\./, $Filename);

        $Self->Print("    importing $Filename...");

        my ($CountTotal, $CountOK) = $Kernel::OM->Get('Kernel::System::Translation')->ImportPO(
            Language => $Language,
            File     => $File,
            UserID   => 1
        );

        if ( $CountOK == $CountTotal ) {
            $Self->Print("<green>$CountOK/$CountTotal</green>\n");
        }
        else {
            $Self->PrintError("$CountOK/$CountTotal\n");
        }
    }

    $Self->Print("\n<green>Done.</green>\n");

    return $Self->ExitCodeOk();
}

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
