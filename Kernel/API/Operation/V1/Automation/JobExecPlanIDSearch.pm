# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Automation::JobExecPlanIDSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Automation::JobExecPlanIDSearch - API JobExecPlanID Search Operation backend

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
        'JobID' => {
            Required => 1
        },
    }
}

=item Run()

perform JobExecPlanIDSearch Operation. This will return a ID list of ExecPlans which are assigned to requested Job.

    my $Result = $OperationObject->Run(
        Data => {
            JobID => 123
        }
    );

    $Result = {
        Success => 1,                           # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            ExecPlanID => [
                1,
                2,
                ...
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @ExecPlanIDs = $Kernel::OM->Get('Automation')->JobExecPlanList(
        JobID => $Param{Data}->{JobID},
    );

    if ( IsArrayRefWithData(\@ExecPlanIDs) ) {
        return $Self->_Success(
            ExecPlanID => \@ExecPlanIDs,
        )
    }

    # return result
    return $Self->_Success(
        ExecPlanID => [],
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
