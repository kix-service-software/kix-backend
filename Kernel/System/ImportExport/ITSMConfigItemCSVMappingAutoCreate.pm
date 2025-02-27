# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ImportExport::ITSMConfigItemCSVMappingAutoCreate;

use strict;
use warnings;

use Data::Dumper;

our @ObjectDependencies = (
    'Config',
    'ITSMConfigItem',
    'ImportExport',
    'GeneralCatalog',
    'Log'
);

use List::Util qw(min);

sub new {
    my ( $Type, %Param ) = @_;

    #allocate new hash for object...
    my $Self = {};
    bless( $Self, $Type );

    $Self->{ITSMConfigItemObject}   = $Kernel::OM->Get('ITSMConfigItem');
    $Self->{GeneralCatalogObject}   = $Kernel::OM->Get('GeneralCatalog');
    $Self->{LogObject}              = $Kernel::OM->Get('Log');
    $Self->{ImportExportObject}     = $Kernel::OM->Get('ImportExport');
    $Self->{ConfigObject}           = $Kernel::OM->Get('Config');

    return $Self;
}

=item CSVMappingAutoCreate()

execute a command. Returns the shell status code to be used by exit().

    AutoCreateObject->CSVMappingAutoCreate(
        ClassID         => 123,
        XMLDefinitionID => 123,                     # optional - last version will be used if omitted
        TemplateComment => 'some comment'           # optional - used as additional comment for template creation
    );

=cut

