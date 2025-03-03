# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use vars (qw($Self));

$Self->True(
    $Kernel::OM->Get('scripts::test::system::ObjectManager::Dummy'),
    "Can load custom object",
);

my $NonexistingObject = eval { $Kernel::OM->Get('scripts::test::system::ObjectManager::Disabled') };
$Self->True(
    $@,
    "Fetching an object that cannot be loaded via OM causes an exception",
);
$Self->False(
    $NonexistingObject,
    "Cannot construct an object that cannot be loaded via OM",
);

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
