# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DynamicField::Driver::Checkbox;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::DynamicField::Driver::Base);

our @ObjectDependencies = (
    'Config',
    'DB',
    'DynamicFieldValue',
    'Ticket::ColumnFilter',
    'Log',
    'Main',
);

=head1 NAME

Kernel::System::DynamicField::Driver::Checkbox

=head1 SYNOPSIS

DynamicFields Checkbox Driver delegate

=head1 PUBLIC INTERFACE

This module implements the public interface of L<Kernel::System::DynamicField::Backend>.
Please look there for a detailed reference of the functions.

=over 4

=item new()

usually, you want to create an instance of this
by using Kernel::System::DynamicField::Backend->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # set field behaviors
    $Self->{Behaviors} = {
        'IsNotificationEventCondition' => 1,
        'IsSortable'                   => 1,
        'IsFiltrable'                  => 1,
        'IsStatsCondition'             => 1,
        'IsCustomerInterfaceCapable'   => 1,
    };

    # get the Dynamic Field Backend custom extensions
    my $DynamicFieldDriverExtensions
        = $Kernel::OM->Get('Config')->Get('DynamicFields::Extension::Driver::Checkbox');

    EXTENSION:
    for my $ExtensionKey ( sort keys %{$DynamicFieldDriverExtensions} ) {

        # skip invalid extensions
        next EXTENSION if !IsHashRefWithData( $DynamicFieldDriverExtensions->{$ExtensionKey} );

        # create a extension config shortcut
        my $Extension = $DynamicFieldDriverExtensions->{$ExtensionKey};

        # check if extension has a new module
        if ( $Extension->{Module} ) {

            # check if module can be loaded
            if (
                !$Kernel::OM->Get('Main')->RequireBaseClass( $Extension->{Module} )
                )
            {
                die "Can't load dynamic fields backend module"
                    . " $Extension->{Module}! $@";
            }
        }

        # check if extension contains more behaviors
        if ( IsHashRefWithData( $Extension->{Behaviors} ) ) {

            %{ $Self->{Behaviors} } = (
                %{ $Self->{Behaviors} },
                %{ $Extension->{Behaviors} }
            );
        }
    }

    return $Self;
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

    return $DFValue->[0]->{ValueInt};
}

sub ValueSet {
    my ( $Self, %Param ) = @_;

    # check value for just 1 or 0
    if ( defined $Param{Value} && !$Param{Value} ) {
        $Param{Value} = 0;
    }
    elsif ( $Param{Value} && $Param{Value} !~ m{\A [0|1]? \z}xms ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Value $Param{Value} is invalid for Checkbox fields!",
        );
        return;
    }

    my $Success = $Kernel::OM->Get('DynamicFieldValue')->ValueSet(
        FieldID  => $Param{DynamicFieldConfig}->{ID},
        ObjectID => $Param{ObjectID},
        Value    => [
            {
                ValueInt => $Param{Value},
            },
        ],
        UserID => $Param{UserID},
    );

    return $Success;
}

sub ValueValidate {
    my ( $Self, %Param ) = @_;

    # check value for just 1 or 0
    if ( defined $Param{Value} && !$Param{Value} ) {
        $Param{Value} = 0;
    }
    elsif ( $Param{Value} && $Param{Value} !~ m{\A [0|1]? \z}xms ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Value $Param{Value} is invalid for Checkbox fields!",
        );
        return;
    }

    my $Success = $Kernel::OM->Get('DynamicFieldValue')->ValueValidate(
        Value => {
            ValueInt => $Param{Value},
        },
        UserID => $Param{UserID}
    );

    return $Success;
}

sub SearchSQLGet {
    my ( $Self, %Param ) = @_;

    if ( !IsInteger( $Param{SearchTerm} ) ) {
        $Kernel::OM->Get('Log')->Log(
            'Priority' => 'error',
            'Message'  => "Unsupported Search Term $Param{SearchTerm}, should be an integer",
        );
        return;
    }

    if ( $Param{Operator} eq 'Equals' ) {
        my $SQL = " $Param{TableAlias}.value_int = ";
        $SQL .= $Kernel::OM->Get('DB')->Quote( $Param{SearchTerm}, 'Integer' ) . q{ };
        return $SQL;
    }

    $Kernel::OM->Get('Log')->Log(
        'Priority' => 'error',
        'Message'  => "Unsupported Operator $Param{Operator}",
    );

    return;
}

sub SearchSQLOrderFieldGet {
    my ( $Self, %Param ) = @_;

    return "$Param{TableAlias}.value_int";
}

sub DisplayValueRender {
    my ( $Self, %Param ) = @_;

    # check for Null value
    if ( !defined $Param{Value} ) {
        return {
            Value => q{},
            Title => q{},
            Link  => q{},
        };
    }

    # convert value to user friendly string
    my $Value = 'Checked';
    if ( $Param{Value} ne '1' ) {
        $Value = 'Unchecked';
    }

    # always translate value
    $Value = $Param{LayoutObject}->{LanguageObject}->Translate($Value);

    # in this backend there is no need for HTMLOutput
    # Title is always equal to Value
    my $Title = $Value;

    # this field type does not support the Link Feature
    my $Link;

    # create return structure
    my $Data = {
        Value => $Value,
        Title => $Title,
        Link  => $Link,
    };

    return $Data;
}

sub ReadableValueRender {
    my ( $Self, %Param ) = @_;

    my $Value = defined $Param{Value} ? $Param{Value} : q{};

    # Title is always equal to Value
    my $Title = $Value;

    # create return structure
    my $Data = {
        Value => $Value,
        Title => $Title,
    };

    return $Data;
}

sub RandomValueSet {
    my ( $Self, %Param ) = @_;

    my $Value = int( rand(2) );

    my $Success = $Self->ValueSet(
        %Param,
        Value => $Value,
    );

    if ( !$Success ) {
        return {
            Success => 0,
        };
    }
    return {
        Success => 1,
        Value   => $Value,
    };
}

sub HistoricalValuesGet {
    my ( $Self, %Param ) = @_;

    # get historical values from database
    my $HistoricalValues = $Kernel::OM->Get('DynamicFieldValue')->HistoricalValueGet(
        FieldID   => $Param{DynamicFieldConfig}->{ID},
        ValueType => 'Integer',
    );

    # return the historical values from database
    return $HistoricalValues;
}

sub ValueLookup {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Key};

    return q{} if $Param{Key} eq q{};

    my $Value = defined $Param{Key} && $Param{Key} eq '1' ? 'Checked' : 'Unchecked';

    # check if translation is possible
    if ( defined $Param{LanguageObject} ) {

        # translate value
        $Value = $Param{LanguageObject}->Translate($Value);
    }

    return $Value;
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
