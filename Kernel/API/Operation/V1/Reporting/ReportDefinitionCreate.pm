# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Reporting::ReportDefinitionCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Reporting::ReportDefinitionCreate - API ReportDefinition Create Operation backend

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
        'ReportDefinition' => {
            Type     => 'HASH',
            Required => 1
        },
        'ReportDefinition::DataSource' => {
            Required => 1,
        },
        'ReportDefinition::Name' => {
            Required => 1
        },
        'ReportDefinition::Config' => {
            Type     => 'HASH',
            Required => 1
        },
        'ReportDefinition::Config::DataSource' => {
            Type     => 'HASH',
            Required => 1
        },
    }
}

=item Run()

perform ReportDefinitionCreate Operation. This will return the created ReportDefinitionID.

    my $Result = $OperationObject->Run(
        Data => {
            ReportDefinition  => {
                Name       => 'Item Name',
                DataSource => '...',
                Config     => {...},                  # optional
                IsPeriodic => 0|1,                    # optional
                MaxReports => ...,                    # optional
                Comment    => 'Comment',              # optional
                ValidID    => 1,                      # optional
            },
        },
    );

    $Result = {
        Success => 1,                       # 0 or 1
        Code    => '',                      #
        Message => '',                      # in case of error
        Data    => {                        # result data payload after Operation
            ReportDefinitionID  => '',    # ID of the created ReportDefinition
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim ReportDefinition parameter
    my $ReportDefinition = $Self->_Trim(
        Data => $Param{Data}->{ReportDefinition}
    );

    my $ReportDefinitionID = $Kernel::OM->Get('Reporting')->ReportDefinitionLookup(
        Name => $ReportDefinition->{Name},
    );

    if ( $ReportDefinitionID ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Cannot create report definition. A report definition with the same name '$ReportDefinition->{Name}' already exists.",
        );
    }

    # create ReportDefinition
    $ReportDefinitionID = $Kernel::OM->Get('Reporting')->ReportDefinitionAdd(
        Name       => $ReportDefinition->{Name},
        DataSource => $ReportDefinition->{DataSource},
        Config     => $ReportDefinition->{Config},
        IsPeriodic => $ReportDefinition->{IsPeriodic},
        MaxReports => $ReportDefinition->{MaxReports},
        Comment    => $ReportDefinition->{Comment} || '',
        ValidID    => $ReportDefinition->{ValidID} || 1,
        UserID     => $Self->{Authorization}->{UserID},
    );

    if ( !$ReportDefinitionID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
        );
    }

    # return result
    return $Self->_Success(
        Code   => 'Object.Created',
        ReportDefinitionID => 0 + $ReportDefinitionID,
    );
}


1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
