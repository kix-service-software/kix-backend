# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::Role::DeletePermission;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Role',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Delete a role permission.');
    $Self->AddOption(
        Name        => 'role-name',
        Description => 'Name of the role.',
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'permission-id',
        Description => 'The ID of the permission to be deleted.',
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub PreRun {

    my ( $Self, %Param ) = @_;

    $Self->{PermissionID} = $Self->GetOption('permission-id');
    $Self->{RoleName} = $Self->GetOption('role-name');

    # check PermissionID
    my %Permission = $Kernel::OM->Get('Role')->PermissionGet( ID => $Self->{PermissionID} );
    if ( !%Permission ) {
        die "Permission with ID $Self->{PermissionID} does not exist.\n";
    }

    # check role
    $Self->{RoleID} = $Kernel::OM->Get('Role')->RoleLookup( Role => $Self->{RoleName} );
    if ( !$Self->{RoleID} ) {
        die "Role $Self->{RoleName} does not exist.\n";
    }

    # check if given PermissionID belongs to given role
    my %PermissionIDs = map {$_ => 1} $Kernel::OM->Get('Role')->PermissionList(
        RoleID  => $Self->{RoleID},
        UserID  => 1,
    );
    if ( !$PermissionIDs{$Self->{PermissionID}} ) {
        die "Permission with ID $Self->{PermissionID} does not belong to role $Self->{RoleName}.\n";
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Delete permission $Self->{PermissionID} from role $Self->{RoleName}...</yellow>\n");

    my $Result = $Kernel::OM->Get('Role')->PermissionDelete(
        ID => $Self->{PermissionID},
    );

    if ($Result) {
        $Self->Print("<green>Done</green>\n");
        return $Self->ExitCodeOk();
    }

    $Self->PrintError("Can't delete permission");
    return $Self->ExitCodeError();
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
