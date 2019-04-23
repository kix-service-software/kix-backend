# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::User::ClearRoles;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::User',
    'Kernel::System::Role',
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
    $Self->{UserID} = $Kernel::OM->Get('Kernel::System::User')->UserLookup( UserLogin => $Self->{UserLogin} );
    if ( !$Self->{UserID} ) {
        die "User $Self->{Userlogin} does not exist.\n";
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Removing all role assignments of the user $Self->{UserLogin}...</yellow>\n");

    my @RoleIDs = $Kernel::OM->Get('Kernel::System::User')->RoleList(
        UserID  => $Self->{UserID},
    );

    foreach my $RoleID ( sort @RoleIDs ) {
        my $RoleName = $Kernel::OM->Get('Kernel::System::Role')->RoleLookup(
            RoleID => $RoleID
        );
        my $Success = $Kernel::OM->Get('Kernel::System::Role')->RoleUserDelete(
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
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
