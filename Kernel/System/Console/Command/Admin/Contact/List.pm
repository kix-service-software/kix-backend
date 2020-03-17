# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::Contact::List;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::User',
    'Kernel::System::Contact',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('List contacts.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing contacts...</yellow>\n");

    # get all users
    my %Contacts = $Kernel::OM->Get('Kernel::System::Contact')->ContactList(
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

    $Self->Print("    ID Firstname            Lastname             Email                          UserID\n");
    $Self->Print("------ -------------------- -------------------- ------------------------------ ------\n");

    foreach my $ID ( sort { $Contacts{$a} cmp $Contacts{$b} } keys %Contacts ) {
        my %Contact = $Kernel::OM->Get('Kernel::System::Contact')->ContactGet(
            ID => $ID
        );

        my $Valid = $ValidStr{$Contact{ValidID}};
        my $AssignedUserID = ($Contact{AssignedUserID}) ? $Contact{AssignedUserID} : '-';

        $Self->Print(sprintf("%6i %-20s %-20s %-30s %6s\n",
            $Contact{ID}, $Contact{Firstname}, $Contact{Lastname}, $Contact{Email}, $AssignedUserID));
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
package List;
use strict;
use warnings FATAL => 'all';

1;
