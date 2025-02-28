# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::StateType::StateTypeSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::StateType::StateTypeGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::StateType::StateTypeSearch - API StateType Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform StateTypeSearch Operation. This will return a StateType ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            StateType => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform StateType search
    my %StateTypeList = $Kernel::OM->Get('State')->StateTypeList(
        UserID => $Self->{Authorization}->{UserID},
        Valid => 1,
    );

	# get already prepared StateType data from StateTypeGet operation
    if ( IsHashRefWithData(\%StateTypeList) ) {
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::StateType::StateTypeGet',
            SuppressPermissionErrors => 1,
            Data      => {
                StateTypeID => join(',', sort keys %StateTypeList),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{StateType} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{StateType}) ? @{$GetResult->{Data}->{StateType}} : ( $GetResult->{Data}->{StateType} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                StateType => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        StateType => [],
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
