# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Automation::ExecPlanUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Automation::ExecPlanUpdate - API ExecPlan Update Operation backend

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
            Required => 1
        },
        'ExecPlan' => {
            Type => 'HASH',
            Required => 1
        },
    }
}

=item Run()

perform ExecPlanUpdate Operation. This will return the updated ExecPlanID.

    my $Result = $OperationObject->Run(
        Data => {
            ExecPlanID => 123,
            ExecPlan  => {
                Type          => '...',                     # (optional)
                Name          => 'Item Name',               # (optional)
                Parameters => {                             # (optional) will be replaced entirely if given
                    Weekday => [0,2],                       # (optional) 0 = Sunday, 1 = Monday, ...
                    Time    => '10:00:00',                  # (optional)
                    Event   => [ 'TicketCreate', ...]       # (optional)
                },
                Comment       => 'Comment',                 # (optional)
                ValidID       => 1,                         # (optional)
            },
        },
    );


    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            ExecPlanID  => 123,       # ID of the updated ExecPlan
        },
    };

=cut


sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim ExecPlan parameter
    my $ExecPlan = $Self->_Trim(
        Data => $Param{Data}->{ExecPlan}
    );

    # check if ExecPlan exists
    my %ExecPlanData = $Kernel::OM->Get('Automation')->ExecPlanGet(
        ID => $Param{Data}->{ExecPlanID},
    );

    if ( !%ExecPlanData ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # check if ExecPlan with the same name already exists
    if ( $ExecPlan->{Name} ) {
        my $ExecPlanID = $Kernel::OM->Get('Automation')->ExecPlanLookup(
            Name => $ExecPlan->{Name},
        );
        if ( $ExecPlanID && $ExecPlanID != $Param{Data}->{ExecPlanID} ) {
            return $Self->_Error(
                Code    => 'Object.AlreadyExists',
                Message => "Cannot update exec plan. Another exec plan with the same name '$ExecPlan->{Name}' already exists.",
            );
        }
    }

    # update ExecPlan
    my $Success = $Kernel::OM->Get('Automation')->ExecPlanUpdate(
        ID          => $Param{Data}->{ExecPlanID},
        Type        => $ExecPlan->{Type} || $ExecPlanData{Type},
        Name        => $ExecPlan->{Name} || $ExecPlanData{Name},
        Parameters  => exists $ExecPlan->{Parameters} ? $ExecPlan->{Parameters} : $ExecPlanData{Parameters},
        Comment     => exists $ExecPlan->{Comment} ? $ExecPlan->{Comment} : $ExecPlanData{Comment},
        ValidID     => exists $ExecPlan->{ValidID} ? $ExecPlan->{ValidID} : $ExecPlanData{ValidID},
        UserID      => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate',
        );
    }

    # return result
    return $Self->_Success(
        ExecPlanID => 0 + $Param{Data}->{ExecPlanID},
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
