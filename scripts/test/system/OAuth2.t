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

use Test::Fake::HTTPD;
use URI;

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# fake HTTP server
my $HttpdOAP = Test::Fake::HTTPD->new(
    timeout     => 5,
    daemon_args => { }, # HTTP::Daemon args
);
$Self->True(
    $HttpdOAP,
    'Create OAuth2-Provider HTTP service'
);

$HttpdOAP->run(sub {
    my $Req = shift;

    if ( $Req->method eq 'GET' ) {
        my $URI = URI->new( $Req->uri() );

        my %QueryParameter = $URI->query_form();

        if (
            $QueryParameter{client_id}
            && $QueryParameter{scope}
            && $QueryParameter{redirect_uri}
            && $QueryParameter{response_type} eq 'code'
            && $QueryParameter{response_mode} eq 'query'
            && $QueryParameter{state}
        ) {
            my $RedirectURI            = URI->new( $QueryParameter{redirect_uri} );
            my %RedirectQueryParameter = $RedirectURI->query_form();

            $RedirectQueryParameter{state} = $QueryParameter{state};
            $RedirectQueryParameter{code}  = '1234';

            $RedirectURI->query_form( \%RedirectQueryParameter );

            return [ 302, [ 'Location', $RedirectURI ], [ ] ];
        }
    }
    elsif ( $Req->method eq 'POST' ) {
        return [ 200, [ 'Content-Type', 'application/json' ], [ '{
            "access_token": "1234",
            "refresh_token": "5678",
            "expires_in": "1200",
            "id_token": "abcd"
        }' ] ];
    }

    return [ 400, [ 'Content-Type', 'application/json' ], [ ] ];
});
$Self->True(
    $HttpdOAP->host_port,
    'Run OAuth2-Provider HTTP service on '.$HttpdOAP->host_port
);

my $HttpdLocal = Test::Fake::HTTPD->new(
    timeout     => 5,
    daemon_args => { }, # HTTP::Daemon args
);
$Self->True(
    $HttpdLocal,
    'Create local HTTP service'
);

$HttpdLocal->run(sub {
    my $Req = shift;

    if ( $Req->method eq 'GET' ) {
        my $URI = URI->new( $Req->uri() );

        my %QueryParameter = $URI->query_form();
        
        if (
            $QueryParameter{state}
            && $QueryParameter{code}
        ) {
            my ( $ProfileID, $Token ) = $Kernel::OM->Get('OAuth2')->ProcessAuthCode(
                AuthCode => $QueryParameter{code},
                State    => $QueryParameter{state}
            );

            return [ 200, [ 'Content-Type', 'application/json' ], [
'{
    "profile_id": "' . $ProfileID . '",
    "token": "' . $Token . '"
}'
            ] ];
        }
    }

    return [ 400, [ 'Content-Type', 'application/json' ], [ ] ];
});
$Self->True(
    $HttpdLocal->host_port,
    'Run local HTTP service on '.$HttpdLocal->host_port
);

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
$Self->Is(
    $OAuth2Profile{ID},
    $OAuth2ProfileAdd,
    'ProfileGet() - ID',
);
$Self->Is(
    $OAuth2Profile{Name},
    'Profile',
    'ProfileGet() - Name',
);
$Self->Is(
    $OAuth2Profile{URLAuth},
    'URL Auth',
    'ProfileGet() - URLAuth',
);
$Self->Is(
    $OAuth2Profile{URLToken},
    'URL Token',
    'ProfileGet() - URLToken',
);
$Self->Is(
    $OAuth2Profile{URLRedirect},
    'URL Redirect',
    'ProfileGet() - URLRedirect',
);
$Self->Is(
    $OAuth2Profile{ClientID},
    'ClientID',
    'ProfileGet() - ClientID',
);
$Self->Is(
    $OAuth2Profile{ClientSecret},
    'ClientSecret',
    'ProfileGet() - ClientSecret',
);
$Self->Is(
    $OAuth2Profile{Scope},
    'Scope',
    'ProfileGet() - Scope',
);
$Self->Is(
    $OAuth2Profile{ValidID},
    1,
    'ProfileGet() - ValidID',
);
$Self->Is(
    $OAuth2Profile{CreateBy},
    1,
    'ProfileGet() - CreateBy',
);
$Self->Is(
    $OAuth2Profile{ChangeBy},
    1,
    'ProfileGet() - ChangeBy',
);

