# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

# get customer user object
my $ContactObject = $Kernel::OM->Get('Kernel::System::Contact');

# add two users
$Kernel::OM->Get('Kernel::Config')->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

my $RandomID = $Helper->GetRandomID();

my @CustomerLogins;
for my $Key ( 1 .. 2 ) {

    my $ContactRand = 'Duplicate' . $Key . $RandomID;

    my $ContactID = $ContactObject->ContactAdd(
        Firstname  => 'Firstname Test' . $Key,
        Lastname   => 'Lastname Test' . $Key,
        PrimaryOrganisationID => $ContactRand . '-Customer-Id',     # TODO!!!
        Login      => $ContactRand,
        Email      => $ContactRand . '-Email@example.com',
        Password   => 'some_pass',
        ValidID    => 1,
        UserID     => 1,
    );

    push @CustomerLogins, $UserID;

    $Self->True(
        $UserID,
        "ContactAdd() - $ContactID",
    );

    my $Update = $ContactObject->ContactUpdate(
        ID         => $ContactID,
        Firstname  => 'Firstname Test Update' . $Key,
        Lastname   => 'Lastname Test Update' . $Key,
        PrimaryOrganisationID => $ContactRand . '-Customer-Update-Id',          # TODO!!!
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
    User => $CustomerLogins[0],
);

my $Customer1Email = $CustomerData{UserEmail};

# create a new customer with email address of customer 1
my $UserID = $ContactObject->ContactAdd(
    Source         => 'Contact',
    UserFirstname  => "Firstname Add $RandomID",
    UserLastname   => "Lastname Add $RandomID",
    UserCustomerID => "CustomerID Add $RandomID",
    UserLogin      => "UserLogin Add $RandomID",
    UserEmail      => $Customer1Email,
    UserPassword   => 'some_pass',
    ValidID        => 1,
    UserID         => 1,
);

$Self->False(
    $UserID,
    "ContactAdd() - not possible for duplicate email address",
);

%CustomerData = $ContactObject->ContactGet(
    User => $CustomerLogins[1],
);

# update user 1 with email address of customer 2
my $Update = $ContactObject->ContactUpdate(
    %CustomerData,
    Source    => 'Contact',
    ID        => $CustomerData{UserLogin},
    UserEmail => $Customer1Email,
    UserID    => 1,
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
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
