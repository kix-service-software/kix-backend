# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::ObjectTagLink::Editor;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::ObjectTagLink::Editor - attribute module for database object search

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
            Column          => 'otl.create_by',
            ValueType       => 'NUMERIC'
        },
        CreateBy   => {
            Column          => 'otl.create_by',
            ValueType       => 'NUMERIC'
## TODO: login based search instead of id
#            Column          => 'otlcru.login',
#            CaseInsensitive => 1
        },
        ChangeByID => {
            Column          => 'otl.change_by',
            ValueType       => 'NUMERIC'
        },
        ChangeBy   => {
            Column          => 'otl.change_by',
            ValueType       => 'NUMERIC'
## TODO: login based search instead of id
#            Column    => 'otlchu.login',
#            CaseInsensitive => 1
        }
    );

## TODO: login based search instead of id
#    # check for needed joins
#    my @SQLJoin = ();
#    if ( $Param{Search}->{Field} eq 'CreateBy' ) {
#        if ( !$Param{Flags}->{JoinMap}->{JoinOTLCreateBy} ) {
#            push( @SQLJoin, 'INNER JOIN users otlcru ON ocru.id = otl.create_by' );
#
#            $Param{Flags}->{JoinMap}->{JoinOTLCreateBy} = 1;
#        }
#    }
#    elsif ( $Param{Search}->{Field} eq 'ChangeBy' ) {
#        if ( !$Param{Flags}->{JoinMap}->{JoinOTLChangeBy} ) {
#            push( @SQLJoin, 'INNER JOIN users otlchu ON ochu.id = otl.change_by' );
#
#            $Param{Flags}->{JoinMap}->{JoinOTLChangeBy} = 1;
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
        if ( !$Param{Flags}->{JoinMap}->{JoinOTLCreateBy} ) {
            push( @SQLJoin, 'INNER JOIN users otlcru ON otlcru.id = otl.create_by' );

            $Param{Flags}->{JoinMap}->{JoinOTLCreateBy} = 1;
        }
        if ( !$Param{Flags}->{JoinMap}->{JoinOTLCreateByContact} ) {
            push( @SQLJoin, 'LEFT OUTER JOIN contact otlcruc ON otlcruc.user_id = otlcru.id' );

            $Param{Flags}->{JoinMap}->{JoinOTLCreateByContact} = 1;
        }
    }
    if ( $Param{Attribute} eq 'ChangeBy' ) {
        if ( !$Param{Flags}->{JoinMap}->{JoinOTLChangeBy} ) {
            push( @SQLJoin, 'INNER JOIN users otlchu ON otlchu.id = otl.change_by' );

            $Param{Flags}->{JoinMap}->{JoinOTLChangeBy} = 1;
        }
        if ( !$Param{Flags}->{JoinMap}->{JoinOTLChangeByContact} ) {
            push( @SQLJoin, 'LEFT OUTER JOIN contact otlchuc ON otlchuc.user_id = otlchu.id' );

            $Param{Flags}->{JoinMap}->{JoinOTLChangeByContact} = 1;
        }
    }

    # init mapping
    my %AttributeMapping = (
        CreateByID => {
            Select  => ['otl.create_by'],
            OrderBy => ['otl.create_by']
        },
        CreateBy   => {
            Select  => ['otlcruc.lastname','otlcruc.firstname','otlcru.login'],
            OrderBy => ['LOWER(otlcruc.lastname)','LOWER(otlcruc.firstname)','LOWER(otlcru.login)']
        },
        ChangeByID => {
            Select  => ['otl.change_by'],
            OrderBy => ['otl.change_by']
        },
        ChangeBy   => {
            Select  => ['otlchuc.lastname','otlchuc.firstname','otlchu.login'],
            OrderBy => ['LOWER(otlchuc.lastname)','LOWER(otlchuc.firstname)','LOWER(otlchu.login)']
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
