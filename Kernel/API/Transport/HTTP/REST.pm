# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Transport::HTTP::REST;

use strict;
use warnings;

use HTTP::Status;
use MIME::Base64;
use REST::Client;
use URI::Escape;

use Kernel::Config;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Transport::HTTP::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Transport::REST - API network transport interface for HTTP::REST

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Transport->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject TransportConfig)) {
        $Self->{$Needed} = $Param{$Needed} || die "Got no $Needed!";
    }

    return $Self;
}

=item ProviderProcessRequest()

Process an incoming web service request. This function has to read the request data
from from the web server process.

Based on the request the Operation to be used is determined.

No outbound communication is done here, except from continue requests.

In case of an error, the resulting http error code and message are remembered for the response.

    my $Result = $TransportObject->ProviderProcessRequest();

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

sub ProviderProcessRequest {
    my ( $Self, %Param ) = @_;

    # check transport config
    if ( !IsHashRefWithData( $Self->{TransportConfig} ) ) {
        return $Self->_Error(
            Code    => 'Transport.REST.NoTransportConfig',
            Message => 'REST Transport: Have no TransportConfig',
        );
    }
    if ( !IsHashRefWithData( $Self->{TransportConfig}->{Config} ) ) {
        return $Self->_Error(
            Code    => 'Transport.REST.NoTransportConfig',
            Message => 'REST Transport: Have no Config',
        );
    }

    my $Config = $Self->{TransportConfig}->{Config};
    $Self->{KeepAlive} = $Config->{KeepAlive} || 0;

    if ( !IsHashRefWithData( $Config->{RouteOperationMapping} ) ) {
        return $Self->_Error(
            Code    => 'Transport.REST.NoRouteOperationMapping',
            Message => "HTTP::REST Can't find RouteOperationMapping in Config",
        );
    }

    # get Encode object
    my $EncodeObject = $Kernel::OM->Get('Kernel::System::Encode');

    my $Operation;
    my %URIData;
    my $RequestURI = $ENV{REQUEST_URI} || $ENV{PATH_INFO};
    $RequestURI =~ s{.*webservice\/[^\/]+(\/.*)$}{$1}xms;

    # remove any query parameter form the URL
    # e.g. from /Ticket/1/2?UserLogin=user&Password=secret
    # to /Ticket/1/2?
    $RequestURI =~ s{([^?]+)(.+)?}{$1};

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
            my ( $Key, $Value ) = split '=', $QueryParam;

            # Convert + characters to its encoded representation, see bug#11917
            $Value =~ s{\+}{%20}g;

            # unescape URI strings in query parameters
            $Key   = URI::Escape::uri_unescape($Key);
            $Value = URI::Escape::uri_unescape($Value);

            # encode variables
            $EncodeObject->EncodeInput( \$Key );
            $EncodeObject->EncodeInput( \$Value );

            if ( !defined $QueryParams{$Key} ) {
                $QueryParams{$Key} = $Value || '';
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
    for my $CurrentOperation ( sort keys %{ $Config->{RouteOperationMapping} } ) {

        next ROUTE if !IsHashRefWithData( $Config->{RouteOperationMapping}->{$CurrentOperation} );

        my %RouteMapping = %{ $Config->{RouteOperationMapping}->{$CurrentOperation} };

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
        $RouteRegEx =~ s{:([^\/]+)}{(?<$1>[^\/]+)}xmsg;

        next ROUTE if !( $RequestURI =~ m{^ $RouteRegEx $}xms );

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

    my %AllowedMethods;
    if ( !%PossibleOperations || $RequestMethod eq 'OPTIONS' ) {
        # if we didn't find any possible operation, respond with 405 - find all allowed methods for this resource
        # if we have a OPTIONS request, just determine the allowed methods
        for my $CurrentOperation ( sort keys %{ $Config->{RouteOperationMapping} } ) {

            next if !IsHashRefWithData( $Config->{RouteOperationMapping}->{$CurrentOperation} );

            my %RouteMapping = %{ $Config->{RouteOperationMapping}->{$CurrentOperation} };
            my $RouteRegEx = $RouteMapping{Route};
            $RouteRegEx =~ s{:([^\/]+)}{(?<$1>[^\/]+)}xmsg;

            next if !( $RequestURI =~ m{^ $RouteRegEx $}xms );

            $AllowedMethods{$RouteMapping{RequestMethod}->[0]} = {
                Operation => $CurrentOperation,
                Route     => $RouteMapping{Route}
            };
        }

        if ( !%PossibleOperations && $RequestMethod ne 'OPTIONS' ) {
            return $Self->_Error(
                Code       => 'NotAllowed',
                Additional => {
                    AddHeader => {
                        Allow => join(', ', sort keys %AllowedMethods),
                    }
                }
            );
        }
    }

    # use the most recent operation (prefer "hard" routes above parameterized routes)
    my $CurrentRoute = %PossibleOperations ? (reverse sort keys %PossibleOperations)[0] : $RequestURI;
    $Operation = $PossibleOperations{$CurrentRoute} ? $PossibleOperations{$CurrentRoute}->{Operation} : '';
    %URIData   = %PossibleOperations ? %{$PossibleOperations{$CurrentRoute}->{URIParams}} : ();

    # get direct sub-resource for generic including
    my %ResourceOperationRouteMapping = (
        $Operation => $CurrentRoute
    );
    for my $Op ( sort keys %{ $Config->{RouteOperationMapping} } ) {
        # ignore invalid config
        next if !IsHashRefWithData( $Config->{RouteOperationMapping}->{$Op} );
        # ignore non-search or -get operations
        next if $Op !~ /(Search|Get)$/;
        # ignore anything that has nothing to do with the current Ops route
        if ( $CurrentRoute ne '/' && "$Config->{RouteOperationMapping}->{$Op}->{Route}/" !~ /^$CurrentRoute\// ) {
            next;
        }
        elsif ( $CurrentRoute eq '/' && "$Config->{RouteOperationMapping}->{$Op}->{Route}/" !~ /^$CurrentRoute[:a-zA-Z_]+\/$/g ) {
            next;
        }

        $ResourceOperationRouteMapping{$Op} = $Config->{RouteOperationMapping}->{$Op}->{Route};
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
    if ( !$Length || $RequestMethod eq 'OPTIONS' ) {
        return $Self->_Success(
            Route          => $CurrentRoute,
            Operation      => $Operation,
            AllowedMethods => \%AllowedMethods,
            ResourceOperationRouteMapping => \%ResourceOperationRouteMapping,
            Data      => {
                %URIData,
                RequestMethod => $RequestMethod,
            },
        );
    }

    # request bigger than allowed
    if ( IsInteger( $Config->{MaxLength} ) && $Length > $Config->{MaxLength} ) {
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
    if ( $ENV{'CONTENT_TYPE'} =~ m{ \A .* charset= ["']? ( [^"']+ ) ["']? \z }xmsi ) {
        $ContentCharset = $1;
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

    # send received data to debugger
    $Self->{DebuggerObject}->Debug(
        Summary => 'Received data by provider from remote system',
        Data    => $Content,
    );

    my $ContentDecoded = $Kernel::OM->Get('Kernel::System::JSON')->Decode(
        Data => $Content,
    );

    if ( !$ContentDecoded ) {
        return $Self->_Error(
            Code    => 'Transport.REST.InvalidJSON',
            Message => 'Error while decoding request content.',
        );
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
        return $Self->_Error(
            Code    => 'Transport.REST.InvalidRequest',
            Message => 'Unsupported request content structure.',
        );
    }

    # all ok - return data
    return $Self->_Success(
        Operation => $Operation,
        Data      => $ReturnData,
        ResourceOperationRouteMapping => \%ResourceOperationRouteMapping,
    );
}

=item ProviderGenerateResponse()

Generates response for an incoming web service request.

In case of an error, error code and message are taken from environment
(previously set on request processing).

The HTTP code is set accordingly
- 200 for (syntactically) correct messages
- 4xx for http errors
- 500 for content syntax errors

    my $Result = $TransportObject->ProviderGenerateResponse(
        Success  => 1
        Code     => ...     # optional
        Message  => ...     # optional
        Additional => {     # optional
            ...
        }
        Data     => {       # data payload for response, optional
            ...
        },
    );

    $Result = HTTP response;

=cut

sub ProviderGenerateResponse {
    my ( $Self, %Param ) = @_;
    my $MappedCode;
    my $MappedMessage;

    # add headers if given
    my $AddHeader;
    if ( IsHashRefWithData($Param{Additional}) && IsHashRefWithData($Param{Additional}->{AddHeader}) ) {
        $AddHeader = $Param{Additional}->{AddHeader};
    }

    # do we have to return an http error code
    if ( IsStringWithData( $Param{Code} ) ) {
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
    my $JSONString = '';
    if ( IsHashRefWithData($Param{Data}) ) {
        $JSONString = $Kernel::OM->Get('Kernel::System::JSON')->Encode(
            Data     => $Param{Data},
            SortKeys => 1
        );

        if ( !$JSONString ) {
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
        Content    => $JSONString,
        AddHeader  => $AddHeader,
    );
}

=item RequesterPerformRequest()

Prepare data payload as XML structure, generate an outgoing web service request,
receive the response and return its data.

    my $Result = $TransportObject->RequesterPerformRequest(
        Operation => 'remote_op', # name of remote operation to perform
        Data      => {            # data payload for request
            ...
        },
    );

    $Result = {
        Success      => 1,        # 0 or 1
        Message => '',       # in case of error
        Data         => {
            ...
        },
    };

=cut

sub RequesterPerformRequest {
    my ( $Self, %Param ) = @_;

    # check transport config
    if ( !IsHashRefWithData( $Self->{TransportConfig} ) ) {
        return $Self->_Error(
            Code    => 'Transport.REST.NoTransportConfig',
            Message => 'REST Transport: Have no TransportConfig',
        );
    }
    if ( !IsHashRefWithData( $Self->{TransportConfig}->{Config} ) ) {
        return $Self->_Error(
            Code    => 'Transport.REST.NoTransportConfig',
            Message => 'REST Transport: Have no Config',
        );
    }
    my $Config = $Self->{TransportConfig}->{Config};

    NEEDED:
    for my $Needed (qw(Host DefaultCommand)) {
        next NEEDED if IsStringWithData( $Config->{$Needed} );

        return $Self->_Error(
            Code    => 'Transport.REST.TransportConfigInvalid',
            Message => "REST Transport: Have no $Needed in config",
        );
    }

    # check data param
    if ( defined $Param{Data} && ref $Param{Data} ne 'HASH' ) {
        return $Self->_Error(
            Code    => 'Transport.REST.DataMissing',
            Message => 'REST Transport: Invalid Data',
        );
    }

    # check operation param
    if ( !IsStringWithData( $Param{Operation} ) ) {
        return $Self->_Error(
            Code    => 'Transport.REST.DataMissing',
            Message => 'REST Transport: Need Operation',
        );
    }

    # create header container
    # and add proper content type
    my $Headers = { 'Content-Type' => 'application/json; charset=UTF-8' };

    if ( IsHashRefWithData( $Config->{Authentication} ) ) {

        # basic authentication
        if (
            IsStringWithData( $Config->{Authentication}->{Type} )
            && $Config->{Authentication}->{Type} eq 'BasicAuth'
            )
        {
            my $User = $Config->{Authentication}->{User};
            my $Password = $Config->{Authentication}->{Password} || '';

            if ( IsStringWithData($User) ) {
                my $EncodedCredentials = encode_base64("$User:$Password");
                $Headers->{Authorization} = 'Basic ' . $EncodedCredentials;
            }
        }
    }

    # set up a REST session
    my $RestClient = REST::Client->new(
        {
            host => $Config->{Host},
        }
    );

    if ( !$RestClient ) {

        my $Message = "Error while creating REST client from 'REST::Client'.";

        # log to debugger
        $Self->{DebuggerObject}->Error(
            Summary => $Message,
        );
        return $Self->_Error(
            Code    => 'Transport.REST.InternalError',
            Message => $Message,
        );
    }

    # add X509 options if configured
    if ( IsHashRefWithData( $Config->{X509} ) ) {

        # use X509 options
        if (
            IsStringWithData( $Config->{X509}->{UseX509} )
            && $Config->{X509}->{UseX509} eq 'Yes'
            )
        {
            #X509 client authentication
            $RestClient->setCert( $Config->{X509}->{X509CertFile} );
            $RestClient->setKey( $Config->{X509}->{X509KeyFile} );

            #add a CA to verify server certificates
            if ( IsStringWithData( $Config->{X509}->{X509CAFile} ) ) {
                $RestClient->setCa( $Config->{X509}->{X509CAFile} );
            }
        }
    }

    my $RestCommand = $Config->{DefaultCommand};
    if ( IsStringWithData( $Config->{InvokerControllerMapping}->{ $Param{Operation} }->{Command} ) )
    {
        $RestCommand = $Config->{InvokerControllerMapping}->{ $Param{Operation} }->{Command};
    }

    $RestCommand = uc $RestCommand;

    if ( !grep { $_ eq $RestCommand } qw(GET POST PUT PATCH DELETE HEAD OPTIONS CONNECT TRACE) ) {

        my $Message = "'$RestCommand' is not a valid REST command.";

        # log to debugger
        $Self->{DebuggerObject}->Error(
            Summary => $Message,
        );
        return $Self->_Error(
            Code    => 'Transport.REST.InvalidMethod',
            Message => $Message,
        );
    }

    if (
        !IsHashRefWithData( $Config->{InvokerControllerMapping} )
        || !IsHashRefWithData( $Config->{InvokerControllerMapping}->{ $Param{Operation} } )
        || !IsStringWithData(
            $Config->{InvokerControllerMapping}->{ $Param{Operation} }->{Controller}
        )
        )
    {
        my $Message = "REST Transport: Have no Invoker <-> Controller mapping for Invoker '$Param{Operation}'.";

        # log to debugger
        $Self->{DebuggerObject}->Error(
            Summary => $Message,
        );
        return $Self->_Error(
            Code    => 'Transport.REST.NoInvokerControllerMapping',
            Message => $Message,
        );
    }

    my @RequestParam;
    my $Controller = $Config->{InvokerControllerMapping}->{ $Param{Operation} }->{Controller};

    # remove any query parameters that might be in the config
    # For example, from the controller: /Ticket/:TicketID/?:UserLogin&:Password
    #     controller must remain  /Ticket/:TicketID/
    $Controller =~ s{([^?]+)(.+)?}{$1};

    # remember the query parameters e.g. ?:UserLogin&:Password
    my $QueryParamsStr = $2 || '';

    my @ParamsToDelete;

    # replace any URI params with their actual value
    #    for example: from /Ticket/:TicketID/:Other
    #    to /Ticket/1/2 (considering that $Param{Data} contains TicketID = 1 and Other = 2)
    for my $ParamName ( sort keys %{ $Param{Data} } ) {
        if ( $Controller =~ m{:$ParamName(?=/|\?|$)}msx ) {
            my $ParamValue = $Param{Data}->{$ParamName};
            $ParamValue = URI::Escape::uri_escape_utf8($ParamValue);
            $Controller =~ s{:$ParamName(?=/|\?|$)}{$ParamValue}msxg;
            push @ParamsToDelete, $ParamName;
        }
    }

    $Self->{DebuggerObject}->Debug(
        Summary => "URI after interpolating URI params from outgoing data",
        Data    => $Controller,
    );

    if ($QueryParamsStr) {

        # replace any query params with their actual value
        #    for example: from ?UserLogin:UserLogin&Password=:Password
        #    to ?UserLogin=user&Password=secret
        #    (considering that $Param{Data} contains UserLogin = 'user' and Password = 'secret')
        my $ReplaceFlag;
        for my $ParamName ( sort keys %{ $Param{Data} } ) {
            if ( $QueryParamsStr =~ m{:$ParamName(?=&|$)}msx ) {
                my $ParamValue = $Param{Data}->{$ParamName};
                $ParamValue = URI::Escape::uri_escape_utf8($ParamValue);
                $QueryParamsStr =~ s{:$ParamName(?=&|$)}{$ParamValue}msxg;
                push @ParamsToDelete, $ParamName;
                $ReplaceFlag = 1;
            }
        }

        # append query params in the URI
        if ($ReplaceFlag) {
            $Controller .= $QueryParamsStr;

            $Self->{DebuggerObject}->Debug(
                Summary => "URI after interpolating Query params from outgoing data",
                Data    => $Controller,
            );
        }
    }

    # remove already used params
    for my $ParamName (@ParamsToDelete) {
        delete $Param{Data}->{$ParamName};
    }

    # get JSON and Encode object
    my $JSONObject   = $Kernel::OM->Get('Kernel::System::JSON');
    my $EncodeObject = $Kernel::OM->Get('Kernel::System::Encode');

    my $Body;
    if ( IsHashRefWithData( $Param{Data} ) ) {

        # POST, PUT and PATCH can have Data in the Body
        if (
            $RestCommand eq 'POST'
            || $RestCommand eq 'PUT'
            || $RestCommand eq 'PATCH'
            )
        {
            $Self->{DebuggerObject}->Debug(
                Summary => "Remaining outgoing data to be sent",
                Data    => $Param{Data},
            );

            $Param{Data} = $JSONObject->Encode(
                Data => $Param{Data},
            );

            # make sure data is correctly encoded
            $EncodeObject->EncodeOutput( \$Param{Data} );
        }

        # whereas GET and the others just have a the data added to the Query URI.
        else {
            my $QueryParams = $RestClient->buildQuery(
                %{ $Param{Data} }
            );

            # check if controller already have a  question mark '?'
            if ( $Controller =~ m{\?}msx ) {

                # replace question mark '?' by an ampersand '&'
                $QueryParams =~ s{\A\?}{&};
            }

            $Controller .= $QueryParams;

            $Self->{DebuggerObject}->Debug(
                Summary => "URI after adding Query params from outgoing data",
                Data    => $Controller,
            );

            $Self->{DebuggerObject}->Debug(
                Summary => "Remaining outgoing data to be sent",
                Data    => "No data is sent in the request body as $RestCommand command sets all"
                    . " Data as query params",
            );
        }
    }
    push @RequestParam, $Controller;

    if ( IsStringWithData( $Param{Data} ) ) {
        $Body = $Param{Data};
        push @RequestParam, $Body;
    }

    # add headers to request
    push @RequestParam, $Headers;

    $RestClient->$RestCommand(@RequestParam);

    my $ResponseCode = $RestClient->responseCode();
    my $ResponseError;
    my $Message = "Error while performing REST '$RestCommand' request to Controller '$Controller' on Host '"
        . $Config->{Host} . "'.";

    if ( !IsStringWithData($ResponseCode) ) {
        $ResponseError = $Message;
    }

    if ( $ResponseCode !~ m{ \A 20 \d \z }xms ) {
        $ResponseError = $Message . " Response code '$ResponseCode'.";
    }

    if ($ResponseError) {

        # log to debugger
        $Self->{DebuggerObject}->Error(
            Summary => $ResponseError,
        );
        return $Self->_Error(
            Code    => $ResponseCode,
            Message => $ResponseError,
        );
    }

    my $ResponseContent = $RestClient->responseContent();
    if ( !IsStringWithData($ResponseContent) ) {

        my $ResponseError = $Message . ' No content provided.';

        # log to debugger
        $Self->{DebuggerObject}->Error(
            Summary => $ResponseError,
        );
        return $Self->_Error(
            Code    => 'Transport.REST.NoContent',
            Message => $ResponseError,
        );
    }

    my $SizeExeeded = 0;
    {
        my $MaxSize
            = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::ResponseLoggingMaxSize') || 200;
        $MaxSize = $MaxSize * 1024;
        use bytes;

        my $ByteSize = length($ResponseContent);

        if ( $ByteSize < $MaxSize ) {
            $Self->{DebuggerObject}->Debug(
                Summary => 'JSON data received from remote system',
                Data    => $ResponseContent,
            );
        }
        else {
            $SizeExeeded = 1;
            $Self->{DebuggerObject}->Debug(
                Summary => "JSON data received from remote system was too large for logging",
                Data =>
                    'See SysConfig option API::Operation::ResponseLoggingMaxSize to change the maximum.',
            );
        }
    }

    # send processed data to debugger
    $Self->{DebuggerObject}->Debug(
        Summary => 'JSON data received from remote system',
        Data    => $ResponseContent,
    );

    $ResponseContent = $EncodeObject->Convert2CharsetInternal(
        Text => $ResponseContent,
        From => 'utf-8',
    );

    # to convert the data into a hash, use the JSON module
    my $Result = $JSONObject->Decode(
        Data => $ResponseContent,
    );

    if ( !$Result ) {
        my $ResponseError = $Message . ' Error while parsing JSON data.';

        # log to debugger
        $Self->{DebuggerObject}->Error(
            Summary => $ResponseError,
        );
        return $Self->_Error(
            Code    => 'Transport.REST.InvalidJSON',
            Message => $ResponseError,
        );
    }

    # all OK - return result
    return $Self->_Success(
        Data        => $Result || undef,
        SizeExeeded => $SizeExeeded,
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

    if ( IsHashRefWithData($Param{Content}) ) {
        $Param{Content} = $Kernel::OM->Get('Kernel::System::JSON')->Encode(
            Data => $Param{Content},
        );

        if ( !$Param{Content} ) {
            $Param{HTTPCode} = 500;
            $Param{Content}  = '
{ 
    "Code": "Transport.REST.InternalError",
    "Message": "Error while encoding return JSON structure."
}';
            $Success         = 0;
            $Message         = 'Error while encoding return JSON structure.';            
        }
    }

    # check params
    if ( defined $Param{HTTPCode} && !IsInteger( $Param{HTTPCode} ) ) {
        $Param{HTTPCode} = 500;
        $Param{Content}  = '
{ 
    "Code": "Transport.REST.InternalError",
    "Message": "Invalid internal HTTPCode"
}';
        $Success         = 0;
        $Message         = 'Invalid internal HTTPCode';
    }
    elsif ( defined $Param{Content} && !IsString( $Param{Content} ) ) {
        $Param{HTTPCode} = 500;
        $Param{Content}  = '
{ 
    "Code": "Transport.REST.InternalError",
    "Message": "Invalid Content"
}';
        $Success         = 0;
        $Message         = 'Invalid Content';
    }

    # prepare protocol
    my $Protocol = defined $ENV{SERVER_PROTOCOL} ? $ENV{SERVER_PROTOCOL} : 'HTTP/1.0';

    # FIXME
    # according to SOAP::Transport::HTTP the previous should only be used
    # for IIS to imitate nph- behavior
    # for all other browser 'Status:' should be used here
    # this breaks apache though

    # prepare data
    $Param{Content}  ||= '';
    $Param{HTTPCode} ||= 500;
    my $ContentType =  'application/json';

    # calculate content length (based on the bytes length not on the characters length)
    my $ContentLength = bytes::length( $Param{Content} );

    # log to debugger
    my $DebugLevel;
    if ( $Param{HTTPCode} =~ /^2/ ) {
        $DebugLevel = 'debug';
    }
    else {
        $DebugLevel = 'error';
    }
    $Self->{DebuggerObject}->DebugLog(
        DebugLevel => $DebugLevel,
        Summary    => "Returning provider data to remote system (HTTP Code: $Param{HTTPCode})",
        Data       => $Param{Content},
    );

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

    # adjust HTTP code
    my $HTTPCode = $Param{HTTPCode};
    if ( $Param{HTTPCode} eq 200 && !$Param{Content} ) {
        $HTTPCode = 204;        # No Content
    }

    # print data to http - '\r' is required according to HTTP RFCs
    my $StatusMessage = HTTP::Status::status_message( $HTTPCode );
    print STDOUT "Status: $HTTPCode $StatusMessage\r\n";
    print STDOUT "Content-Type: $ContentType; charset=UTF-8\r\n";
    print STDOUT "Content-Length: $ContentLength\r\n";
    print STDOUT "Connection: $Connection\r\n";
    
    # add headers if requested
    if ( IsHashRefWithData($Param{AddHeader}) ) {
        foreach my $Header ( sort keys %{$Param{AddHeader}} ) {
            print STDOUT "$Header: $Param{AddHeader}->{$Header}\r\n";
        }
    }
    
    print STDOUT "\r\n";
    print STDOUT $Param{Content};

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

1;

=end Internal:




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
