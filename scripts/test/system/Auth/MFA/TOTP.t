# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
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

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# set module
my $MFAModule = 'Kernel::System::Auth::MFA::TOTP';

# require module
my $Require = $Kernel::OM->Get('Main')->Require( $MFAModule );
$Self->True(
    $Require,
    'Module "' . $MFAModule . '" could be required'
);
return if ( !$Require );

# get backend instance
my $BackendObject = $MFAModule->new(
    Name => 'UnitTest'
);
$Self->Is(
    ref( $BackendObject ),
    $MFAModule,
    'MFA backend object has correct module ref'
);
return if ( ref( $BackendObject ) ne $MFAModule );

# check supported methods
for my $Method ( qw(GetMFAuthType GetMFAuthMethod MFAuth GenerateSecret) ) {
    $Self->True(
        $BackendObject->can($Method),
        'MFA backend object can "' . $Method . '"'
    );
}

# check GetMFAuthType
my $MFAuthType = $BackendObject->GetMFAuthType();
$Self->IsDeeply(
    $MFAuthType,
    'TOTP',
    'GetMFAuthType provides expected data'
);

# check GetMFAuthMethod
my $MFAuthMethod = $BackendObject->GetMFAuthMethod();
$Self->IsDeeply(
    $MFAuthMethod,
    {
        Type => 'TOTP',
        Data => {
            Preference     => 'MFA_TOTP_UnitTest',
            GenerateSecret => 1
        }
    },
    'GetMFAuthMethod provides expected data'
);


### check MFAuth ###
# set fixed time for test
$Helper->FixedTimeSet(
    $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
        String => '2014-01-01 14:00:00',
    ),
);

# basic tests
my $MFAuth = $BackendObject->MFAuth(
    Silent => 1
);
$Self->Is(
    $MFAuth,
    0,
    'MFAuth without parameter'
);
$MFAuth = $BackendObject->MFAuth(
    UserID => 1,
    Silent => 1
);
$Self->Is(
    $MFAuth,
    0,
    'MFAuth without parameter User'
);
$MFAuth = $BackendObject->MFAuth(
    User   => 'admin',
    Silent => 1
);
$Self->Is(
    $MFAuth,
    0,
    'MFAuth without parameter UserID'
);
$MFAuth = $BackendObject->MFAuth(
    User   => 'admin',
    UserID => 1
);
$Self->Is(
    $MFAuth,
    undef,
    'MFAuth without enabled preference'
);

# enable mfa for user admin
my $SetPreferences = $Kernel::OM->Get('User')->SetPreferences(
    Key    => 'MFA_TOTP_UnitTest',
    Value  => '1',
    UserID => 1,
);

# further checks
$MFAuth = $BackendObject->MFAuth(
    User   => 'admin',
    UserID => 1,
    Silent => 1
);
$Self->Is(
    $MFAuth,
    0,
    'MFAuth without secret preference and AllowEmptySecret disabled'
);

# get backend instance with AllowEmptySecret enabled
my $AESBackendObject = $MFAModule->new(
    Name   => 'UnitTest',
    Config => {
        AllowEmptySecret => 1
    }
);

# further checks
$MFAuth = $AESBackendObject->MFAuth(
    User   => 'admin',
    UserID => 1
);
$Self->Is(
    $MFAuth,
    undef,
    'MFAuth without secret preference and AllowEmptySecret enabled'
);

# set secret for user admin
$SetPreferences = $Kernel::OM->Get('User')->SetPreferences(
    Key    => 'MFA_TOTP_UnitTest_Secret',
    Value  => 'SECRET234',
    UserID => 1,
);

