# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
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
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType    => 'NUMERIC'
        },
        CreateBy => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType    => 'NUMERIC'
## TODO: login based search instead of id
#            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        ChangeByID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType    => 'NUMERIC'
        },
        ChangeBy => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType    => 'NUMERIC'
## TODO: login based search instead of id
#            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        }
    };
}

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    # init mapping
    my %AttributeMapping = (
        CreateByID => {
            Column          => 'st.create_by',
            ValueType       => 'NUMERIC'
        },
        CreateBy   => {
            Column          => 'st.create_by',
            ValueType       => 'NUMERIC'
## TODO: login based search instead of id
#            Column          => 'tcru.login',
#            CaseInsensitive => 1
        },
        ChangeByID => {
            Column          => 'st.change_by',
            ValueType       => 'NUMERIC'
        },
        ChangeBy   => {
            Column          => 'st.change_by',
            ValueType       => 'NUMERIC'
## TODO: login based search instead of id
#            Column          => 'tchu.login',
#            CaseInsensitive => 1
        }
    );

## TODO: login based search instead of id
#    # check for needed joins
#    my @SQLJoin = ();
#    if ( $Param{Search}->{Field} eq 'CreateBy' ) {
#        if ( !$Param{Flags}->{JoinMap}->{TicketCreateBy} ) {
#            push( @SQLJoin, 'INNER JOIN users tcru ON tcru.id = st.create_by' );
#
#            $Param{Flags}->{JoinMap}->{TicketCreateBy} = 1;
#        }
#    }
#    elsif ( $Param{Search}->{Field} eq 'ChangeBy' ) {
#        if ( !$Param{Flags}->{JoinMap}->{TicketChangeBy} ) {
#            push( @SQLJoin, 'INNER JOIN users tchu ON tchu.id = st.change_by' );
#
#            $Param{Flags}->{JoinMap}->{TicketChangeBy} = 1;
#        }
#    }

    # prepare condition
    my $Condition = $Self->_GetCondition(
        Operator        => $Param{Search}->{Operator},
        Column          => $AttributeMapping{ $Param{Search}->{Field} }->{Column},
        ValueType       => $AttributeMapping{ $Param{Search}->{Field} }->{ValueType},
## TODO: login based search instead of id
#        CaseInsensitive => $AttributeMapping{ $Param{Search}->{Field} }->{CaseInsensitive},
        Value           => $Param{Search}->{Value},
        Silent          => $Param{Silent}
    );
    return if ( !$Condition );

    # return search def
    return {
## TODO: login based search instead of id
#        Join  => \@SQLJoin,
        Where => [ $Condition ]
    };
}

sub Sort {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSortParams( %Param ) );

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

    # init mapping
    my %AttributeMapping = (
        CreateByID => {
            Select  => ['st.create_by'],
            OrderBy => ['st.create_by']
        },
        CreateBy   => {
            Select  => ['tcruc.lastname','tcruc.firstname','tcru.login'],
            OrderBy => ['LOWER(tcruc.lastname)','LOWER(tcruc.firstname)','LOWER(tcru.login)']
        },
        ChangeByID => {
            Select  => ['st.change_by'],
            OrderBy => ['st.change_by']
        },
        ChangeBy   => {
            Select  => ['tchuc.lastname','tchuc.firstname','tchu.login'],
            OrderBy => ['LOWER(tchuc.lastname)','LOWER(tchuc.firstname)','LOWER(tchu.login)']
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
