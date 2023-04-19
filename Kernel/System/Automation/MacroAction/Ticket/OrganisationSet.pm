# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::MacroAction::Ticket::OrganisationSet;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::MacroAction::Ticket::Common);

our @ObjectDependencies = (
    'Log',
    'Ticket',
    'Organisation'
);

=head1 NAME

Kernel::System::Automation::MacroAction::Ticket::OrganisationSet - A module to set the ticket organisation

=head1 SYNOPSIS

All OrganisationSet functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this macro action module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description(Kernel::Language::Translatable('Sets the organisation of a ticket.'));
    $Self->AddOption(
        Name        => 'OrganisationNumberOrID',
        Label       => Kernel::Language::Translatable('Organisation'),
        Description => Kernel::Language::Translatable('The ID or number of the organisation to be set.'),
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
            OrganisationNumberOrID => 'test',
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

    my $Organisation = $Self->_ReplaceValuePlaceholder(
        %Param,
        Value => $Param{Config}->{OrganisationNumberOrID}
    );

    my $OrganisationID = $Kernel::OM->Get('Organisation')->OrganisationLookup(
        Number => $Organisation,
        Silent => 1
    );
    if ( !$OrganisationID && $Organisation =~ m/^\d+$/ ) {
        my $OrgNumber = $Kernel::OM->Get('Organisation')->OrganisationLookup(
            ID     => $Organisation,
            Silent => 1
        );
        if ($OrgNumber) {
            $OrganisationID = $Organisation;
        }
    }

    if ( !$OrganisationID ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't update ticket $Param{TicketID} - can't find organisation with \"$Param{Config}->{OrganisationNumberOrID}\"!",
            UserID   => $Param{UserID}
        );
        return;
    }

    # do nothing if the desired organisation is already set
    if ( $OrganisationID eq $Ticket{OrganisationID} ) {
        return 1;
    }

    my $Success = $TicketObject->TicketCustomerSet(
        TicketID       => $Param{TicketID},
        OrganisationID => $OrganisationID,
        UserID         => $Param{UserID}
    );

    if ( !$Success ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't update ticket $Param{TicketID} - setting the organisation \"$Param{Config}->{OrganisationNumberOrID}\" failed!",
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
