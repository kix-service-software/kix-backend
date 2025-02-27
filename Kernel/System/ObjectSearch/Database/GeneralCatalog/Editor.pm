# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ObjectSearch::Database::GeneralCatalog::Editor;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::GeneralCatalog::Editor - attribute module for database object search

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
            Column          => 'gc.create_by',
            ValueType       => 'NUMERIC'
        },
        CreateBy   => {
            Column          => 'gc.create_by',
            ValueType       => 'NUMERIC'
## TODO: login based search instead of id
#            Column          => 'gccru.login',
#            CaseInsensitive => 1
        },
        ChangeByID => {
            Column          => 'gc.change_by',
            ValueType       => 'NUMERIC'
        },
        ChangeBy   => {
            Column          => 'gc.change_by',
            ValueType       => 'NUMERIC'
## TODO: login based search instead of id
#            Column    => 'gcchu.login',
#            CaseInsensitive => 1
        }
    );

## TODO: login based search instead of id
#    # check for needed joins
#    my @SQLJoin = ();
#    if ( $Param{Search}->{Field} eq 'CreateBy' ) {
#        if ( !$Param{Flags}->{JoinMap}->{JoinGCCreateBy} ) {
#            push( @SQLJoin, 'INNER JOIN users gccru ON ocru.id = gc.create_by' );
#
#            $Param{Flags}->{JoinMap}->{JoinGCCreateBy} = 1;
#        }
#    }
#    elsif ( $Param{Search}->{Field} eq 'ChangeBy' ) {
#        if ( !$Param{Flags}->{JoinMap}->{JoinGCChangeBy} ) {
#            push( @SQLJoin, 'INNER JOIN users gcchu ON ochu.id = gc.change_by' );
#
#            $Param{Flags}->{JoinMap}->{JoinGCChangeBy} = 1;
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
        if ( !$Param{Flags}->{JoinMap}->{JoinGCCreateBy} ) {
            push( @SQLJoin, 'INNER JOIN users gccru ON gccru.id = gc.create_by' );

            $Param{Flags}->{JoinMap}->{JoinGCCreateBy} = 1;
        }
        if ( !$Param{Flags}->{JoinMap}->{JoinGCCreateByContact} ) {
            push( @SQLJoin, 'LEFT OUTER JOIN contact gccruc ON gccruc.user_id = gccru.id' );

            $Param{Flags}->{JoinMap}->{JoinGCCreateByContact} = 1;
        }
    }
    if ( $Param{Attribute} eq 'ChangeBy' ) {
        if ( !$Param{Flags}->{JoinMap}->{JoinGCChangeBy} ) {
            push( @SQLJoin, 'INNER JOIN users gcchu ON gcchu.id = gc.change_by' );

            $Param{Flags}->{JoinMap}->{JoinGCChangeBy} = 1;
        }
        if ( !$Param{Flags}->{JoinMap}->{JoinGCChangeByContact} ) {
            push( @SQLJoin, 'LEFT OUTER JOIN contact gcchuc ON gcchuc.user_id = gcchu.id' );

            $Param{Flags}->{JoinMap}->{JoinGCChangeByContact} = 1;
        }
    }

    # init mapping
    my %AttributeMapping = (
        CreateByID => {
            Select  => ['gc.create_by'],
            OrderBy => ['gc.create_by']
        },
        CreateBy   => {
            Select  => ['gccruc.lastname','gccruc.firstname','gccru.login'],
            OrderBy => ['LOWER(gccruc.lastname)','LOWER(gccruc.firstname)','LOWER(gccru.login)']
        },
        ChangeByID => {
            Select  => ['gc.change_by'],
            OrderBy => ['gc.change_by']
        },
        ChangeBy   => {
            Select  => ['gcchuc.lastname','gcchuc.firstname','gcchu.login'],
            OrderBy => ['LOWER(gcchuc.lastname)','LOWER(gcchuc.firstname)','LOWER(gcchu.login)']
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
