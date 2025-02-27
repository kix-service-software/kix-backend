# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::Role::ListPermissions;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Role',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('List permissions of a role.');
    $Self->AddOption(
        Name        => 'role-name',
        Description => 'Name of the role.',
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'compact',
        Description => 'Output a compact view.',
        Required    => 0,
        HasValue    => 0,
    );

    return;
}

sub PreRun {

    my ( $Self, %Param ) = @_;

    $Self->{RoleName} = $Self->GetOption('role-name');

    # check role
    $Self->{RoleID} = $Kernel::OM->Get('Role')->RoleLookup( Role => $Self->{RoleName} );
    if ( !$Self->{RoleID} ) {
        die "Role $Self->{RoleName} does not exist.\n";
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Compact = $Self->GetOption('compact') || 0;

    $Self->Print("<yellow>Listing permissions of role $Self->{RoleName}...</yellow>\n");

    my @PermissionIDs = $Kernel::OM->Get('Role')->PermissionList(
        RoleID  => $Self->{RoleID},
        UserID  => 1,
    );

    if ( !$Compact ) {
        foreach my $ID ( sort @PermissionIDs ) {
            my %Permission = $Kernel::OM->Get('Role')->PermissionGet(
                ID => $ID
            );
            foreach my $Key ( qw(ID TypeID Target Value IsRequired Comment CreateBy CreateTime ChangeBy ChangeTime) ) {
                my $Label = $Key;
                my $Value = $Permission{$Key} || '-';
                if ( $Key eq 'Value' ) {
                    $Value = $Kernel::OM->Get('Role')->GetReadablePermissionValue(
                        Value  => $Permission{Value},
                        Format => 'Long'
                    );
                }
                elsif ( $Key eq 'TypeID' ) {
                    $Label = 'Type';
                    my %PermissionType = $Kernel::OM->Get('Role')->PermissionTypeGet(
                        ID     => $Value,
                        UserID => 1,
                    );
                    $Value = $PermissionType{Name};
                }
                elsif ( $Key =~ /IsRequired/ ) {
                    $Value = $Permission{$Key} ? 'yes' : 'no';
                }
                elsif ( $Key =~ /CreateBy|ChangeBy/ ) {
                    $Value = $Kernel::OM->Get('User')->UserLookup(
                        UserID => $Value,
                        Silent => 1,
                    );
                }
                $Self->Print(sprintf("    %10s: %s\n", $Label, $Value));
            }
            $Self->Print("-------------------------------------------------------------------------\n");
        }
    }
    else {
        $Self->Print("ID     Type                      Required  Value Target\n");
        $Self->Print("------ ------------------------- -------- ------ --------------------------------------------------------------------------------\n");

        foreach my $ID ( sort @PermissionIDs ) {
            my %Permission = $Kernel::OM->Get('Role')->PermissionGet(
                ID => $ID,
            );

            # prepare permission value
            my $Value = $Kernel::OM->Get('Role')->GetReadablePermissionValue(
                Value  => $Permission{Value},
                Format => 'Short'
            );

            # prepare type
            my %PermissionType = $Kernel::OM->Get('Role')->PermissionTypeGet(
                ID     => $Permission{TypeID},
                UserID => 1,
            );

            # prepare required
            my $IsRequired = $Permission{IsRequired} ? 'yes' : '';

            $Self->Print(sprintf("%6i %-25s %8s %6s %-80s\n", $Permission{ID}, $PermissionType{Name}, $IsRequired, $Value, $Permission{Target}));

            if ( $Permission{Comment} ) {
                $Self->Print(sprintf("%41s %s\n","", "(Comment: $Permission{Comment})"));
            }
        }
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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
