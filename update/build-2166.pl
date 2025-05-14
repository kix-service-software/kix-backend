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
use lib dirname($Bin) . '/plugins';
use lib dirname($Bin) . '/Kernel/cpan-lib';

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-2166',
    },
);

use vars qw(%INC);

_UpdateReportDefinition();

sub _UpdateReportDefinition {

    my $ReportDefinitionID = $Kernel::OM->Get('Reporting')->ReportDefinitionLookup(
        Name => 'Duration in State and Team',
    );
    return 1 if ( !$ReportDefinitionID );

    my %ReportDefinitionData = $Kernel::OM->Get('Reporting')->ReportDefinitionGet(
        ID => $ReportDefinitionID,
    );
    return 1 if ( !%ReportDefinitionData );
    return 1 if ( !$ReportDefinitionData{IsPeriodic} );

    my $Success = $Kernel::OM->Get('Reporting')->ReportDefinitionUpdate(
        %ReportDefinitionData,
        ID         => $ReportDefinitionID,
        IsPeriodic => 0,
        UserID     => 1,
    );

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