# further checks
$MFAuth = $BackendObject->MFAuth(
    User   => 'admin',
    UserID => 1,
    Silent => 1
);
$Self->Is(
    $MFAuth,
    0,
    'MFAuth without MFAToken'
);
$MFAuth = $BackendObject->MFAuth(
    User     => 'admin',
    UserID   => 1,
    MFAToken => {
        Value => 876948
    },
    Silent   => 1
);
$Self->Is(
    $MFAuth,
    0,
    'MFAuth without Type in MFAToken'
);
$MFAuth = $BackendObject->MFAuth(
    User     => 'admin',
    UserID   => 1,
    MFAToken => {
        Type => 'TOTP'
    },
    Silent   => 1
);
$Self->Is(
    $MFAuth,
    0,
    'MFAuth without Value in MFAToken'
);
$MFAuth = $BackendObject->MFAuth(
    User     => 'admin',
    UserID   => 1,
    MFAToken => {
        Type  => 'UnitTest',
        Value => 603764
    }
);
$Self->Is(
    $MFAuth,
    undef,
    'MFAuth with mismatching Type in MFAToken'
);
$MFAuth = $BackendObject->MFAuth(
    User     => 'admin',
    UserID   => 1,
    MFAToken => {
        Type  => 'TOTP',
        Value => 'UnitTest'
    }
);
$Self->Is(
    $MFAuth,
    0,
    'MFAuth with mismatching Value in MFAToken'
);
$MFAuth = $BackendObject->MFAuth(
    User     => 'admin',
    UserID   => 1,
    MFAToken => {
        Type  => 'TOTP',
        Value => 603764
    }
);
$Self->Is(
    $MFAuth,
    1,
    'MFAuth with matching Value in MFAToken'
);

my @MFAuthTests = (
    {
        Name   => 'MFAuth - TimeStep 60s',
        Config => {
            TimeStep => 60
        },
        Token  => '029357',
    },
    {
        Name   => 'MFAuth - eigth Digits',
        Config => {
            Digits => 8
        },
        Token  => '88603764',
    },
    {
        Name   => 'MFAuth - Algorithm SHA256',
        Config => {
            Algorithm => 'SHA256'
        },
        Token  => '311578',
    },
    {
        Name   => 'MFAuth - Algorithm SHA512',
        Config => {
            Algorithm => 'SHA512'
        },
        Token  => '062740',
    },
    {
        Name   => 'MFAuth - MaxPreviousToken 1',
        Config => {
            MaxPreviousToken => 1
        },
        Token  => '009220',
    },
);
for my $Test ( @MFAuthTests ) {
    # get backend instance with specific config
    my $MFAuthBackendObject = $MFAModule->new(
        Name   => 'UnitTest',
        Config => $Test->{Config}
    );

    $MFAuth = $MFAuthBackendObject->MFAuth(
        User     => 'admin',
        UserID   => 1,
        MFAToken => {
            Type  => 'TOTP',
            Value => $Test->{Token}
        }
    );
    $Self->Is(
        $MFAuth,
        1,
        $Test->{Name}
    );
}
### EO check MFAuth ###

# check GenerateSecret
my $GenerateSecret = $BackendObject->GenerateSecret(
    Silent => 1
);
$Self->Is(
    $GenerateSecret,
    undef,
    'GenerateSecret without parameter'
);
$GenerateSecret = $BackendObject->GenerateSecret(
    MFAuth => 'Test'
);
$Self->Is(
    $GenerateSecret,
    undef,
    'GenerateSecret with mismatching parameter'
);
$GenerateSecret = $BackendObject->GenerateSecret(
    MFAuth => 'MFA_TOTP_UnitTest'
);
$Self->True(
    ( $GenerateSecret =~ m/^[2-7A-Z]{8}$/ ),
    'GenerateSecret with matching parameter and default SecretLength'
);
for my $SecretLength ( 1..64 ) {
    # get backend instance with specific SecretLength
    my $GSBackendObject = $MFAModule->new(
        Name   => 'UnitTest',
        Config => {
            SecretLength => $SecretLength
        }
    );

    $GenerateSecret = $GSBackendObject->GenerateSecret(
        MFAuth => 'MFA_TOTP_UnitTest'
    );
    $Self->True(
        ( $GenerateSecret =~ m/^[2-7A-Z]{$SecretLength}$/ ),
        'GenerateSecret with matching parameter and SecretLength ' . $SecretLength
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