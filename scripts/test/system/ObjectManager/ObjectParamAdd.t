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

use Kernel::System::ObjectManager;

local $Kernel::OM = Kernel::System::ObjectManager->new();

$Kernel::OM->ObjectParamAdd(
    'Config' => {
        Data => 'Test payload',
    },
);

$Self->IsDeeply(
    $Kernel::OM->{Param}->{'Config'},
    {
        Data => 'Test payload',
    },
    'ObjectParamAdd set key',
);

$Kernel::OM->ObjectParamAdd(
    'Config' => {
        Data2 => 'Test payload 2',
    },
);

$Self->IsDeeply(
    $Kernel::OM->{Param}->{'Config'},
    {
        Data  => 'Test payload',
        Data2 => 'Test payload 2',
    },
    'ObjectParamAdd set key',
);

$Kernel::OM->ObjectParamAdd(
    'Config' => {
        Data => undef,
    },
);

$Self->IsDeeply(
    $Kernel::OM->{Param}->{'Config'},
    {
        Data2 => 'Test payload 2',
    },
    'ObjectParamAdd removed key',
);

$Kernel::OM->ObjectParamAdd(
    'Config' => {
        Data2 => undef,
    },
);

$Self->IsDeeply(
    $Kernel::OM->{Param}->{'Config'},
    {},
    'ObjectParamAdd removed key',
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
