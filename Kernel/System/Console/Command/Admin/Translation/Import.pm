# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
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
    'Config',
    'Encode',
    'Main',
    'SysConfig',
    'Time',
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
        Description => "The directory where the PO files are located. If omitted <KIX home>/locale will be used. ",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'file',
        Description => "Only import the given file. The option \"locale-directory\" will be ignored in this case.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'plugin',
        Description => "The name (ID) of the plugin to be updated. If this is not given the framework will be updated. (use ALL to update all plugins). The options \"locale-directory\" and \"file\" will be ignored in this case.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    my $Name = $Self->Name();

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Home = $ENV{KIX_HOME} || $Kernel::OM->Get('Config')->Get('Home');

    my @Plugins = $Kernel::OM->Get('Installation')->PluginList(
        InitOrder => 1
    );
    my %PluginList = map { $_->{Product} => $_ } @Plugins;

    my $Language  = $Self->GetOption('language') || '';
    my $LocaleDir = $Self->GetOption('locale-directory') || $Home.'/locale';
    my $File      = $Self->GetOption('file') || '';
    my $Plugin    = $Self->GetOption('plugin') || '';

    $Self->Print("<yellow>Updating translations...</yellow>\n\n");

    my @ImportItems;
    if ( !$Plugin ) {

        # add framework
        push @ImportItems, { Name => 'framework', Directory => $LocaleDir };
    }
    elsif ( $Plugin && $Plugin ne 'ALL' ) {
        my $Directory = $PluginList{$Plugin}->{Directory};

        if ( ! -d $Directory ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Plugin $Plugin doesn't exist!"
            );
            return;
        }

        if ( -d $Directory . '/locale' ) {
            # add plugin
            push @ImportItems, { Name => $Plugin, Directory => $Directory . '/locale' };
        }
    }
    elsif ( $Plugin && $Plugin eq 'ALL' ) {
        foreach my $Plugin ( @Plugins ) {
            if ( ! -d $Plugin->{Directory} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Plugin $Plugin->{Product} doesn't exist!"
                );
                return;
            }

            next if ! -d $Plugin->{Directory} . '/locale';

            # add plugin
            push @ImportItems, { Name => $Plugin->{Product}, Directory => $Plugin->{Directory} . '/locale' };
        }
    }

    my @POFiles;
    if ( $File ) {

        # only import the given file
        push @POFiles, $File;
    }
    else {
        foreach my $ImportItem ( @ImportItems ) {

            # get all relevant PO files in given directory
            push @POFiles, $Kernel::OM->Get('Main')->DirectoryRead(
                Directory => $ImportItem->{Directory},
                Filter    => $Language ? "$Language.po" : '*.po',
                Recursive => 1,
            );
        }
    }

    my $PreviousDir = '';
    foreach my $File ( sort @POFiles ) {

        # ignore plugins if not plugin requested
        next if $File =~ /\/plugins\// && !$Plugin;

        my $Filename = basename $File;
        my $Dirname  = dirname $File;
        my ($Language) = split(/\./, $Filename);

        if ( $Dirname ne $PreviousDir ) {
            $Self->Print("  importing from directory $Dirname\n");
            $PreviousDir = $Dirname;
        }

        $Self->Print("    importing $Filename...");

        my ($CountTotal, $CountOK) = $Kernel::OM->Get('Translation')->ImportPO(
            Language => $Language,
            File     => $File,
            UserID   => 1
        );

        if ( $CountOK == $CountTotal ) {
            $Self->Print("<green>$CountOK/$CountTotal</green>\n");
        }
        else {
            $Self->Print("<red>$CountOK/$CountTotal</red>\n");
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
