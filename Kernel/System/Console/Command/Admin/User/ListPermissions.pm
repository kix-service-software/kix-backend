# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::User::ListPermissions;

use strict;
use warnings;

use Kernel::System::Role::Permission;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'User'
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('List permissions of a user.');
    $Self->AddOption(
        Name        => 'user',
        Description => 'Specify the user login of the agent.',
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
    $Self->AddOption(
        Name        => 'active',
        Description => 'Only list active permissions (ignore non-valid roles).',
        Required    => 0,
        HasValue    => 0,
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

    my $Compact    = $Self->GetOption('compact') || 0;
    my $OnlyActive = $Self->GetOption('active') || 0;

    $Self->Print("<yellow>Listing permissions of user $Self->{UserLogin}...</yellow>\n");

    my %PermissionList = $Kernel::OM->Get('User')->PermissionList(
        UserID => $Self->{UserID},
        Valid  => $OnlyActive,
    );

    if ( !$Compact ) {
        foreach my $ID ( sort keys %PermissionList ) {
            my %Permission = %{$PermissionList{$ID}};

            foreach my $Key ( qw(RoleID ID TypeID Target Value IsRequired Comment CreateBy CreateTime ChangeBy ChangeTime) ) {
                my $Label = $Key;
                my $Value = $Permission{$Key} || '-';
                if ( $Key eq 'Value' ) {
                    $Value = $Kernel::OM->Get('Role')->GetReadablePermissionValue(
                        Value  => $Permission{Value},
                        Format => 'ExtraLong'
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
                elsif ( $Key eq 'RoleID' ) {
                    $Label = 'Role';
                    my %Role = $Kernel::OM->Get('Role')->RoleGet(
                        ID => $Value,
                    );
                    $Value = $Role{Name};
                    $Value .= ' (inactive)' if $Role{ValidID} != 1;
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
        $Self->Print("ID     Type                      Role                      Required  Value Target\n");
        $Self->Print("------ ------------------------- ------------------------- -------- ------ --------------------------------------------------------------------------------\n");

        foreach my $ID ( sort keys %PermissionList ) {
            my $Permission = $PermissionList{$ID};

            # prepare permission value
            my $Value = $Kernel::OM->Get('Role')->GetReadablePermissionValue(
                Value  => $Permission->{Value},
                Format => 'Short'
            );

            # prepare type
            my %PermissionType = $Kernel::OM->Get('Role')->PermissionTypeGet(
                ID     => $Permission->{TypeID},
                UserID => 1,
            );

            # prepare required
            my $IsRequired = $Permission->{IsRequired} ? 'yes' : '';

            # prepare role
            my %Role = $Kernel::OM->Get('Role')->RoleGet(
                ID => $Permission->{RoleID},
            );
            my $RoleName = $Role{Name};
            $RoleName .= ' (inactive)' if $Role{ValidID} != 1;

            $Self->Print(sprintf("%6i %-25s %-25s %8s %6s %-80s\n", $ID, $PermissionType{Name}, $RoleName, $IsRequired, $Value, $Permission->{Target}));

            if ( $Permission->{Comment} ) {
                $Self->Print(sprintf("%74s %s\n","", "(Comment: $Permission->{Comment})"));
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
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
