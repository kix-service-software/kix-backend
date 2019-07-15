# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::TicketSearch::Database::History;

use strict;
use warnings;

use base qw(
    Kernel::System::Ticket::TicketSearch::Database::Common
);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::Ticket::TicketSearch::Database::History - attribute module for database ticket search

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
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need Search!",
        );
        return;
    }

    # map search attributes to table attributes
    my %AttributeMapping = (
        'CreatedTypeID'     => 'th.type_id',
        'CreatedStateID'    => 'th.state_id',
        'CreatedUserID'     => 'th.create_by',
        'CreatedQueueID'    => 'th.queue_id',
        'CreatedPriorityID' => 'th.priority_id',
    );

    my %JoinType = (
        'AND' => 'INNER',
        'OR'  => 'FULL OUTER'
    );

    # check if we have to add a join
    if ( !$Self->{ModuleData}->{AlreadyJoined} ) {
        push( @SQLJoin, $JoinType{$Param{BoolOperator}}.' JOIN ticket_history th ON st.id = th.ticket_id' );
        $Self->{ModuleData}->{AlreadyJoined} = 1;
    }

    if ( $Param{Search}->{Field} =~ /(Change|Close)Time/ ) {

        # convert to unix time
        my $Value = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
            String => $Param{Search}->{Value},
        );

        my %OperatorMap = (
            'EQ'  => '=',
            'LT'  => '<',
            'GT'  => '>',
            'LTE' => '<=',
            'GTE' => '>='
        );

        if ( !$OperatorMap{$Param{Search}->{Operator}} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Unsupported Operator $Param{Search}->{Operator}!",
            );
            return;
        }

        push( @SQLWhere, 'th.create_time '.$OperatorMap{$Param{Search}->{Operator}}." '".$Param{Search}->{Value}."'" );

        if ( $Param{Search}->{Field} eq 'CloseTime' ) {
            # get close state ids
            my @List = $Kernel::OM->Get('Kernel::System::State')->StateGetStatesByType(
                StateType => ['closed'],
                Result    => 'ID',
            );
            my @StateID = ( $Kernel::OM->Get('Kernel::System::Ticket')->HistoryTypeLookup( Type => 'NewTicket' ) );
            push( @StateID, $Kernel::OM->Get('Kernel::System::Ticket')->HistoryTypeLookup( Type => 'StateUpdate' ) );
            if (@StateID) {
                push( @SQLWhere, 'th.history_type_id IN ('.(join(', ', sort @StateID)).')' );
                push( @SQLWhere, 'th.state_id IN ('.(join(', ', sort @List)).')' );
            }
        }
    }
    else {
        # all other attributes
        if ( $Param{Search}->{Operator} eq 'EQ' ) {
            push( @SQLWhere, $AttributeMapping{$Param{Search}->{Field}}.' = '.$Param{Search}->{Value} );
        }
        elsif ( $Param{Search}->{Operator} eq 'IN' ) {
            push( @SQLWhere, $AttributeMapping{$Param{Search}->{Field}}.' IN ('.(join(',', @{$Param{Search}->{Value}})).')' );
        }
        else {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Unsupported Operator $Param{Search}->{Operator}!",
            );
            return;
        }

        # lookup history type id
        my $HistoryTypeID = $Kernel::OM->Get('Kernel::System::Ticket')->HistoryTypeLookup(
            Type => 'NewTicket',
        );
        push( @SQLWhere, "th.history_type_id = $HistoryTypeID" );
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
    my %AttributeMapping = (
        'ChangeTime'        => 'st.change_time',
        'CloseTime'         => 'th.create_time',
        'CreatedTypeID'     => 'th.type_id',
        'CreatedStateID'    => 'th.state_id',
        'CreatedUserID'     => 'th.create_by',
        'CreatedQueueID'    => 'th.queue_id',
        'CreatedPriorityID' => 'th.priority_id',
    );

    return {
        SQLAttrs => [
            $AttributeMapping{$Param{Attribute}}
        ],
        SQLOrderBy => [
            $AttributeMapping{$Param{Attribute}}
        ],
    };       
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
