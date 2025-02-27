# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Maint::ClientRegistration::SendNotifications;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'ClientRegistration',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Sends all outstanding notifications to the relevant clients.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Sending client notifications...</yellow>\n");

    my $Result = $Kernel::OM->Get('ClientNotification')->NotificationSend();
    if ( !$Result ) {
        $Self->PrintError("Unable to send client notifications.\n");
    }
    else {
        my $Message = $Kernel::OM->Get('Log')->GetLogEntry(
            Type => 'info',
            What => 'Message',
        );
        $Self->Print($Message."\n");
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
