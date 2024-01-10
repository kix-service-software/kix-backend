# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::System::VariableCheck qw(:all);

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my $OAuth2ProfileID = $Kernel::OM->Get('OAuth2')->ProfileAdd(
    Name         => 'Profile',
    URLAuth      => 'URL Auth',
    URLToken     => 'URL Token',
    URLRedirect  => 'URL Redirect',
    ClientID     => "ClientID",
    ClientSecret => "ClientSecret",
    Scope        => "Scope",
    ValidID      => 1,
    UserID       => 1,
);
$Self->True(
    $OAuth2ProfileID,
    'ProfileAdd()',
);

# check for empty token list
my %TokenList = $Kernel::OM->Get('OAuth2')->_TokenList(
    ProfileID => $OAuth2ProfileID,
);
$Self->False(
    IsHashRefWithData( \%TokenList ) // 0,
    'Empty token list after creation',
);

# check that no token is available (access / refresh) after creation
my $HasToken = $Kernel::OM->Get('OAuth2')->HasToken(
    ProfileID => $OAuth2ProfileID,
    Silent    => 1,
);
$Self->False(
    $HasToken,
    'HasToken()',
);

# get AuthURL to generate state token
my $AuthURL = $Kernel::OM->Get('OAuth2')->PrepareAuthURL(
    ProfileID => $OAuth2ProfileID,
);
$Self->True(
    $AuthURL,
    'PrepareAuthURL()',
);

# check for state token in list
%TokenList = $Kernel::OM->Get('OAuth2')->_TokenList(
    ProfileID => $OAuth2ProfileID,
);
$Self->True(
    (
        IsHashRefWithData( \%TokenList )
        && scalar( keys( %TokenList ) ) == 1
        && $TokenList{state}
    ),
    'Only state token in list',
);

# check that no token is available (access / refresh)
$HasToken = $Kernel::OM->Get('OAuth2')->HasToken(
    ProfileID => $OAuth2ProfileID,
    Silent    => 1,
);
$Self->False(
    $HasToken,
    'HasToken()',
);

# setting fake access token to cache
my $CacheAccessToken = $Kernel::OM->Get('Cache')->Set(
    Type           => $Kernel::OM->Get('OAuth2')->{CacheType},
    TTL            => 90,
    Key            => "AccessToken::$OAuth2ProfileID",
    Value          => "UnitTest",
    CacheInMemory  => 0,                                            # Cache in Backend only to enforce TTL
    CacheInBackend => 1,
    NoStatsUpdate  => 1
);
$Self->True(
    $CacheAccessToken,
    'Create fake access token',
);

# check for state token in list (still one token in list, since access token is only in cache)
%TokenList = $Kernel::OM->Get('OAuth2')->_TokenList(
    ProfileID => $OAuth2ProfileID,
);
$Self->True(
    (
        IsHashRefWithData( \%TokenList )
        && scalar( keys( %TokenList ) ) == 1
        && $TokenList{state}
    ),
    'Only state token in list',
);

# check that token is available (access / refresh)
$HasToken = $Kernel::OM->Get('OAuth2')->HasToken(
    ProfileID => $OAuth2ProfileID,
    Silent    => 1,
);
$Self->True(
    $HasToken,
    'HasToken()',
);

# update profile with changed name
my $OAuth2ProfileUpdate = $Kernel::OM->Get('OAuth2')->ProfileUpdate(
    ID           => $OAuth2ProfileID,
    Name         => 'Profile-Changed',
    URLAuth      => 'URL Auth',
    URLToken     => 'URL Token',
    URLRedirect  => 'URL Redirect',
    ClientID     => "ClientID",
    ClientSecret => "ClientSecret",
    Scope        => "Scope",
    ValidID      => 1,
    UserID       => 1,
);
$Self->True(
    $OAuth2ProfileUpdate,
    'ProfileUpdate() changed Name',
);

