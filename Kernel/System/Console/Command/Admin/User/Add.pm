# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::User::Add;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Role',
    'User',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Add a user.');
    $Self->AddOption(
        Name        => 'user-name',
        Description => "User name (login) for the new user.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'password',
        Description => "Password for the new user. If left empty, a password will be created automatically.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'context',
        Description => 'The context of the new user. Can be Agent, Customer or Both (Default: Agent).',
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/(Agent|Customer|Both)/smx,
    );
    $Self->AddOption(
        Name        => 'roles',
        Description => "Comma separated list of roles to which the new user should be added.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    # check if all groups exist
    my @Roles = split( /\s*,\s*/, ( $Self->GetOption('roles') || '' ) );
    my %RoleList = reverse $Kernel::OM->Get('Role')->RoleList( Valid => 1 );

    ROLE:
    for my $Role (@Roles) {
        if ( !$RoleList{$Role} ) {
            die "Role '$Role' does not exist or is not valid.\n";
        }
        $Self->{Roles}->{ $RoleList{$Role} } = $Role;
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Adding a new user...</yellow>\n");

    my $Context = $Self->GetOption('context') || '';

    # add user
    my $UserID = $Kernel::OM->Get('User')->UserAdd(
        UserLogin    => $Self->GetOption('user-name'),
        UserPw       => $Self->GetOption('password'),
        IsAgent      => (!$Context || $Context =~ /(Agent|Both)/) ? 1 : 0,
        IsCustomer   => ($Context =~ /(Customer|Both)/) ? 1 : 0,
        ChangeUserID => 1,
        UserID       => 1,
        ValidID      => 1,
    );

    if ( !$UserID ) {
        $Self->PrintError("Can't add user.");
        return $Self->ExitCodeError();
    }

    for my $RoleID ( sort keys %{ $Self->{Roles} } ) {

        my $Success = $Kernel::OM->Get('Role')->RoleUserAdd(
            AssignUserID => $UserID,
            RoleID       => $RoleID,
            UserID       => 1,
        );
        if ($Success) {
            $Self->Print( "<green>User added to role '" . $Self->{Roles}->{$RoleID} . "'</green>\n" );
        }
        else {
            $Self->PrintError( "Failed to add user to role '" . $Self->{Role}->{$RoleID} . "'." );
        }
    }

    $Self->Print("<green>Done.</green>\n");
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
