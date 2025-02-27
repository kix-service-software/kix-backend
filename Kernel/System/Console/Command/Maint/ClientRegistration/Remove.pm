# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::ClientRegistration::Remove;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'ClientRegistration',
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

    my @ClientIDs;
    if ( $ClientID ) {
        @ClientIDs = ( $ClientID );
    }
    else {
        @ClientIDs = $Kernel::OM->Get('ClientRegistration')->ClientRegistrationList();
        if ( !@ClientIDs ) {
            $Self->PrintError("Unable to determine client registrations.\n");
            return $Self->ExitCodeError();
        }
    }

    foreach my $ClientID ( sort @ClientIDs ) {
        my %ClientRegistration = $Kernel::OM->Get('ClientRegistration')->ClientRegistrationList(
            ClientID => $ClientID,
            Silent   => 1,
        );
        if ( !%ClientRegistration ) {
            $Self->PrintError("No registration for this client exists.\n");
            return $Self->ExitCodeError();
        }

        $Self->Print("removing client $ClientID\n");

        my $Result = $Kernel::OM->Get('ClientRegistration')->ClientRegistrationDelete(
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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
