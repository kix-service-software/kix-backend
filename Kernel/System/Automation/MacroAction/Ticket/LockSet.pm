# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::MacroAction::Ticket::LockSet;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::MacroAction::Ticket::Common);

our @ObjectDependencies = (
    'Log',
    'Ticket',
    'Lock'
);

=head1 NAME

Kernel::System::Automation::MacroAction::Ticket::LockSet - A module to lock or unlock a ticket

=head1 SYNOPSIS

All LockSet functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this macro action module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description(Kernel::Language::Translatable('Sets the lock state of a ticket.'));
    $Self->AddOption(
        Name        => 'Lock',
        Label       => Kernel::Language::Translatable('Lock'),
        Description => Kernel::Language::Translatable('The lock state to be set.'),
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
            Lock => 'unlock',
        },
        UserID   => 123,
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check incoming parameters
    return if !$Self->_CheckParams(%Param);

    my $TicketObject = $Kernel::OM->Get('Ticket');

    my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
        TicketID => $Param{TicketID},
    );

    if (!%Ticket) {
        return;
    }

    # set the new lock
    my $LockID = $Kernel::OM->Get('Lock')->LockLookup(
        Lock => $Param{Config}->{Lock},
    );

    if ( !$LockID ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't update ticket $Param{TicketID} - can't find lock state \"$Param{Config}->{Lock}\"!",
            UserID   => $Param{UserID}
        );
        return;
    }

    # do nothing if the desired lock state is already set
    if ( $LockID eq $Ticket{LockID} ) {
        return 1;
    }

    my $Success = $Kernel::OM->Get('Ticket')->TicketLockSet(
        TicketID => $Param{TicketID},
        LockID   => $LockID,
        UserID   => $Param{UserID},
    );

    if ( !$Success ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't update ticket $Param{TicketID} - setting the lock state \"$Param{Config}->{Lock}\" failed!",
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
