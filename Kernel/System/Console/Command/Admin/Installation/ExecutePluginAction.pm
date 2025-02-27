# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::Installation::ExecutePluginAction;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Installation',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Execute plugin action.');

    $Self->AddOption(
        Name        => 'plugin',
        Description => "The name (ID) of the plugin.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/^.*$/smx,
    );

    $Self->AddOption(
        Name        => 'action',
        Description => "The action to be executed.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/^.*$/smx,
    );


    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>executing plugin action...</yellow>\n");

    # get all plugins
    my $Success = $Kernel::OM->Get('Installation')->PluginActionExecute(
        Plugin => $Self->GetOption('plugin'),
        Action => $Self->GetOption('action'),
        UserID => 1,
    );
    if ( !$Success ) {
        $Self->PrintError("Something went wrong. Could not execute plugin action.");
        return $Self->ExitCodeError();    
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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
