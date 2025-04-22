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

#
# This test makes sure that object dependencies are only created when
# the object actively asks for them, not earlier.
#

use Kernel::System::ObjectManager;

local $Kernel::OM = Kernel::System::ObjectManager->new();

$Self->True( $Kernel::OM, 'Could build object manager' );

$Self->True(
    exists $Kernel::OM->{Objects}->{'Encode'},
    'Encode is always preloaded',
);

$Self->False(
    exists $Kernel::OM->{Objects}->{'Time'},
    'Time was not loaded yet',
);

$Self->False(
    exists $Kernel::OM->{Objects}->{'Log'},
    'Log was not loaded yet',
);

$Kernel::OM->Get('Time');

$Self->True(
    exists $Kernel::OM->{Objects}->{'Time'},
    'Time was loaded',
);

$Self->False(
    exists $Kernel::OM->{Objects}->{'Log'},
    'Log is a dependency of Kernel::System::Time, but was not yet loaded',
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
