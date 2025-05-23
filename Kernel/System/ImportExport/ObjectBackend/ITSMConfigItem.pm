# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ImportExport::ObjectBackend::ITSMConfigItem;

use strict;
use warnings;

use List::Util qw(min);
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'GeneralCatalog',
    'ITSMConfigItem',
    'ImportExport',
    'Log',
);

=head1 NAME

Kernel::System::ImportExport::ObjectBackend::ITSMConfigItem - import/export backend for ITSMConfigItem

=head1 SYNOPSIS

All functions to import and export ITSM config items.

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $BackendObject = $Kernel::OM->Get('ImportExport::ObjectBackend::ITSMConfigItem');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item MappingObjectAttributesGet()

get the mapping attributes of an object as array/hash reference

    my $Attributes = $ObjectBackend->MappingObjectAttributesGet(
        TemplateID => 123,
        UserID     => 1,
    );

=cut

sub MappingObjectAttributesGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            return if $Param{Silent};
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get object data
    my $ObjectData = $Kernel::OM->Get('ImportExport')->ObjectDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
        Silent     => $Param{Silent}
    );

    return [] if !$ObjectData;
    return [] if ref $ObjectData ne 'HASH';
    return [] if !$ObjectData->{ClassID};

    # get definition
    my $XMLDefinition = $Kernel::OM->Get('ITSMConfigItem')->DefinitionGet(
        ClassID => $ObjectData->{ClassID},
        Silent  => $Param{Silent}
    );

    return [] if !$XMLDefinition;
    return [] if ref $XMLDefinition ne 'HASH';
    return [] if !$XMLDefinition->{DefinitionRef};
    return [] if ref $XMLDefinition->{DefinitionRef} ne 'ARRAY';

    my $ElementList = [
        {
            Key   => 'Number',
            Value => 'Number',
        },
        {
            Key   => 'Name',
            Value => 'Name',
        },
        {
            Key   => 'DeplState',
            Value => 'Deployment State',
        },
        {
            Key   => 'InciState',
            Value => 'Incident State',
        },
    ];

    # add xml elements
    $Self->_MappingObjectAttributesGet(
        XMLDefinition => $XMLDefinition->{DefinitionRef},
        ElementList   => $ElementList,
        CountMaxLimit => $ObjectData->{CountMax} || 10,
        Silent        => $Param{Silent}
    );

    my $Attributes = [
        {
            Key   => 'Key',
            Name  => 'Key',
            Input => {
                Type         => 'Selection',
                Data         => $ElementList,
                Required     => 1,
                Translation  => 0,
                PossibleNone => 1,
            },
        },
        {
            Key   => 'Identifier',
            Name  => 'Identifier',
            Input => {
                Type => 'Checkbox',
            },
        },
    ];

    return $Attributes;
}

=item SearchAttributesGet()

get the search object attributes of an object as array/hash reference

    my $AttributeList = $ObjectBackend->SearchAttributesGet(
        TemplateID => 123,
        UserID     => 1,
    );

=cut

sub SearchAttributesGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get object data
    my $ObjectData = $Kernel::OM->Get('ImportExport')->ObjectDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    return [] if !$ObjectData;
    return [] if ref $ObjectData ne 'HASH';
    return [] if !$ObjectData->{ClassID};

    # get definition
    my $XMLDefinition = $Kernel::OM->Get('ITSMConfigItem')->DefinitionGet(
        ClassID => $ObjectData->{ClassID},
    );

    return [] if !$XMLDefinition;
    return [] if ref $XMLDefinition ne 'HASH';
    return [] if !$XMLDefinition->{DefinitionRef};
    return [] if ref $XMLDefinition->{DefinitionRef} ne 'ARRAY';

    # get deployment state list
    my $DeplStateList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class => 'ITSM::ConfigItem::DeploymentState',
    ) || {};

    # get incident state list
    my $InciStateList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class => 'ITSM::Core::IncidentState',
    ) || {};

    my $AttributeList = [
        {
            Key   => 'Number',
            Name  => 'Number',
            Input => {
                Type      => 'Text',
                Size      => 80,
                MaxLength => 255,
            },
        },
        {
            Key   => 'Name',
            Name  => 'Name',
            Input => {
                Type      => 'Text',
                Size      => 80,
                MaxLength => 255,
            },
        },
        {
            Key   => 'DeplStateIDs',
            Name  => 'Deployment State',
            Input => {
                Type        => 'Selection',
                Data        => $DeplStateList,
                Translation => 1,
                Size        => 5,
                Multiple    => 1,
            },
        },
        {
            Key   => 'InciStateIDs',
            Name  => 'Incident State',
            Input => {
                Type        => 'Selection',
                Data        => $InciStateList,
                Translation => 1,
                Size        => 5,
                Multiple    => 1,
            },
        },
    ];

    # add xml attributes
    $Self->_SearchAttributesGet(
        XMLDefinition => $XMLDefinition->{DefinitionRef},
        AttributeList => $AttributeList,
    );

    return $AttributeList;
}

=item ExportDataGet()

get export data as 2D-array-hash reference

    my $ExportData = $ObjectBackend->ExportDataGet(
        TemplateID => 123,
        UserID     => 1,
    );

=cut

