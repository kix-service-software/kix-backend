# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
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

    my %Result = $Kernel::OM->Get('User')->SearchPreferences(
        Key    => 'OutOfOfficeEnd',
        UserID => 1,
    );

    if ( %Result ) {
        my @CurrDate = $Kernel::OM->Get('Time')->SystemTime2Date(
            SystemTime => $Kernel::OM->Get('Time')->SystemTime()
        );
        my $CurrStamp = $CurrDate[5]
            . $CurrDate[4]
            . $CurrDate[3];

        for my $UserID ( keys %Result ) {
            my $Date = $Result{$UserID};
            next if !$Date;
            $Date =~ s/\s+\d{2}:\d{2}:\d{2}$//g;
            $Date =~ s/-//g;

            next if $Date >= $CurrStamp;

            $Kernel::OM->Get('User')->DeletePreferences(
                UserID => $UserID,
                Key    => 'OutOfOfficeStart'
            );
            $Kernel::OM->Get('User')->DeletePreferences(
                UserID => $UserID,
                Key    => 'OutOfOfficeEnd'
            );
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
