# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::Automation::Macro::List;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Automation',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('List macros.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing macros...</yellow>\n");

    # get all macros
    my %Macros = $Kernel::OM->Get('Automation')->MacroList(
        Valid => 0,
    );

    my %ValidStr = (
        1 => 'yes',
        2 => 'no',
        3 => 'no(temp)',
    );

    $Self->Print("    ID Type                      Name                                                                             Valid\n");
    $Self->Print("------ ------------------------- -------------------------------------------------------------------------------- -------- \n");

    foreach my $ID ( sort { $Macros{$a} cmp $Macros{$b} } keys %Macros ) {
        my %Macro = $Kernel::OM->Get('Automation')->MacroGet(
            ID => $ID
        );

        my $Valid = $ValidStr{$Macro{ValidID}};

        $Self->Print(sprintf("%6i %-25s %-80s %-8s\n",
            $Macro{ID}, $Macro{Type}, $Macro{Name}, $Valid));
    }

    $Self->Print("<green>Done</green>\n");
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