sub ExportDataGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(TemplateID UserID UsageContext)) {
        if ( !$Param{$Argument} ) {
            return if $Param{Silent};
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get object data
    my $ObjectData = $Kernel::OM->Get('ImportExport')->ObjectDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
        Silent     => $Param{Silent}
    );

    # check object data
    if (
        !$ObjectData
        || ref $ObjectData ne 'HASH'
        || !$ObjectData->{ClassID}
    ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No valid object data found for the template id $Param{TemplateID}",
        );
        return;
    }

    # get class list
    my $ClassList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class  => 'ITSM::ConfigItem::Class',
        Silent => $Param{Silent}
    );

    return if !$ClassList || ref $ClassList ne 'HASH';

    # check the class id
    if (
        !$ObjectData->{ClassID}
        || !$ClassList->{ $ObjectData->{ClassID} }
    ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No valid class id found for the template id $Param{TemplateID}",
        );
        return;
    }

    # get the mapping list
    my $MappingList = $Kernel::OM->Get('ImportExport')->MappingList(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
        Silent     => $Param{Silent}
    );

    # check the mapping list
    if (
        !$MappingList
        || ref $MappingList ne 'ARRAY'
        || !@{$MappingList}
    ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No valid mapping list found for the template id $Param{TemplateID}",
        );
        return;
    }

    # create the mapping object list
    my @MappingObjectList;
    for my $MappingID ( @{$MappingList} ) {

        # get mapping object data
        my $MappingObjectData = $Kernel::OM->Get('ImportExport')->MappingObjectDataGet(
            MappingID => $MappingID,
            UserID    => $Param{UserID},
            Silent    => $Param{Silent}
        );

        # check mapping object data
        if (
            !$MappingObjectData
            || ref $MappingObjectData ne 'HASH'
        ) {
            return if $Param{Silent};

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No valid mapping list found for the template id $Param{TemplateID}",
            );
            return;
        }

        push @MappingObjectList, $MappingObjectData;
    }

    # get search data
    my $SearchData = $Kernel::OM->Get('ImportExport')->SearchDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
        Silent     => $Param{Silent}
    );

    return if !$SearchData || ref $SearchData ne 'HASH';

    # get deployment state list
    my $DeplStateList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class => 'ITSM::ConfigItem::DeploymentState',
    );

    # check deployment state list
    if (
        !$DeplStateList
        || ref $DeplStateList ne 'HASH'
    ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Can't get the general catalog list ITSM::ConfigItem::DeploymentState!",
        );
        return;
    }

    # get incident state list
    my $InciStateList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class  => 'ITSM::Core::IncidentState',
        Silent => $Param{Silent}
    );

    # check incident state list
    if (
        !$InciStateList
        || ref $InciStateList ne 'HASH'
    ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Can't get the general catalog list ITSM::Core::IncidentState!",
        );
        return;
    }

    # get current definition of this class
    my $DefinitionData = $Kernel::OM->Get('ITSMConfigItem')->DefinitionGet(
        ClassID => $ObjectData->{ClassID},
        UserID  => $Param{UserID},
        Silent  => $Param{Silent}
    );

    my @SearchParams;

    # add number to the search params
    if ( $SearchData->{Number} ) {
        my $Number = delete $SearchData->{Number};
        push(
            @SearchParams,
            {
                Field    => 'Number',
                Operator => 'IN',
                Type     => 'STRING',
                Value    => IsArrayRef($Number) ? $Number : [$Number]
            }
        );
    }

    # add name to the search params
    if ( $SearchData->{Name} ) {
        my $Name = delete $SearchData->{Name};
        push(
            @SearchParams,
            {
                Field    => 'Name',
                Operator => 'EQ',
                Type     => 'STRING',
                Value    => $Name
            }
        );
    }

    # add deployment state to the search params
    if ( $SearchData->{DeplStateIDs} ) {
        my @DeplStateIDs = split(/#####/sm , $SearchData->{DeplStateIDs});
        delete $SearchData->{DeplStateIDs};
        push(
            @SearchParams,
            {
                Field    => 'DeplStateIDs',
                Operator => 'IN',
                Type     => 'NUMERIC',
                Value    => \@DeplStateIDs
            }
        );
    }

    # add incident state to the search params
    if ( $SearchData->{InciStateIDs} ) {
        my @InciStateIDs = split(/#####/sm , $SearchData->{InciStateIDs});
        delete $SearchData->{InciStateIDs};
        push(
            @SearchParams,
            {
                Field    => 'InciStateIDs',
                Operator => 'IN',
                Type     => 'NUMERIC',
                Value    => \@InciStateIDs
            }
        );
    }

    # add all XML data to the search params
    $Self->_ExportXMLSearchDataPrepare(
        XMLDefinition => $DefinitionData->{DefinitionRef},
        What          => \@SearchParams,
        SearchData    => $SearchData
    );

    push(
        @SearchParams,
        {
            Field    => 'ClassID',
            Operator => 'IN',
            Type     => 'NUMERIC',
            Value    => [ $ObjectData->{ClassID} ]
        }
    );

    # search the config items
    my @ConfigItemList = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'ConfigItem',
        Result     => 'ARRAY',
        Search     => {
            AND => \@SearchParams
        },
        UserID     => $Param{UserID},
        Silent     => $Param{Silent}
    );

    my @ExportData;
    CONFIGITEMID:
    for my $ConfigItemID ( @ConfigItemList ) {

        # get last version
        my $VersionData = $Kernel::OM->Get('ITSMConfigItem')->VersionGet(
            ConfigItemID => $ConfigItemID,
        );

        next CONFIGITEMID if !$VersionData;
        next CONFIGITEMID if ref $VersionData ne 'HASH';

        # translate xmldata to a 2d hash
        my %XMLData2D;
        $Self->_ExportXMLDataPrepare(
            ClassID       => $ObjectData->{ClassID},
            ConfigItemID  => $ConfigItemID,
            UserID        => $Param{UserID},
            UsageContext  => $Param{UsageContext},
            XMLDefinition => $DefinitionData->{DefinitionRef},
            XMLData       => $VersionData->{XMLData}->[1]->{Version}->[1],
            XMLData2D     => \%XMLData2D,
        );

        # add data to the export data array
        my @Item;
        MAPPINGOBJECT:
        for my $MappingObject (@MappingObjectList) {

            # extract key
            my $Key = $MappingObject->{Key};

            # handle empty key
            if ( !$Key ) {
                push @Item, q{};
                next MAPPINGOBJECT;
            }

            # handle config item number
            if ( $Key eq 'Number' ) {
                push @Item, $VersionData->{Number};
                next MAPPINGOBJECT;
            }

            # handle current config item name
            if ( $Key eq 'Name' ) {
                push @Item, $VersionData->{Name};
                next MAPPINGOBJECT;
            }

            # handle deployment state
            if ( $Key eq 'DeplState' ) {
                $VersionData->{DeplStateID} ||= 'DUMMY';
                push @Item, $DeplStateList->{ $VersionData->{DeplStateID} };
                next MAPPINGOBJECT;
            }

            # handle incident state
            if ( $Key eq 'InciState' ) {
                $VersionData->{InciStateID} ||= 'DUMMY';
                push @Item, $InciStateList->{ $VersionData->{InciStateID} };
                next MAPPINGOBJECT;
            }

            # handle all XML data elements
            push @Item, $XMLData2D{$Key};
        }

        push @ExportData, \@Item;
    }

    return \@ExportData;
}

