# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Queue::QueueGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Queue::QueueGet - API Queue Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1::Queue::QueueGet->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    # get config for this screen
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::Queue::QueueGet');

    return $Self;
}

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
            Type     => 'ARRAY',
            DataType => 'NUMERIC',
            Required => 1
        }                
    }
}

=item Run()

perform QueueGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            QueueID => 123       # comma separated in case of multiple or arrayref (depending on transport)
            include => '...',    # Optional, 0 as default. Include additional objects
                                 # (supported: TicketStats, Tickets)
            expand  => 0,        # Optional, 0 as default. Expand referenced objects
                                 # (supported: Tickets)             
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            Queue => [
                {
                    "SystemAddressID":...,
                    "UnlockTimeout":...,
                    "ChangeTime": "...",
                    "Email": "...",
                    "Calendar": "",
                    "CreateTime": "...",
                    "ValidID": ...,
                    "QueueID": ...,
                    "FollowUpLock": ...,
                    "Comment": "...",
                    "ParentID": ...,
                    "DefaultSignKey": ...,
                    "FollowUpID": ...,
                    "Name": "...",
                    "RealName": "...",
                    "Signature": "...",
                    # If Include=TicketStats was passed, you'll get an entry like this:
                    "TicketStats": {
                        "EscalatedCount":...,
                        "OpenCount":...,
                        "LockCount":...
                    }
                    # If include=Tickets => 1 was passed, you'll get an entry like this for each tickets:
                    Tickets => [
                        <TicketID>
                        # . . .
                    ]                            
                    # If include=Tickets => 1 AND expand=Tickets => 1 was passed, you'll get an entry like this for each tickets:
                    Tickets => [
                        {
                            ...,
                        },
                    ]                    
                }
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @QueueList;

    # start loop
    foreach my $QueueID ( @{$Param{Data}->{QueueID}} ) {

        # get the Queue data
        my %QueueData = $Kernel::OM->Get('Kernel::System::Queue')->QueueGet(
            ID => $QueueID,
        );

        my @ParentQueueParts = split(/::/, $QueueData{Name});

        if ( !IsHashRefWithData( \%QueueData ) ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }
        # include SubQueues if requested
        if ( $Param{Data}->{include}->{SubQueues} ) {
            my %SubQueueList = $Kernel::OM->Get('Kernel::System::Queue')->GetAllSubQueues(
                QueueID => $QueueID,
            );

            # filter direct children
            my @DirectSubQueues;
            foreach my $SubQueueID ( sort keys %SubQueueList ) {
                my @QueueParts = split(/::/, $SubQueueList{$SubQueueID});
                next if scalar(@QueueParts) > scalar(@ParentQueueParts)+1;
                push(@DirectSubQueues, $SubQueueID)
            }

            $QueueData{SubQueues} = \@DirectSubQueues;
        }

        # save full queue name
        $QueueData{Fullname} = $QueueData{Name};

        # remove hierarchy from name (use last element of name split)
        $QueueData{Name} = pop @ParentQueueParts;

        # add "pseudo" ParentID
        if ( scalar(@ParentQueueParts) > 0 ) {            
            $QueueData{ParentID} = 0 + $Kernel::OM->Get('Kernel::System::Queue')->QueueLookup(
                Queue => join('::', @ParentQueueParts),
            );
        }
        else {
            $QueueData{ParentID} = undef;
        }

        # include Tickets if requested
        if ( $Param{Data}->{include}->{Tickets} ) {
            # execute ticket search
            my @TicketIDs = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(
                Search => {
                    AND => [
                        {
                            Field    => 'QueueID',
                            Operator => 'EQ',
                            Value    => $QueueID,
                        }
                    ]
                },
                UserID => $Self->{Authorization}->{UserID},
                Result => 'ARRAY',
            );
            $QueueData{Tickets} = \@TicketIDs;

            # inform API caching about a new dependency
            $Self->AddCacheDependency(Type => 'Ticket');
        }

        # include TicketStats if requested
        if ( $Param{Data}->{include}->{TicketStats} ) {

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

            # add TicketStatsFilter to cache key to make this request specific
            $Self->AddCacheKeyExtension(
                Extension => [ $TicketStatsFilter ]
            );

            # execute ticket searches
            my %TicketStats;
            my @Filter;
            
            # locked tickets
            @Filter = (
                {
                    Field    => 'QueueID',
                    Operator => 'EQ',
                    Value    => $QueueID,
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
            $TicketStats{LockCount} = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(
                Search => {
                    AND => \@Filter
                },
                UserID => $Self->{Authorization}->{UserID},
                Result => 'COUNT',
            );

            # all relevant tickets
            @Filter = (
                {
                    Field    => 'QueueID',
                    Operator => 'EQ',
                    Value    => $QueueID,
                },
            );
            if ( IsHashRefWithData($TicketStatsFilter) ) {
                push(@Filter, $TicketStatsFilter);
            }
            $TicketStats{TotalCount} = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(
                Search => {
                    AND => \@Filter
                },
                UserID => $Self->{Authorization}->{UserID},
                Result => 'COUNT',
            );
            
            # escalated tickets
            @Filter = (
                {
                    Field    => 'QueueID',
                    Operator => 'EQ',
                    Value    => $QueueID,
                },
                {
                    Field    => 'EscalationTime',
                    Operator => 'LT',
                    DataType => 'NUMERIC',
                    Value    => $Kernel::OM->Get('Kernel::System::Time')->CurrentTimestamp(),
                },
            );
            if ( IsHashRefWithData($TicketStatsFilter) ) {
                push(@Filter, $TicketStatsFilter);
            }
            $TicketStats{EscalatedCount} = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(
                Search => {
                    AND => \@Filter
                },
                
                UserID => $Self->{Authorization}->{UserID},
                Result => 'COUNT',
            );
            
            # force numeric values
            foreach my $Key (keys %TicketStats) {
                $TicketStats{$Key} = 0 + $TicketStats{$Key};
            }
            $QueueData{TicketStats} = \%TicketStats;

            # inform API caching about a new dependency
            $Self->AddCacheDependency(Type => 'Ticket');
        }

        # add
        push(@QueueList, \%QueueData);
    }

    if ( scalar(@QueueList) == 1 ) {
        return $Self->_Success(
            Queue => $QueueList[0],
        );    
    }

    # return result
    return $Self->_Success(
        Queue => \@QueueList,
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
