# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Reporting::ReportDefinitionSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Reporting::ReportDefinitionSearch - API ReportDefinition Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform ReportDefinitionSearch Operation. This will return a ReportDefinition list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                           # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            ReportDefinition => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @ReportDefinitionDataList;

    my %ReportDefinitionList = $Kernel::OM->Get('Reporting')->ReportDefinitionList(
        Valid => 0,
    );

    # get already prepared ReportDefinition data from ReportDefinitionGet operation
    if ( IsHashRefWithData(\%ReportDefinitionList) ) {
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::Reporting::ReportDefinitionGet',
            SuppressPermissionErrors => 1,
            Data      => {
                ReportDefinitionID => join(',', sort keys %ReportDefinitionList),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{ReportDefinition} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{ReportDefinition}) ? @{$GetResult->{Data}->{ReportDefinition}} : ( $GetResult->{Data}->{ReportDefinition} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                ReportDefinition => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        ReportDefinition => [],
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
