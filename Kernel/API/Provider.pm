# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Provider;

use strict;
use warnings;

use URI::Escape;

use Kernel::System::VariableCheck (qw(IsHashRefWithData));

our @ObjectDependencies = (
    'Log',
    'API::Webservice',
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
    my $ProviderObject = $Kernel::OM->Get('API::Provider');

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

    my ($Tmp, $Entrypoint, $WebserviceName, $RequestURI) = split(/\//, $ENV{REQUEST_URI}, 4);
    $ENV{REQUEST_URI} = '/'.$RequestURI;

    if ( !$WebserviceName ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Could not determine WebserviceName from query string $RequestURI",
        );

        return;    # bail out without Transport, plack will generate 500 Error
    }

    $WebserviceName = URI::Escape::uri_unescape($WebserviceName);

    $Webservice = $Kernel::OM->Get('API::Webservice')->WebserviceGet(
        Name => $WebserviceName,
    );

    if ( !IsHashRefWithData($Webservice) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message =>
                "Could not load web service configuration for web service at $RequestURI",
        );

        return;    # bail out, this will generate 500 Error
    }

    # Check if web service has valid state.
    if ( $Kernel::OM->Get('Valid')->ValidLookup( ValidID => $Webservice->{ValidID} ) ne 'valid' ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message =>
                "Web service '$Webservice->{Name}' is not valid and can not be loaded",
        );

        return;    # bail out, this will generate 500 Error
    }

    my $WebserviceID = $Webservice->{ID};

    #
    # Create a debugger instance which will log the details of this
    #   communication entry.
    #

    my $DebuggerModule = $Kernel::OM->GetModuleFor('API::Debugger');
    if ( !$Kernel::OM->Get('Main')->Require($DebuggerModule) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message => "Can't load module $DebuggerModule",
        );
        return;    # bail out, this will generate 500 Error
    }    
    $Self->{DebuggerObject} = $DebuggerModule->new(
        DebuggerConfig    => $Webservice->{Config}->{Debugger},
        WebserviceID      => $WebserviceID,
        CommunicationType => 'Provider',
        RemoteIP          => $ENV{REMOTE_ADDR},
    );

    if ( ref $Self->{DebuggerObject} ne $DebuggerModule ) {

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

print STDERR "here!!\n";

    my $TransportModule = $Kernel::OM->GetModuleFor('API::Transport');
    if ( !$Kernel::OM->Get('Main')->Require($TransportModule) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message => "Can't load module $TransportModule",
        );
        return;    # bail out, this will generate 500 Error
    }    
    $Self->{TransportObject} = $TransportModule->new(
        DebuggerObject  => $Self->{DebuggerObject},
        TransportConfig => $ProviderConfig->{Transport},
    );

    # bail out if transport init failed
    if ( ref $Self->{TransportObject} ne $TransportModule ) {

        return $Self->Error(
            Code    => 'Provider.InternalError',
            Message => 'TransportObject could not be initialized',
            Data    => $Self->{TransportObject},
        );
    }
