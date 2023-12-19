# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::OwnerResponsible;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::OwnerResponsible - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        OwnerID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','GT','GTE','LT','LTE'],
            ValueType    => 'NUMERIC'
        },
        Owner => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        ResponsibleID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','GT','GTE','LT','LTE'],
            ValueType    => 'NUMERIC'
        },
        Responsible => {
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
        OwnerID       => {
            Column    => 'st.user_id',
            ValueType => 'NUMERIC'
        },
        Owner         => {
            Column    => 'tou.login'
        },
        ResponsibleID => {
            Column    => 'st.responsible_user_id',
            ValueType => 'NUMERIC'
        },
        Responsible   => {
            Column    => 'tru.login'
        }
    );

    # check for needed joins
    my @SQLJoin = ();
    if ( $Param{Search}->{Field} eq 'Owner' ) {
        if ( !$Param{Flags}->{JoinMap}->{TicketOwner} ) {
            push( @SQLJoin, 'INNER JOIN users tou ON tou.id = st.user_id' );

            $Param{Flags}->{JoinMap}->{TicketOwner} = 1;
        }
    }
    elsif ( $Param{Search}->{Field} eq 'Responsible' ) {
        if ( !$Param{Flags}->{JoinMap}->{TicketResponsible} ) {
            push( @SQLJoin, 'INNER JOIN users tru ON tru.id = st.responsible_user_id' );

            $Param{Flags}->{JoinMap}->{TicketResponsible} = 1;
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
    my @SQLJoin = ();
    if ( $Param{Attribute} eq 'Owner' ) {
        if ( !$Param{Flags}->{JoinMap}->{TicketOwner} ) {
            push( @SQLJoin, 'INNER JOIN users tou ON tou.id = st.user_id' );

            $Param{Flags}->{JoinMap}->{TicketOwner} = 1;
        }
        if ( !$Param{Flags}->{JoinMap}->{TicketOwnerContact} ) {
            push( @SQLJoin, 'LEFT OUTER JOIN contact touc ON touc.user_id = tou.id' );

            $Param{Flags}->{JoinMap}->{TicketOwnerContact} = 1;
        }
    }
    if ( $Param{Attribute} eq 'Responsible' ) {
        if ( !$Param{Flags}->{JoinMap}->{TicketResponsible} ) {
            push( @SQLJoin, 'INNER JOIN users tru ON tru.id = st.responsible_user_id' );

            $Param{Flags}->{JoinMap}->{TicketResponsible} = 1;
        }
        if ( !$Param{Flags}->{JoinMap}->{TicketResponsibleContact} ) {
            push( @SQLJoin, 'LEFT OUTER JOIN contact truc ON truc.user_id = tru.id' );

            $Param{Flags}->{JoinMap}->{TicketResponsibleContact} = 1;
        }
    }

    # init mapping
    my %AttributeMapping = (
        OwnerID       => {
            Select  => ['st.user_id'],
            OrderBy => ['st.user_id']
        },
        Owner         => {
            Select  => ['touc.lastname','touc.firstname','tou.login'],
            OrderBy => ['LOWER(touc.lastname)','LOWER(touc.firstname)','LOWER(tou.login)']
        },
        ResponsibleID => {
            Select  => ['st.responsible_user_id'],
            OrderBy => ['st.responsible_user_id']
        },
        Responsible   => {
            Select  => ['truc.lastname','truc.firstname','tru.login'],
            OrderBy => ['LOWER(truc.lastname)','LOWER(truc.firstname)','LOWER(tru.login)']
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
