# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Reporting::OutputFormatSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Reporting::OutputFormatSearch - API Reporting Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform OutputFormatSearch Operation. This will return a list report types.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            OutputFormat => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # get formats
    my @OutputFormats = $Kernel::OM->Get('Reporting')->OutputFormatList();

	# get already prepared OutputFormat data from OutputFormatGet operation
    if ( IsArrayRefWithData(\@OutputFormats) ) {
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::Reporting::OutputFormatGet',
            SuppressPermissionErrors => 1,
            Data      => {
                OutputFormat => join(',', @OutputFormats),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{OutputFormat} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{OutputFormat}) ? @{$GetResult->{Data}->{OutputFormat}} : ( $GetResult->{Data}->{OutputFormat} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                OutputFormat => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        OutputFormat => [],
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
