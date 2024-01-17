# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Automation::ExecPlanCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Automation::ExecPlanCreate - API ExecPlan Create Operation backend

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
        'ExecPlan' => {
            Type     => 'HASH',
            Required => 1
        },
        'ExecPlan::Type' => {
            Required => 1,
        },
        'ExecPlan::Name' => {
            Required => 1
        },
    }
}

=item Run()

perform ExecPlanCreate Operation. This will return the created ExecPlanID.

    my $Result = $OperationObject->Run(
        Data => {
            ExecPlan  => {
                Name    => 'Item Name',
                Type    => '...',
                Parameters => {                    # optional
                    Weekday => [0,2],                  # optional 0 = Sunday, 1 = Monday, ...
                    Time    => '10:00:00',             # optional
                    Event   => [ 'TicketCreate', ...]  # optional
                },
                Comment => 'Comment',              # optional
                ValidID => 1,                      # optional
            },
        },
    );

    $Result = {
        Success => 1,                       # 0 or 1
        Code    => '',                      #
        Message => '',                      # in case of error
        Data    => {                        # result data payload after Operation
            ExecPlanID  => '',    # ID of the created ExecPlan
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim ExecPlan parameter
    my $ExecPlan = $Self->_Trim(
        Data => $Param{Data}->{ExecPlan}
    );

    my $ExecPlanID = $Kernel::OM->Get('Automation')->ExecPlanLookup(
        Name => $ExecPlan->{Name},
    );

    if ( $ExecPlanID ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Cannot create exec plan. An exec plan with the same name '$ExecPlan->{Name}' already exists.",
        );
    }

    # create ExecPlan
    $ExecPlanID = $Kernel::OM->Get('Automation')->ExecPlanAdd(
        Name       => $ExecPlan->{Name},
        Type       => $ExecPlan->{Type},
        Parameters => $ExecPlan->{Parameters},
        Comment    => $ExecPlan->{Comment} || '',
        ValidID    => $ExecPlan->{ValidID} || 1,
        UserID     => $Self->{Authorization}->{UserID},
    );

    if ( !$ExecPlanID ) {
        return $Self->_Error(
            Code => 'Object.UnableToCreate',
        );
    }

    # return result
    return $Self->_Success(
        Code   => 'Object.Created',
        ExecPlanID => $ExecPlanID,
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
