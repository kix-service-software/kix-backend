# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Auth::MFA::TOTP;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = qw(
    Log
    Main
    OTP
    User
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # check for backend name
    if ( !$Param{Name} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Name for multi factor backend!'
        );
        return;
    }

    # set MFA type
    $Self->{MFAType} = 'TOTP';

    # use backend name as MFAuthName
    $Self->{MFAPreference} = 'MFA_' . $Self->{MFAType} . '_' . $Param{Name};

    # get totp settings
    $Self->{TOTPTimeStep}  = $Param{Config}->{TimeStep}  || '30';
    $Self->{TOTPDigits}    = $Param{Config}->{Digits}    || '6';
    $Self->{TOTPAlgorithm} = $Param{Config}->{Algorithm} || 'SHA1';

    $Self->{AllowEmptySecret} = $Param{Config}->{AllowEmptySecret} || '0';
    $Self->{MaxPreviousToken} = $Param{Config}->{MaxPreviousToken} || '0';

    $Self->{SecretLength} = $Param{Config}->{SecretLength} || '8';

    if (
        $Self->{MaxPreviousToken} ne '0'
        && !IsPositiveInteger( $Self->{MaxPreviousToken} )
    ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'MaxPreviousToken in Config has to be 0 or a positive integer!'
        );
        return;
    }

    return $Self;
}

sub GetMFAuthType {
    my ( $Self, %Param ) = @_;

    return $Self->{MFAType};
}

sub GetMFAuthMethod {
    my ( $Self, %Param ) = @_;

    return {
        Type => $Self->{MFAType},
        Data => {
            Preference     => $Self->{MFAPreference},
            GenerateSecret => 1
        }
    };
}

sub MFAuth {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed ( qw(User UserID) ) {
        if ( !$Param{ $Needed } ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!"
                );
            }
            return 0;
        }
    }

    # get user preferences
    my %UserPreferences = $Kernel::OM->Get('User')->GetPreferences(
        UserID => $Param{UserID},
    );

    # check if user has this MFA enabled
    if ( !$UserPreferences{ $Self->{MFAPreference} } ) {
        return;
    }

    # check if user has secret stored in preferences
    if ( !$UserPreferences{ $Self->{MFAPreference} . '_Secret' } ) {
        # if login without a stored secret key is permitted, this counts as skipped
        if ( $Self->{AllowEmptySecret} ) {
            return;
        }

        # otherwise login counts as failed
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "MFA Secret not set for user $Param{User}."
            );
        }
        return 0;
    }

    # check if MFAToken is given
    if ( ref( $Param{MFAToken} ) ne 'HASH' ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Parameter MFAToken has to be a HASH!'
            );
        }
        return 0;
    }
    for my $Needed ( qw(Type Value) ) {
        if ( !$Param{MFAToken}->{ $Needed } ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed in MFAToken!"
                );
            }
            return 0;
        }
    }

    # check for relevant type
    if ( $Param{MFAToken}->{Type} ne $Self->{MFAType} ) {
        return;
    }

    # check current and configured previous token
    for my $Previous ( 0 .. $Self->{MaxPreviousToken} ) {
        # generate token
        my $TOTP = $Kernel::OM->Get('OTP')->GenerateTOTP(
            Base32Secret => $UserPreferences{ $Self->{MFAPreference} . '_Secret' },
            TimeStep     => $Self->{TOTPTimeStep},
            Digits       => $Self->{TOTPDigits},
            Algorithm    => $Self->{TOTPAlgorithm},
            Previous     => $Previous,
            Silent       => $Param{Silent}
        );

        # check token
        if ( $TOTP eq $Param{MFAToken}->{Value} ) {
            return 1;
        }
    }

    # if no token matched, login counts as failed
    return 0;
}

sub GenerateSecret {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed ( qw(MFAuth) ) {
        if ( !$Param{ $Needed } ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!"
                );
            }
            return;
        }
    }

    # do not generate secret, if preference does not match the requested secret
    return if ( $Param{MFAuth} ne $Self->{MFAPreference} );

    # generate secret
    my $Secret = $Kernel::OM->Get('Main')->GenerateRandomString(
        Dictionary => [ 2..7, 'A'..'Z' ],       # Base32
        Length     => $Self->{SecretLength}
    );

    return $Secret;
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
