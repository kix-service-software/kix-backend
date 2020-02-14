# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::Contact::Add;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::Contact',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    # rkaiser - T#2017020290001194 - changed customer user to contact
    $Self->Description('Add a contact.');
    $Self->AddOption(
        Name        => 'first-name',
        # rkaiser - T#2017020290001194 - changed customer user to contact
        Description => "First name of the new contact.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'last-name',
        # rkaiser - T#2017020290001194 - changed customer user to contact
        Description => "Last name of the new contact.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'primary-customer-id',
        # rkaiser - T#2017020290001194 - changed customer user to contact
        Description => "The primary customer ID for the new contact.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'email-address',
        # rkaiser - T#2017020290001194 - changed customer user to contact
        Description => "Email address of the new contact.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'customer-ids',
        Description => "All customer IDs for the new contact. Separate multiple values by comma.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'user-login',
        Description => "Login of an existing user which is going to be assigned to the new contact.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Adding a new customer user...</yellow>\n");

    my $AssignedUserID;
    if ($Self->GetOption('user-login')) {
        $AssignedUserID = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
            UserLogin => $Self->GetOption('user-login'),
            Silent    => 1,
        );
    }
    if (
        !$Kernel::OM->Get('Kernel::System::Contact')->ContactAdd(
            Source                => 'Contact',
            Firstname             => $Self->GetOption('first-name'),
            Lastname              => $Self->GetOption('last-name'),
            PrimaryOrganisationID => $Self->GetOption('primary-customer-id'),
            OrganisationIDs       => $Self->GetOption('customer-ids') || $Self->GetOption('primary-customer-id'),
            Email                 => $Self->GetOption('email-address'),
            AssignedUserID        => $AssignedUserID,
            UserID                => 1,
            ChangeUserID          => 1,
            ValidID               => 1,
        )
    )
    {
        $Self->PrintError("Can't add customer user.");
        return $Self->ExitCodeError();
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
