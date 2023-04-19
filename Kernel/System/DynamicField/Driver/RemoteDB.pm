# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::DynamicField::Driver::RemoteDB;

use strict;
use warnings;

use base qw(Kernel::System::DynamicField::Driver::Base);

use Kernel::System::DFRemoteDB;
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'Cache',
    'DB',
    'DynamicFieldValue',
    'Log',
    'Main',
    'Ticket::ColumnFilter',
);

=head1 NAME

Kernel::System::DynamicField::Driver::RemoteDB

=head1 SYNOPSIS

DynamicFields RemoteDB backend delegate

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
    $Self->{ConfigObject}            = $Kernel::OM->Get('Config');
    $Self->{DynamicFieldValueObject} = $Kernel::OM->Get('DynamicFieldValue');

    # get the fields config
    $Self->{FieldTypeConfig} = $Self->{ConfigObject}->Get('DynamicFields::Driver') || {};

    # set field behaviors
    $Self->{Behaviors} = {
        'IsNotificationEventCondition' => 1,
        'IsSortable'                   => 1,
        'IsFiltrable'                  => 1,
        'IsStatsCondition'             => 1,
        'IsCustomerInterfaceCapable'   => 1,
    };

    # get the Dynamic Field Backend custom extensions
    my $DynamicFieldDriverExtensions = $Self->{ConfigObject}->Get('DynamicFields::Extension::Driver::RemoteDB');

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

    my $DFValue = $Self->{DynamicFieldValueObject}->ValueGet(
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
        my @ValueText;
        for my $Item (@Values) {
            push @ValueText, { ValueText => $Item };
        }

        $Success = $Self->{DynamicFieldValueObject}->ValueSet(
            FieldID  => $Param{DynamicFieldConfig}->{ID},
            ObjectID => $Param{ObjectID},
            Value    => \@ValueText,
            UserID   => $Param{UserID},
        );
    }
    else {

        # otherwise no value was selected, then in fact this means that any value there should be
        # deleted
        $Success = $Self->{DynamicFieldValueObject}->ValueDelete(
            FieldID  => $Param{DynamicFieldConfig}->{ID},
            ObjectID => $Param{ObjectID},
            UserID   => $Param{UserID},
        );
    }

    return $Success;
}

sub ValueLookup {
    my ( $Self, %Param ) = @_;

    return if (!defined ($Param{Key}));
    return q{} if ($Param{Key} eq q{});

    # return array or scalar depending on $Param{Key}
    my $Result;
    my @Keys;
    if ( ref $Param{Key} eq 'ARRAY' ) {
        @Keys = @{$Param{Key}};
        $Result = [];
    }
    else{
        push(@Keys, $Param{Key});
        $Result = q{};
    }

    for my $Key ( @Keys ){

        my $Value = $Self->_ValueLookup(
            DynamicFieldConfig => $Param{DynamicFieldConfig},
            Key                => $Key,
        );

        $Value = defined $Value ? $Value : $Key;

        if ( ref $Param{Key} eq 'ARRAY' ) {
            push(@{$Result}, $Value);
        }
        else{
            $Result = $Value;
        }
    }

    return $Result;
}

sub _ValueLookup {
    my ( $Self, %Param ) = @_;

    my $DynamicFieldConfig = $Param{DynamicFieldConfig};
    my $Key                = $Param{Key};

    # check if value is in cache
    if ( $DynamicFieldConfig->{Config}->{CacheTTL} ) {
        $Self->{CacheType} = 'DynamicField_RemoteDB_' . $DynamicFieldConfig->{Name};

        my $Value = $Kernel::OM->Get('Cache')->Get(
            Type => $Self->{CacheType},
            Key  => "ValueLookup::$Key",
        );

        return $Value if $Value;
    }

    my $DFRemoteDBObject = Kernel::System::DFRemoteDB->new(
        %{ $Self },
        DatabaseDSN  => $DynamicFieldConfig->{Config}->{DatabaseDSN},
        DatabaseUser => $DynamicFieldConfig->{Config}->{DatabaseUser},
        DatabasePw   => $DynamicFieldConfig->{Config}->{DatabasePw},
        Type         => $DynamicFieldConfig->{Config}->{DatabaseType},
    );

    my $QuotedValue        = $DFRemoteDBObject->Quote($Key);
    my $QueryCondition = " WHERE";
    if ( length($QuotedValue) ) {
        $QueryCondition .= $DFRemoteDBObject->QueryCondition(
            Key           => $DynamicFieldConfig->{Config}->{DatabaseFieldKey},
            Value         => $QuotedValue,
            CaseSensitive => 1,
        );
    }
    else {
        $QueryCondition = q{};
    }

    my $SQL = 'SELECT '
        . $DynamicFieldConfig->{Config}->{DatabaseFieldValue}
        . ' FROM '
        . $DynamicFieldConfig->{Config}->{DatabaseTable}
        . $QueryCondition;

    my $Success = $DFRemoteDBObject->Prepare(
        SQL   => $SQL,
        Limit => 1,
    );

    return if !$Success;

    my $Value;
    while (my @Row = $DFRemoteDBObject->FetchrowArray()) {
        $Value = $Row[0];
        last;
    }

    return if !$Value;

    # cache request
    if ( $DynamicFieldConfig->{Config}->{CacheTTL} ) {
        $Kernel::OM->Get('Cache')->Set(
            Type  => $Self->{CacheType},
            Key   => "ValueLookup::$Key",
            Value => $Value,
            TTL   => $DynamicFieldConfig->{Config}->{CacheTTL},
        );
    }
    return $Value;
}

