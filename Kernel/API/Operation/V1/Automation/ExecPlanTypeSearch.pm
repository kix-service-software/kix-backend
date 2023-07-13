# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Automation::ExecPlanTypeSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Automation::ExecPlanTypeSearch - API Automation Execution Plan Type Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform ExecPlanTypeSearch Operation. This will return a list macro types.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            ExecPlanType => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # get ExecPlan types
    my $ExecPlanTypes = $Kernel::OM->Get('Config')->Get('Automation::ExecPlanType');

	# get already prepared ExecPlanType data from ExecPlanTypeGet operation
    if ( IsHashRefWithData($ExecPlanTypes) ) {
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::Automation::ExecPlanTypeGet',
            SuppressPermissionErrors => 1,
            Data      => {
                ExecPlanType => join(',', sort keys %{$ExecPlanTypes}),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{ExecPlanType} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{ExecPlanType}) ? @{$GetResult->{Data}->{ExecPlanType}} : ( $GetResult->{Data}->{ExecPlanType} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                ExecPlanType => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        ExecPlanType => [],
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
