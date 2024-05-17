# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::GeneralCatalog::Preferences;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::GeneralCatalog::Preferences - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    # check cache
    my $CacheKey  = "GetSupportedAttributes::GeneralCatalog::Preference";
    my $CacheData = $Kernel::OM->Get('Cache')->Get(
        Type => 'ObjectSearch_GeneralCatalog',
        Key  => $CacheKey,
    );
    return $CacheData if ( IsHashRefWithData( $CacheData ) );

    # init hash ref for supported attributes
    my $AttributesRef = {};


    # get supported attributes
    $Self->_PreferenceAttributeGet(
        AttributesRef => $AttributesRef
    );

    # cache supported attributes
    $Kernel::OM->Get('Cache')->Set(
        Type  => 'ObjectSearch_GeneralCatalog',
        TTL   => 60 * 60 * 24 * 20,
        Key   => $CacheKey,
        Value => $AttributesRef,
    );

    # return supported attributes
    return $AttributesRef;
}

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    # check for needed joins
    my @SQLJoin = ();
    my $JoinFlag = 'JoinGeneralCatalog' . $Param{Search}->{Field};
    my $TableAlias = $Param{Flags}->{JoinMap}->{ $JoinFlag } // 'gcp';
    if ( !$Param{Flags}->{JoinMap}->{ $JoinFlag } ) {
        my $Count = $Param{Flags}->{GeneralCatalogPrefJoinCounter}++;
        $TableAlias .= $Count;
        push(
            @SQLJoin,
            "LEFT OUTER JOIN general_catalog_preferences $TableAlias ON $TableAlias.general_catalog_id = gc.id",
            "AND $TableAlias.pref_key = '$Param{Search}->{Field}'"
        );

        $Param{Flags}->{JoinMap}->{ $JoinFlag } = $TableAlias;
    }

    # prepare condition
    my $Condition = $Self->_GetCondition(
        Operator        => $Param{Search}->{Operator},
        Column          => "$TableAlias.pref_value",
        Value           => $Param{Search}->{Value},
        Silent          => $Param{Silent},
        CaseInsensitive => 1,
        NULLValue       => 1
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

    my $Attr = $Param{Attribute};

    # check for needed joins
    my @SQLJoin    = ();
    my $JoinFlag   = 'JoinGeneralCatalog' . $Attr;
    my $TableAlias = $Param{Flags}->{JoinMap}->{ $JoinFlag } // 'gcp';
    if ( !$Param{Flags}->{JoinMap}->{ $JoinFlag } ) {
        my $Count = $Param{Flags}->{GeneralCatalogPrefJoinCounter}++;
        $TableAlias .= $Count;

        push(
            @SQLJoin,
            "LEFT OUTER JOIN general_catalog_preferences $TableAlias ON $TableAlias.general_catalog_id = gc.id",
            "AND $TableAlias.pref_key = '$Attr'"
        );

        $Param{Flags}->{JoinMap}->{ $JoinFlag } = $TableAlias;
    }

    # return sort def
    return {
        Join    => \@SQLJoin,
        Select  => [ "$TableAlias.pref_value" ],
        OrderBy => [ "$TableAlias.pref_value" ]
    };
}

=begin Internal:

=cut

sub _PreferenceAttributeGet {
    my ($Self, %Param) = @_;

    my $PreferenceConfig = $Kernel::OM->Get('Config')->Get('GeneralCatalogPreferences');

    return 1 if !IsHashRefWithData($PreferenceConfig);

    # process definition
    for my $Attr ( values %{$PreferenceConfig} ) {
        next if !defined $Attr->{PrefKey};
        next if !$Attr->{PrefKey};

        my $Key = $Attr->{PrefKey};

        if ( defined( $Param{AttributesRef}->{ $Key } ) ) {
            push( @{ $Param{AttributesRef}->{ $Key }->{Class} }, $Attr->{Class} );
        }
        else {
            $Param{AttributesRef}->{$Key} = {
                IsSearchable => 1,
                IsSortable   => 1,
                Class        => [ $Attr->{Class} ],
                Operators    => ['EQ','NE','IN','!IN','ENDSWITH','STARTSWITH','CONTAINS','LIKE']
            };
        }
    }

    return 1;
}

=end Internal:

=cut

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut