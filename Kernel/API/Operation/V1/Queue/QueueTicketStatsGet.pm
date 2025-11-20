# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Queue::QueueTicketStatsGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Queue::QueueTicketStatsGet - API Queue TicketStats Get Operation backend

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
        'QueueID' => {
            DataType => 'NUMERIC',
            Required => 1
        }
    }
}

=item Run()

perform QueueTicketStatsGet Operation. This function returns the ticket stats for a given queue.

    my $Result = $OperationObject->Run(
        Data => {
            QueueID => 123       # the relevant QueueID
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            "TicketStats": {
                "EscalatedCount":...,
                "OpenCount":...,
                "LockCount":...
            }
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my %TicketStats;

    if ( $Param{Data}->{'TicketStats.StateType'} =~ /^(Open|Viewable)$/ ) {
        %TicketStats = $Kernel::OM->Get('Ticket')->TicketIndexGetQueueStats(
            QueueID => $Param{Data}->{QueueID}
        );
        %TicketStats = %{$TicketStats{$Param{Data}->{QueueID}}};
    }
    else {
        %TicketStats = $Self->GetTicketStatsFromTicketSearch(
            QueueID   => $Param{Data}->{QueueID},
            StateType => $Param{Data}->{'TicketStats.StateType'},
            StateID   => $Param{Data}->{'TicketStats.StateID'},
        );
    }

    # return result
    return $Self->_Success(
        TicketStats => \%TicketStats,
    );
}

sub GetTicketStatsFromTicketSearch {
    my ( $Self, %Param ) = @_;

    my $TicketStatsFilter;
    if ( $Param{StateType} ) {
        $TicketStatsFilter = {
            Field    => 'StateType',
            Operator => 'IN',
            Value    => [ split(/,/, $Param{StateType}) ],
        };
    }
    elsif ( $Param{StateID} ) {
        $TicketStatsFilter = {
            Field    => 'StateID',
            Operator => 'IN',
            Value    => [ split(/,/, $Param{StateID}) ],
        };
    }

    # execute ticket searches
    my %TicketStats;
    my @Filter;

    # locked tickets
    @Filter = (
        {
            Field    => 'QueueID',
            Operator => 'EQ',
            Value    => $Param{QueueID},
        },
        {
            Field    => 'LockID',
            Operator => 'EQ',
            Value    => '2',
        },
    );
    if ( IsHashRefWithData($TicketStatsFilter) ) {
        push(@Filter, $TicketStatsFilter);
    }
    $TicketStats{LockCount} = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Ticket',
        Search     => {
            AND => \@Filter
        },
        UserID   => $Self->{Authorization}->{UserID},
        UserType => $Self->{Authorization}->{UserType},
        Result   => 'COUNT',
    );

    # all relevant tickets
    @Filter = (
        {
            Field    => 'QueueID',
            Operator => 'EQ',
            Value    => $Param{QueueID},
        },
    );
    if ( IsHashRefWithData($TicketStatsFilter) ) {
        push(@Filter, $TicketStatsFilter);
    }
    $TicketStats{TotalCount} = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Ticket',
        Search     => {
            AND => \@Filter
        },
        UserID   => $Self->{Authorization}->{UserID},
        UserType => $Self->{Authorization}->{UserType},
        Result   => 'COUNT',
    );

    # force numeric values
    foreach my $Key (keys %TicketStats) {
        $TicketStats{$Key} = 0 + $TicketStats{$Key};
    }

    return %TicketStats;
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
