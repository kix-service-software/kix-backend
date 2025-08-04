# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DynamicField::Driver::Multiselect;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::DynamicField::Driver::BaseSelect);

our @ObjectDependencies = qw(
    Config
    DynamicFieldValue
    Log
    Main
);

=head1 NAME

Kernel::System::DynamicField::Driver::Multiselect

=head1 SYNOPSIS

DynamicFields Multiselect Driver delegate

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

    # set field properties
    $Self->{Properties} = {
        'IsSelectable'    => 1,
        'IsSearchable'    => 1,
        'IsSortable'      => 1,
        'IsFulltextable'  => 1,
        'SearchOperators' => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
    };

    # get the Dynamic Field Backend custom extensions
    my $DynamicFieldDriverExtensions
        = $Kernel::OM->Get('Config')->Get('DynamicFields::Extension::Driver::Multiselect');

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

        # check if extension contains more properties
        if ( IsHashRefWithData( $Extension->{Properties} ) ) {

            %{ $Self->{Properties} } = (
                %{ $Self->{Properties} },
                %{ $Extension->{Properties} }
            );
        }
    }

    return $Self;
}

sub ValueSet {
    my ( $Self, %Param ) = @_;

    # check for valid possible values list
    if ( !$Param{DynamicFieldConfig}->{Config}->{PossibleValues} ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need PossibleValues in DynamicFieldConfig!",
        );
        return;
    }

    return $Self->SUPER::ValueSet(%Param);
}

sub DisplayValueRender {
    my ( $Self, %Param ) = @_;

    # set HTMLOuput as default if not specified
    if ( !defined $Param{HTMLOutput} ) {
        $Param{HTMLOutput} = 1;
    }

    # set Value and Title variables
    my $Value           = q{};
    my $Title           = q{};
    my $ValueMaxChars   = $Param{ValueMaxChars} || q{};
    my $TitleMaxChars   = $Param{TitleMaxChars} || q{};

    my $NotTranslatedValue = q{};
    my $NotTranslatedValueMaxChars = $Param{ValueMaxChars} || q{};

    # check value
    my @Values;
    if ( ref $Param{Value} eq 'ARRAY' ) {
        @Values = @{ $Param{Value} };
    }
    else {
        @Values = ( $Param{Value} );
    }

    # get real values
    my $PossibleValues     = $Param{DynamicFieldConfig}->{Config}->{PossibleValues};
    my $TranslatableValues = $Param{DynamicFieldConfig}->{Config}->{TranslatableValues};

    my @ReadableValues;
    my @NotTranslatedValues;
    my @ReadableTitles;

    my $ShowValueEllipsis;
    my $ShowNotTranslatedValueEllipsis;
    my $ShowTitleEllipsis;

    VALUEITEM:
    for my $Item (@Values) {
        next VALUEITEM if ( !defined( $Item ) || $Item eq '' );

        my $ReadableValue = $Item;
        my $NotTranslatedReadableValue = $Item;

        if ( $PossibleValues->{$Item} ) {
            $ReadableValue = $PossibleValues->{$Item};
            $NotTranslatedReadableValue = $PossibleValues->{$Item};

            if ($TranslatableValues) {
                $ReadableValue = $Param{LayoutObject}->{LanguageObject}->Translate($ReadableValue);
            }
        }

        my $ReadableLength = length $ReadableValue;

        # set title equal value
        my $ReadableTitle = $ReadableValue;

        # cut strings if needed
        if ( $ValueMaxChars ne q{} ) {

            if ( length $ReadableValue > $ValueMaxChars ) {
                $ShowValueEllipsis = 1;
            }
            $ReadableValue = substr $ReadableValue, 0, $ValueMaxChars;

            # decrease the max parameter
            $ValueMaxChars = $ValueMaxChars - $ReadableLength;
            if ( $ValueMaxChars < 0 ) {
                $ValueMaxChars = 0;
            }
        }

        my $NotTranslatedLength = length $NotTranslatedReadableValue;

        # cut strings if needed
        if ( $NotTranslatedValueMaxChars ne q{} ) {

            if ( length $NotTranslatedReadableValue > $NotTranslatedValueMaxChars ) {
                $ShowNotTranslatedValueEllipsis = 1;
            }
            $NotTranslatedReadableValue = substr $NotTranslatedReadableValue, 0, $NotTranslatedValueMaxChars;

            # decrease the max parameter
            $NotTranslatedValueMaxChars = $NotTranslatedValueMaxChars - $NotTranslatedLength;
            if ( $NotTranslatedValueMaxChars < 0 ) {
                $NotTranslatedValueMaxChars = 0;
            }
        }

        if ( $TitleMaxChars ne q{} ) {

            if ( length $ReadableTitle > $TitleMaxChars ) {
                $ShowTitleEllipsis = 1;
            }
            $ReadableTitle = substr $ReadableTitle, 0, $TitleMaxChars;

            # decrease the max parameter
            $TitleMaxChars = $TitleMaxChars - $ReadableLength;
            if ( $TitleMaxChars < 0 ) {
                $TitleMaxChars = 0;
            }
        }

        # HTMLOutput transformations
        if ( $Param{HTMLOutput} ) {

            $ReadableValue = $Param{LayoutObject}->Ascii2Html(
                Text => $ReadableValue,
            );

            $NotTranslatedReadableValue = $Param{LayoutObject}->Ascii2Html(
                Text => $NotTranslatedReadableValue,
            );

            $ReadableTitle = $Param{LayoutObject}->Ascii2Html(
                Text => $ReadableTitle,
            );
        }

        if ( length $ReadableValue ) {
            push @ReadableValues, $ReadableValue;
        }
        if ( length $NotTranslatedReadableValue ) {
            push @NotTranslatedValues, $NotTranslatedReadableValue;
        }
        if ( length $ReadableTitle ) {
            push @ReadableTitles, $ReadableTitle;
        }
    }

    # set new line separator
    my $Separator = ', ';
    if (
        IsHashRefWithData($Param{DynamicFieldConfig}) &&
        IsHashRefWithData($Param{DynamicFieldConfig}->{Config}) &&
        defined $Param{DynamicFieldConfig}->{Config}->{ItemSeparator}
    ) {
        $Separator = $Param{DynamicFieldConfig}->{Config}->{ItemSeparator};

        if ( $Param{HTMLOutput} ) {
            $Separator = $Param{LayoutObject}->Ascii2Html(
                Text => $Separator,
            );
        }
    }

    $Value = join( $Separator, @ReadableValues );
    $Title = join( $Separator, @ReadableTitles );
    $NotTranslatedValue = join( $Separator, @NotTranslatedValues );

    if ($ShowValueEllipsis) {
        $Value .= '...';
    }
    if ($ShowNotTranslatedValueEllipsis) {
        $NotTranslatedValue .= '...';
    }
    if ($ShowTitleEllipsis) {
        $Title .= '...';
    }

    # this field type does not support the Link Feature
    my $Link;

    # create return structure
    my $Data = {
        Value => $Value,
        Title => $Title,
        Link  => $Link,
        NotTranslatedValue => $NotTranslatedValue
    };

    return $Data;
}

