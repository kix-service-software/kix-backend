# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
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

our @ObjectDependencies = qw(
    Config
    Daemon::SchedulerDB
    ObjectSearch
    State
    Ticket
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Process pending tickets that are past their pending time and send pending reminders.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Process pending tickets...</yellow>\n");

    my @PendingAutoStateIDs = $Kernel::OM->Get('State')->StateGetStatesByType(
        Type   => 'PendingAuto',
        Result => 'ID',
    );
    my @PendingReminderStateIDs = $Kernel::OM->Get('State')->StateGetStatesByType(
        Type   => 'PendingReminder',
        Result => 'ID',
    );

    if (@PendingAutoStateIDs) {

        # do ticket auto jobs
        my @TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
            ObjectType => 'Ticket',
            Result     => 'ARRAY',
            Search     => {
                AND => [
                    {
                        Field    => 'StateID',
                        Operator => 'IN',
                        Value    => \@PendingAutoStateIDs,
                    },
                    {
                        Field    => 'PendingTime',
                        Operator => 'LTE',
                        Value    => '+0s',
                    },
                ]
            },
            Sort       => [
                {
                    Field     => 'PendingTime',
                    Direction => 'ascending'
                }
            ],
            UserID     => 1,
            UserType   => 'Agent'
        );

        my $States = $Kernel::OM->Get('Config')->Get('Ticket::StateAfterPending') || {};

        TICKETID:
        for my $TicketID (@TicketIDs) {

            # get ticket data
            my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
                TicketID      => $TicketID,
                UserID        => 1,
                DynamicFields => 0,
            );

            my $NewState;

            if ( $States->{"$Ticket{Type}:::$Ticket{State}" } || $States->{$Ticket{State}} ) {
                $NewState = $States->{"$Ticket{Type}:::$Ticket{State}"} || $States->{$Ticket{State}};
            }

            next TICKETID if !$NewState;

            $Self->Print(
                " Update ticket state for ticket $Ticket{TicketNumber} ($TicketID) to '$NewState'..."
            );

            # set new state
            my $Success = $Kernel::OM->Get('Ticket')->TicketStateSet(
                TicketID => $TicketID,
                State    => $NewState,
                UserID   => 1,
            );

            # error handling
            if ( !$Success ) {
                $Self->Print(" failed.\n");
                next TICKETID;
            }

            # get state type for new state
            my %State = $Kernel::OM->Get('State')->StateGet(
                Name => $States->{$Ticket{State}},
            );
            if ( $State{TypeName} eq 'closed' ) {

                # set new ticket lock
                $Kernel::OM->Get('Ticket')->TicketLockSet(
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

    my %CronTaskSummary = map { $_->{Name} => $_ } @{( $Kernel::OM->Get('Daemon::SchedulerDB')->CronTaskSummary() )[0]->{Data}} ;

    if ( @PendingReminderStateIDs ) {
        # look for pending reminder tickets with PendingTime in the past
        my %Tickets = $Kernel::OM->Get('ObjectSearch')->Search(
            ObjectType => 'Ticket',
            Result     => 'HASH',
            Search     => {
                AND => [
                    {
                        Field    => 'StateID',
                        Operator => 'IN',
                        Value    => \@PendingReminderStateIDs,
                    },
                    {
                        Field    => 'PendingTime',
                        Operator => 'LTE',
                        Value    => '+0s',
                    },
                ]
            },
            Sort       => [
                {
                    Field     => 'PendingTime',
                    Direction => 'ascending'
                }
            ],
            UserID     => 1,
            UserType   => 'Agent'
        );

        my $NotificationCount = 0;

        my @PreparedTicketList;
        foreach my $TicketID ( sort keys %Tickets ) {
            push @PreparedTicketList, {
                TicketID              => $TicketID,
                CustomerMessageParams => {
                    TicketNumber => $Tickets{TicketID},
                },
            };
            $NotificationCount++;
        }

        if ( @PreparedTicketList ) {
            # trigger notification event
            $Kernel::OM->Get('Ticket')->EventHandler(
                Event => 'NotificationPendingReminder',
                Data  => {
                    TicketList => \@PreparedTicketList
                },
                UserID => 1,
            );
        }

        $Self->Print("Triggered $NotificationCount reminder notification(s).\n");
    }
    else {
        $Self->Print(" No pending reminder StateIDs found!\n");
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
