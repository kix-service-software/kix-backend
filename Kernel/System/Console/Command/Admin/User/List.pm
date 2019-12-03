# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::User::List;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::User',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('List users.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing users...</yellow>\n");

    # get all users
    my %Users = $Kernel::OM->Get('Kernel::System::User')->UserList(
        Valid => 0,
    );

    my %ValidStr = (
        1 => 'yes',
        2 => 'no',
        3 => 'no(temp)',
    );

    $Self->Print("    ID Login                          Firstname            Lastname             Email                                              Valid\n");
    $Self->Print("------ ------------------------------ -------------------- -------------------- -------------------------------------------------- --------\n");

    foreach my $ID ( sort { $Users{$a} cmp $Users{$b} } keys %Users ) {
        my %User = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
            UserID => $ID
        );

        my $Valid = $ValidStr{$User{ValidID}};

        $Self->Print(sprintf("%6i %-30s %-20s %-20s %-50s %-8s\n", $User{UserID}, $User{UserLogin}, $User{UserFirstname}, $User{UserLastname}, $User{UserEmail}, $Valid));
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
