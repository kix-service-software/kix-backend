# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Provider::REST;

use strict;
use warnings;

use CGI;
use HTTP::Status;
use URI::Escape;
use Time::HiRes qw(time);

use Kernel::Config;
use Kernel::System::VariableCheck qw(:all);
use Kernel::System::PerfLog qw(TimeDiff);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Provider::REST - API network transport interface for HTTP::REST

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item CheckAuthorization()

Checks the incoming web service request for authorization header and validates token.

The HTTP code is set accordingly
- 403 unauthorized
- 500 if no authorization header is given

    my $Result = $ProviderObject->CheckAuthorization();

    $Result = {
        Success      => 1,   # 0 or 1
        HTTPError    => ...
        ErrorMessage => '',  # in case of error
    };

=cut

sub CheckAuthorization {
    my ( $Self, %Param ) = @_;

    # check authentication header
    if ( !$ENV{HTTP_AUTHORIZATION} ) {
        return $Self->_Error(
            Code => 'Authorization.NoHeader'
        );
    }

    my %Authorization = split(/\s+/, $ENV{HTTP_AUTHORIZATION});

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

=item ProcessRequest()

Process an incoming web service request. This function has to read the request data
from from the web server process.

Based on the request the Operation to be used is determined.

No outbound communication is done here, except from continue requests.

In case of an error, the resulting http error code and message are remembered for the response.

    my $Result = $ProviderObject->ProcessRequest();

    $Result = {
        Success      => 1,                  # 0 or 1
        Code         => '',                 # in case of error
        Message      => '',                 # in case of error
        Operation    => 'DesiredOperation', # name of the operation to perform
        Data         => {                   # data payload of request
            ...
        },
    };

=cut

sub ProcessRequest {
    my ( $Self, %Param ) = @_;

    # check transport config
    if ( !IsHashRefWithData( $Self->{TransportConfig} ) ) {
        return $Self->_Error(
            Code    => 'Transport.REST.NoTransportConfig',
            Message => 'REST Transport: Have no TransportConfig',
        );
    }

    $Self->{KeepAlive} = $Self->{TransportConfig}->{KeepAlive} || 0;

    if ( !IsHashRefWithData( $Self->{TransportConfig}->{RouteOperationMapping} ) ) {
        return $Self->_Error(
            Code    => 'Transport.REST.NoRouteOperationMapping',
            Message => "HTTP::REST Can't find RouteOperationMapping in Config",
        );
    }

    # get Encode object
    my $EncodeObject = $Kernel::OM->Get('Encode');

    my $Operation;
    my %URIData;
    
    my %Headers;
    HEADER:
    foreach my $Key ( keys %ENV ) {
        next HEADER if $Key !~ /^HTTP_/; 
        next HEADER if $Key =~ /^HTTP_(PROXY|HOST)/;
        my $Header = $Key;
        $Header =~ s/^HTTP_//g;
        $Header =~ s/_/-/g;
        $Header = ucfirst lc $Header;
        $Headers{$Header} = $ENV{$Key};
    }
    $Headers{'Content-type'} = $ENV{CONTENT_TYPE};

    my $RequestURI = $ENV{REQUEST_URI};
    $RequestURI =~ s{(\/.*)$}{$1}xms;
    # remove any query parameter form the URL
    # e.g. from /Ticket/1/2?UserLogin=user&Password=secret
    # to /Ticket/1/2?
    $RequestURI =~ s{([^?]+)(.+)?}{$1}xms;
    # remember the query parameters e.g. ?UserLogin=user&Password=secret
    my $QueryParamsStr = $2 || '';
    my %QueryParams;

    if ($QueryParamsStr) {

        # remove question mark '?' in the beginning
        substr $QueryParamsStr, 0, 1, '';

        # convert query parameters into a hash (support & and ; as well)
        # e.g. from UserLogin=user&Password=secret
        # to (
        #       UserLogin => 'user',
        #       Password  => 'secret',
        #    );
        for my $QueryParam ( split '&|;', $QueryParamsStr ) {
            my ( $Key, $Value ) = split '=', $QueryParam, 2;

            # Convert + characters to its encoded representation, see bug#11917
            $Value =~ s{\+}{%20}g;

            # unescape URI strings in query parameters
            $Key   = URI::Escape::uri_unescape($Key);
            $Value = URI::Escape::uri_unescape($Value);

            # encode variables
            $EncodeObject->EncodeInput( \$Key );
            $EncodeObject->EncodeInput( \$Value );

            if ( !defined $QueryParams{$Key} ) {
                $QueryParams{$Key} = $Value // '';
            }

            # elements specified multiple times will be added as array reference
            elsif ( ref $QueryParams{$Key} eq '' ) {
                $QueryParams{$Key} = [ $QueryParams{$Key}, $Value ];
            }
            else {
                push @{ $QueryParams{$Key} }, $Value;
            }
        }
    }

    my %PossibleOperations;

    my $RequestMethod = $ENV{'REQUEST_METHOD'} || 'OPTIONS';
    ROUTE:
    for my $CurrentOperation ( sort keys %{ $Self->{TransportConfig}->{RouteOperationMapping} } ) {

        my %RouteMapping = %{ $Self->{TransportConfig}->{RouteOperationMapping}->{$CurrentOperation} || {} };

        if ( $RequestMethod ne 'OPTIONS' && IsArrayRefWithData( $RouteMapping{RequestMethod} ) ) {
            next ROUTE if !grep { $RequestMethod eq $_ } @{ $RouteMapping{RequestMethod} };
        }

        # Convert the configured route with the help of extended regexp patterns
        # to a regexp. This generated regexp is used to:
        # 1.) Determine the Operation for the request
        # 2.) Extract additional parameters from the RequestURI
        # For further information: http://perldoc.perl.org/perlre.html#Extended-Patterns
        #
        # For example, from the RequestURI: /Ticket/1/2
        #     and the route setting:        /Ticket/:TicketID/:Other
        #     %URIData will then contain:
        #     (
        #         TicketID => 1,
        #         Other    => 2,
        #     );
        my $RouteRegEx = $RouteMapping{Route};
        $RouteRegEx =~ s{:([a-z][a-z0-9]*)}{(?<$1>[^\/]+)}xmsgi;

        next ROUTE if !(
            eval { qr/^ $RouteRegEx $/xms }
            && $RequestURI =~ m{^ $RouteRegEx $}xms
        );

        # import URI params
        my %URIParams;
        for my $URIKey ( sort keys %+ ) {
            my $URIValue = $+{$URIKey};

            # unescape value
            $URIValue = URI::Escape::uri_unescape($URIValue);

            # encode value
            $EncodeObject->EncodeInput( \$URIValue );

            # add to URIParams
            $URIParams{$URIKey} = $URIValue;
        }

        # store this possible operation
        $PossibleOperations{$RouteMapping{Route}} = {
            Operation => $CurrentOperation,
            URIParams => \%URIParams,
        }
    }

    # determine base route for later
    my $BaseRoute;
    for my $Route ( keys %PossibleOperations ) {
        if ( !IsHashRefWithData($PossibleOperations{$Route}->{URIParams}) ) {
            # we found the correct route
            $BaseRoute = $Route;
            last;
        }
        $BaseRoute = $Route;
        foreach my $URIParam ( keys %{$PossibleOperations{$Route}->{URIParams}} ) {
            $BaseRoute =~ s/:$URIParam//g;
        }
        # replace multiple slashes and the trailing slash
        $BaseRoute =~ s/\/+/\//g;
        $BaseRoute =~ s/\/$//g;
    }

    # TODO: the following code is nearly identical to the code used in Operation::V1::Common, method ExecOperation -> should be generalized
    # determine all the allowed methods
    my %AvailableMethods;
    for my $CurrentOperation ( sort keys %{ $Self->{TransportConfig}->{RouteOperationMapping} } ) {

        my %RouteMapping = %{ $Self->{TransportConfig}->{RouteOperationMapping}->{$CurrentOperation} || {} };
        my $RouteRegEx = $RouteMapping{Route};
        $RouteRegEx =~ s{:([a-z][a-z0-9]*)}{(?<$1>[^\/]+)}xmsgi;

        my $Base = $RouteMapping{Route};
        $Base =~ s{(/:[^\/]+)}{}xmsg;

        next if !( 
            eval { qr/^ $BaseRoute /xms }
            && $Base =~ m{^ $BaseRoute }xms
        );

        next if !( 
            eval { qr/^ $RouteRegEx $/xms }
            && $RequestURI =~ m{^ $RouteRegEx $}xms
        );
        
        # only add if we didn't have a match upto now
        next if exists $AvailableMethods{$RouteMapping{RequestMethod}->[0]};

        $AvailableMethods{$RouteMapping{RequestMethod}->[0]} = {
            Operation => $CurrentOperation,
            Route     => $RouteMapping{Route}
        };
    }

    if ( !%PossibleOperations && $RequestMethod ne 'OPTIONS' ) {
        # if we didn't find any possible operation, respond with 405
        return $Self->_Error(
            Code       => 'NotAllowed',
            Additional => {
                AddHeader => {
                    Allow => join(', ', sort keys %AvailableMethods),
                }
            }
        );
    }

    # use the most recent operation (prefer "hard" routes above parameterized routes)
    my $CurrentRoute = %PossibleOperations ? (reverse sort keys %PossibleOperations)[0] : $RequestURI;
    $Operation = $PossibleOperations{$CurrentRoute} ? $PossibleOperations{$CurrentRoute}->{Operation} : '';
    %URIData   = %PossibleOperations ? %{$PossibleOperations{$CurrentRoute}->{URIParams}} : ();

    # get direct sub-resource for generic including
    my %ResourceOperationRouteMapping = (
        $Operation => $CurrentRoute
    );
    for my $Op ( sort keys %{ $Self->{TransportConfig}->{RouteOperationMapping} } ) {
        # ignore invalid config
        next if !IsHashRefWithData( $Self->{TransportConfig}->{RouteOperationMapping}->{$Op} );
        # ignore non-search or -get operations
        next if $Op !~ /(Search|Get)$/;
        # ignore anything that has nothing to do with the current Ops route
        if ( $CurrentRoute ne '/' && "$Self->{TransportConfig}->{RouteOperationMapping}->{$Op}->{Route}/" !~ /^$CurrentRoute\// ) {
            next;
        }
        elsif ( $CurrentRoute eq '/' && "$Self->{TransportConfig}->{RouteOperationMapping}->{$Op}->{Route}/" !~ /^$CurrentRoute[:a-zA-Z_]+\/$/g ) {
            next;
        }

        $ResourceOperationRouteMapping{$Op} = $Self->{TransportConfig}->{RouteOperationMapping}->{$Op}->{Route};
    }

    # determine parent mapping as well
    my $ParentObjectRoute = $CurrentRoute;
    $ParentObjectRoute =~ s/^((.*?):(\w+))\/(.+?)$/$1/g;
    $ParentObjectRoute = '' if $ParentObjectRoute eq $CurrentRoute;

    my %ParentMethodOperationMapping;
    if ( $ParentObjectRoute ) {
        for my $Op ( sort keys %{ $Self->{TransportConfig}->{RouteOperationMapping} } ) {
            # ignore invalid config
            next if !IsHashRefWithData( $Self->{TransportConfig}->{RouteOperationMapping}->{$Op} );

            # ignore anything that has nothing to do with the parent Ops route
            if ( $ParentObjectRoute ne '/' && "$Self->{TransportConfig}->{RouteOperationMapping}->{$Op}->{Route}/" !~ /^$ParentObjectRoute\/$/ ) {
                next;
            }
            elsif ( $ParentObjectRoute eq '/' && "$Self->{TransportConfig}->{RouteOperationMapping}->{$Op}->{Route}/" !~ /^$ParentObjectRoute[:a-zA-Z_]+$\//g ) {
                next;
            }

            my $Method = $Self->{TransportConfig}->{RouteOperationMapping}->{$Op}->{RequestMethod}->[0];
            $ParentMethodOperationMapping{$Method} = $Op;
        }
    }

    # combine query params with URIData params, URIData has more precedence
    if (%QueryParams) {
        %URIData = ( %QueryParams, %URIData, );
    }

    if ( !$Operation && $RequestMethod ne 'OPTIONS' ) {
        return $Self->_Error(
            Code    => 'Transport.REST.OperationNotFound',
            Message => "HTTP::REST Error while determine Operation for request URI '$RequestURI'.",
        );
    }

    my $Length = $ENV{'CONTENT_LENGTH'};

    # no length provided, return the information we have
    if ( !$Length ) {
        return $Self->_Success(
            Route          => $CurrentRoute,
            RequestURI     => $RequestURI,
            Operation      => $Operation,
            AvailableMethods => \%AvailableMethods,
            RequestMethod  => $RequestMethod,
            ResourceOperationRouteMapping => \%ResourceOperationRouteMapping,
            ParentMethodOperationMapping => \%ParentMethodOperationMapping,
            Headers   => \%Headers,
            Data      => {
                %URIData,
            },
        );
    }

    # request bigger than allowed
    if ( IsInteger( $Self->{TransportConfig}->{MaxLength} ) && $Length > $Self->{TransportConfig}->{MaxLength} ) {
        return $Self->_Error(
            Code    => 'Transport.REST.RequestTooBig',
            Message => HTTP::Status::status_message(413),
        );
    }

    # read request
    my $Content;
    read STDIN, $Content, $Length;

    # check if we have content
    if ( !IsStringWithData($Content) ) {
        return $Self->_Error(
            Code    => 'Transport.REST.NoContent',
            Message => 'Could not read input data',
        );
    }

    # convert char-set if necessary
    my $ContentCharset;
    if ( $ENV{'CONTENT_TYPE'} =~ /charset=/i ) {
        $ContentCharset = $ENV{'CONTENT_TYPE'};
        $ContentCharset =~ s/.+?charset=("|'|)(\w+)/$2/gi;
        $ContentCharset =~ s/"|'//g;
        $ContentCharset =~ s/(.+?);.*/$1/g;
    }
    if ( $ContentCharset && $ContentCharset !~ m{ \A utf [-]? 8 \z }xmsi ) {
        $Content = $EncodeObject->Convert2CharsetInternal(
            Text => $Content,
            From => $ContentCharset,
        );
    }
    else {
        $EncodeObject->EncodeInput( \$Content );
    }

    my $ContentDecoded = $Content;
    if ( $ENV{'CONTENT_TYPE'} =~ /^application\/json/ ) {
        $ContentDecoded = $Kernel::OM->Get('JSON')->Decode(
            Data => $Content,
        );

        if ( !$ContentDecoded ) {
            return $Self->_Error(
                Code    => 'Transport.REST.InvalidJSON',
                Message => 'Error while decoding request content.',
            );
        }
    }
    # no content-type is provided, assume its json
    elsif ( !$ENV{'CONTENT_TYPE'} ) {
        $ContentDecoded = $Kernel::OM->Get('JSON')->Decode(
            Data   => $Content,
            Silent => 1
        );

        # content could not be decoded as json, use provided content
        if ( !$ContentDecoded ) {
            $ContentDecoded = $Content;
        }
    }

    my $ReturnData;
    if ( IsHashRefWithData($ContentDecoded) ) {

        $ReturnData = $ContentDecoded;
        @{$ReturnData}{ keys %URIData } = values %URIData;
    }
    elsif ( IsArrayRefWithData($ContentDecoded) ) {

        ELEMENT:
        for my $CurrentElement ( @{$ContentDecoded} ) {

            if ( IsHashRefWithData($CurrentElement) ) {
                @{$CurrentElement}{ keys %URIData } = values %URIData;
            }

            push @{$ReturnData}, $CurrentElement;
        }
    }
    else {
        $ReturnData = { Content => $ContentDecoded };
        @{$ReturnData}{ keys %URIData } = values %URIData;
    }

    # all ok - return data
    return $Self->_Success(
        Route                         => $CurrentRoute,
        RequestURI                    => $RequestURI,
        Operation                     => $Operation,
        AvailableMethods              => \%AvailableMethods,
        RequestMethod                 => $RequestMethod,
        ResourceOperationRouteMapping => \%ResourceOperationRouteMapping,
        ParentMethodOperationMapping  => \%ParentMethodOperationMapping,
        Headers                       => \%Headers,
        Data                          => $ReturnData,
    );
}

=item GenerateResponse()

Generates response for an incoming web service request.

In case of an error, error code and message are taken from environment
(previously set on request processing).

The HTTP code is set accordingly
- 200 for (syntactically) correct messages
- 4xx for http errors
- 500 for content syntax errors

    my $Result = $TransportObject->GenerateResponse(
        Success  => 1
        Code     => ...     # optional
        Message  => ...     # optional
        Additional => {     # optional
            ...
        }
        Data     => {       # data payload for response, optional
            ...
        },
        DoNotSortAttributes => 1     # optional, if given, the output is not sorted (default 0)
    );

    $Result = HTTP response;

=cut

sub GenerateResponse {
    my ( $Self, %Param ) = @_;
    my $MappedCode;
    my $MappedMessage;

    # add headers if given
    my $AddHeader;
    if ( IsHashRefWithData($Param{Additional}) && IsHashRefWithData($Param{Additional}->{AddHeader}) ) {
        $AddHeader = $Param{Additional}->{AddHeader};
    }

    # do we have to return an http error code
    if ( IsStringWithData( $Param{Code} ) && !IsInteger($Param{Code}) ) {
        # map error code to HTTP code
        my $Result = $Self->_MapReturnCode(
            Transport    => 'HTTP::REST',
            Code         => $Param{Code},
            Message      => $Param{Message}
        );

        if ( IsHashRefWithData($Result) ) {
            return $Self->_Output(
                HTTPCode => 500,
                Content  => {
                    Code    => $Param{Code},
                    Message => $Result->{Message},
                }
            );
        }
        else {
            ($MappedCode, $MappedMessage) = split(/:/, $Result, 2);
            if ( !$MappedMessage ) {
                $MappedMessage = $Param{Message};
            }
        }
    }
    elsif ( IsInteger($Param{Code}) ) {
        $MappedCode = $Param{Code},
    }

    # do we have to return an error message
    if ( IsStringWithData( $MappedMessage ) ) {
        # return message directly
        return $Self->_Output(
            HTTPCode  => $MappedCode,
            Content   => {
                Code    => $Param{Code},
                Message => $MappedMessage,
            },
            AddHeader => $AddHeader,
        );
    }

    # check data param
    if ( defined $Param{Data} && ref $Param{Data} ne 'HASH' ) {
        return $Self->_Output(
            HTTPCode => 500,
            Content  => {
                Code    => 'Transport.REST.InternalError',
                Message => 'Invalid data',
            }
        );
    }

    # check success param
    my $HTTPCode = $MappedCode || 200;
    if ( !$Param{Success} ) {

        # create Fault structure
        my $FaultString = $MappedMessage || 'Unknown';
        $Param{Data} = {
            Code    => 'Unknown',
            Message => $FaultString,
        };
    }

    # prepare data
    my $Content = $Param{Message};

    if ( IsHashRefWithData($Param{Data}) ) {
        $Content = $Kernel::OM->Get('JSON')->Encode(
            Data     => $Param{Data},
            SortKeys => $Param{DoNotSortAttributes} ? 0 : 1
        );

        if ( !$Content ) {
            return $Self->_Output(
                HTTPCode => 500,
                Content  => {
                    Code    => 'Transport.REST.InternalError',
                    Message => 'Error while encoding return JSON structure.',
                }
            );
        }
    }

    # no error - return output
    return $Self->_Output(
        HTTPCode   => $HTTPCode,
        Content    => $Content,
        AddHeader  => $AddHeader,
    );
}

=begin Internal:

=item _Output()

Generate http response for provider and send it back to remote system.
Environment variables are checked for potential error messages.
Returns structure to be passed to provider.

    my $Result = $TransportObject->_Output(
        HTTPCode  => 200,           # http code to be returned, optional
        Content   => 'response',    # message content, XML response on normal execution
        AddHeader => {              # optional to set some special headers in response
            <Header> => <Value>
        }
    );

    $Result = {
        Success      => 1,
    };

    or

    $Result = {
        Success      => 0,
        Code    => <code>
        Message => '...'
    };

=cut

sub _Output {
    my ( $Self, %Param ) = @_;
    my $Success = 1;
    my $Message;
    my %Headers = %{$Param{AddHeader}||{}};

    my $Content = $Param{Content};
    if ( IsHashRefWithData($Content) ) {
        $Content = $Kernel::OM->Get('JSON')->Encode(
            Data => $Content,
        );

        if ( !$Content ) {
            $Success         = 0;
            $Param{HTTPCode} = 500;
            $Content = {
                Code    => "Transport.REST.InternalError",
                Message => "Error while encoding return JSON structure."
            };
        }
    }

    # check params
    if ( defined $Param{HTTPCode} && !IsInteger( $Param{HTTPCode} ) ) {
        $Success         = 0;
        $Param{HTTPCode} = 500;
        $Content  = {
            Code    => "Transport.REST.InternalError",
            Message => "Invalid internal HTTPCode"
        };
    }

    # prepare protocol
    my $Protocol = defined $ENV{SERVER_PROTOCOL} ? $ENV{SERVER_PROTOCOL} : 'HTTP/1.0';

    # prepare data
    $Content         ||= '';
    $Param{HTTPCode} ||= 500;
    my $ContentType =  $Headers{'Content-Type'} || $Headers{'content-type'} || 'application/json';
    delete $Headers{'Content-Type'};

    # adjust HTTP code
    my $HTTPCode = $Param{HTTPCode};
    if ( $Param{HTTPCode} eq 200 && !$Content ) {
        $HTTPCode = 204;        # No Content
    }

    my $StatusMessage = HTTP::Status::status_message( $HTTPCode );

    # log error message
    if ( $HTTPCode !~ /^2/ ) {
        my $Message = '';

        if ( IsHashRefWithData($Content) || IsHashRefWithData($Param{Content}) ) {
            $Message = sprintf "\n%11s: %s\n%11s: %s",
                'Code', IsHashRefWithData($Content) ? $Content->{Code} : $Param{Content}->{Code},
                'Message', IsHashRefWithData($Content) ? $Content->{Message} : $Param{Content}->{Message};
        }

        printf STDERR "\nAPI ERROR: ProcessID: %i Time: %s\n\n%11s: %s\n%11s: %s\n%11s: %i ms\n%11s: %s%s\n\n",
            $$,
            $Kernel::OM->Get('Time')->CurrentTimestamp(),
            'Method', $Self->{ProcessedRequest}->{RequestMethod},
            'Resource', $Self->{ProcessedRequest}->{RequestURI},
            'Duration', TimeDiff($Self->{Metric}->{StartTime}),
            'HTTPStatus', $HTTPCode.' '.$StatusMessage,
            $Message
    }

    # finally
    if ( $Param{HTTPCode} == 500 && IsHashRefWithData($Content) ) {
        $Param{Content} = $Kernel::OM->Get('JSON')->Encode(
            Data => $Param{Content},
        );
    }

    # calculate content length (based on the bytes length not on the characters length)
    my $ContentLength = bytes::length( $Content );

    # update metric
    if ( $Self->{Metric} ) {
        $Self->{Metric}->{HTTPCode} = $HTTPCode;
        $Self->{Metric}->{OutBytes} = $ContentLength;
    }

    # set keep-alive
    my $Connection = $Self->{KeepAlive} ? 'Keep-Alive' : 'close';

    # in the constructor of this module STDIN and STDOUT are set to binmode without any additional
    # layer (according to the documentation this is the same as set :raw). Previous solutions for
    # binary responses requires the set of :raw or :utf8 according to IO layers.
    # with that solution Windows OS requires to set the :raw layer in binmode, see #bug#8466.
    # while in *nix normally was better to set :utf8 layer in binmode, see bug#8558, otherwise
    # XML parser complains about it... ( but under special circumstances :raw layer was needed
    # instead ).
    # this solution to set the binmode in the constructor and then :utf8 layer before the response
    # is sent  apparently works in all situations. ( Linux circumstances to requires :raw was no
    # reproducible, and not tested in this solution).
    binmode STDOUT, ':utf8';    ## no critic

    # print data to http - '\r' is required according to HTTP RFCs
    print STDOUT "Status: $HTTPCode $StatusMessage\r\n";
    print STDOUT "Content-Type: $ContentType; charset=UTF-8\r\n";
    print STDOUT "Content-Length: $ContentLength\r\n";
    print STDOUT "Connection: $Connection\r\n";

    # add headers if requested
    foreach my $Header ( sort keys %Headers ) {
        print STDOUT "$Header: $Headers{$Header}\r\n";
    }

    print STDOUT "\r\n";
    print STDOUT $Content;

    if ($Success) {
        return $Self->_Success(
            Success => $Success,
        );
    }

    return $Self->_Error(
        Code    => $Param{HTTPCode},
        Message => $Message,
    );
}

=item _MapReturnCode()

Take return code from request processing.
Map the internal return code to transport specific response

    my $MappedCode = $TransportObject->_MapReturnCode(
        Transport => 'REST'        # the specific transport to map to
        Code      => 'Code'        # texttual return code
    );

    $Result = ...

=cut

sub _MapReturnCode {
    my ( $Self, %Param ) = @_;

    # check needed params
    if ( !IsString( $Param{Code} ) ) {
        return $Self->_Error(
            Code    => 'Transport.InternalError',
            Message => 'Need Code!',
        );
    }
    if ( !IsString( $Param{Transport} ) ) {
        return $Self->_Error(
            Code    => 'Transport.InternalError',
            Message => 'Need Transport!',
        );
    }

    # get mapping
    my $Mapping = $Kernel::OM->Get('Config')->Get('API::Transport::ReturnCodeMapping');
    if ( !IsHashRefWithData($Mapping) ) {
        return $Self->_Error(
            Code    => 'Transport.InternalError',
            Message => 'No ReturnCodeMapping config!',
        );
    }

    if ( !IsHashRefWithData($Mapping->{$Param{Transport}}) ) {
        # we don't have a mapping for the given transport, so just return the given code without mapping
        return $Param{Code};
    }
    my $TransportMapping = $Mapping->{$Param{Transport}};

    # get map entry
    my ($MappedCode, $MappedMessage) = split(/:/, $TransportMapping->{$Param{Code}} || $TransportMapping->{'DEFAULT'});

    # override defualt message from mapping if we have some special message
    if ( !$MappedMessage || $Param{Message} ) {
        $MappedMessage = $Param{Message} || '';
    }

    # return
    return "$MappedCode:$MappedMessage";
}

1;

=end Internal:





=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
