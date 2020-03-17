# --
# Modified version of the work: Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::MacroAction::Ticket::ContactSet;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::MacroAction::Ticket::Common);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Ticket',
    'Kernel::System::Contact'
);

=head1 NAME

Kernel::System::Automation::MacroAction::Ticket::ContactSet - A module to set the ticket contact

=head1 SYNOPSIS

All ContactSet functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this macro action module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description(Kernel::Language::Translatable('Sets the contact (and its primary organisation as organisation) of a ticket.'));
    $Self->AddOption(
        Name        => 'Contact',
        Label       => Kernel::Language::Translatable('Contact'),
        Description => Kernel::Language::Translatable('The login of the contact to be set.'),
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
            Contact => 'test',
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

    my $Contact = $Kernel::OM->Get('Kernel::System::TemplateGenerator')->ReplacePlaceHolder(
        RichText => 0,
        Text     => $Param{Config}->{Contact},
        TicketID => $Param{TicketID},
        Data     => {},
        UserID   => $Param{UserID},
    );

    my $ContactID = $Kernel::OM->Get('Kernel::System::Contact')->ContactLookup(
        Login  => $Contact,
        Silent => 1
    );

    my $OrganisationID;
    if ($ContactID) {
        my %Contact = $Kernel::OM->Get('Kernel::System::Contact')->ContactGet(
            ID => $ContactID
        );
        if ( %Contact ) {
            $OrganisationID = $Contact{PrimaryOrganisationID};
        }
    } else {
        $ContactID = $Contact;
        $OrganisationID = $Contact;
    }

    # do nothing if the desired contact is already set
    if ( $ContactID eq $Ticket{ContactID} ) {
        return 1;
    }

    my $Success = $TicketObject->TicketCustomerSet(
        TicketID       => $Param{TicketID},
        OrganisationID => $OrganisationID,
        ContactID      => $ContactID,
        UserID         => $Param{UserID}
    );

    if ( !$Success ) {
        $Kernel::OM->Get('Kernel::System::Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't update ticket $Param{TicketID} - setting the contact \"$Param{Config}->{Contact}\" failed!",
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
