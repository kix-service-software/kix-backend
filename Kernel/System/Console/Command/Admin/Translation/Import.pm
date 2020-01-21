# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::Translation::Import;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

use File::Basename;

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
    $Self->AddOption(
        Name        => 'file',
        Description => "Only import the given file. The option locale-directory will be ignored in this case.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    my $Name = $Self->Name();

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Home      = $Kernel::OM->Get('Kernel::Config')->Get('Home');

    my $Language  = $Self->GetOption('language') || '';
    my $LocaleDir = $Self->GetOption('locale-directory') || $Home.'/locale';
    my $File      = $Self->GetOption('file') || '';

    $Self->Print("<yellow>Updating translations...</yellow>\n\n");

    my @POFiles;
    if ( $File ) {
        # only import the given file
        push @POFiles, $File;
    }
    else {
        # get all relevant PO files in given directory
        @POFiles = $Kernel::OM->Get('Kernel::System::Main')->DirectoryRead(
            Directory => $LocaleDir,
            Filter    => $Language ? "$Language.po" : '*.po'
        );
    }

    foreach my $File ( sort @POFiles ) {
        my $Filename = basename $File;
        my ($Language) = split(/\./, $Filename);

        $Self->Print("    importing $LocaleDir/$Filename...");

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
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
