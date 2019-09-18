# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Maint::ClientRegistration::Remove;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::ClientRegistration',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Removes the given client. If no client-id is given, all clients will be removed.');
    $Self->AddOption(
        Name        => 'client-id',
        Description => "The ID of the registered client.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>removing registered clients...</yellow>\n");

    my $ClientID = $Self->GetOption('client-id') || '';

    my $ClientList = $Kernel::OM->Get('Kernel::System::ClientRegistration')->ClientRegistrationList();
    if ( !$ClientList ) {
        $Self->PrintError("Unable to determine client registrations.\n");
        return $Self->ExitCodeError();
    }
    my %Clients = map { $_ => 1 } @{$ClientList};

    my @ClientIDs;
    if ( $ClientID ) {
        push(@ClientIDs, $ClientID);
    }
    else {
        if ( ref $ClientList eq 'ARRAY' ) {
            @ClientIDs = @{$ClientList};
        }
    }

    foreach my $ClientID ( sort @ClientIDs ) {
        $Self->Print("removing client $ClientID\n");

        if ( !$Clients{$ClientID} ) {
            $Self->PrintError("No registration for this client exists.\n");
            return $Self->ExitCodeError();
        }

        my $Result = $Kernel::OM->Get('Kernel::System::ClientRegistration')->ClientRegistrationDelete(
            ClientID => $ClientID
        );
        if ( !$Result ) {
            $Self->PrintError("Unable to remove client.\n");
        }
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
