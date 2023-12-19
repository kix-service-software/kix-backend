# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
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
        }
    };
}

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    # init mapping
    my %AttributeMapping = (
        QueueID => {
            Column    => 'st.queue_id',
            ValueType => 'NUMERIC'
        },
        Queue   => {
            Column    => 'tq.name'
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
    my $Condition = $Self->_GetCondition(
        Operator  => $Param{Search}->{Operator},
        Column    => $AttributeMapping{ $Param{Search}->{Field} }->{Column},
        ValueType => $AttributeMapping{ $Param{Search}->{Field} }->{ValueType},
        Value     => $Param{Search}->{Value},
        Silent    => $Param{Silent}
    );
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
