# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Ticket::IndexRebuild;

use strict;
use warnings;

use base qw(
    Kernel::System::AsynchronousExecutor
    Kernel::System::Console::BaseCommand
);

our @ObjectDependencies = (
    'Ticket',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Rebuild the ticket index.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Starting rebuild of ticket index...</yellow>\n");

    my $Success = $Self->AsyncCall(
        ObjectName               => $Kernel::OM->GetModuleFor('Ticket'),
        FunctionName             => 'TicketIndexRebuild',
        FunctionParams           => {},
        MaximumParallelInstances => 1,
    );

    if ( $Success ) {
        $Self->Print("<green>Done.</green>\n");
        return $Self->ExitCodeOk();
    }
    return $Self->ExitCodeError();
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
