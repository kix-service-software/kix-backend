# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
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
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 0,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# get config object
my $ConfigObject = $Kernel::OM->Get('Config');

$ConfigObject->Set(
    Key   => 'TimeZone',
    Value => 0,
);
$ConfigObject->Set(
    Key   => 'TimeZoneUser',
    Value => 0,
);
$ConfigObject->Set(
    Key   => 'TimeZoneUserBrowserAutoOffset',
    Value => 0,
);

# set fixed time to have predetermined verifiable results
$Helper->FixedTimeSet(0);

# get time object
my $TimeObject = $Kernel::OM->Get('Time');

# configure auth backend to db
$ConfigObject->Set(
    Key   => 'AuthBackend',
    Value => 'DB',
);

# no additional auth backends
for my $Count ( 1 .. 10 ) {

    $ConfigObject->Set(
        Key   => "AuthBackend$Count",
        Value => '',
    );
}

# disable email checks to create new user
$ConfigObject->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

my $UserRand     = 'example-user' . $Helper->GetRandomID();
my $TestCustomerID = 'example-customer' . $Helper->GetRandomID();

my $UserObject = $Kernel::OM->Get('User');
my $ContactObject = $Kernel::OM->Get('Contact');

# add test agent and contact
my $TestAgentID = $UserObject->UserAdd(
    UserLogin    => $UserRand,
    ValidID      => 1,
    ChangeUserID => 1,
    IsAgent      => 1,
) || die "Could not create test agent";

my $TestAgentContactID = $ContactObject->ContactAdd(
    Firstname      => 'Firstname Test1',
    Lastname       => 'Lastname Test1',
    Email          => $UserRand . '@example.com',
    AssignedUserID => $TestAgentID,
    ValidID        => 1,
    UserID         => 1,
) || die "Could not create test agent contact";


# add test custoemr and contact
my $TestCustomerID = $UserObject->UserAdd(
    UserLogin    => $TestCustomerID,
    ValidID      => 1,
    ChangeUserID => 1,
    IsCustomer   => 1,
) || die "Could not create test customer";

my $TestCustomerContactID = $ContactObject->ContactAdd(
    Source         => 'Contact',
    Firstname      => 'Firstname Test',
    Lastname       => 'Lastname Test',
    AssignedUserID => $TestCustomerID,
    ValidID        => 1,
    UserID         => 1,
) || die "Could not create test customer contact";

# configure two factor auth backend
my %CurrentConfig = (
    'SecretPreferencesKey' => 'UnitTestUserGoogleAuthenticatorSecretKey',
    'AllowEmptySecret'     => 0,
    'AllowPreviousToken'   => 0,
    'TimeZone'             => 0,
    'Secret'               => '',
    'Time'                 => 0,
);
for my $ConfigKey ( sort keys %CurrentConfig ) {
    $ConfigObject->Set(
        Key   => 'AuthTwoFactorModule10::' . $ConfigKey,
        Value => $CurrentConfig{$ConfigKey},
    );
    $ConfigObject->Set(
        Key   => 'Contact::AuthTwoFactorModule10::' . $ConfigKey,
        Value => $CurrentConfig{$ConfigKey},
    );
}

# create Google authenticator object
$Kernel::OM->ObjectParamAdd(
    'Auth::TwoFactor::GoogleAuthenticator' => {
        Count => 10,
    },
    'ContactAuth::TwoFactor::GoogleAuthenticator' => {
        Count => 10,
    },
);
my $AuthTwoFactorObject         = $Kernel::OM->Get('Auth::TwoFactor::GoogleAuthenticator');
my $ContactAuthTwoFactorObject = $Kernel::OM->Get('ContactAuth::TwoFactor::GoogleAuthenticator');

my @Tests = (
    {
        Name               => 'No secret, AllowEmptySecret = 0',
        ExpectedAuthResult => undef,
        Secret             => undef,
        AllowEmptySecret   => 0,
    },
    {
        Name               => 'No secret, AllowEmptySecret = 1',
        ExpectedAuthResult => 1,
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
        ExpectedAuthResult => 1,
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
        ExpectedAuthResult => 1,
        Secret             => 'UNITTESTUNITTEST',
        TwoFactorToken     => '761321',
        AllowPreviousToken => 1,
        FixedTimeSet       => 30,
    },
    {
        Name               => 'New valid token',
        ExpectedAuthResult => 1,
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
        ExpectedAuthResult => 1,
        Secret             => 'UNITTESTUNITTEST',
        TwoFactorToken     => '281099',
        FixedTimeSet       => 0,
        TimeZone           => 1,
    },
);

for my $Test (@Tests) {

    # update secret if necessary
    if ( ( $Test->{Secret} || '' ) ne $CurrentConfig{Secret} && !$Test->{KeepOldSecret} ) {
        $CurrentConfig{Secret} = $Test->{Secret} || '';
        $UserObject->SetPreferences(
            Key    => 'UnitTestUserGoogleAuthenticatorSecretKey',
            Value  => $CurrentConfig{Secret},
            UserID => $TestAgentID,
        );
        $ContactObject->SetPreferences(
            Key       => 'UnitTestUserGoogleAuthenticatorSecretKey',
            Value     => $CurrentConfig{Secret},
            ContactID => $TestCustomerID,
        );
    }

    # update time zone if necessary
    if ( ( $Test->{TimeZone} || '0' ) ne $CurrentConfig{TimeZone} ) {
        $CurrentConfig{TimeZone} = $Test->{TimeZone} || '0';
        $ConfigObject->Set(
            Key   => 'TimeZone',
            Value => $CurrentConfig{TimeZone},
        );

        # a different timezone config requires a new time object
        $Kernel::OM->ObjectsDiscard(
            Objects => ['Time'],
        );
    }

    # update config if necessary
    CONFIGKEY:
    for my $ConfigKey (qw(AllowEmptySecret AllowPreviousToken)) {
        next CONFIGKEY if ( $Test->{$ConfigKey} || '' ) eq $CurrentConfig{$ConfigKey};
        $CurrentConfig{$ConfigKey} = $Test->{$ConfigKey} || '';
        $ConfigObject->Set(
            Key   => 'AuthTwoFactorModule10::' . $ConfigKey,
            Value => $CurrentConfig{$ConfigKey},
        );
        $ConfigObject->Set(
            Key   => 'Contact::AuthTwoFactorModule10::' . $ConfigKey,
            Value => $CurrentConfig{$ConfigKey},
        );
    }

    # update time if necessary
    if ( ( $Test->{FixedTimeSet} || 0 ) ne $CurrentConfig{Time} ) {
        $CurrentConfig{Time} = $Test->{FixedTimeSet} || 0;
        $Helper->FixedTimeSet( $CurrentConfig{Time} );
    }

    # test agent auth
    my $AuthResult = $AuthTwoFactorObject->Auth(
        User           => $UserRand,
        UserID         => $TestAgentID,
        TwoFactorToken => $Test->{TwoFactorToken},
    );
    $Self->Is(
        $AuthResult,
        $Test->{ExpectedAuthResult},
        $Test->{Name} . ' (agent)',
    );

    # test customer auth
    my $ContactAuthResult = $ContactAuthTwoFactorObject->Auth(
        User           => $TestCustomerID,
        TwoFactorToken => $Test->{TwoFactorToken},
    );
    $Self->Is(
        $ContactAuthResult,
        $Test->{ExpectedAuthResult},
        $Test->{Name} . ' (customer)',
    );
}

# cleanup is done by RestoreDatabase

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