# check for state token in list and avaiable token
%TokenList = $Kernel::OM->Get('OAuth2')->_TokenList(
    ProfileID => $OAuth2ProfileID,
);
$Self->True(
    (
        IsHashRefWithData( \%TokenList )
        && scalar( keys( %TokenList ) ) == 1
        && $TokenList{state}
    ),
    'Only state token in list',
);
$HasToken = $Kernel::OM->Get('OAuth2')->HasToken(
    ProfileID => $OAuth2ProfileID,
    Silent    => 1,
);
$Self->True(
    $HasToken,
    'HasToken()',
);

# update profile with changed URLAuth
$OAuth2ProfileUpdate = $Kernel::OM->Get('OAuth2')->ProfileUpdate(
    ID           => $OAuth2ProfileID,
    Name         => 'Profile-Changed',
    URLAuth      => 'URL Auth-Changed',
    URLToken     => 'URL Token',
    URLRedirect  => 'URL Redirect',
    ClientID     => "ClientID",
    ClientSecret => "ClientSecret",
    Scope        => "Scope",
    ValidID      => 1,
    UserID       => 1,
);
$Self->True(
    $OAuth2ProfileUpdate,
    'ProfileUpdate() changed URLAuth',
);

# check for empty token list and no available token
%TokenList = $Kernel::OM->Get('OAuth2')->_TokenList(
    ProfileID => $OAuth2ProfileID,
);
$Self->False(
    IsHashRefWithData( \%TokenList ) // 0,
    'Empty token list',
);
$HasToken = $Kernel::OM->Get('OAuth2')->HasToken(
    ProfileID => $OAuth2ProfileID,
    Silent    => 1,
);
$Self->False(
    $HasToken,
    'HasToken()',
);

# get AuthURL to generate state token and setting fake access token to cache
$AuthURL = $Kernel::OM->Get('OAuth2')->PrepareAuthURL(
    ProfileID => $OAuth2ProfileID,
);
$Self->True(
    $AuthURL,
    'PrepareAuthURL()',
);
$CacheAccessToken = $Kernel::OM->Get('Cache')->Set(
    Type           => $Kernel::OM->Get('OAuth2')->{CacheType},
    TTL            => 90,
    Key            => "AccessToken::$OAuth2ProfileID",
    Value          => "UnitTest",
    CacheInMemory  => 0,                                            # Cache in Backend only to enforce TTL
    CacheInBackend => 1,
    NoStatsUpdate  => 1
);
$Self->True(
    $CacheAccessToken,
    'Create fake access token',
);

# update profile with changed URLToken
$OAuth2ProfileUpdate = $Kernel::OM->Get('OAuth2')->ProfileUpdate(
    ID           => $OAuth2ProfileID,
    Name         => 'Profile-Changed',
    URLAuth      => 'URL Auth-Changed',
    URLToken     => 'URL Token-Changed',
    URLRedirect  => 'URL Redirect',
    ClientID     => "ClientID",
    ClientSecret => "ClientSecret",
    Scope        => "Scope",
    ValidID      => 1,
    UserID       => 1,
);
$Self->True(
    $OAuth2ProfileUpdate,
    'ProfileUpdate() changed URLToken',
);

# check for empty token list and no available token
%TokenList = $Kernel::OM->Get('OAuth2')->_TokenList(
    ProfileID => $OAuth2ProfileID,
);
$Self->False(
    IsHashRefWithData( \%TokenList ) // 0,
    'Empty token list',
);
$HasToken = $Kernel::OM->Get('OAuth2')->HasToken(
    ProfileID => $OAuth2ProfileID,
    Silent    => 1,
);
$Self->False(
    $HasToken,
    'HasToken()',
);

