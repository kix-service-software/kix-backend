# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# get customer user object
my $ContactObject = $Kernel::OM->Get('Contact');

# add two users
$Kernel::OM->Get('Config')->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

my $RandomID = $Helper->GetRandomID();

my $OrgRand  = 'example-organisation' . $Helper->GetRandomID();

my $OrgID = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number => $OrgRand,
    Name   => $OrgRand,
    ValidID => 1,
    UserID  => 1,
);

my @CustomerLogins;
for my $Key ( 1 .. 2 ) {

    my $ContactRand = 'Duplicate' . $Key . $RandomID;

    my $ContactID = $ContactObject->ContactAdd(
        Firstname  => 'Firstname Test' . $Key,
        Lastname   => 'Lastname Test' . $Key,
        PrimaryOrganisationID => $OrgID,
        OrganisationIDs => [
            $OrgID
        ],
        Login      => $ContactRand,
        Email      => $ContactRand . '-Email@example.com',
        Password   => 'some_pass',
        ValidID    => 1,
        UserID     => 1,
    );

    push @CustomerLogins, $ContactID;

    $Self->True(
        $ContactID,
        "ContactAdd() - $ContactID",
    );

    my $Update = $ContactObject->ContactUpdate(
        ID         => $ContactID,
        Firstname  => 'Firstname Test Update' . $Key,
        Lastname   => 'Lastname Test Update' . $Key,
        PrimaryOrganisationID => $OrgID,
        Login      => $ContactRand,
        Email      => $ContactRand . '-Update@example.com',
        ValidID    => 1,
        UserID     => 1,
    );

    $Self->True(
        $Update,
        "ContactUpdate$Key() - $ContactID",
    );
}

my %CustomerData = $ContactObject->ContactGet(
    ID => $CustomerLogins[0],
);

my $Customer1Email = $CustomerData{Email};

# create a new customer with email address of customer 1
my $ContactID = $ContactObject->ContactAdd(
    Firstname  => "Firstname Add $RandomID",
    Lastname   => "Lastname Add $RandomID",
    Login      => "UserLogin Add $RandomID",
    Email      => $Customer1Email,
    PrimaryOrganisationID => $OrgID,
    OrganisationIDs => [
        $OrgID
    ],
    Password   => 'some_pass',
    ValidID        => 1,
    UserID         => 1,
);

$Self->False(
    $ContactID,
    "ContactAdd() - not possible for duplicate email address",
);

%CustomerData = $ContactObject->ContactGet(
    ID => $CustomerLogins[1],
);

# update user 1 with email address of customer 2
my $Update = $ContactObject->ContactUpdate(
    %CustomerData,
    ID     => $CustomerData{ID},
    Email  => $Customer1Email,
    UserID => 1,
);

$Self->False(
    $Update,
    "ContactUpdate() - not possible for duplicate email address",
);

# cleanup is done by RestoreDatabase

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
