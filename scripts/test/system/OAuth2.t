# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
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
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# get oauth2 object
my $OAuth2Object = $Kernel::OM->Get('OAuth2');

my $OAuth2ProfileAdd = $OAuth2Object->ProfileAdd(
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
    $OAuth2ProfileAdd,
    'ProfileAdd()',
);

my %OAuth2Profile = $OAuth2Object->ProfileGet(
    ID => $OAuth2ProfileAdd,
);

$Self->True(
    $OAuth2Profile{ID} eq $OAuth2ProfileAdd,
    'ProfileGet() - ID',
);
$Self->True(
    $OAuth2Profile{Name} eq 'Profile',
    'ProfileGet() - Name',
);
$Self->True(
    $OAuth2Profile{URLAuth} eq 'URL Auth',
    'ProfileGet() - URLAuth',
);
$Self->True(
    $OAuth2Profile{URLToken} eq 'URL Token',
    'ProfileGet() - URLToken',
);
$Self->True(
    $OAuth2Profile{URLRedirect} eq 'URL Redirect',
    'ProfileGet() - URLRedirect',
);
$Self->True(
    $OAuth2Profile{ClientID} eq 'ClientID',
    'ProfileGet() - ClientID',
);
$Self->True(
    $OAuth2Profile{ClientSecret} eq 'ClientSecret',
    'ProfileGet() - ClientSecret',
);
$Self->True(
    $OAuth2Profile{Scope} eq 'Scope',
    'ProfileGet() - Scope',
);
$Self->True(
    $OAuth2Profile{ValidID} eq 1,
    'ProfileGet() - ValidID',
);
$Self->True(
    $OAuth2Profile{CreateBy} eq 1,
    'ProfileGet() - CreateBy',
);
$Self->True(
    $OAuth2Profile{ChangeBy} eq 1,
    'ProfileGet() - ChangeBy',
);

my $OAuth2ProfileUpdate = $OAuth2Object->ProfileUpdate(
    ID            => $OAuth2ProfileAdd,
    Name         => 'Profile2',
    URLAuth      => 'https://authorization-server.com/auth',
    URLToken     => 'https://authorization-server.com/token',
    URLRedirect  => 'https://localhost/authcode',
    ClientID     => "ClientID2",
    ClientSecret => "ClientSecret2",
    Scope        => "Scope2",
    ValidID      => 1,
    UserID       => 1,
);

$Self->True(
    $OAuth2ProfileUpdate,
    'ProfileUpdate()',
);

%OAuth2Profile = $OAuth2Object->ProfileGet(
    ID => $OAuth2ProfileAdd,
);

$Self->True(
    $OAuth2Profile{ID} eq $OAuth2ProfileAdd,
    'ProfileGet() - ID',
);
$Self->True(
    $OAuth2Profile{Name} eq 'Profile2',
    'ProfileGet() - Name',
);
$Self->True(
    $OAuth2Profile{URLAuth} eq 'https://authorization-server.com/auth',
    'ProfileGet() - URLAuth',
);
$Self->True(
    $OAuth2Profile{URLToken} eq 'https://authorization-server.com/token',
    'ProfileGet() - URLToken',
);
$Self->True(
    $OAuth2Profile{URLRedirect} eq 'https://localhost/authcode',
    'ProfileGet() - URLRedirect',
);
$Self->True(
    $OAuth2Profile{ClientID} eq 'ClientID2',
    'ProfileGet() - ClientID',
);
$Self->True(
    $OAuth2Profile{ClientSecret} eq 'ClientSecret2',
    'ProfileGet() - ClientSecret',
);
$Self->True(
    $OAuth2Profile{Scope} eq 'Scope2',
    'ProfileGet() - Scope',
);
$Self->True(
    $OAuth2Profile{ValidID} eq 1,
    'ProfileGet() - ValidID',
);
$Self->True(
    $OAuth2Profile{CreateBy} eq 1,
    'ProfileGet() - CreateBy',
);
$Self->True(
    $OAuth2Profile{ChangeBy} eq 1,
    'ProfileGet() - ChangeBy',
);

%OAuth2Profile = $OAuth2Object->ProfileGet(
    Name => 'Profile2',
);

