# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Ticket::PendingCheck;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Config',
    'State',
    'Ticket',
    'Time',
    'User',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Process pending tickets that are past their pending time and send pending reminders.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Process pending tickets...</yellow>\n");

    # get needed objects
    my $StateObject  = $Kernel::OM->Get('State');
    my $TicketObject = $Kernel::OM->Get('Ticket');

    my @TicketIDs;

    my @PendingAutoStateIDs = $StateObject->StateGetStatesByType(
        Type   => 'PendingAuto',
        Result => 'ID',
    );

    if (@PendingAutoStateIDs) {

        # do ticket auto jobs
        @TicketIDs = $TicketObject->TicketSearch(
            Result   => 'ARRAY',
            Search => {
                AND => [
                    {
                        Field    => 'StateIDs',
                        Operator => 'IN',
                        Value    => \@PendingAutoStateIDs,
                    },
                    {
                        Field    => 'PendingTime',
                        Operator => 'LT',
                        Value    => '+0s',
                    },
                ]
            },
            UserID   => 1,
        );

        my %States = %{ $Kernel::OM->Get('Config')->Get('Ticket::StateAfterPending') };

        TICKETID:
        for my $TicketID (@TicketIDs) {

            # get ticket data
            my %Ticket = $TicketObject->TicketGet(
                TicketID      => $TicketID,
                UserID        => 1,
                DynamicFields => 0,
            );

            # KIX4OTRS-capeIT
            if ( $States{ $Ticket{Type} . ':::' . $Ticket{State} } || $States{ $Ticket{State} } ) {
                $States{ $Ticket{State} } = $States{ $Ticket{Type} . ':::' . $Ticket{State} }
                    || $States{ $Ticket{State} };
            }

            # EO KIX4OTRS-capeIT

            next TICKETID if !$States{ $Ticket{State} };

            $Self->Print(
                " Update ticket state for ticket $Ticket{TicketNumber} ($TicketID) to '$States{$Ticket{State}}'..."
            );

            # set new state
            my $Success = $TicketObject->StateSet(
                TicketID => $TicketID,
                State    => $States{ $Ticket{State} },
                UserID   => 1,
            );

            # error handling
            if ( !$Success ) {
                $Self->Print(" failed.\n");
                next TICKETID;
            }

            # get state type for new state
            my %State = $StateObject->StateGet(
                Name => $States{ $Ticket{State} },
            );
            if ( $State{TypeName} eq 'closed' ) {

                # set new ticket lock
                $TicketObject->LockSet(
                    TicketID     => $TicketID,
                    Lock         => 'unlock',
                    UserID       => 1,
                    Notification => 0,
                );
            }
            $Self->Print(" done.\n");
        }
    }
    else {

        $Self->Print(" No pending auto StateIDs found!\n");
    }

    # determine relevant calendars
    my %RelevantCalendars;
    my $ConfigObject = $Kernel::OM->Get('Config');
    my $TimeObject = $Kernel::OM->Get('Time');

    my $MaxCalendarCount = $ConfigObject->Get('MaximumCalendarNumber') || 100;

    CALENDAR:
    foreach my $Calendar ('', 1..$MaxCalendarCount) {
        my $CalendarConfig = 'TimeWorkingHours' . ($Calendar ? '::Calendar'.$Calendar : '');

        next CALENDAR if !$ConfigObject->Get($CalendarConfig);

        # check if NOW is within the calendars business hours
        my $IsBusinessHour = $TimeObject->WorkingTime(
            StartTime => $TimeObject->SystemTime() - ( 10 * 60 ),
            StopTime  => $TimeObject->SystemTime(),
            Calendar  => $Calendar,
        );
        next CALENDAR if !$IsBusinessHour;
        $RelevantCalendars{$Calendar} = $IsBusinessHour;
    }

    if ( %RelevantCalendars ) {
        # look for pending reminder tickets with PendingTime in the past
        my %Tickets = $TicketObject->TicketSearch(
            Result    => 'HASH',
            Search => {
                AND => [
                    {
                        Field    => 'StateType',
                        Operator => 'EQ',
                        Value    => 'pending reminder',
                    },
                    {
                        Field    => 'PendingTime',
                        Operator => 'LT',
                        Value    => '+0s',
                    },
                ]
            },
            UserID    => 1,
        );

        # get calendars of tickets
        my $TicketList = $TicketObject->TicketCalendarGet(
            TicketIDs     => [ sort keys %Tickets ],
            OnlyCalendars => [ sort keys %RelevantCalendars ],
        );
        
        TICKETID:
        for my $Ticket ( @{$TicketList || []} ) {

            # trigger notification event
            $TicketObject->EventHandler(
                Event => 'NotificationPendingReminder',
                Data  => {
                    TicketID              => $Ticket->{TicketID},
                    CustomerMessageParams => {
                        TicketNumber => $Tickets{$Ticket->{TicketID}},
                    },
                },
                UserID => 1,
            );
        }
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
