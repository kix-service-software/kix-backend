# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Automation::JobExecPlanIDDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Automation::JobExecPlanIDDelete - API JobExecPlanID Delete Operation backend

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
        'ExecPlanID' => {
            DataType => 'NUMERIC',
            Type     => 'ARRAY',
            Required => 1
        },
    }
}

=item Run()

perform JobExecPlanIDDelete Operation. This will return {}.

    my $Result = $OperationObject->Run(
        Data => {
            ExecPlanID  => '...'
        }
    );

    $Result = {
        Message    => ''                      # in case of error
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # start loop
    foreach my $ExecPlanID ( @{$Param{Data}->{ExecPlanID}} ) {

        my $Found = $Kernel::OM->Get('Automation')->ExecPlanLookup(
            ID => $ExecPlanID,
        );

        if ( !$Found ) {
            return $Self->_Error(
                Code    => 'Object.NotFound',
                Message => "Exec plan with ID $ExecPlanID not found!",
            );
        }

        # unassign ExecPlan from Job 
        my $Success = $Kernel::OM->Get('Automation')->JobExecPlanDelete(
            JobID      => $Param{Data}->{JobID},
            ExecPlanID => $ExecPlanID,
            UserID     => $Self->{Authorization}->{UserID},
        );

        if ( !$Success ) {
            return $Self->_Error(
                Code    => 'Object.UnableToDelete',
            );
        }
    }

    # return result
    return $Self->_Success();
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
