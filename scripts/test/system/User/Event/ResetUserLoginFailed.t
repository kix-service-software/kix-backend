# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
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

use Kernel::System::VariableCheck qw(:all);

use vars (qw($Self));

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# prepare config for test
my $Success = $Helper->ConfigSettingChange(
    Key   => 'Authentication###000-Default',
    Value => [
        {
            'Enabled' => 1,
            'Name'    => 'Local Database',
            'Module'  => 'Kernel::System::Auth::DB',
            'Config'  => {}
        }
    ],
);
$Self->True(
    $Success,
    'Prepare SysConfig "Authentication###000-Default" for test',
);
$Success = $Helper->ConfigSettingChange(
    Key   => 'PreferencesGroups###Password',
    Value => {
        Module                            => 'Kernel::Output::HTML::Preferences::Password',
        Column                            => 'User Profile',
        Label                             => 'Change password',
        Prio                              => '0500',
        Area                              => 'Agent',
        PasswordRegExp                    => '',
        PasswordMinSize                   => '0',
        PasswordMin2Lower2UpperCharacters => '0',
        PasswordMin2Characters            => '0',
        PasswordNeedDigit                 => '0',
        PasswordMaxLoginFailed            => '2',
        Active                            => '1',
    },
);
$Self->True(
    $Success,
    'Prepare SysConfig "PreferencesGroups###Password" for test',
);

# create user
my $UserLogin = $Helper->GetRandomID();
my $UserID = $Kernel::OM->Get('User')->UserAdd(
    UserLogin    => $UserLogin,
    UserPw       => $UserLogin,
    IsAgent      => 1,
    ValidID      => 1,
    ChangeUserID => 1
);

# execute failed auth
my $AuthSuccess = $Kernel::OM->Get('Auth')->Auth(
    User         => $UserLogin,
    UsageContext => 'Agent',
    Pw           => 'Test'
);
$Self->False(
    $AuthSuccess,
    'First failed login - only UserLoginFailed incremented'
);

# get user data
my %User = $Kernel::OM->Get('User')->GetUserData(
    UserID => $UserID,
);
$Self->Is(
    $User{ValidID},
    1,
    'User is valid'
);
$Self->Is(
    $User{Preferences}->{UserLoginFailed},
    1,
    'Preference "UserLoginFailed" has correct value'
);

# update user
my $UserUpdateSuccess = $Kernel::OM->Get('User')->UserUpdate(
    UserID       => $UserID,
    UserLogin    => $UserLogin,
    ValidID      => 1,
    ChangeUserID => 1,
);
$Self->True(
    $UserUpdateSuccess,
    'UserUpdate successful'
);

# get updated user data
%User = $Kernel::OM->Get('User')->GetUserData(
    UserID => $UserID,
);
$Self->Is(
    $User{ValidID},
    1,
    'User is invalid'
);
$Self->Is(
    $User{Preferences}->{UserLoginFailed},
    1,
    'Preference "UserLoginFailed" has correct value'
);

# execute failed auth
$AuthSuccess = $Kernel::OM->Get('Auth')->Auth(
    User         => $UserLogin,
    UsageContext => 'Agent',
    Pw           => 'Test'
);
$Self->False(
    $AuthSuccess,
    'Second failed login - set user invalid'
);

# get updated user data
%User = $Kernel::OM->Get('User')->GetUserData(
    UserID => $UserID,
);
$Self->Is(
    $User{ValidID},
    3,
    'User is invalid'
);
$Self->Is(
    $User{Preferences}->{UserLoginFailed},
    2,
    'Preference "UserLoginFailed" has correct value'
);

# set user valid again
my $UserUpdateSuccess = $Kernel::OM->Get('User')->UserUpdate(
    UserID       => $UserID,
    UserLogin    => $UserLogin,
    ValidID      => 1,
    ChangeUserID => 1,
);
$Self->True(
    $UserUpdateSuccess,
    'UserUpdate successful'
);

# handle transaction events
if ( $Kernel::OM->Get('User')->EventHandlerHasQueuedTransactions() ) {
    $Kernel::OM->Get('User')->EventHandlerTransaction();
}

# get updated user data
%User = $Kernel::OM->Get('User')->GetUserData(
    UserID => $UserID,
);
$Self->Is(
    $User{ValidID},
    1,
    'User is valid'
);
$Self->Is(
    $User{Preferences}->{UserLoginFailed},
    0,
    'Preference "UserLoginFailed" has correct value'
);

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
