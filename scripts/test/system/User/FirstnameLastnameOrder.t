# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
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

$Kernel::OM->Get('Config')->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

# create test user
my $UserLogin = $Helper->TestUserCreate(
    Firstname => 'John',
    Lastname  => 'Doe',
);
my $UserID = $Kernel::OM->Get('User')->UserLookup(
    UserLogin => $UserLogin
);
$Self->True(
    $UserID,
    'TestUserCreate( Firstname => \'Jon\', Lastname => \'Doe\' )',
);

my %Tests = (
    0 => "John Doe",
    1 => "Doe, John",
    2 => "John Doe ($UserLogin)",
    3 => "Doe, John ($UserLogin)",
    4 => "($UserLogin) John Doe",
    5 => "($UserLogin) Doe, John",
    6 => "Doe John",
    7 => "Doe John ($UserLogin)",
    8 => "($UserLogin) Doe John",
);

for my $Order ( sort keys %Tests ) {
    # cleanup contact cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => 'Contact',
    );

    # set config
    $Kernel::OM->Get('Config')->Set(
        Key   => 'FirstnameLastnameOrder',
        Value => $Order,
    );

    # perform check
    $Self->Is(
        $Kernel::OM->Get('User')->UserName( UserID => $UserID ),
        $Tests{$Order},
        "FirstnameLastnameOrder $Order",
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
