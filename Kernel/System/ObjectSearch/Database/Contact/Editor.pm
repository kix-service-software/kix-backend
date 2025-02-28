# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Contact::Editor;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Contact::Editor - attribute module for database object search

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
            Column          => 'c.create_by',
            ValueType       => 'NUMERIC'
        },
        CreateBy   => {
            Column          => 'c.create_by',
            ValueType       => 'NUMERIC'
## TODO: login based search instead of id
#            Column          => 'ccru.login',
#            CaseInsensitive => 1
        },
        ChangeByID => {
            Column          => 'c.change_by',
            ValueType       => 'NUMERIC'
        },
        ChangeBy   => {
            Column          => 'c.change_by',
            ValueType       => 'NUMERIC'
## TODO: login based search instead of id
#            Column    => 'cchu.login',
#            CaseInsensitive => 1
        }
    );

## TODO: login based search instead of id
#    # check for needed joins
#    my @SQLJoin = ();
#    if ( $Param{Search}->{Field} eq 'CreateBy' ) {
#        if ( !$Param{Flags}->{JoinMap}->{ContactCreateBy} ) {
#            push( @SQLJoin, 'INNER JOIN users ccru ON ccru.id = c.create_by' );
#
#            $Param{Flags}->{JoinMap}->{ContactCreateBy} = 1;
#        }
#    }
#    elsif ( $Param{Search}->{Field} eq 'ChangeBy' ) {
#        if ( !$Param{Flags}->{JoinMap}->{ContactChangeBy} ) {
#            push( @SQLJoin, 'INNER JOIN users cchu ON cchu.id = c.change_by' );
#
#            $Param{Flags}->{JoinMap}->{ContactChangeBy} = 1;
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
        if ( !$Param{Flags}->{JoinMap}->{ContactCreateBy} ) {
            push( @SQLJoin, 'INNER JOIN users ccru ON ccru.id = c.create_by' );

            $Param{Flags}->{JoinMap}->{ContactCreateBy} = 1;
        }
        if ( !$Param{Flags}->{JoinMap}->{ContactCreateByContact} ) {
            push( @SQLJoin, 'LEFT OUTER JOIN contact ccruc ON ccruc.user_id = ccru.id' );

            $Param{Flags}->{JoinMap}->{ContactCreateByContact} = 1;
        }
    }
    if ( $Param{Attribute} eq 'ChangeBy' ) {
        if ( !$Param{Flags}->{JoinMap}->{ContactChangeBy} ) {
            push( @SQLJoin, 'INNER JOIN users cchu ON cchu.id = c.change_by' );

            $Param{Flags}->{JoinMap}->{ContactChangeBy} = 1;
        }
        if ( !$Param{Flags}->{JoinMap}->{ContactChangeByContact} ) {
            push( @SQLJoin, 'LEFT OUTER JOIN contact cchuc ON cchuc.user_id = cchu.id' );

            $Param{Flags}->{JoinMap}->{ContactChangeByContact} = 1;
        }
    }

    # init mapping
    my %AttributeMapping = (
        CreateByID => {
            Select  => ['c.create_by'],
            OrderBy => ['c.create_by']
        },
        CreateBy   => {
            Select  => ['ccruc.lastname','ccruc.firstname','ccru.login'],
            OrderBy => ['LOWER(ccruc.lastname)','LOWER(ccruc.firstname)','LOWER(ccru.login)']
        },
        ChangeByID => {
            Select  => ['c.change_by'],
            OrderBy => ['c.change_by']
        },
        ChangeBy   => {
            Select  => ['cchuc.lastname','cchuc.firstname','cchu.login'],
            OrderBy => ['LOWER(cchuc.lastname)','LOWER(cchuc.firstname)','LOWER(cchu.login)']
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
