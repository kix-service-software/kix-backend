# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::Role::AssignUser;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'User',
    'Role',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Assign a user to a role.');
    $Self->AddOption(
        Name        => 'role-name',
        Description => 'Name of the role the given user should be assigned to.',
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'user-name',
        Description => 'Name of the user who should be assigned to the given role.',
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub PreRun {

    my ( $Self, %Param ) = @_;

    $Self->{UserName} = $Self->GetOption('user-name');
    $Self->{RoleName} = $Self->GetOption('role-name');

    # check user
    $Self->{UserID} = $Kernel::OM->Get('User')->UserLookup( UserLogin => $Self->{UserName} );
    if ( !$Self->{UserID} ) {
        die "User $Self->{UserName} does not exist.\n";
    }

    # check role
    $Self->{RoleID} = $Kernel::OM->Get('Role')->RoleLookup( Role => $Self->{RoleName} );
    if ( !$Self->{RoleID} ) {
        die "Role $Self->{RoleName} does not exist.\n";
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Assigning user $Self->{UserName} to role $Self->{RoleName}...</yellow>\n");

    # add user to role
    my $Success = $Kernel::OM->Get('Role')->RoleUserAdd(
        AssignUserID => $Self->{UserID},
        RoleID       => $Self->{RoleID},
        UserID       => 1,
    );

    if ( !$Success ) {
        $Self->PrintError("Can't assign user to role.");
        return $Self->ExitCodeError();
    }

    $Self->Print("Done.\n");
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