sub ReadableValueRender {
    my ( $Self, %Param ) = @_;

    # set Value and Title variables
    my $Value = q{};
    my $Title = q{};

    # check value
    my @Values;
    if ( ref $Param{Value} eq 'ARRAY' ) {
        @Values = @{ $Param{Value} };
    }
    else {
        @Values = ( $Param{Value} );
    }

    my @ReadableValues;

    VALUEITEM:
    for my $Item (@Values) {
        next VALUEITEM if !defined $Item;

        push @ReadableValues, $Item;
    }

    # set new line separator
    my $Separator = ', ';
    if (
        IsHashRefWithData($Param{DynamicFieldConfig}) &&
        IsHashRefWithData($Param{DynamicFieldConfig}->{Config}) &&
        defined $Param{DynamicFieldConfig}->{Config}->{ItemSeparator}
    ) {
        $Separator = $Param{DynamicFieldConfig}->{Config}->{ItemSeparator};
    }

    # Output transformations
    $Value = join( $Separator, @ReadableValues );
    $Title = $Value;

    # cut strings if needed
    if ( $Param{ValueMaxChars} && length($Value) > $Param{ValueMaxChars} ) {
        $Value = substr( $Value, 0, $Param{ValueMaxChars} ) . '...';
    }
    if ( $Param{TitleMaxChars} && length($Title) > $Param{TitleMaxChars} ) {
        $Title = substr( $Title, 0, $Param{TitleMaxChars} ) . '...';
    }

    # create return structure
    my $Data = {
        Value => $Value,
        Title => $Title,
    };

    return $Data;
}

sub HistoricalValuesGet {
    my ( $Self, %Param ) = @_;

    # get historical values from database
    my $HistoricalValues = $Kernel::OM->Get('DynamicFieldValue')->HistoricalValueGet(
        FieldID   => $Param{DynamicFieldConfig}->{ID},
        ValueType => 'Text',
    );

    # return the historical values from database
    return $HistoricalValues;
}

sub ValueLookup {
    my ( $Self, %Param ) = @_;

    my @Keys;
    if ( ref $Param{Key} eq 'ARRAY' ) {
        @Keys = @{ $Param{Key} };
    }
    else {
        @Keys = ( $Param{Key} );
    }

    # get real values
    my $PossibleValues = $Param{DynamicFieldConfig}->{Config}->{PossibleValues};

    # to store final values
    my @Values;

    KEYITEM:
    for my $Item (@Keys) {
        next KEYITEM if (!(defined $Item) || $Item eq q{});

        # set the value as the key by default
        my $Value = $Item;

        # try to convert key to real value
        if ( $PossibleValues->{$Item} ) {
            $Value = $PossibleValues->{$Item};
        }
        push @Values, $Value;
    }

    return \@Values;
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
