# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::ITSM::IncidentState::Recalculate;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'GeneralCatalog',
    'ITSMConfigItem',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Recalculates the incident state of config items.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Recalculating the incident state of config items...</yellow>\n\n");

    # get class list
    my $ClassList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class => 'ITSM::ConfigItem::Class',
    );

    # get the valid class ids
    my @ValidClassIDs = sort keys %{$ClassList};

    # get all config items ids form all valid classes
    my $ConfigItemsIDsRef = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemSearch(
        ClassIDs => \@ValidClassIDs,
    );

    # get number of config items
    my $CICount = scalar @{$ConfigItemsIDsRef};

    $Self->Print("<yellow>Recalculating incident state for $CICount config items.</yellow>\n");

    my $Count = 0;
    CONFIGITEM:
    for my $ConfigItemID ( @{$ConfigItemsIDsRef} ) {

        my $Success = $Kernel::OM->Get('ITSMConfigItem')->RecalculateCurrentIncidentState(
            ConfigItemID => $ConfigItemID,
        );

        if ( !$Success ) {
            $Self->Print("<red>... could not recalculate incident state for config item id '$ConfigItemID'!</red>\n");
            next CONFIGITEM;
        }

        $Count++;

        if ( $Count % 100 == 0 ) {
            $Self->Print("<green>... $Count config items recalculated.</green>\n");
        }
    }

    $Self->Print("\n<green>Ready. Recalculated $Count config items.</green>\n\n");

    $Self->Print("<green>Ready.</green>\n");
    return $Self->ExitCodeOk();

}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
