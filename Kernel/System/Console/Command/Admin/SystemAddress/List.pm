# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::SystemAddress::List;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'SystemAddress',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('List system addresses.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing system addresses...</yellow>\n");

    # get all syste addresses
    my %SystemAddress = $Kernel::OM->Get('SystemAddress')->SystemAddressList(
        Valid => 0,
    );

    my %ValidStr = (
        1 => 'yes',
        2 => 'no',
        3 => 'no(temp)',
    );

    $Self->Print("    ID Name                                     Realname                                 Valid\n");
    $Self->Print("------ ---------------------------------------- ---------------------------------------- -------- \n");

    foreach my $ID ( sort { $SystemAddress{$a} cmp $SystemAddress{$b} } keys %SystemAddress ) {
        my %SystemAddress = $Kernel::OM->Get('SystemAddress')->SystemAddressGet(
            ID => $ID
        );

        my $Valid = $ValidStr{$SystemAddress{ValidID}};

        $Self->Print(sprintf("%6i %-40s %-40s %-8s\n",
            $SystemAddress{ID}, $SystemAddress{Name}, $SystemAddress{Realname}, $Valid));
    }

    $Self->Print("<green>Done</green>\n");
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
