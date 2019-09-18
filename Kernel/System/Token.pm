# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Token;

use strict;
use warnings;
use JSON;
use JSON::WebToken;

use Kernel::Language qw(Translatable);
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
    'Kernel::System::Main',
);

=head1 NAME

Kernel::System::Session - handling of user session tokens

=head1 SYNOPSIS

All session functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $TokenObject = $Kernel::OM->Get('Kernel::System::Token');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item ValidateToken()

validates a token, returns the payload (valid) or nothing (invalid)

    my $Result = $TokenObject->ValidateToken(
        Token => '1234567890123456',
    );

=cut

sub ValidateToken {
    my ( $Self, %Param ) = @_;

    # check session id
    if ( !$Param{Token} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Got no token!!'
        );
        return;
    }
    my $RemoteAddr = $ENV{REMOTE_ADDR} || 'none';

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # check whitelist
    $Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => "SELECT token, last_request_time FROM token WHERE token = ?",
        Bind => [ \$Param{Token} ],
    );

    my $TokenFound = 0;
    my $LastRequestTimeUnix;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        $TokenFound = $Row[0];

        if ( $Row[1] ) {
            $LastRequestTimeUnix = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
                String => $Row[1],
            );
        }
    }

    # nothing found, this token is invalid
    if ( !$TokenFound ) {
        return;
    }

    # decode token
    my $Payload = decode_jwt(
        $Param{Token}, 
        $ConfigObject->Get('TokenSecret') || '###KIX_TOKEN_SECRET!!!',
    );

    # unable to decode
    if ( !IsHashRefWithData($Payload) ) {
        return;
    }

    # remote ip check
    if (
        $ConfigObject->Get('TokenCheckRemoteIP') &&
        $Payload->{RemoteIP} ne '0.0.0.0' &&  
        $Payload->{RemoteIP} ne $RemoteAddr
        )
    {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => "RemoteIP ($Payload->{RemoteIP}) of request is "
                . "different from registered IP ($RemoteAddr). Invalidating token! "
                . "Disable config 'TokenCheckRemoteIP' if you don't want this!",
        );

        $Self->RemoveToken( Token => $Param{Token} );

        return;
    }

    # check time validity
    my $TimeNow = $Kernel::OM->Get('Kernel::System::Time')->SystemTime();

    if ( $TimeNow > $Payload->{ValidUntilTimeUnix} ) {

        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => "Token valid time exceeded!",
        );

        $Self->RemoveToken( Token => $Param{Token} );

        return;
    }

    # check idle time
    if ($LastRequestTimeUnix && !$Payload->{IgnoreMaxIdleTime}) {
        my $TokenMaxIdleTime = $ConfigObject->Get('TokenMaxIdleTime');

        if ( ( $TimeNow - $TokenMaxIdleTime ) >= $LastRequestTimeUnix ) {

            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message =>
                    "Token maximum idle time exceeded!",
            );

            $Self->RemoveToken( Token => $Param{Token} );

            return;
        }
    }

    # update last request time
    $TimeNow = $Kernel::OM->Get('Kernel::System::Time')->CurrentTimestamp();
    $Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => "UPDATE token SET last_request_time = ? WHERE token = ?",
        Bind =>  [
            \$TimeNow,
            \$Param{Token} 
        ],
    );
    
    return $Payload;
}

=item CreateToken()

create a new token with given data

    my $Token = $TokenObject->CreateToken(
        Payload => {
            UserType    => 'User' | 'Customer'     # required
            UserID      => '...'                   # required
            TokenType   => 'AccessToken',          # optional, used to create special AccessTokens
            ValidUntil  => 'YYYY-MM-YY HH24:MI:SS' # optional, used to create special AccessTokens
            RemoteIP    => '...'                   # optional, used to create special AccessTokens
            IgnoreMaxIdleTime => '...'             # optional, used to create special AccessTokens
            PermittedOperations => {}              # optional, used to create special AccessTokens
            DeniedOperations => {}                 # optional, used to create special AccessTokens                          
            Description => '...'                   # optional, used to create special AccessTokens
        }
    );

=cut

