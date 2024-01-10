# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# set fixed time for test
$Helper->FixedTimeSet(
    $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
        String => '2014-01-01 12:00:00',
    ),
);

my @Tests = (
    {
        Name   => 'GenerateTOTP - Missing Base32Secret',
        Input  => {},
        Output => '',
    },
    {
        Name   => 'GenerateTOTP - Invalid Base32Secret',
        Input  => {
            Base32Secret => 'Passw0rd',
        },
        Output => '',
    },
    {
        Name   => 'GenerateTOTP - Invalid TimeStep',
        Input  => {
            Base32Secret => 'SECRET234',
            TimeStep     => 0,
        },
        Output => '',
    },
    {
        Name   => 'GenerateTOTP - Invalid Digits',
        Input  => {
            Base32Secret => 'SECRET234',
            Digits       => 4,
        },
        Output => '',
    },
    {
        Name   => 'GenerateTOTP - Invalid Algorithm',
        Input  => {
            Base32Secret => 'SECRET234',
            Algorithm    => 'SHA2',
        },
        Output => '',
    },
    {
        Name   => 'GenerateTOTP - Invalid Previous',
        Input  => {
            Base32Secret => 'SECRET234',
            Previous     => 'abc',
        },
        Output => '',
    },
    {
        Name   => 'GenerateTOTP - Valid Base32Secret',
        Input  => {
            Base32Secret => 'SECRET234',
        },
        Output => '876948',
    },
    {
        Name   => 'GenerateTOTP - Valid Base32Secret, TimeStep 60s',
        Input  => {
            Base32Secret => 'SECRET234',
            TimeStep     => 60,
        },
        Output => '371471',
    },
    {
        Name   => 'GenerateTOTP - Valid Base32Secret, eigth Digits',
        Input  => {
            Base32Secret => 'SECRET234',
            Digits       => 8,
        },
        Output => '67876948',
    },
    {
        Name   => 'GenerateTOTP - Valid Base32Secret, Algorithm SHA256',
        Input  => {
            Base32Secret => 'SECRET234',
            Algorithm    => 'SHA256',
        },
        Output => '732950',
    },
    {
        Name   => 'GenerateTOTP - Valid Base32Secret, Algorithm SHA512',
        Input  => {
            Base32Secret => 'SECRET234',
            Algorithm    => 'SHA512',
        },
        Output => '529007',
    },
    {
        Name   => 'GenerateTOTP - Valid Base32Secret, previous OTP',
        Input  => {
            Base32Secret => 'SECRET234',
            Previous     => 1,
        },
        Output => '909756',
    },
    {
        Name   => 'GenerateTOTP - Valid Base32Secret, one before previous OTP',
        Input  => {
            Base32Secret => 'SECRET234',
            Previous     => 2,
        },
        Output => '441849',
    },
    {
        Name   => 'GenerateTOTP - Valid Base32Secret, next OTP',
        Input  => {
            Base32Secret => 'SECRET234',
            Previous     => -1,
        },
        Output => '519952',
    },
    {
        Name   => 'GenerateTOTP - Valid Base32Secret, all parameter',
        Input  => {
            Base32Secret => 'SECRET234',
            TimeStep     => 45,
            Digits       => 7,
            Algorithm    => 'SHA1',
            Previous     => 3,
        },
        Output => '2225250',
    },
);

for my $Test (@Tests) {

    my $TOTP = $Kernel::OM->Get('OTP')->GenerateTOTP(
        %{ $Test->{Input} },
        Silent => $Test->{Output} ? 0 : 1,
    );

    if ( $Test->{Output} ) {
        $Self->Is(
            $Test->{Output},
            $TOTP,
            $Test->{Name},
        );
    }
    else {
        $Self->False(
            $TOTP,
            $Test->{Name}
        );
    }
}

# reset fixed time
$Helper->FixedTimeUnset();

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
