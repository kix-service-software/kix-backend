# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Session::UserTicketsGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Session::UserTicketsGet - API User Tickets Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub Init {
    my ( $Self, %Param ) = @_;

    my $Result = $Self->SUPER::Init(%Param);

    $Self->{HandleSortInCORE} = 1;

    return $Result;
}

=item Run()

perform UserCountersGet Operation.

    my $Result = $OperationObject->Run(
        Data => {
        },
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Message => '',                               # In case of an error
        Data         => {
            Ticket => [
                ...
            ],
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;
    my %Counters;

    # get counters for user
    my @TicketIDs = $Kernel::OM->Get('User')->GetObjectIDsForCounter(
        Category => 'Ticket',
        Counter  => $Param{Data}->{Counter},
        UserID   => $Self->{Authorization}->{UserID},
    );

    # consider search and sort
    if ( @TicketIDs && (IsHashRefWithData($Self->{Search}->{Ticket}) || $Self->{Sort}->{Ticket}) ) {
        if ( !IsHashRefWithData($Self->{Search}->{Ticket}) ) {
            $Self->{Search}->{Ticket} = {};
        }
        if ( !IsArrayRefWithData($Self->{Search}->{Ticket}->{AND}) ) {
            $Self->{Search}->{Ticket}->{AND} = [
                { Field => 'TicketID', Operator => 'IN', Value => \@TicketIDs }
            ];
        } else {
            push(
                @{$Self->{Search}->{Ticket}->{AND}},
                { Field => 'TicketID', Operator => 'IN', Value => \@TicketIDs }
            );
        }

        @TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
            ObjectType => 'Ticket',
            Result     => 'ARRAY',
            Search     => $Self->{Search}->{Ticket},
            Limit      => $Self->{SearchLimit}->{Ticket} || $Self->{SearchLimit}->{'__COMMON'},
            Sort       => $Self->{Sort}->{Ticket} || $Self->{DefaultSort}->{Ticket},
            UserType   => $Self->{Authorization}->{UserType},
            UserID     => $Self->{Authorization}->{UserID},
        );
    }

    if ( @TicketIDs ) {

        # get already prepared Ticket data from TicketGet operation
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::Ticket::TicketGet',
            SuppressPermissionErrors => 1,
            Data                     => {
                TicketID                    => join(',', @TicketIDs),
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
