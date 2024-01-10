# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Auth::TwoFactor::GoogleAuthenticator;

use strict;
use warnings;

our @ObjectDependencies = (
    'Config',
    'Log',
    'OTP',
    'User',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{Count} = $Param{Count} || '';

    return $Self;
}

sub Auth {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(User UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my $ConfigObject = $Kernel::OM->Get('Config');
    my $SecretPreferencesKey = $ConfigObject->Get("AuthTwoFactorModule$Self->{Count}::SecretPreferencesKey") || '';
    if ( !$SecretPreferencesKey ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Found no configuration for SecretPreferencesKey in AuthTwoFactorModule.",
        );
        return;
    }

    # check if user has secret stored in preferences
    my %UserPreferences = $Kernel::OM->Get('User')->GetPreferences(
        UserID => $Param{UserID},
    );
    if ( !$UserPreferences{$SecretPreferencesKey} ) {

        # if login without a stored secret key is permitted, this counts as passed
        if ( $ConfigObject->Get("AuthTwoFactorModule$Self->{Count}::AllowEmptySecret") ) {
            return 1;
        }

        return if $Param{Silent};

        # otherwise login counts as failed
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Found no SecretPreferencesKey for user $Param{User}.",
        );
        return;
    }

    # if we get to here (user has preference), we need a passed token
    if ( !$Param{TwoFactorToken} ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need TwoFactorToken!"
        );
        return;
    }

    # generate otp based on secret from preferences
    my $OTP = $Kernel::OM->Get('OTP')->GenerateTOTP(
        Base32Secret => $UserPreferences{$SecretPreferencesKey},
        TimeStep     => 30,
        Digits       => 6,
        Algorithm    => 'SHA1',
    );

    # compare against user provided otp
    if ( $Param{TwoFactorToken} ne $OTP ) {

        # check if previous token is also to be accepted
        if ( $ConfigObject->Get("AuthTwoFactorModule$Self->{Count}::AllowPreviousToken") ) {

            # try again with previous otp (from 30 seconds ago)
            $OTP = $Kernel::OM->Get('OTP')->GenerateTOTP(
                Base32Secret => $UserPreferences{$SecretPreferencesKey},
                TimeStep     => 30,
                Digits       => 6,
                Algorithm    => 'SHA1',
                Previous     => 1,
            );
        }

        if ( $Param{TwoFactorToken} ne $OTP ) {

            # log failure
            $Kernel::OM->Get('Log')->Log(
                Priority => 'notice',
                Message  => "User: $Param{User} two factor authentication failed (non-matching otp).",
            );
            return;
        }
    }

    # log success
    $Kernel::OM->Get('Log')->Log(
        Priority => 'notice',
        Message  => "User: $Param{User} two factor authentication ok.",
    );

    return 1;
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
