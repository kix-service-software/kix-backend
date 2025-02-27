# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::Auth::MFA::GenerateSecret;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = qw(
    Auth
    User
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Generate MFA secret for given users.');
    $Self->AddOption(
        Name        => 'mfa',
        Description => "Name of MFA to enable and generate a secret for.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'user',
        Description => "Login of user to generate secret for.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
        Multiple    => 1,
    );
    $Self->AddOption(
        Name        => 'force',
        Description => "Generate new secret, even if user already has one set.",
        Required    => 0,
        HasValue    => 0,
    );

    return;
}

sub Run {
    my ($Self) = @_;

    my $MFAuth = $Self->GetOption('mfa');
    my @Users  = @{ $Self->GetOption('user') // [] };
    my $Force  = $Self->GetOption('force');

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

        # check if secret is already set and should not be updated
        my %Preferences = $Kernel::OM->Get('User')->GetPreferences(
            UserID => $UserID,
        );
        if (
            $Preferences{ $MFAuth . '_Secret' }
            && !$Force
        ) {
            $Self->Print("<yellow>Skipped. Secret already set</yellow>\n");

            next USER;
        }

        # generate secret
        my $Success = $Kernel::OM->Get('Auth')->MFASecretGenerate(
            MFAuth => $MFAuth,
            UserID => $UserID
        );
        if ( !$Success ) {
            $Self->Print("<red>Generation failed!</red>\n");

            next USER;
        }

        # enable MFAuth
        $Success = $Kernel::OM->Get('User')->SetPreferences(
            Key    => $MFAuth,
            Value  => 1,
            UserID => $UserID,
        );
        if ( !$Success ) {
            $Self->Print("<red>Enabling MFA failed!</red>\n");

            next USER;
        }

        # get user preferences again to get secret
        %Preferences = $Kernel::OM->Get('User')->GetPreferences(
            UserID => $UserID,
        );

        $Self->Print("<green>$Preferences{ $MFAuth . '_Secret' }</green>\n");
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
