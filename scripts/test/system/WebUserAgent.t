# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

# include needed libs
use HTTP::Response;
use HTTP::Status qw(:constants status_message);

use vars (qw($Self));

use Kernel::System::WebUserAgent;

use Kernel::System::VariableCheck qw(:all);

my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my %UnitTestData = (
    Method      => 'GET',
    ContentType => undef,
    Content     => '',
    ProxyScheme => undef,
    ProxyHost   => undef,
    ProxyPort   => undef,
    Size        => undef,
    Timeout     => 15,
);

$Helper->HTTPRequestOverwriteSet(
    sub {
        my ( $Self, $Request, $Proxy, $Arguments, $Size, $Timeout ) = @_;

        # declare response
        my $Response;

        # get ContentType
        my $ContentType = $Request->header('Content-Type');

        # check Method
        if (
            DataIsDifferent(
                Data1 => $Request->method(),
                Data2 => $UnitTestData{Method},
            )
        ) {
            $Response = HTTP::Response->new(HTTP_INTERNAL_SERVER_ERROR, 'Unexpected RequestType ' . $Kernel::OM->Get('JSON')->Encode(
                Data => {
                    Actual  => $Request->method(),
                    Nominal => $UnitTestData{Method},
                },
                SortKeys => 1,
            ));
        }
        # check ContentType
        elsif (
            DataIsDifferent(
                Data1 => $ContentType,
                Data2 => $UnitTestData{ContentType},
            )
        ) {
            $Response = HTTP::Response->new(HTTP_INTERNAL_SERVER_ERROR, 'Unexpected ContentType ' . $Kernel::OM->Get('JSON')->Encode(
                Data => {
                    Actual  => $ContentType,
                    Nominal => $UnitTestData{ContentType},
                },
                SortKeys => 1,
            ));
        }
        # check Content
        elsif (
            DataIsDifferent(
                Data1 => $Request->content(),
                Data2 => $UnitTestData{Content},
            )
        ) {
            $Response = HTTP::Response->new(HTTP_INTERNAL_SERVER_ERROR, 'Unexpected Content ' . $Kernel::OM->Get('JSON')->Encode(
                Data => {
                    Actual  => $Request->content(),
                    Nominal => $UnitTestData{Content},
                },
                SortKeys => 1,
            ));
        }
        # check ProxyScheme
        elsif (
            DataIsDifferent(
                Data1 => defined( $Proxy ) ? $Proxy->scheme() : undef,
                Data2 => $UnitTestData{ProxyScheme},
            )
        ) {
            $Response = HTTP::Response->new(HTTP_INTERNAL_SERVER_ERROR, 'Unexpected ProxyScheme ' . $Kernel::OM->Get('JSON')->Encode(
                Data => {
                    Actual  => defined( $Proxy ) ? $Proxy->scheme() : undef,
                    Nominal => $UnitTestData{ProxyScheme},
                },
                SortKeys => 1,
            ));
        }
        # check ProxyHost
        elsif (
            DataIsDifferent(
                Data1 => defined( $Proxy ) ? $Proxy->host() : undef,
                Data2 => $UnitTestData{ProxyHost},
            )
        ) {
            $Response = HTTP::Response->new(HTTP_INTERNAL_SERVER_ERROR, 'Unexpected ProxyHost ' . $Kernel::OM->Get('JSON')->Encode(
                Data => {
                    Actual  => defined( $Proxy ) ? $Proxy->host() : undef,
                    Nominal => $UnitTestData{ProxyHost},
                },
                SortKeys => 1,
            ));
        }
        # check ProxyPort
        elsif (
            DataIsDifferent(
                Data1 => defined( $Proxy ) ? $Proxy->port() : undef,
                Data2 => $UnitTestData{ProxyPort},
            )
        ) {
            $Response = HTTP::Response->new(HTTP_INTERNAL_SERVER_ERROR, 'Unexpected ProxyPort ' . $Kernel::OM->Get('JSON')->Encode(
                Data => {
                    Actual  => defined( $Proxy ) ? $Proxy->port() : undef,
                    Nominal => $UnitTestData{ProxyPort},
                },
                SortKeys => 1,
            ));
        }
        # check Size
        elsif (
            DataIsDifferent(
                Data1 => $Size,
                Data2 => $UnitTestData{Size},
            )
        ) {
            $Response = HTTP::Response->new(HTTP_INTERNAL_SERVER_ERROR, 'Unexpected Size ' . $Kernel::OM->Get('JSON')->Encode(
                Data => {
                    Actual  => $Size,
                    Nominal => $UnitTestData{Size},
                },
                SortKeys => 1,
            ));
        }
        # check Timeout
        elsif (
            DataIsDifferent(
                Data1 => $Timeout,
                Data2 => $UnitTestData{Timeout},
            )
        ) {
            $Response = HTTP::Response->new(HTTP_INTERNAL_SERVER_ERROR, 'Unexpected Timeout ' . $Kernel::OM->Get('JSON')->Encode(
                Data => {
                    Actual  => $Timeout,
                    Nominal => $UnitTestData{Timeout},
                },
                SortKeys => 1,
            ));
        }
        # handle "http://unittest" and "https://unittest"
        elsif (
            $Request->uri()->eq('http://unittest')
            || $Request->uri()->eq('https://unittest')
        ) {
            $Response = HTTP::Response->new(HTTP_OK, status_message(HTTP_OK));
            $Response->header('Content-Type' => $Request->header('Content-Type'));
            $Response->content($Request->content());
        }
        # handle "http://unittest/CustomMessage/"
        elsif ( $Request->uri()->eq('http://unittest/CustomMessage/') ) {
            $Response = HTTP::Response->new(HTTP_OK, 'UnitTest');
            $Response->header('Content-Type' => 'text/plain');
            $Response->content('UnitTest');
        }
        # handle GET "https://unittest/HTTPBasicAuth/"
        elsif ( $Request->uri()->eq('https://unittest/HTTPBasicAuth/') ) {
            if (
                IsHashRefWithData( $Self->{ua}->{basic_authentication} )
                && IsHashRefWithData( $Self->{ua}->{basic_authentication}->{'unittest:443'} )
                && IsArrayRefWithData( $Self->{ua}->{basic_authentication}->{'unittest:443'}->{'UnitTest'} )
                && $Self->{ua}->{basic_authentication}->{'unittest:443'}->{'UnitTest'}->[0] eq 'unittest'
                && $Self->{ua}->{basic_authentication}->{'unittest:443'}->{'UnitTest'}->[1] eq 'unittest'
            ) {
                $Response = HTTP::Response->new(HTTP_OK, status_message(HTTP_OK));
                $Response->header('Content-Type' => 'text/plain');
                $Response->content('UnitTest');
            }
            else {
                $Response = HTTP::Response->new(HTTP_UNAUTHORIZED, status_message(HTTP_UNAUTHORIZED));
            }
        }
        # fallback with 404
        else {
            $Response = HTTP::Response->new(HTTP_NOT_FOUND, status_message(HTTP_NOT_FOUND));
        }

        return $Response;
    }
);

