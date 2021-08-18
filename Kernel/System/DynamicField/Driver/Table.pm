# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DynamicField::Driver::Table;

use strict;
use warnings;

use base qw(Kernel::System::DynamicField::Driver::Base);

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'DynamicFieldValue',
    'Log',
    'Main',
    'JSON'
);

=head1 NAME

Kernel::System::DynamicField::Driver::Table

=head1 SYNOPSIS

DynamicFields Attachment backend delegate

=head1 PUBLIC INTERFACE

This module implements the public interface of L<Kernel::System::DynamicField::Backend>.
Please look there for a detailed reference of the functions.

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # create additional objects
    my $ConfigObject = $Kernel::OM->Get('Config');
    my $MainObject   = $Kernel::OM->Get('Main');

    # set field behaviors
    $Self->{Behaviors} = {
        'IsACLReducible'               => 0,
        'IsNotificationEventCondition' => 0,
        'IsSortable'                   => 0,
        'IsFiltrable'                  => 0,
        'IsStatsCondition'             => 0,
        'IsCustomerInterfaceCapable'   => 1,
    };

    # get the Dynamic Field Backend custom extensions
    my $DriverExtensions = $ConfigObject->Get('DynamicFields::Extension::Driver::Table');

    EXTENSION:
    for my $ExtensionKey ( sort keys %{$DriverExtensions} ) {

        # skip invalid extensions
        next EXTENSION if !IsHashRefWithData( $DriverExtensions->{$ExtensionKey} );

        # create a extension config shortcut
        my $Extension = $DriverExtensions->{$ExtensionKey};

        # check if extension has a new module
        if ( $Extension->{Module} ) {

            # check if module can be loaded
            if (
                !$MainObject->RequireBaseClass( $Extension->{Module} )
            ) {
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

    my $ValueObject = $Kernel::OM->Get('DynamicFieldValue');

    my $DFValue = $ValueObject->ValueGet(
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

sub ValueSet {
    my ( $Self, %Param ) = @_;

    my $ValueObject = $Kernel::OM->Get('DynamicFieldValue');

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

        # if there is at least one value to set, this means one or more values are selected, set those values!
        my @ValueText;
        for my $Item (@Values) {
            push @ValueText, { ValueText => $Item };
        }

        $Success = $ValueObject->ValueSet(
            FieldID  => $Param{DynamicFieldConfig}->{ID},
            ObjectID => $Param{ObjectID},
            Value    => \@ValueText,
            UserID   => $Param{UserID},
        );
    }
    else {

        # otherwise no value was selected, then in fact this means that any value there should be deleted
        $Success = $ValueObject->ValueDelete(
            FieldID  => $Param{DynamicFieldConfig}->{ID},
            ObjectID => $Param{ObjectID},
            UserID   => $Param{UserID},
        );
    }

    return $Success;
}

sub ValueLookup {
    my ( $Self, %Param ) = @_;

    return if ( !defined( $Param{Key} ) );
    return '' if ( $Param{Key} eq '' );

    # return array or scalar depending on $Param{Key}
    my $Result;
    if (
        ref $Param{Key} eq 'ARRAY'
        && $Param{Key}->[0]
    ) {
        $Result = $Param{Key};
    }
    elsif (
        ref $Param{Value} ne 'HASH'
        && ref $Param{Value} ne 'ARRAY'
        && $Param{Key}
    ) {
        $Result = $Param{Key};
    }

    return $Result;
}

sub ValueIsDifferent {
    my ( $Self, %Param ) = @_;

    # special cases where the values are different but they should be reported as equals
    if (
        !defined $Param{Value1}
        && ref $Param{Value2} eq 'ARRAY'
        && (
            !IsArrayRefWithData( $Param{Value2} )
            || !$Param{Value2}->[0]
        )
    ) {
        return
    }
    if (
        !defined $Param{Value2}
        && ref $Param{Value1} eq 'ARRAY'
        && (
            !IsArrayRefWithData( $Param{Value1} )
            || !$Param{Value1}->[0]
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

sub ValueValidate {
    my ( $Self, %Param ) = @_;

    my $ValueObject = $Kernel::OM->Get('DynamicFieldValue');

    # check value
    my @Values;
    if ( IsArrayRefWithData( $Param{Value} ) ) {
        @Values = @{ $Param{Value} };
    }
    else {
        @Values = ( $Param{Value} );
    }

    my $Success;
    for my $Item (@Values) {

        $Success = $ValueObject->ValueValidate(
            Value => {
                ValueText => $Item,
            },
            UserID => $Param{UserID}
        );

        return if !$Success
    }

    return $Success;
}

sub TemplateValueTypeGet {
    my ( $Self, %Param ) = @_;

    my $FieldName = 'DynamicField_' . $Param{DynamicFieldConfig}->{Name};

    # set the field types
    my $EditValueType   = 'ARRAY';
    my $SearchValueType = 'SCALAR';

    # return the correct structure
    if ( $Param{FieldType} eq 'Edit' ) {
        return {
            $FieldName => $EditValueType,
            }
    }
    elsif ( $Param{FieldType} eq 'Search' ) {
        return {
            'Search_' . $FieldName => $SearchValueType,
            }
    }
    else {
        return {
            $FieldName             => $EditValueType,
            'Search_' . $FieldName => $SearchValueType,
        }
    }
}

sub EditFieldValueGet {
    my ( $Self, %Param ) = @_;

    my $JSONObject = $Kernel::OM->Get('JSON');
    my $FieldName  = 'DynamicField_' . $Param{DynamicFieldConfig}->{Name};
    my $Value;
    my @Values;

    # check if there is a Template and retrieve the dynamic field value from there
    if (
        IsHashRefWithData( $Param{Template} )
        && defined $Param{Template}->{$FieldName}
    ) {
        $Value  = $Param{Template}->{$FieldName};
    }

    # otherwise get dynamic field value from the web request
    elsif (
        defined $Param{ParamObject}
        && ref $Param{ParamObject} eq 'WebRequest'
    ) {
        my @ParamNames = $Param{ParamObject}->GetParamNames();

        for my $Key ( sort @ParamNames ) {
            my $Pattern = '^'
                . $FieldName
                . '_\d+$';

            next if $Key !~ /$Pattern/;

            my @Data = $Param{ParamObject}->GetArray( Param => $Key );
            push(@Values, \@Data);
        }

        if ( scalar( @Values ) ) {

            my $IsEmpty = 1;
            EMPTY:
            for my $Index ( @Values ) {
                for my $Val ( @{$Index} ) {
                    if ( $Val ) {
                        $IsEmpty = 0;
                        last EMPTY;
                    }
                }
            }

            if ( !$IsEmpty ) {
                $Value = $JSONObject->Encode(
                    Data => \@Values
                );
            }
        }
    }

    if (
        defined $Param{ReturnTemplateStructure}
        && $Param{ReturnTemplateStructure} eq '1'
    ) {
        return {
            $FieldName => $Value,
        };
    }

    if (
        defined $Param{ReturnValueStructure}
        && $Param{ReturnValueStructure} eq '1'
    ) {
        return \@Values;
    }

    # for this field the normal return are an json string
    return $Value;
}

sub EditFieldValueValidate {
    my ( $Self, %Param ) = @_;

    # get the field value from the http request
    my $Values = $Self->EditFieldValueGet(
        DynamicFieldConfig => $Param{DynamicFieldConfig},
        ParamObject        => $Param{ParamObject},

        # not necessary for this Driver but place it for consistency reasons
        ReturnValueStructure => 1,
    );

    my $ServerError;
    my $ErrorMessage;

    # perform necessary validations
    if (
        $Param{Mandatory}
        && !IsArrayRefWithData($Values)
    ) {
        return {
            ServerError => 1,
        };
    }

    # create resulting structure
    my $Result = {
        ServerError  => $ServerError,
        ErrorMessage => $ErrorMessage,
    };

    return $Result;
}

sub SearchFieldValueGet {
    my ( $Self, %Param ) = @_;

    my $Value = '';

    # get dynamic field value from param object
    if ( defined $Param{ParamObject} ) {
        $Value = $Param{ParamObject}->GetParam(
            Param => 'Search_DynamicField_' . $Param{DynamicFieldConfig}->{Name}
        ) || '';
    }

    # otherwise get the value from the profile
    elsif ( defined $Param{Profile} ) {
        $Value = $Param{Profile}->{ 'Search_DynamicField_' . $Param{DynamicFieldConfig}->{Name} } || '';
    }
    else {
        return;
    }

    if ( defined $Param{ReturnProfileStructure} && $Param{ReturnProfileStructure} eq '1' ) {
        return {
            'Search_DynamicField_' . $Param{DynamicFieldConfig}->{Name} => $Value,
        };
    }

    return $Value;
}

sub SearchFieldParameterBuild {
    my ( $Self, %Param ) = @_;

    # get field value
    my $Value = $Self->SearchFieldValueGet(%Param);

    # return search parameter structure
    return {
        Parameter => {
            'Like' => '*' . $Value . '*',
        },
        Display => $Value,
    };
}

sub SearchSQLGet {
    my ( $Self, %Param ) = @_;

    my %Operators = (
        Equals            => '=',
        GreaterThan       => '>',
        GreaterThanEquals => '>=',
        SmallerThan       => '<',
        SmallerThanEquals => '<=',
    );

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    if ( $Operators{ $Param{Operator} } ) {
        my $SQL = " $Param{TableAlias}.value_text $Operators{$Param{Operator}} '";
        $SQL .= $DBObject->Quote( $Param{SearchTerm} ) . "' ";
        return $SQL;
    }

    if ( $Param{Operator} eq 'Like' ) {

        my $SQL = $DBObject->QueryCondition(
            Key   => "$Param{TableAlias}.value_text",
            Value => $Param{SearchTerm},
        );

        return $SQL;
    }

    $Kernel::OM->Get('Log')->Log(
        'Priority' => 'error',
        'Message'  => "Unsupported Operator $Param{Operator}",
    );

    return;
}

sub StatsFieldParameterBuild {
    my ( $Self, %Param ) = @_;

    return ;
}

sub StatsSearchFieldParameterBuild {
    my ( $Self, %Param ) = @_;

    return ;
}

sub ReadableValueRender {
    my ( $Self, %Param ) = @_;

    my $Value = '';

    if (
        ref $Param{Value} eq 'ARRAY'
        && $Param{Value}->[0]
    ) {
        $Value = $Param{Value}->[0];
    }
    elsif (
        ref $Param{Value} ne 'HASH'
        && ref $Param{Value} ne 'ARRAY'
        && $Param{Value}
    ) {
        $Value = $Param{Value};
    }

    my $Title = $Value;

    # cut strings if needed
    if (
        $Param{ValueMaxChars}
        && length($Value) > $Param{ValueMaxChars}
    ) {
        $Value = substr( $Value, 0, $Param{ValueMaxChars} ) . '...';
    }

    if (
        $Param{TitleMaxChars}
        && length($Title) > $Param{TitleMaxChars}
    ) {
        $Title = substr( $Title, 0, $Param{TitleMaxChars} ) . '...';
    }

    # create return structure
    my $Data = {
        Value => $Value,
        Title => $Title,
    };

    return $Data;
}

sub DisplayValueRender {
    my ( $Self, %Param ) = @_;

    my $HTMLUtilsObject = $Kernel::OM->Get('HTMLUtils');
    my $HTMLData = $Self->HTMLDisplayValueRender(%Param);

    my $Output = '';
    if ( $HTMLData->{Value} ) {
        $Output = $HTMLUtilsObject->ToAscii(
            String => $HTMLData->{Value}
        );
    }
    # create return structure
    my $Data = {
        Value => $Output,
        Title => $HTMLData->{Title}
    };

    return $Data;
}

sub HTMLDisplayValueRender {
    my ( $Self, %Param ) = @_;

    my $JSONObject     = $Kernel::OM->Get('JSON');
    my $LanguageObject = $Param{LayoutObject}->{LanguageObject};

    my $FieldConfig = $Param{DynamicFieldConfig}->{Config};
    my $Output      = '';

    # get raw Value strings from field value
    my $Title = '';
    my $Values;
    if (
        ref $Param{Value} eq 'ARRAY'
        && $Param{Value}->[0]
    ) {
        $Title  = $Param{Value}->[0];
        $Values = $JSONObject->Decode(
            Data => $Param{Value}->[0]
        );
    }
    elsif (
        ref $Param{Value} ne 'HASH'
        && ref $Param{Value} ne 'ARRAY'
        && $Param{Value}
    ) {
        $Title  = $Param{Value};
        $Values = $JSONObject->Decode(
            Data => $Param{Value}
        );
    }
    else {
        return;
    }

    $Output = <<"END";
<table border="1" cellspacing="0" cellpadding="2">
    <thead>
        <tr>
END

    for my $Column ( @{$FieldConfig->{Columns}} ) {
        my $Col = $Column;

        # get column header transatlation
        if (
            $Col
            && $FieldConfig->{TranslatableColumn}
        ) {
            $Col = $LanguageObject->Translate(
                $Col
            );
        }

        $Output .= <<"END";
            <th>$Col</th>
END
        }

        $Output .= <<"END";
        </tr>
    </thead>
    <tbody>
END

        for my $Row ( @{$Values} ) {

            $Output .= <<"END";
        <tr>
END
            for my $Col ( @{$Row} ) {
                $Output .= <<"END";
            <td>$Col</td>
END
            }
        $Output .= <<"END";
        </tr>
END
        }

        $Output .= <<"END";
    </tbody>
</table>
END

    # create return structure
    my $Data = {
        Value => $Output,
        Title => $Title,
        Link  => '',
    };

    return $Data;
}

sub ShortDisplayValueRender {
    my ( $Self, %Param ) = @_;

    my $JSONObject     = $Kernel::OM->Get('JSON');
    my $LanguageObject = $Param{LayoutObject}->{LanguageObject};

    my $FieldConfig = $Param{DynamicFieldConfig}->{Config};
    my $Output      = '';

    # get raw Value strings from field value
    my $Title = '';
    my $Values;
    if (
        ref $Param{Value} eq 'ARRAY'
        && $Param{Value}->[0]
    ) {
        $Title  = $Param{Value}->[0];
        $Values = $JSONObject->Decode(
            Data => $Param{Value}->[0]
        );
    }
    elsif (
        ref $Param{Value} ne 'HASH'
        && ref $Param{Value} ne 'ARRAY'
        && $Param{Value}
    ) {
        $Title  = $Param{Value};
        $Values = $JSONObject->Decode(
            Data => $Param{Value}
        );
    }
    else {
        return;
    }

    if ( $Values ) {
        $Output = $LanguageObject->Translate('%s rows', scalar(@{$Values}));
    }

    # create return structure
    my $Data = {
        Value => $Output,
        Title => $Title
    };

    return $Data;
}

sub RandomValueSet {
    my ( $Self, %Param ) = @_;

    return {
        Success => 0,
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

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
