# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
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
        && ref $Param{Value2} eq 'ARRAY'
        && !IsArrayRefWithData( $Param{Value2} )
    ) {
        return
    }

    if (
        !defined $Param{Value2}
        && ref $Param{Value1} eq 'ARRAY'
        && !IsArrayRefWithData( $Param{Value1} )
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

sub HasBehavior {
    my ( $Self, %Param ) = @_;

    # return fail if Behaviors hash does not exists
    return if !IsHashRefWithData( $Self->{Behaviors} );

    # return success if the dynamic field has the expected behavior
    return 1 if IsPositiveInteger( $Self->{Behaviors}->{ $Param{Behavior} } );

    # otherwise return fail
    return;
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

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
