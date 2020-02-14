# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
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

# get config object
my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

# configure ContactAuth backend to db
$ConfigObject->Set('ContactAuthBackend', 'DB');

# no additional ContactAuth backends
for my $Count (1 .. 10) {
    $ConfigObject->Set("ContactAuthBackend$Count", '');
}

# disable email checks to create new user
$ConfigObject->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

# add test user
my $GlobalUserObject = $Kernel::OM->Get('Kernel::System::Contact');
my $GlobalContactObject = $Kernel::OM->Get('Kernel::System::Contact');

my $OrgRand = 'example-organisation' . $Helper->GetRandomID();
my $UserRand = 'example-user' . $Helper->GetRandomID();

my $TestUserID = $Kernel::OM->Get('Kernel::System::User')->UserAdd(
    UserLogin    => $UserRand,
    IsCustomer   => 1,
    ValidID      => 1,
    ChangeUserID => 1,
);

my $OrgID = $Kernel::OM->Get('Kernel::System::Organisation')->OrganisationAdd(
    Number  => $OrgRand,
    Name    => $OrgRand,
    ValidID => 1,
    UserID  => 1,
);

my $TestContactID = $GlobalContactObject->ContactAdd(
    Firstname             => 'CustomerFirstname Test1',
    Lastname              => 'CustomerLastname Test1',
    PrimaryOrganisationID => $OrgID,
    OrganisationIDs       => [
        $OrgID
    ],
    Email                 => $UserRand . '@example.com',
    ValidID               => 1,
    UserID                => 1,
    AssignedUserID        => $TestUserID,
);

$Self->True(
    $TestContactID,
    # rkaiser - T#2017020290001194 - changed customer user to contact
    "Creating test contact",
);

# set pw
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
        Password   => "a" x 64, # max length for plain
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
            'Kernel::System::Contact',
            'Kernel::System::ContactAuth',
            'Kernel::System::User',
        ],
    );

    $ConfigObject->Set(
        Key   => "Contact::AuthModule::DB::CryptType",
        Value => $CryptType
    );

    my $UserObject = $Kernel::OM->Get('Kernel::System::User');
    my $ContactObject = $Kernel::OM->Get('Kernel::System::Contact');
    my $ContactAuthObject = $Kernel::OM->Get('Kernel::System::ContactAuth');

    for my $Test (@Tests) {

        my $PasswordSet = $UserObject->SetPassword(
            UserLogin => $UserRand,
            PW        => $Test->{Password},
        );

        $Self->True(
            $PasswordSet,
            "Password set"
        );

        my $ContactAuthResult = $ContactAuthObject->Auth(
            User => $UserRand,
            Pw   => $Test->{Password},
        );

        $Self->True(
            $ContactAuthResult,
            "CryptType $CryptType Password '$Test->{Password}'",
        );

        $ContactAuthResult = $ContactAuthObject->Auth(
            User => $UserRand,
            Pw   => $Test->{Password},
        );

        $Self->True(
            $ContactAuthResult,
            "CryptType $CryptType Password '$Test->{Password}' (cached)",
        );

        $ContactAuthResult = $ContactAuthObject->Auth(
            User => $UserRand,
            Pw   => 'wrong_pw',
        );

        $Self->False(
            $ContactAuthResult,
            "CryptType $CryptType Password '$Test->{Password}' (wrong password)",
        );

        $ContactAuthResult = $ContactAuthObject->Auth(
            User => 'non_existing_user_id',
            Pw   => $Test->{Password},
        );

        $Self->False(
            $ContactAuthResult,
            "CryptType $CryptType Password '$Test->{Password}' (wrong user)",
        );
    }
}

my $Success = $GlobalContactObject->ContactUpdate(
    ID                    => $TestContactID,
    Firstname             => 'CustomerFirstname Test1',
    Lastname              => 'CustomerLastname Test1',
    PrimaryOrganisationID => 'Customer246',
    Email                 => $UserRand . '@example.com',
    ValidID               => 2,
    UserID                => 1,
);

$Self->True(
    $Success,
    # rkaiser - T#2017020290001194 - changed customer user to contact
    "Invalidating test contact",
);

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
