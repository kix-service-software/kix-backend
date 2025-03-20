# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::TicketType::List;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Type',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('List ticket types.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing ticket types...</yellow>\n");

    # get all types
    my %Types = $Kernel::OM->Get('Type')->TypeList(
        Valid => 0,
    );

    my %ValidStr = (
        1 => 'yes',
        2 => 'no',
        3 => 'no(temp)',
    );

    $Self->Print("    ID Name                                               Valid\n");
    $Self->Print("------ -------------------------------------------------- -------- \n");

    foreach my $ID ( sort { $Types{$a} cmp $Types{$b} } keys %Types ) {
        my %Type = $Kernel::OM->Get('Type')->TypeGet(
            ID => $ID
        );

        my $Valid = $ValidStr{$Type{ValidID}};

        $Self->Print(sprintf("%6i %-50s %-8s\n", $Type{ID}, $Type{Name}, $Valid));
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
