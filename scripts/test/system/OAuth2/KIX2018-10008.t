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
my $HasAccessToken = $Kernel::OM->Get('OAuth2')->HasAccessToken(
    ProfileID => $OAuth2ProfileID
);
$Self->False(
    $HasAccessToken,
    'HasAccessToken()',
);

# get AuthURL to generate state token
my $AuthURL = $Kernel::OM->Get('OAuth2')->PrepareAuthURL(
    ProfileID => $OAuth2ProfileID,
);
$Self->True(
    $AuthURL,
    'PrepareAuthURL()',
);

# check for no token in list
%TokenList = $Kernel::OM->Get('OAuth2')->_TokenList(
    ProfileID => $OAuth2ProfileID,
);
$Self->True(
    (
        IsHashRef( \%TokenList )
        && scalar( keys( %TokenList ) ) == 0
    ),
    'No token in list',
);

# check that no token is available (access / refresh)
$HasAccessToken = $Kernel::OM->Get('OAuth2')->HasAccessToken(
    ProfileID => $OAuth2ProfileID
);
$Self->False(
    $HasAccessToken,
    'HasAccessToken()',
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

# check for no token in list (access token is only in cache)
%TokenList = $Kernel::OM->Get('OAuth2')->_TokenList(
    ProfileID => $OAuth2ProfileID,
);
$Self->True(
    (
        IsHashRef( \%TokenList )
        && scalar( keys( %TokenList ) ) == 0
    ),
    'No token in list',
);

# check that token is available (access / refresh)
$HasAccessToken = $Kernel::OM->Get('OAuth2')->HasAccessToken(
    ProfileID => $OAuth2ProfileID
);
$Self->True(
    $HasAccessToken,
    'HasAccessToken()',
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

# check for no token in list and avaiable token
%TokenList = $Kernel::OM->Get('OAuth2')->_TokenList(
    ProfileID => $OAuth2ProfileID,
);
$Self->True(
    (
        IsHashRef( \%TokenList )
        && scalar( keys( %TokenList ) ) == 0
    ),
    'No token in list',
);
$HasAccessToken = $Kernel::OM->Get('OAuth2')->HasAccessToken(
    ProfileID => $OAuth2ProfileID
);
$Self->True(
    $HasAccessToken,
    'HasAccessToken()',
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
$HasAccessToken = $Kernel::OM->Get('OAuth2')->HasAccessToken(
    ProfileID => $OAuth2ProfileID
);
$Self->False(
    $HasAccessToken,
    'HasAccessToken()',
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
$HasAccessToken = $Kernel::OM->Get('OAuth2')->HasAccessToken(
    ProfileID => $OAuth2ProfileID
);
$Self->False(
    $HasAccessToken,
    'HasAccessToken()',
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

# check for no token in list and avaiable token
%TokenList = $Kernel::OM->Get('OAuth2')->_TokenList(
    ProfileID => $OAuth2ProfileID,
);
$Self->True(
    (
        IsHashRef( \%TokenList )
        && scalar( keys( %TokenList ) ) == 0
    ),
    'No token in list',
);
$HasAccessToken = $Kernel::OM->Get('OAuth2')->HasAccessToken(
    ProfileID => $OAuth2ProfileID
);
$Self->True(
    $HasAccessToken,
    'HasAccessToken()',
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
$HasAccessToken = $Kernel::OM->Get('OAuth2')->HasAccessToken(
    ProfileID => $OAuth2ProfileID
);
$Self->False(
    $HasAccessToken,
    'HasAccessToken()',
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

# check for no token in list and avaiable token
%TokenList = $Kernel::OM->Get('OAuth2')->_TokenList(
    ProfileID => $OAuth2ProfileID,
);
$Self->True(
    (
        IsHashRef( \%TokenList )
        && scalar( keys( %TokenList ) ) == 0
    ),
    'No token in list',
);
$HasAccessToken = $Kernel::OM->Get('OAuth2')->HasAccessToken(
    ProfileID => $OAuth2ProfileID
);
$Self->True(
    $HasAccessToken,
    'HasAccessToken()',
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
$HasAccessToken = $Kernel::OM->Get('OAuth2')->HasAccessToken(
    ProfileID => $OAuth2ProfileID
);
$Self->False(
    $HasAccessToken,
    'HasAccessToken()',
);

# get AuthURL to generate state token and setting fake access token to cache
$AuthURL = $Kernel::OM->Get('OAuth2')->PrepareAuthURL(
    ProfileID => $OAuth2ProfileID,
);
# extract state from provided url
my $State;
if ( $AuthURL =~ m/state=([^&;]+)/ ) {
    $State = $1;
}
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

# check for no token in list and avaiable token
%TokenList = $Kernel::OM->Get('OAuth2')->_TokenList(
    ProfileID => $OAuth2ProfileID,
);
$Self->True(
    (
        IsHashRef( \%TokenList )
        && scalar( keys( %TokenList ) ) == 0
    ),
    'No token in list',
);
$HasAccessToken = $Kernel::OM->Get('OAuth2')->HasAccessToken(
    ProfileID => $OAuth2ProfileID
);
$Self->True(
    $HasAccessToken,
    'HasAccessToken()',
);

# process auth code with failure
my $ProcessAuthCodeProfileID = $Kernel::OM->Get('OAuth2')->ProcessAuthCode(
    AuthCode => 'UnitTest',
    State    => $State
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
$HasAccessToken = $Kernel::OM->Get('OAuth2')->HasAccessToken(
    ProfileID => $OAuth2ProfileID
);
$Self->False(
    $HasAccessToken,
    'HasAccessToken()',
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
my $RequestAccessToken = $Kernel::OM->Get('OAuth2')->RequestToken(
    ProfileID => $OAuth2ProfileID,
    TokenType => 'access_token',
    GrantType => 'UnitTest',
);
$Self->False(
    $RequestAccessToken,
    'RequestAccessToken()',
);

# check for no avaiable token
%TokenList = $Kernel::OM->Get('OAuth2')->_TokenList(
    ProfileID => $OAuth2ProfileID,
);
$Self->True(
    (
        IsHashRef( \%TokenList )
        && scalar( keys( %TokenList ) ) == 0
    ),
    'No token in list',
);
$HasAccessToken = $Kernel::OM->Get('OAuth2')->HasAccessToken(
    ProfileID => $OAuth2ProfileID
);
$Self->False(
    $HasAccessToken,
    'HasAccessToken()',
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
$HasAccessToken = $Kernel::OM->Get('OAuth2')->HasAccessToken(
    ProfileID => $OAuth2ProfileID
);
$Self->False(
    $HasAccessToken,
    'HasAccessToken()',
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
