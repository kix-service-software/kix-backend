# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Provider;

use strict;
use warnings;

use URI::Escape;
use Time::HiRes qw(time);

use Kernel::System::VariableCheck qw(IsHashRefWithData IsInteger);
use Kernel::System::PerfLog qw(TimeDiff);

our @ObjectDependencies = (
    'Config',
    'Log',
    'Webservice',
);

use base qw(
    Kernel::API::Common
    Kernel::API::Provider::REST
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

    $Self->{Debug} = $Kernel::OM->Get('Config')->Get('API::Debug');
    $Self->{LogRequestContent}  = $Kernel::OM->Get('Config')->Get('API::Debug::LogRequestContent');
    $Self->{LogResponseContent} = $Kernel::OM->Get('Config')->Get('API::Debug::LogResponseContent');

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

    $Self->{RequestStartTime} = Time::HiRes::time();

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

    # store the webservice name for easy use
    $Self->{WebserviceName} = URI::Escape::uri_unescape($WebserviceName);

    $Webservice = $Kernel::OM->Get('Webservice')->WebserviceGet(
        Name => $Self->{WebserviceName},
    );

    if ( !IsHashRefWithData($Webservice) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message =>
                "Could not load web service configuration for web service at $RequestURI",
        );

        return;    # bail out, this will generate 500 Error
    }

    # Check if web service has valid state (we are explicitely using the numeric ID here to prevent additional executing time)
    if ( $Webservice->{ValidID} != 1 ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message =>
                "Web service '$Webservice->{Name}' is not valid and can not be loaded",
        );

        return;    # bail out, this will generate 500 Error
    }

    # store the configs for easy use
    $Self->{ProviderConfig}  = $Webservice->{Config}->{Provider};
    $Self->{TransportConfig} = $Self->{ProviderConfig}->{Transport}->{Config};

    # use max length from config
    my $LengthFromConfig = $Kernel::OM->Get('Config')->Get('API::Provider::Transport::MaxLength');
    if (IsInteger($LengthFromConfig) && $LengthFromConfig) {
        $Self->{TransportConfig}->{Config}->{MaxLength} = $LengthFromConfig;
    }

    # read request content
    my $ProcessedRequest = $Self->ProcessRequest();

    if ( $Self->{Debug} && $Self->{LogRequestContent} ) {
        use Data::Dumper;
        $Self->_Debug('', "Request Data: ".Data::Dumper::Dumper($ProcessedRequest->{Data}));
    }

    # If the request was not processed correctly, send error to client.
    if ( !$ProcessedRequest->{Success} ) {

        return $Self->_GenerateErrorResponse(
            %{$ProcessedRequest},
        );
    }

    # save for later use
    $Self->{RequestMethod} = $ProcessedRequest->{RequestMethod};

    # check authorization if needed
    my $Authorization;
    my $AuthorizationResult = $Self->CheckAuthorization();

    if (
        $ProcessedRequest->{RequestMethod} ne 'OPTIONS' &&
        !$AuthorizationResult->{Success} &&
        !$Self->{ProviderConfig}->{Operation}->{$ProcessedRequest->{Operation}}->{NoAuthorizationNeeded}
    ) {
        return $Self->_GenerateErrorResponse(
            %{$AuthorizationResult},
        );
    }
    else {
        $Authorization = $AuthorizationResult->{Data}->{Authorization};
    }

    # check if we have to respond to an OPTIONS request instead of executing the operation
    if ( $Self->{RequestMethod} && $Self->{RequestMethod} eq 'OPTIONS' ) {
        my $Data;

        # add information about each available method
        METHOD:
        foreach my $Method ( sort keys %{$ProcessedRequest->{AvailableMethods}} ) {

            # create an operation object for each allowed method and ask it for options
            my $Operation = $ProcessedRequest->{AvailableMethods}->{$Method}->{Operation};

            my $OperationModule = $Kernel::OM->GetModuleFor('API::Operation');
            if ( !$Kernel::OM->Get('Main')->Require($OperationModule) ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message => "Can't load module $OperationModule",
                );
                return;    # bail out, this will generate 500 Error
            }

            my $OperationObject = $OperationModule->new(
                APIVersion              => $Webservice->{Config}->{APIVersion},
                Operation               => $ProcessedRequest->{Operation},
                OperationType           => $Self->{ProviderConfig}->{Operation}->{$Operation}->{Type},
                WebserviceID            => $Webservice->{ID},
                AvailableMethods        => $ProcessedRequest->{AvailableMethods},
                OperationRouteMapping   => $ProcessedRequest->{ResourceOperationRouteMapping},
                ParentMethodOperationMapping => $ProcessedRequest->{ParentMethodOperationMapping},
                RequestMethod           => $Method,
                CurrentRoute            => $ProcessedRequest->{Route},
                RequestURI              => $ProcessedRequest->{RequestURI},
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
                # don't execute GET operation on collections
                # (atm we simply check if the OperationType ends with 'Search', that will cover all critical collections so far)
                if ( $Self->{ProviderConfig}->{Operation}->{$Operation}->{Type} !~ /Search$/ || $Method ne 'GET' ) {
                    my $OperationResult = $OperationObject->Run(
                        Data                => $ProcessedRequest->{Data},
                        PermissionCheckOnly => 1
                    );
                    if ( !$OperationResult->{Success} ) {
                        # only bail out if it's not a 403
                        if ( $OperationResult->{Code} ne 'Forbidden' ) {
                            return $Self->_GenerateErrorResponse(
                                %{$OperationResult},
                            );
                        }
                        next METHOD;
                    }
                }

                # get options from operation
                my $OptionsResult = $OperationObject->Options();
                my %OptionsData   = IsHashRefWithData($OptionsResult->{Data}) ? %{$OptionsResult->{Data}} : ();

                $Data->{Methods}->{$Method} = {
                    %OptionsData,
                    Route               => $ProcessedRequest->{AvailableMethods}->{$Method}->{Route},
                    AuthorizationNeeded => $Self->{ProviderConfig}->{Operation}->{$Operation}->{NoAuthorizationNeeded} ? 0 : 1,
                }
            }
        }

        # add information about sub-resources
        my $CurrentRoute = $ProcessedRequest->{Route};
        $CurrentRoute = '' if $CurrentRoute eq '/';
        my @ChildResources = grep(/^$CurrentRoute\/([:a-zA-Z_]+)$/g, values %{$ProcessedRequest->{ResourceOperationRouteMapping}});
        if ( @ChildResources ) {
            $Data->{Resources} = \@ChildResources;
        }

        if ( $Self->{Debug} && $Self->{LogResponseContent} ) {
            use Data::Dumper;
            $Self->_Debug('', "Response Data: ".Data::Dumper::Dumper($Data));
        }

        my $GeneratedResponse = $Self->GenerateResponse(
            Success => 1,
            Data    => $Data,
            Additional => {
                AddHeader => {
                    Allow => join(', ', sort keys %{$Data->{Methods}}),
                }
            }
        );

        if ( !$GeneratedResponse->{Success} ) {
            $Self->_Error(
                Code    => 'Provider.InternalError',
                Message => 'Response could not be sent',
                Data    => $GeneratedResponse->{ErrorMessage},
            );
        }

        return;
    }

    #
    # store user authorization info in object manager for usage in kernel packages
    #
    $Kernel::OM->{Authorization} = $Authorization;

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
        APIVersion                   => $Webservice->{Config}->{APIVersion},
        Operation                    => $ProcessedRequest->{Operation},
        OperationType                => $Self->{ProviderConfig}->{Operation}->{$ProcessedRequest->{Operation}}->{Type},
        WebserviceID                 => $Webservice->{ID},
        AvailableMethods             => $ProcessedRequest->{AvailableMethods},
        OperationRouteMapping        => $ProcessedRequest->{ResourceOperationRouteMapping},
        ParentMethodOperationMapping => $ProcessedRequest->{ParentMethodOperationMapping},
        AvailableMethods             => $ProcessedRequest->{AvailableMethods},
        RequestMethod                => $ProcessedRequest->{RequestMethod},
        CurrentRoute                 => $ProcessedRequest->{Route},
        RequestURI                   => $ProcessedRequest->{RequestURI},
        Authorization                => $Authorization,
    );

    # if operation init failed, bail out
    if ( ref $OperationObject ne $OperationModule ) {
        return $Self->_GenerateErrorResponse(
            %{$OperationObject},
        );
    }

    # execute the actual operation
    my $OperationResult = $OperationObject->Run(
        Data => $ProcessedRequest->{Data},
    );

    if ( $Self->{Debug} && $Self->{LogResponseContent} ) {
        use Data::Dumper;
        $Self->_Debug('', "Response Data: ".Data::Dumper::Dumper($OperationResult->{Data}));
    }

    if ( !$OperationResult->{Success} ) {
        return $Self->_GenerateErrorResponse(
            %{$OperationResult},
        );
    }

    #
    # Generate the actual response
    #

    my $GeneratedResponse = $Self->GenerateResponse(
        Success => 1,
        %{$OperationResult},
        DoNotSortAttributes => IsHashRefWithData($OperationObject->{OperationConfig}) ?
            $OperationObject->{OperationConfig}->{DoNotSortAttributes} : 0
    );

    if ( !$GeneratedResponse->{Success} ) {
        $Self->_Error(
            Code    => 'Provider.InternalError',
            Message => 'Response could not be sent',
            Data    => $GeneratedResponse->{ErrorMessage},
        );
    }

    $Self->_Debug('', sprintf "total execution time for \"%s %s\": %i ms", $ProcessedRequest->{RequestMethod}, $ProcessedRequest->{RequestURI}, (time() - $Self->{RequestStartTime}) * 1000);

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

    my $FunctionResult = $Self->GenerateResponse(
        %Param,
        Success => 0,
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
