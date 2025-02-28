# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::User::ClearRoles;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'User',
    'Role',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Removes all the role assignments from the given user.');
    $Self->AddOption(
        Name        => 'user',
        Description => 'Specify the user login of the agent.',
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub PreRun {

    my ( $Self, %Param ) = @_;

    $Self->{UserLogin} = $Self->GetOption('user');

    # check user
    $Self->{UserID} = $Kernel::OM->Get('User')->UserLookup( UserLogin => $Self->{UserLogin} );
    if ( !$Self->{UserID} ) {
        die "User $Self->{Userlogin} does not exist.\n";
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Removing all role assignments of the user $Self->{UserLogin}...</yellow>\n");

    my @RoleIDs = $Kernel::OM->Get('Role')->UserRoleList(
        UserID  => $Self->{UserID},
    );

    foreach my $RoleID ( sort @RoleIDs ) {
        my $RoleName = $Kernel::OM->Get('Role')->RoleLookup(
            RoleID => $RoleID
        );
        my $Success = $Kernel::OM->Get('Role')->RoleUserDelete(
            RoleID => $RoleID,
            UserID => $Self->{UserID}
        );
        next if !$Success;

        $Self->Print("removed user from role $RoleName\n");
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
