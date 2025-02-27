# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2019–2021 Efflux GmbH, https://efflux.de/
# Copyright (C) 2019-2021 Rother OSS GmbH, https://otobo.de/
# --
# This software comes with ABSOLUTELY NO WARRANTY. This program is
# licensed under the AGPL-3.0 with code licensed under the GPL-3.0.
# For details, see the enclosed files LICENSE (AGPL) and
# LICENSE-GPL3 (GPL3) for license information. If you did not receive
# this files, see https://www.gnu.org/licenses/agpl.txt (APGL) and
# https://www.gnu.org/licenses/gpl-3.0.txt (GPL3).
# --

package Kernel::System::OAuth2;

use strict;
use warnings;

use URI;
use URI::QueryParam;

our @ObjectDependencies = qw(
    ClientRegistration
    Cache
    DB
    JSON
    Log
    Valid
    WebUserAgent
);

=head1 NAME

Kernel::System::OAuth2 - to authenticate

=head1 DESCRIPTION

Global module to authenticate accounts via OAuth 2.0.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $OAuth2Object = $Kernel::OM->Get('OAuth2');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    $Self->{CacheType} = 'OAuth2';

    return $Self;
}

=item ProfileAdd()

add new oauth2 profile

    my $ID = $OAuth2Object->ProfileAdd(
        Name         => 'Profile',
        URLAuth      => 'URL Auth',
        URLToken     => 'URL Token',
        URLRedirect  => 'URL Redirect',
        ClientID     => "ClientID",
        ClientSecret => "ClientSecret",
        Scope        => "Scope",
        ValidID      => 1,
        UserID       => 123,
    );

=cut

sub ProfileAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Name URLAuth URLToken URLRedirect ClientID ClientSecret Scope ValidID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check if a profile with this name already exists
    if ( $Self->ProfileLookup( Name => $Param{Name} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "A OAuth2 profile with name '$Param{Name}' already exists!"
        );
        return;
    }

    # get needed objects
    my $DBObject = $Kernel::OM->Get('DB');

    # store data
    return if !$DBObject->Do(
        SQL => 'INSERT INTO oauth2_profile (name, url_auth, url_token, url_redirect,'
            . ' client_id, client_secret, scope, valid_id,'
            . ' create_time, create_by, change_time, change_by)'
            . ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Name}, \$Param{URLAuth}, \$Param{URLToken}, \$Param{URLRedirect},
            \$Param{ClientID}, \$Param{ClientSecret}, \$Param{Scope}, \$Param{ValidID},
            \$Param{UserID}, \$Param{UserID},
        ],
    );

    # get new profile id
    return if !$DBObject->Prepare(
        SQL   => 'SELECT id FROM oauth2_profile WHERE name = ?',
        Bind  => [ \$Param{Name} ],
        Limit => 1,
    );

    # fetch the result
    my $ID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ID = $Row[0];
    }
    return if !$ID;

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'OAuth2Profile',
        ObjectID  => $ID
    );

    return $ID;
}

=item ProfileGet()

get profile attributes

    my %Profile = $OAuth2Object->ProfileGet(
        Name  => 'Profile',
    );

    my %Profile = $OAuth2Object->ProfileGet(
        ID    => 123,
    );

returns

    my %Profile = (
        ID           => 1,
        Name         => "Profile",
        URLAuth      => 'URL Auth',
        URLToken     => 'URL Token',
        URLRedirect  => 'URL Redirect',
        ClientID     => "ClientID",
        ClientSecret => "ClientSecret",
        Scope        => "Scope",
        ValidID      => 1,
        CreateTime   => '2010-04-07 15:41:15',
        CreateBy     => '321',
        ChangeTime   => '2010-04-07 15:59:45',
        ChangeBy     => '223',
    );

=cut

