# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Valid::ValidSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::Valid::ValidGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Valid::ValidSearch - API Valid Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform ValidSearch Operation. This will return a Valid ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            Valid => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform Valid search
    my %ValidList = $Kernel::OM->Get('Valid')->ValidList();

	# get already prepared Valid data from ValidGet operation
    if ( IsHashRefWithData(\%ValidList) ) {
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::Valid::ValidGet',
            SuppressPermissionErrors => 1,
            Data      => {
                ValidID => join(',', sort keys %ValidList),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{Valid} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{Valid}) ? @{$GetResult->{Data}->{Valid}} : ( $GetResult->{Data}->{Valid} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                Valid => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Valid => [],
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
