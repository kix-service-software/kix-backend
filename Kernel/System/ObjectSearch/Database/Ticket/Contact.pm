# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::Contact;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::Contact - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        ContactID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','GT','GTE','LT','LTE'],
            ValueType    => 'NUMERIC'
        },
        Contact => {
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
        ContactID => {
            Column    => 'st.contact_id',
            ValueType => 'NUMERIC',
        },
        Contact => {
            Column          => ['tcon.lastname','tcon.firstname'],
            CaseInsensitive => 1
        },
    );

    # check for needed joins
    my @SQLJoin = ();
    if ( $Param{Search}->{Field} eq 'Contact' ) {
        if ( !$Param{Flags}->{JoinMap}->{TicketContact} ) {
            push( @SQLJoin, 'LEFT OUTER JOIN contact tcon ON tcon.id = st.contact_id' );

            $Param{Flags}->{JoinMap}->{TicketContact} = 1;
        }
    }

    # prepare condition
    my $Condition = $Self->_GetCondition(
        Operator        => $Param{Search}->{Operator},
        Column          => $AttributeMapping{ $Param{Search}->{Field} }->{Column},
        ValueType       => $AttributeMapping{ $Param{Search}->{Field} }->{ValueType},
        Value           => $Param{Search}->{Value},
        NULLValue       => 1,
        CaseInsensitive => $AttributeMapping{ $Param{Search}->{Field} }->{CaseInsensitive},
        Silent          => $Param{Silent}
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
    if (
        $Param{Attribute} eq 'Contact'
    ) {
        if ( !$Param{Flags}->{JoinMap}->{TicketContact} ) {
            push( @SQLJoin, 'LEFT OUTER JOIN contact tcon ON tcon.id = st.contact_id' );

            $Param{Flags}->{JoinMap}->{TicketContact} = 1;
        }
    }

    # init mapping
    my %AttributeMapping = (
        ContactID => {
            Select  => ['st.contact_id'],
            OrderBy => ['st.contact_id']
        },
        Contact   => {
            Select  => ['tcon.lastname','tcon.firstname'],
            OrderBy => ['LOWER(tcon.lastname)','LOWER(tcon.firstname)']
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
