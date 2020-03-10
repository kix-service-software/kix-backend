#!/usr/bin/perl
# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use File::Basename;
use FindBin qw($RealBin);
use lib dirname($RealBin) . '/../../';
use lib dirname($RealBin) . '/../../Kernel/cpan-lib';

use Getopt::Std;
use File::Path qw(mkpath);
use Data::UUID;

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);
use Kernel::System::EmailParser;

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Kernel::System::Log' => {
        LogPrefix => 'db-update-build-1163.pl',
    },
);
my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

use vars qw(%INC);

sub _MigrateMobileProcessingChecklistDynamicFields {
    my ( $Self, %Param ) = @_;

    $Self->{DynamicFieldObject} = $Kernel::OM->Get('Kernel::System::DynamicField');

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
