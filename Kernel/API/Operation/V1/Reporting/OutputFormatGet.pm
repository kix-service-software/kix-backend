# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Reporting::OutputFormatGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Reporting::OutputFormatGet - API Reporting Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item ParameterDefinition()

define parameter preparation and check for this operation

    my $Result = $OperationObject->ParameterDefinition(
        Data => {
            ...
        },
    );

    $Result = {
        ...
    };

=cut

sub ParameterDefinition {
    my ( $Self, %Param ) = @_;

    return {
        'OutputFormat' => {
            Type     => 'ARRAY',
            Required => 1
        }
    }
}

=item Run()

perform ReportDefinitionGet Operation. This function is able to return
one or more entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            OutputFormat => 'TimeBased'       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            OutputFormat => [
                {
                    ...
                },
                {
                    ...
                },
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;
    my @Result;

    my $OutputFormats = $Kernel::OM->Get('Config')->Get('Reporting::OutputFormat');

    # start loop
    foreach my $OutputFormat ( @{$Param{Data}->{OutputFormat}} ) {

	    # get the OutputFormat data
	    my %OutputFormatData = $Kernel::OM->Get('Reporting')->OutputFormatGet(
	        Name => $OutputFormat,
	    );

        if ( !%OutputFormatData ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # add some more data
        $OutputFormatData{Name}        = $OutputFormat;
        $OutputFormatData{DisplayName} = $OutputFormats->{$OutputFormat}->{DisplayName};

        # add
        push(@Result, \%OutputFormatData);
    }

    if ( scalar(@Result) == 1 ) {
        return $Self->_Success(
            OutputFormat => $Result[0],
        );
    }

    # return result
    return $Self->_Success(
        OutputFormat => \@Result,
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
