# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::WebUserAgent;

use strict;
use warnings;

use HTTP::Headers;
use List::Util qw(first);
use LWP::UserAgent;
use IO::Socket::SSL qw( SSL_VERIFY_NONE );

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'Encode',
    'Log',
    'Main',
);

=head1 NAME

Kernel::System::WebUserAgent - a web user agent lib

=head1 SYNOPSIS

All web user agent functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::System::WebUserAgent;

    my $WebUserAgentObject = Kernel::System::WebUserAgent->new(
        Timeout => 15,                  # optional, timeout
        Proxy   => 'proxy.example.com', # optional, proxy
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get database object
    my $ConfigObject = $Kernel::OM->Get('Config');

    $Self->{Timeout} = $Param{Timeout} || $ConfigObject->Get('WebUserAgent::Timeout') || 15;
    $Self->{Proxy}   = $Param{Proxy}   || $ConfigObject->Get('WebUserAgent::Proxy')   || '';

    return $Self;
}

=item Request()

return the content of requested URL.

Simple GET request:

    my %Response = $WebUserAgentObject->Request(
        URL => 'http://example.com/somedata.xml',
        SkipSSLVerification => 1, # (optional)
    );

Or a POST request; attributes can be a hashref like this:

    my %Response = $WebUserAgentObject->Request(
        URL  => 'http://example.com/someurl',
        Type => 'POST',
        Data => { Attribute1 => 'Value', Attribute2 => 'Value2' },
        SkipSSLVerification => 1, # (optional)
    );

alternatively, you can use an arrayref like this:

    my %Response = $WebUserAgentObject->Request(
        URL  => 'http://example.com/someurl',
        Type => 'POST',
        Data => [ Attribute => 'Value', Attribute => 'OtherValue' ],
        SkipSSLVerification => 1, # (optional)
    );

returns

    %Response = (
        Success => 1,           # 1 or 0
        Status  => '200 OK',    # http status
        Content => $ContentRef, # content of requested URL
    );

You can even pass some headers

    my %Response = $WebUserAgentObject->Request(
        URL    => 'http://example.com/someurl',
        Type   => 'POST',
        Data   => [ Attribute => 'Value', Attribute => 'OtherValue' ],
        Header => {
            Authorization => 'Basic xxxx',
            Content_Type  => 'text/json',
        },
        SkipSSLVerification => 1, # (optional)
    );

If you need to set credentials

    my %Response = $WebUserAgentObject->Request(
        URL          => 'http://example.com/someurl',
        Type         => 'POST',
        Data         => [ Attribute => 'Value', Attribute => 'OtherValue' ],
        Credentials  => {
            User     => 'kix_user',
            Password => 'kix_password',
            Realm    => 'KIX Unittests',
            Location => 'www.kixdesk.com:80',
        },
        SkipSSLVerification => 1, # (optional)
    );

If you need to use a specific proxy (this overrides the global config):

    my %Response = $WebUserAgentObject->Request(
        URL      => 'http://example.com/somedata.xml',
        Proxy    => 'proxy.example.com:3128',
        UseProxy => 1                                   # (0|1). Defaults to 1 if undefined. 0 ignores proxy settings
    );

=cut

sub Request {
    my ( $Self, %Param ) = @_;

    # define method - default to GET
    $Param{Type} ||= 'GET';

    my $Response;

    # init agent
    my $UserAgent = LWP::UserAgent->new();

    # In some scenarios like transparent HTTPS proxies, it can be neccessary to turn off
    #   SSL certificate validation.
    if (
        $Param{SkipSSLVerification}
        || $Kernel::OM->Get('Config')->Get('WebUserAgent::DisableSSLVerification')
        )
    {
        $UserAgent->ssl_opts(
            verify_hostname => 0,
            SSL_verify_mode => SSL_VERIFY_NONE,
        );
    }

    # set credentials
    if ( $Param{Credentials} ) {
        my %CredentialParams    = %{ $Param{Credentials} || {} };
        my @Keys                = qw(Location Realm User Password);
        my $AllCredentialParams = !first { !defined $_ } @CredentialParams{@Keys};

        if ($AllCredentialParams) {
            $UserAgent->credentials(
                @CredentialParams{@Keys},
            );
        }
    }

    # set headers
    if ( $Param{Header} ) {
        $UserAgent->default_headers(
            HTTP::Headers->new( %{ $Param{Header} } ),
        );
    }

    # set timeout
    $UserAgent->timeout( $Self->{Timeout} );

    # get database object
    my $ConfigObject = $Kernel::OM->Get('Config');

    # set user agent
    $UserAgent->agent(
        $ConfigObject->Get('Product') . ' ' . $ConfigObject->Get('Version')
    );

    # set UseProxy to 1 if undefined
    $Param{UseProxy} //= 1;

    # set proxy if required
    if (
        $Param{UseProxy}
        && (
            $Param{Proxy}
            || $Self->{Proxy}
        )
    ) {
        $UserAgent->proxy( [ 'http', 'https', 'ftp' ], ( $Param{Proxy} || $Self->{Proxy} ) );
    }

    if ( $Param{Type} eq 'GET' ) {

        # perform get request on URL
        $Response = $UserAgent->get( $Param{URL} );
    }

    else {

        # check for Data param
        if (
            !IsArrayRefWithData( $Param{Data} )
            && !IsHashRefWithData( $Param{Data} )
        ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => 'WebUserAgent POST: Need Data param containing a hashref or arrayref with data.',
                );
            }
            return ( Status => 0 );
        }

        # perform post request plus data
        $Response = $UserAgent->post( $Param{URL}, $Param{Data} );
    }

    if ( !$Response->is_success() ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Can't perform $Param{Type} on $Param{URL}: " . $Response->status_line(),
            );
        }
        return (
            Success => 0,
            Status  => $Response->status_line(),
        );
    }

    # get the content to convert internal used charset
    my $ResponseContent = $Response->decoded_content();
    $Kernel::OM->Get('Encode')->EncodeInput( \$ResponseContent );

    if ( $Param{Return} && $Param{Return} eq 'REQUEST' ) {
        return (
            Success => 1,
            Status  => $Response->status_line(),
            Content => \$Response->request()->as_string(),
        );
    }

    # return request
    return (
        Success => 1,
        Status  => $Response->status_line(),
        Content => \$ResponseContent,
    );
}

1;





=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
