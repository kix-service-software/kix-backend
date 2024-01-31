# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::MacroAction::Ticket::PrioritySet;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::MacroAction::Ticket::Common);

our @ObjectDependencies = (
    'Log',
    'Ticket',
    'Priority',
);

=head1 NAME

Kernel::System::Automation::MacroAction::Ticket::PrioritySet - A module to set the ticket priority

=head1 SYNOPSIS

All PrioritySet functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this macro action module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description(Kernel::Language::Translatable('Sets the priority of a ticket.'));
    $Self->AddOption(
        Name        => 'Priority',
        Label       => Kernel::Language::Translatable('Priority'),
        Description => Kernel::Language::Translatable('The name of the priority to be set.'),
        Required    => 1
    );

    return;
}

=item Run()

Run this module. Returns 1 if everything is ok.

Example:
    my $Success = $Object->Run(
        TicketID => 123,
        Config   => {
            Priority => '3 normal',
        },
        UserID   => 123,
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check incoming parameters
    return if !$Self->_CheckParams(%Param);

    my $TicketObject = $Kernel::OM->Get('Ticket');

    my %Ticket = $TicketObject->TicketGet(
        TicketID => $Param{TicketID},
    );

    if (!%Ticket) {
        return;
    }

    my $Priority = $Self->_ReplaceValuePlaceholder(
        %Param,
        Value => $Param{Config}->{Priority}
    );

    # set the new priority
    my $PriorityID = $Kernel::OM->Get('Priority')->PriorityLookup(
        Priority => $Priority
    );

    if ( !$PriorityID ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't update ticket $Param{TicketID} - can't find ticket priority \"$Param{Config}->{Priority}\"!",
            UserID   => $Param{UserID}
        );
        return;
    }

    # do nothing if the desired priority is already set
    if ( $PriorityID eq $Ticket{PriorityID} ) {
        return 1;
    }

    my $Success = $TicketObject->TicketPrioritySet(
        TicketID   => $Param{TicketID},
        PriorityID => $PriorityID,
        Priority   => $Param{Config}->{Priority},
        UserID     => $Param{UserID},
    );

    if ( !$Success ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't update ticket $Param{TicketID} - setting the priority \"$Param{Config}->{Priority}\" failed!",
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
