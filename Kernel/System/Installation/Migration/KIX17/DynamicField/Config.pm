# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Installation::Migration::KIX17::DynamicField::Config;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::Installation::Migration::KIX17::Common
);

our @ObjectDependencies = (
    'Config',
    'DB',
    'Installation',
    'Log',
);

our %FieldTypeMigration = (
    'ActivityID' => {
        Type         => 'Text',
        Deactivate   => 1,
        Warning      => 1,
        ConfigChange => {
            Add => {
                CountMin      => 1,
                CountMax      => 1,
                CountDefault  => 1,
                ItemSeparator => '',
                RegExList     => [],
            }
        }
    },
    'Attachment' => {
        Type         => 'Text',
        Deactivate   => 1,
        Warning      => 1,
        ConfigChange => {
            Add => {
                CountMin     => 0,
                CountMax     => 1,
                CountDefault => 0,
                RegExList    => [],
            },
            Remove => [
                'AllowedFileExtensions',
                'ForbiddenFileExtensions',
                'MaxArraySize',
            ]
        }
    },
    'Captcha' => {
        Ignore => 1,
    },
    'Checkbox' => {
        Type         => 'Multiselect',
        ConfigChange => {
            Add => {
                CountMin       => 0,
                CountMax       => 1,
                CountDefault   => 0,
                ItemSeparator  => '',
                PossibleValues => {
                    '1' => 'checked'
                },
                TranslatableValues => 1
            }
        }
    },
    'CustomerCompany' => {
        Type         => 'OrganisationReference',
        ConfigChange => {
            Add => {
                CountMin      => 0,
                CountMax      => 1,
                CountDefault  => 0,
                DefaultValue  => '',
                ItemSeparator => '',
            },
            Remove => [
                'AlternativeDisplay',
                'DisplayFieldType',
                'Link',
                'ObjectReference',
                'PossibleNone',
                'TranslatableValues',
                'TreeView'
            ]
        }
    },
    'CustomerUser' => {
        Type         => 'ContactReference',
        ConfigChange => {
            Add => {
                CountMin      => 0,
                CountMax      => 1,
                CountDefault  => 0,
                DefaultValue  => '',
                ItemSeparator => '',
                UsageContext  => ['2']
            },
            Remove => [
                'AlternativeDisplay',
                'DisplayFieldType',
                'Link',
                'ObjectReference',
                'PossibleNone',
                'TranslatableValues',
                'TreeView'
            ]
        }
    },
    'Date' => {
        Type         => 'Date',
        ConfigChange => {
            Add => {
                CountMin      => 0,
                CountMax      => 1,
                CountDefault  => 0,
                ItemSeparator => '',
            },
            Remove => [
                'Link',
                'LinkPreview',
                'YearsPeriod'
            ],
        }
    },
    'DateTime' => {
        Type         => 'DateTime',
        ConfigChange => {
            Add => {
                CountMin      => 0,
                CountMax      => 1,
                CountDefault  => 0,
                ItemSeparator => '',
            },
            Remove => [
                'Link',
                'LinkPreview',
                'YearsPeriod'
            ],
        }
    },
    'Dropdown' => {
        Type         => 'Multiselect',
        ConfigChange => {
            Add => {
                CountMin      => 0,
                CountMax      => 1,
                CountDefault  => 0,
                ItemSeparator => '',
            },
            Remove => [
                'Link',
                'LinkPreview',
                'PossibleNone',
                'TreeView'
            ]
        }
    },
    'DropdownGeneralCatalog' => {
        Type         => 'DataSource',
        Deactivate   => 1,
        Warning      => 1,
        ConfigChange => {
            Add => {
                CountMin              => 0,
                CountMax              => 1,
                CountDefault          => 0,
                DataSourceID          => '',
                DisplayPattern        => '',
                DefaultDisplayColumns => [],
                CacheTTL              => 0,
            },
            Remove => [
                'Link',
                'LinkPreview',
                'PossibleNone'
            ]
        }
    },
    'Invoker' => {
        Type         => 'DataSource',
        Deactivate   => 1,
        Warning      => 1,
        ConfigChange => {
            Add => {
                CountMin              => 0,
                CountMax              => 1,
                CountDefault          => 0,
                DataSourceID          => '',
                DisplayPattern        => '',
                DefaultDisplayColumns => [],
                CacheTTL              => 0,
            },
            Remove => [
                'AgentLink',
                'CacheTTLLookup',
                'CacheTTLSearch',
                'CustomerLink',
                'DefaultValues',
                'MaxArraySize',
                'MaxQueryResult',
                'MinQueryLength',
                'QueryDelay',
                'SearchPrefix',
                'SearchSuffix',
                'WebserviceInvokerLookup',
                'WebserviceInvokerSearch',
            ]
        }
    },
    'InvokerDropdown' => {
        Type         => 'DataSource',
        Deactivate   => 1,
        Warning      => 1,
        ConfigChange => {
            Add => {
                CountMin              => 0,
                CountMax              => 1,
                CountDefault          => 0,
                DataSourceID          => '',
                DisplayPattern        => '',
                DefaultDisplayColumns => [],
                CacheTTL              => 0,
            },
            Remove => [
                'CacheTTLLookup',
                'CacheTTLSearch',
                'Link',
                'LinkPreview',
                'PossibleNone',
                'TranslatableValues',
                'TreeView',
                'WebserviceInvokerLookup',
                'WebserviceInvokerSearch',
            ]
        }
    },
    'ITSMConfigItemReference' => {
        Type         => 'ITSMConfigItemReference',
        Deactivate   => 1,
        ConfigChange => {
            Add => {
                CountMin      => 0,
                CountMax      => 99,
                CountDefault  => 0,
            },
            Remove => [
                'AgentLink',
                'Constrictions',
                'CustomerLink',
                'DisplayPattern',
                'MaxArraySize',
                'MaxQueryResult',
                'MinQueryLength',
                'QueryDelay'
            ],
            StringToArray => [
                'DefaultValue'
            ]
        }
    },
    'Multiselect' => {
        Type         => 'Multiselect',
        ConfigChange => {
            Add => {
                CountMin      => 0,
                CountMax      => 99,
                CountDefault  => 0,
                ItemSeparator => ', ',
            },
            Remove => [
                'PossibleNone',
                'TreeView'
            ],
            StringToArray => [
                'DefaultValue'
            ]
        }
    },
    'MultiselectGeneralCatalog' => {
        Type         => 'DataSource',
        Deactivate   => 1,
        Warning      => 1,
        ConfigChange => {
            Add => {
                CountMin              => 0,
                CountMax              => 99,
                CountDefault          => 0,
                DataSourceID          => '',
                DisplayPattern        => '',
                DefaultDisplayColumns => [],
                CacheTTL              => 0,
            },
            Remove => [
                'PossibleNone'
            ],
            StringToArray => [
                'DefaultValue'
            ]
        }
    },
    'ProcessID' => {
        Type         => 'Text',
        Deactivate   => 1,
        Warning      => 1,
        ConfigChange => {
            Add => {
                CountMin      => 1,
                CountMax      => 1,
                CountDefault  => 1,
                ItemSeparator => '',
                RegExList     => [],
            }
        }
    },
    'RemoteDB' => {
        Type         => 'DataSource',
        Deactivate   => 1,
        Warning      => 1,
        ConfigChange => {
            Add => {
                CountMin              => 0,
                CountMax              => 1,
                CountDefault          => 0,
                DataSourceID          => '',
                DisplayPattern        => '',
                DefaultDisplayColumns => [],
                CacheTTL              => 0,
            },
            Remove => [
                'AgentLink',
                'CustomerLink',
                'MaxArraySize',
                'MaxQueryResult',
                'MinQueryLength',
                'QueryDelay'
            ]
        }
    },
    'RichText' => {
        Type         => 'Text',
        Deactivate   => 1,
        Warning      => 1,
        ConfigChange => {
            Add => {
                CountMin      => 1,
                CountMax      => 1,
                CountDefault  => 1,
                ItemSeparator => '',
                RegExList     => [],
            },
            Remove => [
                'Cols',
                'Rows',
                'WordCountMax',
                'WordLengthMin',
                'WordLengthMax',

            ]
        }
    },
    'Table' => {}, # no changes needed for Table
    'Text' => {
        Type         => 'Text',
        ConfigChange => {
            Add => {
                CountMin      => 1,
                CountMax      => 1,
                CountDefault  => 1,
                ItemSeparator => ''
            },
            Remove => [
                'Link',
                'LinkPreview',
            ]
        }
    },
    'TextArea' => {
        Type         => 'TextArea',
        ConfigChange => {
            Add => {
                CountMin      => 1,
                CountMax      => 1,
                CountDefault  => 1,
                ItemSeparator => ''
            },
            Remove => [
                'Cols',
                'Rows',
            ]
        }
    },
    'TicketReference' => {
        Type         => 'TicketReference',
        Deactivate   => 1,
        Warning      => 1,
        ConfigChange => {
            Add => {
                CountMin      => 0,
                CountMax      => 1,
                CountDefault  => 0,
                TicketStates  => [],
                TicketTypes   => [],
                LinkType      => '',
            },
            Remove => [
                'AgentLink',
                'Constrictions',
                'CustomerLink',
                'DefaultValues',
                'DisplayPattern',
                'MaxArraySize',
                'MaxQueryResult',
                'MinQueryLength',
                'QueryDelay',
            ]
        }
    },
    'Token' => {
        Type         => 'Text',
        Deactivate   => 1,
        Warning      => 1,
        ConfigChange => {
            Add => {
                CountMin      => 1,
                CountMax      => 1,
                CountDefault  => 1,
                ItemSeparator => '',
                RegExList     => [],
            },
            Remove => [
                'Length',
            ]
        }
    },
    'User' => {
        Type         => 'ContactReference',
        ConfigChange => {
            Add => {
                CountMin      => 0,
                CountMax      => 1,
                CountDefault  => 0,
                DefaultValue  => '',
                ItemSeparator => '',
                UsageContext  => ['1']
            },
            Remove => [
                'AlternativeDisplay',
                'DisplayFieldType',
                'Link',
                'ObjectReference',
                'PossibleNone',
                'TranslatableValues',
                'TreeView',
            ]
        }
    },
);