# get AuthURL to generate state token and setting fake access token to cache
$AuthURL = $Kernel::OM->Get('OAuth2')->PrepareAuthURL(
    ProfileID => $OAuth2ProfileID,
);
$Self->True(
    $AuthURL,
    'PrepareAuthURL()',
);
$CacheAccessToken = $Kernel::OM->Get('Cache')->Set(
    Type           => $Kernel::OM->Get('OAuth2')->{CacheType},
    TTL            => 90,
    Key            => "AccessToken::$OAuth2ProfileID",
    Value          => "UnitTest",
    CacheInMemory  => 0,                                            # Cache in Backend only to enforce TTL
    CacheInBackend => 1,
    NoStatsUpdate  => 1
);
$Self->True(
    $CacheAccessToken,
    'Create fake access token',
);

# update profile with changed URLRedirect
$OAuth2ProfileUpdate = $Kernel::OM->Get('OAuth2')->ProfileUpdate(
    ID           => $OAuth2ProfileID,
    Name         => 'Profile-Changed',
    URLAuth      => 'URL Auth-Changed',
    URLToken     => 'URL Token-Changed',
    URLRedirect  => 'URL Redirect-Changed',
    ClientID     => "ClientID",
    ClientSecret => "ClientSecret",
    Scope        => "Scope",
    ValidID      => 1,
    UserID       => 1,
);
$Self->True(
    $OAuth2ProfileUpdate,
    'ProfileUpdate() changed URLRedirect',
);

# check for state token in list and avaiable token
%TokenList = $Kernel::OM->Get('OAuth2')->_TokenList(
    ProfileID => $OAuth2ProfileID,
);
$Self->True(
    (
        IsHashRefWithData( \%TokenList )
        && scalar( keys( %TokenList ) ) == 1
        && $TokenList{state}
    ),
    'Only state token in list',
);
$HasToken = $Kernel::OM->Get('OAuth2')->HasToken(
    ProfileID => $OAuth2ProfileID,
    Silent    => 1,
);
$Self->True(
    $HasToken,
    'HasToken()',
);

# update profile with changed ClientID
$OAuth2ProfileUpdate = $Kernel::OM->Get('OAuth2')->ProfileUpdate(
    ID           => $OAuth2ProfileID,
    Name         => 'Profile-Changed',
    URLAuth      => 'URL Auth-Changed',
    URLToken     => 'URL Token-Changed',
    URLRedirect  => 'URL Redirect-Changed',
    ClientID     => "ClientID-Changed",
    ClientSecret => "ClientSecret",
    Scope        => "Scope",
    ValidID      => 1,
    UserID       => 1,
);
$Self->True(
    $OAuth2ProfileUpdate,
    'ProfileUpdate() changed ClientID',
);

# check for empty token list and no available token
%TokenList = $Kernel::OM->Get('OAuth2')->_TokenList(
    ProfileID => $OAuth2ProfileID,
);
$Self->False(
    IsHashRefWithData( \%TokenList ) // 0,
    'Empty token list',
);
$HasToken = $Kernel::OM->Get('OAuth2')->HasToken(
    ProfileID => $OAuth2ProfileID,
    Silent    => 1,
);
$Self->False(
    $HasToken,
    'HasToken()',
);

# get AuthURL to generate state token and setting fake access token to cache
$AuthURL = $Kernel::OM->Get('OAuth2')->PrepareAuthURL(
    ProfileID => $OAuth2ProfileID,
);
$Self->True(
    $AuthURL,
    'PrepareAuthURL()',
);
$CacheAccessToken = $Kernel::OM->Get('Cache')->Set(
    Type           => $Kernel::OM->Get('OAuth2')->{CacheType},
    TTL            => 90,
    Key            => "AccessToken::$OAuth2ProfileID",
    Value          => "UnitTest",
    CacheInMemory  => 0,                                            # Cache in Backend only to enforce TTL
    CacheInBackend => 1,
    NoStatsUpdate  => 1
);
$Self->True(
    $CacheAccessToken,
    'Create fake access token',
);

