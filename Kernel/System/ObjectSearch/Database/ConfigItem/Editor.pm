# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::ConfigItem::Editor;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::ConfigItem::Editor - attribute module for database object search

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
            Column          => 'ci.create_by',
            ValueType       => 'NUMERIC'
        },
        CreateBy   => {
            Column          => 'ci.create_by',
            ValueType       => 'NUMERIC'
## TODO: login based search instead of id
#            Column          => 'cicru.login',
#            CaseInsensitive => 1
        },
        ChangeByID => {
            Column          => 'ci.change_by',
            ValueType       => 'NUMERIC'
        },
        ChangeBy   => {
            Column          => 'ci.change_by',
            ValueType       => 'NUMERIC'
## TODO: login based search instead of id
#            Column          => 'cichu.login',
#            CaseInsensitive => 1
        }
    );

## TODO: login based search instead of id
#    # check for needed joins
#    my @SQLJoin = ();
#    if ( $Param{Search}->{Field} eq 'CreateBy' ) {
#        if ( !$Param{Flags}->{JoinMap}->{ConfigItemCreateBy} ) {
#            push( @SQLJoin, 'INNER JOIN users cicru ON cicru.id = ci.create_by' );
#
#            $Param{Flags}->{JoinMap}->{ConfigItemCreateBy} = 1;
#        }
#    }
#    elsif ( $Param{Search}->{Field} eq 'ChangeBy' ) {
#        if ( !$Param{Flags}->{JoinMap}->{ConfigItemChangeBy} ) {
#            push( @SQLJoin, 'INNER JOIN users cichu ON cichu.id = ci.change_by' );
#
#            $Param{Flags}->{JoinMap}->{ConfigItemChangeBy} = 1;
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
        if ( !$Param{Flags}->{JoinMap}->{ConfigItemCreateBy} ) {
            push( @SQLJoin, 'INNER JOIN users cicru ON cicru.id = ci.create_by' );

            $Param{Flags}->{JoinMap}->{ConfigItemCreateBy} = 1;
        }
        if ( !$Param{Flags}->{JoinMap}->{TicketCreateByContact} ) {
            push( @SQLJoin, 'LEFT OUTER JOIN contact cicruc ON cicruc.user_id = cicru.id' );

            $Param{Flags}->{JoinMap}->{TicketCreateByContact} = 1;
        }
    }
    if ( $Param{Attribute} eq 'ChangeBy' ) {
        if ( !$Param{Flags}->{JoinMap}->{ConfigItemChangeBy} ) {
            push( @SQLJoin, 'INNER JOIN users cichu ON cichu.id = ci.change_by' );

            $Param{Flags}->{JoinMap}->{ConfigItemChangeBy} = 1;
        }
        if ( !$Param{Flags}->{JoinMap}->{TicketChangeByContact} ) {
            push( @SQLJoin, 'LEFT OUTER JOIN contact cichuc ON cichuc.user_id = cichu.id' );

            $Param{Flags}->{JoinMap}->{TicketChangeByContact} = 1;
        }
    }

    # init mapping
    my %AttributeMapping = (
        CreateByID => {
            Select  => ['ci.create_by'],
            OrderBy => ['ci.create_by']
        },
        CreateBy   => {
            Select  => ['cicruc.lastname','cicruc.firstname','cicru.login'],
            OrderBy => ['LOWER(cicruc.lastname)','LOWER(cicruc.firstname)','LOWER(cicru.login)']
        },
        ChangeByID => {
            Select  => ['ci.change_by'],
            OrderBy => ['ci.change_by']
        },
        ChangeBy   => {
            Select  => ['cichuc.lastname','cichuc.firstname','cichu.login'],
            OrderBy => ['LOWER(cichuc.lastname)','LOWER(cichuc.firstname)','LOWER(cichu.login)']
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
