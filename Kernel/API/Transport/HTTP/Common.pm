# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Transport::HTTP::Common;

use strict;
use warnings;

use Kernel::Config;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Transport::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Transport::HTTP::Common - Base class for all HTTP transports

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item ProviderCheckAuthorization()

Checks the incoming web service request for authorization header and validates token.

The HTTP code is set accordingly
- 403 unauthorized
- 500 if no authorization header is given

    my $Result = $TransportObject->ProviderCheckAuthorization();

    $Result = {
        Success      => 1,   # 0 or 1
        HTTPError    => ...
        ErrorMessage => '',  # in case of error
    };

=cut

sub ProviderCheckAuthorization {
    my ( $Self, %Param ) = @_;

    # check authentication header
    my $cgi = CGI->new;
    my %Headers = map { $_ => $cgi->http($_) } $cgi->http();
        
    if ( !$Headers{HTTP_AUTHORIZATION} ) {
        return $Self->_Error(
            Code => 'Authorization.NoHeader'
        );
    }

    my %Authorization = split(/\s+/, $Headers{HTTP_AUTHORIZATION});

    if ( !$Authorization{Token} ) {
        return $Self->_Error(
            Code => 'Authorization.NoToken'
        );
    }

    my $ValidatedToken = $Kernel::OM->Get('Token')->ValidateToken(
        Token => $Authorization{Token},
    );

    if ( !IsHashRefWithData($ValidatedToken) ) {
        return $Self->_Error(
            Code => 'Unauthorized'
        );
    }

    return $Self->_Success(
        Data    => {
            Authorization => {
                Token => $Authorization{Token},
                %{$ValidatedToken},
            }
        }
    );    
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
