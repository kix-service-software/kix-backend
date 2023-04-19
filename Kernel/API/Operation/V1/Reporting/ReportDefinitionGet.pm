# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Reporting::ReportDefinitionGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Reporting::ReportDefinitionGet - API ReportDefinition Get Operation backend

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
        'ReportDefinitionID' => {
            Type     => 'ARRAY',
            DataType => 'NUMERIC',
            Required => 1
        }
    }
}

=item Run()

perform ReportDefinitionGet Operation. This function is able to return
one or more ReportResult entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            ReportDefinitionID => 123       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            ReportDefinition => [
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

    my @ReportDefinitionList;

    my $ReportingObject = $Kernel::OM->Get('Reporting');

    # start loop
    foreach my $ReportDefinitionID ( @{$Param{Data}->{ReportDefinitionID}} ) {

	    # get the ReportDefinition data
	    my %ReportDefinitionData = $ReportingObject->ReportDefinitionGet(
	        ID => $ReportDefinitionID,
	    );

        if ( !%ReportDefinitionData ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # include Reports if requested
        if ( $Param{Data}->{include}->{Reports} ) {
            my $GetResult = $Self->ExecOperation(
                OperationType            => 'V1::Reporting::ReportSearch',
                SuppressPermissionErrors => 1,
                Data => {
                    search => {
                        Report => {
                            AND => [
                                {
                                    Field => 'DefinitionID',
                                    Operator => 'EQ',
                                    Value => $ReportDefinitionID
                                }
                            ]
                        }
                    }
                }
            );
            my @ResultList;
            if ( defined $GetResult->{Data}->{Report} ) {
                @ResultList = IsArrayRef($GetResult->{Data}->{Report}) ? @{$GetResult->{Data}->{Report}} : ( $GetResult->{Data}->{Report} );
            }
            $ReportDefinitionData{Reports} = \@ResultList;
        }

        # add
        push(@ReportDefinitionList, \%ReportDefinitionData);
    }

    if ( scalar(@ReportDefinitionList) == 1 ) {
        return $Self->_Success(
            ReportDefinition => $ReportDefinitionList[0],
        );
    }

    # return result
    return $Self->_Success(
        ReportDefinition => \@ReportDefinitionList,
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
