# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::ArticleDynamicField;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::ArticleDynamicField - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    # get all valid dynamic fields for object type article
    my $DynamicFieldList = $Kernel::OM->Get('DynamicField')->DynamicFieldListGet(
        ObjectType => 'Article',
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

            $Supported{ $AttributeName } = {
                Operators    => $Operators    || [],
                IsSearchable => $IsSearchable || 0,
                IsSortable   => 0,
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

    # join article table for dynamic field table join (object_id)
    if ( !$Param{Flags}->{JoinMap}->{Article} ) {
        my $JoinString = 'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id';

        # restrict search from customers to customer visible articles
        if ( $Param{UserType} eq 'Customer' ) {
            $JoinString .= ' AND ta.customer_visible = 1';
        }
        push( @SQLJoin, $JoinString );

        $Param{Flags}->{JoinMap}->{Article} = 1;
    }

    if ( !defined( $Param{Flags}->{JoinMap}->{ 'DynamicField_' . $DFName } ) ) {
        my $Count = $Param{Flags}->{DynamicFieldJoinCounter}++;
        $TableAlias .= $Count;
        push( @SQLJoin, "LEFT OUTER JOIN dynamic_field_value $TableAlias ON $TableAlias.object_id = ta.id AND $TableAlias.field_id = $DynamicFieldConfig->{ID}" );

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
        Join       => \@SQLJoin,
        Where      => [ $Condition ],
        IsRelative => $Param{Search}->{IsRelative}
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
