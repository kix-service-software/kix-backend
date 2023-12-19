# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DynamicField::Driver::BaseSelect;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::DynamicField::Driver::Base);

our @ObjectDependencies = qw(
    DB
    DynamicFieldValue
    Log
);

=head1 NAME

Kernel::System::DynamicField::Driver::BaseSelect

=head1 SYNOPSIS

Date common functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

sub ValueGet {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $DynamicFieldValueObject = $Kernel::OM->Get('DynamicFieldValue');

    my $DFValue = $DynamicFieldValueObject->ValueGet(
        FieldID  => $Param{DynamicFieldConfig}->{ID},
        ObjectID => $Param{ObjectID},
        Silent   => $Param{Silent} || 0
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

sub ValueSet {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $DynamicFieldValueObject = $Kernel::OM->Get('DynamicFieldValue');
    my $LogObject               = $Kernel::OM->Get('Log');

    # check value
    my @Values;
    if ( ref $Param{Value} eq 'ARRAY' ) {
        @Values = @{ $Param{Value} };
    }
    else {
        @Values = ( $Param{Value} );
    }

    my $Success;
    if ( IsArrayRefWithData( \@Values ) ) {

        # if there is at least one value to set, this means one or more values are selected,
        #    set those values!
        my $Valid = $Self->ValueValidate(
            Value              => $Param{Value},
            UserID             => $Param{UserID},
            DynamicFieldConfig => $Param{DynamicFieldConfig},
            Silent             => $Param{Silent} || 0
        );

        if (!$Valid) {
            return if $Param{Silent};

            $LogObject->Log(
                Priority => 'error',
                Message  => "The value for the field is invalid!"
            );
            return;
        }

        my @ValueText;
        for my $Item (@Values) {
            push @ValueText, { ValueText => $Item };
        }

        $Success = $DynamicFieldValueObject->ValueSet(
            FieldID  => $Param{DynamicFieldConfig}->{ID},
            ObjectID => $Param{ObjectID},
            Value    => \@ValueText,
            UserID   => $Param{UserID},
            Silent   => $Param{Silent} || 0
        );
    } else {

        # otherwise no value was selected, then in fact this means that any value there should be deleted
        $Success = $DynamicFieldValueObject->ValueDelete(
            FieldID  => $Param{DynamicFieldConfig}->{ID},
            ObjectID => $Param{ObjectID},
            UserID   => $Param{UserID},
            Silent   => $Param{Silent} || 0
        );
    }

    return $Success;
}

sub ValueValidate {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $DynamicFieldValueObject = $Kernel::OM->Get('DynamicFieldValue');
    my $LogObject               = $Kernel::OM->Get('Log');

    # check value
    my @Values;
    if ( IsArrayRefWithData( $Param{Value} ) ) {
        @Values = @{ $Param{Value} };
    } elsif (defined $Param{Value}) {
        @Values = ( $Param{Value} );
    }

    if(!$Param{SearchValidation}) {

        my $CountMin = $Param{DynamicFieldConfig}->{Config}->{CountMin};
        if (
            $CountMin
            && scalar(@Values) < $CountMin
        ) {
            return if $Param{Silent};

            $LogObject->Log(
                Priority => 'error',
                Message => "At least $CountMin value(s) must be selected."
            );
            return;
        }

        my $CountMax = $Param{DynamicFieldConfig}->{Config}->{CountMax};
        if (
            $CountMax
            && $CountMax > 1
            && scalar(@Values) > $CountMax
        ) {
            return if $Param{Silent};

            $LogObject->Log(
                Priority => 'error',
                Message => "A maximum of $CountMax values can be selected."
            );
            return;
        }

        if(
            (
                !$CountMax
                || 1 == $CountMax
                || 0 == $CountMax
            )
            && scalar(@Values) > 1
        ) {
            return if $Param{Silent};

            $LogObject->Log(
                Priority => 'error',
                Message => "A maximum of 1 value can be selected. (Singleselect)"
            );
            return;
        }

        if (IsHashRefWithData($Param{DynamicFieldConfig}->{Config}->{PossibleValues})) {
            for my $Item (@Values) {
                my $Known = $Param{DynamicFieldConfig}->{Config}->{PossibleValues}->{$Item};

                if (!$Known) {
                    return if $Param{Silent};

                    $LogObject->Log(
                        Priority => 'error',
                        Message  => "Unknown value ($Item)"
                    );
                    return;
                }
            }
        }
    }

    for my $Item (@Values) {
        my $Success = $DynamicFieldValueObject->ValueValidate(
            Value => {
                ValueText => $Item,
            },
            UserID => $Param{UserID}
        );

        return if !$Success
    }

    return 1;
}

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

sub SearchSQLSearchFieldGet {
    my ( $Self, %Param ) = @_;

    return {
        Column => "$Param{TableAlias}.value_text"
    };
}

sub SearchSQLSortFieldGet {
    my ( $Self, %Param ) = @_;

    return {
        Select  => ["$Param{TableAlias}.value_text"],
        OrderBy => ["$Param{TableAlias}.value_text"]
    };
}

sub DisplayValueRender {
    my ( $Self, %Param ) = @_;

    # set HTMLOuput as default if not specified
    if ( !defined $Param{HTMLOutput} ) {
        $Param{HTMLOutput} = 1;
    }

    # get raw Value strings from field value
    my $Value = defined $Param{Value} ? $Param{Value} : q{};

    # get real value
    if ( $Param{DynamicFieldConfig}->{Config}->{PossibleValues}->{$Value} ) {

        # get readable value
        $Value = $Param{DynamicFieldConfig}->{Config}->{PossibleValues}->{$Value};
    }

    # check is needed to translate values
    if ( $Param{DynamicFieldConfig}->{Config}->{TranslatableValues} ) {

        # translate value
        $Value = $Param{LayoutObject}->{LanguageObject}->Translate($Value);
    }

    # set title as value after update and before limit
    my $Title = $Value;

    # HTMLOuput transformations
    if ( $Param{HTMLOutput} ) {
        $Value = $Param{LayoutObject}->Ascii2Html(
            Text => $Value,
            Max  => $Param{ValueMaxChars} || q{},
        );

        $Title = $Param{LayoutObject}->Ascii2Html(
            Text => $Title,
            Max  => $Param{TitleMaxChars} || q{},
        );
    }
    else {
        if ( $Param{ValueMaxChars} && length($Value) > $Param{ValueMaxChars} ) {
            $Value = substr( $Value, 0, $Param{ValueMaxChars} ) . '...';
        }
        if ( $Param{TitleMaxChars} && length($Title) > $Param{TitleMaxChars} ) {
            $Title = substr( $Title, 0, $Param{TitleMaxChars} ) . '...';
        }
    }

    # set field link from config
    my $Link        = $Param{DynamicFieldConfig}->{Config}->{Link}        || q{};
    my $LinkPreview = $Param{DynamicFieldConfig}->{Config}->{LinkPreview} || q{};

    my $Data = {
        Value       => $Value,
        Title       => $Title,
        Link        => $Link,
        LinkPreview => $LinkPreview,
    };

    return $Data;
}


sub ReadableValueRender {
    my ( $Self, %Param ) = @_;

    my $Value = defined $Param{Value} ? $Param{Value} : q{};

    # set title as value after update and before limit
    my $Title = $Value;

    # cut strings if needed
    if ( $Param{ValueMaxChars} && length($Value) > $Param{ValueMaxChars} ) {
        $Value = substr( $Value, 0, $Param{ValueMaxChars} ) . '...';
    }
    if ( $Param{TitleMaxChars} && length($Title) > $Param{TitleMaxChars} ) {
        $Title = substr( $Title, 0, $Param{TitleMaxChars} ) . '...';
    }

    my $Data = {
        Value => $Value,
        Title => $Title,
    };

    return $Data;
}
sub RandomValueSet {
    my ( $Self, %Param ) = @_;

    my $Value = int( rand(500) );

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
        ValueType => 'Text',
    );

    # return the historical values from database
    return $HistoricalValues;
}

sub ValueLookup {
    my ( $Self, %Param ) = @_;

    my $Value = defined $Param{Key} ? $Param{Key} : q{};

    # get real values
    my $PossibleValues = $Param{DynamicFieldConfig}->{Config}->{PossibleValues};

    if ($Value) {

        # check if there is a real value for this key (otherwise keep the key)
        if ( $Param{DynamicFieldConfig}->{Config}->{PossibleValues}->{$Value} ) {

            # get readable value
            $Value = $Param{DynamicFieldConfig}->{Config}->{PossibleValues}->{$Value};

        }
    }

    return $Value;
}

sub DisplayKeyRender {
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

    my @Keys;
    VALUEITEM:
    for my $Item (@Values) {
        next VALUEITEM if !defined $Item;

        push @Keys, $Item;
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

    # output transformations
    $Value = join( $Separator, @Keys );
    $Title = $Value;

    # create return structure
    my $Data = {
        Value => $Value,
        Title => $Title,
    };

    return $Data;
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
