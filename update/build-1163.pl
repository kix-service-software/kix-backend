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
        LogPrefix => 'framework_update-to-build-1163',
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
        next DYNAMICFIELD if $DynamicFieldConfig->{FieldType} ne 'Checklist';

        my $Success = $Self->{DynamicFieldObject}->DynamicFieldUpdate(
            %{$DynamicFieldConfig},
            FieldType  => 'CheckList',
            UserID     => 1
        );

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
