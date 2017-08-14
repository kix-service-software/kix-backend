# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Common;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Common - Base class for all Operations

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Init()

initialize the operation by checking the webservice configuration

    my $Return = $CommonObject->Init(
        WebserviceID => 1,
    );

    $Return = {
        Success => 1,                       # or 0 in case of failure,
        ErrorMessage => 'Error Message',
    }

=cut

sub Init {
    my ( $Self, %Param ) = @_;

    # check needed
    if ( !$Param{WebserviceID} ) {
        return {
            Success      => 0,
            ErrorMessage => "Got no WebserviceID!",
        };
    }

    # get webservice configuration
    my $Webservice = $Kernel::OM->Get('Kernel::System::API::Webservice')->WebserviceGet(
        ID => $Param{WebserviceID},
    );

    if ( !IsHashRefWithData($Webservice) ) {
        return {
            Success => 0,
            ErrorMessage =>
                'Could not determine Web service configuration'
                . ' in Kernel::API::Operation::V1::Common::Init()',
        };
    }

    return {
        Success => 1,
    };
}

=item ParseParameters()

check given parameters and parse them according to type

    my $Return = $CommonObject->ParseParameters(
        Data   => {
            ...
        },
        Parameters => {
            <Parameter> => {
                Type          => 'ARRAY',               # optional
                Required      => 1,                     # optional
                RequiredIfNot => '<AltParameter>'       # optional
                Default       => ...                    # optional
                OneOf         => [...]                  # optional
            }
        }
    );

    $Return = {
        Success => 1,                       # or 0 in case of failure,
        ErrorMessage => 'Error Message',
    }

=cut

sub ParseParameters {
    my ( $Self, %Param ) = @_;
    my $Result = {
        Success => 1
    };

    # check needed stuff
    for my $Needed (qw(Data Parameters)) {
        if ( !$Param{$Needed} ) {
            return $Self->ReturnError(
                ErrorCode    => 'ParseParameters.MissingParameter',
                ErrorMessage => "ParseParameters: $Needed parameter is missing!",
            );
        }
    }

    foreach my $Parameter ( sort keys %{$Param{Parameters}} ) {
        
        # check requirement
        if ( $Param{Parameters}->{$Parameter}->{Required} && !exists($Param{Data}->{$Parameter}) ) {
            $Result->{Success} = 0;
            $Result->{ErrorMessage} = "ParseParameters: required parameter $Parameter is missing!",
            last;            
        }
        elsif ( $Param{Parameters}->{$Parameter}->{RequiredIfNot} && !exists($Param{Data}->{$Parameter}) && !exists($Param{Data}->{$Param{Parameters}->{$Parameter}->{RequiredIfNot}})) {            
            $Result->{Success} = 0;
            $Result->{ErrorMessage} = "ParseParameters: required parameter $Parameter or $Param{Parameters}->{$Parameter}->{RequiredIfNot} is missing!",
            last;            
        }

        # parse into arrayref if parameter value is scalar and ARRAY type is needed
        if ( $Param{Parameters}->{$Parameter}->{Type} eq 'ARRAY' && $Param{Data}->{$Parameter} && ref($Param{Data}->{$Parameter}) ne 'ARRAY' ) {
            $Param{Data}->{$Parameter} = [ split('\s*,\s*', $Param{Data}->{$Parameter}) ];
        }

        # set default value
        if ( !$Param{Data}->{$Parameter} && exists($Param{Parameters}->{$Parameter}->{Default}) ) {
            $Param{Data}->{$Parameter} = $Param{Parameters}->{$Parameter}->{Default}
        }
        
        # check valid values
        if ( exists($Param{Parameters}->{$Parameter}->{OneOf}) && ref($Param{Parameters}->{$Parameter}->{OneOf}) eq 'ARRAY' ) {
            if ( !grep(/^$Param{Data}->{$Parameter}$/g, @{$Param{Parameters}->{$Parameter}->{OneOf}}) ) {
                $Result->{Success} = 0;
                $Result->{ErrorMessage} = "ParseParameters: parameter $Parameter is not one of '".(join(',', @{$Param{Parameters}->{$Parameter}->{OneOf}}))."'!",
                last;                  
            }
        }
    }

    return $Result; 
}


=item ReturnError()

helper function to return an error message.

    my $Return = $CommonObject->ReturnError(
        ErrorCode    => Ticket.AccessDenied,
        ErrorMessage => 'You don't have rights to access this ticket',
    );

=cut

sub ReturnError {
    my ( $Self, %Param ) = @_;

    $Self->{DebuggerObject}->Error(
        Summary => $Param{ErrorCode},
        Data    => $Param{ErrorMessage},
    );

    # return structure
    return {
        Success      => 1,
        ErrorMessage => "$Param{ErrorCode}: $Param{ErrorMessage}",
        Data         => {
            Error => {
                ErrorCode    => $Param{ErrorCode},
                ErrorMessage => $Param{ErrorMessage},
            },
        },
    };
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
