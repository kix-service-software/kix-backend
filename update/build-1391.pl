#!/usr/bin/perl
# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
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

use Getopt::Std;

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1391',
    },
);

use vars qw(%INC);

# update notifications
_ReconfigureNotificationEvents();

# add new contact dynamic field "Source"
_AddDynamicFields();

sub _ReconfigureNotificationEvents {

    my %Notification = $Kernel::OM->Get('NotificationEvent')->NotificationGet(
        Name => 'Agent - Responsible Assignment',
    );

    # remove event "TicketResponsibleUpdate"
    my %Events = map { $_ => 1 } @{$Notification{Data}->{Events}};
    delete $Events{TicketResponsibleUpdate};
    $Notification{Data}->{Events} = [ sort keys %Events ];

    $Kernel::OM->Get('NotificationEvent')->NotificationUpdate(
        ID => $Notification{ID},
        %Notification,
        UserID => 1
    );

    return 1;
}

sub _AddDynamicFields {
    my ( $Self, %Param ) = @_;

    $Self->{DynamicFieldObject} = $Kernel::OM->Get('DynamicField');

    # get all current dynamic fields
    my $DynamicFieldList = $Self->{DynamicFieldObject}->DynamicFieldListGet(
        Valid => 0,
    );

    # create a dynamic fields lookup table
    my %DynamicFieldLookup;
    for my $DynamicField ( @{$DynamicFieldList} ) {
        next if ( !IsHashRefWithData($DynamicField) );
        $DynamicFieldLookup{ $DynamicField->{Name} } = $DynamicField;
    }

    # get the definition for new dynamic fields
    my @DynamicFields = _GetDynamicFieldsDefinition();

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

            # rename the old field and create a new one
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
                ValidID    => $DynamicFieldLookup{ $DynamicField->{Name} }->{ValidID},
                UserID     => 1,
            );
        }

        # check if new field has to be created
        if ($CreateDynamicField) {

            # create a new field
            my $FieldID = $Self->{DynamicFieldObject}->DynamicFieldAdd(
                %{$DynamicField},
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

    my @Functionality = ( 'preproductive', 'productive' );
    my $StateList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class       => 'ITSM::ConfigItem::DeploymentState',
        Preferences => {
            Functionality => \@Functionality,
        },
    ) || {};
    my @StateIDs = map { $_ } keys %{$StateList};

    my @DynamicFields = (
        {
            Name          => 'Source',
            Label         => Kernel::Language::Translatable('Source'),
            FieldType     => 'Text',
            ObjectType    => 'Contact',
            InternalField => 0,
            Config        => {},
        },
        {
            Name          => 'Type',
            Label         => Kernel::Language::Translatable('Type'),
            FieldType     => 'Multiselect',
            ObjectType    => 'Organisation',
            InternalField => 0,
            Config        => {
                CountMin => 1,
                CountMax => 2,
                CountDefault => 1,
                DefaultValue => undef,
                PossibleNone => 1,
                PossibleValues => {
                    'customer' => 'Customer',
                    'external supplier' => 'External Supplier',
                    'internal supplier' => 'Internal Supplier'
                },
                TranslatableValues => 1
            }
        }
    );

    return @DynamicFields;
}

exit 0;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
