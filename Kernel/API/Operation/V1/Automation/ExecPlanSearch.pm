# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Automation::ExecPlanSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Automation::ExecPlanSearch - API ExecPlan Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform ExecPlanSearch Operation. This will return a ExecPlan list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                           # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            ExecPlan => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @ExecPlanDataList;

    my %ExecPlanList = $Kernel::OM->Get('Automation')->ExecPlanList(
        Valid => 0,
    );

    # get already prepared ExecPlan data from ExecPlanGet operation
    if ( IsHashRefWithData(\%ExecPlanList) ) {
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::Automation::ExecPlanGet',
            SuppressPermissionErrors => 1,
            Data      => {
                ExecPlanID => join(',', sort keys %ExecPlanList),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{ExecPlan} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{ExecPlan}) ? @{$GetResult->{Data}->{ExecPlan}} : ( $GetResult->{Data}->{ExecPlan} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                ExecPlan => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        ExecPlan => [],
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
