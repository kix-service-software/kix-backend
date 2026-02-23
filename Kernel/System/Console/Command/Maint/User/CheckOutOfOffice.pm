# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::User::CheckOutOfOffice;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = qw(
    User Time
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Checks whether the OutOfOffice set by the user has expired and resets it.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Check OutOfOffice...</yellow>\n");

    my %Users = $Kernel::OM->Get('User')->UserSearch(
        IsOutOfOfficeEnd => 1
    );

    for my $UserID ( keys %Users ) {
        my %User = $Kernel::OM->Get('User')->GetUserData(
            UserID => $UserID
        );

        $Kernel::OM->Get('User')->UserUpdate(
            %User,
            OutOfOfficeEnd        => undef,
            OutOfOfficeStart      => undef,
            OutOfOfficeSubstitute => undef,
            ChangeUserID          => 1
        );
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