sub ProfileGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ID} && !$Param{Name} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need ID or Name!"
        );
        return;
    }

    # lookup the ID
    if ( !$Param{ID} ) {
        $Param{ID} = $Self->ProfileLookup(
            Name => $Param{Name},
        );
        if ( !$Param{ID} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "ID for OAuth2 profile '$Param{Name}' not found!",
            );
            return;
        }
    }

    # get needed objects
    my $DBObject = $Kernel::OM->Get('DB');

    # ask the database
    return if !$DBObject->Prepare(
        SQL => 'SELECT id, name, url_auth, url_token, url_redirect,'
            . ' client_id, client_secret, scope, valid_id,'
            . ' create_time, create_by, change_time, change_by'
            . ' FROM oauth2_profile WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );

    # fetch the result
    my %Profile;
    while ( my @Data = $DBObject->FetchrowArray() ) {
        %Profile = (
            ID           => $Data[0],
            Name         => $Data[1],
            URLAuth      => $Data[2],
            URLToken     => $Data[3],
            URLRedirect  => $Data[4],
            ClientID     => $Data[5],
            ClientSecret => $Data[6],
            Scope        => $Data[7],
            ValidID      => $Data[8],
            CreateTime   => $Data[9],
            CreateBy     => $Data[10],
            ChangeTime   => $Data[11],
            ChangeBy     => $Data[12],
        );
    }

    # no data found
    if ( !%Profile ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "OAuth2 profile with ID '$Param{ID}' not found!",
        );
        return;
    }

    return %Profile;
}

=item ProfileUpdate()

update profile attributes

    my $Success = $OAuth2Object->ProfileUpdate(
        ID           => 123,
        Name         => 'Profile',
        URLAuth      => 'URL Auth',
        URLToken     => 'URL Token',
        URLRedirect  => 'URL Redirect',
        ClientID     => "ClientID",
        ClientSecret => "ClientSecret",
        Scope        => "Scope",
        ValidID      => 1,
        UserID       => 123,
    );

=cut

sub ProfileUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID Name URLAuth URLToken URLRedirect ClientID ClientSecret Scope ValidID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check if a profile with this name already exists
    my $ExistingID = $Self->ProfileLookup(
       Name => $Param{Name},
    );
    if (
        $ExistingID
        && $ExistingID != $Param{ID}
    ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "A OAuth2 profile with name '$Param{Name}' already exists!"
        );
        return;
    }

    # get current data
    my %OldProfile = $Self->ProfileGet(
        ID => $Param{ID},
    );

    # check if token need to be cleaned
    if (
        $Param{URLAuth} ne $OldProfile{URLAuth}
        || $Param{URLToken} ne $OldProfile{URLToken}
        || $Param{ClientID} ne $OldProfile{ClientID}
        || $Param{Scope} ne $OldProfile{Scope}
    ) {
        return if  !$Self->_TokenDelete(
            ProfileID => $Param{ID},
        );

        # push client callback event
        $Kernel::OM->Get('ClientNotification')->NotifyClients(
            Event     => 'DELETE',
            Namespace => 'OAuth2ProfileAuth',
            ObjectID  => $Param{ID},
        );
    }

    # get needed objects
    my $DBObject = $Kernel::OM->Get('DB');

    # sql
    return if !$DBObject->Do(
        SQL => 'UPDATE oauth2_profile SET name = ?, url_auth = ?, url_token = ?, url_redirect = ?,'
            . ' client_id = ?, client_secret = ?, scope = ?, valid_id = ?,'
            . ' change_time = current_timestamp, change_by = ?'
            . ' WHERE id = ?',
        Bind => [
            \$Param{Name}, \$Param{URLAuth}, \$Param{URLToken}, \$Param{URLRedirect},
            \$Param{ClientID}, \$Param{ClientSecret}, \$Param{Scope}, \$Param{ValidID},
            \$Param{UserID}, \$Param{ID},
        ],
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'OAuth2Profile',
        ObjectID  => $Param{ID},
    );

    return 1;
}

=item ProfileList()

get profile list as a hash of ID, Name pairs

    my %List = $OAuth2Object->ProfileList();

or

    my %List = $OAuth2Object->ProfileList(
        Valid  => 1,
    );

or

    my %List = $OAuth2Object->ProfileList(
        Valid  => 0, # is default
    );

returns

    my %List = (
        1 => "Profile",
    );

=cut

sub ProfileList {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $DBObject    = $Kernel::OM->Get('DB');
    my $ValidObject = $Kernel::OM->Get('Valid');

    # check Valid param
    my $Valid = 0;
    if ( $Param{Valid} ) {
        $Valid = 1;
    }

    # build SQL
    my $SQL = 'SELECT id, name FROM oauth2_profile';

    # add WHERE statement
    if ( $Valid ) {
        # create the valid list
        my $ValidIDs = join( ', ', $ValidObject->ValidIDsGet() );

        $SQL .= ' WHERE valid_id IN (' . $ValidIDs . ')';
    }

    # ask database
    return if !$DBObject->Prepare(
        SQL => $SQL,
    );

    # fetch the result
    my %ProfileList;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ProfileList{ $Row[0] } = $Row[1];
    }

    return %ProfileList;
}

