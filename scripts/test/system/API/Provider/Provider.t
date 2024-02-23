# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use CGI;
use LWP::UserAgent;

# get config object
my $ConfigObject = $Kernel::OM->Get('Config');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# skip SSL certificate verification
$Helper->SSLVerify(
    SkipSSLVerify => 1,
);

my $RandomID = $Helper->GetRandomID();

my @Tests = (
    {
        Name             => 'HTTP request',
        WebserviceConfig => {
            Debugger => {
                DebugThreshold => 'debug',
            },
            Provider => {
                Operation => {
                    'Test::User::UserSearch' => {
                        Description           => '',
                        NoAuthorizationNeeded => 1,
                        Type                  => 'V1::Sessions::SessionCreate',
                    },
                },
                Transport => {
                    Config => {
                        KeepAlive             => '',
                        MaxLength             => '52428800',
                        RouteOperationMapping => {
                            'Test::User::UserSearch' => {
                                RequestMethod => [
                                    'GET',
                                    'POST'
                                ],
                                Route => '/Test'
                            }
                        }
                    },
                },
            },
        },
        RequestData => {
            UserLogin => 'admin',
            UserType  => 'Agent',
            Password  => 'Passw0rd'
        },
        ResponseStatus => 'Status: 201 Created',
    },
    {
        Name             => 'HTTP request umlaut',
        WebserviceConfig => {
            Debugger => {
                DebugThreshold => 'debug',
            },
            Provider => {
                Operation => {
                    'Test::User::UserSearch' => {
                        Description           => '',
                        NoAuthorizationNeeded => 1,
                        Type                  => 'V1::Sessions::SessionCreate',
                    },
                },
                Transport => {
                    Config => {
                        KeepAlive             => '',
                        MaxLength             => '52428800',
                        RouteOperationMapping => {
                            'Test::User::UserSearch' => {
                                RequestMethod => [
                                    'GET',
                                    'POST'
                                ],
                                Route => '/Test'
                            }
                        }
                    },
                },
            },
        },
        RequestData => {
            UserLogin => 'admin',
            UserType  => 'Agent',
            Password  => 'ÄÖÜßäöü'
        },
        ResponseStatus => 'Status: 401 Unauthorized',
    },
    {
        Name             => 'HTTP request Unicode',
        WebserviceConfig => {
            Debugger => {
                DebugThreshold => 'debug',
            },
            Provider => {
                Operation => {
                    'Test::User::UserSearch' => {
                        Description           => '',
                        NoAuthorizationNeeded => 1,
                        Type                  => 'V1::Sessions::SessionCreate',
                    },
                },
                Transport => {
                    Config => {
                        KeepAlive             => '',
                        MaxLength             => '52428800',
                        RouteOperationMapping => {
                            'Test::User::UserSearch' => {
                                RequestMethod => [
                                    'GET',
                                    'POST'
                                ],
                                Route => '/Test'
                            }
                        }
                    },
                },
            },
        },
        RequestData => {
            UserLogin => 'Языковые',
            UserType  => 'Agent',
            Password  => '使用下列语言'
        },
        ResponseStatus => 'Status: 401 Unauthorized',
    },
    {
        Name             => 'HTTP request without data',
        WebserviceConfig => {
            Debugger => {
                DebugThreshold => 'debug',
            },
            Provider => {
                Operation => {
                    'Test::User::UserSearch' => {
                        Description           => '',
                        NoAuthorizationNeeded => 1,
                        Type                  => 'V1::Sessions::SessionCreate',
                    },
                },
                Transport => {
                    Config => {
                        KeepAlive             => '',
                        MaxLength             => '52428800',
                        RouteOperationMapping => {
                            'Test::User::UserSearch' => {
                                RequestMethod => [
                                    'GET',
                                    'POST'
                                ],
                                Route => '/Test'
                            }
                        }
                    },
                },
            },
        },
        RequestData    => {},
        ResponseStatus => 'Status: 400 Bad Request',
    },
    {
        Name            => 'Test non existing webservice',
        RequestData    => {},
        ResponseStatus => '',
        Silent         => 1,
    },
);

