# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --
#todo firstname lastname now in contacts
use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get needed objects
my $ConfigObject = $Kernel::OM->Get('Config');
my $UserObject   = $Kernel::OM->Get('User');

$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

$ConfigObject->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

# create non existing user login
my $UserRandom;
TRY:
for my $Try ( 1 .. 20 ) {

    $UserRandom = 'unittest-' . $Helper->GetRandomID();

    my $UserID = $UserObject->UserLookup(
        UserLogin => $UserRandom,
    );

    last TRY if !$UserID;

    next TRY if $Try ne 20;

    $Self->True(
        0,
        'Find non existing user login.',
    );
}

# add user
my $UserID = $UserObject->UserAdd(
    UserLogin    => $UserRandom,
    ValidID      => 1,
    ChangeUserID => 1,
    IsAgent      => 1,
);

$Self->True(
    $UserID,
    'UserAdd()',
);

my %Tests = (
    0 => "John Doe",
    1 => "Doe, John",
    2 => "John Doe ($UserRandom)",
    3 => "Doe, John ($UserRandom)",
    4 => "($UserRandom) John Doe",
    5 => "($UserRandom) Doe, John",
    6 => "Doe John",
    7 => "Doe John ($UserRandom)",
    8 => "($UserRandom) Doe John",
);

for my $Order ( sort keys %Tests ) {
    $ConfigObject->Set(
        Key   => 'FirstnameLastnameOrder',
        Value => $Order,
    );
    $Self->Is(
        $UserObject->UserName( UserID => $UserID ),
        $Tests{$Order},
        "FirstnameLastnameOrder $Order",
    );
}

# cleanup is done by RestoreDatabase.

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
