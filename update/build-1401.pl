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

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1401',
    },
);

use vars qw(%INC);

# add new contact dynamic field "Source"

_UpdateDynamicFields();

sub _UpdateDynamicFields {
    my ($Self, %Param) = @_;

    $Self->{DynamicFieldObject} = $Kernel::OM->Get('DynamicField');

    my $DFAffectedAsset = $Self->{DynamicFieldObject}->DynamicFieldGet(Name => 'AffectedAsset');

    if (!$DFAffectedAsset) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Could not update dynamic field \"Affected Asset\"! Dynamic Field not found!"
        );
        return;
    }

    my $Success = $Self->{DynamicFieldObject}->DynamicFieldUpdate(
        %{$DFAffectedAsset},
        CustomerVisible => 1,
        UserID          => 1,
    );

    if (!$Success) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Could not update dynamic field \"Affected Asset\"!"
        );
        return;
    }

    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp();

    return 1;

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
