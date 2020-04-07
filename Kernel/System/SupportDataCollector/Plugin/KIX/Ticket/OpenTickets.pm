# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::SupportDataCollector::Plugin::KIX::Ticket::OpenTickets;

use strict;
use warnings;

use base qw(Kernel::System::SupportDataCollector::PluginBase);

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Ticket',
);

sub GetDisplayPath {
    return Translatable('KIX');
}

sub Run {
    my $Self = shift;

    my $OpenTickets = $Kernel::OM->Get('Ticket')->TicketSearch(
        Result     => 'COUNT',
        StateType  => 'Open',
        UserID     => 1,
        Permission => 'ro',
    );

    if ( $OpenTickets > 8000 ) {
        $Self->AddResultWarning(
            Label   => Translatable('Open Tickets'),
            Value   => $OpenTickets,
            Message => Translatable('You should not have more than 8,000 open tickets in your system.'),
        );
    }
    else {
        $Self->AddResultOk(
            Label => Translatable('Open Tickets'),
            Value => $OpenTickets,
        );
    }

    return $Self->GetResults();
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
