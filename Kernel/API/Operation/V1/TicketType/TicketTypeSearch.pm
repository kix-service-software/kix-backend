# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::TicketType::TicketTypeSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::TicketType::TicketTypeGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::TicketType::TicketTypeSearch - API TicketType Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform TicketTypeSearch Operation. This will return a TicketType ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Message => '',                               # In case of an error
        Data    => {
            TypeID => [ 1, 2, 3, 4 ],
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # get tickettype list
    my %TicketTypeList = $Kernel::OM->Get('Type')->TypeList(
        Valid => 0
    );

    # get already prepared tickettype data from TicketTypeGet operation
    if ( IsHashRefWithData(\%TicketTypeList) ) {
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::TicketType::TicketTypeGet',
            SuppressPermissionErrors => 1,
            Data      => {
                TypeID => join(',', sort keys %TicketTypeList),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{TicketType} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{TicketType}) ? @{$GetResult->{Data}->{TicketType}} : ( $GetResult->{Data}->{TicketType} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                TicketType => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        TicketType => [],
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
