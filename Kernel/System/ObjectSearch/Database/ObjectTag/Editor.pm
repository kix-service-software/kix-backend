# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::ObjectTag::Editor;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::ObjectTag::Editor - attribute module for database object search

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
            Column          => 'ot.create_by',
            ValueType       => 'NUMERIC'
        },
        CreateBy   => {
            Column          => 'ot.create_by',
            ValueType       => 'NUMERIC'
## TODO: login based search instead of id
#            Column          => 'otcru.login',
#            CaseInsensitive => 1
        },
        ChangeByID => {
            Column          => 'ot.change_by',
            ValueType       => 'NUMERIC'
        },
        ChangeBy   => {
            Column          => 'ot.change_by',
            ValueType       => 'NUMERIC'
## TODO: login based search instead of id
#            Column    => 'otchu.login',
#            CaseInsensitive => 1
        }
    );

## TODO: login based search instead of id
#    # check for needed joins
#    my @SQLJoin = ();
#    if ( $Param{Search}->{Field} eq 'CreateBy' ) {
#        if ( !$Param{Flags}->{JoinMap}->{ObjectTagCreateBy} ) {
#            push( @SQLJoin, 'INNER JOIN users otcru ON ocru.id = ot.create_by' );
#
#            $Param{Flags}->{JoinMap}->{ObjectTagCreateBy} = 1;
#        }
#    }
#    elsif ( $Param{Search}->{Field} eq 'ChangeBy' ) {
#        if ( !$Param{Flags}->{JoinMap}->{ObjectTagChangeBy} ) {
#            push( @SQLJoin, 'INNER JOIN users otchu ON ochu.id = ot.change_by' );
#
#            $Param{Flags}->{JoinMap}->{ObjectTagChangeBy} = 1;
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
        if ( !$Param{Flags}->{JoinMap}->{ObjectTagCreateBy} ) {
            push( @SQLJoin, 'INNER JOIN users otcru ON otcru.id = ot.create_by' );

            $Param{Flags}->{JoinMap}->{ObjectTagCreateBy} = 1;
        }
        if ( !$Param{Flags}->{JoinMap}->{ObjectTagCreateByContact} ) {
            push( @SQLJoin, 'LEFT OUTER JOIN contact otcruc ON otcruc.user_id = otcru.id' );

            $Param{Flags}->{JoinMap}->{ObjectTagCreateByContact} = 1;
        }
    }
    if ( $Param{Attribute} eq 'ChangeBy' ) {
        if ( !$Param{Flags}->{JoinMap}->{ObjectTagChangeBy} ) {
            push( @SQLJoin, 'INNER JOIN users otchu ON otchu.id = ot.change_by' );

            $Param{Flags}->{JoinMap}->{ObjectTagChangeBy} = 1;
        }
        if ( !$Param{Flags}->{JoinMap}->{ObjectTagChangeByContact} ) {
            push( @SQLJoin, 'LEFT OUTER JOIN contact otchuc ON otchuc.user_id = otchu.id' );

            $Param{Flags}->{JoinMap}->{ObjectTagChangeByContact} = 1;
        }
    }

    # map search attributes to table attributes
    my %AttributeMapping = (
        CreateByID => ['ot.create_by'],
        CreateBy   => ['LOWER(otcruc.lastname)','LOWER(otcruc.firstname)','LOWER(otcru.login)'],
        ChangeByID => ['ot.change_by'],
        ChangeBy   => ['LOWER(otchuc.lastname)','LOWER(otchuc.firstname)','LOWER(otchu.login)'],
    );

    return {
        Join    => \@SQLJoin,
        Select  => $AttributeMapping{ $Param{Attribute} },
        OrderBy => $AttributeMapping{ $Param{Attribute} }
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