=item ProfileLookup()

returns the id or the name of a profile

    my $ProfileID = $OAuth2Object->ProfileLookup(
        Name => 'Profile',
    );

or

    my $ProfileName = $OAuth2Object->ProfileLookup(
        ID => 2,
    );

=cut

sub ProfileLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Name} && !$Param{ID} ) {
        $Kernel::OM->Get('Log')->Log(
            State   => 'error',
            Message => 'Need Name or ID!'
        );
        return;
    }

    # get needed objects
    my $DBObject = $Kernel::OM->Get('DB');

    # init data
    my $Key;
    my $Value;
    my $SQL;
    my @Bind;

    # prepare data
    if ( $Param{ID} ) {
        $Key   = 'ID';
        $Value = $Param{ID};
        $SQL   = 'SELECT name FROM oauth2_profile WHERE id = ?';
        push( @Bind, \$Param{ID} );
    }
    else {
        $Key   = 'Name';
        $Value = $Param{Name};
        $SQL   = 'SELECT id FROM oauth2_profile WHERE name = ?';
        push( @Bind, \$Param{Name} );
    }

    # lookup
    $DBObject->Prepare(
        SQL   => $SQL,
        Bind  => \@Bind,
        Limit => 1,
    );

    my $ReturnData;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ReturnData = $Row[0];
    }

    return $ReturnData;
}

=head2 ProfileDelete()

Delete profile.

    my $Success = $OAuth2Object->ProfileDelete(
        ID => $ID,
    );

=cut

sub ProfileDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # delete token of profile
    return if !$Self->_TokenDelete(
        ProfileID => $Param{ID}
    );

    # get needed objects
    my $DBObject = $Kernel::OM->Get('DB');

    # init data
    my $SQL  = 'DELETE FROM oauth2_profile WHERE id = ?';
    my @Bind = ( \$Param{ID} );

    # execute
    return if !$DBObject->Do(
        SQL  => $SQL,
        Bind => \@Bind,
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'OAuth2Profile',
        ObjectID  => $Param{ID},
    );

    return 1;
}

=item StateAdd()

add new oauth2 state

    my $State = $OAuth2Object->StateAdd(
        ProfileID   => '123',
        TokenType   => 'access_token',
        URLRedirect => 'URL Redirect',      # optional, fallback to URLRedirect of profile
        StateData   => {},                  # optional, hash with additional data
    );

=cut

sub StateAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ProfileID TokenType)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my %Profile = $Self->ProfileGet(
        ID => $Param{ProfileID},
    );
    return if ( !%Profile );

    # create a random string to prevent cross-site requests.
    my $State = $Kernel::OM->Get('Main')->GenerateRandomString(
        Length => 32,
    );

    # prepare state data
    if ( ref( $Param{StateData} ) ne 'HASH' ) {
        $Param{StateData} = {};
    }
    my %StateData = (
        %{ $Param{StateData} },
        ProfileID   => $Param{ProfileID},
        TokenType   => $Param{TokenType},
        URLRedirect => $Param{URLRedirect} || $Profile{URLRedirect}
    );
    if ( $Param{Nonce} ) {
        $StateData{Nonce} = $Param{Nonce};
    }

    # remember state in cache for 15minutes
    $Kernel::OM->Get('Cache')->Set(
        Type           => $Self->{CacheType},
        TTL            => ( 15 * 60 ),
        Key            => "State::$State",
        Value          => \%StateData,
        CacheInMemory  => 0,                                            # Cache in Backend only to enforce TTL
        CacheInBackend => 1,
        NoStatsUpdate  => 1
    );

    return $State;
}

=item StateGet()

get state data

    my $StateData = $OAuth2Object->StateGet(
        State  => 'State',
    );

returns

    my $StateData = {
        ProfileID   => 123,
        TokenType   => "access_token",
        URLRedirect => 'URL Redirect',
        ...
    };

=cut

sub StateGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(State)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get state data from cache
    my $StateDataRef = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => "State::$Param{State}",
    );

    return $StateDataRef;
}

