# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::History;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::History - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        ChangeTime        => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','LT','LTE','GT','GTE'],
            ValueType    => 'DATETIME'
        },
        CloseTime         => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','LT','LTE','GT','GTE'],
            ValueType    => 'DATETIME'
        },
        CreatedPriorityID => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType    => 'NUMERIC'
        },
        CreatedQueueID    => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType    => 'NUMERIC'
        },
        CreatedStateID    => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType    => 'NUMERIC'
        },
        CreatedTypeID     => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType    => 'NUMERIC'
        }
    };
}

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    # init mapping
    my %AttributeMapping = (
        ChangeTime        => {
            Column    => 'th.create_time'
        },
        CloseTime         => {
            Column    => 'thcl.create_time'
        },
        CreatedPriorityID => {
            Column    => 'thcr.priority_id',
            ValueType => 'NUMERIC'
        },
        CreatedQueueID    => {
            Column    => 'thcr.queue_id',
            ValueType => 'NUMERIC'
        },
        CreatedStateID    => {
            Column    => 'thcr.state_id',
            ValueType => 'NUMERIC'
        },
        CreatedTypeID     => {
            Column    => 'thcr.type_id',
            ValueType => 'NUMERIC'
        }
    );

    # handle joins
    my @SQLJoin = ();
    # handle joins for ChangeTime attribute
    if ( $Param{Search}->{Field} eq 'ChangeTime' ) {
        if ( !$Param{Flags}->{JoinMap}->{TicketHistoryChanged} ) {
            push( @SQLJoin, 'INNER JOIN ticket_history th ON th.ticket_id = st.id' );

            $Param{Flags}->{JoinMap}->{TicketHistoryChanged} = 1;
        }
    }
    # handle joins for CloseTime attribute
    elsif ( $Param{Search}->{Field} eq 'CloseTime' ) {
        if ( !$Param{Flags}->{JoinMap}->{TicketHistoryClose} ) {
            push( @SQLJoin, 'LEFT OUTER JOIN ticket_history thcl ON thcl.ticket_id = st.id' );
            push( @SQLJoin, 'INNER JOIN ticket_state thscl ON thscl.id = thcl.state_id' );
            push( @SQLJoin, 'INNER JOIN ticket_state_type thstcl ON thstcl.id = thscl.type_id AND thstcl.name = \'closed\'' );
            push( @SQLJoin, 'INNER JOIN ticket_history_type thtcl ON thtcl.id = thcl.history_type_id AND thtcl.name IN (\'NewTicket\',\'StateUpdate\')' );

            $Param{Flags}->{JoinMap}->{TicketHistoryClose} = 1;
        }
    }
    # handle joins for Created* attributes
    elsif ( $Param{Search}->{Field} =~ /^Created.+$/ ) {
        if ( !$Param{Flags}->{JoinMap}->{TicketHistoryCreated} ) {
            push( @SQLJoin, 'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id' );
            push( @SQLJoin, 'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\'' );

            $Param{Flags}->{JoinMap}->{TicketHistoryCreated} = 1;
        }
    }

    # prepare condition
    my $Condition = $Self->_GetCondition(
        Operator  => $Param{Search}->{Operator},
        Column    => $AttributeMapping{ $Param{Search}->{Field} }->{Column},
        ValueType => $AttributeMapping{ $Param{Search}->{Field} }->{ValueType},
        Value     => $Param{Search}->{Value},
        Silent    => $Param{Silent}
    );

    # return search def
    return {
        Join       => \@SQLJoin,
        Where      => [ $Condition ],
        IsRelative => $Param{Search}->{IsRelative}
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
