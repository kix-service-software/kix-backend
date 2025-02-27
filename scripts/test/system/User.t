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

# init fixed time
my $SystemTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
    String => '2024-02-09 00:00:00',
);
$Helper->FixedTimeSet($SystemTime);

$Kernel::OM->Get('Config')->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

# create non existing user login
my $UserRand;
TRY:
for my $Try ( 1 .. 20 ) {

    $UserRand = 'unittest-' . $Helper->GetRandomID();

    my $UserID = $Kernel::OM->Get('User')->UserLookup(
        UserLogin => $UserRand,
        Silent    => 1,
    );

    last TRY if !$UserID;

    next TRY if $Try ne 20;

    $Self->True(
        0,
        'Find non existing user login.',
    );
}

# add user
my $UserID = $Kernel::OM->Get('User')->UserAdd(
    UserLogin    => $UserRand,
    ValidID      => 1,
    ChangeUserID => 1,
    IsAgent      => 1,
);

$Self->True(
    $UserID,
    'UserAdd()',
);

my %UserList = $Kernel::OM->Get('User')->UserList(
    Type  => 'Short',
    Valid => 0,
);

$Self->Is(
    $UserList{$UserID},
    $UserRand,
    "UserList valid 0",
);

%UserList = $Kernel::OM->Get('User')->UserList(
    Type  => 'Short',
    Valid => 1,
);

$Self->Is(
    $UserList{$UserID},
    $UserRand,
    "UserList valid 1",
);

%UserList = $Kernel::OM->Get('User')->UserList(
    Type  => 'Short',
    Valid => 0,
);

$Self->Is(
    $UserList{$UserID},
    $UserRand,
    "UserList valid 0 cached",
);

%UserList = $Kernel::OM->Get('User')->UserList(
    Type  => 'Short',
    Valid => 1,
);

$Self->Is(
    $UserList{$UserID},
    $UserRand,
    "UserList valid 1 cached",
);

my $Update = $Kernel::OM->Get('User')->UserUpdate(
    UserID        => $UserID,
    UserLogin     => $UserRand . '房治郎',
    ValidID       => 2,
    ChangeUserID  => 1,
);

$Self->True(
    $Update,
    'UserUpdate()',
);

my %UserData = $Kernel::OM->Get('User')->GetUserData( UserID => $UserID );

$Self->Is(
    $UserData{UserLogin} || '',
    $UserRand . '房治郎',
    'GetUserData() - UserLogin',
);

%UserList = $Kernel::OM->Get('User')->UserList(
    Type  => 'Short',
    Valid => 0,
);

$Self->Is(
    $UserList{$UserID},
    $UserRand . '房治郎',
    "UserList valid 0",
);

%UserList = $Kernel::OM->Get('User')->UserList(
    Type  => 'Short',
    Valid => 1,
);

$Self->Is(
    $UserList{$UserID},
    undef,
    "UserList valid 1",
);

%UserList = $Kernel::OM->Get('User')->UserList(
    Type  => 'Short',
    Valid => 0,
);

$Self->Is(
    $UserList{$UserID},
    $UserRand . '房治郎',
    "UserList valid 0 cached",
);

%UserList = $Kernel::OM->Get('User')->UserList(
    Type  => 'Short',
    Valid => 1,
);

$Self->Is(
    $UserList{$UserID},
    undef,
    "UserList valid 1 cached",
);

my %UserSearch = $Kernel::OM->Get('User')->UserSearch(
    UserLogin => '*房治郎*',
    Valid     => 0,
);

$Self->Is(
    $UserSearch{$UserID},
    $UserRand . '房治郎',
    "UserSearch(Search) for login after update",
);

# check token support
my $Token = $Kernel::OM->Get('User')->TokenGenerate( UserID => 1 );
$Self->True(
    $Token || 0,
    "TokenGenerate() - $Token",
);

my $TokenValid = $Kernel::OM->Get('User')->TokenCheck(
    Token  => $Token,
    UserID => 1,
);

$Self->True(
    $TokenValid || 0,
    "TokenCheck() - $Token",
);

$TokenValid = $Kernel::OM->Get('User')->TokenCheck(
    Token  => $Token,
    UserID => 1,
);

$Self->True(
    !$TokenValid || 0,
    "TokenCheck() - $Token",
);

$TokenValid = $Kernel::OM->Get('User')->TokenCheck(
    Token  => $Token . '123',
    UserID => 1,
);

$Self->True(
    !$TokenValid || 0,
    "TokenCheck() - $Token" . "123",
);

# testing preferences
my $SetPreferences = $Kernel::OM->Get('User')->SetPreferences(
    Key    => 'UserLanguage',
    Value  => 'fr',
    UserID => $UserID,
);

$Self->True(
    $SetPreferences,
    "SetPreferences - $UserID",
);

my %UserPreferences = $Kernel::OM->Get('User')->GetPreferences(
    UserID => $UserID,
);

$Self->True(
    %UserPreferences || '',
    "GetPreferences - $UserID",
);

