# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::MacroAction::Ticket::TypeSet;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::MacroAction::Ticket::Common);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Ticket',
    'Kernel::System::Type',
);

=head1 NAME

Kernel::System::Automation::MacroAction::Ticket::TypeSet - A module to set the ticket type

=head1 SYNOPSIS

All TypeSet functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this macro action module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description('Sets the type of a ticket.');
    $Self->AddOption(
        Name        => 'Type',
        Label       => 'Type',        
        Description => 'The name of the type to be set.',
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
            State           => 'wait for customer',
            PendingTimeDiff => 36000
        },
        UserID   => 123,
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check incoming parameters
    return if !$Self->_CheckParams(\%Param);

    my $TicketObject = Kernel::OM->Get('Kernel::System::Ticket');

    my %Ticket = $TicketObject->TicketGet(
        TicketID => $Param{TicketID},
    );

    # do nothing if the desired type is already set
    if ( defined $Param{Config}->{Type} && $Param{Config}->{Type} eq $Ticket{Type} ) {
        return 1;
    }

    # set the new type
    my %Type = $Kernel::OM->Get('Kernel::System::Type')->TypeGet(
        Name => $Param{Config}->{Type},
    );

    if ( !IsHashRefWithData(\%Type) ) {
        $Kernel::OM->Get('Kernel::System::Automation')->LogError(
            Referrer  => $Self,
            Message  => "Couldn't update ticket $Param{TicketID} - can't find ticket type \"$Param{Config}->{Type}\"!",
        );
        return;
    }

    my $Success = $Kernel::OM->Get('Kernel::System::Ticket')->TypeSet(
        TicketID => $Param{TicketID},
        TypeID   => $Type{ID},
        UserID   => $Param{UserID},
    );

    if ( !$Success ) {
        $Kernel::OM->Get('Kernel::System::Automation')->LogError(
            Referrer  => $Self,
            Message  => "Couldn't update ticket $Param{TicketID} - setting the type \"$Param{Config}->{Type}\" failed!",
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