=head2 StateDelete()

Delete state.

    my $Success = $OAuth2Object->StateDelete(
        State => 'State',
    );

=cut

sub StateDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(State)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # forget state
    $Kernel::OM->Get('Cache')->Delete(
        Type => $Self->{CacheType},
        Key  => "State::$Param{State}",
    );

    return 1;
}



=head2 PrepareAuthURL()

Build the URL to request an authorization code.

Example:
    my $AuthURL = $OAuth2Object->PrepareAuthURL(
        ProfileID   => 123,
        TokenType   => 'access_token',          # optional, default 'access_token'
        URLRedirect => 'redirect url',          # optional, override URLRedirect from profile
        Nonce       => 1,                       # optional, generate nonce for request
        StateData   => {...},                   # optional, addition state data
    );

returns

    my $AuthURL = "https://login.microsoftonline.com/common/oauth2/v2.0/authorize?...";

=cut

sub PrepareAuthURL {
    my ( $Self, %Param ) = @_;

### Code licensed under the GPL-3.0, Copyright (C) 2019-2021 Rother OSS GmbH, https://otobo.de/ ###
    # check needed stuff
    for (qw(ProfileID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my %Profile = $Self->ProfileGet(
        ID => $Param{ProfileID},
    );
    return if ( !%Profile );

    # use provided redirect url or fallback to profile
    my $URLRedirect = $Param{URLRedirect} || $Profile{URLRedirect};

    # fallback to access_token if not defined
    if ( !defined( $Param{TokenType} ) ) {
        $Param{TokenType} = 'access_token';
    }

    # generate nonce, when requested
    my $Nonce;
    if ( $Param{Nonce} ) {
        $Nonce = $Kernel::OM->Get('Main')->GenerateRandomString(
            Length => 32,
        );
    }

    # create state
    my $State = $Self->StateAdd(
        ProfileID   => $Param{ProfileID},
        TokenType   => $Param{TokenType},
        URLRedirect => $URLRedirect,
        StateData   => $Param{StateData},
        Nonce       => $Nonce,
    );
    return if ( !$State );

    # build authorization url
    my $URL = URI->new( $Profile{URLAuth} );
    $URL->query_param_append( 'client_id',     $Profile{ClientID} );
    $URL->query_param_append( 'scope',         $Profile{Scope} );
    $URL->query_param_append( 'redirect_uri',  $URLRedirect );
    $URL->query_param_append( 'response_type', 'code' );
    $URL->query_param_append( 'response_mode', 'query' );
    $URL->query_param_append( 'state',         $State );
    if ( $Nonce ) {
        $URL->query_param_append( 'nonce', $Nonce );
    }
### EO Code licensed under the GPL-3.0, Copyright (C) 2019-2021 Rother OSS GmbH, https://otobo.de/ ###

    return $URL->as_string();
}

=head2 ProcessAuthCode()

Process the provided code and state.

Example:
    my ( $ProfileID, $Token ) = $OAuth2Object->ProcessAuthCode(
        AuthCode => 'iLjCNtwdbGTF3WyBuJPeT3uJA8njrQEi',
        State    => 'mrgMqBWueEKYufTcLgQXeCYLzxHw6695'
    );

returns

    my ( $ProfileID, $Token ) = ( 123, 'iLjCNtwueEKYufTcLgQXeCYJA8njrQEi' );

=cut

sub ProcessAuthCode {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(AuthCode State)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get state data
    my $StateData = $Self->StateGet(
        State => $Param{State}
    );
    if (
        ref( $StateData ) ne 'HASH'
        || !$StateData->{ProfileID}
        || !$StateData->{TokenType}
        || !$StateData->{URLRedirect}
    ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Could not find profile for provided state!"
        );
        return;
    }

    # forget state
    $Self->StateDelete(
        State => $Param{State}
    );

    # request token with authorization code
    my $Token = $Self->RequestToken(
        ProfileID   => $StateData->{ProfileID},
        TokenType   => $StateData->{TokenType},
        URLRedirect => $StateData->{URLRedirect},
        GrantType   => 'authorization_code',
        Code        => $Param{AuthCode},
    );
    if ( !$Token ) {
        return;
    }

    return ( $StateData->{ProfileID}, $Token );
}

=head2 GetAccessToken()

Request a valid access token for the profile

Example:
    my $AccessToken = $OAuth2Object->GetAccessToken(
        ProfileID => 123
    )

=cut

sub GetAccessToken {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ProfileID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need ProfileID!"
        );
        return;
    }

    # Try the cache
    my $Token = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => "AccessToken::$Param{ProfileID}",
    );
    return $Token if $Token;

    # Get an access and refresh token.
    my $AccessToken = $Self->RequestToken(
        ProfileID => $Param{ProfileID},
        TokenType => 'access_token',
        GrantType => 'refresh_token'
    );
    return if !$AccessToken;

    return $AccessToken;
}

