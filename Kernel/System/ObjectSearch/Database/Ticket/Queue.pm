# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::Queue;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::Queue - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        QueueID => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','GT','GTE','LT','LTE'],
            ValueType      => 'NUMERIC'
        },
        Queue => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        MyQueues => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 0,
            Operators      => ['EQ'],
            ValueType      => 'NUMERIC'
        },
        HistoricMyQueues => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 0,
            Operators      => ['EQ'],
            ValueType      => 'NUMERIC'
        }
    };
}

sub AttributePrepare {
    my ( $Self, %Param ) = @_;

    # init Definition
    my %AttributeDefinition = (
        QueueID => {
            Column       => 'st.queue_id',
            ConditionDef => {
                ValueType => 'NUMERIC'
            }
        },
        Queue   => {
            Column       => 'tq.name',
            ConditionDef => {}
        }
    );

    # check for needed joins
    my $TableAliasTLP = 'tlp' . ( $Param{Flags}->{JoinMap}->{TranslationTicketQueue} // '' );
    my $TableAliasTL  = 'tl' . ( $Param{Flags}->{JoinMap}->{TranslationTicketQueue} // '' );
    my @SQLJoin = ();
    if ( $Param{Attribute} eq 'Queue' ) {
        if ( !$Param{Flags}->{JoinMap}->{TicketQueue} ) {
            push( @SQLJoin, 'INNER JOIN queue tq ON tq.id = st.queue_id' );

            $Param{Flags}->{JoinMap}->{TicketQueue} = 1;
        }

        if ( $Param{PrepareType} eq 'Sort' ) {
            if ( !defined( $Param{Flags}->{JoinMap}->{TranslationTicketQueue} ) ) {
                my $Count = $Param{Flags}->{TranslationJoinCounter}++;
                $TableAliasTLP .= $Count;
                $TableAliasTL  .= $Count;

                push( @SQLJoin, "LEFT OUTER JOIN translation_pattern $TableAliasTLP ON $TableAliasTLP.value = tq.name" );
                push( @SQLJoin, "LEFT OUTER JOIN translation_language $TableAliasTL ON $TableAliasTL.pattern_id = $TableAliasTLP.id AND $TableAliasTL.language = '$Param{Language}'" );

                $Param{Flags}->{JoinMap}->{TranslationTicketQueue} = $Count;
            }
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
    elsif ( $Param{PrepareType} eq 'Sort' ) {
        if ( $Param{Attribute} eq 'Queue' ) {
            $Attribute{Column} = 'LOWER(COALESCE(' . $TableAliasTL . '.value, tq.name))';
        }
    }

    return \%Attribute;
}

sub Search {
    my ( $Self, %Param ) = @_;

    if (
        ref( $Param{Search} ) eq 'HASH'
        && $Param{Search}->{Field}
        && (
            $Param{Search}->{Field} eq 'MyQueues'
            || $Param{Search}->{Field} eq 'HistoricMyQueues'
        )
    ) {
        # check params
        return if ( !$Self->_CheckSearchParams( %Param ) );

        my $TableAlias = 'st';
        my @SQLJoin = ();
        if ( $Param{Search}->{Field} eq 'HistoricMyQueues' ) {
            if ( !$Param{Flags}->{JoinMap}->{TicketHistoryChanged} ) {
                push( @SQLJoin, 'INNER JOIN ticket_history th ON th.ticket_id = st.id' );

                $Param{Flags}->{JoinMap}->{TicketHistoryChanged} = 1;
            }

            $TableAlias = 'th';
        }

        # get user preferences
        my %UserPreferences = $Kernel::OM->Get('User')->GetPreferences(
            UserID => $Param{UserID},
        );

        # prepare condition values
        my $ConditionValues = [];
        if ( defined( $UserPreferences{MyQueues} ) ) {
            $ConditionValues = $UserPreferences{MyQueues};
        }

        # prepare search values
        my $SearchValues = [];
        if ( !IsArrayRef( $Param{Search}->{Value} ) ) {
            push( @{ $SearchValues }, $Param{Search}->{Value} );
        }
        else {
            $SearchValues =  $Param{Search}->{Value};
        }

        # prepare conditions for search values
        my @Conditions;
        for my $SearchValue ( @{ $SearchValues } ) {
            # prepare condition for true value
            if ( $SearchValue ) {
                my $SearchCondition = $Self->_GetCondition(
                    Operator  => 'IN',
                    Column    => $TableAlias . '.queue_id',
                    ValueType => 'NUMERIC',
                    Value     => $ConditionValues,
                    Silent    => $Param{Silent}
                );
                return if ( !$SearchCondition );

                # add special condition
                push( @Conditions, $SearchCondition );
            }
            # prepare condition for false value
            else {
                my $SearchCondition = $Self->_GetCondition(
                    Operator  => '!IN',
                    Column    => $TableAlias . '.queue_id',
                    ValueType => 'NUMERIC',
                    Value     => $ConditionValues,
                    Silent    => $Param{Silent}
                );
                return if ( !$SearchCondition );

                # add special condition
                push( @Conditions, $SearchCondition );
            }
        }

        my $Condition;
        if ( scalar( @Conditions ) > 1 ) {
            $Condition = '(' . join( ' OR ', @Conditions ) . ')';
        }
        else {
            $Condition = $Conditions[0];
        }

        return if ( !$Condition );

        # return search def
        return {
            Where => [ $Condition ],
            Join  => \@SQLJoin,
        };
    }
    else {
        return $Self->SUPER::Search(%Param);
    }
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
