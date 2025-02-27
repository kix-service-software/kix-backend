# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DynamicField::Driver::BaseDateTime;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use Kernel::Language qw(Translatable);

use base qw(Kernel::System::DynamicField::Driver::Base);

our @ObjectDependencies = qw(
    DB
    DynamicFieldValue
    Log
    Time
);

=head1 NAME

Kernel::System::DynamicField::Driver::BaseDateTime - sub module of
Kernel::System::DynamicField::Driver::Date and
Kernel::System::DynamicField::Driver::DateTime

=head1 SYNOPSIS

Date common functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

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
        push @ReturnData, $Item->{ValueDateTime}
    }

    return \@ReturnData;
}

sub ValueSet {
    my ( $Self, %Param ) = @_;

    my @Values;
    if ( ref $Param{Value} eq 'ARRAY' ) {
        @Values = @{ $Param{Value} };
    }
    else {
        @Values = ( $Param{Value} );
    }

    # get dynamic field value object
    my $DynamicFieldValueObject = $Kernel::OM->Get('DynamicFieldValue');

    my $Success;

    if ( IsArrayRefWithData( \@Values ) ) {

        # if there is at least one value to set, this means one or more values are selected,
        #    set those values!
        my @ValueDateTime;
        for my $Item (@Values) {
            my $Valid = $Self->ValueValidate(
                Value              => $Item,
                UserID             => $Param{UserID},
                DynamicFieldConfig => $Param{DynamicFieldConfig},
                Silent             => $Param{Silent} || 0
            );

            if (!$Valid) {
                return if $Param{Silent};

                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "The value for the field is invalid!"
                );
                return;
            }

            push @ValueDateTime, { ValueDateTime => $Item };
        }

        $Success = $DynamicFieldValueObject->ValueSet(
            FieldID  => $Param{DynamicFieldConfig}->{ID},
            ObjectID => $Param{ObjectID},
            Value    => \@ValueDateTime,
            UserID   => $Param{UserID},
            Silent   => $Param{Silent} || 0
        );
    } else {

        # delete all existing values for the dynamic field
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

    my $Prefix          = 'DynamicField_' . $Param{DynamicFieldConfig}->{Name};
    my $DateRestriction = $Param{DynamicFieldConfig}->{Config}->{DateRestriction};

    my $Success = $Kernel::OM->Get('DynamicFieldValue')->ValueValidate(
        Value => {
            ValueDateTime => $Param{Value},
        },
        UserID => $Param{UserID},
        Silent => $Param{Silent} || 0
    );

    if (!$Param{SearchValidation} && IsStringWithData($Param{Value}) && $DateRestriction) {

        # get time object
        my $TimeObject = $Kernel::OM->Get('Time');

        my $ValueSystemTime = $TimeObject->TimeStamp2SystemTime(
            String => $Param{Value},
        );
        my $SystemTime = $TimeObject->SystemTime();

        if ( $DateRestriction eq 'DisableFutureDates' && $ValueSystemTime > $SystemTime ) {
            return if $Param{Silent};

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message =>
                    "The value for the field Date is in the future! The date needs to be in the past!",
            );
            return;
        }
        elsif ( $DateRestriction eq 'DisablePastDates' && $ValueSystemTime < $SystemTime ) {
            return if $Param{Silent};

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message =>
                    "The value for the field Date is in the past! The date needs to be in the future!",
            );
            return;
        }
    }

    return $Success;
}


sub SearchSQLSearchFieldGet {
    my ( $Self, %Param ) = @_;

    return {
        Column => "$Param{TableAlias}.value_date"
    };
}

sub SearchSQLSortFieldGet {
    my ( $Self, %Param ) = @_;

    return {
        Select  => ["$Param{TableAlias}.value_date"],
        OrderBy => ["$Param{TableAlias}.value_date"]
    };
}

sub DisplayValueRender {
    my ( $Self, %Param ) = @_;

    my $Value = q{};

    # check value
    my @Values;
    if ( ref $Param{Value} eq 'ARRAY' ) {
        @Values = @{ $Param{Value} };
    }
    else {
        @Values = ( $Param{Value} );
    }

    # convert date to localized string
    my @LocalizedValues;
    for my $Date ( @Values) {
        next if !$Date;
        if ( defined $Date ) {
            my $LocalizedValue = $Param{LayoutObject}->{LanguageObject}->FormatTimeString(
                $Date,
                'DateFormat',
                'NoSeconds',
            );
            push(@LocalizedValues, $LocalizedValue);
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

    # Output transformations
    $Value = join( $Separator, @LocalizedValues );
    my $Title = $Value;

    # set field link form config
    my $Link        = $Param{DynamicFieldConfig}->{Config}->{Link}        || q{};
    my $LinkPreview = $Param{DynamicFieldConfig}->{Config}->{LinkPreview} || q{};

    my $Data = {
        Value       => $Value,
        Title       => $Title,
        Link        => $Link,
        LinkPreview => $LinkPreview,
        NotTranslatedValue => join( $Separator, @Values )
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
    for my $Date (@Values) {
        next VALUEITEM if !$Date;

        # only keep date and time without seconds or milliseconds
        $Date =~ s{\A (\d{4} - \d{2} - \d{2} [ ] \d{2} : \d{2} ) }{$1}xms;

        push @ReadableValues, $Date;
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

    $Value = join( $Separator, @ReadableValues );
    $Title = $Value;

    my $Data = {
        Value => $Value,
        Title => $Title,
    };

    return $Data;
}
sub RandomValueSet {
    my ( $Self, %Param ) = @_;

    my $YearValue   = int( rand(40) ) + 1_990;
    my $MonthValue  = int( rand(9) ) + 1;
    my $DayValue    = int( rand(10) ) + 10;
    my $HourValue   = int( rand(12) ) + 10;
    my $MinuteValue = int( rand(30) ) + 10;
    my $SecondValue = int( rand(30) ) + 10;

    my $Value = $YearValue
        . '-0'
        . $MonthValue
        . q{-}
        . $DayValue
        . q{ }
        . $HourValue
        . q{:}
        . $MinuteValue
        . q{:}
        . $SecondValue;

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
        ValueType => 'DateTime',
    );

    # return the historical values from database
    return $HistoricalValues;
}

sub ValueLookup {
    my ( $Self, %Param ) = @_;

    # check key
    my @Keys;
    if ( ref $Param{Key} eq 'ARRAY' ) {
        @Keys = @{ $Param{Key} };
    }
    else {
        @Keys = ( $Param{Key} );
    }

    return \@Keys;
}

sub GetCacheDependencies {
    my ( $Self, %Param ) = @_;

    # return "UserLanguage" because of prepared DF display values (localisation)
    return ['UserLanguage'];
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
