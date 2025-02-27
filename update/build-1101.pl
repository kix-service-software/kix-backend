#!/usr/bin/perl
# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use File::Basename;
use FindBin qw($Bin);
use lib dirname($Bin);
use lib dirname($Bin) . '/Kernel/cpan-lib';

use Getopt::Std;
use File::Path qw(mkpath);

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1101',
    },
);

use vars qw(%INC);

# migrate ticket watchers to generic watchers
_CreateDynamicFields();

exit 0;

sub _CreateDynamicFields {
    my ( $Self, %Param ) = @_;

    $Self->{DynamicFieldObject} = $Kernel::OM->Get('DynamicField');

    # get all current dynamic fields
    my $DynamicFieldList = $Self->{DynamicFieldObject}->DynamicFieldListGet(
        Valid => 0,
    );

    # get the definition for dynamic fields
    my @DynamicFields = ( IsArrayRefWithData( $Param{DynamicFieldList} ) )
        ?
        @{ $Param{DynamicFieldList} }
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
            )
        {

            # rename the field and create a new one
            my $Success = $Self->{DynamicFieldObject}->DynamicFieldUpdate(
                %{ $DynamicFieldLookup{ $DynamicField->{Name} } },
                Name   => $DynamicFieldLookup{ $DynamicField->{Name} }->{Name} . 'Old',
                UserID => 1,
            );

            $CreateDynamicField = 1;
        }

        # otherwise if the field exists and the type match, update it to the new definition
        else {
            my $Success = $Self->{DynamicFieldObject}->DynamicFieldUpdate(
                %{$DynamicField},
                ID         => $DynamicFieldLookup{ $DynamicField->{Name} }->{ID},
                FieldOrder => $DynamicFieldLookup{ $DynamicField->{Name} }->{FieldOrder},
                ValidID    => $Self->{ValidID},
                Reorder    => 0,
                UserID     => 1,
            );
        }

        # check if new field has to be created
        if ($CreateDynamicField) {

            # create a new field
            my $FieldID = $Self->{DynamicFieldObject}->DynamicFieldAdd(
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

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # define possible values
    my %MobileProcessingStatePossibleValues = (
        assigned          => 'assigned',
        downloaded        => 'downloaded',
        rejected          => 'rejected',
        accepted          => 'accepted',
        processing        => 'processing',
        suspended         => 'suspended',
        completed         => 'completed',
        partiallyexecuted => 'partially executed',
        cancelled         => 'cancelled'
    );

    my $CheckList01DefaultValue = '[{
    "id": "100",
    "title": "Announce shut off",
    "description": "Announce shut off to all possibly affected personell directly or indirectly working with the device.",
    "input": "ChecklistState",
    "value": "-"
  },
  {
    "id": "200",
    "title": "Identify energy source(s)",
    "description": "Check for connected external and internal energy sources.",
    "input": "ChecklistState",
    "value": "-"
  },
  {
    "id": "300",
    "title": "Isolate energy source(s)",
    "description": "Document measures you took in order to isolate energy source(s).",
    "input": "ChecklistState",
    "value": "-",
    "sub": [{
      "id": "210",
      "title": "Isolation by",
      "input": "Text",
      "value": ""
    }]
  },
  {
    "id": "400",
    "title": "Lock & Tag energy source(s)",
    "description": "Lock energy sources to avoid accidential re-energizing while working on the device. Tag the device as out of order due to maintenance actions.",
    "input": "ChecklistState",
    "value": "-"
  },
  {
    "id": "500",
    "title": "Ensure that equipment isolation is effective",
    "description": "Before starting maintenance or repair tasks ensure that isolation is working.",
    "input": "ChecklistState",
    "value": ""
  }
]';

    my $CheckList02DefaultValue = '[{
    "id": "100",
    "title": "task 1",
    "description": "",
    "input": "ChecklistState",
    "value": "-"
  },
  {
    "id": "200",
    "title": "task 2",
    "description": "",
    "input": "ChecklistState",
    "value": "-"
  },
  {
    "id": "300",
    "title": "task 3",
    "description": "",
    "input": "ChecklistState",
    "value": "-"
  }
]';

    # define all dynamic fields
    my @DynamicFields = (
        {
            Name       => 'MobileProcessingState',
            Label      => 'Mobile Processing',
            FieldType  => 'Dropdown',
            ObjectType => 'Ticket',
            Config     => {
                DefaultValue       => '',
                TranslatableValues => 1,
                PossibleNone       => 1,
                CountMin           => 1,
                CountMax           => 1,
                CountDefault       => 1,
                PossibleValues     => \%MobileProcessingStatePossibleValues,
                }
        },
        {
            Name       => 'RiskAssumptionRemark',
            Label      => 'Risk Assumption Remark',
            FieldType  => 'TextArea',
            ObjectType => 'Ticket',
            Config     => {
                DefaultValue => '',
                CountMin     => 0,
                CountMax     => 1,
                CountDefault => 0,
                }
        },
        {
            Name       => 'MobileProcessingChecklist010',
            Label      => 'Checklist 01',
            FieldType  => 'Checklist',
            ObjectType => 'Ticket',
            Config     => {
                DefaultValue => $CheckList01DefaultValue,
                CountMin     => 1,
                CountMax     => 1,
                CountDefault => 1,
                }
        },
        {
            Name       => 'MobileProcessingChecklist020',
            Label      => 'Checklist 02',
            FieldType  => 'Checklist',
            ObjectType => 'Ticket',
            Config     => {
                DefaultValue => $CheckList02DefaultValue,
                CountMin     => 1,
                CountMax     => 1,
                CountDefault => 1,
                }
        }
    );

    return @DynamicFields;
}


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