$Self->Is(
    $UserPreferences{UserLanguage},
    "fr",
    "GetPreferences $UserID - fr",
);

%UserList = $Kernel::OM->Get('User')->SearchPreferences(
    Key   => 'UserLanguage',
    Value => 'fr',
);

$Self->True(
    %UserList || '',
    "SearchPreferences - $UserID",
);

$Self->Is(
    $UserList{$UserID},
    'fr',
    "SearchPreferences() - $UserID",
);

%UserList = $Kernel::OM->Get('User')->SearchPreferences(
    Key   => 'UserLanguage',
    Value => 'de',
);

$Self->False(
    $UserList{$UserID},
    "SearchPreferences() - $UserID",
);

# look for any value
%UserList = $Kernel::OM->Get('User')->SearchPreferences(
    Key => 'UserLanguage',
);

$Self->True(
    %UserList || '',
    "SearchPreferences - $UserID",
);

$Self->Is(
    $UserList{$UserID},
    'fr',
    "SearchPreferences() - $UserID",
);

#update existing prefs
my $UpdatePreferences = $Kernel::OM->Get('User')->SetPreferences(
    Key    => 'UserLanguage',
    Value  => 'da',
    UserID => $UserID,
);

$Self->True(
    $UpdatePreferences,
    "UpdatePreferences - $UserID",
);

%UserPreferences = $Kernel::OM->Get('User')->GetPreferences(
    UserID => $UserID,
);

$Self->True(
    %UserPreferences || '',
    "GetPreferences - $UserID",
);

$Self->Is(
    $UserPreferences{UserLanguage},
    "da",
    "UpdatePreferences $UserID - da",
);

### UserSearch with IsOutOfOffice ###
## Check without set preference ##
my %UserSearchResult = $Kernel::OM->Get('User')->UserSearch(
    IsOutOfOffice => 1,
    Valid         => 0,
);
$Self->False(
    $UserSearchResult{ $UserID },
    'UserSearch() - IsOutOfOffice = 1, Preference not set',
);
%UserSearchResult = $Kernel::OM->Get('User')->UserSearch(
    IsOutOfOffice => 0,
    Valid         => 0,
);
$Self->True(
    $UserSearchResult{ $UserID },
    'UserSearch() - IsOutOfOffice = 0, Preference not set',
);

## Check with set preference on same day ##
my $CurrDate = $Kernel::OM->Get('Time')->CurrentTimestamp();
$CurrDate =~ s/^(\d{4}-\d{2}-\d{2}).+$/$1/;
my %Values = (
    'OutOfOfficeStart' => $CurrDate,
    'OutOfOfficeEnd'   => $CurrDate,
);
for my $Key ( sort( keys( %Values ) ) ) {
    $Kernel::OM->Get('User')->SetPreferences(
        UserID => $UserID,
        Key    => $Key,
        Value  => $Values{ $Key },
    );
}
%UserSearchResult = $Kernel::OM->Get('User')->UserSearch(
    IsOutOfOffice => 1,
    Valid         => 0,
);
$Self->True(
    $UserSearchResult{ $UserID },
    'UserSearch() - IsOutOfOffice = 1, Preference set, correct day',
);
%UserSearchResult = $Kernel::OM->Get('User')->UserSearch(
    IsOutOfOffice => 0,
    Valid         => 0,
);
$Self->False(
    $UserSearchResult{ $UserID },
    'UserSearch() - IsOutOfOffice = 0, Preference set, correct day',
);

## Check with set preference on day before ##
$SystemTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
    String => '2024-02-08 00:00:00',
);
$Helper->FixedTimeSet($SystemTime);
%UserSearchResult = $Kernel::OM->Get('User')->UserSearch(
    IsOutOfOffice => 1,
    Valid         => 0,
);
$Self->False(
    $UserSearchResult{ $UserID },
    'UserSearch() - IsOutOfOffice = 1, Preference set, day before',
);
%UserSearchResult = $Kernel::OM->Get('User')->UserSearch(
    IsOutOfOffice => 0,
    Valid         => 0,
);
$Self->True(
    $UserSearchResult{ $UserID },
    'UserSearch() - IsOutOfOffice = 0, Preference set, day before',
);

## Check with set preference on day after ##
$SystemTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
    String => '2024-02-10 00:00:00',
);
$Helper->FixedTimeSet($SystemTime);
%UserSearchResult = $Kernel::OM->Get('User')->UserSearch(
    IsOutOfOffice => 1,
    Valid         => 0,
);
$Self->False(
    $UserSearchResult{ $UserID },
    'UserSearch() - IsOutOfOffice = 1, Preference set, day after',
);
%UserSearchResult = $Kernel::OM->Get('User')->UserSearch(
    IsOutOfOffice => 0,
    Valid         => 0,
);
$Self->True(
    $UserSearchResult{ $UserID },
    'UserSearch() - IsOutOfOffice = 0, Preference set, day after',
);

# reset fixed time
$Helper->FixedTimeUnset();

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
