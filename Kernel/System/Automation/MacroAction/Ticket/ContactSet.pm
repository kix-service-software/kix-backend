# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
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
    'Log',
    'Ticket',
    'Contact'
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
        Name        => 'ContactEmailOrID',
        Label       => Kernel::Language::Translatable('Contact'),
        Description => Kernel::Language::Translatable('The ID or email (or Login of the corresponding user) of the contact to be set.'),
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
            ContactEmailOrID => 'test',
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

    my $Contact = $Self->_ReplaceValuePlaceholder(
        %Param,
        Value => $Param{Config}->{ContactEmailOrID}
    );

    my $ContactID;
    if ( $Contact =~ m/^\d+$/ ) {
        my $ContactMail = $Kernel::OM->Get('Contact')->ContactLookup(
            ID     => $Contact,
            Silent => 1
        );
        if ($ContactMail) {
            $ContactID = $Contact;
        }
    } else {
        $ContactID = $Kernel::OM->Get('Contact')->ContactLookup(
            Email  => $Contact,
            Silent => 1
        );
    }

    if ( !$ContactID ) {
        # try to find a contact with this user login
        my $UserID = $Kernel::OM->Get('User')->UserLookup(
           UserLogin => $Contact,
           Silent    => 1,
        );
        if ( $UserID ) {
            $ContactID = $Kernel::OM->Get('Contact')->ContactLookup(
                UserID => $UserID,
                Silent => 1
            );
        }
    }

    if (!$ContactID) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't update ticket $Param{TicketID} - no contact found with \"$Contact\" (\"$Param{Config}->{ContactEmailOrID}\")",
            UserID   => $Param{UserID}
        );
        return;
    }

    # do nothing if the desired contact is already set
    if ( $ContactID eq $Ticket{ContactID} ) {
        return 1;
    }

    my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
        ID => $ContactID
    );
    my $OrganisationID = $Contact{PrimaryOrganisationID};

    my $Success = $TicketObject->TicketCustomerSet(
        TicketID       => $Param{TicketID},
        OrganisationID => $OrganisationID,
        ContactID      => $ContactID,
        UserID         => $Param{UserID}
    );

    if ( !$Success ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't update ticket $Param{TicketID} - setting the contact \"$Param{Config}->{ContactEmailOrID}\" failed!",
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
