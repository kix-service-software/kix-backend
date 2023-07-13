# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::SystemAddress::SystemAddressSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::SystemAddress::SystemAddressGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::SystemAddress::SystemAddressSearch - API SystemAddress Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform SystemAddressSearch Operation. This will return a SystemAddress ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            SystemAddress => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform SystemAddress search
    my %SystemAddressList = $Kernel::OM->Get('SystemAddress')->SystemAddressList(
        Valid => 0,
    );

	# get already prepared SystemAddress data from SystemAddressGet operation
    if ( IsHashRefWithData(\%SystemAddressList) ) {
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::SystemAddress::SystemAddressGet',
            SuppressPermissionErrors => 1,
            Data      => {
                SystemAddressID => join(',', sort keys %SystemAddressList),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{SystemAddress} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{SystemAddress}) ? @{$GetResult->{Data}->{SystemAddress}} : ( $GetResult->{Data}->{SystemAddress} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                SystemAddress => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        SystemAddress => [],
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
