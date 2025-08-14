# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::DynamicField;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::DynamicField - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    # get all valid dynamic fields for object type ticket
    my $DynamicFieldList = $Kernel::OM->Get('DynamicField')->DynamicFieldListGet(
        ObjectType => 'Ticket',
        Valid      => 1
    );

    # process fields
    my %Supported = ();
    if ( IsArrayRefWithData( $DynamicFieldList ) ) {
        for my $DynamicFieldConfig ( @{ $DynamicFieldList } ) {
            my $AttributeName = 'DynamicField_' . $DynamicFieldConfig->{Name};

            my $IsSelectable = $Kernel::OM->Get('DynamicField::Backend')->GetProperty(
                DynamicFieldConfig => $DynamicFieldConfig,
                Property           => 'IsSelectable'
            );

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

            my $IsFulltextable = $Kernel::OM->Get('DynamicField::Backend')->GetProperty(
                DynamicFieldConfig => $DynamicFieldConfig,
                Property           => 'IsFulltextable'
            );

            $Supported{ $AttributeName } = {
                Operators      => $Operators      || [],
                IsSelectable   => $IsSelectable   || 0,
                IsSearchable   => $IsSearchable   || 0,
                IsSortable     => $IsSortable     || 0,
                IsFulltextable => $IsFulltextable || 0,
                ValueType      => $ValueType      || q{}
            };
        }
    }

    return \%Supported;
}

sub AttributePrepare {
    my ( $Self, %Param ) = @_;

    # get dynamic field config
    my $DFName = $Param{Attribute};
    $DFName =~ s/DynamicField_//g;
    return if ( !$DFName );

    my $DynamicFieldConfig = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
        Name => $DFName,
    );
    return if ( !IsHashRefWithData( $DynamicFieldConfig ) );

    my $FlagPrefix = '';
    if ( $Param{PrepareType} eq 'Sort' ) {
        $FlagPrefix = 'Sort';
    }

    # check for needed joins
    my $TableAlias = 'dfv_left' . ( $Param{Flags}->{JoinMap}->{ $FlagPrefix . 'DynamicField_' . $DFName } // '' );
    my @SQLJoin = ();
    if ( !defined( $Param{Flags}->{JoinMap}->{ $FlagPrefix . 'DynamicField_' . $DFName } ) ) {
        my $Count = $Param{Flags}->{DynamicFieldJoinCounter}++;
        $TableAlias .= $Count;

        my $JoinStatement = "LEFT OUTER JOIN dynamic_field_value $TableAlias ON $TableAlias.object_id = st.id AND $TableAlias.field_id = $DynamicFieldConfig->{ID}";
        if ( $Param{PrepareType} eq 'Sort' ) {
            $JoinStatement .= " AND $TableAlias.first_value = 1";
        }
        push( @SQLJoin, $JoinStatement );

        $Param{Flags}->{JoinMap}->{ $FlagPrefix . 'DynamicField_' . $DFName } = $Count;
    }

    # get search def from dynamic field backend
    my $SQLParameter = $Kernel::OM->Get('DynamicField::Backend')->SQLParameterGet(
        DynamicFieldConfig => $DynamicFieldConfig,
        TableAlias         => $TableAlias,
        ParameterType      => $Param{PrepareType},
    );

    return if ( !IsHashRefWithData( $SQLParameter ) );

    if ( $Param{PrepareType} eq 'Condition' ) {
        $SQLParameter->{ConditionDef}->{NULLValue} = 1;
    }

    $SQLParameter->{SQLDef}->{Join} = \@SQLJoin;

    return $SQLParameter;
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
