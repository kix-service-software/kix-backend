# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::DynamicField::Driver::User;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::DynamicField::Driver::BaseSelect);

our @ObjectDependencies = (
    'User',
    'DynamicFieldValue',
    'Ticket::ColumnFilter',
);

=head1 NAME

Kernel::System::DynamicField::Driver::ObjectReference

=head1 SYNOPSIS

DynamicFields ObjectReference Driver delegate

=head1 PUBLIC INTERFACE

This module implements the public interface of L<Kernel::System::DynamicField::Driver>.
Please look there for a detailed reference of the functions.

=over 4

=item new()

usually, you want to create an instance of this
by using Kernel::System::DynamicField::Driver->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{UserObject}              = $Kernel::OM->Get('User');
    $Self->{DynamicFieldValueObject} = $Kernel::OM->Get('DynamicFieldValue');

    # set field behaviors
    $Self->{Behaviors} = {
        'IsNotificationEventCondition' => 1,
        'IsSortable'                   => 0,
        'IsFiltrable'                  => 0,
        'IsStatsCondition'             => 1,
        'IsCustomerInterfaceCapable'   => 1,
    };

    # get the Dynamic Field Driver custmom extensions
    my $DynamicFieldDriverExtensions = $Kernel::OM->Get('Config')->Get('DynamicFields::Extension::Driver::User');

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

        # check if extension contains more behabiors
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

    # check for valid UserLogin
    for my $Object (@Values) {

        next if !$Object;

        my %UserListCustomer =
            $Self->{UserObject}
            ->UserSearch( UserLogin => $Object, );
        if ( !%UserListCustomer ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "The value for the field User is invalid!\n"
                    . "No Customer with login "
                    . $Object
                    . " found in configured backend(s).",
            );
            return 0;
        }
    }

    # get dynamic field value object
    my $DynamicFieldValueObject = $Kernel::OM->Get('DynamicFieldValue');

    my $Success;
    if ( IsArrayRefWithData( \@Values ) ) {

        # if there is at least one value to set, this means one or more values are selected,
        #    set those values!
        my @ValueText;
        for my $Item (@Values) {
            push @ValueText, { ValueText => $Item };
        }

        $Success = $DynamicFieldValueObject->ValueSet(
            FieldID  => $Param{DynamicFieldConfig}->{ID},
            ObjectID => $Param{ObjectID},
            Value    => \@ValueText,
            UserID   => $Param{UserID},
        );
    }
    else {

        # otherwise no value was selected, then in fact this means that any value there should be
        # deleted
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

    # check value
    my @Values;
    if ( IsArrayRefWithData( $Param{Value} ) ) {
        @Values = @{ $Param{Value} };
    }
    else {
        @Values = ( $Param{Value} );
    }

    # check for valid UserLogin
    for my $Object (@Values) {
        my %UserListCustomer =
            $Self->{UserObject}
            ->UserSearch( UserLogin => $Object, );
        if ( !%UserListCustomer ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "The value for the field User is invalid!\n"
                    . "No Customer with login "
                    . $Object
                    . " found in configured backend(s).",
            );
            return 0;
        }
    }

    # get dynamic field value object
    my $DynamicFieldValueObject = $Kernel::OM->Get('DynamicFieldValue');

    my $Success;
    for my $Item (@Values) {

        $Success = $DynamicFieldValueObject->ValueValidate(
            Value => {
                ValueText => $Item,
            },
            UserID => $Param{UserID}
        );
        return if !$Success
    }
    return $Success;
}

sub DisplayValueRender {
    my ( $Self, %Param ) = @_;

    # set HTMLOuput as default if not specified
    if ( !defined $Param{HTMLOutput} ) {
        $Param{HTMLOutput} = 1;
    }

    # set Value and Title variables
    my $Value         = q{};
    my $Title         = q{};
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

    VALUEITEM:
    for my $Item (@Values) {
        next VALUEITEM if !$Item;

        my $ReadableValue = $Item;
        my $UserID = $Self->{UserObject}->UserLookup(
            UserLogin => $ReadableValue,
        );
        my %ContactData;
        if ($UserID) {
            my %ContactData = $Self->{ContactObject}->ContactGet(
                UserID => $UserID,
            );
            $ReadableValue = $ContactData{Firstname} . " "
                . $ContactData{Lastname} . " <"
                . $ContactData{Email} . ">";
        }
        # alternative display string defined ?
        if ( $Param{DynamicFieldConfig}->{Config}->{AlternativeDisplay} ) {
            $ReadableValue = $Param{DynamicFieldConfig}->{Config}->{AlternativeDisplay};
            $ReadableValue =~ s{<(.+?)>}{$ContactData{$1}}egxsm;
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

        # HTMLOuput transformations
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

    # get specific field settings
    my $FieldConfig
        = $Kernel::OM->Get('Config')->Get('DynamicFields::Driver')->{Multiselect} || {};

    # set new line separator
    my $ItemSeparator = $FieldConfig->{ItemSeparator} || ', ';

    $Value = join( $ItemSeparator, @ReadableValues );
    $Title = join( $ItemSeparator, @ReadableTitles );

    if ($ShowValueEllipsis) {
        $Value .= '...';
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
        next VALUEITEM if !$Item;

        push @ReadableValues, $Item;
    }

    # set new line separator
    my $ItemSeparator = ', ';

    # Ouput transformations
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

sub HistoricalValuesGet {
    my ( $Self, %Param ) = @_;

    # get historical values from database
    my $HistoricalValues = $Self->{DynamicFieldValueObject}->HistoricalValueGet(
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

    # to store final values
    my @Values;

    KEYITEM:
    for my $Item (@Keys) {
        next KEYITEM if !$Item;

        # set the value as the key by default
        my $Value = $Item;
        my $UserID = $Self->{UserObject}->UserLookup(
            UserLogin => $Value,
        );
        if ($UserID) {
            my %ContactData = $Self->{ContactObject}->ContactGet(
                UserID => $UserID,
            );
            $Value = $ContactData{Firstname}
                . " "
                . $ContactData{Lastname}
                . " <"
                . $ContactData{Email}
                . ">";

            # alternative display string defined ?
            if ($Param{DynamicFieldConfig}->{Config}->{AlternativeDisplay}) {
                $Value = $Param{DynamicFieldConfig}->{Config}->{AlternativeDisplay};
                $Value =~ s{<(.+?)>}{$ContactData{$1} }egxsm;
            }
            push(@Values, $Value);
        }

        return \@Values;
    }
    return;
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
