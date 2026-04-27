# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::TicketAccountedTimeUpdate;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Log
    Ticket
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Data Event Config)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # handle only events with given TicketID
    return 1 if ( !$Param{Data}->{TicketID} );

    return 1 if !$Kernel::OM->Get('Ticket')->TicketNumberLookup(
        TicketID => $Param{Data}->{TicketID}
    );

    my $TotalTime = $Kernel::OM->Get('Ticket')->TicketAccountedTimeSet(
        TicketID => $Param{Data}->{TicketID},
        UserID   => $Param{UserID}
    );

    return 1 if !defined $TotalTime;

    my $TimeUnit     = $Param{Data}->{TimeUnit} || 0;
    my $TimeUnitStrg = $Param{Data}->{OldTimeUnit} ? "$Param{Data}->{OldTimeUnit} -> $TimeUnit" : $TimeUnit;

    # add history
    $Kernel::OM->Get('Ticket')->HistoryAdd(
        TicketID     => $Param{Data}->{TicketID},
        ArticleID    => $Param{Data}->{ArticleID},
        CreateUserID => $Param{UserID},
        HistoryType  => 'TimeAccounting',
        Name         => "\%\%$TimeUnitStrg\%\%$TotalTime",
    );

    if ( $Param{Event} eq 'TimeAccountingCreate' ) {
        # trigger event
        $Kernel::OM->Get('Ticket')->EventHandler(
            Event => 'TicketAccountTime',
            Data  => {
                TicketID  => $Param{Data}->{TicketID},
                ArticleID => $Param{Data}->{ArticleID},
            },
            UserID => $Param{UserID},
        );
    }

    return 1;
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
