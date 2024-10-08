# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DynamicField::Driver::BaseText;

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

Kernel::System::DynamicField::Driver::BaseText - sub module of
Kernel::System::DynamicField::Driver::Text and
Kernel::System::DynamicField::Driver::TextArea

=head1 SYNOPSIS

Text common functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

sub ValueSet {
    my ( $Self, %Param ) = @_;

    # check value
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
        my @ValueText;
        for my $Item (@Values) {
            my $Valid = $Self->ValueValidate(
                Value => $Item,
                UserID => $Param{UserID},
                DynamicFieldConfig => $Param{DynamicFieldConfig}
            );

            if (!$Valid) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "The value for the field Text is invalid!"
                );
                return;
            }

            push @ValueText, { ValueText => $Item };
        }

        $Success = $DynamicFieldValueObject->ValueSet(
            FieldID  => $Param{DynamicFieldConfig}->{ID},
            ObjectID => $Param{ObjectID},
            Value    => \@ValueText,
            UserID   => $Param{UserID},
        );
    } else {

        # delete all existing values for the dynamic field
        $Success = $DynamicFieldValueObject->ValueDelete(
            FieldID  => $Param{DynamicFieldConfig}->{ID},
            ObjectID => $Param{ObjectID},
            UserID   => $Param{UserID},
        );
    }

    return $Success;
}

sub ValueValidate {
    my ( $Self, %Param ) = @_;

    my $Success = $Kernel::OM->Get('DynamicFieldValue')->ValueValidate(
        Value => {
            ValueText => $Param{Value},
        },
        UserID => $Param{UserID}
    );

    if (
        !$Param{SearchValidation}
        && IsArrayRefWithData( $Param{DynamicFieldConfig}->{Config}->{RegExList} )
        && IsStringWithData( $Param{Value} )
    ) {
        # check regular expressions
        my @RegExList = @{ $Param{DynamicFieldConfig}->{Config}->{RegExList} };

        REGEXENTRY:
        for my $RegEx (@RegExList) {

            if ( $Param{Value} !~ $RegEx->{Value} ) {
                $Success = undef;
                last if $Param{Silent};

                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "The value '$Param{Value}' is not matching /"
                        . $RegEx->{Value} . "/ ("
                        . $RegEx->{ErrorMessage} . ")!",
                );
                last REGEXENTRY;
            }
        }
    }

    return $Success;
}

sub SearchSQLSearchFieldGet {
    my ( $Self, %Param ) = @_;

    return {
        Column          => "$Param{TableAlias}.value_text",
        CaseInsensitive => 1
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

    my $ValueMaxChars = $Param{ValueMaxChars} || q{};
    my $TitleMaxChars = $Param{TitleMaxChars} || q{};

    # check value
    my @Values;
    if ( ref $Param{Value} eq 'ARRAY' ) {
        @Values = @{ $Param{Value} };
    }
    else {
        @Values = ( $Param{Value} );
    }

    my @ReadableValues;
    my @ReadableTitles;

    my $ShowValueEllipsis;
    my $ShowTitleEllipsis;

    for my $Text (@Values) {
        next if !$Text;

        my $ReadableValue = $Text;

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

        if ( $TitleMaxChars ne q{} ) {

            if ( length $ReadableTitle > $ValueMaxChars ) {
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

            $ReadableTitle = $Param{LayoutObject}->Ascii2Html(
                Text => $ReadableTitle,
            );
        }

        if ( length $ReadableValue ) {
            push @ReadableValues, $ReadableValue;
        }
        if ( length $ReadableTitle ) {
            push @ReadableTitles, $ReadableTitle;
        }
    }

    # set field link form config
    my $Link        = $Param{DynamicFieldConfig}->{Config}->{Link}        || q{};
    my $LinkPreview = $Param{DynamicFieldConfig}->{Config}->{LinkPreview} || q{};

    # set new line separator
    my $Separator = ', ';
    if (
        IsHashRefWithData($Param{DynamicFieldConfig}) &&
        IsHashRefWithData($Param{DynamicFieldConfig}->{Config}) &&
        defined $Param{DynamicFieldConfig}->{Config}->{ItemSeparator}
    ) {
        $Separator = $Param{DynamicFieldConfig}->{Config}->{ItemSeparator};
    }

    my $Value = join( $Separator, @ReadableValues );
    my $Title = join( $Separator, @ReadableTitles );

    if ($ShowValueEllipsis) {
        $Value .= '...';
    }
    if ($ShowTitleEllipsis) {
        $Title .= '...';
    }

    # create return structure
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
        next VALUEITEM if !$Item;

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
