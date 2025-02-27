# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::MacroAction::Ticket::TeamSet;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::MacroAction::Ticket::Common);

our @ObjectDependencies = (
    'Log',
    'Ticket',
    'Queue'
);

=head1 NAME

Kernel::System::Automation::MacroAction::Ticket::TeamSet - A module to move a ticket to a new team

=head1 SYNOPSIS

All TeamSet functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this macro action module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description(Kernel::Language::Translatable('Sets the team of a ticket.'));
    $Self->AddOption(
        Name        => 'Team',
        Label       => Kernel::Language::Translatable('Team'),
        Description => Kernel::Language::Translatable('The name of the team to be set. If it is as sub-team, the full path-name has to be used (separated by two colons - e.g. "NameOfParentTeam::NameOfTeamToBeSet").'),
        Required    => 1,
        Placeholder => {
            Richtext  => 0,
            Translate => 0,
        },
    );

    return;
}

=item Run()

Run this module. Returns 1 if everything is ok.

Example:
    my $Success = $Object->Run(
        TicketID => 123,
        Config   => {
            Team => 'Junk',
        },
        UserID   => 123,
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check incoming parameters
    return if !$Self->_CheckParams(%Param);

    my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
        TicketID => $Param{TicketID},
    );

    if (!%Ticket) {
        return;
    }

    # set the new team
    my $QueueID = $Kernel::OM->Get('Queue')->QueueLookup(
        Queue  => $Param{Config}->{Team},
        Silent => 1
    );

    if (!$QueueID && $Param{Config}->{Team} =~ m/^\d+$/) {
        my $QueueName = $Kernel::OM->Get('Queue')->QueueLookup(
            QueueID => $Param{Config}->{Team},
            Silent => 1
        );
        if ($QueueName) {
            $QueueID = $Param{Config}->{Team};
        }
    }

    if ( !$QueueID ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't update ticket $Param{TicketID} - can't find ticket team \"$Param{Config}->{Team}\"!",
            UserID   => $Param{UserID}
        );
        return;
    }

    # do nothing if the desired team is already set
    if ( $QueueID eq $Ticket{QueueID} ) {
        return 1;
    }

    my $Success = $Kernel::OM->Get('Ticket')->TicketQueueSet(
        TicketID => $Param{TicketID},
        QueueID  => $QueueID,
        UserID   => $Param{UserID},
    );

    if ( !$Success ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't update ticket $Param{TicketID} - setting the team \"$Param{Config}->{Team}\" failed!",
            UserID   => $Param{UserID}
        );
        return;
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
