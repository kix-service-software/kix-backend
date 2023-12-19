# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::FAQArticle::DynamicField;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::FAQArticle::DynamicField - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    # get all valid dynamic fields for object type ticket
    my $DynamicFieldList = $Kernel::OM->Get('DynamicField')->DynamicFieldListGet(
        ObjectType => 'FAQArticle',
        Valid      => 1
    );

    # process fields
    my %Supported = ();
    if ( IsArrayRefWithData( $DynamicFieldList ) ) {
        for my $DynamicFieldConfig ( @{ $DynamicFieldList } ) {
            my $AttributeName = 'DynamicField_' . $DynamicFieldConfig->{Name};

            my $IsSearchable = $Kernel::OM->Get('DynamicField::Backend')->GetProperty(
                DynamicFieldConfig => $DynamicFieldConfig,
                Property           => 'IsSearchable'
            );
            my $Operators = [];
            my $ValueType = q{};
            if ( $IsSearchable ) {
                $Operators = $Kernel::OM->Get('DynamicField::Backend')->GetProperty(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    Property           => 'SearchOperators'
                );
                $ValueType = $Kernel::OM->Get('DynamicField::Backend')->GetProperty(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    Property           => 'SearchValueType'
                );
            }
            my $IsSortable = $Kernel::OM->Get('DynamicField::Backend')->GetProperty(
                DynamicFieldConfig => $DynamicFieldConfig,
                Property           => 'IsSortable'
            );

            $Supported{ $AttributeName } = {
                Operators    => $Operators    || [],
                IsSearchable => $IsSearchable || 0,
                IsSortable   => $IsSortable   || 0,
                ValueType    => $ValueType    || q{}
            };
        }
    }

    return \%Supported;
}

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    # get dynamic field config
    my $DFName = $Param{Search}->{Field};
    $DFName =~ s/DynamicField_//g;
    return if ( !$DFName );
    my $DynamicFieldConfig = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
        Name => $DFName,
    );
    return if ( !IsHashRefWithData( $DynamicFieldConfig ) );

    # check for needed joins
    my $TableAlias = 'dfv_left' . ( $Param{Flags}->{JoinMap}->{ 'DynamicField_' . $DFName } // '' );
    my @SQLJoin = ();
    if ( !defined( $Param{Flags}->{JoinMap}->{ 'DynamicField_' . $DFName } ) ) {
        my $Count = $Param{Flags}->{DynamicFieldJoinCounter}++;
        $TableAlias .= $Count;
        push( @SQLJoin, "LEFT OUTER JOIN dynamic_field_value $TableAlias ON $TableAlias.object_id = f.id AND $TableAlias.field_id = $DynamicFieldConfig->{ID}" );

        $Param{Flags}->{JoinMap}->{ 'DynamicField_' . $DFName } = $Count;
    }

    # get search def from dynamic field backend
    my $SearchFieldRef = $Kernel::OM->Get('DynamicField::Backend')->SearchSQLSearchFieldGet(
        DynamicFieldConfig => $DynamicFieldConfig,
        TableAlias         => $TableAlias,
    );
    return if ( !IsHashRefWithData( $SearchFieldRef ) );

    # prepare condition
    my $Condition = $Self->_GetCondition(
        Operator        => $Param{Search}->{Operator},
        Column          => $SearchFieldRef->{Column},
        Value           => $Param{Search}->{Value},
        ValueType       => $SearchFieldRef->{ValueType},
        CaseInsensitive => $SearchFieldRef->{CaseInsensitive},
        NULLValue       => 1,
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

    # get dynamic field config
    my $DFName = $Param{Attribute};
    $DFName =~ s/DynamicField_//g;
    return if ( !$DFName );
    my $DynamicFieldConfig = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
        Name => $DFName,
    );
    return if ( !IsHashRefWithData( $DynamicFieldConfig ) );

    # check for needed joins
    my $TableAlias = 'dfv_left' . ( $Param{Flags}->{JoinMap}->{ 'SortDynamicField_' . $DFName } // '' );
    my @SQLJoin = ();
    if ( !defined( $Param{Flags}->{JoinMap}->{ 'SortDynamicField_' . $DFName } ) ) {
        my $Count = $Param{Flags}->{DynamicFieldJoinCounter}++;
        $TableAlias .= $Count;
        push( @SQLJoin, "LEFT OUTER JOIN dynamic_field_value $TableAlias ON $TableAlias.object_id = f.id AND $TableAlias.field_id = $DynamicFieldConfig->{ID} AND $TableAlias.first_value = 1" );

        $Param{Flags}->{JoinMap}->{ 'SortDynamicField_' . $DFName } = $Count;
    }

    # get sort def from dynamic field backend
    my $SortFieldRef = $Kernel::OM->Get('DynamicField::Backend')->SearchSQLSortFieldGet(
        DynamicFieldConfig => $DynamicFieldConfig,
        TableAlias         => $TableAlias,
    );
    return if ( !IsHashRefWithData( $SortFieldRef ) );

    return {
        %{ $SortFieldRef },
        Join => \@SQLJoin
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
