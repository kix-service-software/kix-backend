# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
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
    'Role',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('List users assigned to a role.');
    $Self->AddOption(
        Name        => 'role-name',
        Description => 'Name of the role.',
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'all',
        Description => 'List all users grouped by role.',
        Required    => 0,
        HasValue    => 0,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub PreRun {

    my ( $Self, %Param ) = @_;

    $Self->{RoleName} = $Self->GetOption('role-name');
    $Self->{ListAll} =  $Self->GetOption('all');


    if (!$Self->{ListAll} && !$Self->{RoleName}) {
        print $Self->GetUsageHelp();
        return $Self->ExitCodeOk();
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    if ($Self->{ListAll}) {
        my %Roles = $Kernel::OM->Get('Role')->RoleList();
        for my $RoleID (keys %Roles) {
            $Self->_ListUsers(
                RoleID   => $RoleID,
                RoleName => $Roles{$RoleID},
            );
        }
    }
    elsif($Self->{RoleName}) {
        # check role
        $Self->{RoleID} = $Kernel::OM->Get('Role')->RoleLookup( Role => $Self->{RoleName} );
        if ( !$Self->{RoleID} ) {
            die "Role $Self->{RoleName} does not exist.\n";
        }
        $Self->_ListUsers(
            RoleID   => $Self->{RoleID},
            RoleName => $Self->{RoleName},
        );
    }


    $Self->Print("<green>Done</green>\n");
    return $Self->ExitCodeOk();
}

sub _ListUsers {
    my ($Self, %Param) = @_;

    $Self->Print("<yellow>Listing users assigned to role $Param{RoleName}...</yellow>\n");

    my @UserIDs = $Kernel::OM->Get('Role')->RoleUserList(
        RoleID => $Param{RoleID},
        UserID => 1,
    );

    foreach my $ID (sort @UserIDs) {
        my %User = $Kernel::OM->Get('User')->GetUserData(
            UserID => $ID
        );
        my %UserContactData = $Kernel::OM->Get('Contact')->ContactGet(
            UserID => $User{UserID}
        );
        my $Fullname;
        my $FirstnameLastnameOrder = $Kernel::OM->Get('Config')->Get('FirstnameLastnameOrder') || 2;
        if (%UserContactData) {
            $Fullname = $Kernel::OM->Get('Contact')->_ContactFullname(
                Firstname => $UserContactData{Firstname},
                Lastname  => $UserContactData{Lastname},
                UserLogin => $User{UserLogin},
                NameOrder => $FirstnameLastnameOrder,
            );
        }
        $Self->Print("" . (!$Fullname) ? $User{UserLogin} : $Fullname . "\n");
    }
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
