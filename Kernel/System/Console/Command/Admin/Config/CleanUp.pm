# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::Config::CleanUp;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'SysConfig',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Cleaning up the system configuration.');
    $Self->AddOption(
        Name        => 'confirm',
        Description => "If not given, command will not be executed.",
        HasValue    => 0,
        Required    => 1,
    );
    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Cleaning up the system configuration...</yellow>\n");

    my $Result = $Kernel::OM->Get('SysConfig')->CleanUp();

    if ( !$Result ) {
        $Self->Print("<red>Error.</red>\n");
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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
