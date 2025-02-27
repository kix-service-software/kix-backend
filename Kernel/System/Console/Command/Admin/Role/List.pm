# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::Role::List;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Role',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('List roles.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing roles...</yellow>\n");

    # get all roles
    my %Roles = $Kernel::OM->Get('Role')->RoleList(
        Valid => 0,
    );

    my %ValidStr = (
        1 => 'yes',
        2 => 'no',
        3 => 'no(temp)',
    );

    $Self->Print("    ID Role                                               Usage Context           Valid    Comment\n");
    $Self->Print("------ -------------------------------------------------- ----------------------- -------- --------------------------------------------------------------------------------\n");

    foreach my $ID ( sort { $Roles{$a} cmp $Roles{$b} } keys %Roles ) {
        my %Role = $Kernel::OM->Get('Role')->RoleGet(
            ID => $ID
        );

        my $Valid        = $ValidStr{$Role{ValidID}};
        my $UsageContext = join(', ', @{$Role{UsageContextList}});

        $Self->Print(sprintf("%6i %-50s %-23s %-8s %-80s\n", $Role{ID}, $Role{Name}, $UsageContext, $Valid, $Role{Comment}));
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