=item ImportDataSave()

imports a single entity of the import data. The C<TemplateID> points to the definition
of the current import. C<ImportDataRow> holds the data. C<Counter> is only used in
error messages, for indicating which item was not imported successfully.

The current version of the config item will never be deleted. When there are no
changes in the data, the import will be skipped. When there is new or changed data,
then a new config item or a new version is created.

In the case of changed data, the new version of the config item will contain the
attributes of the C<ImportDataRow> plus the old attributes that are
not part of the import definition.
Thus ImportDataSave() guarantees to not overwrite undeclared attributes.

The behavior when imported attributes are empty depends on the setting in the object data.
When C<EmptyFieldsLeaveTheOldValues> is not set, then empty values will wipe out
the old data. This is the default behavior. When C<EmptyFieldsLeaveTheOldValues> is set,
then empty values will leave the old values.

The decision what constitute an empty value is a bit hairy.
Here are the rules.
Fields that are not even mentioned in the Import definition are empty. These are the 'not defined' fields.
Empty strings and undefined values constitute empty fields.
Fields with with only one or more whitespace characters are not empty.
Fields with the digit '0' are not empty.

    my ( $ConfigItemID, $RetCode ) = $ObjectBackend->ImportDataSave(
        TemplateID    => 123,
        ImportDataRow => $ArrayRef,
        Counter       => 367,
        UserID        => 1,
        UsageContext  => 'Agent',
    );

An empty C<ConfigItemID> indicates failure. Otherwise it indicates the
location of the imported data.
C<RetCode> is either 'Created', 'Updated' or 'Skipped'. 'Created' means that a new
config item has been created. 'Updated' means that a new version has been added to
an existing config item. 'Skipped' means that no new version has been created,
as the new data is identical to the latest version of an existing config item.

No codes have yet been defined for the failure case.

=cut