our %ObjectTypeMigration = (
    'FAQ'             => 'FAQArticle',
    'CustomerUser'    => 'Contact',
    'CustomerCompany' => 'Organisation'
);

=item Describe()

describe what is supported and what is required

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    return {
        Supports => [
            'dynamic_field'
        ],
        Depends => {
            'create_by' => 'users',
            'change_by' => 'users',
        }
    }
}

=item Run()

create a new item in the DB

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # get source data
    my $SourceData = $Self->GetSourceData(Type => 'dynamic_field', OrderBy => 'id');

    # bail out if we don't have something to todo
    return if !IsArrayRefWithData($SourceData);

    my $YAMLObject = $Kernel::OM->Get('YAML');

    $Self->InitProgress(Type => $Param{Type}, ItemCount => scalar(@{$SourceData}));

    my %ActiveObjectTypes;
    my $ObjectTypeConfigs = $Kernel::OM->Get('Config')->Get('DynamicFields::ObjectType');
    if (IsHashRefWithData($ObjectTypeConfigs)) {
        my $SysConfigObject = $Kernel::OM->Get('SysConfig');
        for my $Type ( keys %{$ObjectTypeConfigs} ) {
            my %Config = $SysConfigObject->OptionGet(
                Name => "DynamicFields::ObjectType###$Type",
            );
            if (IsHashRefWithData(\%Config) && $Config{ValidID} == 1) {
                $ActiveObjectTypes{$Type} = 1;
            }
        }
    } else {
        %ActiveObjectTypes = (
            Ticket       => 1,
            FAQArticle   => 1,
            Contact      => 1,
            Organisation => 1,
        );
    }

    my %ActiveFieldTypes;
    my $FieldTypeConfigs = $Kernel::OM->Get('Config')->Get('DynamicFields::Driver');
    if (IsHashRefWithData($FieldTypeConfigs)) {
        my $SysConfigObject = $Kernel::OM->Get('SysConfig');
        for my $Type ( keys %{$FieldTypeConfigs} ) {
            my %Config = $SysConfigObject->OptionGet(
                Name => "DynamicFields::Driver###$Type",
            );
            if (IsHashRefWithData(\%Config) && $Config{ValidID} == 1) {
                $ActiveFieldTypes{$Type} = 1;
            }
        }
    }

    foreach my $Item ( @{$SourceData} ) {

        my $Migration = $FieldTypeMigration{$Item->{field_type}};

        # ignore Captcha
        if ( $Migration->{Ignore} ) {
            $Self->UpdateProgress($Param{Type}, 'Ignored');
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Dynamic field \"$Item->{name}\" will be ignored due to non-migrateable type \"$Item->{field_type}\"!"
            );
            next;
        }

        # check if this object is already mapped
        my $MappedID = $Self->GetOIDMapping(
            ObjectType     => 'dynamic_field',
            SourceObjectID => $Item->{id}
        );
        if ( $MappedID ) {
            $Self->UpdateProgress($Param{Type}, 'Ignored');
            next;
        }

        # check if this item already exists (i.e. some initial data)
        LOOKUP:
        my $ID = $Self->Lookup(
            Table        => 'dynamic_field',
            PrimaryKey   => 'id',
            Item         => $Item,
            RelevantAttr => [
                'name',
            ]
        );

        # some special handling if the DF already exists
        if ( $ID ) {
            $Item->{name} = 'Migration'.$Item->{name};
            # do the lookup again
            goto LOOKUP;
        }

        # insert row
        if ( !$ID ) {

            # migrate field type if needed
            my $FieldTypeSrc = $Item->{field_type};
            $Item->{field_type} = $Migration->{Type} ? $Migration->{Type} : $Item->{field_type};

            # migrate object type if needed
            $Item->{object_type} = $ObjectTypeMigration{$Item->{object_type}} ? $ObjectTypeMigration{$Item->{object_type}} : $Item->{object_type};

            # deactivate field if needed
            $Item->{valid_id} = ($Migration->{Deactivate} || !$ActiveObjectTypes{ $Item->{object_type} } || !$ActiveFieldTypes{ $Item->{field_type} }) ? 2 : $Item->{valid_id};

            # add a warning comment if needed
            $Item->{label} = ($Migration->{Warning} || !$ActiveFieldTypes{ $Item->{field_type} }) ? $Item->{label} . ' - ' . Kernel::Language::Translatable('DF not fully migrated!') : $Item->{label};

            # add a warning comment if needed
            $Item->{comments} = ($Migration->{Deactivate} || !$ActiveObjectTypes{ $Item->{object_type} } || !$ActiveFieldTypes{ $Item->{field_type} }) ? Kernel::Language::Translatable('DO NOT ENABLE THIS FIELD BEFORE ADAPTING THE CONFIG!') : undef;

            if ( $Item->{config} ) {
                my $Config = $YAMLObject->Load(Data => $Item->{config});

                # add configs for migration
                if ( IsHashRefWithData($Migration->{ConfigChange}->{Add}) ) {
                    $Config = {
                        %{$Config},
                        %{$Migration->{ConfigChange}->{Add}},
                    }
                }

                # special handling for Attachment
                if ( $FieldTypeSrc eq 'Attachment' ) {
                    # migrate MaxArraySize
                    if ( $Config->{MaxArraySize} ) {
                        $Config->{CountMax} = $Config->{MaxArraySize};
                    }
                }

                # special handling for Checkbox
                if ( $FieldTypeSrc eq 'Checkbox' ) {
                    # migrate DefaultValue
                    if ( $Config->{DefaultValue} eq 'Checked' ) {
                        $Config->{DefaultValue} = '1';
                    }
                    else {
                        $Config->{DefaultValue} = '';
                    }
                }

                # special handling for CustomerCompany, CustomerUser & User
                if (
                    $FieldTypeSrc eq 'CustomerCompany'
                    || $FieldTypeSrc eq 'CustomerUser'
                    || $FieldTypeSrc eq 'User'
                ) {
                    # migrate DisplayFieldType Multiselect
                    if ( $Config->{DisplayFieldType} eq 'Multiselect' ) {
                        $Config->{CountMax} = '99';
                    }
                    # migrate empty possible none
                    if ( !$Config->{PossibleNone} ) {
                        $Config->{CountMin}     = '1';
                        $Config->{CountDefault} = '1';
                    }
                }

                # special handling for Date & DateTime
                if (
                    $FieldTypeSrc eq 'Date'
                    || $FieldTypeSrc eq 'DateTime'
                ) {
                    # migrate DisplayFieldType Multiselect
                    if ( !$Config->{DateRestriction} ) {
                        $Config->{DateRestriction} = 'none';
                    }
                }

                # special handling for Dropdown, DropdownGeneralCatalog, Multiselect & MultiselectGeneralCatalog
                if (
                    $FieldTypeSrc eq 'Dropdown'
                    || $FieldTypeSrc eq 'DropdownGeneralCatalog'
                    || $FieldTypeSrc eq 'Multiselect'
                    || $FieldTypeSrc eq 'MultiselectGeneralCatalog'
                ) {
                    # migrate empty possible none
                    if ( !$Config->{PossibleNone} ) {
                        $Config->{CountMin}     = '1';
                        $Config->{CountDefault} = '1';
                    }

                    # init default value, if missing
                    if ( !defined( $Config->{DefaultValue} ) ) {
                        $Config->{DefaultValue} = '';
                    }
                }

                # special handling for Invoker
                if ( $FieldTypeSrc eq 'Invoker' ) {
                    # migrate MaxArraySize
                    if ( $Config->{MaxArraySize} ) {
                        $Config->{CountMax} = $Config->{MaxArraySize};
                    }
                }

                # special handling for InvokerDropdown
                if ( $FieldTypeSrc eq 'InvokerDropdown' ) {
                    # migrate empty possible none
                    if ( !$Config->{PossibleNone} ) {
                        $Config->{CountMin}     = '1';
                        $Config->{CountDefault} = '1';
                    }
                }

                # special handling for ITSMConfigItemReference
                if ( $FieldTypeSrc eq 'ITSMConfigItemReference' ) {
                    # migrate MaxArraySize
                    if ( $Config->{MaxArraySize} ) {
                        $Config->{CountMax} = $Config->{MaxArraySize};
                    }

                    # init default value, if missing
                    if ( !defined( $Config->{DefaultValue} ) ) {
                        $Config->{DefaultValue} = '';
                    }

                    # init config item classes, if missing
                    if ( !defined( $Config->{ITSMConfigItemClasses} ) ) {
                        $Config->{ITSMConfigItemClasses} = [];
                    }

                    # init deployment states, if missing
                    if ( !defined( $Config->{DeploymentStates} ) ) {
                        $Config->{DeploymentStates} = [];
                    }
                }

                # special handling for RemoteDB
                if ( $FieldTypeSrc eq 'RemoteDB' ) {
                    # migrate MaxArraySize
                    if ( $Config->{MaxArraySize} ) {
                        $Config->{CountMax} = $Config->{MaxArraySize};
                    }
                }

                # special handling for Text and TextArea
                if (
                    $FieldTypeSrc eq 'Text'
                    || $FieldTypeSrc eq 'TextArea'
                ) {
                    # init default value, if missing
                    if ( !defined( $Config->{DefaultValue} ) ) {
                        $Config->{DefaultValue} = '';
                    }

                    # init regular expression list, if missing
                    if ( !defined( $Config->{RegExList} ) ) {
                        $Config->{RegExList} = [];
                    }
                }

                # convert string config to array
                if ( IsArrayRefWithData( $Migration->{ConfigChange}->{StringToArray} ) ) {
                    for my $Attr ( @{ $Migration->{ConfigChange}->{StringToArray} } ) {
                        next if ( !defined( $Config->{ $Attr } ) );
                        next if ( ref( $Config->{ $Attr } ) eq 'ARRAY' );

                        if ( $Config->{ $Attr } eq q{} ) {
                            $Config->{ $Attr } = [];
                        }
                        else {
                            $Config->{ $Attr } = [ $Config->{$Attr} ];
                        }
                    }
                }

                # remove configs for migration
                for my $Attr ( @{ $Migration->{ConfigChange}->{Remove} || [] }, 'ValueTTL', 'ValueTTLData', 'ValueTTLMultiplier' ) {
                    delete $Config->{ $Attr };
                }

                # check for not supported field type
                if ( !$ActiveFieldTypes{ $Item->{field_type} } ) {
                    # cleanup config
                    for my $Attr ( keys( %{ $Config } ) ) {
                        # skip needed config
                        next if (
                            $Attr eq 'CountMin'
                            || $Attr eq 'CountMax'
                            || $Attr eq 'CountDefault'
                            || $Attr eq 'RegExList'
                        );

                        # initialize needed config if missing
                        if ( !defined( $Config->{CountMin} ) ) {
                            $Config->{CountMin} = 0;
                        }
                        if ( !defined( $Config->{CountMax} ) ) {
                            $Config->{CountMax} = 99;
                        }
                        if ( !defined( $Config->{CountDefault} ) ) {
                            $Config->{CountDefault} = 0;
                        }
                        if ( !defined( $Config->{RegExList} ) ) {
                            $Config->{RegExList} = [];
                        }

                        # change field type to text
                        $Item->{field_type} = 'Text';
                    }
                }

                # get yaml string
                $Item->{config} = $YAMLObject->Dump(Data => $Config);
            }

            $Item->{customer_visible} = 0;

            $ID = $Self->Insert(
                Table          => 'dynamic_field',
                PrimaryKey     => 'id',
                Item           => $Item,
                AutoPrimaryKey => 1,
                AdditionalData => { FieldTypeSource => $FieldTypeSrc }
            );
        }

        if ( $ID ) {
            $Self->UpdateProgress($Param{Type}, 'OK');
        }
        else {
            $Self->UpdateProgress($Param{Type}, 'Error');
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
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