# update profile with changed ClientSecret
$OAuth2ProfileUpdate = $Kernel::OM->Get('OAuth2')->ProfileUpdate(
    ID           => $OAuth2ProfileID,
    Name         => 'Profile-Changed',
    URLAuth      => 'URL Auth-Changed',
    URLToken     => 'URL Token-Changed',
    URLRedirect  => 'URL Redirect-Changed',
    ClientID     => "ClientID-Changed",
    ClientSecret => "ClientSecret-Changed",
    Scope        => "Scope",
    ValidID      => 1,
    UserID       => 1,
);
$Self->True(
    $OAuth2ProfileUpdate,
    'ProfileUpdate() changed ClientSecret',
);

# check for state token in list and avaiable token
%TokenList = $Kernel::OM->Get('OAuth2')->_TokenList(
    ProfileID => $OAuth2ProfileID,
);
$Self->True(
    (
        IsHashRefWithData( \%TokenList )
        && scalar( keys( %TokenList ) ) == 1
        && $TokenList{state}
    ),
    'Only state token in list',
);
$HasToken = $Kernel::OM->Get('OAuth2')->HasToken(
    ProfileID => $OAuth2ProfileID,
    Silent    => 1,
);
$Self->True(
    $HasToken,
    'HasToken()',
);

# update profile with changed scope
$OAuth2ProfileUpdate = $Kernel::OM->Get('OAuth2')->ProfileUpdate(
    ID           => $OAuth2ProfileID,
    Name         => 'Profile-Changed',
    URLAuth      => 'URL Auth-Changed',
    URLToken     => 'URL Token-Changed',
    URLRedirect  => 'URL Redirect-Changed',
    ClientID     => "ClientID-Changed",
    ClientSecret => "ClientSecret-Changed",
    Scope        => "Scope-Changed",
    ValidID      => 1,
    UserID       => 1,
);

# check for empty token list and no available token
%TokenList = $Kernel::OM->Get('OAuth2')->_TokenList(
    ProfileID => $OAuth2ProfileID,
);
$Self->False(
    IsHashRefWithData( \%TokenList ) // 0,
    'Empty token list',
);
$HasToken = $Kernel::OM->Get('OAuth2')->HasToken(
    ProfileID => $OAuth2ProfileID,
    Silent    => 1,
);
$Self->False(
    $HasToken,
    'HasToken()',
);

# get AuthURL to generate state token and setting fake access token to cache
$AuthURL = $Kernel::OM->Get('OAuth2')->PrepareAuthURL(
    ProfileID => $OAuth2ProfileID,
);
$Self->True(
    $AuthURL,
    'PrepareAuthURL()',
);
$CacheAccessToken = $Kernel::OM->Get('Cache')->Set(
    Type           => $Kernel::OM->Get('OAuth2')->{CacheType},
    TTL            => 90,
    Key            => "AccessToken::$OAuth2ProfileID",
    Value          => "UnitTest",
    CacheInMemory  => 0,                                            # Cache in Backend only to enforce TTL
    CacheInBackend => 1,
    NoStatsUpdate  => 1
);
$Self->True(
    $CacheAccessToken,
    'Create fake access token',
);

# update profile with changed ValidID
$OAuth2ProfileUpdate = $Kernel::OM->Get('OAuth2')->ProfileUpdate(
    ID           => $OAuth2ProfileID,
    Name         => 'Profile-Changed',
    URLAuth      => 'URL Auth-Changed',
    URLToken     => 'URL Token-Changed',
    URLRedirect  => 'URL Redirect-Changed',
    ClientID     => "ClientID-Changed",
    ClientSecret => "ClientSecret-Changed",
    Scope        => "Scope-Changed",
    ValidID      => 2,
    UserID       => 1,
);
$Self->True(
    $OAuth2ProfileUpdate,
    'ProfileUpdate() changed ValidID',
);

# check for state token in list and avaiable token
%TokenList = $Kernel::OM->Get('OAuth2')->_TokenList(
    ProfileID => $OAuth2ProfileID,
);
$Self->True(
    (
        IsHashRefWithData( \%TokenList )
        && scalar( keys( %TokenList ) ) == 1
        && $TokenList{state}
    ),
    'Only state token in list',
);
$HasToken = $Kernel::OM->Get('OAuth2')->HasToken(
    ProfileID => $OAuth2ProfileID,
    Silent    => 1,
);
$Self->True(
    $HasToken,
    'HasToken()',
);