my @Tests = (
    {
        Name      => 'GET - empty url',
        Config    => {},
        UserAgent => {},
        Request   => {
            URL => '',
        },
        UnitTest  => {},
        Expected  => {
            Success  => 0,
            HTTPCode => 400,
            Status   => '400 URL missing',
        },
    },
    {
        Name        => 'GET - invalid url',
        Config    => {},
        UserAgent => {},
        UnitTest  => {},
        Request   => {
            URL => 'invalidurl',
        },
        Expected  => {
            Success  => 0,
            HTTPCode => 400,
            Status   => '400 URL must be absolute',
        },
    },
    {
        Name        => 'GET - http - changed proxy in constructor',
        Config    => {
            'WebUserAgent::Proxy'   => 'http://proxy.unittest',
            'WebUserAgent::Timeout' => undef,
        },
        UserAgent => {
            Proxy => 'http://proxy2.unittest',
        },
        Request   => {
            URL => 'http://unittest',
        },
        UnitTest  => {
            Method      => 'GET',
            ContentType => undef,
            Content     => '',
            ProxyScheme => 'http',
            ProxyHost   => 'proxy2.unittest',
            ProxyPort   => 80,
            Size        => undef,
            Timeout     => 15,
        },
        Expected  => {
            Success  => 1,
            HTTPCode => 200,
            Status   => '200 OK',
            Content  => '',
        },
    },
    {
        Name        => 'GET - http - changed proxy in request',
        Config    => {
            'WebUserAgent::Proxy'   => 'http://proxy.unittest',
            'WebUserAgent::Timeout' => undef,
        },
        UserAgent => {},
        Request   => {
            URL    => 'http://unittest',
            Proxy  => 'http://proxy2.unittest',
        },
        UnitTest  => {
            Method      => 'GET',
            ContentType => undef,
            Content     => '',
            ProxyScheme => 'http',
            ProxyHost   => 'proxy2.unittest',
            ProxyPort   => 80,
            Size        => undef,
            Timeout     => 15,
        },
        Expected  => {
            Success  => 1,
            HTTPCode => 200,
            Status   => '200 OK',
            Content  => '',
        },
    },
    {
        Name        => 'GET - http - changed proxy including port in request',
        Config    => {
            'WebUserAgent::Proxy'   => 'http://proxy.unittest',
            'WebUserAgent::Timeout' => undef,
        },
        UserAgent => {},
        Request   => {
            URL    => 'http://unittest',
            Proxy  => 'http://proxy2.unittest:3128',
        },
        UnitTest  => {
            Method      => 'GET',
            ContentType => undef,
            Content     => '',
            ProxyScheme => 'http',
            ProxyHost   => 'proxy2.unittest',
            ProxyPort   => 3128,
            Size        => undef,
            Timeout     => 15,
        },
        Expected  => {
            Success  => 1,
            HTTPCode => 200,
            Status   => '200 OK',
            Content  => '',
        },
    },
    {
        Name        => 'GET - http - changed proxy with https in request',
        Config    => {
            'WebUserAgent::Proxy'   => 'http://proxy.unittest',
            'WebUserAgent::Timeout' => undef,
        },
        UserAgent => {},
        Request   => {
            URL    => 'http://unittest',
            Proxy  => 'https://proxy2.unittest',
        },
        UnitTest  => {
            Method      => 'GET',
            ContentType => undef,
            Content     => '',
            ProxyScheme => 'https',
            ProxyHost   => 'proxy2.unittest',
            ProxyPort   => 443,
            Size        => undef,
            Timeout     => 15,
        },
        Expected  => {
            Success  => 1,
            HTTPCode => 200,
            Status   => '200 OK',
            Content  => '',
        },
    },
    {
        Name        => 'GET - http - do not send proxy in request',
        Config    => {
            'WebUserAgent::Proxy'   => 'http://proxy.unittest',
            'WebUserAgent::Timeout' => undef,
        },
        UserAgent => {},
        Request   => {
            URL      => 'http://unittest',
            UseProxy => 0,
        },
        UnitTest  => {
            Method      => 'GET',
            ContentType => undef,
            Content     => '',
            ProxyScheme => undef,
            ProxyHost   => undef,
            ProxyPort   => undef,
            Size        => undef,
            Timeout     => 15,
        },
        Expected  => {
            Success  => 1,
            HTTPCode => 200,
            Status   => '200 OK',
            Content  => '',
        },
    },
    {
        Name        => 'GET - http - use config proxy',
        Config    => {
            'WebUserAgent::Proxy'   => 'http://proxy.unittest',
            'WebUserAgent::Timeout' => undef,
        },
        UserAgent => {},
        Request   => {
            URL => 'http://unittest',
        },
        UnitTest  => {
            Method      => 'GET',
            ContentType => undef,
            Content     => '',
            ProxyScheme => 'http',
            ProxyHost   => 'proxy.unittest',
            ProxyPort   => 80,
            Size        => undef,
            Timeout     => 15,
        },
        Expected  => {
            Success  => 1,
            HTTPCode => 200,
            Status   => '200 OK',
            Content  => '',
        },
    },
    {
        Name        => 'GET - http - changed timeout in constructor',
        Config    => {
            'WebUserAgent::Proxy'   => undef,
            'WebUserAgent::Timeout' => 20,
        },
        UserAgent => {
            Timeout => 10,
        },
        Request   => {
            URL => 'http://unittest',
        },
        UnitTest  => {
            Method      => 'GET',
            ContentType => undef,
            Content     => '',
            ProxyScheme => undef,
            ProxyHost   => undef,
            ProxyPort   => undef,
            Size        => undef,
            Timeout     => 10,
        },
        Expected  => {
            Success  => 1,
            HTTPCode => 200,
            Status   => '200 OK',
            Content  => '',
        },
    },
    {
        Name      => 'GET - http - use config timeout',
        Config    => {
            'WebUserAgent::Proxy'   => undef,
            'WebUserAgent::Timeout' => 20,
        },
        UserAgent => {},
        Request   => {
            URL => 'http://unittest',
        },
        UnitTest  => {
            Method      => 'GET',
            ContentType => undef,
            Content     => '',
            ProxyScheme => undef,
            ProxyHost   => undef,
            ProxyPort   => undef,
            Size        => undef,
            Timeout     => 20,
        },
        Expected  => {
            Success  => 1,
            HTTPCode => 200,
            Status   => '200 OK',
            Content  => '',
        },
    },
    {
        Name      => 'GET - http - check default timeout',
        Config    => {
            'WebUserAgent::Proxy'   => undef,
            'WebUserAgent::Timeout' => undef,
        },
        UserAgent => {},
        Request   => {
            URL => 'http://unittest',
        },
        UnitTest  => {
            Method      => 'GET',
            ContentType => undef,
            Content     => '',
            ProxyScheme => undef,
            ProxyHost   => undef,
            ProxyPort   => undef,
            Size        => undef,
            Timeout     => 15,
        },
        Expected  => {
            Success  => 1,
            HTTPCode => 200,
            Status   => '200 OK',
            Content  => '',
        },
    },
    {
        Name    => 'GET - http - check default request',
        Config    => {
            'WebUserAgent::Proxy'   => undef,
            'WebUserAgent::Timeout' => undef,
        },
        UserAgent => {},
        Request   => {
            URL => 'http://unittest',
        },
        UnitTest  => {
            Method      => 'GET',
            ContentType => undef,
            Content     => '',
            ProxyScheme => undef,
            ProxyHost   => undef,
            ProxyPort   => undef,
            Size        => undef,
            Timeout     => 15,
        },
        Expected  => {
            Success  => 1,
            HTTPCode => 200,
            Status   => '200 OK',
            Content  => '',
        },
    },
    {
        Name    => 'GET - http - custom response status message',
        Config    => {
            'WebUserAgent::Proxy'   => undef,
            'WebUserAgent::Timeout' => undef,
        },
        UserAgent => {},
        Request   => {
            URL => 'http://unittest/CustomMessage/',
        },
        UnitTest  => {
            Method      => 'GET',
            ContentType => undef,
            Content     => '',
            ProxyScheme => undef,
            ProxyHost   => undef,
            ProxyPort   => undef,
            Size        => undef,
            Timeout     => 15,
        },
        Expected  => {
            Success  => 1,
            HTTPCode => 200,
            Status   => '200 UnitTest',
            Content  => 'UnitTest',
        },
    },
    {
        Name    => 'GET - https - check default request',
        Config    => {
            'WebUserAgent::Proxy'   => undef,
            'WebUserAgent::Timeout' => undef,
        },
        UserAgent => {},
        Request   => {
            URL => 'https://unittest',
        },
        UnitTest  => {
            Method      => 'GET',
            ContentType => undef,
            Content     => '',
            ProxyScheme => undef,
            ProxyHost   => undef,
            ProxyPort   => undef,
            Size        => undef,
            Timeout     => 15,
        },
        Expected  => {
            Success  => 1,
            HTTPCode => 200,
            Status   => '200 OK',
            Content  => '',
        },
    },
    {
        Name    => 'GET - http - request with Header',
        Config    => {
            'WebUserAgent::Proxy'   => undef,
            'WebUserAgent::Timeout' => undef,
        },
        UserAgent => {},
        Request   => {
            URL    => 'https://unittest',
            Header => {
                Content_Type => 'text/json',
            },
        },
        UnitTest  => {
            Method      => 'GET',
            ContentType => 'text/json',
            Content     => '',
            ProxyScheme => undef,
            ProxyHost   => undef,
            ProxyPort   => undef,
            Size        => undef,
            Timeout     => 15,
        },
        Expected  => {
            Success  => 1,
            HTTPCode => 200,
            Status   => '200 OK',
            Content  => '',
        },
    },
    {
        Name    => 'GET - http - request with Credentials',
        Config    => {
            'WebUserAgent::Proxy'   => undef,
            'WebUserAgent::Timeout' => undef,
        },
        UserAgent => {},
        Request   => {
            URL         => 'https://unittest/HTTPBasicAuth/',
            Credentials => {
                User     => 'unittest',
                Password => 'unittest',
                Realm    => 'UnitTest',
                Location => 'unittest:443',
            },
        },
        UnitTest  => {
            Method      => 'GET',
            ContentType => undef,
            Content     => '',
            ProxyScheme => undef,
            ProxyHost   => undef,
            ProxyPort   => undef,
            Size        => undef,
            Timeout     => 15,
        },
        Expected  => {
            Success  => 1,
            HTTPCode => 200,
            Status   => '200 OK',
            Content  => 'UnitTest',
        },
    },
    {
        Name    => 'POST - http - request with Data and Header',
        Config    => {
            'WebUserAgent::Proxy'   => undef,
            'WebUserAgent::Timeout' => undef,
        },
        UserAgent => {},
        Request   => {
            Type   => 'POST',
            URL    => 'https://unittest',
            Header => {
                Content_Type => 'text/json',
            },
            Data   => {
                'Test' => 'UnitTest',
            }
        },
        UnitTest  => {
            Method      => 'POST',
            ContentType => 'application/x-www-form-urlencoded',
            Content     => "Test=UnitTest",
            ProxyScheme => undef,
            ProxyHost   => undef,
            ProxyPort   => undef,
            Size        => undef,
            Timeout     => 15,
        },
        Expected  => {
            Success  => 1,
            HTTPCode => 200,
            Status   => '200 OK',
            Content  => "Test=UnitTest",
        },
    },
);