=head2 HasAccessToken()

Check if profile has a valid access_token, or at least a refresh_token

Example:
    my $Result = $OAuth2Object->HasAccessToken(
        ProfileID => 123,
        Silent    => 0       # Optional: No error if tokens not found
    )

    return 1 or undef

=cut

sub HasAccessToken {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ProfileID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need ProfileID!"
        );
        return;
    }

    # Try the cache
    my $Token = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => "AccessToken::$Param{ProfileID}",
    );
    return 1 if $Token;

    my %TokenList = $Self->_TokenList(
        ProfileID => $Param{ProfileID},
    );
    return 1 if $TokenList{'refresh'};

    return;
}

=head2 RequestToken()

This can either be used to request an initial token or to request a refreshed token.

Example:
    my $Token = $Self->RequestToken(
        ProfileID => 123,
        TokenType => 'access_token',
        GrantType => 'refresh_token',
        Code      => $Code,    # Optional: Only needed in combination with GrantType "authorization_code".
    )

Returns:
    my $AccessToken = '...';

=cut

sub RequestToken {
    my ( $Self, %Param ) = @_;

### Code licensed under the GPL-3.0, Copyright (C) 2019-2024 Rother OSS GmbH, https://otobo.de/ ###
    # check needed stuff
    for (qw(ProfileID GrantType TokenType)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my %Profile = $Self->ProfileGet(
        ID => $Param{ProfileID},
    );
    return if !%Profile;

    # delete current token
    $Self->_TokenDelete(
        ProfileID => $Param{ProfileID},
        TokenType => $Param{TokenType},
    );

    # use provided redirect url or fallback to profile
    my $URLRedirect = $Param{URLRedirect} || $Profile{URLRedirect};

    # init data
    my %Data = (
        client_id     => $Profile{ClientID},
        client_secret => $Profile{ClientSecret},
        redirect_uri  => $URLRedirect,
        scope         => $Profile{Scope},
        grant_type    => $Param{GrantType},
    );

    # add optional parameters
    if (
        $Param{GrantType} eq 'authorization_code'
        && $Param{Code}
    ) {
        $Data{code} = $Param{Code};
    }
    elsif ( $Param{GrantType} eq 'refresh_token' ) {

        my %TokenList = $Self->_TokenList(
            ProfileID => $Param{ProfileID},
        );

        if ( !$TokenList{'refresh'} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No refresh token found for profile ($Param{ProfileID})!"
            );
            return;
        }

        $Data{refresh_token} = $TokenList{'refresh'};
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need GrantType authorization_code and the Code, or GrantType refresh_token!',
        );
        return;
    }

    my %Response = $Kernel::OM->Get('WebUserAgent')->Request(
        URL  => $Profile{URLToken},
        Type => 'POST',
        Data => \%Data,
    );

    # Server did not accept the request.
    if ( $Response{HTTPCode} != 200 ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Got: '$Response{Status}'! Expected status code 200.",
        );
        return;
    }

    my $ResponseData = $Kernel::OM->Get('JSON')->Decode(
        Data => ${ $Response{Content} }
    );

    if ( exists $ResponseData->{error} || exists $ResponseData->{error_description} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => $ResponseData->{error} . ': ' . $ResponseData->{error_description},
        );
        return;
    }

    # check for requested token
    if ( !$ResponseData->{ $Param{TokenType} } ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Host did not provide requested token!',
        );
        return;
    }

    # special handling for access_token
    if ( $Param{TokenType} eq 'access_token' ) {
        # check for refresh_token and expires_in
        if (
            !$ResponseData->{refresh_token}
            || !$ResponseData->{expires_in}
        ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Host did not provide "refresh_token" or "expires_in" for access_token!',
            );
            return;
        }

        # renew refresh token if necessary
        if (
            !$Data{refresh_token}
            || $Data{refresh_token} ne $ResponseData->{refresh_token}
        ) {
            return if !$Self->_TokenAdd(
                ProfileID => $Param{ProfileID},
                TokenType => 'refresh',
                Token     => $ResponseData->{refresh_token},
            );
        }
