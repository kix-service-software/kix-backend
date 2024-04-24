# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::Installation::Migrate::Ticket::SetAffectedAssetFromLinks;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'DynamicField',
    'DynamicField::Backend',
    'LinkObject',
    'NotificationClient',
    'Cache',
    'ObjectSearch'
);

use Kernel::System::VariableCheck qw(:all);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Updates AffectedAsset dynamic field with all linked assets from ticket.');

    my $Name = $Self->Name();

    $Self->AdditionalHelp(<<"EOF");
The <green>$Name</green> command updates the 'AffectedAsset' dynamic field with all linked assets that are linked to the respective ticket.
EOF
    return;
}

sub Run {
    my ($Self) = @_;

    my $DynamicFieldConfig = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
        Name => 'AffectedAsset'
    );

    if ( !IsHashRefWithData($DynamicFieldConfig) ){
        $Self->PrintError("DynmicField 'AffectedAsset' doesn't exists!");
        return $Self->ExitCodeError();
    }

    $Self->Print("<yellow>Fetch tickets...</yellow>\n");
    my @TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Ticket',
        Result     => 'ARRAY',
        Limit      => 0,
        UserID     => 1,
    );

    my $CountTotal = scalar @TicketIDs;

    $Self->Print("Found $CountTotal and start update AffectedAsset...\n");

    my $CleanUp = 0;
    for my $TicketID ( @TicketIDs ) {

        $Self->Print("<yellow>Fetch linked asset to ticket (ID: $TicketID)...</yellow>\n");
        my %LinkKeyList = $Kernel::OM->Get('LinkObject')->LinkKeyList(
            Object1   => 'Ticket',
            Key1      => $TicketID,
            Object2   => 'ConfigItem',
            UserID    => 1,
        );
        my $Count = scalar ( keys %LinkKeyList);
        $Self->Print("Found $Count asset(s)...\n");

        next if !%LinkKeyList;

        my $DynamicFieldValue = $Kernel::OM->Get('DynamicField::Backend')->ValueGet(
            DynamicFieldConfig => $DynamicFieldConfig,
            ObjectID           => $TicketID
        );

        my %NewValues;
        if ( IsArrayRefWithData($DynamicFieldValue) ) {
            %NewValues = map{ $_ => 1 } @{$DynamicFieldValue};
        }
        elsif ( $DynamicFieldValue ) {
            $NewValues{$DynamicFieldValue} = 1;
        }

        %NewValues = (
            %NewValues,
            %LinkKeyList
        );

        my @Values;
        ITEM:
        for my $ItemID ( sort keys %NewValues ) {
            next ITEM if ( !$ItemID );
            push(@Values, $ItemID);
        }

        next if !@Values;

        if (
            $DynamicFieldConfig->{Config}->{CountMax}
            && $DynamicFieldConfig->{Config}->{CountMax} < scalar( @Values )
        ) {
            $Self->Print("<yellow>WARNING: The number of assets to be linked is higher than the set MaxCount of the dynamic field.</yellow>\n");
        }

        my $Success = $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
            DynamicFieldConfig => $DynamicFieldConfig,
            ObjectID           => $TicketID,
            Value              => \@Values,
            UserID             => 1
        );

        if ( !$Success ) {
            $Self->PrintError("Couldn't update dynamic field 'AffectedAsset' for ticket (ID: $TicketID)!");
            next;
        }

        $CleanUp = 1;
    }

    if ( $CleanUp ) {
        for my $Key (
            qw(
                Ticket ITSMConfigurationManagement
                DynamicFieldValue LinkObject
            )
        ) {
            $Kernel::OM->Get('Cache')->CleanUp(
                Type => $Key
            );
        }
    }

    $Self->Print("<green>Done.</green>\n");

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
