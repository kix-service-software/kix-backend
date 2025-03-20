# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Maint::Frontend::Execute;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'SysConfig',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Sends a maintenance command to the frontend server.');

    $Self->AddOption(
        Name        => 'command',
        Description => "The command to execute in the frontend server.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'parameters',
        Description => "The optional parameters for the command (JSON string).",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Sending command to the frontend server...</yellow>\n");

    my $CommandParam = $Self->GetOption('command');

    my ($Namespace, $Command) = split('/', $CommandParam);
    if ( !$Command && !$Namespace ) {
        $Self->Print("<red>ERROR:</red> unknown command \"$CommandParam\"!\n");
        return $Self->ExitCodeError();
    }

    my $EventListJSON = $Kernel::OM->Get('JSON')->Encode(
        Data => [
            {
                Event     => 'EXECUTE_COMMAND',
                Namespace => $Namespace,
                Data      => {
                    Command    => $Command,
                    Parameters => $Self->GetOption('parameters') || '',
                }
            }
        ]
    );

    my $Result = $Kernel::OM->Get('ClientNotification')->NotifyFrontendServer(
        EventList => $EventListJSON
    );

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