### EO Code licensed under the GPL-3.0, Copyright (C) 2019-2024 Rother OSS GmbH, https://otobo.de/ ###

        # Cache the access token until it expires - add a buffer (90 seconds) for latency reasons
        my $TTL = $ResponseData->{expires_in} ? ($ResponseData->{expires_in} - 90) : 0;
        if ($TTL > 0) {
            $Kernel::OM->Get('Cache')->Set(
                Type           => $Self->{CacheType},
                TTL            => $TTL,
                Key            => "AccessToken::$Param{ProfileID}",
                Value          => $ResponseData->{access_token},
                CacheInMemory  => 0,                                            # Cache in Backend only to enforce TTL
                CacheInBackend => 1,
                NoStatsUpdate  => 1
            );
        }

        if (
            $Param{GrantType} eq 'authorization_code'
            && $Param{Code}
        ) {
            # push client callback event
            $Kernel::OM->Get('ClientNotification')->NotifyClients(
                Event     => 'CREATE',
                Namespace => 'OAuth2ProfileAuth',
                ObjectID  => $Param{ProfileID},
            );
        }
        else {
            # push client callback event
            $Kernel::OM->Get('ClientNotification')->NotifyClients(
                Event     => 'UPDATE',
                Namespace => 'OAuth2ProfileAuth',
                ObjectID  => $Param{ProfileID},
            );
        }
    }

    return $ResponseData->{ $Param{TokenType} };
}

=begin Internal:

=cut
sub _TokenAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ProfileID TokenType Token)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get needed objects
    my $DBObject = $Kernel::OM->Get('DB');

    # delete old token
    return if !$DBObject->Do(
        SQL  => 'DELETE FROM oauth2_token WHERE profile_id = ? AND token_type = ?',
        Bind => [ \$Param{ProfileID}, \$Param{TokenType} ],
    );

    # insert new token
    return if !$DBObject->Do(
        SQL => 'INSERT INTO oauth2_token (profile_id, token_type, token, create_time) '
             . 'VALUES (?, ?, ?, current_timestamp)',
        Bind => [ \$Param{ProfileID}, \$Param{TokenType}, \$Param{Token} ],
    );

    return 1;
}

sub _TokenList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ProfileID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get needed objects
    my $DBObject = $Kernel::OM->Get('DB');

    # ask database
    return if !$DBObject->Prepare(
        SQL => 'SELECT token_type, token FROM oauth2_token WHERE profile_id = ?',
        Bind => [ \$Param{ProfileID} ]
    );

    # fetch the result
    my %TokenList;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $TokenList{ $Row[0] } = $Row[1];
    }

    return %TokenList;
}

sub _TokenDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ProfileID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get needed objects
    my $DBObject = $Kernel::OM->Get('DB');

    # init data
    my $SQL  = 'DELETE FROM oauth2_token WHERE profile_id = ?';
    my @Bind = ( \$Param{ProfileID} );

    # add token type if provided
    if ( $Param{TokenType} ) {
        $SQL .= ' AND token_type = ?';
        push( @Bind, \$Param{TokenType} );
    }

    # execute
    return if !$DBObject->Do(
        SQL   => $SQL,
        Bind  => \@Bind,
    );

    if (
        !$Param{TokenType}
        || $Param{TokenType} eq 'access_token'
    ) {
        # delete access token from cache
        $Kernel::OM->Get('Cache')->Delete(
            Type => $Self->{CacheType},
            Key  => "AccessToken::$Param{ProfileID}",
        );
    }

    return 1;
}
=end Internal:

=cut

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. This program is
licensed under the AGPL-3.0 with code licensed under the GPL-3.0.
For details, see the enclosed files LICENSE (AGPL) and
LICENSE-GPL3 (GPL3) for license information. If you did not receive
this files, see <https://www.gnu.org/licenses/agpl.txt> (APGL) and
<https://www.gnu.org/licenses/gpl-3.0.txt> (GPL3).

=cut
