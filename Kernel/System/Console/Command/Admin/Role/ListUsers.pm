# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::Role::ListUsers;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::Role',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('List users assigned to a role.');
    $Self->AddOption(
        Name        => 'role-name',
        Description => 'Name of the role.',
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub PreRun {

    my ( $Self, %Param ) = @_;

    $Self->{RoleName} = $Self->GetOption('role-name');

    # check role
    $Self->{RoleID} = $Kernel::OM->Get('Kernel::System::Role')->RoleLookup( Role => $Self->{RoleName} );
    if ( !$Self->{RoleID} ) {
        die "Role $Self->{RoleName} does not exist.\n";
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing users assigned to role $Self->{RoleName}...</yellow>\n");

    my @UserIDs = $Kernel::OM->Get('Kernel::System::Role')->RoleUserList(
        RoleID  => $Self->{RoleID},
        UserID  => 1,
    );

    foreach my $ID ( sort @UserIDs ) {
        my %User = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
            UserID => $ID
        );
        $Self->Print("$User{UserFullname} ($User{UserLogin})\n");
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
