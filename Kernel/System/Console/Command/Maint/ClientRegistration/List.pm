# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::ClientRegistration::List;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::ClientRegistration',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Lists all registered clients.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing registered clients...</yellow>\n");

    my @ClientIDs;
    my $ClientList = $Kernel::OM->Get('Kernel::System::ClientRegistration')->ClientRegistrationList();
    if ( ref $ClientList eq 'ARRAY' ) {
        @ClientIDs = @{$ClientList};
    }

    foreach my $ClientID ( sort @ClientIDs ) {
        my %ClientRegistration = $Kernel::OM->Get('Kernel::System::ClientRegistration')->ClientRegistrationGet(
            ClientID => $ClientID
        );
        foreach my $Key ( sort keys %ClientRegistration ) {
            my $Value = $ClientRegistration{$Key} || '-';
            $Self->Print(sprintf("    %25s: %s\n", $Key, $Value));
        }
        $Self->Print("-------------------------------------------------------------------------\n");
    }

    $Self->Print("<green>Done.</green>\n");

    return $Self->ExitCodeOk();
}

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
