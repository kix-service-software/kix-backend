# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Automation::JobSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Automation::JobSearch - API Job Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform JobSearch Operation. This will return a Job list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                           # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            Job => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @JobDataList;

    my %JobList = $Kernel::OM->Get('Automation')->JobList(
        Valid => 0,
    );

    # get already prepared Job data from JobGet operation
    if ( IsHashRefWithData(\%JobList) ) {
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::Automation::JobGet',
            SuppressPermissionErrors => 1,
            Data      => {
                JobID => join(',', sort keys %JobList),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{Job} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{Job}) ? @{$GetResult->{Data}->{Job}} : ( $GetResult->{Data}->{Job} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                Job => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Job => [],
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
