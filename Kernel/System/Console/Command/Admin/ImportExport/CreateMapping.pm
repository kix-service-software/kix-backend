# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::ImportExport::CreateMapping;

use strict;
use warnings;

use Kernel::System::Console;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies =
  ( 'Main', 'JSON', 'ITSMConfigItem', 'ImportExport', 'GeneralCatalog', );

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description(
        'Create new import export mappings out of definitions given in JSON file.'
    );

    $Self->AddOption(
        Name        => 'file',
        Description => 'JSON file containing mapping definition.',
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    $Self->AddOption(
        Name        => 'replace',
        Description => 'enable if you want to replace existing templates with same name.',
        Required    => 0,
        HasValue    => 0,
    );

}

sub PreRun {
    my ( $Self, %Param ) = @_;

    my $File = $Self->GetOption('file');
    if ( !$File ) {
        die "Please provide --file /path/to/mapping.json - For more details use --help\n";
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # read JSON file
    my $Mapping;
    my $Replace     = $Self->GetOption('replace');
    my $MappingFile = $Self->GetOption('file');

    if ( !$MappingFile ) {
        my $NoteText = "\n<red>Need --file /path/to/mapping.json.</red>\n";
        $Self->Print($NoteText);
        return;
    }

    my $Content = $Kernel::OM->Get('Main')->FileRead( Location => $MappingFile );
    if ( !$Content ) {
        my $NoteText = "\n<red>Unable to open file \"$MappingFile\"!</red>\n";
        $Self->Print($NoteText);
        return;
    }

    $Mapping = $Kernel::OM->Get('JSON')->Decode( Data => $$Content );

    # get list of existing asset-CSV-mappings...
    my $TemplateObject  = 'ITSMConfigItem';
    my %TemplateList    = ();
    my $TemplateListRef = $Kernel::OM->Get('ImportExport')->TemplateList(
        Object => $TemplateObject,
        Format => 'CSV',
        UserID => 1,
    );

    if ( $TemplateListRef && ref($TemplateListRef) eq 'ARRAY' ) {
        for my $CurrTemplateID ( @{$TemplateListRef} ) {
            my $TemplateDataRef = $Kernel::OM->Get('ImportExport')->TemplateGet(
                TemplateID => $CurrTemplateID,
                UserID     => 1,
            );

            if ( $TemplateDataRef && ref($TemplateDataRef) eq 'HASH' && $TemplateDataRef->{Object} && $TemplateDataRef->{Name} ) {
                $TemplateList{ $TemplateDataRef->{Object} . '::' . $TemplateDataRef->{Name} } = $CurrTemplateID;
            }
        }
    }

    # get some GC data...
    my $ClassNamesDataRef = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class => 'ITSM::ConfigItem::Class',
        Valid => 1,
    );
    my $DeploymentStateDataRef = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class => 'ITSM::ConfigItem::DeploymentState',
        Valid => 1,
    );
    my $IncidentStateDataRef = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class => 'ITSM::Core::IncidentState',
        Valid => 1,
    );

    my %ClassNameData       = reverse( %{$ClassNamesDataRef} );
    my %DeploymentStateData = reverse( %{$DeploymentStateDataRef} );
    my %IncidentStateData   = reverse( %{$IncidentStateDataRef} );

    MAPPING:
    for my $TemplateName ( keys( %{$Mapping} ) ) {

        my $NoteText = "\n<green>Creating template <$TemplateName>...</green>";
        $Self->Print($NoteText);

        my $CurrMapping = $Mapping->{$TemplateName};

        my $ExistingTemplateID = $TemplateList{ $TemplateObject . '::' . $TemplateName } || '';
        if ($ExistingTemplateID) {
            my $NoteText = "\n\t<yellow>Mapping with name <" . "$TemplateName> already exists... </yellow>";
            $Self->Print($NoteText);
            if ($Replace) {
                $NoteText = "<yellow>DELETING. </yellow>\n";
                $Self->Print($NoteText);
                $Kernel::OM->Get('ImportExport')->TemplateDelete(
                    TemplateID => $ExistingTemplateID,
                    UserID     => 1,
                );
            }
            else {
                $NoteText = "<yellow>SKIPPING.</yellow>\n";
                $Self->Print($NoteText);
                next MAPPING;
            }
        }

        my $ClassID = '';
        if ( !$CurrMapping->{"ClassName"} && !$CurrMapping->{"ClassID"} ) {
            my $NoteText = "\n\t<red>No asset class name or ID given - skipping.</red>\n";
            $Self->Print($NoteText);
            next MAPPING;
        }
        elsif ($CurrMapping->{"ClassName"} && $ClassNameData{ $CurrMapping->{"ClassName"} } ) {
            $ClassID = $ClassNameData{ $CurrMapping->{"ClassName"} };
        }
        elsif ( $CurrMapping->{"ClassName"} && !$ClassNameData{ $CurrMapping->{"ClassName"} } ) {
            my $NoteText =
              "\n\t<red>Asset class <> not found - skipping.</red>\n";
            $Self->Print($NoteText);
            next MAPPING;
        }
        elsif ( $CurrMapping->{"ClassID"} && !$ClassNamesDataRef->{ $CurrMapping->{"ClassID"} } ) {
            my $NoteText = "\n\t<red>Asset class ID <> not found - skipping.</red>\n";
            $Self->Print($NoteText);
            next MAPPING;
        }
        else {
            $ClassID = $CurrMapping->{"ClassID"};
        }

        my $DeplStateID = $DeploymentStateData{"Planned"}   || '';
        my $InciStateID = $IncidentStateData{"Operational"} || '';

        if ( $CurrMapping->{"DefaultDeploymentState"} && $DeploymentStateData{ $CurrMapping->{"DefaultDeploymentState"} } ) {
            $DeplStateID = $DeploymentStateData{ $CurrMapping->{"DefaultDeploymentState"} };
        }

        if ( $CurrMapping->{"DefaultIncidentState"} && $IncidentStateData{ $CurrMapping->{"DefaultIncidentState"} } ) {
            $InciStateID = $IncidentStateData{ $CurrMapping->{"DefaultIncidentState"} };
        }

        my %AttributeValues = (
            ClassID                         => $CurrMapping->{"ClassID"}  || $ClassID,
            CountMax                        => $CurrMapping->{"CountMax"} || '10',
            EmptyFieldsLeaveTheOldValues    => $CurrMapping->{"EmptyFieldsLeaveTheOldValues"} || '1',
            Charset                         => $CurrMapping->{"Charset"}         || 'UTF-8',
            ColumnSeparator                 => $CurrMapping->{"ColumnSeparator"} || 'Semicolon',
            IncludeColumnHeaders            => $CurrMapping->{"IncludeColumnHeaders"} || '1',
            DefaultName                     => $CurrMapping->{"DefaultName"} || '',
            DefaultIncidentState            => $CurrMapping->{"DefaultDeploymentStateID"} || $InciStateID,
            DefaultDeploymentState          => $CurrMapping->{"DefaultIncidentStateID"} || $DeplStateID,
        );

        # create mapping template...
        my $TemplateID = $Kernel::OM->Get('ImportExport')->TemplateAdd(
            Object  => $TemplateObject,
            Format  => 'CSV',
            Name    => $TemplateName,
            Comment => 'Automatically created' . ( $Param{TemplateComment} ? " ($Param{TemplateComment})" : "" ),
            ValidID => 1,
            UserID  => 1,
        );
        if ( !$TemplateID ) {
            my $NoteText = "\n<red>Could not create mapping template <" . "$TemplateName> skipping.</red>\n";
            $Self->Print($NoteText);
            next MAPPING;
        }

        # store the template object data...
        $Kernel::OM->Get('ImportExport')->ObjectDataSave(
            TemplateID => $TemplateID,
            ObjectData => \%AttributeValues,
            UserID     => 1,
        );

        # store the template format data...
        $Kernel::OM->Get('ImportExport')->FormatDataSave(
            TemplateID => $TemplateID,
            FormatData => \%AttributeValues,
            UserID     => 1,
        );

        # create the row-2-attribute map...
        for my $CurrAttributeKey ( @{ $CurrMapping->{"CSVRowMapping"} } ) {

            my %ObjectAttributeValues = (
                Identifier => undef,
                Key        => $CurrAttributeKey,
            );

            # check if attribute is set as IdentifierAttribute...
            if ( $CurrMapping->{"IdentifierAttribute"} eq "$CurrAttributeKey" ) {
                $ObjectAttributeValues{Identifier} = 1;
            }
            my %FormatAttributeValues = ( Column => '', );

            # create new mapping...
            my $MappingID = $Kernel::OM->Get('ImportExport')->MappingAdd(
                TemplateID => $TemplateID,
                UserID     => 1,
            );

            # store mapping object data...
            $Kernel::OM->Get('ImportExport')->MappingObjectDataSave(
                MappingID         => $MappingID,
                MappingObjectData => \%ObjectAttributeValues,
                UserID            => 1,
            );

            # store mapping format data...
            $Kernel::OM->Get('ImportExport')->MappingFormatDataSave(
                MappingID         => $MappingID,
                MappingFormatData => \%FormatAttributeValues,
                UserID            => 1,
            );

        }

    }

    $Self->Print( "<green>Done.</green>\n" );

    return $Self->ExitCodeOk();
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
