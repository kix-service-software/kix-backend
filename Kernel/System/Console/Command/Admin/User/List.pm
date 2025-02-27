# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::User::List;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'User',
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
    my %Users = $Kernel::OM->Get('User')->UserList(
        Valid => 0,
    );

    my %ValidStr = (
        1 => 'yes',
        2 => 'no',
        3 => 'no(temp)',
    );

    my %BoolStr = (
        0 => 'no',
        1 => 'yes',
    );

    $Self->Print("    ID Login                          Agent    Customer Valid\n");
    $Self->Print("------ ------------------------------ -------- -------- --------\n");

    foreach my $ID ( sort { $Users{$a} cmp $Users{$b} } keys %Users ) {
        my %User = $Kernel::OM->Get('User')->GetUserData(
            UserID => $ID
        );

        my $Valid = $ValidStr{$User{ValidID}};
        my $IsAgent = $BoolStr{ $User{IsAgent} };
        my $IsCustomer = $BoolStr{ $User{IsCustomer} };

        $Self->Print(sprintf("%6i %-30s %-8s %-8s %-8s\n", $User{UserID}, $User{UserLogin}, $IsAgent, $IsCustomer, $Valid));
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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
