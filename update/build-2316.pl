#!/usr/bin/perl
# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/ 
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
use Kernel::System::Role::Permission;

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-2316',
    },
);

use vars qw(%INC);

_UpdateDurationInStateAndTeamReportDefinition();

sub _UpdateDurationInStateAndTeamReportDefinition {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Log');
    my $ReportingObject = $Kernel::OM->Get('Reporting');

    my $ReportDefinitionID = $ReportingObject->ReportDefinitionLookup(
        Name => 'Duration in State and Team'
    );

    if ($ReportDefinitionID) {
        my %ReportDefinitionData = $ReportingObject->ReportDefinitionGet(
            ID => $ReportDefinitionID
        );

        # remove unncecessary whitespace
        if (
            IsHashRefWithData($ReportDefinitionData{Config}) &&
            IsHashRefWithData($ReportDefinitionData{Config}->{DataSource}) &&
            IsArrayRefWithData($ReportDefinitionData{Config}->{DataSource}->{OutputHandler}) &&
            IsHashRefWithData($ReportDefinitionData{Config}->{DataSource}->{OutputHandler}->[0]) &&
            $ReportDefinitionData{Config}->{DataSource}->{OutputHandler}->[0]->{Name} eq 'TicketStateDuration' &&
            IsArrayRefWithData($ReportDefinitionData{Config}->{DataSource}->{OutputHandler}->[0]->{States}) &&
            $ReportDefinitionData{Config}->{DataSource}->{OutputHandler}->[0]->{States}->[0] eq 'new '
        ) {
            $ReportDefinitionData{Config}->{DataSource}->{OutputHandler}->[0]->{States}->[0] = 'new';

            my $Success = $ReportingObject->ReportDefinitionUpdate(
                %ReportDefinitionData,
                ID     => $ReportDefinitionID,
                UserID => 1
            );

            if ( !$Success ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Could not update report definition."
                );
            }
        }
    }

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
