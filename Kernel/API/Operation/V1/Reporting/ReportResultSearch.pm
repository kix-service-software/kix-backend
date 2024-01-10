# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Reporting::ReportResultSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Reporting::ReportResultSearch - API ReportResult Search Operation backend

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
        'ReportID' => {
            DataType => 'NUMERIC',
            Required => 1
        },
    }
}

=item Run()

perform ReportResultSearch Operation. This will return a ReportResult list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                           # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            ReportResult => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @ReportResultList = $Kernel::OM->Get('Reporting')->ReportResultList(
        ReportID => $Param{Data}->{ReportID}
    );

    # get already prepared ReportResult data from ReportResultGet operation
    if ( IsArrayRefWithData(\@ReportResultList) ) {
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::Reporting::ReportResultGet',
            SuppressPermissionErrors => 1,
            Data      => {
                ReportDefinitionID => $Param{Data}->{ReportDefinitionID},
                ReportID           => $Param{Data}->{ReportID},
                ReportResultID     => join(',', @ReportResultList),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{ReportResult} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{ReportResult}) ? @{$GetResult->{Data}->{ReportResult}} : ( $GetResult->{Data}->{ReportResult} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                ReportResult => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        ReportResult => [],
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
