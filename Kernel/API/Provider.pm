# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Provider;

use strict;
use warnings;

use URI::Escape;

use Kernel::API::Debugger;
use Kernel::API::Transport;
use Kernel::API::Mapping;
use Kernel::API::Operation;
use Kernel::API::Validator;
use Kernel::System::API::Webservice;
use Kernel::System::VariableCheck (qw(IsHashRefWithData));

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::API::Webservice',
);

use base qw(
    Kernel::API::Common
);

=head1 NAME

Kernel::API::Provider - handler for incoming webservice requests.

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;

    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $ProviderObject = $Kernel::OM->Get('Kernel::API::Provider');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item Run()

receives the current incoming web service request, handles it,
and returns an appropriate answer based on the configured requested
web service.

    # put this in the handler script
    $ProviderObject->Run();

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    #
    # First, we need to locate the desired webservice and load its configuration data.
    #

    my $Webservice;

    # on Microsoft IIS 7.0, $ENV{REQUEST_URI} is not set. See bug#9172.
    my $RequestURI = $ENV{REQUEST_URI} || $ENV{PATH_INFO};

    my ($WebserviceName) = $RequestURI =~ m{ api[.]pl [/] webservice [/] ([^/?]+) }smx;

    if ( !$WebserviceName ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Could not determine WebserviceName from query string $RequestURI",
        );

        return;    # bail out without Transport, plack will generate 500 Error
    }

    $WebserviceName = URI::Escape::uri_unescape($WebserviceName);

    $Webservice = $Kernel::OM->Get('Kernel::System::API::Webservice')->WebserviceGet(
        Name => $WebserviceName,
    );

    if ( !IsHashRefWithData($Webservice) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message =>
                "Could not load web service configuration for web service at $RequestURI",
        );

        return;    # bail out without Transport, plack will generate 500 Error
    }

    my $WebserviceID = $Webservice->{ID};

    #
    # Create a debugger instance which will log the details of this
    #   communication entry.
    #

    $Self->{DebuggerObject} = Kernel::API::Debugger->new(
        DebuggerConfig    => $Webservice->{Config}->{Debugger},
        WebserviceID      => $WebserviceID,
        CommunicationType => 'Provider',
        RemoteIP          => $ENV{REMOTE_ADDR},
    );

    if ( ref $Self->{DebuggerObject} ne 'Kernel::API::Debugger' ) {

        return;    # bail out without Transport, plack will generate 500 Error
    }

    $Self->{DebuggerObject}->Debug(
        Summary => 'Communication sequence started',
        Data    => \%ENV,
    );

    #
    # Create the network transport backend and read the network request.
    #

    my $ProviderConfig = $Webservice->{Config}->{Provider};

    $Self->{TransportObject} = Kernel::API::Transport->new(
        DebuggerObject  => $Self->{DebuggerObject},
        TransportConfig => $ProviderConfig->{Transport},
    );

    # bail out if transport init failed
    if ( ref $Self->{TransportObject} ne 'Kernel::API::Transport' ) {

        return $Self->Error(
            Code    => 'Provider.InternalError',
            Message => 'TransportObject could not be initialized',
            Data    => $Self->{TransportObject},
        );
    }

    # read request content
    my $FunctionResult = $Self->{TransportObject}->ProviderProcessRequest();

    # If the request was not processed correctly, send error to client.
    if ( !$FunctionResult->{Success} ) {

        # # don't tell something about the interna of the API
        my $ErrorResponse = $Self->_Error(
            Code    => 'BadRequest',
            Message => 'Request could not be processed',
        );

        return $Self->_GenerateErrorResponse(
            %{$ErrorResponse},
        );
    }

    my $Operation = $FunctionResult->{Operation};

    $Self->{DebuggerObject}->Debug(
        Summary => "Detected operation '$Operation'",
    );

    #
    # Map the incoming data based on the configured mapping
    #

    my $DataIn = $FunctionResult->{Data};

    $Self->{DebuggerObject}->Debug(
        Summary => "Incoming data before mapping",
        Data    => $DataIn,
    );

    # decide if mapping needs to be used or not
    if (
        IsHashRefWithData( $ProviderConfig->{Operation}->{$Operation}->{MappingInbound} )
        )
    {
        my $MappingInObject = Kernel::API::Mapping->new(
            DebuggerObject => $Self->{DebuggerObject},
            Operation      => $Operation,
            OperationType  => $ProviderConfig->{Operation}->{$Operation}->{Type},
            MappingConfig =>
                $ProviderConfig->{Operation}->{$Operation}->{MappingInbound},
        );

        # if mapping init failed, bail out
        if ( ref $MappingInObject ne 'Kernel::API::Mapping' ) {
            my $ErrorResponse = $Self->_Error(
                Code    => 'Provider.InternalError',
                Message => 'MappingIn could not be initialized',
                Data    => $MappingInObject,
            );

            return $Self->_GenerateErrorResponse(
                %{$ErrorResponse},
            );
        }

        $FunctionResult = $MappingInObject->Map(
            Data => $DataIn,
        );

        if ( !$FunctionResult->{Success} ) {

            return $Self->_GenerateErrorResponse(
                %{$FunctionResult},
            );
        }

        $DataIn = $FunctionResult->{Data};

        $Self->{DebuggerObject}->Debug(
            Summary => "Incoming data after mapping",
            Data    => $DataIn,
        );
    }

    # check authorization if needed
    my $Authorization;
    if ( !$ProviderConfig->{Operation}->{$Operation}->{NoAuthorizationNeeded} ) {
        $FunctionResult = $Self->{TransportObject}->ProviderCheckAuthorization();

        if ( !$FunctionResult->{Success} ) {

            return $Self->_GenerateErrorResponse(
                %{$FunctionResult},
            );
        }
        else {
            $Authorization = $FunctionResult->{Data}->{Authorization};
        }
    }

    #
    # Execute actual operation.
    #

    my $OperationObject = Kernel::API::Operation->new(
        DebuggerObject          => $Self->{DebuggerObject},
        APIVersion              => $Webservice->{Config}->{APIVersion},
        Operation               => $Operation,
        OperationType           => $ProviderConfig->{Operation}->{$Operation}->{Type},
        WebserviceID            => $WebserviceID,
        Authorization           => $Authorization,
    );

    # if operation init failed, bail out
    if ( ref $OperationObject ne 'Kernel::API::Operation' ) {
        return $Self->_GenerateErrorResponse(
            %{$OperationObject},
        );
    }

    my $FunctionResultOperation = $OperationObject->Run(
        Data => $DataIn,
    );

    if ( !$FunctionResultOperation->{Success} ) {

        return $Self->_GenerateErrorResponse(
            %{$FunctionResultOperation},
        );
    }

    #
    # Map the outgoing data based on configured mapping.
    #

    my $DataOut = $FunctionResultOperation->{Data};

    $Self->{DebuggerObject}->Debug(
        Summary => "Outgoing data before mapping",
        Data    => $DataOut,
    );

    # decide if mapping needs to be used or not
    if (
        IsHashRefWithData(
            $ProviderConfig->{Operation}->{$Operation}->{MappingOutbound}
        )
        )
    {
        my $MappingOutObject = Kernel::API::Mapping->new(
            DebuggerObject => $Self->{DebuggerObject},
            Operation      => $Operation,
            OperationType  => $ProviderConfig->{Operation}->{$Operation}->{Type},
            MappingConfig =>
                $ProviderConfig->{Operation}->{$Operation}->{MappingOutbound},
        );

        # if mapping init failed, bail out
        if ( ref $MappingOutObject ne 'Kernel::API::Mapping' ) {
            my $ErrorResponse = $Self->_Error(
                Code    => 'Provider.InternalError',
                Message => 'MappingOut could not be initialized',
                Data    => $MappingOutObject,
            );

            return $Self->_GenerateErrorResponse(
                %{$ErrorResponse}
            );
        }

        $FunctionResult = $MappingOutObject->Map(
            Data => $DataOut,
        );

        if ( !$FunctionResult->{Success} ) {

            return $Self->_GenerateErrorResponse(
                %{$FunctionResult},
            );
        }

        $DataOut = $FunctionResult->{Data};

        $Self->{DebuggerObject}->Debug(
            Summary => "Outgoing data after mapping",
            Data    => $DataOut,
        );
    }

    #
    # Generate the actual response
    #

    $FunctionResult = $Self->{TransportObject}->ProviderGenerateResponse(
        Success => 1,
        %{$FunctionResultOperation},
    );

    if ( !$FunctionResult->{Success} ) {
        $Self->_Error(
            Code    => 'Provider.InternalError',
            Message => 'Response could not be sent',
            Data    => $FunctionResult->{ErrorMessage},
        );
    }

    return;
}

=item _GenerateErrorResponse()

returns an error message to the client.

    $ProviderObject->_GenerateErrorResponse(
        Code    => $ReturnCode,
        Message => $ErrorMessage,
    );

=cut

sub _GenerateErrorResponse {
    my ( $Self, %Param ) = @_;

    my $FunctionResult = $Self->{TransportObject}->ProviderGenerateResponse(
        %Param,
        Success      => 0,
    );

    return;
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
