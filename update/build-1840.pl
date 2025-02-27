#!/usr/bin/perl
# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use File::Basename;
use FindBin qw($Bin);
use lib dirname($Bin);
use lib dirname($Bin) . '/Kernel/cpan-lib';

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1840',
    },
);

use vars qw(%INC);

# execution of multiple functions
_CreateDynamicFields();
_DeleteObseleteSysConfigKeys();
_AddSysConfig();

exit 0;

sub _CreateDynamicFields {
    my ( $Self, %Param ) = @_;

    my $DynamicFieldObject = $Kernel::OM->Get('DynamicField');

    # get all current dynamic fields
    my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
        Valid => 0,
    );

    # get the definition for dynamic fields
    my @DynamicFields = ( IsArrayRefWithData( $Param{DynamicFieldList} ) )
        ? @{ $Param{DynamicFieldList} }
        : _GetDynamicFieldsDefinition();

    # create a dynamic fields lookup table
    my %DynamicFieldLookup;
    for my $DynamicField ( @{$DynamicFieldList} ) {
        next if ( !IsHashRefWithData($DynamicField) );
        $DynamicFieldLookup{ $DynamicField->{Name} } = $DynamicField;
    }

    # create or update dynamic fields
    DYNAMICFIELD:
    for my $DynamicField (@DynamicFields) {

        my $CreateDynamicField;

        # check if the dynamic field already exists
        if ( !IsHashRefWithData( $DynamicFieldLookup{ $DynamicField->{Name} } ) ) {
            $CreateDynamicField = 1;
        }

        # if the field exists check if the type match with the needed type
        elsif (
            $DynamicFieldLookup{ $DynamicField->{Name} }->{FieldType}
            ne $DynamicField->{FieldType}
        ) {

            # rename the field and create a new one
            my $Success = $DynamicFieldObject->DynamicFieldUpdate(
                %{ $DynamicFieldLookup{ $DynamicField->{Name} } },
                Name   => $DynamicFieldLookup{ $DynamicField->{Name} }->{Name} . 'Old',
                UserID => 1,
            );

            $CreateDynamicField = 1;
        }

        # otherwise if the field exists and the type match, update it to the new definition
        else {
            my $Success = $DynamicFieldObject->DynamicFieldUpdate(
                %{$DynamicField},
                ID         => $DynamicFieldLookup{ $DynamicField->{Name} }->{ID},
                FieldOrder => $DynamicFieldLookup{ $DynamicField->{Name} }->{FieldOrder},
                ValidID    => 1,
                Reorder    => 0,
                UserID     => 1,
            );
        }

        # check if new field has to be created
        if ($CreateDynamicField) {

            # create a new field
            my $FieldID = $DynamicFieldObject->DynamicFieldAdd(
                Name       => $DynamicField->{Name},
                Label      => $DynamicField->{Label},
                FieldType  => $DynamicField->{FieldType},
                ObjectType => $DynamicField->{ObjectType},
                Config     => $DynamicField->{Config},
                ValidID    => 1,
                UserID     => 1,
            );
            next DYNAMICFIELD if !$FieldID;

        }
    }

    return 1;
}

sub _GetDynamicFieldsDefinition {
    my ( $Self, %Param ) = @_;

    # define all dynamic fields
    my @DynamicFields = (
        {
            Name       => 'AddressDomainPattern',
            Label      => 'Pattern',
            FieldType  => 'Text',
            ObjectType => 'Organisation',
            Config     => {
                DefaultValue => q{},
                CountMin     => 0,
                CountMax     => 25,
                CountDefault => 0,
            }
        },
    );

    return @DynamicFields;
}

sub _DeleteObseleteSysConfigKeys {

    my $SysConfigObject = $Kernel::OM->Get('SysConfig');

    my @Items = qw{
        ContactImport::DefaultCustomerID
        ContactImport::DefaultEmailAddress
        ContactImport::EMailDomainCustomerIDMapping
        ImportExport::ContactImportExport::ForceCSVMappingRecreation
    };

    foreach my $Key (@Items) {
        if (!$SysConfigObject->OptionDelete(Name => $Key)) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to delete obsolete item $Key from sysconfig!"
            );
            return;
        }
    }
    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp();

    return 1;
}

sub _AddSysConfig {
    my ( $Self, %Param ) = @_;

    my $SysConfigObject = $Kernel::OM->Get('SysConfig');

    my @Options = _GetSysConfigOptions();

    foreach my $Option (@Options) {
        my %Data = $SysConfigObject->OptionGet(
            Name => $Option->{Name}
        );

        if (%Data) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Option $Option->{Name} from sysconfig already exists!"
            );
            return;
        }

        my $Result = $SysConfigObject->OptionAdd(
            %{$Option}
        );

        if (!$Result) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to add option $Option->{Name} to sysconfig!"
            );
            return;
        }
    }

    return 1;
}

sub _GetSysConfigOptions {
    my ( $Self, %Param ) = @_;

    my @Options = (
        {
            Name            => 'Contact::EventModulePost###800-AutoAssignOrganisation',
            Description     => 'Event module to add organisations based on the enabled organisation mapping methods.',
            Type            => 'Hash',
            AccessLevel     => 'internal',
            Group           => 'Contact',
            Default         => {
                Module         => 'Kernel::System::Contact::Event::AutoAssignOrganisation',
                Event          => '(ContactAdd|ContactUpdate)',
                MappingMethods => [
                    {
                        Active => 1,
                        Method => 'MailDomain'
                    },
                    {
                        Active              => 0,
                        Method              => 'DefaultOrganisation',
                        DefaultOrganisation => 'MY_ORGA'
                    },
                    {
                        Active => 0,
                        Method => 'PersonalOrganisation'
                    }
                ]
            },
            UserID          => 1
        }
    );

    return @Options;
}

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
