# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
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
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 0,
            Operators      => ['EQ','LT','LTE','GT','GTE'],
            ValueType      => 'DATETIME'
        },
        CloseTime         => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 0,
            Operators      => ['EQ','LT','LTE','GT','GTE'],
            ValueType      => 'DATETIME'
        },
        CreatedPriorityID => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType      => 'NUMERIC'
        },
        CreatedQueueID    => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType      => 'NUMERIC'
        },
        CreatedStateID    => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType      => 'NUMERIC'
        },
        CreatedTypeID     => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType      => 'NUMERIC'
        }
    };
}

sub AttributePrepare {
    my ( $Self, %Param ) = @_;

    # init mapping
    my %AttributeDefinition = (
        ChangeTime        => {
            Column       => 'th.create_time',
            ConditionDef => {}
        },
        CloseTime         => {
            Column       => 'thcl.create_time',
            ConditionDef => {}
        },
        CreatedPriorityID => {
            Column       => 'thcr.priority_id',
            ConditionDef => {
                ValueType => 'NUMERIC'
            }
        },
        CreatedQueueID    => {
            Column       => 'thcr.queue_id',
            ConditionDef => {
                ValueType => 'NUMERIC'
            }
        },
        CreatedStateID    => {
            Column       => 'thcr.state_id',
            ConditionDef => {
                ValueType => 'NUMERIC'
            }
        },
        CreatedTypeID     => {
            Column       => 'thcr.type_id',
            ConditionDef => {
                ValueType => 'NUMERIC'
            }
        }
    );

    # handle joins
    my @SQLJoin = ();
    # handle joins for ChangeTime attribute
    if ( $Param{Attribute} eq 'ChangeTime' ) {
        if ( !$Param{Flags}->{JoinMap}->{TicketHistoryChanged} ) {
            push( @SQLJoin, 'INNER JOIN ticket_history th ON th.ticket_id = st.id' );

            $Param{Flags}->{JoinMap}->{TicketHistoryChanged} = 1;
        }
    }
    # handle joins for CloseTime attribute
    elsif ( $Param{Attribute} eq 'CloseTime' ) {
        if ( !$Param{Flags}->{JoinMap}->{TicketHistoryClose} ) {
            push( @SQLJoin, 'LEFT OUTER JOIN ticket_history thcl ON thcl.ticket_id = st.id' );
            push( @SQLJoin, 'INNER JOIN ticket_state thscl ON thscl.id = thcl.state_id' );
            push( @SQLJoin, 'INNER JOIN ticket_state_type thstcl ON thstcl.id = thscl.type_id AND thstcl.name = \'closed\'' );
            push( @SQLJoin, 'INNER JOIN ticket_history_type thtcl ON thtcl.id = thcl.history_type_id AND thtcl.name IN (\'NewTicket\',\'StateUpdate\')' );

            $Param{Flags}->{JoinMap}->{TicketHistoryClose} = 1;
        }
    }
    # handle joins for Created* attributes
    elsif ( $Param{Attribute} =~ /^Created.+$/ ) {
        if ( !$Param{Flags}->{JoinMap}->{TicketHistoryCreated} ) {
            push( @SQLJoin, 'INNER JOIN ticket_history thcr ON thcr.ticket_id = st.id' );
            push( @SQLJoin, 'INNER JOIN ticket_history_type thtcr ON thtcr.id = thcr.history_type_id AND thtcr.name = \'NewTicket\'' );

            $Param{Flags}->{JoinMap}->{TicketHistoryCreated} = 1;
        }
    }

    my %Attribute = (
        Column => $AttributeDefinition{ $Param{Attribute} }->{Column},
        SQLDef => {
            Join => \@SQLJoin,
        }
    );
    if ( $Param{PrepareType} eq 'Condition' ) {
        $Attribute{ConditionDef} = $AttributeDefinition{ $Param{Attribute} }->{ConditionDef};
    }

    return \%Attribute;
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