sub ImportDataSave {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(TemplateID ImportDataRow Counter UserID UsageContext)) {
        if ( !$Param{$Argument} ) {
            return if $Param{Silent};
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # check import data row
    if ( ref $Param{ImportDataRow} ne 'ARRAY' ) {
        return if $Param{Silent};
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message =>
                "Can't import entity $Param{Counter}: "
                . "ImportDataRow must be an array reference",
        );
        return;
    }

    # get object data
    my $ObjectData = $Kernel::OM->Get('ImportExport')->ObjectDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
        Silent     => $Param{Silent}
    );

    # check object data
    if ( !$ObjectData || ref $ObjectData ne 'HASH' ) {
        return if $Param{Silent};
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message =>
                "Can't import entity $Param{Counter}: "
                . "No object data found for the template id '$Param{TemplateID}'",
        );
        return;
    }

    # just for convenience
    my $EmptyFieldsLeaveTheOldValues = $ObjectData->{EmptyFieldsLeaveTheOldValues};

    # get class list
    my $ClassList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class  => 'ITSM::ConfigItem::Class',
        Silent => $Param{Silent}
    );

    # check class list
    if ( !$ClassList || ref $ClassList ne 'HASH' ) {
        return if $Param{Silent};
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message =>
                "Can't import entity $Param{Counter}: "
                . "Can't get the general catalog list ITSM::ConfigItem::Class",
        );
        return;
    }

    # check the class id
    if (
        !$ObjectData->{ClassID}
        || !$ClassList->{ $ObjectData->{ClassID} }
    ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message =>
                "Can't import entity $Param{Counter}: "
                . "No class found for the template id '$Param{TemplateID}'",
        );
        return;
    }

    # get the mapping list
    my $MappingList = $Kernel::OM->Get('ImportExport')->MappingList(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
        Silent     => $Param{Silent}
    );

    # check the mapping list
    if (
        !$MappingList
        || ref $MappingList ne 'ARRAY'
        || !@{$MappingList}
    ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message =>
                "Can't import entity $Param{Counter}: "
                . "No valid mapping list found for the template id '$Param{TemplateID}'",
        );
        return;
    }

    # create the mapping object list
    my @MappingObjectList;
    for my $MappingID ( @{$MappingList} ) {

        # get mapping object data
        my $MappingObjectData = $Kernel::OM->Get('ImportExport')->MappingObjectDataGet(
            MappingID => $MappingID,
            UserID    => $Param{UserID},
            Silent    => $Param{Silent}
        );

        # check mapping object data
        if (
            !$MappingObjectData
            || ref $MappingObjectData ne 'HASH'
        ) {
            return if $Param{Silent};

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message =>
                    "Can't import entity $Param{Counter}: "
                    . "No mapping object data found for the mapping id '$MappingID'",
            );
            return;
        }

        push @MappingObjectList, $MappingObjectData;
    }

    # check and remember the Identifiers
    # the Identifiers identify the config item that should be updated
    my %Identifier;
    my $RowIndex = 0;
    MAPPINGOBJECTDATA:
    for my $MappingObjectData (@MappingObjectList) {

        next MAPPINGOBJECTDATA if !$MappingObjectData->{Identifier};

        # check if identifier already exists
        if ( $Identifier{ $MappingObjectData->{Key} } ) {
            return if $Param{Silent};

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message =>
                    "Can't import entity $Param{Counter}: "
                    . "'$MappingObjectData->{Key}' has been used multiple times as an identifier",
            );
            return;
        }

        # set identifier value
        $Identifier{ $MappingObjectData->{Key} } = $Param{ImportDataRow}->[$RowIndex];

        next MAPPINGOBJECTDATA if $MappingObjectData->{Key} && $Param{ImportDataRow}->[$RowIndex];

        return if $Param{Silent};
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message =>
                "Can't import entity $Param{Counter}: "
                . "Identifier field is empty",
        );

        return;
    }
    continue {
        $RowIndex++;
    }

    # get deployment state list
    my $DeplStateList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class => 'ITSM::ConfigItem::DeploymentState',
    );

    # check deployment state list
    if (
        !$DeplStateList
        || ref $DeplStateList ne 'HASH'
    ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message =>
                "Can't import entity $Param{Counter}: "
                . "Can't get the general catalog list ITSM::ConfigItem::DeploymentState!",
        );
        return;
    }

    # reverse the deployment state list
    my %DeplStateListReverse = reverse %{$DeplStateList};

    # get incident state list
    my $InciStateList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class  => 'ITSM::Core::IncidentState',
        Silent => $Param{Silent}
    );

    # check incident state list
    if (
        !$InciStateList
        || ref $InciStateList ne 'HASH'
    ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message =>
                "Can't import entity $Param{Counter}: "
                . "Can't get the general catalog list ITSM::Core::IncidentState",
        );
        return;
    }

    # reverse the incident state list
    my %InciStateListReverse = reverse %{$InciStateList};

    # get current definition of this class
    my $DefinitionData = $Kernel::OM->Get('ITSMConfigItem')->DefinitionGet(
        ClassID => $ObjectData->{ClassID},
        UserID  => $Param{UserID},
        Silent  => $Param{Silent}
    );

    # check definition data
    if (
        !$DefinitionData
        || ref $DefinitionData ne 'HASH'
    ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message =>
                "Can't import entity $Param{Counter}: "
                . "Can't get the definition of class id $ObjectData->{ClassID}",
        );
        return;
    }

    # try to get config item ids, when there are identifiers
    my $ConfigItemID;
    if (%Identifier) {

        my @SearchParams;

        # add number to the search params
        if ( $Identifier{Number} ) {
            my $Number = delete $Identifier{Number};
            push(
                @SearchParams,
                {
                    Field    => 'Number',
                    Operator => 'IN',
                    Type     => 'STRING',
                    Value    => IsArrayRef($Number) ? $Number : [$Number]
                }
            );
        }

        # add name to the search params
        if ( $Identifier{Name} ) {
            my $Name = delete $Identifier{Name};
            push(
                @SearchParams,
                {
                    Field    => 'Name',
                    Operator => 'EQ',
                    Type     => 'STRING',
                    Value    => $Name
                }
            );
        }

        # add deployment state to the search params
        if ( $Identifier{DeplState} ) {
            # extract deployment state id
            my $DeplStateID = $DeplStateListReverse{ $Identifier{DeplState} } || q{};

            if ( !$DeplStateID ) {
                return if $Param{Silent};

                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message =>
                        "Can't import entity $Param{Counter}: "
                        . "The deployment state '$Identifier{DeplState}' is invalid",
                );
                return;
            }
            push(
                @SearchParams,
                {
                    Field    => 'DeplStateIDs',
                    Operator => 'IN',
                    Type     => 'NUMERIC',
                    Value    => [$DeplStateID]
                }
            );
            delete $Identifier{DeplState};
        }

        # add incident state to the search params
        if ( $Identifier{InciState} ) {

            # extract incident state id
            my $InciStateID = $InciStateListReverse{ $Identifier{InciState} } || q{};

            if ( !$InciStateID ) {
                return if $Param{Silent};

                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message =>
                        "Can't import entity $Param{Counter}: "
                        . "The incident state '$Identifier{InciState}' is invalid",
                );
                return;
            }
            push(
                @SearchParams,
                {
                    Field    => 'InciStateIDs',
                    Operator => 'IN',
                    Type     => 'NUMERIC',
                    Value    => [$InciStateID]
                }
            );
            delete $Identifier{InciState};
        }

        # add all XML data to the search params
        $Self->_ImportXMLSearchDataPrepare(
            XMLDefinition => $DefinitionData->{DefinitionRef},
            What          => \@SearchParams,
            Identifier    => \%Identifier
        );

        push (
            @SearchParams,
            {
                Field    => 'ClassID',
                Operator => 'IN',
                Type     => 'NUMERIC',
                Value    => [ $ObjectData->{ClassID} ]
            }
        );

        # search existing config item with the same identifiers
        my @ConfigItemList = $Kernel::OM->Get('ObjectSearch')->Search(
            ObjectType => 'ConfigItem',
            Result     => 'ARRAY',
            Search     => {
                AND => \@SearchParams
            },
            UsingWildcards => 0,
            UserID         => $Param{UserID},
            UsageContext   => $Param{UsageContext},
            Silent         => $Param{Silent}
        );

        if ( scalar(@ConfigItemList) > 1 ) {
            return if $Param{Silent};

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message =>
                    "Can't import entity $Param{Counter}: "
                    . "Identifier fields NOT unique!",
            );
            return;
        }

        $ConfigItemID = $ConfigItemList[0];
    }

    # get version data of the config item
    my $VersionData = {};
    if ($ConfigItemID) {

        # get latest version
        $VersionData = $Kernel::OM->Get('ITSMConfigItem')->VersionGet(
            ConfigItemID => $ConfigItemID,
            Silent       => $Param{Silent}
        );

        # remove empty xml data
        if (
            !$VersionData->{XMLData}
            || ref $VersionData->{XMLData} ne 'ARRAY'
            || !@{ $VersionData->{XMLData} }
        ) {
            delete $VersionData->{XMLData};
        }
    }

    my $DefaultInciStateID = $ObjectData->{DefaultIncidentState}   || q{};
    my $DefaultDeplStateID = $ObjectData->{DefaultDeploymentState} || q{};
    my $DefaultName        = $ObjectData->{DefaultName}            || q{};

    # set up fields in VersionData and in the XML attributes
    my %XMLData2D;
    $RowIndex = 0;
    for my $MappingObjectData (@MappingObjectList) {

        # just for convenience
        my $Key   = $MappingObjectData->{Key};
        my $Value = $Param{ImportDataRow}->[ $RowIndex++ ];

        # Import does not override the config item number
        next if $Key eq 'Number';
        if ( $Key eq 'Name' ) {
            if ( !$Value && ( !$DefaultName || $EmptyFieldsLeaveTheOldValues ) ) {

                # do nothing, keep the old value
            }
            elsif ( !$Value && $DefaultName ) {
                $VersionData->{Name} = $DefaultName;
            }
            else {
                if ( !$Value ) {
                    return if $Param{Silent};
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message =>
                            "Can't import entity $Param{Counter}: "
                            . "The name '$Value' is invalid!",
                    );
                    return;
                }

                $VersionData->{$Key} = $Value;
            }
        }
        elsif ( $Key eq 'DeplState' ) {

            if ( !$Value && ( !$DefaultDeplStateID || $EmptyFieldsLeaveTheOldValues ) ) {

                # do nothing, keep the old value
            }
            elsif ( !$Value && $DefaultDeplStateID ) {
                $VersionData->{DeplStateID} = $DefaultDeplStateID;
            }
            else {

                # extract deployment state id
                my $DeplStateID = $DeplStateListReverse{$Value} || q{};
                if ( !$DeplStateID ) {
                    return if $Param{Silent};
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message =>
                            "Can't import entity $Param{Counter}: "
                            . "The deployment state '$Value' is invalid!",
                    );
                    return;
                }

                $VersionData->{DeplStateID} = $DeplStateID;
            }
        }
        elsif ( $Key eq 'InciState' ) {

            if ( !$Value && ( !$DefaultInciStateID || $EmptyFieldsLeaveTheOldValues ) ) {

                # do nothing, keep the old value
            }
            elsif ( !$Value && $DefaultInciStateID ) {
                $VersionData->{InciStateID} = $DefaultInciStateID;
            }
            else {

                # extract the deployment state id
                my $InciStateID = $InciStateListReverse{$Value} || q{};
                if ( !$InciStateID ) {
                    return if $Param{Silent};
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message =>
                            "Can't import entity $Param{Counter}: "
                            . "The incident state '$Value' is invalid!",
                    );
                    return;
                }

                $VersionData->{InciStateID} = $InciStateID;
            }
        }
        else {

            # handle xml data
            $XMLData2D{$Key} = $Value;
        }
    }

    # set up empty container, in case there is no previous data
    $VersionData->{XMLData}->[1]->{Version}->[1] ||= {};

    # Edit XMLDataPrev, so that the values in XMLData2D take precedence.
    my $MergeOk = $Self->_ImportXMLDataMerge(
        ClassID                      => $ObjectData->{ClassID},
        XMLDefinition                => $DefinitionData->{DefinitionRef},
        XMLDataPrev                  => $VersionData->{XMLData}->[1]->{Version}->[1],
        XMLData2D                    => \%XMLData2D,
        EmptyFieldsLeaveTheOldValues => $EmptyFieldsLeaveTheOldValues,
        UserID                       => $Param{UserID},
        UsageContext                 => $Param{UsageContext},
        Silent                       => $Param{Silent}
    );


    # bail out, when the was a problem in _ImportXMLDataMerge()
    if ( !$MergeOk ) {
        return if $Param{Silent};
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message =>
                "Can't import entity $Param{Counter}: "
                . "Could not prepare the input!",
        );
        return;
    }

    my $RetCode = $ConfigItemID ? 'Changed' : 'Created';

    # check if the feature to check for a unique name is enabled
    if (
        IsStringWithData( $VersionData->{Name} )
        && $Kernel::OM->Get('Config')->Get('UniqueCIName::EnableUniquenessCheck')
    ) {

        if ( $Kernel::OM->Get('Config')->{Debug} > 0 ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message  => "Checking for duplicate names (ClassID: $ObjectData->{ClassID}, "
                    . "Name: $VersionData->{Name}, ConfigItemID: " . $ConfigItemID || 'NEW' . ')',
            );
        }

        my $NameDuplicates = $Kernel::OM->Get('ITSMConfigItem')->UniqueNameCheck(
            ConfigItemID => $ConfigItemID || 'NEW',
            ClassID      => $ObjectData->{ClassID},
            Name         => $VersionData->{Name},
            Silent       => $Param{Silent}
        );

        # stop processing if the name is not unique
        if ( IsArrayRefWithData($NameDuplicates) ) {

            # build a string of all duplicate IDs
            my $NameDuplicatesString = join ', ', @{$NameDuplicates};

            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message =>
                        "The name $VersionData->{Name} is already in use by the ConfigItemID(s): "
                        . $NameDuplicatesString,
                );
            }

            # set the return code to also include the duplicate name
            $RetCode = "DuplicateName '$VersionData->{Name}'";

            # return undef for the config item id so it will be counted as 'Failed'
            return (undef, $RetCode);
        }
    }

    my $LatestVersionID = 0;
    if ($ConfigItemID) {

        # the specified config item already exists
        # get id of the latest version, for checking later whether a version was created
        my $VersionList = $Kernel::OM->Get('ITSMConfigItem')->VersionList(
            ConfigItemID => $ConfigItemID,
            Silent       => $Param{Silent}
        ) || [];
        if ( scalar @{$VersionList} ) {
            $LatestVersionID = $VersionList->[-1];
        }
    }
    else {

        # no config item was found, so add new config item
        $ConfigItemID = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
            ClassID => $ObjectData->{ClassID},
            UserID  => $Param{UserID},
            Silent  => $Param{Silent}
        );

        if ( !$VersionData->{InciStateID} && $DefaultInciStateID ) {
            $VersionData->{InciStateID} = $DefaultInciStateID;
        }
        if ( !$VersionData->{DeplStateID} && $DefaultDeplStateID ) {
            $VersionData->{DeplStateID} = $DefaultDeplStateID;
        }
        if ( !$VersionData->{Name} && $DefaultName ) {
            $VersionData->{Name} = $DefaultName;
        }

        # check the new config item id
        if ( !$ConfigItemID ) {
            return if $Param{Silent};

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message =>
                    "Can't import entity $Param{Counter}: "
                    . "Error when adding the new config item.",
            );
            return;
        }
    }

    # add new version
    my $VersionID = $Kernel::OM->Get('ITSMConfigItem')->VersionAdd(
        ConfigItemID => $ConfigItemID,
        Name         => $VersionData->{Name},
        DefinitionID => $DefinitionData->{DefinitionID},
        DeplStateID  => $VersionData->{DeplStateID},
        InciStateID  => $VersionData->{InciStateID},
        XMLData      => $VersionData->{XMLData},
        UserID       => $Param{UserID},
        Silent       => $Param{Silent}
    );

    # the import was successful, when we get a version id
    if ( $VersionID && ref($VersionID) ne 'HASH' ) {

        # When VersionAdd() returns the previous latest version ID, we know that
        # no new version has been added.
        # The import of this config item has been skipped.
        if ( $LatestVersionID && $VersionID == $LatestVersionID ) {
            $RetCode = 'Skipped';
        }

        return $ConfigItemID, $RetCode;
    }

    if ( $RetCode eq 'Created' ) {

        # delete the new config item
        $Kernel::OM->Get('ITSMConfigItem')->ConfigItemDelete(
            ConfigItemID => $ConfigItemID,
            UserID       => $Param{UserID},
            Silent       => $Param{Silent}
        );
    }

    my $ErrMsgFromEvent = q{};
    if ( ref($VersionID) eq 'HASH' && $VersionID->{Error} && $VersionID->{Message} ) {
        $ErrMsgFromEvent = $VersionID->{Message};
    }

    return if $Param{Silent};

    $Kernel::OM->Get('Log')->Log(
        Priority => 'error',
        Message  => "Can't import entity $Param{Counter}: "
            . "Error when adding the new config item version. $ErrMsgFromEvent",
    );

    return;
}

