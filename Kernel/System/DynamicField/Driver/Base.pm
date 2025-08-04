# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DynamicField::Driver::Base;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = qw(
    DynamicFieldValue
    Log
);

=head1 NAME

Kernel::System::DynamicField::Driver::Base - common fields backend functions

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub ValueIsDifferent {
    my ( $Self, %Param ) = @_;

    # special cases where the values are different but they should be reported as equals
    if (
        !defined $Param{Value1}
        && (
            (
                ref $Param{Value2} eq 'ARRAY'
                && !IsArrayRefWithData( $Param{Value2} )
            )
            || (
                ref $Param{Value2} eq ''
                && !IsStringWithData( $Param{Value2} )
            )
        )
    ) {
        return
    }

    if (
        !defined $Param{Value2}
        && (
            (
                ref $Param{Value1} eq 'ARRAY'
                && !IsArrayRefWithData( $Param{Value1} )
            )
            || (
                ref $Param{Value1} eq ''
                && !IsStringWithData( $Param{Value1} )
            )
        )
    ) {
        return
    }

    # compare the results
    return DataIsDifferent(
        Data1 => \$Param{Value1},
        Data2 => \$Param{Value2}
    );
}

sub ValueGet {
    my ( $Self, %Param ) = @_;

    my $DFValue = $Kernel::OM->Get('DynamicFieldValue')->ValueGet(
        FieldID  => $Param{DynamicFieldConfig}->{ID},
        ObjectID => $Param{ObjectID},
    );

    return if !$DFValue;
    return if !IsArrayRefWithData($DFValue);
    return if !IsHashRefWithData( $DFValue->[0] );

    # extract real values
    my @ReturnData;
    for my $Item ( @{$DFValue} ) {
        push @ReturnData, $Item->{ValueText}
    }

    return \@ReturnData;
}

sub ValueDelete {
    my ( $Self, %Param ) = @_;

    my $Success = $Kernel::OM->Get('DynamicFieldValue')->ValueDelete(
        FieldID  => $Param{DynamicFieldConfig}->{ID},
        ObjectID => $Param{ObjectID},
        UserID   => $Param{UserID},
    );

    return $Success;
}

sub AllValuesDelete {
    my ( $Self, %Param ) = @_;

    my $Success = $Kernel::OM->Get('DynamicFieldValue')->AllValuesDelete(
        FieldID => $Param{DynamicFieldConfig}->{ID},
        UserID  => $Param{UserID},
    );

    return $Success;
}

sub GetProperty {
    my ( $Self, %Param ) = @_;

    # return fail if Behaviors hash does not exists
    return if !IsHashRefWithData( $Self->{Properties} );

    # return requested Property
    return $Self->{Properties}->{ $Param{Property} };
}

sub HTMLDisplayValueRender {
    my ( $Self, %Param ) = @_;

    return $Self->DisplayValueRender(%Param);
}

sub ShortDisplayValueRender {
    my ( $Self, %Param ) = @_;

    return $Self->DisplayValueRender(%Param);
}

sub DisplayKeyRender {
    my ( $Self, %Param ) = @_;

    return $Self->DisplayValueRender(%Param);
}

sub DisplayObjectValueRender {
    my ( $Self, %Param ) = @_;

    return if !$Param{Value};

    # check value
    my @Values;
    if ( ref $Param{Value} eq 'ARRAY' ) {
        @Values = @{ $Param{Value} };
    }
    else {
        @Values = ( $Param{Value} );
    }

    return \@Values;
}

sub DFValueObjectReplace {
    my ( $Self, %Param ) = @_;

    return if ( !$Param{Placeholder} || !IsArrayRefWithData($Param{Value}) );

    if (
        IsHashRefWithData($Self->{ReferencePlaceholderParameter}) &&
        $Self->{ReferencePlaceholderParameter}->{Prefix} &&
        $Self->{ReferencePlaceholderParameter}->{ObjectType}
    ) {
        if ($Param{Placeholder} =~ m/_Object_(\d+)_(.+)/) {
            if (($1 || $1 == 0) && $2 && $Param{Value}->[$1]) {
                return $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
                    %Param,
                    Text        => "<KIX_$Self->{ReferencePlaceholderParameter}->{Prefix}\_$2>",
                    ObjectType  => $Self->{ReferencePlaceholderParameter}->{ObjectType},
                    ObjectID    => $Param{Value}->[$1]
                );
            }
        }
    }
    return;
}

sub GetCacheDependencies {
    my ( $Self, %Param ) = @_;

    return;
}

sub ExportConfigPrepare {
    my ( $Self, %Param ) = @_;

    return $Param{Config};
}

sub ImportConfigPrepare {
    my ( $Self, %Param ) = @_;

    return $Param{Config};
}

sub SQLParameterGet {
    my ( $Self, %Param ) = @_;

    return {
        Column => "$Param{TableAlias}.value_text",
    };
}

sub SearchSQLSearchFieldGet {
    my ( $Self, %Param ) = @_;

    my $SQLParameter = $Self->SQLParameterGet(
        %Param,
        ParameterType => 'Condition'
    );
    my %ConditionDef = %{ $SQLParameter->{ConditionDef} || {} };

    return {
        %ConditionDef,
        Column => $SQLParameter->{Column}
    };
}

sub SearchSQLSortFieldGet {
    my ( $Self, %Param ) = @_;

    my $SQLParameter = $Self->SQLParameterGet(
        %Param,
        ParameterType => 'Sort'
    );

    return {
        Select  => [ $SQLParameter->{Column} ],
        OrderBy => [ $SQLParameter->{Column} ]
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
