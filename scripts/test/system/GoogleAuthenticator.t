# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

local $ENV{TZ} = 'UTC';

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

$Kernel::OM->Get('Config')->Set(
    Key   => 'TimeZone',
    Value => 0,
);
$Kernel::OM->Get('Config')->Set(
    Key   => 'TimeZoneUser',
    Value => 0,
);
$Kernel::OM->Get('Config')->Set(
    Key   => 'TimeZoneUserBrowserAutoOffset',
    Value => 0,
);

# set fixed time to have predetermined verifiable results
$Helper->FixedTimeSet(0);

# disable email checks to create new user
$Kernel::OM->Get('Config')->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

my $TestAgent = $Helper->TestUserCreate();

my $UserID = $Kernel::OM->Get('User')->UserLookup(
    UserLogin => $TestAgent
);

# configure two factor auth backend
my %CurrentConfig = (
    'SecretPreferencesKey' => 'UnitTestUserGoogleAuthenticatorSecretKey',
    'AllowEmptySecret'     => 0,
    'AllowPreviousToken'   => 0,
    'TimeZone'             => 0,
    'Secret'               => q{},
    'Time'                 => 0,
);

$Kernel::OM->Get('Config')->Set(
    Key   => 'AuthTwoFactorModule10',
    Value => 'Kernel::System::Auth::TwoFactor::GoogleAuthenticator',
);

for my $ConfigKey ( sort keys %CurrentConfig ) {
    $Kernel::OM->Get('Config')->Set(
        Key   => 'AuthTwoFactorModule10::' . $ConfigKey,
        Value => $CurrentConfig{$ConfigKey},
    );
}

my @Tests = (
    {
        Name               => 'No secret, AllowEmptySecret = 0',
        ExpectedAuthResult => undef,
        Secret             => undef,
        AllowEmptySecret   => 0,
        Silent             => 1
    },
    {
        Name               => 'No secret, AllowEmptySecret = 1',
        ExpectedAuthResult => $TestAgent,
        Secret             => undef,
        AllowEmptySecret   => 1,
    },
    {
        Name               => 'Invalid token',
        ExpectedAuthResult => undef,
        Secret             => 'UNITTESTUNITTEST',
        TwoFactorToken     => '123456',
    },
    {
        Name               => 'Valid token',
        ExpectedAuthResult => $TestAgent,
        Secret             => 'UNITTESTUNITTEST',
        TwoFactorToken     => '761321',
    },
    {
        Name               => 'Valid token, different secret',
        ExpectedAuthResult => undef,
        Secret             => 'UNITTESTUNITTESX',
        TwoFactorToken     => '761321',
    },
    {
        Name               => 'Previous token, AllowPreviousToken = 0',
        ExpectedAuthResult => undef,
        Secret             => 'UNITTESTUNITTEST',
        TwoFactorToken     => '761321',
        AllowPreviousToken => 0,
        FixedTimeSet       => 30,
    },
    {
        Name               => 'Previous token, AllowPreviousToken = 1',
        ExpectedAuthResult => $TestAgent,
        Secret             => 'UNITTESTUNITTEST',
        TwoFactorToken     => '761321',
        AllowPreviousToken => 1,
        FixedTimeSet       => 30,
    },
    {
        Name               => 'New valid token',
        ExpectedAuthResult => $TestAgent,
        Secret             => 'UNITTESTUNITTEST',
        TwoFactorToken     => '002639',
        FixedTimeSet       => 30,
    },
    {
        Name               => 'Even older token, AllowPreviousToken = 1',
        ExpectedAuthResult => undef,
        Secret             => 'UNITTESTUNITTEST',
        TwoFactorToken     => '761321',
        AllowPreviousToken => 1,
        FixedTimeSet       => 60,
    },
    {
        Name               => 'Valid token for different time zone',
        ExpectedAuthResult => $TestAgent,
        Secret             => 'UNITTESTUNITTEST',
        TwoFactorToken     => '281099',
        FixedTimeSet       => 0,
        TimeZone           => 1,
    },
);

for my $Test (@Tests) {

    $Kernel::OM->ObjectsDiscard(
        Objects => ['Auth']
    );

    # update secret if necessary
    if (
        (
            $Test->{Secret}
            || q{}
        ) ne $CurrentConfig{Secret}
        && !$Test->{KeepOldSecret}
    ) {
        $CurrentConfig{Secret} = $Test->{Secret} || q{};
        $Kernel::OM->Get('User')->SetPreferences(
            Key    => 'UnitTestUserGoogleAuthenticatorSecretKey',
            Value  => $CurrentConfig{Secret},
            UserID => $UserID,
        );
    }

    # update time zone if necessary
    if (
        (
            $Test->{TimeZone}
            || '0'
        ) ne $CurrentConfig{TimeZone}
    ) {
        $CurrentConfig{TimeZone} = $Test->{TimeZone} || '0';
        $Kernel::OM->Get('Config')->Set(
            Key   => 'TimeZone',
            Value => $CurrentConfig{TimeZone},
        );
        my $DatabaseHandle = $Kernel::OM->Get('DB')->{dbh};

        $Kernel::OM->Get('DB')->{dbh} = undef;

        # a different timezone config requires a new time object
        $Kernel::OM->ObjectsDiscard(
            Objects => ['Time'],
        );
        $Kernel::OM->Get('DB')->{dbh} = $DatabaseHandle;
    }

    # update config if necessary
    CONFIGKEY:
    for my $ConfigKey (
        qw(
            AllowEmptySecret AllowPreviousToken
        )
    ) {
        next CONFIGKEY if ( $Test->{$ConfigKey} || q{} ) eq $CurrentConfig{$ConfigKey};

        $CurrentConfig{$ConfigKey} = $Test->{$ConfigKey} || q{};

        $Kernel::OM->Get('Config')->Set(
            Key   => 'AuthTwoFactorModule10::' . $ConfigKey,
            Value => $CurrentConfig{$ConfigKey},
        );
    }

    # update time if necessary
    if (
        (
            $Test->{FixedTimeSet}
            || 0
        ) ne $CurrentConfig{Time}
    ) {
        $CurrentConfig{Time} = $Test->{FixedTimeSet} || 0;
        $Helper->FixedTimeSet( $CurrentConfig{Time} );
    }

    # test agent auth
    my $AuthResult = $Kernel::OM->Get('Auth')->Auth(
        User           => $TestAgent,
        UsageContext   => 'Agent',
        Pw             => $TestAgent,
        TwoFactorToken => $Test->{TwoFactorToken},
        Silent         => $Test->{Silent} || 0
    );
    $Self->Is(
        $AuthResult,
        $Test->{ExpectedAuthResult},
        $Test->{Name},
    );
}

# rollback transaction on database
$Helper->Rollback();

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
