# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
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

    # check value
    my @Values;
    if ( IsArrayRefWithData( $Param{Value} ) ) {
        @Values = @{ $Param{Value} };
    } elsif (defined $Param{Value}) {
        @Values = ( $Param{Value} );
    }

    if( !$Param{SearchValidation} ) {
        my $CountMin = $Param{DynamicFieldConfig}->{Config}->{CountMin};
        if (
            $CountMin
            && scalar(@Values) < $CountMin
        ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "At least $CountMin value(s) must be selected.",
                Silent   => $Param{Silent},
            );
            return;
        }

        my $CountMax = $Param{DynamicFieldConfig}->{Config}->{CountMax};
        if (
            $CountMax
            && $CountMax > 1
            && scalar(@Values) > $CountMax
        ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "A maximum of $CountMax values can be selected.",
                Silent   => $Param{Silent},
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
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "A maximum of 1 value can be selected. (Singleselect)",
                Silent   => $Param{Silent},
            );
            return;
        }

        # make sure PossibleValues is a hashref
        $Param{DynamicFieldConfig}->{Config}->{PossibleValues} //= {};

        # check the values
        my $AppendValues;
        my @RegExList;
        my $PossibleValuesChanged = 0;
        ITEM:
        for my $Item (@Values) {
            # lookup value
            my $Known = $Param{DynamicFieldConfig}->{Config}->{PossibleValues}->{ $Item };

            # skip know values
            next ITEM if ( defined( $Known ) );

            # init AppendValues config if needed
            if ( !defined( $AppendValues ) ) {
                $AppendValues = $Param{DynamicFieldConfig}->{Config}->{AppendValues} || 0;

                # check if AppendValues is active and AppendValuesRoleIDs given
                if (
                    $AppendValues
                    && IsArrayRefWithData( $Param{DynamicFieldConfig}->{Config}->{AppendValuesRoleIDs} )
                ) {
                    # assume the agent does not have an allowed role
                    $AppendValues = 0;

                    # get role list of user
                    my @RoleIDs = $Kernel::OM->Get('Role')->UserRoleList(
                        UserID => $Param{UserID},
                    );

                    # check for allowed role
                    ROLE:
                    for my $RoleID ( @{ $Param{DynamicFieldConfig}->{Config}->{AppendValuesRoleIDs} } ) {
                        if ( grep { $_ eq $RoleID } @RoleIDs ) {
                            $AppendValues = 1;

                            last ROLE;
                        }
                    }
                }

                # init regex list when AppendValues is allowed
                if ( $AppendValues ) {
                    @RegExList = @{ $Param{DynamicFieldConfig}->{Config}->{AppendValuesRegexList} || [] };
                }
            }

            # append new value
            if ( $AppendValues ) {
                # check value against regex list
                for my $RegEx ( @RegExList ) {
                    if ( $Item !~ $RegEx->{Value} ) {
                        $Kernel::OM->Get('Log')->Log(
                            Priority => 'error',
                            Message  => "Invalid value ($Item)",
                            Slient   => $Param{Silent},
                        );
                        return;
                    }
                }

                # add new value to possible values
                $Param{DynamicFieldConfig}->{Config}->{PossibleValues}->{ $Item } = $Item;

                # remember the change
                $PossibleValuesChanged = 1;
            }
            else {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unknown value ($Item)",
                    Silent   => $Param{Silent},
                );
                return;
            }
        }

        # check for change
        if ( $PossibleValuesChanged ) {
            # update DynamicField with new PossibleValues
            my $Success = $Kernel::OM->Get('DynamicField')->DynamicFieldUpdate(
                %{ $Param{DynamicFieldConfig} },
                UserID => $Param{UserID},
            );
            if ( !$Success ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => 'Error while updateing dynamic field "' . $Param{DynamicFieldConfig}->{Name} . '"!',
                    Silent   => $Param{Silent},
                );
            }
        }
    }

    for my $Item (@Values) {
        my $Success = $Kernel::OM->Get('DynamicFieldValue')->ValueValidate(
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

    my $NotTranslatedValue = $Value;

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

        $NotTranslatedValue = $Param{LayoutObject}->Ascii2Html(
            Text => $NotTranslatedValue,
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
        if ( $Param{ValueMaxChars} && length($NotTranslatedValue) > $Param{ValueMaxChars} ) {
            $NotTranslatedValue = substr( $NotTranslatedValue, 0, $Param{ValueMaxChars} ) . '...';
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
        NotTranslatedValue => $NotTranslatedValue
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
