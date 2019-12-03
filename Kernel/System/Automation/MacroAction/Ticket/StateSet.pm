# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::MacroAction::Ticket::StateSet;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::MacroAction::Ticket::Common);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::State',
    'Kernel::System::Ticket',
    'Kernel::System::Time',
);

=head1 NAME

Kernel::System::Automation::MacroAction::Ticket::StateSet - A module to set the ticket state

=head1 SYNOPSIS

All StateSet functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this macro action module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description('Sets the state of a ticket.');
    $Self->AddOption(
        Name        => 'State',
        Label       => 'State',
        Description => 'The name of the state to be set.',
        Required    => 1,
    );
    $Self->AddOption(
        Name        => 'PendingTimeDiff',
        Label       => 'Pending Time Difference',
        Description => '(Optional) The pending time in seconds. Will be added to the actual time when the macro action is executed. Used for pending states only.',
        Required    => 0,
    );

    return;
}

=item Run()

Run this module. Returns 1 if everything is ok.

Example:
    my $Success = $Object->Run(
        TicketID => 123,
        Config   => {
            State           => 'wait for customer',
            PendingTimeDiff => 36000
        },
        UserID   => 123,
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check incoming parameters
    return if !$Self->_CheckParams(%Param);

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my %Ticket = $TicketObject->TicketGet(
        TicketID => $Param{TicketID},
    );

    if (!%Ticket) {
        return;
    }

    # set the new state
    my %State = $Kernel::OM->Get('Kernel::System::State')->StateGet(
        Name => $Param{Config}->{State}
    );

    if ( !%State || !$State{ID} ) {
        $Kernel::OM->Get('Kernel::System::Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't update ticket $Param{TicketID} - can't find ticket state \"$Param{Config}->{State}\"!",
            UserID   => $Param{UserID},
        );
        return;
    }

    my $Success = 1;

    # do nothing if the desired state is already set
    if ( $State{ID} ne $Ticket{StateID} ) {
        $Success = $TicketObject->StateSet(
            TicketID => $Param{TicketID},
            StateID  => $State{ID},
            UserID   => $Param{UserID}
        );
    }

    if ( !$Success ) {
        $Kernel::OM->Get('Kernel::System::Automation')->LogError(
            Referrer  => $Self,
            Message  => "Couldn't update ticket $Param{TicketID} - setting the state \"$Param{Config}->{State}\" failed!",
            UserID   => $Param{UserID},
        );
        return;
    }

    # set pending time if needed
    if ( $Success && $State{TypeName} =~ m{\A pending}msxi && IsNumber( $Param{Config}->{PendingTimeDiff} ) ) {

        # get time object
        my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

        # get current time
        my $PendingTime = $TimeObject->SystemTime();

        # add PendingTimeDiff
        $PendingTime += $Param{Config}->{PendingTimeDiff};

        # convert pending time to time stamp
        my $PendingTimeString = $TimeObject->SystemTime2TimeStamp(
            SystemTime => $PendingTime,
        );

        # set pending time
        my $Success = $TicketObject->TicketPendingTimeSet(
            UserID   => $Param{UserID},
            TicketID => $Param{TicketID},
            String   => $PendingTimeString,
        );

        if ( !$Success ) {
            $Kernel::OM->Get('Kernel::System::Automation')->LogError(
                Referrer => $Self,
                Message  => "Couldn't update ticket $Param{TicketID} - setting the pending time for state \"$Param{Config}->{State}\" failed!",
                UserID   => $Param{UserID},
            );
            return;
        }
    }

    return 1;
}

=item ValidateConfig()

Validates the parameters of the config.

Example:
    my $Valid = $Self->ValidateConfig(
        Config => {}                # required
    );

=cut

sub ValidateConfig {
    my ( $Self, %Param ) = @_;

    return if !$Self->SUPER::ValidateConfig(%Param);

    my %State = $Kernel::OM->Get('Kernel::System::State')->StateGet(
        Name => $Param{Config}->{State}
    );

    if (%State) {
        if ( $State{TypeName} =~ m{\A pending}msxi && !IsNumber( $Param{Config}->{PendingTimeDiff} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Validation of parameter \"PendingTimeDiff\" failed!"
            );
            return;
        }
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
