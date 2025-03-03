# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::Role::UpdatePermission;

use strict;
use warnings;

use Kernel::System::Role::Permission;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Role',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Update a role permission.');
    $Self->AddOption(
        Name        => 'role-name',
        Description => 'Name of the role.',
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'permission-id',
        Description => 'The ID of the permission to be updated.',
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'type',
        Description => 'The new type of the permission (Base::Ticket, Resource, Object, Property).',
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'target',
        Description => 'The new target of the permission (i.e. "/tickets/*").',
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'value',
        Description => 'The value of the new permission (CREATE,READ,UPDATE,DELETE,DENY,NONE). You can combine different values by using a comma and plus or minus sign to add or remove the permission, i.e. +READ,-UPDATE. You can also use the alias WRITE to combine CREATE,UPDATE and DELETE.',
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'comment',
        Description => 'Comment for the new permission.',
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub PreRun {

    my ( $Self, %Param ) = @_;

    $Self->{PermissionID} = $Self->GetOption('permission-id');
    $Self->{RoleName} = $Self->GetOption('role-name');
    $Self->{PermissionType} = $Self->GetOption('type');

    # check PermissionID
    my %Permission = $Kernel::OM->Get('Role')->PermissionGet( ID => $Self->{PermissionID} );
    if ( !%Permission ) {
        die "Permission with ID $Self->{PermissionID} does not exist.\n";
    }
    $Self->{Permission} = \%Permission;

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

    # check permission type
    if ( $Self->{PermissionType} ) {
        $Self->{PermissionTypeID} = $Kernel::OM->Get('Role')->PermissionTypeLookup( Name => $Self->{PermissionType} );
        if ( !$Self->{PermissionTypeID} ) {
            die "Permission type $Self->{PermissionType} does not exist.\n";
        }
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Update permission $Self->{PermissionID} of role $Self->{RoleName}...</yellow>\n");

    my $Value = 0;
    if ( $Self->GetOption('value') ) {
        my $Mode = '';
        if ( $Self->GetOption('value') =~ /^\+/g ) {
            $Mode  = 'add';
            $Value = $Self->{Permission}->{Value};
        }
        elsif ( $Self->GetOption('value') =~ /^\-/g ) {
            $Mode = 'sub';
            $Value = $Self->{Permission}->{Value};
        }

        my %PossiblePermissions = %{Kernel::System::Role::Permission::PERMISSION()};
        $PossiblePermissions{CRUD} = Kernel::System::Role::Permission::PERMISSION_CRUD;

        foreach my $Permission ( split(/\s*\,\s*/, $Self->GetOption('value') ) ) {
            my $Mode = 'add';
            if ( $Permission =~ /^([+-])(.*?)$/g ) {
                $Mode = $1;
                $Permission = $2;
            }

            if ( $Mode eq '+' && ($Value & $PossiblePermissions{$Permission}) != $PossiblePermissions{$Permission} ) {
                $Value += $PossiblePermissions{$Permission};
            }
            elsif ( $Mode eq '-' && ($Value & $PossiblePermissions{$Permission}) == $PossiblePermissions{$Permission} ) {
                $Value -= $PossiblePermissions{$Permission};
            }
        }

        $Value = 0 if $Value < 0;
    }

    my $Result = $Kernel::OM->Get('Role')->PermissionUpdate(
        ID         => $Self->{PermissionID},
        TypeID     => $Self->{PermissionTypeID} || $Self->{Permission}->{TypeID},
        Target     => $Self->GetOption('target') || $Self->{Permission}->{Target},
        Value      => defined $Self->GetOption('value') ? $Value : $Self->{Permission}->{Value},
        IsRequired => 0,
        Comment    => defined $Self->GetOption('comment') ? $Self->GetOption('comment') : $Self->{Permission}->{Comment},
        UserID     => 1,
    );

    if ($Result) {
        $Self->Print("<green>Done</green>\n");
        return $Self->ExitCodeOk();
    }

    $Self->PrintError("Can't add permission");
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
