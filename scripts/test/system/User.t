# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
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

# get needed objects
my $ConfigObject = $Kernel::OM->Get('Config');
my $TimeObject   = $Kernel::OM->Get('Time');
my $UserObject   = $Kernel::OM->Get('User');

# get helper object
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
my $UserRand;
TRY:
for my $Try ( 1 .. 20 ) {

    $UserRand = 'unittest-' . $Helper->GetRandomID();

    my $UserID = $UserObject->UserLookup(
        UserLogin => $UserRand,
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
    UserLogin    => $UserRand,
    ValidID      => 1,
    ChangeUserID => 1,
    IsAgent      => 1,
);

$Self->True(
    $UserID,
    'UserAdd()',
);

my %UserList = $UserObject->UserList(
    Type  => 'Short',
    Valid => 0,
);

$Self->Is(
    $UserList{$UserID},
    $UserRand,
    "UserList valid 0",
);

%UserList = $UserObject->UserList(
    Type  => 'Short',
    Valid => 1,
);

$Self->Is(
    $UserList{$UserID},
    $UserRand,
    "UserList valid 1",
);

%UserList = $UserObject->UserList(
    Type  => 'Short',
    Valid => 0,
);

$Self->Is(
    $UserList{$UserID},
    $UserRand,
    "UserList valid 0 cached",
);

%UserList = $UserObject->UserList(
    Type  => 'Short',
    Valid => 1,
);

$Self->Is(
    $UserList{$UserID},
    $UserRand,
    "UserList valid 1 cached",
);

my $Update = $UserObject->UserUpdate(
    UserID        => $UserID,
    UserLogin     => $UserRand . '房治郎',
    ValidID       => 2,
    ChangeUserID  => 1,
);

$Self->True(
    $Update,
    'UserUpdate()',
);

my %UserData = $UserObject->GetUserData( UserID => $UserID );

$Self->Is(
    $UserData{UserLogin} || '',
    $UserRand . '房治郎',
    'GetUserData() - UserLogin',
);

%UserList = $UserObject->UserList(
    Type  => 'Short',
    Valid => 0,
);

$Self->Is(
    $UserList{$UserID},
    $UserRand . '房治郎',
    "UserList valid 0",
);

%UserList = $UserObject->UserList(
    Type  => 'Short',
    Valid => 1,
);

$Self->Is(
    $UserList{$UserID},
    undef,
    "UserList valid 1",
);

%UserList = $UserObject->UserList(
    Type  => 'Short',
    Valid => 0,
);

$Self->Is(
    $UserList{$UserID},
    $UserRand . '房治郎',
    "UserList valid 0 cached",
);

%UserList = $UserObject->UserList(
    Type  => 'Short',
    Valid => 1,
);

$Self->Is(
    $UserList{$UserID},
    undef,
    "UserList valid 1 cached",
);

my %UserSearch = $UserObject->UserSearch(
    UserLogin => '*房治郎*',
    Valid     => 0,
);

$Self->Is(
    $UserSearch{$UserID},
    $UserRand . '房治郎',
    "UserSearch(Search) for login after update",
);

# check token support
my $Token = $UserObject->TokenGenerate( UserID => 1 );
$Self->True(
    $Token || 0,
    "TokenGenerate() - $Token",
);

my $TokenValid = $UserObject->TokenCheck(
    Token  => $Token,
    UserID => 1,
);

$Self->True(
    $TokenValid || 0,
    "TokenCheck() - $Token",
);

$TokenValid = $UserObject->TokenCheck(
    Token  => $Token,
    UserID => 1,
);

$Self->True(
    !$TokenValid || 0,
    "TokenCheck() - $Token",
);

$TokenValid = $UserObject->TokenCheck(
    Token  => $Token . '123',
    UserID => 1,
);

$Self->True(
    !$TokenValid || 0,
    "TokenCheck() - $Token" . "123",
);

# testing preferences
my $SetPreferences = $UserObject->SetPreferences(
    Key    => 'UserLanguage',
    Value  => 'fr',
    UserID => $UserID,
);

$Self->True(
    $SetPreferences,
    "SetPreferences - $UserID",
);

my %UserPreferences = $UserObject->GetPreferences(
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

%UserList = $UserObject->SearchPreferences(
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

%UserList = $UserObject->SearchPreferences(
    Key   => 'UserLanguage',
    Value => 'de',
);

$Self->False(
    $UserList{$UserID},
    "SearchPreferences() - $UserID",
);

# look for any value
%UserList = $UserObject->SearchPreferences(
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
my $UpdatePreferences = $UserObject->SetPreferences(
    Key    => 'UserLanguage',
    Value  => 'da',
    UserID => $UserID,
);

$Self->True(
    $UpdatePreferences,
    "UpdatePreferences - $UserID",
);

%UserPreferences = $UserObject->GetPreferences(
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

#check no out of office
%UserData = $UserObject->GetUserData(
    UserID        => $UserID,
    Valid         => 0,
    NoOutOfOffice => 0
);

$Self->False(
    $UserData{Preferences}->{OutOfOfficeMessage},
    'GetUserData() - OutOfOfficeMessage',
);

%UserData = $UserObject->GetUserData(
    UserID => $UserID,
    Valid  => 0,

    #       NoOutOfOffice => 0
);

$Self->False(
    $UserData{Preferences}->{OutOfOfficeMessage},
    'GetUserData() - OutOfOfficeMessage',
);

my ( $Sec, $Min, $Hour, $Day, $Month, $Year, $WeekDay ) = $TimeObject->SystemTime2Date(
    SystemTime => $TimeObject->SystemTime(),
);

my %Values = (
    'OutOfOffice'           => 'on',
    'OutOfOfficeStartYear'  => $Year,
    'OutOfOfficeStartMonth' => $Month,
    'OutOfOfficeStartDay'   => $Day,
    'OutOfOfficeEndYear'    => $Year,
    'OutOfOfficeEndMonth'   => $Month,
    'OutOfOfficeEndDay'     => $Day,
);

for my $Key ( sort keys %Values ) {
    $UserObject->SetPreferences(
        UserID => $UserID,
        Key    => $Key,
        Value  => $Values{$Key},
    );
}
%UserData = $UserObject->GetUserData(
    UserID        => $UserID,
    Valid         => 0,
    NoOutOfOffice => 0
);

$Self->True(
    $UserData{Preferences}->{OutOfOfficeMessage},
    'GetUserData() - OutOfOfficeMessage',
);

%UserData = $UserObject->GetUserData(
    UserID => $UserID,
    Valid  => 0,
);

$Self->True(
    $UserData{Preferences}->{OutOfOfficeMessage},
    'GetUserData() - OutOfOfficeMessage',
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
