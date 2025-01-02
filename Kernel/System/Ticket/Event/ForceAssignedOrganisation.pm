# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2022 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::ForceAssignedOrganisation;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Contact',
    'Log',
    'Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Data Event Config)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }
    for (qw(TicketID)) {
        if ( !$Param{Data}->{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_ in Data!"
            );
            return;
        }
    }

    # get ticket data
    my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
        TicketID => $Param{Data}->{TicketID}
    );
    if ( !%Ticket ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Ticket with ID $Param{Data}->{TicketID} not found!"
        );
        return;
    }
    if ( !$Ticket{ContactID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Ticket with ID $Param{Data}->{TicketID} has no contact!"
        );
        return;
    }

    # get contact data
    my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
        ID            => $Ticket{ContactID},
        DynamicFields => 0,
    );

    # init variable to set new organisation with undefined value
    my $SetOrganisation = undef;

    # handle empty/missing organisation on ticket
    if ( !$Ticket{OrganisationID} ) {
        $SetOrganisation = $Contact{PrimaryOrganisationID};
    }
    # handle organisation on ticket is not an assigned contact organisation
    elsif (
        !grep { $_ eq $Ticket{OrganisationID} } @{ $Contact{OrganisationIDs} } 
    ) {
        $SetOrganisation = $Contact{PrimaryOrganisationID};
    }

    # set new organisation if necessary
    if ( defined( $SetOrganisation ) ) {
        # unlock ticket
        $Kernel::OM->Get('Ticket')->TicketCustomerSet(
            OrganisationID => $SetOrganisation,
            TicketID       => $Param{Data}->{TicketID},
            UserID         => 1,
        );
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
