# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::Translation::List;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

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

    $Self->Description('List the existing translations in the database.');

    $Self->AddOption(
        Name        => 'language',
        Description => "Which language to list, omit to list all languages.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Home      = $Kernel::OM->Get('Config')->Get('Home');

    my $Language  = $Self->GetOption('language') || '';

    $Self->Print("<yellow>Listing existing translations...</yellow>\n\n");

    my %PatternList = $Kernel::OM->Get('Translation')->PatternList();

    foreach my $ID ( sort { $PatternList{$a} cmp $PatternList{$b} } keys %PatternList ) {
        # get pattern
        my %Pattern = $Kernel::OM->Get('Translation')->PatternGet(
            ID => $ID,
        );

        # get languages
        my %LanguageList = $Kernel::OM->Get('Translation')->TranslationLanguageList(
            PatternID => $ID,
        );

        $Self->Print("Pattern: \"$PatternList{$ID}\":\n");
        foreach my $Lang ( sort keys %LanguageList ) {
            $Self->Print("    Language $Lang:\n");
            $Self->Print("        \"$LanguageList{$Lang}\"\n");
        }
        $Self->Print("\n");
    }

    $Self->Print("<green>".(scalar(keys %PatternList))." patterns</green>\n");
    $Self->Print("\n<green>Done.</green>\n");

    return $Self->ExitCodeOk();
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