my $OAuth2ProfileUpdate = $OAuth2Object->ProfileUpdate(
    ID            => $OAuth2ProfileAdd,
    Name         => 'Profile2',
    URLAuth      => $HttpdOAP->endpoint->as_string() . '/auth',
    URLToken     => $HttpdOAP->endpoint->as_string() . '/token',
    URLRedirect  => $HttpdLocal->endpoint->as_string() . '/authcode',
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
$Self->Is(
    $OAuth2Profile{ID},
    $OAuth2ProfileAdd,
    'ProfileGet() - ID',
);
$Self->Is(
    $OAuth2Profile{Name},
    'Profile2',
    'ProfileGet() - Name',
);
$Self->Is(
    $OAuth2Profile{URLAuth},
    $HttpdOAP->endpoint->as_string() . '/auth',
    'ProfileGet() - URLAuth',
);
$Self->Is(
    $OAuth2Profile{URLToken},
    $HttpdOAP->endpoint->as_string() . '/token',
    'ProfileGet() - URLToken',
);
$Self->Is(
    $OAuth2Profile{URLRedirect},
    $HttpdLocal->endpoint->as_string() . '/authcode',
    'ProfileGet() - URLRedirect',
);
$Self->Is(
    $OAuth2Profile{ClientID},
    'ClientID2',
    'ProfileGet() - ClientID',
);
$Self->Is(
    $OAuth2Profile{ClientSecret},
    'ClientSecret2',
    'ProfileGet() - ClientSecret',
);
$Self->Is(
    $OAuth2Profile{Scope},
    'Scope2',
    'ProfileGet() - Scope',
);
$Self->Is(
    $OAuth2Profile{ValidID},
    1,
    'ProfileGet() - ValidID',
);
$Self->Is(
    $OAuth2Profile{CreateBy},
    1,
    'ProfileGet() - CreateBy',
);
$Self->Is(
    $OAuth2Profile{ChangeBy},
    1,
    'ProfileGet() - ChangeBy',
);

%OAuth2Profile = $OAuth2Object->ProfileGet(
    Name => 'Profile2',
);
$Self->Is(
    $OAuth2Profile{ID},
    $OAuth2ProfileAdd,
    'ProfileGet() with Name param - ID',
);
$Self->Is(
    $OAuth2Profile{Name},
    'Profile2',
    'ProfileGet() with Name param - Name',
);
$Self->Is(
    $OAuth2Profile{URLAuth},
    $HttpdOAP->endpoint->as_string() . '/auth',
    'ProfileGet() with Name param - URLAuth',
);
$Self->Is(
    $OAuth2Profile{URLToken},
    $HttpdOAP->endpoint->as_string() . '/token',
    'ProfileGet() with Name param - URLToken',
);
$Self->Is(
    $OAuth2Profile{URLRedirect},
    $HttpdLocal->endpoint->as_string() . '/authcode',
    'ProfileGet() with Name param - URLRedirect',
);
$Self->Is(
    $OAuth2Profile{ClientID},
    'ClientID2',
    'ProfileGet() with Name param - ClientID',
);
$Self->Is(
    $OAuth2Profile{ClientSecret},
    'ClientSecret2',
    'ProfileGet() with Name param - ClientSecret',
);
$Self->Is(
    $OAuth2Profile{Scope},
    'Scope2',
    'ProfileGet() with Name param - Scope',
);
$Self->Is(
    $OAuth2Profile{ValidID},
    1,
    'ProfileGet() with Name param - ValidID',
);
$Self->Is(
    $OAuth2Profile{CreateBy},
    1,
    'ProfileGet() with Name param - CreateBy',
);
$Self->Is(
    $OAuth2Profile{ChangeBy},
    1,
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
$Self->Is(
    $OAuth2ProfileAdd,
    $ProfileID,
    'ProfileLookup() with Name param',
);

my $ProfileName = $OAuth2Object->ProfileLookup(
    ID => $OAuth2ProfileAdd,
);
$Self->Is(
    $ProfileName,
    'Profile2',
    'ProfileLookup() with ID param',
);

my $State = $OAuth2Object->StateAdd(
    ProfileID => $ProfileID,
    TokenType => 'access_token',
);
$Self->True(
    $State,
    'StateAdd() - minimal parameter',
);

my $StateData = $OAuth2Object->StateGet(
    State  => $State,
);
$Self->IsDeeply(
    $StateData,
    {
        ProfileID   => $ProfileID,
        TokenType   => 'access_token',
        URLRedirect => $HttpdLocal->endpoint->as_string() . '/authcode'
    },
    'StateGet()',
);

my $StateDelete = $OAuth2Object->StateDelete(
    State => $State,
);
$Self->True(
    $StateDelete,
    'StateDelete()',
);

$State = $OAuth2Object->StateAdd(
    ProfileID   => $ProfileID,
    TokenType   => 'access_token',
    URLRedirect => $HttpdOAP->endpoint->as_string() . '/auth',
    StateData   => {
        ProfileID   => '0',
        TokenType   => 'UnitTest',
        URLRedirect => 'http://localhost',
        UnitTest    => 1
    }
);
$Self->True(
    $State,
    'StateAdd() - all parameter, StateData trying to override ProfileID, TokenType and URLRedirect',
);

$StateData = $OAuth2Object->StateGet(
    State  => $State,
);
$Self->IsDeeply(
    $StateData,
    {
        ProfileID   => $ProfileID,
        TokenType   => 'access_token',
        URLRedirect => $HttpdOAP->endpoint->as_string() . '/auth',
        UnitTest    => 1
    },
    'StateGet()',
);

$StateDelete = $OAuth2Object->StateDelete(
    State => $State,
);
$Self->True(
    $StateDelete,
    'StateDelete()',
);

my $AuthURL = $OAuth2Object->PrepareAuthURL(
    ProfileID => $OAuth2ProfileAdd
);
$Self->True(
    $AuthURL,
    'PrepareAuthURL()',
);
my $URI = URI->new( $AuthURL );
my %QueryParameter = $URI->query_form();
$Self->Is(
    $QueryParameter{'client_id'},
    'ClientID2',
    'PrepareAuthURL() - client_id',
);
$Self->Is(
    $QueryParameter{'scope'},
    'Scope2',
    'PrepareAuthURL() - scope',
);
$Self->Is(
    $QueryParameter{'redirect_uri'},
    $HttpdLocal->endpoint->as_string() . '/authcode',
    'PrepareAuthURL() - redirect_uri',
);
$Self->Is(
    $QueryParameter{'response_type'},
    'code',
    'PrepareAuthURL() - response_type',
);
$Self->Is(
    $QueryParameter{'response_mode'},
    'query',
    'PrepareAuthURL() - response_mode',
);
$Self->True(
    $QueryParameter{'state'},
    'PrepareAuthURL() - state',
);
$Self->False(
    $QueryParameter{'nonce'},
    'PrepareAuthURL() - No nonce',
);

$StateData = $OAuth2Object->StateGet(
    State  => $QueryParameter{'state'},
);
$Self->IsDeeply(
    $StateData,
    {
        ProfileID   => $ProfileID,
        TokenType   => 'access_token',
        URLRedirect => $HttpdLocal->endpoint->as_string() . '/authcode'
    },
    'StateGet() for AuthURL',
);

my $WebUserAgentObject = $Kernel::OM->Get('WebUserAgent');
my %Response = $WebUserAgentObject->Request(
    URL                 => $AuthURL,
    SkipSSLVerification => 1,
);
$Self->Is(
    $Response{Status},
    '200 OK',
    'Response of AuthURL - State'
);
$Self->Is(
    ${$Response{Content}},
'{
    "profile_id": "' . $OAuth2ProfileAdd . '",
    "token": "1234"
}',
    'Response of AuthURL - Content'
);

my $AccessToken = $OAuth2Object->GetAccessToken(
    ProfileID => $OAuth2ProfileAdd
);
$Self->Is(
    $AccessToken,
    '1234',
    'GetAccessToken()'
);

# remove access token from cache
$Kernel::OM->Get('Cache')->Delete(
    Type => $OAuth2Object->{CacheType},
    Key  => "AccessToken::$OAuth2ProfileAdd",
);
$AccessToken = $OAuth2Object->GetAccessToken(
    ProfileID => $OAuth2ProfileAdd
);
$Self->Is(
    $AccessToken,
    '1234',
    'GetAccessToken() - after access token is removed from cache'
);

$AuthURL = $OAuth2Object->PrepareAuthURL(
    ProfileID   => $OAuth2ProfileAdd,
    TokenType   => 'id_token',
    URLRedirect => $HttpdLocal->endpoint->as_string() . '/ProcessAuthCode',
    Nonce       => 1,
    StateData   => {
        UnitTest => 1,
    }
);
$Self->True(
    $AuthURL,
    'PrepareAuthURL() - specific parameter',
);
my $URI = URI->new( $AuthURL );
my %QueryParameter = $URI->query_form();
$Self->Is(
    $QueryParameter{'client_id'},
    'ClientID2',
    'PrepareAuthURL() - client_id',
);
$Self->Is(
    $QueryParameter{'scope'},
    'Scope2',
    'PrepareAuthURL() - scope',
);
$Self->Is(
    $QueryParameter{'redirect_uri'},
    $HttpdLocal->endpoint->as_string() . '/ProcessAuthCode',
    'PrepareAuthURL() - redirect_uri',
);
$Self->Is(
    $QueryParameter{'response_type'},
    'code',
    'PrepareAuthURL() - response_type',
);
$Self->Is(
    $QueryParameter{'response_mode'},
    'query',
    'PrepareAuthURL() - response_mode',
);
$Self->True(
    $QueryParameter{'state'},
    'PrepareAuthURL() - state',
);
$Self->True(
    $QueryParameter{'nonce'},
    'PrepareAuthURL() - nonce',
);

$StateData = $OAuth2Object->StateGet(
    State  => $QueryParameter{'state'},
);
$Self->IsDeeply(
    $StateData,
    {
        ProfileID   => $ProfileID,
        TokenType   => 'id_token',
        URLRedirect => $HttpdLocal->endpoint->as_string() . '/ProcessAuthCode',
        Nonce       => $QueryParameter{'nonce'},
        UnitTest    => 1
    },
    'StateGet() for AuthURL',
);

%Response = $WebUserAgentObject->Request(
    URL                 => $AuthURL,
    SkipSSLVerification => 1,
);
$Self->Is(
    $Response{Status},
    '200 OK',
    'Response of AuthURL - State'
);
$Self->Is(
    ${$Response{Content}},
'{
    "profile_id": "' . $OAuth2ProfileAdd . '",
    "token": "abcd"
}',
    'Response of AuthURL - Content'
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
$Self->Is(
    $TokenList{'Test'},
    'TEST',
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
$Self->Is(
    $TokenList{'Test'},
    'TEST2',
    '_TokenList()',
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
    !defined($TokenList{'Test'}),
    '_TokenList()',
);

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
