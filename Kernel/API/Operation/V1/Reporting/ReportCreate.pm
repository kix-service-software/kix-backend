# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Reporting::ReportCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Reporting::ReportCreate - API Report Create Operation backend

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

    my %Definitions = $Kernel::OM->Get('Reporting')->ReportDefinitionList(
        Valid => 1
    );

    return {
        'Report' => {
            Type     => 'HASH',
            Required => 1
        },
        'Report::DefinitionID' => {
            Required => 1,
            OneOf    => [ sort keys %Definitions ],
        },
        'Report::Config' => {
            Type     => 'HASH',
            Required => 1
        },
        'Report::Config::OutputFormats' => {
            Type     => 'ARRAY',
            Required => 1,
        },
    }
}

=item Run()

perform ReportCreate Operation. This will return the created ReportID.

    my $Result = $OperationObject->Run(
        Data => {
            Report  => {
                Parameters => {},           # optional
            },
        },
    );

    $Result = {
        Success => 1,                       # 0 or 1
        Code    => '',                      #
        Message => '',                      # in case of error
        Data    => {                        # result data payload after Operation
            ReportID  => '',    # ID of the created Report
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Report parameter
    my $Report = $Self->_Trim(
        Data => $Param{Data}->{Report}
    );

    # check output formats
    my %OutputFormats;
    if ( IsHashRefWithData($Kernel::OM->Get('Config')->Get('Reporting::OutputFormat')) ) {
        %OutputFormats = map { $_ => 1 } sort keys %{ $Kernel::OM->Get('Config')->Get('Reporting::OutputFormat') };
    }
    my %Definition = $Kernel::OM->Get('Reporting')->ReportDefinitionGet(
        ID => $Report->{DefinitionID},
    );
    foreach my $OutputFormat ( @{$Report->{Config}->{OutputFormats}} ) {
        if ( !$OutputFormats{$OutputFormat} ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => "Unknown output format \"$OutputFormat\"!"
            );
        }
        if ( IsHashRefWithData($Definition{Config}->{OutputFormats}) && !exists $Definition{Config}->{OutputFormats}->{$OutputFormat} ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => "Output format \"$OutputFormat\" isn't supported for this report definition!"
            );
        }
    }

    # create Report
    my $ReportID = $Kernel::OM->Get('Reporting')->ReportCreate(
        DefinitionID => $Report->{DefinitionID},
        Config       => $Report->{Config},
        UserID       => $Self->{Authorization}->{UserID}
    );

    if ( !$ReportID ) {
        return $Self->_Error(
            Code => 'Object.UnableToCreate',
        );
    }

    # return result
    return $Self->_Success(
        Code   => 'Object.Created',
        ReportID => 0 + $ReportID,
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
