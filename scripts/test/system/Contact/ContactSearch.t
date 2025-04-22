# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get needed objects
my $ConfigObject  = $Kernel::OM->Get('Config');
my $ContactObject = $Kernel::OM->Get('Contact');
my $UserObject    = $Kernel::OM->Get('User');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

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

my @Contacts = ('Test_A', 'Test_B', 'Test_C');
for my $Contact (@Contacts) {

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
}

my @Tests = (
    {
        Search      => 'First*',
        ResultCount => 3,
        Name        => 'Match all'
    },
    {
        Search      => 'Firstname_Test_A',
        ResultCount => 1,
        Name        => 'Match only A'
    },
    {
        Search      => 'First*+*Test_A',
        ResultCount => 1,
        Name        => 'Match all AND only A => only A'
    },
    {
        Search      => '*Test_A|*Test_B',
        ResultCount => 2,
        Name        => 'Match A OR B => A and B'
    },
    {
        Search      => '*Test_A+*Test_B',
        ResultCount => 0,
        Name        => 'Match A AND B => nothing'
    },
    {
        Search      => '*Test_A|Login*+*Test_B',
        ResultCount => 2,
        Name        => 'Match A OR all AND B => A and B'
    }
);

for my $Test (@Tests) {
    my $Result = $Kernel::OM->Get('ObjectSearch')->Search(
        Search => {
            AND => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => $Test->{Search}
                }
            ]
        },
        ObjectType => 'Contact',
        Result     => 'COUNT',
        UserID     => 1,
        UserType   => 'Agent'
    );

    $Self->Is(
        $Result,
        $Test->{ResultCount},
        'Search: "' . $Test->{Search} . q{"}
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
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
