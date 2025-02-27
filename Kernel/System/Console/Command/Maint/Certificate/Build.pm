# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Certificate::Build;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Certificate',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Adds the certificates and private keys stored in KIX into the file system.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>building certificates...</yellow>\n");

    my $Success = $Kernel::OM->Get('Certificate')->CertificateToFS();

    if ( $Success ) {
        $Self->Print("<green>Done.</green>\n");

        return $Self->ExitCodeOk();
    }

     $Self->Print("<red>Error.</red>\n");
    return $Self->ExitCodeError();
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
