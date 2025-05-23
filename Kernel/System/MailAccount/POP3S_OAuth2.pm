# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# based on the original work of:
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# Copyright (C) 2019–2021 Efflux GmbH, https://efflux.de/
# Copyright (C) 2019-2021 Rother OSS GmbH, https://otobo.de/
# --
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later version.
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
# --

package Kernel::System::MailAccount::POP3S_OAuth2;

use strict;
use warnings;

use IO::Socket::SSL qw( SSL_VERIFY_NONE SSL_VERIFY_PEER );
use Net::POP3;
use MIME::Base64;

use parent qw(Kernel::System::MailAccount::POP3);

our @ObjectDependencies = (
    'Log',
    'OAuth2',
);

# Use Net::SSLGlue::POP3 on systems with older Net::POP3 modules that do not provide starttls
BEGIN {
    if ( !defined &Net::POP3::starttls ) {
        require Net::SSLGlue::POP3;
    }
}

sub Connect {
    my ( $Self, %Param ) = @_;

    my $Type = 'POP3S_OAuth2';

    # check needed stuff
    for (qw(OAuth2_ProfileID Login Password Host Timeout Debug)) {
        if ( !defined $Param{$_} ) {
            return (
                Successful => 0,
                Message    => $Type . ': Need ' . $_ . '!',
            );
        }
    }

    # get access token
    my $AccessToken = $Kernel::OM->Get('OAuth2')->GetAccessToken(
        ProfileID => $Param{OAuth2_ProfileID},
    );
    if ( !$AccessToken ) {
        return (
            Successful => 0,
            Message    => $Type . ': Could not request access token for ' . $Param{Login} . '/' . $Param{Host} . '. The refresh token could be expired or invalid.'
        );
    }

    # connect to host
    my $PopObject = Net::POP3->new(
        $Param{Host},
        Timeout         => $Param{Timeout},
        Debug           => $Param{Debug},
        SSL             => 1,
        SSL_verify_mode => $Param{SSLVerify} ? SSL_VERIFY_PEER : SSL_VERIFY_NONE,
    );

    if ( !$PopObject ) {
        return (
            Successful => 0,
            Message    => $Type . ': Could not connect to ' . $Param{Host} . ': ' . $! . '!'
        );
    }

    # try it 2 times to authenticate with the POP3 server
    my $NOM;
    TRY:
    for my $Try ( 1 .. 2 ) {
        # auth via SASL XOAUTH2
        my $SASLXOAUTH2 = encode_base64( 'user=' . $Param{Login} . "\x01auth=Bearer " . $AccessToken . "\x01\x01" );
        $PopObject->command( 'AUTH', 'XOAUTH2' )->response();
        $NOM = $PopObject->command($SASLXOAUTH2)->response();

        last TRY if ( defined $NOM );

        # sleep 0,3 seconds;
        sleep( 0.3 );

        # get a new access token
        $AccessToken = $Kernel::OM->Get('OAuth2')->RequestToken(
            ProfileID => $Param{OAuth2_ProfileID},
            TokenType => 'access_token',
            GrantType => 'refresh_token'
        );
        if ( !$AccessToken ) {
            $PopObject->quit();
            return (
                Successful => 0,
                Message    => $Type . ': Could not request access token for ' . $Param{Login} . '/' . $Param{Host} . '. The refresh token could be expired or invalid.'
            );
        }
    }

    if ( !defined $NOM ) {
        $PopObject->quit();
        return (
            Successful => 0,
            Message    => $Type . ': Auth for user ' . $Param{Login} . '/' . $Param{Host} . ' failed!'
        );
    }

    return (
        Successful => 1,
        PopObject  => $PopObject,
        NOM        => $NOM,
        Type       => $Type,
    );
}

1;