# process auth code with failure
my $ProcessAuthCodeProfileID = $Kernel::OM->Get('OAuth2')->ProcessAuthCode(
    AuthCode => 'UnitTest',
    State    => $TokenList{state}
);
$Self->False(
    $ProcessAuthCodeProfileID,
    'ProcessAuthCode()',
);

# check for empty token list and no available token
%TokenList = $Kernel::OM->Get('OAuth2')->_TokenList(
    ProfileID => $OAuth2ProfileID,
);
$Self->False(
    IsHashRefWithData( \%TokenList ) // 0,
    'Empty token list',
);
$HasToken = $Kernel::OM->Get('OAuth2')->HasToken(
    ProfileID => $OAuth2ProfileID,
    Silent    => 1,
);
$Self->False(
    $HasToken,
    'HasToken()',
);

# get AuthURL to generate state token and setting fake access token to cache
$AuthURL = $Kernel::OM->Get('OAuth2')->PrepareAuthURL(
    ProfileID => $OAuth2ProfileID,
);
$Self->True(
    $AuthURL,
    'PrepareAuthURL()',
);
$CacheAccessToken = $Kernel::OM->Get('Cache')->Set(
    Type           => $Kernel::OM->Get('OAuth2')->{CacheType},
    TTL            => 90,
    Key            => "AccessToken::$OAuth2ProfileID",
    Value          => "UnitTest",
    CacheInMemory  => 0,                                            # Cache in Backend only to enforce TTL
    CacheInBackend => 1,
    NoStatsUpdate  => 1
);
$Self->True(
    $CacheAccessToken,
    'Create fake access token',
);

# request access token with invalid grant type
my $RequestAccessToken = $Kernel::OM->Get('OAuth2')->RequestAccessToken(
    ProfileID => $OAuth2ProfileID,
    GrantType => 'UnitTest',
);
$Self->False(
    $RequestAccessToken,
    'RequestAccessToken()',
);

# check for state token in list but no avaiable token
%TokenList = $Kernel::OM->Get('OAuth2')->_TokenList(
    ProfileID => $OAuth2ProfileID,
);
$Self->True(
    (
        IsHashRefWithData( \%TokenList )
        && scalar( keys( %TokenList ) ) == 1
        && $TokenList{state}
    ),
    'Only state token in list',
);
$HasToken = $Kernel::OM->Get('OAuth2')->HasToken(
    ProfileID => $OAuth2ProfileID,
    Silent    => 1,
);
$Self->False(
    $HasToken,
    'HasToken()',
);

# setting fake access token to cache
$CacheAccessToken = $Kernel::OM->Get('Cache')->Set(
    Type           => $Kernel::OM->Get('OAuth2')->{CacheType},
    TTL            => 90,
    Key            => "AccessToken::$OAuth2ProfileID",
    Value          => "UnitTest",
    CacheInMemory  => 0,                                            # Cache in Backend only to enforce TTL
    CacheInBackend => 1,
    NoStatsUpdate  => 1
);
$Self->True(
    $CacheAccessToken,
    'Create fake access token',
);

my $OAuth2ProfileDelete = $Kernel::OM->Get('OAuth2')->ProfileDelete(
    ID => $OAuth2ProfileID,
);
$Self->True(
    $OAuth2ProfileDelete,
    'ProfileDelete()',
);

# check for empty token list
%TokenList = $Kernel::OM->Get('OAuth2')->_TokenList(
    ProfileID => $OAuth2ProfileID,
);
$Self->False(
    IsHashRefWithData( \%TokenList ) // 0,
    'Empty token list after deletion',
);

# check that no token is available (access / refresh)
$HasToken = $Kernel::OM->Get('OAuth2')->HasToken(
    ProfileID => $OAuth2ProfileID,
    Silent    => 1,
);
$Self->False(
    $HasToken,
    'HasToken()',
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
