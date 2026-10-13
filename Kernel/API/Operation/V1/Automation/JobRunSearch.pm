# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Automation::JobRunSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Automation::JobRunSearch - API JobRun Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

sub Init {
    my ( $Self, %Param ) = @_;

    my $Result = $Self->SUPER::Init(%Param);

    $Self->{HandleSortInCORE} = 1;

    return $Result;
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
    }
}

=item Run()

perform JobRunSearch Operation. This will return a list of runs for the given Job.

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
            JobRun => [
                {}
                {}
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->{Search}->{JobRun}->{AND} //= [];
    push(
        @{ $Self->{Search}->{JobRun}->{AND} },
        {
            Field    => 'JobID',
            Operator => 'EQ',
            Value    => $Param{Data}->{JobID}
        }
    );

    my @JobRunList = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Automation_JobRun',
        Result     => 'ARRAY',
        Search     => $Self->{Search}->{JobRun},
        Limit      => $Self->{SearchLimit}->{JobRun} || $Self->{SearchLimit}->{'__COMMON'},
        Sort       => $Self->{Sort}->{JobRun}        || $Self->{DefaultSort}->{JobRun},
        UserType   => $Self->{Authorization}->{UserType},
        UserID     => $Self->{Authorization}->{UserID}
    );

    # get already prepared Run data from JobRunGet operation
    if ( IsArrayRefWithData(\@JobRunList) ) {
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::Automation::JobRunGet',
            SuppressPermissionErrors => 1,
            Data      => {
                JobID => $Param{Data}->{JobID},
                RunID => join(',', @JobRunList),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{JobRun} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{JobRun}) ? @{$GetResult->{Data}->{JobRun}} : ( $GetResult->{Data}->{JobRun} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                JobRun => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        JobRun => [],
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
