# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::Type;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::Type - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        TypeID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','GT','GTE','LT','LTE'],
            ValueType    => 'NUMERIC'
        },
        Type => {
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
        TypeID => {
            Column    => 'st.type_id',
            ValueType => 'NUMERIC'
        },
        Type   => {
            Column    => 'tt.name'
        }
    );

    # check for needed joins
    my @SQLJoin = ();
    if ( $Param{Search}->{Field} eq 'Type' ) {
        if ( !$Param{Flags}->{JoinMap}->{TicketType} ) {
            push( @SQLJoin, 'INNER JOIN ticket_type tt ON tt.id = st.type_id' );

            $Param{Flags}->{JoinMap}->{TicketType} = 1;
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
    my $TableAliasTLP = 'tlp' . ( $Param{Flags}->{JoinMap}->{TranslationTicketType} // '' );
    my $TableAliasTL  = 'tl' . ( $Param{Flags}->{JoinMap}->{TranslationTicketType} // '' );
    my @SQLJoin = ();
    if ( $Param{Attribute} eq 'Type' ) {
        if ( !$Param{Flags}->{JoinMap}->{TicketType} ) {
            push( @SQLJoin, 'INNER JOIN ticket_type tt ON tt.id = st.type_id' );

            $Param{Flags}->{JoinMap}->{TicketType} = 1;
        }

        if ( !defined( $Param{Flags}->{JoinMap}->{TranslationTicketType} ) ) {
            my $Count = $Param{Flags}->{TranslationJoinCounter}++;
            $TableAliasTLP .= $Count;
            $TableAliasTL  .= $Count;

            push( @SQLJoin, "LEFT OUTER JOIN translation_pattern $TableAliasTLP ON $TableAliasTLP.value = tt.name" );
            push( @SQLJoin, "LEFT OUTER JOIN translation_language $TableAliasTL ON $TableAliasTL.pattern_id = $TableAliasTLP.id AND $TableAliasTL.language = '$Param{Language}'" );

            $Param{Flags}->{JoinMap}->{TranslationTicketType} = $Count;
        }
    }

    # init mapping
    my %AttributeMapping = (
        TypeID => {
            Select  => ['st.type_id'],
            OrderBy => ['st.type_id']
        },
        Type   => {
            Select  => ["LOWER(COALESCE($TableAliasTL.value, tt.name)) AS TranslateType"],
            OrderBy => ['TranslateType']
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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