sub ValueValidate {
    my ( $Self, %Param ) = @_;

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

        $Success = $Self->{DynamicFieldValueObject}->ValueValidate(
            Value => {
                ValueText => $Item,
            },
            UserID => $Param{UserID}
        );

        return if !$Success
    }

    return $Success;
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

sub SearchSQLOrderFieldGet {
    my ( $Self, %Param ) = @_;

    return "$Param{TableAlias}.value_text";
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
        next VALUEITEM if !$Item;

        push @ReadableValues, $Item;
    }

    # set new line separator
    my $ItemSeparator = $Param{DynamicFieldConfig}->{Config}->{ItemSeparator} || ', ';

    # Output transformations
    $Value = join( $ItemSeparator, @ReadableValues );
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

sub DisplayValueRender {
    my ( $Self, %Param ) = @_;

    # set HTMLOuput as default if not specified
    if ( !defined $Param{HTMLOutput} ) {
        $Param{HTMLOutput} = 1;
    }

    # get raw Value strings from field value
    my @Keys;
    if ( ref $Param{Value} eq 'ARRAY' ) {
        @Keys = @{ $Param{Value} };
    }
    else {
        @Keys = ( $Param{Value} );
    }

    my @Values;
    my @Titles;

    for my $Key (@Keys) {

        $Key ||= q{};

        my $EntryValue = $Self->ValueLookup(
            %Param,
            Key => $Key,
        );

        # set title as value after update and before limit
        my $EntryTitle = $EntryValue;
        if ( $Param{DynamicFieldConfig}->{Config}->{ShowKeyInTitle} ) {
            $EntryTitle .= ' (' . $Key . ')';
        }

        # HTMLOuput transformations
        if ( $Param{HTMLOutput} ) {
            $EntryValue = $Param{LayoutObject}->Ascii2Html(
                Text => $EntryValue,
                Max => $Param{ValueMaxChars} || q{},
            );

            $EntryTitle = $Param{LayoutObject}->Ascii2Html(
                Text => $EntryTitle,
                Max => $Param{TitleMaxChars} || q{},
            );

            # set field link form config
            my $HasLink = 0;
            my $OldValue;
            if (
                $Param{LayoutObject}->{UserType} eq 'User'
                && $Param{DynamicFieldConfig}->{Config}->{AgentLink}
                )
            {
                $OldValue = $EntryValue;
                $EntryValue
                    = '<a href="'
                    . $Param{DynamicFieldConfig}->{Config}->{AgentLink}
                    . '" title="'
                    . $EntryTitle
                    . '" target="_blank" class="DynamicFieldLink">'
                    . $EntryValue . '</a>';
                $HasLink = 1;
            }
            elsif (
                $Param{LayoutObject}->{UserType} eq 'Customer'
                && $Param{DynamicFieldConfig}->{Config}->{CustomerLink}
                )
            {
                $OldValue = $EntryValue;
                $EntryValue
                    = '<a href="'
                    . $Param{DynamicFieldConfig}->{Config}->{CustomerLink}
                    . '" title="'
                    . $EntryTitle
                    . '" target="_blank" class="DynamicFieldLink">'
                    . $EntryValue . '</a>';
                $HasLink = 1;
            }
            if ($HasLink) {

                # Replace <RDB_Key>
                if ( $EntryValue =~ /<RDB_Key>/smx ) {
                    my $Replace = $Param{LayoutObject}->LinkEncode($Key);
                    $EntryValue =~ s/<RDB_Key>/$Replace/gsmx;
                }

                # Replace <RDB_Value>
                if ( $EntryValue =~ /<RDB_Value>/smx ) {
                    my $Replace = $Param{LayoutObject}->LinkEncode($OldValue);
                    $EntryValue =~ s/<RDB_Value>/$Replace/gsmx;
                }

                # Replace <RDB_Title>
                if ( $EntryValue =~ /<RDB_Title>/smx ) {
                    my $Replace = $Param{LayoutObject}->LinkEncode($EntryTitle);
                    $EntryValue =~ s/<RDB_Title>/$Replace/gsmx;
                }

                # Replace <SessionID>
                if ( $EntryValue =~ /<SessionID>/smx ) {
                    my $Replace = $Param{LayoutObject}->{SessionID};
                    $EntryValue =~ s/<SessionID>/$Replace/gsmx;
                }
            }
        }
        else {
            if ( $Param{ValueMaxChars} && length($EntryValue) > $Param{ValueMaxChars} ) {
                $EntryValue = substr( $EntryValue, 0, $Param{ValueMaxChars} ) . '...';
            }
            if ( $Param{TitleMaxChars} && length($EntryTitle) > $Param{TitleMaxChars} ) {
                $EntryTitle = substr( $EntryTitle, 0, $Param{TitleMaxChars} ) . '...';
            }
        }

        push( @Values, $EntryValue );
        push( @Titles, $EntryTitle );
    }

    # set item separator
    my $ItemSeparator = $Param{DynamicFieldConfig}->{Config}->{ItemSeparator} || ', ';

    my $Value = join( $ItemSeparator, @Values );
    my $Title = join( $ItemSeparator, @Titles );

    # this field type does not support the Link Feature in normal way. Links are provided via Value in HTMLOutput
    my $Link;

    # create return structure
    my $Data = {
        Value => $Value,
        Title => $Title,
        Link  => $Link,
    };

    return $Data;
}

