# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Queue::QueueTicketStatsSearch;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Queue::QueueTicketStatsSearch - API Queue TicketStats Search Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform QueueTicketStatsSearch Operation. This function returns a list of ticket stats.

    my $Result = $OperationObject->Run(
        Data => {
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            "TicketStats": [
                {
                    "QueueID": 123
                    "EscalatedCount":...,
                    "OpenCount":...,
                    "LockCount":...
                },
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # prepare search if given (only AND supported)
    my $QueueIDs;
    if ( IsArrayRefWithData($Self->{Search}->{TicketStats}->{AND})) {
        foreach my $SearchItem ( @{$Self->{Search}->{TicketStats}->{AND}} ) {
            # only support QueueID (EQ and IN)
            next if ($SearchItem->{Field} !~ /^(QueueID)$/g);
            next if ($SearchItem->{Operator} ne 'EQ' && $SearchItem->{Operator} ne 'IN');

            my $Value = $SearchItem->{Value};
            if ( $SearchItem->{Operator} eq 'EQ' ) {
                $Value = [ $Value ];
            }

            if ( !IsArrayRef($QueueIDs) ) {
                $QueueIDs = [];
            }

            push @{$QueueIDs}, @{$Value};
        }
    }

    my %QueueList = $Kernel::OM->Get('Queue')->QueueList(
        IDs   => $QueueIDs,
        Valid => 0
    );

    my @TicketStatsList;

    if ( $Param{Data}->{'TicketStats.StateType'} =~ /^(Open|Viewable)$/ ) {
        my %TicketStats = $Kernel::OM->Get('Ticket')->TicketIndexGetQueueStats(
            QueueIDs => $QueueIDs
        );
        @TicketStatsList = map { { %{$TicketStats{$_}}, QueueID => 0 + $_ } } keys %TicketStats;
    }
    else {
        foreach my $QueueID ( keys %QueueList ) {
            my $TicketStatsFilter;
            if ( $Param{Data}->{'TicketStats.StateType'} ) {
                $TicketStatsFilter = {
                    Field    => 'StateType',
                    Operator => 'IN',
                    Value    => [ split(/,/, $Param{Data}->{'TicketStats.StateType'}) ],
                };
            }
            elsif ( $Param{Data}->{'TicketStats.StateID'} ) {
                $TicketStatsFilter = {
                    Field    => 'StateID',
                    Operator => 'IN',
                    Value    => [ split(/,/, $Param{Data}->{'TicketStats.StateID'}) ],
                };
            }

            my %TicketStats = $Self->GetTicketStatsFromTicketSearch(
                QueueID           => $QueueID,
                TicketStatsFilter => $TicketStatsFilter
            );
            $TicketStats{QueueID} = $QueueID;
            push @TicketStatsList, \%TicketStats
        }
    }

    # return result
    return $Self->_Success(
        TicketStats => \@TicketStatsList,
    );
}

sub GetTicketStatsFromTicketSearch {
    my ( $Self, %Param ) = @_;

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
    if ( IsHashRefWithData($Param{TicketStatsFilter}) ) {
        push(@Filter, $Param{TicketStatsFilter});
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
    if ( IsHashRefWithData($Param{TicketStatsFilter}) ) {
        push(@Filter, $Param{TicketStatsFilter});
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
