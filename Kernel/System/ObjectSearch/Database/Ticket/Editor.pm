# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::Editor;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::Editor - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        CreateByID => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType      => 'NUMERIC'
        },
        CreateBy => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType      => 'NUMERIC'
## TODO: login based search instead of id
#            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        ChangeByID => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType      => 'NUMERIC'
        },
        ChangeBy => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType      => 'NUMERIC'
## TODO: login based search instead of id
#            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        }
    };
}

sub AttributePrepare {
    my ( $Self, %Param ) = @_;

    # init Definition
    my %AttributeDefinition = (
        CreateByID => {
            Column       => 'st.create_by',
            ConditionDef => {
                ValueType => 'NUMERIC'
            }
        },
        CreateBy   => {
            Column       => 'st.create_by',
            SortColumn   => ['LOWER(tcruc.lastname)','LOWER(tcruc.firstname)','LOWER(tcru.login)'],
            ConditionDef => {
                ValueType => 'NUMERIC'
            }
## TODO: login based search instead of id
#            Column          => 'tcru.login',
#            CaseInsensitive => 1
        },
        ChangeByID => {
            Column       => 'st.change_by',
            ConditionDef => {
                ValueType => 'NUMERIC'
            }
        },
        ChangeBy   => {
            Column       => 'st.change_by',
            SortColumn   => ['LOWER(tchuc.lastname)','LOWER(tchuc.firstname)','LOWER(tchu.login)'],
            ConditionDef => {
                ValueType => 'NUMERIC'
            }
## TODO: login based search instead of id
#            Column          => 'tchu.login',
#            CaseInsensitive => 1
        }
    );

    my %Attribute = (
        Column => $AttributeDefinition{ $Param{Attribute} }->{ $Param{PrepareType} . 'Column' }
            || $AttributeDefinition{ $Param{Attribute} }->{Column},
    );
    if ( $Param{PrepareType} eq 'Condition' ) {
        $Attribute{ConditionDef} = $AttributeDefinition{ $Param{Attribute} }->{ConditionDef};

## TODO: login based search instead of id
#        # check for needed joins
#        my @SQLJoin = ();
#        if ( $Param{Attribute} eq 'CreateBy' ) {
#            if ( !$Param{Flags}->{JoinMap}->{TicketCreateBy} ) {
#                push( @SQLJoin, 'INNER JOIN users tcru ON tcru.id = st.create_by' );
#
#                $Param{Flags}->{JoinMap}->{TicketCreateBy} = 1;
#            }
#        }
#        elsif ( $Param{Attribute} eq 'ChangeBy' ) {
#            if ( !$Param{Flags}->{JoinMap}->{TicketChangeBy} ) {
#                push( @SQLJoin, 'INNER JOIN users tchu ON tchu.id = st.change_by' );
#
#                $Param{Flags}->{JoinMap}->{TicketChangeBy} = 1;
#            }
#        }
#
#        $Attribute{SQLDef}->{Join} = \@SQLJoin;
    }
    elsif ( $Param{PrepareType} eq 'Sort' ) {
        # check for needed joins
        my @SQLJoin = ();
        if ( $Param{Attribute} eq 'CreateBy' ) {
            if ( !$Param{Flags}->{JoinMap}->{TicketCreateBy} ) {
                push( @SQLJoin, 'INNER JOIN users tcru ON tcru.id = st.create_by' );

                $Param{Flags}->{JoinMap}->{TicketCreateBy} = 1;
            }
            if ( !$Param{Flags}->{JoinMap}->{TicketCreateByContact} ) {
                push( @SQLJoin, 'LEFT OUTER JOIN contact tcruc ON tcruc.user_id = tcru.id' );

                $Param{Flags}->{JoinMap}->{TicketCreateByContact} = 1;
            }
        }
        if ( $Param{Attribute} eq 'ChangeBy' ) {
            if ( !$Param{Flags}->{JoinMap}->{TicketChangeBy} ) {
                push( @SQLJoin, 'INNER JOIN users tchu ON tchu.id = st.change_by' );

                $Param{Flags}->{JoinMap}->{TicketChangeBy} = 1;
            }
            if ( !$Param{Flags}->{JoinMap}->{TicketChangeByContact} ) {
                push( @SQLJoin, 'LEFT OUTER JOIN contact tchuc ON tchuc.user_id = tchu.id' );

                $Param{Flags}->{JoinMap}->{TicketChangeByContact} = 1;
            }
        }

        $Attribute{SQLDef}->{Join} = \@SQLJoin;
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
