#!/usr/bin/perl
# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
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

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1819',
    },
);

use vars qw(%INC);

# sets the flag of the first value of dynamic fields
_SetFlagFirstValue();

sub _SetFlagFirstValue {
    my ( $Self, %Param ) = @_;

    return if $Kernel::OM->Get('DB')->Do(
        SQL => <<'END'
UPDATE dynamic_field_value
SET first_value = 1
WHERE id IN (
    SELECT dfv.id
    FROM dynamic_field_value dfv
    WHERE dfv.id = (
        SELECT MIN(dfv1.id)
        FROM dynamic_field_value dfv1
        WHERE dfv1.object_id = dfv.object_id AND dfv1.field_id = dfv.field_id
    )
)
END
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