print STDERR "here2!!\n";

    # read request content
    my $FunctionResult = $Self->{TransportObject}->ProviderProcessRequest();

    # If the request was not processed correctly, send error to client.
    if ( !$FunctionResult->{Success} ) {

        return $Self->_GenerateErrorResponse(
            %{$FunctionResult},
        );
    }

    # save FunctionResult for later use
    my %ProcessRequestResult = %{$FunctionResult};

    my $Operation = $FunctionResult->{Operation};
    my $DataIn    = $FunctionResult->{Data};

    if ( $Operation ) {
        $Self->{DebuggerObject}->Debug(
            Summary => "Detected operation '$Operation'",
        );
    }

    # check authorization if needed
    my $Authorization;
    if ( !$ProviderConfig->{Operation}->{$Operation}->{NoAuthorizationNeeded} ) {
        $FunctionResult = $Self->{TransportObject}->ProviderCheckAuthorization();

        if ( $ProcessRequestResult{RequestMethod} ne 'OPTIONS' && !$FunctionResult->{Success} ) {
            return $Self->_GenerateErrorResponse(
                %{$FunctionResult},
            );
        }
        else {
            $Authorization = $FunctionResult->{Data}->{Authorization};
        }
    }

    # check if we have to respond to an OPTIONS request instead of executing the operation
    if ( $ProcessRequestResult{RequestMethod} && $ProcessRequestResult{RequestMethod} eq 'OPTIONS' ) {
        my $Data;

        # add information about each available method
        foreach my $Method ( sort keys %{$ProcessRequestResult{AvailableMethods}} ) {

            # create an operation object for each allowed method and ask it for options
            my $Operation = $ProcessRequestResult{AvailableMethods}->{$Method}->{Operation}; 

            my $OperationModule = $Kernel::OM->GetModuleFor('API::Operation');
            if ( !$Kernel::OM->Get('Main')->Require($OperationModule) ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message => "Can't load module $OperationModule",
                );
                return;    # bail out, this will generate 500 Error
            }    

            my $OperationObject = $OperationModule->new(
                DebuggerObject          => $Self->{DebuggerObject},
                APIVersion              => $Webservice->{Config}->{APIVersion},
                Operation               => $Operation,
                OperationType           => $ProviderConfig->{Operation}->{$Operation}->{Type},
                WebserviceID            => $WebserviceID,
                AvailableMethods        => $ProcessRequestResult{AvailableMethods},
                OperationRouteMapping   => $ProcessRequestResult{ResourceOperationRouteMapping},
                RequestMethod           => $Method,
                CurrentRoute            => $ProcessRequestResult{Route},
                RequestURI              => $ProcessRequestResult{RequestURI},
                Authorization           => $Authorization,
            );

            # if operation init failed, bail out
            if ( ref $OperationObject ne $OperationModule ) {
                # only bail out if it's not a 403
                if ( $OperationObject->{Code} ne 'Forbidden' ) {
                    return $Self->_GenerateErrorResponse(
                        %{$OperationObject},
                    );
                }
            }
            else {
                # get options from operation
                my $OptionsResult = $OperationObject->Options();
                my %OptionsData = IsHashRefWithData($OptionsResult->{Data}) ? %{$OptionsResult->{Data}} : ();

                $Data->{Methods}->{$Method} = {
                    %OptionsData,
                    Route               => $ProcessRequestResult{AvailableMethods}->{$Method}->{Route},
                    AuthorizationNeeded => $ProviderConfig->{Operation}->{$Operation}->{NoAuthorizationNeeded} ? 0 : 1,
                }
            }
        }

        # add information about sub-resources
        my $CurrentRoute = $ProcessRequestResult{Route};
        $CurrentRoute = '' if $CurrentRoute eq '/';
        my @ChildResources = grep(/^$CurrentRoute\/([:a-zA-Z_]+)$/g, values %{$ProcessRequestResult{ResourceOperationRouteMapping}});
        if ( @ChildResources ) {
            $Data->{Resources} = \@ChildResources;
        }

        my $FunctionResult = $Self->{TransportObject}->ProviderGenerateResponse(
            Success => 1,
            Data    => $Data,
            Additional => {
                AddHeader => {
                    Allow => join(', ', sort keys %{$Data->{Methods}}),
                }
            }
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

    #
    # Map the incoming data based on the configured mapping
    #

    $Self->{DebuggerObject}->Debug(
        Summary => "Incoming data before mapping",
        Data    => $DataIn,
    );

    # decide if mapping needs to be used or not
    if (
        $Operation && IsHashRefWithData( $ProviderConfig->{Operation}->{$Operation}->{MappingInbound} )
        )
    {
        my $MappingModule = $Kernel::OM->GetModuleFor('API::Mapping');
        if ( !$Kernel::OM->Get('Main')->Require($MappingModule) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message => "Can't load module $MappingModule",
            );
            return;    # bail out, this will generate 500 Error
        }    
        my $MappingInObject = $MappingModule->new(
            DebuggerObject => $Self->{DebuggerObject},
            Operation      => $Operation,
            OperationType  => $ProviderConfig->{Operation}->{$Operation}->{Type},
            MappingConfig =>
                $ProviderConfig->{Operation}->{$Operation}->{MappingInbound},
        );

        # if mapping init failed, bail out
        if ( ref $MappingInObject ne $MappingModule ) {
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

    #
    # Execute actual operation.
    #
    my $OperationModule = $Kernel::OM->GetModuleFor('API::Operation');
    if ( !$Kernel::OM->Get('Main')->Require($OperationModule) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message => "Can't load module $OperationModule",
        );
        return;    # bail out, this will generate 500 Error
    }    

    my $OperationObject = $OperationModule->new(
        DebuggerObject          => $Self->{DebuggerObject},
        APIVersion              => $Webservice->{Config}->{APIVersion},
        Operation               => $Operation,
        OperationType           => $ProviderConfig->{Operation}->{$Operation}->{Type},
        WebserviceID            => $WebserviceID,
        AvailableMethods        => $ProcessRequestResult{AvailableMethods},
        OperationRouteMapping   => $ProcessRequestResult{ResourceOperationRouteMapping},
        AvailableMethods        => $ProcessRequestResult{AvailableMethods},
        RequestMethod           => $ProcessRequestResult{RequestMethod},
        CurrentRoute            => $ProcessRequestResult{Route},
        RequestURI              => $ProcessRequestResult{RequestURI},
        Authorization           => $Authorization,
    );

    # if operation init failed, bail out
    if ( ref $OperationObject ne $OperationModule ) {
        return $Self->_GenerateErrorResponse(
            %{$OperationObject},
        );
    }

    # execute the actual operation
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
        my $MappingModule = $Kernel::OM->GetModuleFor('API::Mapping');
        if ( !$Kernel::OM->Get('Main')->Require($MappingModule) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message => "Can't load module $MappingModule",
            );
            return;    # bail out, this will generate 500 Error
        }    
        my $MappingOutObject = $MappingModule->new(
            DebuggerObject => $Self->{DebuggerObject},
            Operation      => $Operation,
            OperationType  => $ProviderConfig->{Operation}->{$Operation}->{Type},
            MappingConfig =>
                $ProviderConfig->{Operation}->{$Operation}->{MappingOutbound},
        );

        # if mapping init failed, bail out
        if ( ref $MappingOutObject ne $MappingModule ) {
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
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
