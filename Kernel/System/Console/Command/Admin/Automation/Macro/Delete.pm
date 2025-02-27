# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::Automation::Macro::Delete;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Automation',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Delete a macro.');
    $Self->AddOption(
        Name        => 'name',
        Description => 'Name of the macro.',
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub PreRun {

    my ( $Self, %Param ) = @_;

    $Self->{MacroName} = $Self->GetOption('name');

    # check macro
    $Self->{MacroID} = $Kernel::OM->Get('Automation')->MacroLookup( Name => $Self->{MacroName} );
    if ( !$Self->{MacroID} ) {
        die "Macro $Self->{MacoName} does not exist.\n";
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Delete a macro...</yellow>\n");

    my $Success = $Kernel::OM->Get('Automation')->MacroDelete(
        ID     => $Self->{MacroID},
        UserID => 1,
    );

    if ($Success) {
        $Self->Print("<green>Done</green>\n");
        return $Self->ExitCodeOk();
    }

    $Self->PrintError("Can't delete macro");
    return $Self->ExitCodeError();
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
