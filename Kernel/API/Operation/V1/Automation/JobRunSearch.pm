# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
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

    my @JobRunDataList;

    my %JobRunList = $Kernel::OM->Get('Kernel::System::Automation')->JobRunList(
        JobID => $Param{Data}->{JobID},
    );

    # get already prepared Run data from JobRunGet operation
    if ( IsHashRefWithData(\%JobRunList) ) {
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::Automation::JobRunGet',
            SuppressPermissionErrors => 1,
            Data      => {
                JobID => $Param{Data}->{JobID},
                RunID => join(',', sort keys %JobRunList),
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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