$Self->True(
    $OAuth2Profile{ID} eq $OAuth2ProfileAdd,
    'ProfileGet() with Name param - ID',
);
$Self->True(
    $OAuth2Profile{Name} eq 'Profile2',
    'ProfileGet() with Name param - Name',
);
$Self->True(
    $OAuth2Profile{URLAuth} eq 'https://authorization-server.com/auth',
    'ProfileGet() with Name param - URLAuth',
);
$Self->True(
    $OAuth2Profile{URLToken} eq 'https://authorization-server.com/token',
    'ProfileGet() with Name param - URLToken',
);
$Self->True(
    $OAuth2Profile{URLRedirect} eq 'https://localhost/authcode',
    'ProfileGet() with Name param - URLRedirect',
);
$Self->True(
    $OAuth2Profile{ClientID} eq 'ClientID2',
    'ProfileGet() with Name param - ClientID',
);
$Self->True(
    $OAuth2Profile{ClientSecret} eq 'ClientSecret2',
    'ProfileGet() with Name param - ClientSecret',
);
$Self->True(
    $OAuth2Profile{Scope} eq 'Scope2',
    'ProfileGet() with Name param - Scope',
);
$Self->True(
    $OAuth2Profile{ValidID} eq 1,
    'ProfileGet() with Name param - ValidID',
);
$Self->True(
    $OAuth2Profile{CreateBy} eq 1,
    'ProfileGet() with Name param - CreateBy',
);
$Self->True(
    $OAuth2Profile{ChangeBy} eq 1,
    'ProfileGet() with Name param - ChangeBy',
);

my %List = $OAuth2Object->ProfileList(
    Valid => 0,    # just valid/all accounts
);

$Self->True(
    $List{$OAuth2ProfileAdd},
    'ProfileList()',
);

my $ProfileID = $OAuth2Object->ProfileLookup(
    Name => 'Profile2',
);

$Self->True(
    $OAuth2ProfileAdd eq $ProfileID,
    'ProfileLookup() with Name param',
);

my $ProfileName = $OAuth2Object->ProfileLookup(
    ID => $OAuth2ProfileAdd,
);

$Self->True(
    $ProfileName eq 'Profile2',
    'ProfileLookup() with ID param',
);

my $AuthURL = $OAuth2Object->PrepareAuthURL(
    ProfileID => $OAuth2ProfileAdd,
);

## TODO - match schema of expected auth url
$Self->True(
    $AuthURL,
    'PrepareAuthURL()',
);

my $TokenAdd = $OAuth2Object->_TokenAdd(
    ProfileID => $OAuth2ProfileAdd,
    TokenType => 'Test',
    Token     => 'TEST',
);

$Self->True(
    $TokenAdd,
    '_TokenAdd()',
);

my %TokenList = $OAuth2Object->_TokenList(
    ProfileID => $OAuth2ProfileAdd,
);

$Self->True(
    $TokenList{'state'},
    '_TokenList()',
);
$Self->True(
    $TokenList{'Test'} eq 'TEST',
    '_TokenList()',
);

my $TokenUpdate = $OAuth2Object->_TokenAdd(
    ProfileID => $OAuth2ProfileAdd,
    TokenType => 'Test',
    Token     => 'TEST2',
);

$Self->True(
    $TokenUpdate,
    '_TokenAdd() update token',
);

%TokenList = $OAuth2Object->_TokenList(
    ProfileID => $OAuth2ProfileAdd,
);

$Self->True(
    $TokenList{'Test'} eq 'TEST2',
    '_TokenList()',
);

my $TokenProfileID = $OAuth2Object->_TokenLookup(
    TokenType => 'Test',
    Token     => 'TEST2',
);

$Self->True(
    $OAuth2ProfileAdd eq $TokenProfileID,
    '_TokenLookup()',
);

my $TokenDelete = $OAuth2Object->_TokenDelete(
    ProfileID => $OAuth2ProfileAdd,
    TokenType => 'Test',
);

$Self->True(
    $TokenDelete,
    '_TokenDelete()',
);

%TokenList = $OAuth2Object->_TokenList(
    ProfileID => $OAuth2ProfileAdd,
);

$Self->True(
    $TokenList{'state'},
    '_TokenList()',
);
$Self->True(
    !defined($TokenList{'Test'}),
    '_TokenList()',
);

## TODO ##
# UnitTest for sub ProcessAuthCode
# UnitTest for sub GetAccessToken
# UnitTest for sub RequestAccessToken

my $OAuth2ProfileDelete = $OAuth2Object->ProfileDelete(
    ID => $OAuth2ProfileAdd,
);

$Self->True(
    $OAuth2ProfileDelete,
    'ProfileDelete()',
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
