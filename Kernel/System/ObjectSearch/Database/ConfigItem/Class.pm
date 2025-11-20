# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::ConfigItem::Class;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::ConfigItem::Class - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        ClassID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ', 'NE', 'IN','!IN','GT','GTE','LT','LTE'],
            ValueType    => 'NUMERIC'
        },
        ClassIDs => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ', 'NE', 'IN','!IN','GT','GTE','LT','LTE'],
            ValueType    => 'NUMERIC'
        },
        Class => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ', 'NE', 'IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        }
    };
}

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    # init mapping
    my %AttributeMapping = (
        ClassID  => {
            Column    => 'ci.class_id',
            ValueType => 'NUMERIC'
        },
        ClassIDs => {
            Column    => 'ci.class_id',
            ValueType => 'NUMERIC'
        },
        Class    => {
            Column    => 'cic.name'
        }
    );

    # check for needed joins
    my @SQLJoin = ();
    if ( $Param{Search}->{Field} eq 'Class' ) {
        if ( !$Param{Flags}->{JoinMap}->{ConfigItemClass} ) {
            push( @SQLJoin, 'INNER JOIN general_catalog cic ON cic.id = ci.class_id AND cic.general_catalog_class = \'ITSM::ConfigItem::Class\'' );

            $Param{Flags}->{JoinMap}->{ConfigItemClass} = 1;
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
    my $TableAliasTLP = 'tlp' . ( $Param{Flags}->{JoinMap}->{TranslationConfigItemClass} // '' );
    my $TableAliasTL  = 'tl' . ( $Param{Flags}->{JoinMap}->{TranslationConfigItemClass} // '' );
    my @SQLJoin = ();
    if ( $Param{Attribute} eq 'Class' ) {
        if ( !$Param{Flags}->{JoinMap}->{ConfigItemClass} ) {
            push( @SQLJoin, 'INNER JOIN general_catalog cic ON cic.id = ci.class_id AND cic.general_catalog_class = \'ITSM::ConfigItem::Class\'' );

            $Param{Flags}->{JoinMap}->{ConfigItemClass} = 1;
        }

        if ( !defined( $Param{Flags}->{JoinMap}->{TranslationConfigItemClass} ) ) {
            my $Count = $Param{Flags}->{TranslationJoinCounter}++;
            $TableAliasTLP .= $Count;
            $TableAliasTL  .= $Count;

            push( @SQLJoin, "LEFT OUTER JOIN translation_pattern $TableAliasTLP ON $TableAliasTLP.value = cic.name" );
            push( @SQLJoin, "LEFT OUTER JOIN translation_language $TableAliasTL ON $TableAliasTL.pattern_id = $TableAliasTLP.id AND $TableAliasTL.language = '$Param{Language}'" );

            $Param{Flags}->{JoinMap}->{TranslationConfigItemClass} = $Count;
        }
    }

    # init mapping
    my %AttributeMapping = (
        ClassID  => {
            Select  => ['ci.class_id'],
            OrderBy => ['ci.class_id']
        },
        ClassIDs => {
            Select  => ['ci.class_id'],
            OrderBy => ['ci.class_id']
        },
        Class    => {
            Select  => ["LOWER(COALESCE($TableAliasTL.value, cic.name)) AS TranslateClass"],
            OrderBy => ['TranslateClass']
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
