# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Automation::JobUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Automation::JobUpdate - API Job Update Operation backend

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
        'JobID' => {
            Required => 1
        },
        'Job' => {
            Type => 'HASH',
            Required => 1
        },
    }
}

=item Run()

perform JobUpdate Operation. This will return the updated JobID.

    my $Result = $OperationObject->Run(
        Data => {
            JobID => 123,
            Job  => {
                Type          => 'Ticket',                  # (optional)
                Name          => 'Item Name',               # (optional)
                Filter        => [],                        # (optional)
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
            JobID  => 123,       # ID of the updated Job
        },
    };

=cut


sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Job parameter
    my $Job = $Self->_Trim(
        Data => $Param{Data}->{Job}
    );

    # check if Job exists
    my %JobData = $Kernel::OM->Get('Automation')->JobGet(
        ID => $Param{Data}->{JobID},
    );

    if ( !%JobData ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # do not update if only Exec is given
    if ( scalar(keys %{$Job}) > 1 || !$Job->{Exec} ) {

        # check if job with the same name already exists
        if ( $Job->{Name} ) {
            my $JobID = $Kernel::OM->Get('Automation')->JobLookup(
                Name => $Job->{Name},
            );
            if ( $JobID && $JobID != $Param{Data}->{JobID} ) {
                return $Self->_Error(
                    Code    => 'Object.AlreadyExists',
                    Message => "Cannot update job. Another job with the same name '$Job->{Name}' already exists.",
                );
            }
        }

        # update Job
        my $Success = $Kernel::OM->Get('Automation')->JobUpdate(
            ID             => $Param{Data}->{JobID},
            Type           => $Job->{Type} || $JobData{Type},
            IsAsynchronous => exists $Job->{IsAsynchronous} ? $Job->{IsAsynchronous} : $JobData{IsAsynchronous},
            Name           => $Job->{Name} || $JobData{Name},
            Filter         => exists $Job->{Filter} ? $Job->{Filter} : $JobData{Filter},
            Comment        => exists $Job->{Comment} ? $Job->{Comment} : $JobData{Comment},
            ValidID        => exists $Job->{ValidID} ? $Job->{ValidID} : $JobData{ValidID},
            UserID         => $Self->{Authorization}->{UserID},
        );

        if ( !$Success ) {
            return $Self->_Error(
                Code => 'Object.UnableToUpdate',
            );
        }
    }

    if ( $Job->{Exec} ) {
        my $Success = $Kernel::OM->Get('Automation')->JobExecute(
            ID     => $Param{Data}->{JobID},
            UserID => 1,
        );

        if ( !$Success ) {
            my $LogMessage = $Kernel::OM->Get('Log')->GetLogEntry(
                Type => 'error',
                What => 'Message',
            );
            return $Self->_Error(
                Code    => 'Object.ExecFailed',
                Message => "An error occured during job execution (error: $LogMessage).",
            );
        }
    }

    # return result
    return $Self->_Success(
        JobID => 0 + $Param{Data}->{JobID},
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
