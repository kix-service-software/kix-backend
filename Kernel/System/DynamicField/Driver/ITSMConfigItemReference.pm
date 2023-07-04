# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::DynamicField::Driver::ITSMConfigItemReference;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::DynamicField::Driver::BaseSelect);

our @ObjectDependencies = (
    'Config',
    'DB',
    'DynamicFieldValue',
    'GeneralCatalog',
    'ITSMConfigItem',
    'Log',
    'Main',
    'Ticket::ColumnFilter',
);

=head1 NAME

Kernel::System::DynamicField::Driver::ITSMConfigItemReference

=head1 SYNOPSIS

DynamicFields ITSMConfigItemReference backend delegate

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
    $Self->{GeneralCatalogObject}    = $Kernel::OM->Get('GeneralCatalog');
    $Self->{ITSMConfigItemObject}    = $Kernel::OM->Get('ITSMConfigItem');

    # get the fields config
    $Self->{FieldTypeConfig} = $Self->{ConfigObject}->Get('DynamicFields::Driver') || {};

    # set field behaviors
    $Self->{Behaviors} = {
        'IsNotificationEventCondition' => 1,
        'IsSortable'                   => 1,
        'IsFilterable'                 => 1,
        'IsStatsCondition'             => 1,
        'IsCustomerInterfaceCapable'   => 1,
    };

    # get the Dynamic Field Backend custom extensions
    my $DynamicFieldDriverExtensions = $Self->{ConfigObject}->Get('DynamicFields::Extension::Driver::ITSMConfigItemReference');

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
    for my $Item ( @Keys ) {
        next KEYITEM if !$Item;

        # set the value as the key by default
        my $Value = $Item;

        # try to convert key to real value
        my $Number = $Self->{ITSMConfigItemObject}->ConfigItemLookup(
            ConfigItemID => $Item,
        );
        if ( $Number ) {
            my $ConfigItem = $Self->{ITSMConfigItemObject}->VersionGet(
                ConfigItemID => $Item,
                XMLDataGet   => 0,
            );

            $Value = $Param{DynamicFieldConfig}->{Config}->{DisplayPattern} || '<CI_Name>';
            while ($Value =~ m/<CI_([^>]+)>/smx) {
                my $Replace = $ConfigItem->{$1} || q{};
                $Value =~ s/<CI_$1>/$Replace/gsmx;
            }
        }
        push( @Values, $Value );
    }

    return \@Values;
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

    for my $Item (@Values) {

        # check if value is an integer (an ID)
        my $Success = $Self->{DynamicFieldValueObject}->ValueValidate(
            Value => {
                ValueInt => $Item,
            },
            UserID => $Param{UserID}
        );

        return if (!$Success);

        # check if ticket exists
        my $Number = $Self->{ITSMConfigItemObject}->ConfigItemLookup(
            ConfigItemID => $Item,
        );

        if (!$Number) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No config item with id $Item exists"
            );
            return;
        }
    }

    return 1;
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
        next if ( !$Key );

        my $ConfigItem = $Self->{ITSMConfigItemObject}->VersionGet(
            ConfigItemID => $Key,
            XMLDataGet   => 0,
        );

        my $EntryValue = $Param{DisplayPattern} || $Param{DynamicFieldConfig}->{Config}->{DisplayPattern} || '<CI_Number> - <CI_Name>';
        while ($EntryValue =~ m/<CI_([^>]+)>/smx) {
            my $Replace = $ConfigItem->{$1} || q{};
            if ($1 eq 'Number') {
                my $Hook = $Kernel::OM->Get('Config')->Get('ITSMConfigItem::Hook');
                if ($Hook) {
                    $Replace = $Hook . $Replace;
                }
            }
            $EntryValue =~ s/<CI_$1>/$Replace/gsxm;
        }

        # set title as value after update and before limit
        my $EntryTitle = $EntryValue;

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
        }
        else {
            if ( $Param{ValueMaxChars} && length($EntryValue) > $Param{ValueMaxChars} ) {
                $EntryValue = substr( $EntryValue, 0, $Param{ValueMaxChars} ) . '...';
            }
            if ( $Param{TitleMaxChars} && length($EntryTitle) > $Param{TitleMaxChars} ) {
                $EntryTitle = substr( $EntryTitle, 0, $Param{TitleMaxChars} ) . '...';
            }
        }

        push ( @Values, $EntryValue );
        push ( @Titles, $EntryTitle );
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

