# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::Organisation::Add;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Organisation',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Add a organisation.');
    $Self->AddOption(
        Name        => 'number',
        Description => "Number of the new organisation.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'name',
        Description => "Name of the new organisation.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'street',
        Description => "Street of the new organisation.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'zip',
        Description => "ZIP code of the new organisation.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'city',
        Description => "City of the new organisation.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'country',
        Description => "Country of the new organisation.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'url',
        Description => "URL of the new organisation.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'comment',
        Description => "Comment for the new organisation.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Adding a new organisation...</yellow>\n");

    # add organisation
    if (
        !$Kernel::OM->Get('Organisation')->OrganisationAdd(
            Number  => $Self->GetOption('number'),
            Name    => $Self->GetOption('name'),
            Street  => $Self->GetOption('street'),
            Zip     => $Self->GetOption('zip'),
            City    => $Self->GetOption('city'),
            Country => $Self->GetOption('country'),
            Url     => $Self->GetOption('url'),
            Comment => $Self->GetOption('comment'),
            ValidID => 1,
            UserID  => 1,
        )
        )
    {
        $Self->PrintError("Can't add organisation.");
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
