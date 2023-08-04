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

# get Job object
my $AutomationObject = $Kernel::OM->Get('Automation');
my $ConfigObject     = $Kernel::OM->Get('Config');
my $ContactObject    = $Kernel::OM->Get('Contact');
my $UserObject       = $Kernel::OM->Get('User');

#
# Job tests
#

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $Contact = 'customer' . $Helper->GetRandomID();

# do not check mail addresses
$ConfigObject->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

my $OrgRand  = 'test-organisation' . $Helper->GetRandomID();
my $OrgID = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number => $OrgRand,
    Name   => $OrgRand,
    ValidID => 1,
    UserID  => 1
);

my %Contacts = (
    'Test_A' => 0,
    'Test_B' => 0, 
    'Test_C' => 0
);

for my $Contact (sort keys %Contacts) {

    # add assigned user
    my $UserID = $UserObject->UserAdd(
        UserLogin    => 'Login_' . $Contact,
        ValidID      => 1,
        ChangeUserID => 1,
        IsAgent      => 1
    );
    $Self->True(
        $UserID,
        "Assigned UserAdd() - $Contact",
    );

    # add contact
    my $ContactID = $ContactObject->ContactAdd(
        AssignedUserID => $UserID,
        Firstname      => 'Firstname_' . $Contact,
        Lastname       => 'Lastname_' . $Contact,
        PrimaryOrganisationID => $OrgID,
        OrganisationIDs       => [$OrgID],
        Email   => 'some-random-' . $Helper->GetRandomID() . '@example.com',
        ValidID => 1,
        UserID  => 1
    );
    $Self->True(
        $ContactID,
        "ContactAdd() - $Contact",
    );

    $Contacts{$Contact} = $ContactID;
}

# test data
my @TestData = (
    {
        Test     => 'without filter',
        Filter   => undef,
        Expected => [
            1,
            sort values %Contacts
        ],
    },
    {
        Test     => 'AND filter for firstname',
        Filter   => {
            AND => [
                { Field => 'Firstname', Operator => 'LIKE', Value => '*Test*' }
            ]
        },
        Expected => [
            sort values %Contacts
        ],
    },
    {
        Test     => 'AND filter for login',
        Filter   => {
            AND => [
                { Field => 'Login', Operator => 'EQ', Value => 'Login_Test_A' }
            ]
        },
        Expected => [
            $Contacts{'Test_A'}
        ],
    },
    {
        Test     => 'multiple AND filter',
        Filter   => {
            AND => [
                { Field => 'Firstname', Operator => 'LIKE', Value => '*Test*' },
                { Field => 'Login', Operator => 'EQ', Value => 'Login_Test_A' }
            ]
        },
        Expected => [
            $Contacts{'Test_A'}
        ],
    },
    {
        Test     => 'multiple OR filter',
        Filter   => {
            OR => [
                { Field => 'Firstname', Operator => 'LIKE', Value => '*Test*' },
                { Field => 'Login', Operator => 'EQ', Value => 'Login_Test_A' }
            ]
        },
        Expected => [
            sort values %Contacts
        ],
    },
    {
        Test     => 'multiple OR and AND filter combined',
        Filter   => {
            OR => [
                { Field => 'Firstname', Operator => 'LIKE', Value => '*Test*' },
                { Field => 'Login', Operator => 'EQ', Value => 'admin' }
            ],
            AND => [
                { Field => 'Lastname', Operator => 'LIKE', Value => '*_B*' },
            ]
        },
        Expected => [
            $Contacts{'Test_B'}
        ],
    },
);

# load job type backend module
my $JobObject = $AutomationObject->_LoadJobTypeBackend(
    Name => 'Contact',
);
$Self->True(
    $JobObject,
    'JobObject loaded',
);

# run checks
foreach my $Test ( @TestData ) {

    my @ObjectIDs = $JobObject->Run(
        Data   => $Test->{Data},
        Filter => $Test->{Filter},
        UserID => 1,
    );

    $Self->IsDeeply(
        [ sort @ObjectIDs ],
        $Test->{Expected},
        'Test "'.$Test->{Test}.'" - result'
    )
}

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
