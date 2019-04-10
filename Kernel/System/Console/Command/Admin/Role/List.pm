# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::Role::List;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::Role',
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
    my %Roles = $Kernel::OM->Get('Kernel::System::Role')->RoleList(
        Valid => 0,
    );

    my %ValidStr = (
        1 => 'yes',
        2 => 'no',
        3 => 'no(temp)',
    );

    $Self->Print("Role                                               Valid    Comment\n");
    $Self->Print("-------------------------------------------------- -------- --------------------------------------------------------------------------------\n");

    foreach my $ID ( sort { $Roles{$a} cmp $Roles{$b} } keys %Roles ) {
        my %Role = $Kernel::OM->Get('Kernel::System::Role')->RoleGet(
            ID => $ID
        );

        my $Valid = $ValidStr{$Role{ValidID}};

        $Self->Print(sprintf("%-50s %-8s %-80s\n", $Role{Name}, $Valid, $Role{Comment}));
    }

    $Self->Print("<green>Done</green>\n");
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
