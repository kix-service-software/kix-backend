# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
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

our @ObjectDependencies = qw(
    GeneralCatalog
    ITSMConfigItem
    ObjectSearch
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Recalculates the incident state of config items.');
    $Self->AddOption(
        Name        => 'configitem-number',
        Description => "Recalculate only this config item",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+/smx,
        Multiple    => 1,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Recalculating the incident state of config items...</yellow>\n\n");

    # get class list
    my $ClassList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class => 'ITSM::ConfigItem::Class',
    );

    my @ConfigItemNumbers = @{ $Self->GetOption('configitem-number') // [] };

    my @ConfigItemIDs;

    if ( !@ConfigItemNumbers ) {
        # get the valid class ids
        my @ValidClassIDs = sort keys %{$ClassList};

        # get all config items ids form all valid classes
        @ConfigItemIDs = $Kernel::OM->Get('ObjectSearch')->Search(
            ObjectType => 'ConfigItem',
            Result     => 'ARRAY',
            Search     => {
                AND => [
                    {
                        Field    => 'ClassIDs',
                        Operator => 'IN',
                        Type     => 'NUMERIC',
                        Value    => \@ValidClassIDs
                    }
                ]
            },
            UserID     => 1,
            UserType   => 'Agent'
        );
    }
    else {
        for my $ConfigItemNumber (@ConfigItemNumbers) {

            # checks the validity of the config item id
            my $ID = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemLookup(
                ConfigItemNumber => $ConfigItemNumber,
            );

            if ($ID) {
                push @ConfigItemIDs, $ID;
            }
            else {
                $Self->Print("<yellow>Unable to find config item $ConfigItemNumber.</yellow>\n");
            }
        }
    }

    # get number of config items
    my $CICount = scalar @ConfigItemIDs;

    $Self->Print("<yellow>Recalculating incident state for $CICount config items.</yellow>\n");

    my $Count = 0;
    CONFIGITEM:
    for my $ConfigItemID ( @ConfigItemIDs ) {

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
