# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::Auth::MFA::RemoveSecret;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = qw(
    User
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Disable MFA and remove MFA secret for given users.');
    $Self->AddOption(
        Name        => 'mfa',
        Description => "Name of MFA to disable.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'user',
        Description => "Login of user to disable MFA for.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
        Multiple    => 1,
    );

    return;
}

sub Run {
    my ($Self) = @_;

    my $MFAuth = $Self->GetOption('mfa');
    my @Users  = @{ $Self->GetOption('user') // [] };

    USER:
    for my $User ( @Users ) {
        # print current user login to console
        $Self->Print( $User . ": ");

        my $UserID = $Kernel::OM->Get('User')->UserLookup(
            UserLogin => $User,
            Silent    => 1,
        );
        if ( !$UserID ) {
            $Self->Print("<red>Unknown user!</red>\n");

            next USER;
        }

        # check if mfa is enabled
        my %Preferences = $Kernel::OM->Get('User')->GetPreferences(
            UserID => $UserID,
        );
        if ( !$Preferences{ $MFAuth } ) {
            $Self->Print("<yellow>MFA already disabled</yellow>\n");

            next USER;
        }

        # disable mfa
        my $Success = $Kernel::OM->Get('User')->DeletePreferences(
            Key    => $MFAuth,
            UserID => $UserID,
        );
        if ( !$Success ) {
            $Self->Print("<red>Disable failed!</red>\n");

            next USER;
        }

        # remove secret
        $Success = $Kernel::OM->Get('User')->DeletePreferences(
            Key    => $MFAuth . '_Secret',
            UserID => $UserID,
        );
        if ( !$Success ) {
            $Self->Print("<red>Removal failed!</red>\n");

            next USER;
        }

        $Self->Print("<green>MFA disabled</green>\n");
    }

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
