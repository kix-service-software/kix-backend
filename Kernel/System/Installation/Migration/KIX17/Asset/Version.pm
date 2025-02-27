# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Installation::Migration::KIX17::Asset::Version;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::Installation::Migration::KIX17::Common
);

our @ObjectDependencies = (
    'Config',
    'DB',
    'Log',
);

=item Describe()

describe what is supported and what is required

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    return {
        Supports => [
            'configitem_version'
        ],
        DependsOnType => [
            'configitem',
            'configitem_definition',
            'customer_user',
            'customer_company',
            'queue',
        ],
        Depends => {
            'configitem_id' => 'configitem',
            'definition_id' => 'configitem_definition',
            'depl_state_id' => 'general_catalog',
            'inci_state_id' => 'general_catalog',
            'create_by'     => 'users',
        },
    }
}

=item Run()

create a new item in the DB

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # only cache the following types in memory not redis
    $Self->SetCacheOptions(
        ObjectType     => ['configitem_version', 'xml_storage'],
        CacheInMemory  => 1,
        CacheInBackend => 0,
    );

    # get source data
    my $SourceData = $Self->GetSourceData(Type => 'configitem_version', OrderBy => 'id');

    # bail out if we don't have something to todo
    return if !IsArrayRefWithData($SourceData);

    $Self->InitProgress(Type => $Param{Type}, ItemCount => scalar(@{$SourceData}));

    my $Result = $Self->_RunParallel(
        $Self->{WorkerSubRef} || \&_Run,
        Items => $SourceData,
        %Param,
    );

    # update corresponding CIs
    $Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE configitem ci SET last_version_id = (SELECT MAX(id) FROM configitem_version WHERE configitem_id = ci.id), name = (SELECT name FROM configitem_version WHERE configitem_id = ci.id ORDER BY id DESC LIMIT 1)',
    );

    # we need to cleanup the relevant caches to update the counters correctly
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Kernel::OM->Get('ITSMConfigItem')->{CacheType},
    );
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Kernel::OM->Get('GeneralCatalog')->{CacheType},
    );

    return $Result;
}

sub _Run {
    my ( $Self, %Param ) = @_;
    my $Result;

    my $Item = $Param{Item};

    # check if this object is already mapped
    my $MappedID = $Self->GetOIDMapping(
        ObjectType     => 'configitem_version',
        SourceObjectID => $Item->{id}
    );
    if ( $MappedID ) {
        return 'Ignored';
    }

    # check if this item already exists (i.e. some initial data)
    my $ID = $Self->Lookup(
        Table        => 'configitem_version',
        PrimaryKey   => 'id',
        Item         => $Item,
        RelevantAttr => [
            'name',
            'configitem_id',
            'id'
        ]
    );

    # insert row
    if ( !$ID ) {
        # get additional data of already migrated config item
        my $ConfigItemAdditionalData = $Self->GetOIDAdditionalData(
            ObjectType     => 'configitem',
            SourceObjectID => $Item->{'configitem_id::raw'}
        );
        if ( ref( $ConfigItemAdditionalData ) ne 'HASH' ) {
            return 'Error';
        }

        # remove all attributes we can't handle
        for my $Attr ( qw( name_lower ci_class_id ci_configitem_number ci_create_time ci_create_by is_last_version ) ) {
            delete $Item->{$Attr};
        }

        $ID = $Self->Insert(
            Table          => 'configitem_version',
            PrimaryKey     => 'id',
            Item           => $Item,
            AutoPrimaryKey => 1,
        );

        $Self->_MigrateXMLData(
            SourceAssetID   => $Item->{'configitem_id::raw'},
            SourceClassID   => $ConfigItemAdditionalData->{'class_id::raw'},
            ClassID         => $ConfigItemAdditionalData->{'class_id'},
            VersionID       => $ID,
            SourceVersionID => $Item->{id},
            DefinitionID    => $Item->{definition_id},
        );
    }

    if ( $ID ) {
        $Result = 'OK';
    }
    else {
        $Result = 'Error';
    }

    return $Result;
}