my $CreateQueryString = sub {
    my ( $Self, %Param ) = @_;

    my $QueryString;

    for my $Key ( sort keys %{ $Param{Data} || {} } ) {
        $QueryString .= '&' if ($QueryString);
        $QueryString .= $Param{Encode} ? URI::Escape::uri_escape_utf8($Key) : $Key;
        if ( $Param{Data}->{$Key} ) {
            $QueryString
                .= "="
                . (
                $Param{Encode}
                ? URI::Escape::uri_escape_utf8( $Param{Data}->{$Key} )
                : $Param{Data}->{$Key}
                );
        }
    }

    $Kernel::OM->Get('Encode')->EncodeOutput( \$QueryString );
    return $QueryString;
};

# get remote host with some precautions for certain unit test systems
my $Host = $Helper->GetTestHTTPHostname();

# create URL
my $ApacheBaseURL = "http://$Host/";
my $PlackBaseURL;
if ( $ConfigObject->Get('UnitTestPlackServerPort') ) {
    $PlackBaseURL = "http://localhost:"
        . $ConfigObject->Get('UnitTestPlackServerPort')
        . '/';
}

# get objects
my $WebserviceObject = $Kernel::OM->Get('Webservice');
my $ProviderObject   = $Kernel::OM->Get('API::Provider');

for my $Test (@Tests) {

    my $WebserviceID;
    if ( $Test->{WebserviceConfig} ) {
        # add config
        $WebserviceID = $WebserviceObject->WebserviceAdd(
            Config  => $Test->{WebserviceConfig},
            Name    => "$Test->{Name} $RandomID",
            ValidID => 1,
            UserID  => 1,
        );

        $Self->True(
            $WebserviceID,
            "$Test->{Name} WebserviceAdd()",
        );
    }

    my $WebserviceNameEncoded = URI::Escape::uri_escape_utf8("$Test->{Name} $RandomID");

    #
    # Test with IO redirection, no real HTTP request
    #
    for my $RequestMethod (qw(get post)) {

        my $RequestData  = '';
        my $ResponseData = '';

        {
            local %ENV;

            if ( $RequestMethod eq 'post' ) {
                # prepare CGI environment variables
                $ENV{REQUEST_URI}    = "localhost/Webservice/$WebserviceNameEncoded/Test";
                $ENV{REQUEST_METHOD} = 'POST';
                $RequestData         = $Kernel::OM->Get('JSON')->Encode(
                    Data => $Test->{RequestData}
                );
                $Kernel::OM->Get('Encode')->EncodeOutput( \$RequestData );
                use bytes;
                $ENV{CONTENT_LENGTH} = length($RequestData);
                $ENV{CONTENT_TYPE} = 'application/json; charset=utf-8;';
            }
            else {    # GET
                # prepare CGI environment variables
                $ENV{REQUEST_URI} = "localhost/Webservice/$WebserviceNameEncoded/Test?" . $CreateQueryString->(
                    $Self,
                    Data   => $Test->{RequestData},
                    Encode => 1,
                );
                $ENV{QUERY_STRING} = $CreateQueryString->(
                    $Self,
                    Data   => $Test->{RequestData},
                    Encode => 1,
                );
                $ENV{REQUEST_METHOD} = 'GET';
                $ENV{CONTENT_TYPE} = 'application/x-www-form-urlencoded; charset=utf-8;';
            }


            # redirect STDIN from String so that the transport layer will use this data
            local *STDIN;
            open STDIN, '<:utf8', \$RequestData;

            # redirect STDOUT from String so that the transport layer will write there
            local *STDOUT;
            open STDOUT, '>:utf8', \$ResponseData;

            # reset CGI object from previous runs
            CGI::initialize_globals();
            $Kernel::OM->ObjectsDiscard( Objects => ['WebRequest'] );

            $ProviderObject->Run(
                Silent => $Test->{Silent},
            );
        }

        $Self->True(
            index( $ResponseData, $Test->{ResponseStatus} ) > -1,
            "$Test->{Name} Webservice/$WebserviceNameEncoded Run() HTTP $RequestMethod result status is '$Test->{ResponseStatus}'",
        );
    }

    if ( $Test->{WebserviceConfig} ) {
        # delete webservice
        my $Success = $WebserviceObject->WebserviceDelete(
            ID     => $WebserviceID,
            UserID => 1,
        );

        $Self->True(
            $Success,
            "$Test->{Name} WebserviceDelete()",
        );
    }
}

# rollback transaction on database
$Helper->Rollback();

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
