# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::Automation::Macro::Dump;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Automation',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Dump a macro.');
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
        die "Macro $Self->{MacroName} does not exist.\n";
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Code = $Kernel::OM->Get('Automation')->MacroDump(
        ID     => $Self->{MacroID},
        UserID => 1,
    );

    if ( $Code ) {
        $Self->Print($Code);
        return $Self->ExitCodeOk();
    }

    $Self->PrintError("Can't dump macro");
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
