# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Ticket::TicketSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Ticket::TicketSearch - API Ticket Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform TicketSearch Operation. This will return a ticket list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Code         => ''                                # In case of an error
        Message      => '',                               # In case of an error
        Data         => {
            Ticket => [
                {
                },
                {
                }
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->SetDefaultSort(
        Ticket => [ 
            { Field => 'CreateTime' },
        ]
    );

    # check for customer relevant ids if necessary
    if ($Self->{Authorization}->{UserType} eq 'Customer') {
        my $CustomerTicketIDList = $Self->_GetCustomerUserVisibleObjectIds(
            ObjectType             => 'Ticket',
            UserID                 => $Self->{Authorization}->{UserID},
            RelevantOrganisationID => $Param{Data}->{RelevantOrganisationID}
        );

        # return empty result if there are no assigned tickets for customer
        return $Self->_Success(
            Ticket => [],
        ) if (!IsArrayRefWithData($CustomerTicketIDList));

        # add tickets ids of customer to search as AND condition
        if ( !IsHashRefWithData($Self->{Search}->{Ticket}) ) {
            $Self->{Search}->{Ticket} = {};
        }
        if ( !IsArrayRefWithData($Self->{Search}->{Ticket}->{AND}) ) {
            $Self->{Search}->{Ticket}->{AND} = [
                { Field => 'TicketID', Operator => 'IN', Value => $CustomerTicketIDList }
            ];
        } else {
            push(
                @{$Self->{Search}->{Ticket}->{AND}},
                { Field => 'TicketID', Operator => 'IN', Value => $CustomerTicketIDList }
            );
        }
    }

    my $TicketObject = $Kernel::OM->Get('Ticket');

    my @TicketIndex = $TicketObject->TicketSearch(
        Result     => 'ARRAY',
        Search     => $Self->{Search}->{Ticket},
        Limit      => $Self->{SearchLimit}->{Ticket} || $Self->{SearchLimit}->{'__COMMON'},
        Sort       => $Self->{Sort}->{Ticket} || $Self->{DefaultSort}->{Ticket},
        UserType   => $Self->{Authorization}->{UserType},
        UserID     => $Self->{Authorization}->{UserID}
    );

   if ( @TicketIndex ) {

        # inform the API core of the total number of tickets
        $Self->SetTotalItemCount(
            Ticket => scalar @TicketIndex
        );
        
        # restrict data to the request window
        my %PagedResult = $Self->ApplyPaging(
            Ticket => \@TicketIndex
        );

        # get already prepared Ticket data from TicketGet operation
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::Ticket::TicketGet',
            SuppressPermissionErrors => 1,
            Data                     => {
                TicketID                    => join(',', @{$PagedResult{Ticket}}),
                include                     => $Param{Data}->{include},
                expand                      => $Param{Data}->{expand},
                NoDynamicFieldDisplayValues => $Param{Data}->{NoDynamicFieldDisplayValues}
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{Ticket} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{Ticket}) ? @{$GetResult->{Data}->{Ticket}} : ( $GetResult->{Data}->{Ticket} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                Ticket => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Ticket => [],
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
