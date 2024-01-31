# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::MacroAction::Ticket::ResponsibleSet;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::MacroAction::Ticket::Common);

our @ObjectDependencies = (
    'Log',
    'Ticket',
    'User'
);

=head1 NAME

Kernel::System::Automation::MacroAction::Ticket::ResponsibleSet - A module to set the ticket responsible

=head1 SYNOPSIS

All ResponsibleSet functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this macro action module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description(Kernel::Language::Translatable('Sets the responsible of a ticket.'));
    $Self->AddOption(
        Name        => 'ResponsibleLoginOrID',
        Label       => Kernel::Language::Translatable('Responsible'),
        Description => Kernel::Language::Translatable('The ID or login of the agent to be set.'),
        Required    => 1,
    );

    return;
}

=item Run()

Run this module. Returns 1 if everything is ok.

Example:
    my $Success = $Object->Run(
        TicketID => 123,
        Config   => {
            ResponsibleLoginOrID => 'test',
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

    my $Responsible = $Self->_ReplaceValuePlaceholder(
        %Param,
        Value => $Param{Config}->{ResponsibleLoginOrID}
    );

    my $UserID = $Kernel::OM->Get('User')->UserLookup(
        UserLogin => $Responsible,
        Silent    => 1
    );
    if ( !$UserID && $Responsible =~ m/^\d+$/ ) {
        my $ResponsibleLogin = $Kernel::OM->Get('User')->UserLookup(
            UserID => $Responsible,
            Silent => 1
        );
        if ($ResponsibleLogin) {
            $UserID = $Responsible;
        }
    }

    if ( !$UserID ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't update ticket $Param{TicketID} - can't find user with \"$Param{Config}->{ResponsibleLoginOrID}\"!",
            UserID   => $Param{UserID}
        );
        return;
    }

    # do nothing if the desired responsible is already set
    if ( $UserID eq $Ticket{ResponsibleID} ) {
        return 1;
    }

    my $Success = $TicketObject->TicketResponsibleSet(
        TicketID  => $Param{TicketID},
        NewUserID => $UserID,
        UserID    => $Param{UserID},
    );

    if ( !$Success ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't update ticket $Param{TicketID} - setting the responsible \"$Param{Config}->{ResponsibleLoginOrID}\" failed!",
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
