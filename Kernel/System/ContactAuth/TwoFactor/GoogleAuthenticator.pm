# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ContactAuth::TwoFactor::GoogleAuthenticator;

use strict;
use warnings;

use Digest::SHA qw(sha1);
use Digest::HMAC qw(hmac_hex);

use base qw(Kernel::System::Auth::TwoFactor::GoogleAuthenticator);

our @ObjectDependencies = (
    'Config',
    'Contact',
    'Log',
    'Time',
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
    if ( !$Param{User} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need User!"
        );
        return;
    }

    my $ConfigObject = $Kernel::OM->Get('Config');
    my $SecretPreferencesKey
        = $ConfigObject->Get("Contact::AuthTwoFactorModule$Self->{Count}::SecretPreferencesKey") || '';
    if ( !$SecretPreferencesKey ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Found no configuration for SecretPreferencesKey in Contact::AuthTwoFactorModule.",
        );
        return;
    }

    # check if customer has secret stored in preferences
    my %UserPreferences = $Kernel::OM->Get('Contact')->GetPreferences(
        UserID => $Param{User},
    );
    if ( !$UserPreferences{$SecretPreferencesKey} ) {

        # if login without a stored secret key is permitted, this counts as passed
        if ( $ConfigObject->Get("Contact::AuthTwoFactorModule$Self->{Count}::AllowEmptySecret") ) {
            return 1;
        }

        # otherwise login counts as failed
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Found no SecretPreferencesKey for customer $Param{User}.",
        );
        return;
    }

    # if we get to here (user has preference), we need a passed token
    if ( !$Param{TwoFactorToken} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need TwoFactorToken!"
        );
        return;
    }

    # generate otp based on secret from preferences
    my $OTP = $Self->_GenerateOTP(
        Secret => $UserPreferences{$SecretPreferencesKey},
    );

    # compare against user provided otp
    if ( $Param{TwoFactorToken} ne $OTP ) {

        # check if previous token is also to be accepted
        if ( $ConfigObject->Get("Contact::AuthTwoFactorModule$Self->{Count}::AllowPreviousToken") ) {

            # try again with previous otp (from 30 seconds ago)
            $OTP = $Self->_GenerateOTP(
                Secret   => $UserPreferences{$SecretPreferencesKey},
                Previous => 1,
            );
        }

        if ( $Param{TwoFactorToken} ne $OTP ) {

            # log failure
            $Kernel::OM->Get('Log')->Log(
                Priority => 'notice',
                Message  => "Contact: $Param{User} two factor customer authentication failed (non-matching otp).",
            );
            return;
        }
    }

    # log success
    $Kernel::OM->Get('Log')->Log(
        Priority => 'notice',
        Message  => "Contact: $Param{User} two factor customer authentication ok.",
    );

    return 1;
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
