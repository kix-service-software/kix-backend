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
        LogPrefix => 'framework_update-to-build-1206',
    },
);

use vars qw(%INC);

# store current CI name in table configitem as well
_MigrateConfigItemNames();

sub _MigrateConfigItemNames {
    my ( $Self, %Param ) = @_;

    my $SQL = 'UPDATE configitem ci SET name = (SELECT name FROM configitem_version civ WHERE civ.configitem_id = ci.id AND civ.id = ci.last_version_id)';

    my $Result = $Kernel::OM->Get('DB')->Do(
        SQL  => $SQL,
    );

    if ( !$Result ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Migration of ConfigItem names failed!",
        );
    }

    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp();

    return 1;
}

exit 0;

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
