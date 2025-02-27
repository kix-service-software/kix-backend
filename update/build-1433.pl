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

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1433',
    },
);
my $LogObject = $Kernel::OM->Get('Log');

use vars qw(%INC);

# add new faq dynamic field "Work Order"
_AddDynamicFields();

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
    my @DynamicFields = _GetDynamicFieldsDefinitions();

    # create or update dynamic fields
    DYNAMICFIELD:
    for my $DynamicField (@DynamicFields) {

        my $CreateDynamicField;

        # check if the dynamic field already exists
        if ( !IsHashRefWithData( $DynamicFieldLookup{ $DynamicField->{Name} } ) ) {
            $LogObject->Log(
                Priority => 'info',
                Message  => "DynamicField ($DynamicField->{Name}) will not be created, because allready exists!"
            );

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

            $LogObject->Log(
                Priority => 'info',
                Message  => "Successfully updated DynamicField ($DynamicField->{Name})!"
            );

            $CreateDynamicField = 1;
        }

        # otherwise if the field exists and the type match, update it to the new definition
        else {
            my $Success = $Self->{DynamicFieldObject}->DynamicFieldUpdate(
                %{$DynamicField},
                ID         => $DynamicFieldLookup{ $DynamicField->{Name} }->{ID},
                ValidID    => $DynamicFieldLookup{ $DynamicField->{Name} }->{ValidID},
                Reorder    => 0,
                UserID     => 1,
            );

            $LogObject->Log(
                Priority => 'info',
                Message  => "Successfully updated DynamicField ($DynamicField->{Name})!"
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
        } else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to create DynamicField ($DynamicField->{Name})!"
            );
        }
    }

    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp();

    return 1;
}

sub _GetDynamicFieldsDefinitions {
    my ( $Self, %Param ) = @_;

    my @DynamicFields = (
        {
            Name          => 'WorkOrder',
            Label         => Kernel::Language::Translatable('Work Order'),
            FieldType     => 'TextArea',
            ObjectType    => 'Ticket',
            InternalField => 0,
            Config        => {
                CountDefault          => 1,
                CountMax              => 1,
                CountMin              => 1,
                DefaultValue          => ""
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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