TEST:
for my $Test ( @Tests ) {
    # prepare config
    for my $ConfigKey ( keys ( %{ $Test->{Config} } ) ) {
        $Helper->ConfigSettingChange(
            Key   => $ConfigKey,
            Value => $Test->{Config}->{ $ConfigKey }
        );
    }

    # prepare unittest data
    %UnitTestData = %{ $Test->{UnitTest} };

    # build WebUserAgent
    my $WebUserAgentObject = Kernel::System::WebUserAgent->new(
        %{ $Test->{UserAgent} },
    );
    $Self->Is(
        ref( $WebUserAgentObject ),
        'Kernel::System::WebUserAgent',
        "$Test->{Name} - WebUserAgent object creation",
    );

    my %Response = $WebUserAgentObject->Request(
        %{ $Test->{Request} },
        Silent => !$Test->{Expected}->{Success}
    );
    $Self->True(
        IsHashRefWithData( \%Response ),
        "$Test->{Name} - WebUserAgent check structure from request",
    );

    $Self->Is(
        $Response{Success},
        $Test->{Expected}->{Success},
        "$Test->{Name} - Check success state",
    );

    $Self->Is(
        $Response{Status},
        $Test->{Expected}->{Status},
        "$Test->{Name} - Check Status",
    );

    $Self->Is(
        $Response{HTTPCode},
        $Test->{Expected}->{HTTPCode},
        "$Test->{Name} - Check HTTPCode",
    );

    $Self->Is(
        ${$Response{Content}},
        $Test->{Expected}->{Content},
        "$Test->{Name} - Check Content",
    );
}

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
