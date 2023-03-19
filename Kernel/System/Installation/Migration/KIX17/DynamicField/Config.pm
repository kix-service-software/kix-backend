# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
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
    'Log',
);

our %FieldTypeMigration = (
    'Attachment' => {
        Deactivate => 1,
        Warning    => 1,
    },
    'Checkbox' => {
        Type => 'Multiselect',
        ConfigChange => {
            Remove => [
                'PossibleNone',
            ],
            Add => {
                CountMin => 1,
                CountMax => 1,
                CountDefault => 1,
                PossibleValues => {
                    ''  => '-',
                    '1' => 'checked'
                },
                TranslatableValues => 1,
            }
        }
    },
    'Dropdown' => {
        Type => 'Multiselect',
        ConfigChange => {
            Remove => [
                'PossibleNone'
            ],
            Add => {
                CountMin => 1,
                CountMax => 1,
                CountDefault => 1,
            }
        }
    },
    'DropdownGeneralCatalog' => {
        Type => 'Multiselect',
        Deactivate => 1,
        Warning    => 1,
        ConfigChange => {
            Remove => [
                'PossibleNone'
            ],
            Add => {
                CountMin => 1,
                CountMax => 1,
                CountDefault => 1,
            }
        }
    },
    'Multiselect' => {
        Type => 'Multiselect',
        ConfigChange => {
            Remove => [
                'PossibleNone'
            ],
            Add => {
                CountMin => 1,
                CountMax => 99,
                CountDefault => 1,
            }
        }
    },
    'MultiselectGeneralCatalog' => {
        Type => 'Multiselect',
        Deactivate => 1,
        Warning    => 1,
        ConfigChange => {
            Remove => [
                'PossibleNone'
            ],
            Add => {
                CountMin => 1,
                CountMax => 99,
                CountDefault => 1,
            }
        }
    },
    'CustomerCompany' => {
        Type => 'OrganisationReference',
        ConfigChange => {
            Add => {
                CountMin => 1,
                CountMax => 1,
                CountDefault => 1,
            }
        }
    },
    'CustomerUser' => {
        Type => 'ContactReference',
        ConfigChange => {
            Add => {
                CountMin => 1,
                CountMax => 1,
                CountDefault => 1,
            }
        }
    },
    'User' => {
        Type => 'ContactReference',
        ConfigChange => {
            Add => {
                CountMin => 1,
                CountMax => 1,
                CountDefault => 1,
            }
        }
    },
    'ActivityID' => {
        Deactivate => 1,
        Warning    => 1,
    },
    'ProcessID' => {
        Deactivate => 1,
        Warning    => 1,
    },
    'RemoteDB' => {
        Type => 'Multiselect',
        Deactivate => 1,
        Warning    => 1,
    },
    'TicketReference' => {
        Deactivate => 1,
        Warning    => 1,
    },
    'RichText' => {
        Deactivate => 1,
        Warning    => 1,
    },
    'Token' => {
        Type => 'Text',
        Deactivate => 1,
    },
    'Captcha' => {
        Ignore => 1,
    },
    'Date' => {
        Type => 'Date',
        ConfigChange => {
            Remove => [
                'YearsPeriod'
            ],
        }
    },
    'DateTime' => {
        Type => 'DateTime',
        ConfigChange => {
            Remove => [
                'YearsPeriod'
            ],
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
            $Item->{name} = 'Migration-'.$Item->{name};
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
            $Item->{valid_id} = ($Migration->{Deactivate} || !$ActiveObjectTypes{ $Item->{object_type} }) ? 2 : $Item->{valid_id};

            # add a warning comment if needed
            $Item->{label} = $Migration->{Warning} ? $Item->{label} . ' - ' . Kernel::Language::Translatable('DF Type not yet supported!') : $Item->{label};

            # add a warning comment if needed
            $Item->{comments} = ($Migration->{Deactivate} || !$ActiveObjectTypes{ $Item->{object_type} }) ? Kernel::Language::Translatable('DO NOT ENABLE THIS FIELD UNTIL THE TYPE IS SUPPORTED!') : undef;

            if ( $Item->{config} ) {
                my $Config = $YAMLObject->Load(Data => $Item->{config});
                if ( IsHashRefWithData($Migration->{ConfigChange}->{Add}) ) {
                    $Config = {
                        %{$Config},
                        %{$Migration->{ConfigChange}->{Add}},
                    }
                }
                foreach my $Attr ( @{$Migration->{ConfigChange}->{Remove} || []}, 'ValueTTL', 'ValueTTLData', 'ValueTTLMultiplier' ) {
                    delete $Config->{$Attr};
                }
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