sub _MigrateXMLData {
    my ( $Self, %Param ) = @_;
    my %Result;

    # check needed params
    for my $Needed (qw(SourceAssetID ClassID SourceClassID VersionID SourceVersionID DefinitionID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # get source data
    my $SourceData = $Self->GetSourceData(
        Type       => 'configitem_xmldata',
        ObjectID   => $Param{SourceVersionID},
        NoProgress => 1
    );

    # bail out if we don't have something to todo
    return %Result if !IsArrayRefWithData($SourceData);

    # fake CI attachments as additional items
    my $CIAttachments = $Self->GetSourceData(
        Type       => 'configitem_attachment',
        ObjectID   => $Param{SourceAssetID},
        NoProgress => 1
    );

    if ( IsArrayRefWithData($CIAttachments) ) {
        my $XMLType = 'ITSM::ConfigItem';
        if ( $SourceData->[0]->{xml_type} =~ /^(.*?)::\d+$/ ) {
            $XMLType = $1;
        }
        
        my $BackendObject = $Kernel::OM->Get('ITSMConfigItem::XML::Type::Attachment');
        my $Index = 1;
        foreach my $Attachment ( @{$CIAttachments} ) {
            my $AttachmentDirID = $BackendObject->InternalValuePrepare(
                Value => $Attachment,
            );
            push @{$SourceData}, {
                'xml_type'          => $XMLType.'::'.$Param{SourceClassID},
                'xml_key'           => $Param{SourceVersionID},
                'xml_content_key'   => "[1]{Version}[1]{CIAttachments}[$Index]{TagKey}",
                'xml_content_value' => "[1]{Version}[1]{CIAttachments}[$Index]",
            };
            push @{$SourceData}, {
                'xml_type'          => $XMLType.'::'.$Param{SourceClassID},
                'xml_key'           => $Param{SourceVersionID},
                'xml_content_key'   => "[1]{Version}[1]{CIAttachments}[$Index]{Content}",
                'xml_content_value' => $AttachmentDirID,
            };
            $Index++;
        }
    }

    foreach my $Item ( @{$SourceData} ) {

        # check if this object is already mapped
        my $MappedID = $Self->GetOIDMapping(
            ObjectType     => 'xml_storage',
            SourceObjectID => $Item->{xml_type} . '::' . $Item->{xml_key} . '::' . $Item->{xml_content_key}
        );
        next if $MappedID;

        # set new AssetID
        my @TypeParts = split(/::/, $Item->{xml_type});
        pop @TypeParts;
        $Item->{xml_type} = join('::', @TypeParts) . '::' . $Param{ClassID};
        $Item->{xml_key}  = $Param{VersionID};

        # check if this item already exists (i.e. some initial data)
        my $ID = $Self->Lookup(
            Table        => 'xml_storage',
            PrimaryKey   => 'id',
            Item         => $Item,
            RelevantAttr => [
                'xml_type',
                'xml_key',
                'xml_content_key'
            ]
        );

        # insert row
        if ( !$ID ) {
            # map the original ID in the XML data to the migrated one
            my $Success = $Self->_MapAttributeValue(Item => $Item, DefinitionID => $Param{DefinitionID});
            if ( $Success ) {
                $ID = $Self->Insert(
                    Table          => 'xml_storage',
                    PrimaryKey     => 'id',
                    Item           => $Item,
                    SourceObjectID => $Item->{xml_type} . '::' . $Item->{xml_key} . '::' . $Item->{xml_content_key},
                    AutoPrimaryKey => 1,
                );
            }
        }

        if ( $ID ) {
            $Result{OK}++;
        }
        else {
            $Result{Error}++;
        }
    }

    return %Result;
}

sub _MapAttributeValue {
    my ( $Self, %Param ) = @_;

    my %TypeLookupMapping = (
        'CIClassReference'    => 'configitem',
        'Organisation'        => 'organisation',
        'Contact'             => 'contact',
        'GeneralCatalog'      => 'general_catalog',
        'TeamReference'       => 'queue',
    );

    # check needed params
    for my $Needed (qw(Item DefinitionID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my $Key = $Param{Item}->{xml_content_key};
    $Key =~ s/[\']//g;
    $Key =~ s/\[.*?\]//g;
    return 1 if $Key !~ /{Content}$/;
    return 1 if !$Param{Item}->{xml_content_value};

    if ( !$Self->{DefinitionFlatHash}->{$Param{DefinitionID}} ) {
        my $Definition = $Kernel::OM->Get('ITSMConfigItem')->DefinitionGet(
            DefinitionID => $Param{DefinitionID},
        );
        $Self->{DefinitionFlatHash}->{$Param{DefinitionID}} = $Self->_CreateDefinitionFlatHash(
            Definition => $Definition->{DefinitionRef},
        );
    }

    # prepare key
    my @PreparedKeyParts;
    while ( $Key ) {
        if ( $Key =~ /^{(.*?)}(.*?)$/ ) {
            $Key = $2;
            next if $1 =~ /Content|Version/;
            push @PreparedKeyParts, $1;
        }
    }
    my $PreparedKey = join('.', @PreparedKeyParts);
    return 1 if $PreparedKey eq 'CIAttachments';
    return 1 if !$PreparedKey;
    return 1 if !$Self->{DefinitionFlatHash}->{$Param{DefinitionID}}->{$PreparedKey};

    # now map the field type to the object type
    my $TypeMapping = $TypeLookupMapping{$Self->{DefinitionFlatHash}->{$Param{DefinitionID}}->{$PreparedKey}};
    if ( $TypeMapping ) {
        # we need to take special care of some values because we now store the IDs of the objects

        # define the source type
        my %LookupTypeMapping = (
            'contact' => 'customer_user',
        );

        if ( $LookupTypeMapping{$TypeMapping} ) {
            # define the lookup attribute for this source type
            my %LookupAttributeMapping = (
                'contact' => 'login',
            );

            # some special handling here
            if ( $Param{Item}->{xml_content_value} eq 'root@localhost' ) {
                $Param{Item}->{xml_content_value} = 'admin'
            }

            # get source data if not already cached
            if ( !IsArrayRef($Self->{LookupSourceData}->{$TypeMapping}->{$Param{Item}->{xml_content_value}}) ) {
                $Self->{LookupSourceData}->{$TypeMapping}->{$Param{Item}->{xml_content_value}} = $Self->GetSourceData(Type => $LookupTypeMapping{$TypeMapping}, Where => "$LookupAttributeMapping{$TypeMapping} = '$Param{Item}->{xml_content_value}'");
                if ( !IsArrayRefWithData($Self->{LookupSourceData}->{$TypeMapping}->{$Param{Item}->{xml_content_value}}) ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => "Unable to lookup $LookupTypeMapping{$TypeMapping} row with $LookupAttributeMapping{$TypeMapping} \"$Param{Item}->{xml_content_value}\"!"
                    );
                    return;
                }
            }
            if ( IsArrayRef($Self->{LookupSourceData}->{$TypeMapping}->{$Param{Item}->{xml_content_value}}) ) {
                # define the reference attribute to be used for this type
                my %ReferenceAttributeMapping = (
                    'contact' => 'id',
                );

                # we have an object, so we can use its id for the OID mapping
                $Param{Item}->{xml_content_value} = $Self->{LookupSourceData}->{$TypeMapping}->{$Param{Item}->{xml_content_value}}->[0]->{$ReferenceAttributeMapping{$TypeMapping} || 'id'}
            }
        }

        my $MappedID = $Self->GetOIDMapping(
            ObjectType     => $TypeMapping,
            SourceObjectID => $Param{Item}->{xml_content_value},
        );
        if ( $MappedID ) {
            $Param{Item}->{xml_content_value} = $MappedID;
        }
    }
    elsif ( $Self->{DefinitionFlatHash}->{$Param{DefinitionID}}->{$PreparedKey} eq 'Attachment' ) {
        my $AttachmentMeta = $Self->GetSourceData(
            Type       => 'attachment_directory',
            Where      => "id = $Param{Item}->{xml_content_value}",
            NoProgress => 1
        );
        if ( IsArrayRefWithData($AttachmentMeta) ) {
            my $AttachmentContent = $Self->GetSourceData(
                Type       => 'attachment_storage',
                Where      => "attachment_directory_id = $Param{Item}->{xml_content_value}",
                NoProgress => 1
            );

            if ( IsArrayRefWithData($AttachmentContent) ) {
                my $AttachmentPrefs = $Self->GetSourceData(
                    Type       => 'attachment_dir_preferences',
                    Where      => "attachment_directory_id = $Param{Item}->{xml_content_value}",
                    NoProgress => 1
                );
                my %Attachment = (
                    Filename => $AttachmentMeta->[0]->{file_name},
                    Content  => $AttachmentContent->[0]->{data},
                );
                foreach my $Pref ( @{$AttachmentPrefs || []} ) {
                    $Attachment{$Pref->{preferences_key}} = $Pref->{preferences_value};
                }
                $Attachment{ContentType} = $Attachment{DataType};

                my $AttachmentDirID = $Kernel::OM->Get('ITSMConfigItem::XML::Type::Attachment')->InternalValuePrepare(
                    Value => \%Attachment,
                );
                $Param{Item}->{xml_content_value} = $AttachmentDirID;
            }
        }
    }

    return 1;
}

sub _CreateDefinitionFlatHash {
    my ( $Self, %Param ) = @_;
    my %Result;

    return if !$Param{Definition} || !IsArrayRefWithData($Param{Definition});

    foreach my $Attr ( @{$Param{Definition}} ) {
        my $Key = $Param{ParentKey} ? $Param{ParentKey}.'.'.$Attr->{Key} : $Attr->{Key};

        $Result{$Key} = $Attr->{Input}->{Type};
        if ( IsArrayRefWithData($Attr->{Sub}) ) {
            my $SubResult = $Self->_CreateDefinitionFlatHash(
                Definition => $Attr->{Sub},
                ParentKey  => $Key,
            );
            %Result = (
                %Result,
                %{$SubResult},
            );
        }
    }

    return \%Result;
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