sub CreateToken {
    my ( $Self, %Param ) = @_;

    if ( !IsHashRefWithData($Param{Payload}) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Got no Payload!'
        );
        return;
    }

    if ( !$Param{Payload}->{UserType} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Got no UserType!'
        );
        return;
    }

    if ( $Param{Payload}->{UserType} ne 'Agent' && $Param{Payload}->{UserType} ne 'Customer' ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Got wrong UserType!'
        );
        return;
    }

    if ( !$Param{Payload}->{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Got no UserID!'
        );
        return;
    }

    # enrich payload and create token
    my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

    my $ValidUntilTimeUnix;
    if ( $Param{Payload}->{ValidUntil} ) {
        $ValidUntilTimeUnix = $TimeObject->TimeStamp2SystemTime(
            String => $Param{Payload}->{ValidUntil},
        );
    }

    if ( !$ValidUntilTimeUnix ) {
        $ValidUntilTimeUnix = $TimeObject->SystemTime() + $Kernel::OM->Get('Kernel::Config')->Get('TokenMaxTime');
    } 
    
    my %Payload = %{$Param{Payload}};
    my $CreateTimeString           = $TimeObject->CurrentTimestamp();
    $Payload{CreateTimeUnix}       = $TimeObject->SystemTime();
    $Payload{ValidUntilTimeUnix}   = $ValidUntilTimeUnix;
    $Payload{RemoteIP}             = $Param{Payload}->{RemoteIP} || $ENV{REMOTE_ADDR} || 'none';
    $Payload{IgnoreMaxIdleTime}    = ($Param{Payload}->{IgnoreMaxIdleTime} || 0) + 0;
    $Payload{Description}          = $Param{Payload}->{Description} || '';
    $Payload{TokenType}            = $Param{Payload}->{TokenType} || 'Normal';
    $Payload{AllowedOperations}    = $Param{Payload}->{AllowedOperations} || [];
    $Payload{DeniedOperations}     = $Param{Payload}->{DeniedOperations} || [];

    my $Token = encode_jwt(
        \%Payload, 
        $Kernel::OM->Get('Kernel::Config')->Get('TokenSecret') || '###KIX_TOKEN_SECRET!!!',
        'HS256', 
    );

    # store token in whitelist
    $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL  => "INSERT INTO token (token) values (?)",
        Bind => [
            \$Token,
        ],
    );

    return $Token;
}

=item RemoveToken()

removes a token and returns true (deleted), false (if
it can't get deleted)

    $TokenObject->RemoveToken(Token => '1234567890123456');

=cut

sub RemoveToken {
    my ( $Self, %Param ) = @_;

    # check session id
    if ( !$Param{Token} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Got no Token!!'
        );
        return;
    }

    # delete token from the database
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL  => "DELETE FROM token WHERE token = ?",
        Bind => [ \$Param{Token} ],
    );

    # log event
    $Kernel::OM->Get('Kernel::System::Log')->Log(
        Priority => 'notice',
        Message  => "Removed token $Param{Token}."
    );

    return 1;

}

=item ExtractToken()

returns the payload of a given token, adding LastRequestTime

    my $Payload = $TokenObject->ValidateToken(
        Token => '1234567890123456',
    );

=cut

sub ExtractToken {
    my ( $Self, %Param ) = @_;

    # check session id
    if ( !$Param{Token} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Got no token!!'
        );
        return;
    }
 
     # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get time of last request
    $Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => "SELECT token, last_request_time FROM token WHERE token = ?",
        Bind => [ \$Param{Token} ],
    );

    my $TokenFound = 0;
    my $LastRequestTimeUnix;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        $TokenFound = $Row[0];

        if ( $Row[1] ) {
            $LastRequestTimeUnix = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
                String => $Row[1],
            );
        }
    }

    if ( !$TokenFound ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => 'Token not found in database!'
        );
    }

    # decode token
    my $Payload = decode_jwt(
        $Param{Token}, 
        $ConfigObject->Get('TokenSecret') || '###KIX_TOKEN_SECRET!!!',
    );

    # unable to decode
    if ( !IsHashRefWithData($Payload) ) {
        return;
    }

    # enrich payload
    $Payload->{LastRequestTimeUnix} = $LastRequestTimeUnix || undef;
    $Payload->{LastRequestTime} = undef;
    if ( $LastRequestTimeUnix ) {
        $Payload->{LastRequestTime} = $Kernel::OM->Get('Kernel::System::Time')->SystemTime2TimeStamp(
            SystemTime => $LastRequestTimeUnix,
        );
    }
    $Payload->{CreateTime} = $Kernel::OM->Get('Kernel::System::Time')->SystemTime2TimeStamp(
        SystemTime => $Payload->{CreateTimeUnix},
    );
    $Payload->{ValidUntilTime} = $Kernel::OM->Get('Kernel::System::Time')->SystemTime2TimeStamp(
        SystemTime => $Payload->{ValidUntilTimeUnix},
    );

    return $Payload;
}

=item GetAllTokens()

returns a hashref with all tokens, key = Token, value = last request time

    my $Tokens = $TokenObject->GetAllTokens();

=cut

sub GetAllTokens {
    my ( $Self, %Param ) = @_;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # get all session ids from the database
    return if !$DBObject->Prepare(
        SQL => "SELECT token, last_request_time FROM token",
    );

    # fetch the result
    my %Tokens;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Tokens{$Row[0]} = $Row[1];
    }

    return \%Tokens;
}

=item CleanUp()

cleanup all tokens in system

    $TokensObject->CleanUp();

=cut

sub CleanUp {
    my ( $Self, %Param ) = @_;

    my %TokenList = $Self->GetAllTokens();

    foreach my $Token ( keys %TokenList ) {
        my $Payload = $Self->ExtractToken(
            Token => $Token,
        );
        if ( !IsHashRefWithData($Payload) ) {
            return;
        }

        # only remove normal tokens
        if ( $Payload->{TokenType} eq 'Normal' ) {
            $Self->RemoveToken(
                Token => $Token,
            );
        }
    }

    return 1;
}

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
