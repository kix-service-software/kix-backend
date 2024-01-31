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

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# get config object
my $ConfigObject = $Kernel::OM->Get('Config');

# configure auth backend to db
$ConfigObject->Set(
    Key   => 'Authentication',
    Value => {
        '000-Default' => [
            {
                "Enabled" => 1,
                "Name" => "Local Database",
                "Module" => "Kernel::System::Auth::DB",
                "Config" => {
                    "CryptType" => "sha2"
                },
            }
        ]
    }
);

# disable email checks to create new user
$ConfigObject->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

my $TestUserID;
my $UserRand = 'example-user' . $Helper->GetRandomID();

# get user object
my $UserObject = $Kernel::OM->Get('User');

# add test user
$TestUserID = $UserObject->UserAdd(
    UserLogin    => $UserRand,
    ValidID      => 1,
    ChangeUserID => 1,
    IsAgent      => 1,
) || die "Could not create test user";

my @Tests = (
    {
        Password   => 'simple',
        AuthResult => $UserRand,
    },
    {
        Password   => 'very long password line which is unusual',
        AuthResult => $UserRand,
    },
    {
        Password   => 'Переводчик',
        AuthResult => $UserRand,
    },
    {
        Password   => 'كل ما تحب معرفته عن',
        AuthResult => $UserRand,
    },
    {
        Password   => ' ',
        AuthResult => $UserRand,
    },
    {
        Password   => "\n",
        AuthResult => $UserRand,
    },
    {
        Password   => "\t",
        AuthResult => $UserRand,
    },
    {
        Password   => "a" x 64,    # max length for plain
        AuthResult => $UserRand,
    },

    # SQL security tests
    {
        Password   => "'UNION'",
        AuthResult => $UserRand,
    },
    {
        Password   => "';",
        AuthResult => $UserRand,
    },
);

for my $CryptType (qw(plain crypt apr1 md5 sha1 sha2 bcrypt)) {

    # make sure that the customer user objects gets recreated for each loop.
    $Kernel::OM->ObjectsDiscard(
        Objects => [
            'User',
            'Auth',
        ],
    );

    $ConfigObject->Set(
        Key   => "AuthModule::DB::CryptType",
        Value => $CryptType
    );

    # get needed objects
    my $UserObject = $Kernel::OM->Get('User');
    my $AuthObject = $Kernel::OM->Get('Auth');

    TEST:
    for my $Test (@Tests) {

        my $PasswordSet = $UserObject->SetPassword(
            UserLogin => $UserRand,
            PW        => $Test->{Password},
        );

        if ( $CryptType eq 'plain' && $Test->{PlainFail} ) {
            $Self->False(
                $PasswordSet,
                "Password set"
            );
            next TEST;
        }

        $Self->True(
            $PasswordSet,
            "Password set"
        );

        my $AuthResult = $AuthObject->Auth(
            User => $UserRand,
            Pw   => $Test->{Password},
        );

        $Self->Is(
            $AuthResult,
            $Test->{AuthResult},
            "CryptType $CryptType Password '$Test->{Password}'",
        );

        $AuthResult = $AuthObject->Auth(
            User => $UserRand,
            Pw   => $Test->{Password},
        );

        $Self->Is(
            $AuthResult,
            $Test->{AuthResult},
            "CryptType $CryptType Password '$Test->{Password}' (cached)",
        );

        $AuthResult = $AuthObject->Auth(
            User => $UserRand,
            Pw   => 'wrong_pw',
        );

        $Self->False(
            $AuthResult,
            "CryptType $CryptType Password '$Test->{Password}' (wrong password)",
        );

        $AuthResult = $AuthObject->Auth(
            User => 'non_existing_user_id',
            Pw   => $Test->{Password},
        );

        $Self->False(
            $AuthResult,
            "CryptType $CryptType Password '$Test->{Password}' (wrong user)",
        );
    }
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