sub ShortDisplayValueRender {
    my ( $Self, %Param ) = @_;

    return $Self->DisplayValueRender(
        %Param,
        DisplayPattern => '<CI_Name>'
    );
}

sub DFValueObjectReplace {
    my ( $Self, %Param ) = @_;

    return if ( !$Param{Placeholder} || !IsArrayRefWithData($Param{Value}) );

    if ($Param{Placeholder} =~ m/(?:<.+)?_Object_(\d+)_(.+)>?/) {
        if (($1 || $1 == 0) && $2 && $Param{Value}->[$1]) {
            return $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
                Text        => "<KIX_ASSET_$2>",
                ObjectType  => 'ITSMConfigItem',
                ObjectID    => $Param{Value}->[$1],
                UserID      => $Param{UserID},
                Language    => $Param{Language}
            );
        }
    }

    return;
}

sub ExportConfigPrepare {
    my ( $Self, %Param ) = @_;
    my $GeneralCatalogObject = $Kernel::OM->Get('GeneralCatalog');

    if (
        $Param{Config}->{DeploymentStates}
        || $Param{Config}->{ITSMConfigItemClasses}
    ) {
        KEY:
        for my $Key ( qw(DeploymentStates ITSMConfigItemClasses) ) {
            next KEY if !$Param{Config}->{$Key};
            my @Names;

            ITEM:
            for my $ItemID ( @{$Param{Config}->{$Key}} ) {
                next ITEM if !$ItemID;

                if ( $ItemID !~ m/^\d+$/smx ) {
                    push(@Names, $ItemID);
                    next ITEM;
                }
                my $ItemDataRef = $GeneralCatalogObject->ItemGet(
                    ItemID => $ItemID
                );

                next ITEM if !$ItemDataRef;

                push(@Names, $ItemDataRef->{Name});
            }

            if ( scalar(@Names) ) {
                $Param{Config}->{$Key} = \@Names;
            } else {
                delete $Param{Config}->{$Key};
            }
        }
    }

    return $Param{Config};
}

sub ImportConfigPrepare {
    my ( $Self, %Param ) = @_;
    my $GeneralCatalogObject = $Kernel::OM->Get('GeneralCatalog');

    if (
        $Param{Config}->{DeploymentStates}
        || $Param{Config}->{ITSMConfigItemClasses}
    ) {
        KEY:
        for my $Key ( qw(DeploymentStates ITSMConfigItemClasses) ) {
            next KEY if !$Param{Config}->{$Key};
            my @IDs;

            ITEM:
            for my $ItemName ( @{$Param{Config}->{$Key}} ) {
                my $ItemDataRef = $GeneralCatalogObject->ItemGet(
                    Class => 'ITSM::ConfigItem::' . ($Key eq 'DeploymentStates' ? 'DeploymentState' : 'Class'),
                    Name  => $ItemName,
                );

                next ITEM if !$ItemDataRef;

                push(@IDs, $ItemDataRef->{ItemID});
            }

            if ( scalar(@IDs) ) {
                $Param{Config}->{$Key} = \@IDs;
            } else {
                delete $Param{Config}->{$Key};
            }
        }
    }

    return $Param{Config};
}

sub _ExportXMLSearchDataPrepare {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{XMLDefinition} || ref $Param{XMLDefinition} ne 'ARRAY';
    return if !$Param{What}          || ref $Param{What}          ne 'ARRAY';
    return if !$Param{SearchData}    || ref $Param{SearchData}    ne 'HASH';

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {

        # create key
        my $Key = $Param{Prefix} ? $Param{Prefix} . '::' . $Item->{Key} : $Item->{Key};
        my $DataKey = $Item->{Key};

        # prepare value
        my $Values = $Param{SearchData}->{$DataKey};
        if ($Values) {

            # create search key
            my $SearchKey = $Key;
            $SearchKey =~ s{ :: }{\'\}[%]\{\'}xmsg;

            # create search hash
            my $SearchHash = {
                '[1]{\'Version\'}[1]{\''
                . $SearchKey
                . '\'}[%]{\'Content\'}' => $Values,
            };
            push @{ $Param{What} }, $SearchHash;
        }
        next ITEM if !$Item->{Sub};

        # start recursion, if "Sub" was found
        $Self->_ExportXMLSearchDataPrepare(
            XMLDefinition => $Item->{Sub},
            What          => $Param{What},
            SearchData    => $Param{SearchData},
            Prefix        => $Key,
        );
    }

    return 1;
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
