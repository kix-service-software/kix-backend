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
        LogPrefix => 'framework_update-to-build-2238',
    },
);

use vars qw(%INC);

# update object icon for depl state Expired
_UpdateDeplStateExpiredIcon();

sub _UpdateTicketAttachmentCounters {
    my ( $Self, %Param ) = @_;

    # get item id of depl state Production
    my $ProductionItemID = $Kernel::OM->Get('GeneralCatalog')->ItemLookup(
        Class => 'ITSM::ConfigItem::DeploymentState',
        Name  => 'Production'
    );
    if ( !$ProductionItemID ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Could not lookup ID for DeplState Production!",
        );
        return;
    }

    # get item id of depl state Expired
    my $ExpiredItemID = $Kernel::OM->Get('GeneralCatalog')->ItemLookup(
        Class => 'ITSM::ConfigItem::DeploymentState',
        Name  => 'Expired'
    );
    if ( !$ExpiredItemID ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Could not lookup ID for DeplState Expired!",
        );
        return;
    }

    # get object icon id depl state Production
    my $ProductionObjectIconIDs = $Kernel::OM->Get('ObjectIcon')->ObjectIconList(
        Object   => 'GeneralCatalogItem',
        ObjectID => $ProductionItemID
    );
    if ( !$ProductionObjectIconIDs->[0] ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Could not lookup ID for DeplState Production ObjectIcon!",
        );
        return;
    }

    # get object icon data of depl state Production
    my %ProductionObjectIcon = $Kernel::OM->Get('ObjectIcon')->ObjectIconGet(
        ID => $ProductionObjectIconIDs->[0],
    );
    if ( !%ProductionObjectIcon ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Could not get data for DeplState Production ObjectIcon!",
        );
        return;
    }

    # get object icon id depl state Expired
    my $ExpiredObjectIconIDs = $Kernel::OM->Get('ObjectIcon')->ObjectIconList(
        Object   => 'GeneralCatalogItem',
        ObjectID => $ExpiredItemID
    );
    if ( !$ExpiredObjectIconIDs->[0] ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Could not lookup ID for DeplState Expired ObjectIcon!",
        );
        return;
    }

    # update object icon of depl state Expired with content of depl state Production
    my $Success = $Kernel::OM->Get('ObjectIcon')->ObjectIconUpdate(
        ID              => $ExpiredObjectIconIDs->[0],
        Object          => 'GeneralCatalogItem',
        ObjectID        => $ExpiredItemID,
        ContentType     => $ProductionObjectIcon{ContentType},
        Content         => $ProductionObjectIcon{Content},
        UserID          => 1,
    );
    if ( !$Success ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Could not update ObjectIcon for DeplState Expired!",
        );
        return;
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