=begin Internal:

=item _MappingObjectAttributesGet()

recursion function for MappingObjectAttributesGet().
Definitions for object attributes are passed in C<XMLDefinition>.
The new object attributes are appended to C<ElementList>.
C<CountMaxLimit> limits the max length of importable arrays.

    $ObjectBackend->_MappingObjectAttributesGet(
        XMLDefinition => $ArrayRef,
        ElementList   => $ArrayRef,
        CountMaxLimit => 10,
    );

=cut

sub _MappingObjectAttributesGet {
    my ( $Self, %Param ) = @_;

    return if !$Param{CountMaxLimit};
    return if !$Param{XMLDefinition};
    return if !$Param{ElementList};
    return if ref $Param{XMLDefinition} ne 'ARRAY';
    return if ref $Param{ElementList} ne 'ARRAY';

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {

        # limit the length of importable arrays, even if more elements can be set via the GUI
        my $CountMax = min( $Item->{CountMax}, $Param{CountMaxLimit} );

        COUNT:
        for my $Count ( 1 .. $CountMax ) {

            # create key string
            my $Key = $Item->{Key} . q{::} . $Count;

            # add prefix to key
            if ( $Param{KeyPrefix} ) {
                $Key = $Param{KeyPrefix} . q{::} . $Key;
            }

            # create value string
            my $Value = $Item->{Key};

            # add count if required
            if ( $CountMax > 1 || $Item->{Sub} ) {
                $Value .= q{::} . $Count;
            }

            # add prefix to key
            if ( $Param{ValuePrefix} ) {
                $Value = $Param{ValuePrefix} . q{::} . $Value;
            }

            # add row
            my %Row = (
                Key   => $Key,
                Value => $Value,
            );
            push @{ $Param{ElementList} }, \%Row;

            next COUNT if !$Item->{Sub};

            # start recursion
            $Self->_MappingObjectAttributesGet(
                XMLDefinition => $Item->{Sub},
                ElementList   => $Param{ElementList},
                KeyPrefix     => $Key,
                ValuePrefix   => $Value,
                CountMaxLimit => $Param{CountMaxLimit} || '10',
            );
        }
    }

    return 1;
}