sub CSVMappingAutoCreate {
    my ( $Self, %Param ) = @_;

    # check required stuff...
    foreach (qw(ClassID)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Needed ClassID!"
            );
            return;
        }
    }

    my $CIClassRef = $Self->{GeneralCatalogObject}->ItemGet(
        ItemID => $Param{ClassID},
    );

    my %CIClassHash = %{$CIClassRef};
    my $XMLDefinition;

    if ( $Param{XMLDefinitionID} ) {
        $XMLDefinition = $Self->{ITSMConfigItemObject}->DefinitionGet(
            DefinitionID => $Param{XMLDefinitionID},
        );
    } else {
        $XMLDefinition = $Self->{ITSMConfigItemObject}->DefinitionGet(
            ClassID => $Param{ClassID},
        );
    }

    if ( !$XMLDefinition
        || ref $XMLDefinition ne 'HASH'
        || !$XMLDefinition->{DefinitionRef}
        || ref $XMLDefinition->{DefinitionRef} ne 'ARRAY'
    ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Event::ITSMConfigItemCSVMappingAutoCreate: No relevant XMLDefinition exists"
            . ($Param{XMLDefinitionID} ? " (with ID $Param{XMLDefinitionID})" : "") . "!"
        );
        return;
    }

    my $CSVMappingAutoCreateConfig = $Self->{ConfigObject}->Get('ImportExport::CSVMappingAutoCreate');

    my $TemplateName    = $CIClassHash{Name} . ' (auto-created map)';
    my $TemplateObject  = 'ITSMConfigItem';
    my %TemplateList    = ();
    my $TemplateListRef = $Self->{ImportExportObject}->TemplateList(
        Object => $TemplateObject,
        Format => 'CSV',
        UserID => 1,
    );
    if ( $TemplateListRef && ref($TemplateListRef) eq 'ARRAY' ) {
        for my $CurrTemplateID ( @{$TemplateListRef} ) {
            my $TemplateDataRef = $Self->{ImportExportObject}->TemplateGet(
                TemplateID => $CurrTemplateID,
                UserID     => 1,
            );
            if (
                $TemplateDataRef
                && ref($TemplateDataRef) eq 'HASH'
                && $TemplateDataRef->{Object}
                && $TemplateDataRef->{Name}
                )
            {
                $TemplateList{ $TemplateDataRef->{Object} . '::' . $TemplateDataRef->{Name} }
                    = $CurrTemplateID;
            }
        }
    }

    #-----------------------------------------------------------------------
    # check if template already exists...
    if ( $TemplateList{ $TemplateObject . '::' . $TemplateName } ) {
        if ($CSVMappingAutoCreateConfig->{ForceCSVMappingRecreation}) {
            $Self->{ImportExportObject}->TemplateDelete(
                TemplateID => $TemplateList{ $TemplateObject . '::' . $TemplateName },
                UserID     => 1,
            );
            $Self->{LogObject}->Log(
                Priority => 'notice',
                Message  => "CSV mapping \"$TemplateName\" deleted for re-creation."
            );
        }
        else {
            $Self->{LogObject}->Log(
                Priority => 'notice',
                Message  => "CSV mapping \"$TemplateName\" already exists and is not re-created (see \"ForceCSVMappingRecreation\").",
            );
            return;
        }
    }

    #-----------------------------------------------------------------------
    # get CI-class attribute list...
    my @AttributeKeyList = (
        'Number',
        'Name',
        'DeplState',
        'InciState',
    );
    $Self->_MappingObjectAttributesGet(
        XMLDefinition => $XMLDefinition->{DefinitionRef},
        ElementList   => \@AttributeKeyList,
        CountMaxLimit => $CSVMappingAutoCreateConfig->{CountMax},
    );

    #-----------------------------------------------------------------------
    # create mapping template...
    my $TemplateID = $Self->{ImportExportObject}->TemplateAdd(
        Object  => $TemplateObject,
        Format  => 'CSV',
        Name    => $TemplateName,
        Comment => 'Automatically created' . ($Param{TemplateComment} ? " ($Param{TemplateComment})" : ""),
        ValidID => 1,
        UserID  => 1,
    );
    if ( !$TemplateID ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'Could not create mapping template <'
                . $TemplateName
                . '>.',
        );
        next;
    }

    my $DeploymentStateDataRef = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class => 'ITSM::ConfigItem::DeploymentState',
        Valid => 1,
    );
    my $IncidentStateDataRef = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class => 'ITSM::Core::IncidentState',
        Valid => 1,
    );

    my %IncidentStateData   = reverse(%{$IncidentStateDataRef});
    my %DeploymentStateData = reverse(%{$DeploymentStateDataRef});
    my $DeplStateID         = $DeploymentStateData{Planned}   || '';
    my $InciStateID         = $IncidentStateData{Operational} || '';

    if ( $CSVMappingAutoCreateConfig->{DefaultDeploymentState}
        && $DeploymentStateData{$CSVMappingAutoCreateConfig->{DefaultDeploymentState}}
    ) {
        $DeplStateID = $DeploymentStateData{$CSVMappingAutoCreateConfig->{DefaultDeploymentState}};
    }
    if ( $CSVMappingAutoCreateConfig->{DefaultIncidentState}
        && $IncidentStateData{$CSVMappingAutoCreateConfig->{DefaultIncidentState}}
    ) {
        $InciStateID = $IncidentStateData{$CSVMappingAutoCreateConfig->{DefaultIncidentState}};
    }

    #-----------------------------------------------------------------------
    # mapping for current CI-class definition
    my %AttributeValues = (
        ClassID                      => $CIClassHash{ItemID},
        CountMax                     => $CSVMappingAutoCreateConfig->{CountMax}                     || '10',
        EmptyFieldsLeaveTheOldValues => $CSVMappingAutoCreateConfig->{EmptyFieldsLeaveTheOldValues} // '1',
        Charset                      => $CSVMappingAutoCreateConfig->{Charset}                      || 'UTF-8',
        ColumnSeparator              => $CSVMappingAutoCreateConfig->{ColumnSeparator}              || 'Semicolon',
        IncludeColumnHeaders         => $CSVMappingAutoCreateConfig->{IncludeColumnHeaders}         || '1',
        DefaultName                  => $CSVMappingAutoCreateConfig->{DefaultName}                  || '',
        DefaultIncidentState         => $InciStateID,
        DefaultDeploymentState       => $DeplStateID,
    );

    # store the template object data...
    $Self->{ImportExportObject}->ObjectDataSave(
        TemplateID => $TemplateID,
        ObjectData => \%AttributeValues,
        UserID     => 1,
    );

    # store the template format data...
    $Self->{ImportExportObject}->FormatDataSave(
        TemplateID => $TemplateID,
        FormatData => \%AttributeValues,
        UserID     => 1,
    );
    for my $CurrAttributeKey (@AttributeKeyList) {
        my %ObjectAttributeValues = (
            Identifier => undef,
            Key        => $CurrAttributeKey,
        );
        if ( $CurrAttributeKey eq 'Number' ) {
            $ObjectAttributeValues{Identifier} = 1;
        }
        my %FormatAttributeValues = (
            Column => '',
        );

        # create new mapping...
        my $MappingID = $Self->{ImportExportObject}->MappingAdd(
            TemplateID => $TemplateID,
            UserID     => 1,
        );

        # store mapping object data...
        $Self->{ImportExportObject}->MappingObjectDataSave(
            MappingID         => $MappingID,
            MappingObjectData => \%ObjectAttributeValues,
            UserID            => 1,
        );

        # store mapping format data...
        $Self->{ImportExportObject}->MappingFormatDataSave(
            MappingID         => $MappingID,
            MappingFormatData => \%FormatAttributeValues,
            UserID            => 1,
        );
    }
    return 1;
}

sub _MappingObjectAttributesGet {
    my ( $Self, %Param ) = @_;
    return if !$Param{CountMaxLimit};
    return if !$Param{XMLDefinition};
    return if !$Param{ElementList};
    return if ref $Param{XMLDefinition} ne 'ARRAY';
    return if ref $Param{ElementList} ne 'ARRAY';
    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {
        my $CountMax = min( $Item->{CountMax}, $Param{CountMaxLimit} );
        COUNT:
        for my $Count ( 1 .. $CountMax ) {

            # create key string
            my $Key = $Item->{Key} . '::' . $Count;

            # add prefix to key
            if ( $Param{KeyPrefix} ) {
                $Key = $Param{KeyPrefix} . '::' . $Key;
            }
            push( @{ $Param{ElementList} }, $Key );
            next COUNT if !$Item->{Sub};

            # start recursion
            $Self->_MappingObjectAttributesGet(
                XMLDefinition => $Item->{Sub},
                ElementList   => $Param{ElementList},
                KeyPrefix     => $Key,
                CountMaxLimit => $Param{CountMaxLimit},
            );
        }
    }
    return 1;
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
