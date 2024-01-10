# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::ConfigItem::DeplState;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::ConfigItem::DeplState - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        DeplStateID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','GT','GTE','LT','LTE'],
            ValueType    => 'NUMERIC'
        },
        DeplStateIDs => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','GT','GTE','LT','LTE'],
            ValueType    => 'NUMERIC'
        },
        DeplState => {
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

    # check for needed joins
    my @SQLJoin = ();
    if ( $Param{Flags}->{PreviousVersionSearch} ) {
        if ( !$Param{Flags}->{JoinMap}->{ConfigItemVersion} ) {
            push( @SQLJoin, 'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id' );

            $Param{Flags}->{JoinMap}->{ConfigItemVersion} = 1;
        }

        if ( $Param{Search}->{Field} eq 'DeplState' ) {
            if ( !$Param{Flags}->{JoinMap}->{ConfigItemVersionDeplState} ) {
                push( @SQLJoin, 'INNER JOIN general_catalog civds ON civds.id = civ.depl_state_id AND general_catalog_class = \'ITSM::ConfigItem::DeploymentState\'' );

                $Param{Flags}->{JoinMap}->{ConfigItemVersionDeplState} = 1;
            }
        }
    }
    elsif ( $Param{Search}->{Field} eq 'DeplState' ) {
        if ( !$Param{Flags}->{JoinMap}->{ConfigItemDeplState} ) {
            push( @SQLJoin, 'INNER JOIN general_catalog cids ON cids.id = ci.cur_depl_state_id AND general_catalog_class = \'ITSM::ConfigItem::DeploymentState\'' );

            $Param{Flags}->{JoinMap}->{ConfigItemDeplState} = 1;
        }
    }

    # init mapping
    my %AttributeMapping = (
        DeplStateID  => {
            Column    => $Param{Flags}->{PreviousVersionSearch} ? 'civ.depl_state_id' : 'ci.cur_depl_state_id',
            ValueType => 'NUMERIC'
        },
        DeplStateIDs => {
            Column    => $Param{Flags}->{PreviousVersionSearch} ? 'civ.depl_state_id' : 'ci.cur_depl_state_id',
            ValueType => 'NUMERIC'
        },
        DeplState    => {
            Column    => $Param{Flags}->{PreviousVersionSearch} ? 'civds.name' : 'cids.name'
        }
    );

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
    my $TableAliasTLP = 'tlp' . ( $Param{Flags}->{JoinMap}->{TranslationConfigItemDeplState} // '' );
    my $TableAliasTL  = 'tl' . ( $Param{Flags}->{JoinMap}->{TranslationConfigItemDeplState} // '' );
    my @SQLJoin = ();
    if ( $Param{Attribute} eq 'DeplState' ) {
        if ( !$Param{Flags}->{JoinMap}->{ConfigItemDeplStateSort} ) {
            push( @SQLJoin, 'LEFT OUTER JOIN general_catalog cids ON cids.id = ci.cur_depl_state_id AND general_catalog_class = \'ITSM::ConfigItem::DeploymentState\'' );

            $Param{Flags}->{JoinMap}->{ConfigItemDeplStateSort} = 1;
        }

        if ( !defined( $Param{Flags}->{JoinMap}->{TranslationConfigItemDeplState} ) ) {
            my $Count = $Param{Flags}->{TranslationJoinCounter}++;
            $TableAliasTLP .= $Count;
            $TableAliasTL  .= $Count;

            push( @SQLJoin, "LEFT OUTER JOIN translation_pattern $TableAliasTLP ON $TableAliasTLP.value = cids.name" );
            push( @SQLJoin, "LEFT OUTER JOIN translation_language $TableAliasTL ON $TableAliasTL.pattern_id = $TableAliasTLP.id AND $TableAliasTL.language = '$Param{Language}'" );

            $Param{Flags}->{JoinMap}->{TranslationConfigItemDeplState} = $Count;
        }
    }

    # init mapping
    my %AttributeMapping = (
        DeplStateID  => {
            Select  => ['ci.cur_depl_state_id'],
            OrderBy => ['ci.cur_depl_state_id']
        },
        DeplStateIDs => {
            Select  => ['ci.cur_depl_state_id'],
            OrderBy => ['ci.cur_depl_state_id']
        },
        DeplState    => {
            Select  => ["LOWER(COALESCE($TableAliasTL.value, cids.name)) AS TranslateDeplState"],
            OrderBy => ['TranslateDeplState']
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
