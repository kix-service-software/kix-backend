# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
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
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','GT','GTE','LT','LTE'],
            ValueType    => 'NUMERIC'
        },
        Queue => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        MyQueues => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ'],
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
        QueueID  => {
            Column    => 'st.queue_id',
            ValueType => 'NUMERIC'
        },
        Queue    => {
            Column    => 'tq.name'
        },
        MyQueues => {
            Column    => 'st.queue_id',
            ValueType => 'NUMERIC'
        }
    );

    # check for needed joins
    my @SQLJoin = ();
    if ( $Param{Search}->{Field} eq 'Queue' ) {
        if ( !$Param{Flags}->{JoinMap}->{TicketQueue} ) {
            push( @SQLJoin, 'INNER JOIN queue tq ON tq.id = st.queue_id' );

            $Param{Flags}->{JoinMap}->{TicketQueue} = 1;
        }
    }


    # prepare condition
    my $Condition;
    # special handling for 'MyQueues'
    if ( $Param{Search}->{Field} eq 'MyQueues' ) {
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
                    Column    => $AttributeMapping{ $Param{Search}->{Field} }->{Column},
                    ValueType => $AttributeMapping{ $Param{Search}->{Field} }->{ValueType},
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
                    Column    => $AttributeMapping{ $Param{Search}->{Field} }->{Column},
                    ValueType => $AttributeMapping{ $Param{Search}->{Field} }->{ValueType},
                    Value     => $ConditionValues,
                    Silent    => $Param{Silent}
                );
                return if ( !$SearchCondition );

                # add special condition
                push( @Conditions, $SearchCondition );
            }
        }

        if ( scalar( @Conditions ) > 1 ) {
            $Condition = '(' . join( ' OR ', @Conditions ) . ')';
        }
        else {
            $Condition = $Conditions[0];
        }
    }
    # default handling
    else {
        $Condition = $Self->_GetCondition(
            Operator  => $Param{Search}->{Operator},
            Column    => $AttributeMapping{ $Param{Search}->{Field} }->{Column},
            ValueType => $AttributeMapping{ $Param{Search}->{Field} }->{ValueType},
            Value     => $Param{Search}->{Value},
            Silent    => $Param{Silent}
        );
    }
    return if ( !$Condition );

    # return search def
    return {
        Join  => \@SQLJoin,
        Where => [ $Condition ]
    };
}

sub Sort {
    my ( $Self, %Param ) = @_;


    # check params
    return if ( !$Self->_CheckSortParams( %Param ) );

    # check for needed joins
    my $TableAliasTLP = 'tlp' . ( $Param{Flags}->{JoinMap}->{TranslationTicketQueue} // '' );
    my $TableAliasTL  = 'tl' . ( $Param{Flags}->{JoinMap}->{TranslationTicketQueue} // '' );
    my @SQLJoin = ();
    if ( $Param{Attribute} eq 'Queue' ) {
        if ( !$Param{Flags}->{JoinMap}->{TicketQueue} ) {
            push( @SQLJoin, 'INNER JOIN queue tq ON tq.id = st.queue_id' );

            $Param{Flags}->{JoinMap}->{TicketQueue} = 1;
        }

        if ( !defined( $Param{Flags}->{JoinMap}->{TranslationTicketQueue} ) ) {
            my $Count = $Param{Flags}->{TranslationJoinCounter}++;
            $TableAliasTLP .= $Count;
            $TableAliasTL  .= $Count;

            push( @SQLJoin, "LEFT OUTER JOIN translation_pattern $TableAliasTLP ON $TableAliasTLP.value = tq.name" );
            push( @SQLJoin, "LEFT OUTER JOIN translation_language $TableAliasTL ON $TableAliasTL.pattern_id = $TableAliasTLP.id AND $TableAliasTL.language = '$Param{Language}'" );

            $Param{Flags}->{JoinMap}->{TranslationTicketQueue} = $Count;
        }
    }

    # init mapping
    my %AttributeMapping = (
        QueueID => {
            Select  => ['st.queue_id'],
            OrderBy => ['st.queue_id']
        },
        Queue   => {
            Select  => ["LOWER(COALESCE($TableAliasTL.value, tq.name)) AS TranslateQueue"],
            OrderBy => ['TranslateQueue']
        }
    );

    # return sort def
    return {
        Join    => \@SQLJoin,
        Select  => $AttributeMapping{ $Param{Attribute} }->{Select},
        OrderBy => $AttributeMapping{ $Param{Attribute} }->{OrderBy}
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
