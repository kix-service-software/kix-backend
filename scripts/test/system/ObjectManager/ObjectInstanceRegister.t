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

use Kernel::System::Time;
use Kernel::System::ObjectManager;

$Self->Is(
    $Kernel::OM->Get('UnitTest'),
    $Self,
    "Global OM returns $Self as 'UnitTest'",
);

local $Kernel::OM = Kernel::System::ObjectManager->new();

$Self->True( $Kernel::OM, 'Could build object manager' );

$Self->False(
    exists $Kernel::OM->{Objects}->{'Time'},
    'Time was not loaded yet',
);

my $TimeObject = Kernel::System::Time->new();

$Self->True(
    $Kernel::OM->ObjectInstanceRegister(
        Package      => 'Time',
        Object       => $TimeObject,
        Dependencies => [],
    ),
    'Registered TimeObject',
);

$Self->Is(
    $Kernel::OM->Get('Time'),
    $TimeObject,
    "OM returns the original TimeObject",
);

$Kernel::OM->ObjectsDiscard();

$Self->True(
    $TimeObject,
    "TimeObject is still alive after ObjectsDiscard()",
);

$Self->IsNot(
    $Kernel::OM->Get('Time'),
    $TimeObject,
    "OM returns its own TimeObject",
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
