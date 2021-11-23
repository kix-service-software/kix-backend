# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Automation::JobExecPlanIDCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Automation::JobExecPlanIDCreate - API Job ExecPlanID Create Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(WebserviceID )) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    return $Self;
}

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
        'ExecPlanID' => {
            Required => 1
        }
    }
}

=item Run()

perform JobExecPlanIDCreate Operation. This will return the ID of the assigned ExecPlan.

    my $Result = $OperationObject->Run(
        Data => {
            JobID   => 123,
            ExecPlanID => 321
        },
    );

    $Result = {
        Success => 1,                       # 0 or 1
        Code    => '',                      # 
        Message => '',                      # in case of error
        Data    => {                        # result data payload after Operation
            ExecPlanID  => '',    # ID of the assigned ExecPlan
            JobID       => '',    # ID of the relevant Job
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # assign ExecPlan to Job
    my $Result = $Kernel::OM->Get('Automation')->JobExecPlanAdd(
        JobID      => $Param{Data}->{JobID},
        ExecPlanID => $Param{Data}->{ExecPlanID},
        UserID     => $Self->{Authorization}->{UserID}
    );

    if ( !$Result ) {
        return $Self->_Error(
            Code => 'Object.UnableToCreate',
        );
    }
    
    # return result
    return $Self->_Success(
        Code       => 'Object.Created',
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
