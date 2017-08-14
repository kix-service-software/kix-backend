# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::JWT;

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

Kernel::System::JWT - handoling of JSON Web Tokens

=head1 SYNOPSIS

All session functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $JWTObject = $Kernel::OM->Get('Kernel::System::JWT');

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

    my $Result = $JWTObject->ValidateToken(
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
        SQL => "SELECT token, last_request_time FROM jwt WHERE token = ?",
        Bind => [ \$Param{Token} ],
    );

    my $LastRequestTime;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        $LastRequestTime = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
            String => $Row[1],
        );
    }

    # nothing found
    if ( !$LastRequestTime ) {
        return;
    }

    # decode token
    my $Token = decode_jwt(
        $Param{Token}, 
        $ConfigObject->Get('JWTSecret') || 'KIX_JWT_SECRET!!!',
    );

    # unable to decode
    if ( !IsHashRefWithData($Token) ) {
        return;
    }

    # remote ip check
    if (
        $ConfigObject->Get('TokenCheckRemoteIP') && 
        $Token->{UserRemoteAddr} ne $RemoteAddr
        )
    {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => "RemoteIP ($Token->{UserRemoteAddr}) of request is "
                . "different from registered IP ($RemoteAddr). Invalidating token! "
                . "Disable config 'TokenCheckRemoteIP' if you don't want this!",
        );

        $Self->RemoveToken( Token => $Param{Token} );

        return;
    }

    # check time validity
    my $TimeNow = $Kernel::OM->Get('Kernel::System::Time')->SystemTime();

    if ( $TimeNow > $Token->{ValidUntil} ) {

        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => "Token valid time exceeded!",
        );

        $Self->RemoveToken( Token => $Param{Token} );

        return;
    }

    # check idle time
    my $TokenMaxIdleTime = $ConfigObject->Get('TokenMaxIdleTime');

    if ( ( $TimeNow - $TokenMaxIdleTime ) >= $LastRequestTime ) {

        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message =>
                "Token maximum idle time exceeded!",
        );

        $Self->RemoveToken( Token => $Param{Token} );

        return;
    }

    # update last request time
    $TimeNow = $Kernel::OM->Get('Kernel::System::Time')->CurrentTimestamp();
    $Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => "UPDATE jwt SET last_request_time = ? WHERE token = ?",
        Bind =>  [
            \$TimeNow,
            \$Param{Token} 
        ],
    );
    
    return $Token;
}

=item CreateToken()

create a new token with given data

    my $Token = $JWTObject->CreateToken(
        Payload => {
            UserType => 'User' | 'Customer'     # required
            UserID   => '...'                   # required
            ...
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
    
    my %Payload = %{$Param{Payload}};
    $Payload{CreateTime}    = $TimeObject->CurrentTimestamp();
    $Payload{ValidUntil}    = $TimeObject->SystemTime() + $Kernel::OM->Get('Kernel::Config')->Get('TokenMaxTime');
    $Payload{RemoteIP}      = $ENV{REMOTE_ADDR} || 'none';

    my $Token = encode_jwt(
        \%Payload, 
        $Kernel::OM->Get('Kernel::Config')->Get('JWTSecret') || 'KIX_JWT_SECRET!!!',
        'HS256', 
    );

    # store token in whitelist
    $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL  => "INSERT INTO jwt (token, last_request_time) values (?, ?)",
        Bind => [
            \$Token,
            \$Payload{CreateTime},
        ],
    );

    return $Token;
}

=item RemoveToken()

removes a token and returns true (deleted), false (if
it can't get deleted)

    $JWTObject->RemoveToken(Token => '1234567890123456');

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
        SQL  => "DELETE FROM jwt WHERE token = ?",
        Bind => [ \$Param{Token} ],
    );

    # log event
    $Kernel::OM->Get('Kernel::System::Log')->Log(
        Priority => 'notice',
        Message  => "Removed token $Param{Token}."
    );

    return 1;

}

=item GetAllTokens()

returns a hashref with all tokens, key = Token, value = last request time

    my $Tokens = $JWTObject->GetAllTokens();

=cut

sub GetAllTokens {
    my ( $Self, %Param ) = @_;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # get all session ids from the database
    return if !$DBObject->Prepare(
        SQL => "SELECT token, last_request_time FROM jwt",
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

    $JWTObject->CleanUp();

=cut

sub CleanUp {
    my ( $Self, %Param ) = @_;

    return if !$Kernel::OM->Get('Kernel::System::DB')->Do( 
        SQL => "DELETE FROM jwt"
    );

    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
