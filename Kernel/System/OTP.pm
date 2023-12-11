# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::OTP;

use strict;
use warnings;

our @ObjectDependencies = (
    'Log',
    'Main',
    'Time',
);

=head1 NAME

Kernel::System::OTP - one time password lib

=head1 SYNOPSIS

Functions for generating one time passwords.

=head1 PUBLIC INTERFACE

=over 4

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $OTPObject = $Kernel::OM->Get('OTP');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item GenerateTOTP()

get time-based one time password

    my $TOTP = $OTPObject->GenerateTOTP(
        Base32Secret => 'SECRET234',        # Base32 encoded secret
        TimeStep     => 30,                 # Optional. TTL of OTP Defaults to 30.
        Digits       => 6,                  # Optional. Number of digits of the generated OPT. Defaults to 6. Integer from 6 to 8
        Algorithm    => 'SHA1',             # Optional. Used algorithm for HMAC. Defaults to SHA1. SHA1, SHA256 and SHA512 supported
        Previous     => 0,                  # Optional. Generate a previous/future OTP. Integer
    );

returns

    my $TOTP = 'ABCDEF';

=cut

sub GenerateTOTP {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Base32Secret)) {
        if ( !$Param{$_} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $_!"
                );
            }
            return;
        }
    }

    # convert provided string to upper case
    $Param{Base32Secret} = uc( $Param{Base32Secret} );

    # validate Base32Secret
    if ( $Param{Base32Secret} !~ m/^[A-Z2-7=]+$/ ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Invalid Base32Secret!"
            );
        }
        return;
    }

    # use default, when TimeStep is not given
    if ( !defined( $Param{TimeStep} ) ) {
        $Param{TimeStep} = 30;
    }
    # validate TimeStep
    elsif ( $Param{TimeStep} !~ m/^[1-9][0-9]*$/ ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Invalid TimeStep!"
            );
        }
        return;
    }

    # use default, when Digits is not given
    if ( !defined( $Param{Digits} ) ) {
        $Param{Digits} = 6;
    }
    # validate Digits
    elsif ( $Param{Digits} !~ m/^[6-8]$/ ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Invalid Digits!"
            );
        }
        return;
    }

    # use default, when Algorithm is not given
    if ( !defined( $Param{Algorithm} ) ) {
        $Param{Algorithm} = 'SHA1';
    }
    # validate Algorithm
    elsif (
        $Param{Algorithm} ne 'SHA1'
        && $Param{Algorithm} ne 'SHA256'
        && $Param{Algorithm} ne 'SHA512'
    ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Invalid Algorithm!"
            );
        }
        return;
    }

    # use default, when Previous is not given
    if ( !defined( $Param{Previous} ) ) {
        $Param{Previous} = 0;
    }
    # validate Previous
    elsif ( $Param{Previous} !~ m/^-?[0-9]+$/ ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Invalid Previous!"
            );
        }
        return;
    }

    my $TOTP = $Self->_GenerateTOTP(
        Base32Secret => $Param{Base32Secret},
        TimeStep     => $Param{TimeStep},
        Digits       => $Param{Digits},
        Algorithm    => $Param{Algorithm},
        Previous     => $Param{Previous},
        Silent       => $Param{Silent},
    );

    return $TOTP;
}

sub _GenerateTOTP {
    my ( $Self, %Param ) = @_;

    # algorithm based on RfC 6238 for current time stamp, code inspired by Authen::TOTP

    # decode base32 encoded secret
    my $Secret = $Self->_DecodeBase32(
        Base32String => $Param{Base32Secret},
        Silent       => $Param{Silent},
    );
    if ( !$Secret ) {
        return;
    }

    # get unix timestamp
    my $TimeStamp = $Kernel::OM->Get('Time')->SystemTime();

    # get time count for time stamp
    my $TimeCount = int( $TimeStamp / $Param{TimeStep} );

    # handle parameter Previous
    if ( $Param{Previous} != 0 ) {
        $TimeCount -= $Param{Previous};
    }

    # extend time count to 16 character hex value
    my $HexTimeCount = sprintf( "%016x", $TimeCount );

    # convert to high nybble first hex string
    my $HNHexTimeCount = pack( 'H*', $HexTimeCount );

    # generate keyed-hash message authentication code (HMAC)
    my $HMAC = $Self->_HMAC(
        Key       => $Secret,
        Count     => $HNHexTimeCount,
        Algorithm => $Param{Algorithm},
        Silent    => $Param{Silent},
    );
    if ( !$HMAC ) {
        return;
    }

    # get the 4 least significant bits (1 hex char) from the hmac as offset
    my $Offset = hex( substr( $HMAC, -1 ) );

    # get 4-byte dynamic binary code from hmac
    my $TruncatedHMAC = hex( substr( $HMAC, $Offset * 2, 8 ) ) & 0x7fffffff;

    # get zero-padded reduced code
    my $TOTP = sprintf( '%0' . $Param{Digits} . 'd', ( $TruncatedHMAC % ( 10 ** $Param{Digits} ) ) );

    return $TOTP;
}

sub _DecodeBase32 {
    my ( $Self, %Param ) = @_;

    # algorithm based on RfC 3548, code inspired by MIME::Base32

    # init variable with provided string
    my $Decoded = $Param{Base32String};

    # transliterate into binary characters
    $Decoded =~ tr/A-Z2-7/\0-\37/;

    # unpack from descanding order bit string
    $Decoded = unpack( 'B*', $Decoded );

    # keep the 5 least significant bits of every 8-bit group
    $Decoded =~ s/0{3}(.{5})/$1/g;

    # trim to full 8 bit groups
    my $Length = length( $Decoded );
    if ( $Length % 8 ) {
        $Decoded = substr( $Decoded, 0, $Length - $Length % 8 );
    }

    # pack as descending order bit string
    $Decoded = pack( 'B*', $Decoded );

    return $Decoded;
}

sub _HMAC {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $MainObject = $Kernel::OM->Get('Main');

    # require Digest::SHA
    my $DigestSHALoaded = $MainObject->Require(
        'Digest::SHA',
        Silent => 1,
    );
    if  ( $DigestSHALoaded ) {
        if ( $Param{Algorithm} eq 'SHA512' ) {
            return Digest::SHA::hmac_sha512_hex( $Param{Count}, $Param{Key} );
        }
        elsif ( $Param{Algorithm} eq 'SHA256' ) {
            return Digest::SHA::hmac_sha256_hex( $Param{Count}, $Param{Key} );
        }
        else {
            return Digest::SHA::hmac_sha1_hex( $Param{Count}, $Param{Key} );
        }
    }
    else {
        # require Digest::SHA::PurePerl
        my $DigestSHAPurePerlLoaded = $MainObject->Require(
            'Digest::SHA::PurePerl',
            Silent => 1,
        );
        if ( !$DigestSHAPurePerlLoaded ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Could require neither Digest::SHA nor Digest::SHA::PurePerl!"
                );
            }
            return;
        }
        if ( $Param{Algorithm} eq 'SHA512') {
            return Digest::SHA::PurePerl::hmac_sha512_hex( $Param{Count}, $Param{Key} );
        }
        elsif ( $Param{Algorithm} eq 'SHA256') {
            return Digest::SHA::PurePerl::hmac_sha256_hex( $Param{Count}, $Param{Key} );
        }
        else {
            return Digest::SHA::PurePerl::hmac_sha1_hex( $Param{Count}, $Param{Key} );
        }
    }
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
