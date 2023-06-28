# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Maint::ClientRegistration::List;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'ClientRegistration',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Lists all registered clients.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing registered clients...</yellow>\n");

    my @ClientIDs = $Kernel::OM->Get('ClientRegistration')->ClientRegistrationList();

    foreach my $ClientID ( sort @ClientIDs ) {
        my %ClientRegistration = $Kernel::OM->Get('ClientRegistration')->ClientRegistrationGet(
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
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