=item _SearchAttributesGet()

recursion function for MappingObjectAttributesGet()

    $ObjectBackend->_SearchAttributesGet(
        XMLDefinition => $ArrayRef,
        AttributeList => $ArrayRef,
    );

=cut

sub _SearchAttributesGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{XMLDefinition};
    return if !$Param{AttributeList};
    return if ref $Param{XMLDefinition} ne 'ARRAY';
    return if ref $Param{AttributeList} ne 'ARRAY';

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {

        # set prefix
        my $Key  = $Item->{Key};
        my $Name = $Item->{Name};

        if ( $Param{KeyPrefix} ) {
            $Key = $Param{KeyPrefix} . q{::} . $Key;
        }

        if ( $Param{NamePrefix} ) {
            $Name = $Param{NamePrefix} . q{::} . $Name;
        }

        # add attribute, if marked as searchable
        if ( $Item->{Searchable} ) {

            if ( $Item->{Input}->{Type} eq 'Text' || $Item->{Input}->{Type} eq 'TextArea' ) {

                my %Row = (
                    Key   => $Key,
                    Name  => $Name,
                    Input => {
                        Type        => 'Text',
                        Translation => $Item->{Input}->{Input}->{Translation},
                        Size        => $Item->{Input}->{Input}->{Size} || 60,
                        MaxLength   => $Item->{Input}->{Input}->{MaxLength},
                    },
                );

                push @{ $Param{AttributeList} }, \%Row;
            }
            elsif ( $Item->{Input}->{Type} eq 'GeneralCatalog' ) {

                # get general catalog list
                my $GeneralCatalogList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
                    Class => $Item->{Input}->{Class},
                ) || {};

                my %Row = (
                    Key   => $Key,
                    Name  => $Name,
                    Input => {
                        Type        => 'Selection',
                        Data        => $GeneralCatalogList,
                        Translation => $Item->{Input}->{Input}->{Translation},
                        Size        => 5,
                        Multiple    => 1,
                    },
                );

                push @{ $Param{AttributeList} }, \%Row;
            }
        }

        next ITEM if !$Item->{Sub};

        # start recursion, if "Sub" was found
        $Self->_SearchAttributesGet(
            XMLDefinition => $Item->{Sub},
            AttributeList => $Param{AttributeList},
            KeyPrefix     => $Key,
            NamePrefix    => $Name,
        );
    }

    return 1;
}

=item _ExportXMLSearchDataPrepare()

recursion function to prepare the export XML search params

    $ObjectBackend->_ExportXMLSearchDataPrepare(
        XMLDefinition => $ArrayRef,
        What          => $ArrayRef,
        SearchData    => $HashRef,
    );

=cut

