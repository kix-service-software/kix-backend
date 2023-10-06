# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::History;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::Ticket::Common
);

our @ObjectDependencies = (
    'Config',
    'Log',
);

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::History - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item GetSupportedAttributes()

defines the list of attributes this module is supporting

    my $AttributeList = $Object->GetSupportedAttributes();

    $Result = {
        Search => [ ],
        Sort   => [ ],
    };

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        Search => [
            'CreatedTypeID',
            'CreatedUserID',
            'CreatedStateID',
            'CreatedQueueID',
            'CreatedPriorityID',
            'CloseTime',
            'ChangeTime',
        ],
        Sort => [
            'CreatedTypeID',
            'CreatedUserID',
            'CreatedStateID',
            'CreatedQueueID',
            'CreatedPriorityID',
            'CloseTime',
            'ChangeTime',
        ]
    };
}


=item Search()

run this module and return the SQL extensions

    my $Result = $Object->Search(
        BoolOperator => 'AND' | 'OR',
        Search       => {}
    );

    $Result = {
        SQLWhere   => [ ],
    };

=cut

sub Search {
    my ( $Self, %Param ) = @_;
    my @SQLJoin;
    my @SQLWhere;

    # check params
    if ( !$Param{Search} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Search!",
        );
        return;
    }

    # map search attributes to table attributes
    my %AttributeMapping = (
        'CreatedTypeID'     => 'type_id',
        'CreatedStateID'    => 'state_id',
        'CreatedUserID'     => 'create_by',
        'CreatedQueueID'    => 'queue_id',
        'CreatedPriorityID' => 'priority_id',
    );

    # check if we have to add a join
    if ( !$Self->{ModuleData}->{AlreadyJoined} || !$Self->{ModuleData}->{AlreadyJoined}->{$Param{BoolOperator}} ) {
        if ( $Param{BoolOperator} eq 'OR') {
            push( @SQLJoin, 'LEFT OUTER JOIN ticket_history th_left ON st.id = th_left.ticket_id ' );
            push( @SQLJoin, 'RIGHT OUTER JOIN ticket_history th_right ON st.id = th_right.ticket_id ' );
        } else {
            push( @SQLJoin, 'INNER JOIN ticket_history th ON st.id = th.ticket_id ' );
        }
        $Self->{ModuleData}->{AlreadyJoined}->{$Param{BoolOperator}} = 1;
    }

    if ( $Param{Search}->{Field} =~ /(Change|Close)Time/ ) {

        # convert to unix time
        my $SystemTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
            String => $Param{Search}->{Value},
        );

        if ( !$SystemTime ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Invalid search value \"$Param{Search}->{Value}\" for $Param{Search}->{Field}!",
            );
            return;
        }

        my $Value = $Kernel::OM->Get('Time')->SystemTime2TimeStamp(
            SystemTime => $SystemTime,
        );

        my %OperatorMap = (
            'EQ'  => '=',
            'LT'  => '<',
            'GT'  => '>',
            'LTE' => '<=',
            'GTE' => '>='
        );

        if ( !$OperatorMap{$Param{Search}->{Operator}} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unsupported Operator $Param{Search}->{Operator}!",
            );
            return;
        }

        if ( $Param{Search}->{Field} eq 'CloseTime' ) {
            # get close state ids
            my @List = $Kernel::OM->Get('State')->StateGetStatesByType(
                StateType => ['closed'],
                Result    => 'ID',
            );
            my @StateID = (
                $Kernel::OM->Get('Ticket')->HistoryTypeLookup( Type => 'NewTicket' ),
                $Kernel::OM->Get('Ticket')->HistoryTypeLookup( Type => 'StateUpdate' )
            );
            if (@StateID) {
                if ( $Param{BoolOperator} eq 'OR') {
                    push( @SQLWhere, 'th_left.history_type_id IN ('.(join(', ', sort @StateID)).')' );
                    push( @SQLWhere, 'th_left.state_id IN ('.(join(', ', sort @List)).')' );
                    push( @SQLWhere, 'th_right.history_type_id IN ('.(join(', ', sort @StateID)).')' );
                    push( @SQLWhere, 'th_right.state_id IN ('.(join(', ', sort @List)).')' );
                } else {
                    push( @SQLWhere, 'th.history_type_id IN ('.(join(', ', sort @StateID)).')' );
                    push( @SQLWhere, 'th.state_id IN ('.(join(', ', sort @List)).')' );
                }
            }
        }

        if ( $Param{BoolOperator} eq 'OR') {
            push( @SQLWhere, 'th_left.create_time '.$OperatorMap{$Param{Search}->{Operator}}." '".$Value."' " );
            push( @SQLWhere, 'th_right.create_time '.$OperatorMap{$Param{Search}->{Operator}}." '".$Value."' " );
        } else {
            push( @SQLWhere, 'th.create_time '.$OperatorMap{$Param{Search}->{Operator}}." '".$Value."' " );
        }
    }
    else {
        # all other attributes
        if ( $Param{Search}->{Operator} eq 'EQ' ) {
            if ( $Param{BoolOperator} eq 'OR') {
                push( @SQLWhere, 'th_left.'.$AttributeMapping{$Param{Search}->{Field}}.' = '.$Param{Search}->{Value} );
                push( @SQLWhere, 'th_right.'.$AttributeMapping{$Param{Search}->{Field}}.' = '.$Param{Search}->{Value} );
            } else {
                push( @SQLWhere, 'th.'.$AttributeMapping{$Param{Search}->{Field}}.' = '.$Param{Search}->{Value} );
            }
        }
        elsif ( $Param{Search}->{Operator} eq 'IN' ) {
            if ( $Param{BoolOperator} eq 'OR') {
                push( @SQLWhere, 'th_left.'.$AttributeMapping{$Param{Search}->{Field}}.' IN ('.(join(',', @{$Param{Search}->{Value}})).')' );
                push( @SQLWhere, 'th_right.'.$AttributeMapping{$Param{Search}->{Field}}.' IN ('.(join(',', @{$Param{Search}->{Value}})).')' );
            } else {
                push( @SQLWhere, 'th.'.$AttributeMapping{$Param{Search}->{Field}}.' IN ('.(join(',', @{$Param{Search}->{Value}})).')' );
            }
        }
        else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unsupported Operator $Param{Search}->{Operator}!",
            );
            return;
        }

        # lookup history type id
        my $HistoryTypeID = $Kernel::OM->Get('Ticket')->HistoryTypeLookup(
            Type => 'NewTicket',
        );
        if ( $Param{BoolOperator} eq 'OR') {
            push( @SQLWhere, "th_left.history_type_id = $HistoryTypeID" );
            push( @SQLWhere, "th_right.history_type_id = $HistoryTypeID" );
        } else {
            push( @SQLWhere, "th.history_type_id = $HistoryTypeID" );
        }
    }

    return {
        SQLJoin  => \@SQLJoin,
        SQLWhere => \@SQLWhere,
    };
}

