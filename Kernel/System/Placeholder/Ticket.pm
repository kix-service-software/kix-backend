# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Placeholder::Ticket;

use strict;
use warnings;

use Kernel::Language;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Placeholder::Base);

our @ObjectDependencies = (
    'Config',
    'Log',
    'Queue'
);

=head1 NAME

Kernel::System::Placeholder::Ticket

=cut

=begin Internal:

=cut

sub _Replace {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Text UserID)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my %Queue;
    if ( $Param{QueueID} ) {
        %Queue = $Kernel::OM->Get('Queue')->QueueGet(
            ID => $Param{QueueID},
        );
    }

    if ( IsHashRefWithData(\%Queue) ) {
        $Param{Text} =~ s/$Self->{Start} KIX_TICKET_QUEUE $Self->{End}/$Queue{Name}/gixms;
    }

    my $Tag = $Self->{Start} . 'KIX_TICKET_';
    if ( IsHashRefWithData($Param{Ticket}) ) {

        # add (simple) ID
        $Param{Ticket}->{ID} = $Param{Ticket}->{TicketID};

        $Param{Text} =~ s/$Self->{Start} KIX_TICKET_ID $Self->{End}/$Param{Ticket}->{TicketID}/gixms;
        $Param{Text} =~ s/$Self->{Start} KIX_TICKET_NUMBER $Self->{End}/$Param{Ticket}->{TicketNumber}/gixms;
        $Param{Text} =~ s/$Self->{Start} KIX_QUEUE $Self->{End}/$Param{Ticket}->{Queue}/gixms;

        if ( !$Param{Ticket}->{AccountedTime} && $Param{Text} =~ m/AccountedTime/) {
            $Param{Ticket}->{AccountedTime} = $Kernel::OM->Get('Ticket')->TicketAccountedTimeGet(
                TicketID => $Param{TicketID},
            );
        }
        if ( !$Param{Ticket}->{Contact} && $Param{Ticket}->{ContactID} ) {
            my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
                ID => $Param{Ticket}->{ContactID}
            );
            $Param{Ticket}->{Contact} = IsHashRefWithData(\%Contact) ? $Contact{Fullname} : '';
        }
        if ( !$Param{Ticket}->{Organisation} && $Param{Ticket}->{OrganisationID} ) {
            my %Org = $Kernel::OM->Get('Organisation')->OrganisationGet(
                ID => $Param{Ticket}->{OrganisationID}
            );
            $Param{Ticket}->{Organisation} = IsHashRefWithData(\%Org) ? $Org{Name} : '';
        }

        # replace it
        $Param{Text} = $Self->_HashGlobalReplace( $Param{Text}, $Tag, %{ $Param{Ticket} } );
    }

    # cleanup
    $Param{Text} =~ s/$Tag.+?$Self->{End}/$Param{ReplaceNotFound}/gi;

    return $Param{Text};
}

1;

=end Internal:

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