sub _ExportXMLSearchDataPrepare {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{XMLDefinition};
    return if !$Param{What};
    return if !$Param{SearchData};
    return if ref $Param{XMLDefinition} ne 'ARRAY';
    return if ref $Param{What} ne 'ARRAY';
    return if ref $Param{SearchData} ne 'HASH';

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {

        # create key
        my $Key = $Param{Prefix} ? $Param{Prefix} . q{::} . $Item->{Key} : $Item->{Key};

        # prepare value
        my $Values = $Kernel::OM->Get('ITSMConfigItem')->XMLExportSearchValuePrepare(
            Item  => $Item,
            Value => $Param{SearchData}->{$Key},
        );

        if ($Values) {

            # create search key
            my $SearchKey = 'CurrentVersion.Data.' . $Key;
            $SearchKey =~ s/::/./gsm;

            # create search hash
            my $SearchHash = {
                Field    => $SearchKey,
                Operator => 'EQ',
                Type     => 'STRING',
                Value    => $Values
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

=item _ExportXMLDataPrepare()

recursion function to prepare the export XML data

    $ObjectBackend->_ExportXMLDataPrepare(
        XMLDefinition => $ArrayRef,
        XMLData       => $HashRef,
        XMLData2D     => $HashRef,
    );

=cut

sub _ExportXMLDataPrepare {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{XMLDefinition};
    return if !$Param{XMLData};
    return if !$Param{XMLData2D};
    return if ref $Param{XMLDefinition} ne 'ARRAY';
    return if ref $Param{XMLData} ne 'HASH';
    return if ref $Param{XMLData2D} ne 'HASH';

    if ( $Param{Prefix} ) {
        $Param{Prefix} .= q{::};
    }
    $Param{Prefix} ||= q{};

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {
        COUNTER:
        for my $Counter ( 1 .. $Item->{CountMax} ) {

            # create key
            my $Key = $Param{Prefix} . $Item->{Key} . q{::} . $Counter;

            # prepare value
            if (defined $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content}) {
                $Param{XMLData2D}->{$Key} = $Kernel::OM->Get('ITSMConfigItem')->XMLExportValuePrepare(
                    ClassID       => $Param{ClassID},
                    ConfigItemID  => $Param{ConfigItemID},
                    UserID        => $Param{UserID},
                    UsageContext  => $Param{UsageContext},
                    Item          => $Item,
                    Value         => $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content},
                );
            }

            next COUNTER if !$Item->{Sub};

            # start recursion, if "Sub" was found
            $Self->_ExportXMLDataPrepare(
                ClassID       => $Param{ClassID},
                ConfigItemID  => $Param{ConfigItemID},
                UserID        => $Param{UserID},
                UsageContext  => $Param{UsageContext},
                XMLDefinition => $Item->{Sub},
                XMLData       => $Param{XMLData}->{ $Item->{Key} }->[$Counter],
                XMLData2D     => $Param{XMLData2D},
                Prefix        => $Key,
            );
        }
    }

    return 1;
}

=item _ImportXMLSearchDataPrepare()

recursion function to prepare the import XML search params

    $ObjectBackend->_ImportXMLSearchDataPrepare(
        XMLDefinition => $ArrayRef,
        What          => $ArrayRef,
        Identifier    => $HashRef,
    );

=cut

sub _ImportXMLSearchDataPrepare {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{XMLDefinition};
    return if !$Param{What};
    return if !$Param{Identifier};
    return if ref $Param{XMLDefinition} ne 'ARRAY';
    return if ref $Param{What} ne 'ARRAY';
    return if ref $Param{Identifier} ne 'HASH';

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {

        # create key
        my $Key = $Param{Prefix} ? $Param{Prefix} . '::' . $Item->{Key} : $Item->{Key};
        $Key .= '::\d+';

        my $IdentifierKey;
        IDENTIFIERKEY:
        for my $IdentKey ( sort keys %{ $Param{Identifier} } ) {

            next IDENTIFIERKEY if $IdentKey !~ m{ \A $Key \z }xms;

            $IdentifierKey = $IdentKey;
        }

        if ($IdentifierKey) {

            # prepare value
            my $Value = $Kernel::OM->Get('ITSMConfigItem')->XMLImportSearchValuePrepare(
                Item  => $Item,
                Value => $Param{Identifier}->{$IdentifierKey},
            );

            if ($Value) {

                # create search key
                my $SearchKey = 'CurrentVersion.Data.' . $IdentifierKey;
                $SearchKey =~ s/::\d+::/./gsm;
                $SearchKey =~ s/::\d+//gsm;

                # create search hash
                my $SearchHash = {
                    Field    => $SearchKey,
                    Operator => 'EQ',
                    Type     => 'STRING',
                    Value    => $Value
                };

                push @{ $Param{What} }, $SearchHash;
            }
        }

        next ITEM if !$Item->{Sub};

        # start recursion, if "Sub" was found
        $Self->_ImportXMLSearchDataPrepare(
            XMLDefinition => $Item->{Sub},
            What          => $Param{What},
            Identifier    => $Param{Identifier},
            Prefix        => $Key,
        );
    }

    return 1;
}

=item _ImportXMLDataMerge()

recursive function to inplace edit the import XML data.

    my $MergeOk = $ObjectBackend->_ImportXMLDataMerge(
        XMLDefinition => $ArrayRef,
        XMLDataPrev   => $HashRef,
        XMLData2D     => $HashRef,
    );

The return value indicates wheter the merge was successful.
A merge fails when for example a general catalog item name can't be mapped to an id.

=cut

sub _ImportXMLDataMerge {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if ( !$Param{XMLDefinition} );
    return if ( !$Param{XMLData2D} );
    return if ( !$Param{XMLDataPrev} );
    return if ( ref( $Param{XMLDefinition} ) ne 'ARRAY' );    # the attributes of the config item class
    return if ( ref( $Param{XMLData2D} ) ne 'HASH' );         # hash with values that should be imported
    return if ( ref( $Param{XMLDataPrev} ) ne 'HASH' );       # hash with current values of the config item

    # isolate XMLDataPrev
    my $XMLData = $Param{XMLDataPrev};

    # default value for prefix
    $Param{Prefix} ||= q{};

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {
        # init offset, to add values on "next" free/empty array element
        my $Offset = 0;

        COUNTER:
        for my $Counter ( 1 .. $Item->{CountMax} ) {
            # create inputkey
            my $Key = $Param{Prefix} . $Item->{Key} . q{::} . $Counter;

            # start recursion, if "Sub" was found
            if ( $Item->{Sub} ) {
                # empty container, in case there is no previous data
                $XMLData->{ $Item->{Key} }->[ $Counter - $Offset ] ||= {};

                my $MergeOk = $Self->_ImportXMLDataMerge(
                    ClassID                      => $Param{ClassID},
                    XMLDefinition                => $Item->{Sub},
                    XMLData2D                    => $Param{XMLData2D},
                    XMLDataPrev                  => $XMLData->{ $Item->{Key} }->[ $Counter - $Offset ],
                    Prefix                       => $Key . q{::},
                    EmptyFieldsLeaveTheOldValues => $Param{EmptyFieldsLeaveTheOldValues},
                    UserID                       => $Param{UserID},
                    UsageContext                 => $Param{UsageContext},
                    Silent                       => $Param{Silent}
                );

                return if !$MergeOk;
            }

            # when the data point is not part of the input definition,
            # then do not overwrite the previous setting.
            if ( !exists( $Param{XMLData2D}->{ $Key } ) ) {
                if ( $Item->{Sub} ) {

                    # if there is no (old) value and neither children - remove it and use position for next
                    if (
                        !IsArrayRefWithData( $XMLData->{ $Item->{Key} } )
                        || !IsHashRefWithData( $XMLData->{ $Item->{Key} }->[ $Counter - $Offset ] )
                    ) {
                        # empty container added during sub-handling above - remove it
                        splice( @{ $XMLData->{ $Item->{Key} } }, ( $Counter - $Offset ), 1 );
                        $Offset++;
                    }
                }
                next COUNTER;
            }

            if ( $Param{EmptyFieldsLeaveTheOldValues} ) {
                # do not override old value with an empty field is imported
                next COUNTER if ( !defined( $Param{XMLData2D}->{ $Key } ) );
            }

            # prepare value
            my $Value = $Kernel::OM->Get('ITSMConfigItem')->XMLImportValuePrepare(
                ClassID      => $Param{ClassID},
                Item         => $Item,
                Value        => $Param{XMLData2D}->{ $Key },
                UserID       => $Param{UserID},
                UsageContext => $Param{UsageContext},
                Silent       => $Param{Silent}
            );

            return if (
                defined( $Param{XMLData2D}->{ $Key } )
                && !defined( $Value )
            );

            # check if value of previous version should be restored
            my $RestorePreviousValue = 0;
            if (
                ref( $Value ) eq 'HASH'
                && $Value->{RestorePreviousValue}
            ) {
                $RestorePreviousValue = 1;

                $Value = '';
            }

            # handling if an empty field is imported
            if (
                !defined( $Value )
                || $Value eq ''
            ) {

                # if current is "leaf"-attribute (has no children)
                if ( !$Item->{Sub} ) {
                    # if there is no old value - use position for next
                    if (
                        !IsArrayRefWithData( $XMLData->{ $Item->{Key} } )
                        || !IsHashRefWithData( $XMLData->{ $Item->{Key} }->[ $Counter - $Offset ] )
                    ) {
                        $Offset++;
                    }

                    # there is an old value
                    else {
                        # but it should be removed, do it and use position for next
                        if (
                            !$Param{EmptyFieldsLeaveTheOldValues}
                            && !$RestorePreviousValue
                        ) {
                            splice( @{ $XMLData->{ $Item->{Key} } }, ( $Counter - $Offset ), 1 );
                            $Offset++;
                        }
                        # else do nothing (keep value and its postion for itself)
                    }

                } else {

                    # remove old value if requested (remove content and tagkey (old value))
                    if (
                        !$Param{EmptyFieldsLeaveTheOldValues}
                        && !$RestorePreviousValue
                    ) {
                        delete( $XMLData->{ $Item->{Key} }->[ $Counter - $Offset ]->{Content} );
                        delete( $XMLData->{ $Item->{Key} }->[ $Counter - $Offset ]->{TagKey} );
                    }

                    # if there is no (old) value and neither children - remove it and use position for next
                    if (
                        !IsArrayRefWithData( $XMLData->{ $Item->{Key} } )
                        || !IsHashRefWithData( $XMLData->{ $Item->{Key} }->[ $Counter - $Offset ] )
                    ) {
                        # empty container added during sub-handling above - remove it
                        splice( @{ $XMLData->{ $Item->{Key} } }, ( $Counter - $Offset ), 1 );
                        $Offset++;
                    }
                }

                # if last counter and only positon 0 with "undef" is contained, remove it
                if (
                    $Counter == $Item->{CountMax}
                    && $XMLData->{ $Item->{Key} }
                    && scalar( @{ $XMLData->{ $Item->{Key} } } ) == 1
                ) {
                    delete( $XMLData->{ $Item->{Key} } );
                }

                # do next, no value handling needed
                next COUNTER;
            }

            # dummy attribute does not need any value
            next COUNTER if (
                IsHashRefWithData( $Item->{Input} )
                && $Item->{Input}->{Type}
                && $Item->{Input}->{Type} eq 'Dummy'
            );

            # let merge fail, when a value cannot be prepared
            return if ( !defined( $Value ) );

            # do not set value if empty but required in CI-class... (try with next imported value)
            if (
                !$Value
                && $Item->{Input}->{Required}
            ) {
                splice( @{ $XMLData->{ $Item->{Key} } }, ( $Counter - $Offset ), 1 );
                $Offset++;
                next COUNTER;
            }

            # save the prepared value
            $XMLData->{ $Item->{Key} }->[ $Counter - $Offset ]->{Content} = $Value;
        }

        if (
            $XMLData->{ $Item->{Key} }
            && scalar( @{ $XMLData->{ $Item->{Key} } } ) == 1
        ) {
            delete( $XMLData->{ $Item->{Key} } );
        }
    }

    return 1;
}

1;

=end Internal:

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
