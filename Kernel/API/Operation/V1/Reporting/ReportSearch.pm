# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Reporting::ReportSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Reporting::ReportSearch - API Report Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform ReportSearch Operation. This will return a Report list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                           # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            Report => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # we don't do any core search filtering, inform the API to do it for us, based on the given search
    $Self->HandleSearchInAPI();

    my @ReportList = $Kernel::OM->Get('Reporting')->ReportList();

    # get already prepared Report data from ReportGet operation
    if ( IsArrayRefWithData(\@ReportList) ) {
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::Reporting::ReportGet',
            SuppressPermissionErrors => 1,
            Data      => {
                ReportDefinitionID => $Param{Data}->{ReportDefinitionID},
                ReportID           => join(',', @ReportList),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{Report} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{Report}) ? @{$GetResult->{Data}->{Report}} : ( $GetResult->{Data}->{Report} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                Report => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Report => [],
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
