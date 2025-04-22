# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::MacroAction::Ticket::OwnerSet;

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

Kernel::System::Automation::MacroAction::Ticket::OwnerSet - A module to set the ticket owner

=head1 SYNOPSIS

All OwnerSet functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this macro action module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description(Kernel::Language::Translatable('Sets the owner of a ticket.'));
    $Self->AddOption(
        Name        => 'OwnerLoginOrID',
        Label       => Kernel::Language::Translatable('Owner'),
        Description => Kernel::Language::Translatable('The ID or login of the agent to be set.'),
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
            OwnerLoginOrID => 'test',
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

    my $UserID = $Kernel::OM->Get('User')->UserLookup(
        UserLogin => $Param{Config}->{OwnerLoginOrID},
        Silent    => 1
    );
    if ( !$UserID && $Param{Config}->{OwnerLoginOrID} =~ m/^\d+$/ ) {
        my $OwnerLogin = $Kernel::OM->Get('User')->UserLookup(
            UserID => $Param{Config}->{OwnerLoginOrID},
            Silent => 1
        );
        if ($OwnerLogin) {
            $UserID = $Param{Config}->{OwnerLoginOrID};
        }
    }

    if ( !$UserID ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't update ticket $Param{TicketID} - can't find user with \"$Param{Config}->{OwnerLoginOrID}\"!",
            UserID   => $Param{UserID}
        );
        return;
    }

    # do nothing if the desired owner is already set
    if ( $UserID eq $Ticket{OwnerID} ) {
        return 1;
    }

    my $Success = $Kernel::OM->Get('Ticket')->TicketOwnerSet(
        TicketID  => $Param{TicketID},
        NewUserID => $UserID,
        UserID    => $Param{UserID},
    );

    if ( !$Success ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't update ticket $Param{TicketID} - setting the owner \"$Param{Config}->{OwnerLoginOrID}\" failed!",
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
