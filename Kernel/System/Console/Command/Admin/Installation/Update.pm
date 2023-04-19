# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::Installation::Update;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Installation',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Update the current installation to a specific build');
    $Self->AddOption(
        Name        => 'source-build',
        Description => "The build number to start from (usually the installed build).",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+/smx,
    );

    $Self->AddOption(
        Name        => 'target-build',
        Description => "The build number to get to (usually the build that is being installed).",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+/smx,
    );

    $Self->AddOption(
        Name        => 'plugin',
        Description => "The name (ID) of the plugin to be updated. If this is not given the framework will be updated. (use ALL to update all plugins)",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^.*$/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Updating installation...</yellow>\n");

    my $SourceBuild = $Self->GetOption('source-build');
    my $TargetBuild = $Self->GetOption('target-build');
    my $Plugin      = $Self->GetOption('plugin');

    my $Result = $Kernel::OM->Get('Installation')->Update(
        SourceBuild => $SourceBuild,
        TargetBuild => $TargetBuild,
        Plugin      => $Plugin,
    );

    if ( !$Result ) {
        $Self->PrintError("Something went wrong. Update aborted. Please check the KIX log for details.");
        return $Self->ExitCodeError();
    }

    $Self->Print("<green>Done.</green>\n");

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
