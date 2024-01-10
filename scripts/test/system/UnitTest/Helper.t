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

use Kernel::Config;

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

$Self->True(
    $Helper,
    "Instance created",
);

# GetRandomID
my %SeenRandomIDs;
my $DuplicateIDFound;

LOOP:
for my $I ( 1 .. 1_000_000 ) {
    my $RandomID = $Helper->GetRandomID();
    if ( $SeenRandomIDs{$RandomID}++ ) {
        $Self->True(
            0,
            "GetRandomID iteration $I returned a duplicate RandomID $RandomID",
        );
        $DuplicateIDFound++;
        last LOOP;
    }
}

$Self->False(
    $DuplicateIDFound,
    "GetRandomID() returned no duplicates",
);

# GetRandomNumber
my %SeenRandomNumbers;
my $DuplicateNumbersFound;

LOOP:
for my $I ( 1 .. 1_000_000 ) {
    my $RandomNumber = $Helper->GetRandomNumber();
    if ( $SeenRandomNumbers{$RandomNumber}++ ) {
        $Self->True(
            0,
            "GetRandomNumber iteration $I returned a duplicate RandomNumber $RandomNumber",
        );
        $DuplicateNumbersFound++;
        last LOOP;
    }
}

$Self->False(
    $DuplicateNumbersFound,
    "GetRandomNumber() returned no duplicates",
);

# Test transactions
$Helper->BeginWork();

my $TestUserLogin = $Helper->TestUserCreate();

$Self->True(
    $TestUserLogin,
    'Can create test user',
);

$Helper->Rollback();
$Kernel::OM->Get('Cache')->CleanUp();

my %User = $Kernel::OM->Get('User')->GetUserData(
    User => $TestUserLogin,
);

$Self->False(
    $User{UserID},
    'Rollback worked',
);

$Self->Is(
    $Kernel::OM->Get('Config')->Get('CheckEmailAddresses'),
    '1',
    "Config setting does not exist yet",
);

$Helper->ConfigSettingChange(
    Valid  => 1,
    Key    => 'CheckEmailAddresses',
    Value  => '0',
);

$Self->Is(
    $Kernel::OM->Get('Config')->Get('CheckEmailAddresses'),
    '0',
    "Runtime config updated",
);

my $NewConfigObject = Kernel::Config->new();
$Self->Is(
    $NewConfigObject->Get('CheckEmailAddresses'),
    '0',
    "System config updated",
);

$Helper->Rollback();

$NewConfigObject = Kernel::Config->new();
$Self->Is(
    $NewConfigObject->Get('CheckEmailAddresses'),
    '1',
    "System config reset",
);

$Self->Is(
    $Kernel::OM->Get('Config')->Get('CheckEmailAddresses'),
    '0',
    "Runtime config still has the changed value, it will be destroyed at the end of every test",
);

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