sub _GetPossibleValues {
    my ( $Self, %Param ) = @_;

    my $PossibleValues;

    # create cache object
    if ( $Param{DynamicFieldConfig}->{Config}->{CacheTTL} && $Param{DynamicFieldConfig}->{Config}->{CachePossibleValues} ) {

        # set cache type
        $Self->{CacheType} = 'DynamicField_RemoteDB_' . $Param{DynamicFieldConfig}->{Name};

        $PossibleValues = $Kernel::OM->Get('Cache')->Get(
            Type => $Self->{CacheType},
            Key  => "GetPossibleValues",
        );
        return $PossibleValues if $PossibleValues;
    }

    my $DFRemoteDBObject = Kernel::System::DFRemoteDB->new(
        %{ $Self },
        DatabaseDSN  => $Param{DynamicFieldConfig}->{Config}->{DatabaseDSN},
        DatabaseUser => $Param{DynamicFieldConfig}->{Config}->{DatabaseUser},
        DatabasePw   => $Param{DynamicFieldConfig}->{Config}->{DatabasePw},
        Type         => $Param{DynamicFieldConfig}->{Config}->{DatabaseType},
    );

    my %Constrictions = ();
    if ($Param{DynamicFieldConfig}->{Config}->{Constrictions}) {
        my @Constrictions = split(/[\n\r]+/smx, $Param{DynamicFieldConfig}->{Config}->{Constrictions});
        RESTRICTION:
        for my $Constriction ( @Constrictions ) {
            my @ConstrictionRule = split(/::/smx, $Constriction);
            next RESTRICTION if (
                scalar(@ConstrictionRule) != 4
                || $ConstrictionRule[0] eq q{}
                || $ConstrictionRule[1] eq q{}
                || $ConstrictionRule[2] eq q{}
            );

            if (
                $ConstrictionRule[1] eq 'Configuration'
            ) {
                $Constrictions{$ConstrictionRule[0]} = $ConstrictionRule[2];
            }
        }
    }

    my $SQL = 'SELECT '
        . $Param{DynamicFieldConfig}->{Config}->{DatabaseFieldKey}
        . ', '
        . $Param{DynamicFieldConfig}->{Config}->{DatabaseFieldValue}
        . ' FROM '
        . $Param{DynamicFieldConfig}->{Config}->{DatabaseTable};

    $DFRemoteDBObject->Prepare(
        SQL   => $SQL,
    );

    while (my @Row = $DFRemoteDBObject->FetchrowArray()) {
        my $Key   = $Row[0] || q{};
        my $Value = $Row[1] || q{};
        $PossibleValues->{$Key} = $Value;
    }

    # cache request
    if ( $Param{DynamicFieldConfig}->{Config}->{CacheTTL} && $Param{DynamicFieldConfig}->{Config}->{CachePossibleValues} ) {
        $Kernel::OM->Get('Cache')->Set(
            Type  => $Self->{CacheType},
            Key   => "GetPossibleValues",
            Value => $PossibleValues,
            TTL   => $Param{DynamicFieldConfig}->{Config}->{CacheTTL},
        );
    }

    return $PossibleValues;
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
