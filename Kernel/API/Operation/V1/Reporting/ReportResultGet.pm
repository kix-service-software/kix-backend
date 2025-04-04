# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Reporting::ReportResultGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Reporting::ReportResultGet - API ReportResult Get Operation backend

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
        'ReportID' => {
            DataType => 'NUMERIC',
            Required => 1
        },
        'ReportResultID' => {
            Type     => 'ARRAY',
            DataType => 'NUMERIC',
            Required => 1
        }
    }
}

=item Run()

perform ReportResultGet Operation. This function is able to return
one or more ReportResult entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            ReportResultID => 123       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            ReportResult => [
                {
                    ...
                },
                {
                    ...
                },
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @ReportResultList;

    # start loop
    foreach my $ReportResultID ( @{$Param{Data}->{ReportResultID}} ) {

        # get the ReportResult data
        my %ReportResultData = $Kernel::OM->Get('Reporting')->ReportResultGet(
            ID             => $ReportResultID,
            IncludeContent => $Param{Data}->{include}->{Content} ? 1 : 0,
        );

        if ( !%ReportResultData ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        if ( $Param{Data}->{include}->{Content} ) {
            # encode content base64
            $ReportResultData{Content} = MIME::Base64::encode_base64( $ReportResultData{Content} ),
        }

        # add
        push(@ReportResultList, \%ReportResultData);
    }

    if ( scalar(@ReportResultList) == 1 ) {
        return $Self->_Success(
            ReportResult => $ReportResultList[0],
        );
    }

    # return result
    return $Self->_Success(
        ReportResult => \@ReportResultList,
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