=item Sort()

run this module and return the SQL extensions

    my $Result = $Object->Sort(
        Attribute => '...'      # required
    );

    $Result = {
        SQLAttrs   => [ ],          # optional
        SQLOrderBy => [ ]           # optional
    };

=cut

sub Sort {
    my ( $Self, %Param ) = @_;

    # map search attributes to table attributes
    my @SQLJoin;
    my %AttributeMapping = (
        'ChangeTime'        => 'st.change_time',
        'CloseTime'         => 'th.create_time',
        'CreatedTypeID'     => 'th.type_id',
        'CreatedStateID'    => 'th.state_id',
        'CreatedUserID'     => 'th.create_by',
        'CreatedQueueID'    => 'th.queue_id',
        'CreatedPriorityID' => 'th.priority_id',
    );

    # check if we have to add a join
    if ( !$Self->{ModuleData}->{AlreadyJoined} || !$Self->{ModuleData}->{AlreadyJoined}->{AND} ) {
        push( @SQLJoin, 'INNER JOIN ticket_history th ON st.id = th.ticket_id' );
    }

    return {
        SQLAttrs => [
            $AttributeMapping{$Param{Attribute}}
        ],
        SQLOrderBy => [
            $AttributeMapping{$Param{Attribute}}
        ],
        SQLJoin  => \@SQLJoin
    };
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
