# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Reporting::DataSourceSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Reporting::DataSourceSearch - API Reporting Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform DataSourceSearch Operation. This will return a list report types.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            DataSource => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # get types
    my @DataSources = $Kernel::OM->Get('Reporting')->DataSourceList();

	# get already prepared DataSource data from DataSourceGet operation
    if ( IsArrayRefWithData(\@DataSources) ) {
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::Reporting::DataSourceGet',
            SuppressPermissionErrors => 1,
            Data      => {
                DataSource => join(',', @DataSources),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{DataSource} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{DataSource}) ? @{$GetResult->{Data}->{DataSource}} : ( $GetResult->{Data}->{DataSource} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                DataSource => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        DataSource => [],
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
