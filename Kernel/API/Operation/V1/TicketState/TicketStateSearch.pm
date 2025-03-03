# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::TicketState::TicketStateSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::TicketState::TicketStateGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::TicketState::TicketStateSearch - API TicketState Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform TicketStateSearch Operation. This will return a TicketState ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Message => '',                               # In case of an error
        Data    => {
            StateID => [ 1, 2, 3, 4 ],
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform TicketState search
    my %TicketStateList = $Kernel::OM->Get('State')->StateList(
        UserID => $Self->{Authorization}->{UserID},
        Valid => 0,
    );

	# get already prepared ticketstate data from TicketStateGet operation
    if ( IsHashRefWithData(\%TicketStateList) ) {
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::TicketState::TicketStateGet',
            SuppressPermissionErrors => 1,
            Data      => {
                StateID => join(',', sort keys %TicketStateList),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{TicketState} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{TicketState}) ? @{$GetResult->{Data}->{TicketState}} : ( $GetResult->{Data}->{TicketState} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                TicketState => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        TicketState => [],
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
