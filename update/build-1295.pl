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

use Getopt::Std;
use File::Path qw(mkpath);
use Data::UUID;

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);
use Kernel::System::EmailParser;

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1295',
    },
);
my $LogObject = $Kernel::OM->Get('Log');

use vars qw(%INC);

sub _MigrateMobileProcessingChecklistDynamicFields {
    my ( $Self, %Param ) = @_;

    $Self->{DynamicFieldObject} = $Kernel::OM->Get('DynamicField');

    # get all current dynamic fields
    my $DynamicFieldList = $Self->{DynamicFieldObject}->DynamicFieldListGet();

    # update dynamic fields
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{ $DynamicFieldList } ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
        next DYNAMICFIELD if $DynamicFieldConfig->{Name} !~ /MobileProcessingChecklist/;
        next DYNAMICFIELD if $DynamicFieldConfig->{FieldType} ne 'CheckList';

        if( $DynamicFieldConfig->{Name} eq "MobileProcessingChecklist010") {
            my $Success = $Self->{DynamicFieldObject}->DynamicFieldUpdate(
                %{$DynamicFieldConfig},
                Config  => {
                    DefaultValue => "[{\r\n    \"id\": \"100\",\r\n    \"title\": \"Announce shut off\",\r\n\n       \"description\": \"Announce shut off to all possibly affected personell directly or indirectly working with the device.\",\r\n    \"input\": \"ChecklistState\",\r\n\n       \"value\": \"-\"\r\n  },\r\n  {\r\n    \"id\": \"200\",\r\n    \"title\": \"Identify energy source(s)\",\r\n    \"description\": \"Check for connected external and internal energy sources.\",\r\n    \"input\": \"ChecklistState\",\r\n    \"value\": \"-\"\r\n\n     },\r\n  {\r\n    \"id\": \"300\",\r\n    \"title\": \"Isolate energy source(s)\",\r\n\n       \"description\": \"Document measures you took in order to isolate energy source(s).\",\r\n\n       \"input\": \"ChecklistState\",\r\n    \"value\": \"-\",\r\n    \"sub\": [{\r\n\n         \"id\": \"210\",\r\n      \"title\": \"Isolation by\",\r\n      \"input\":\n    \"Text\",\r\n      \"value\": \"\"\r\n    }]\r\n  },\r\n  {\r\n    \"id\": \"400\",\r\n\n       \"title\": \"Lock & Tag energy source(s)\",\r\n    \"description\": \"Lock energy sources to avoid accidential re-energizing while working on the device. Tag the device as out of order due to maintenance actions.\",\r\n    \"input\": \"ChecklistState\",\r\n\n       \"value\": \"-\"\r\n  },\r\n  {\r\n    \"id\": \"500\",\r\n    \"title\": \"Ensure that equipment isolation is effective\",\r\n    \"description\": \"Before starting maintenance or repair tasks ensure that isolation is working.\",\r\n    \"input\":\n    \"ChecklistState\",\r\n    \"value\": \"\"\r\n  }\r\n]"
                },
                UserID     => 1
            );
        }

        if( $DynamicFieldConfig->{Name} eq "MobileProcessingChecklist020") {
            my $Success = $Self->{DynamicFieldObject}->DynamicFieldUpdate(
                %{$DynamicFieldConfig},
                Config  => {
                    DefaultValue => "[{\r\n    \"id\": \"100\",\r\n    \"title\": \"task 1\",\r\n    \"description\":
  \"\",\r\n    \"input\": \"ChecklistState\",\r\n    \"value\": \"-\"\r\n  },\r\n
  \ {\r\n    \"id\": \"200\",\r\n    \"title\": \"task 2\",\r\n    \"description\":
  \"\",\r\n    \"input\": \"ChecklistState\",\r\n    \"value\": \"-\"\r\n  },\r\n
  \ {\r\n    \"id\": \"300\",\r\n    \"title\": \"task 3\",\r\n    \"description\":
  \"\",\r\n    \"input\": \"ChecklistState\",\r\n    \"value\": \"-\"\r\n  }\r\n]"
                },
                UserID     => 1
            );
        }

    }
    return 1;
}

# change existing mobile processing dynamic fields
_MigrateMobileProcessingChecklistDynamicFields();

exit 0;

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
