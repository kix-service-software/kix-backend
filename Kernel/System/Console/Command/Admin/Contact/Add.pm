# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::Contact::Add;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Contact',
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
        Name        => 'primary-organisation',
        # rkaiser - T#2017020290001194 - changed customer user to contact
        Description => "The number of the primary organisation for the new contact.",
        Required    => 0,
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
        Name        => 'organisations',
        Description => "All organisation number for the new contact. Separate multiple values by comma (primary organisation must be included).",
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

    $Self->Print("<yellow>Adding a new contact...</yellow>\n");

    my %OrganisationList = reverse $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Organisation',
        Result     => 'HASH',
        UserType   => 'Agent',
        UserID     => 1,
    );

    my $AssignedUserID;
    if ($Self->GetOption('user-login')) {
        $AssignedUserID = $Kernel::OM->Get('User')->UserLookup(
            UserLogin => $Self->GetOption('user-login'),
            Silent    => 1,
        );
    }

    my @OrgIDs;
    if ($Self->GetOption('organisations')) {
        foreach my $OrgNumber ( split(/,\s*/, $Self->GetOption('organisations')) ) {
            if ( !$OrganisationList{$OrgNumber} ) {
                $Self->PrintError("Can't find organisation \"$OrgNumber\".");
                return $Self->ExitCodeError();
            }
            push @OrgIDs, $OrganisationList{$OrgNumber}
        };
    }

    if (
        $Self->GetOption('primary-organisation')
        && !$OrganisationList{$Self->GetOption('primary-organisation')}
    ) {
        $Self->PrintError("Can't find organisation \"".$Self->GetOption('primary-organisation'). "\".");
        return $Self->ExitCodeError();
    }

    if (
        !$Kernel::OM->Get('Contact')->ContactAdd(
            Firstname             => $Self->GetOption('first-name'),
            Lastname              => $Self->GetOption('last-name'),
            PrimaryOrganisationID => $Self->GetOption('primary-organisation') ? $OrganisationList{$Self->GetOption('primary-organisation')} : undef,
            OrganisationIDs       => \@OrgIDs,
            Email                 => $Self->GetOption('email-address'),
            AssignedUserID        => $AssignedUserID,
            UserID                => 1,
            ValidID               => 1,
        )
    ) {
        $Self->PrintError("Can't add contact.");
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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
