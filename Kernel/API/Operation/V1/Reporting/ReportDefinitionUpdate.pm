# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Reporting::ReportDefinitionUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Reporting::ReportDefinitionUpdate - API ReportDefinition Update Operation backend

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
        'ReportDefinitionID' => {
            Required => 1
        },
        'ReportDefinition' => {
            Type => 'HASH',
            Required => 1
        },
    }
}

=item Run()

perform ReportDefinitionUpdate Operation. This will return the updated ReportDefinitionID.

    my $Result = $OperationObject->Run(
        Data => {
            ReportDefinitionID => 123,
            ReportDefinition  => {
                Type    => '...',                     # optional
                Name    => 'Item Name',               # optional
                Config  => {}                         # optional
                IsPeriodic => 0|1,                    # optional
                MaxReports => ...,                    # optional
                Comment => 'Comment',                 # optional
                ValidID => 1,                         # optional
            },
        },
    );


    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            ReportDefinitionID  => 123,       # ID of the updated ReportDefinition
        },
    };

=cut


sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim ReportDefinition parameter
    my $ReportDefinition = $Self->_Trim(
        Data => $Param{Data}->{ReportDefinition}
    );

    # check if ReportDefinition exists
    my %ReportDefinitionData = $Kernel::OM->Get('Reporting')->ReportDefinitionGet(
        ID => $Param{Data}->{ReportDefinitionID},
    );

    if ( !%ReportDefinitionData ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # check if ReportDefinition with the same name already exists
    if ( $ReportDefinition->{Name} ) {
        my $ReportDefinitionID = $Kernel::OM->Get('Reporting')->ReportDefinitionLookup(
            Name => $ReportDefinition->{Name},
        );
        if ( $ReportDefinitionID && $ReportDefinitionID != $Param{Data}->{ReportDefinitionID} ) {
            return $Self->_Error(
                Code    => 'Object.AlreadyExists',
                Message => "Cannot update report definition. Another report definition with the same name '$ReportDefinition->{Name}' already exists.",
            );
        }
    }

    # update ReportDefinition
    my $Success = $Kernel::OM->Get('Reporting')->ReportDefinitionUpdate(
        ID         => $Param{Data}->{ReportDefinitionID},
        DataSource => $ReportDefinition->{DataSource} || $ReportDefinitionData{DataSource},
        Name       => $ReportDefinition->{Name} || $ReportDefinitionData{Name},
        Config     => exists $ReportDefinition->{Config} ? $ReportDefinition->{Config} : $ReportDefinitionData{Config},
        IsPeriodic => exists $ReportDefinition->{IsPeriodic} ? $ReportDefinition->{IsPeriodic} : $ReportDefinitionData{IsPeriodic},
        MaxReports => exists $ReportDefinition->{MaxReports} ? $ReportDefinition->{MaxReports} : $ReportDefinitionData{MaxReports},
        Comment    => exists $ReportDefinition->{Comment} ? $ReportDefinition->{Comment} : $ReportDefinitionData{Comment},
        ValidID    => exists $ReportDefinition->{ValidID} ? $ReportDefinition->{ValidID} : $ReportDefinitionData{ValidID},
        UserID     => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
        );
    }

    # return result
    return $Self->_Success(
        ReportDefinitionID => 0 + $Param{Data}->{ReportDefinitionID},
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
