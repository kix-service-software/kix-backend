# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::Role::Delete;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Role',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Delete a role.');
    $Self->AddOption(
        Name        => 'name',
        Description => 'Name of the role.',
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}


sub PreRun {

    my ( $Self, %Param ) = @_;

    $Self->{RoleName} = $Self->GetOption('name');

    # check role
    $Self->{RoleID} = $Kernel::OM->Get('Role')->RoleLookup( Role => $Self->{RoleName} );
    if ( !$Self->{RoleID} ) {
        die "Role $Self->{RoleName} does not exist.\n";
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Delete a role...</yellow>\n");

    my $Success = $Kernel::OM->Get('Role')->RoleDelete(
        ID     => $Self->{RoleID},
        UserID => 1,
    );

    if ($Success) {
        $Self->Print("<green>Done</green>\n");
        return $Self->ExitCodeOk();
    }

    $Self->PrintError("Can't delete role");
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
