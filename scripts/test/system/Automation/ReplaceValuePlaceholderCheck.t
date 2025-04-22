# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::System::VariableCheck qw(:all);

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# create tickets
my $TicketID1 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title   => '1',
    LockID  => 1,
    OwnerID => 1,
    UserID  => 1,
);
$Self->True(
    $TicketID1,
    'TicketCreate 1',
);
my $TicketID2 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title   => '2',
    LockID  => 1,
    OwnerID => 1,
    UserID  => 1,
);
$Self->True(
    $TicketID2,
    'TicketCreate 2',
);

# create check macro
my $MacroIDCheck = $Kernel::OM->Get('Automation')->MacroAdd(
    Name    => 'ExecuteMacro - Check Macro',
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $MacroIDCheck,
    'Check: MacroAdd',
);
my $MacroActionIDCheck = $Kernel::OM->Get('Automation')->MacroActionAdd(
    MacroID    => $MacroIDCheck,
    Type       => 'VariableSet',
    Parameters => {
        Value => '<KIX_TICKET_TicketID>',
    },
    ValidID    => 1,
    UserID     => 1,
);
$Self->True(
    $MacroActionIDCheck,
    'Check: MacroActionAdd',
);
my $UpdateCheck = $Kernel::OM->Get('Automation')->MacroUpdate(
    ID        => $MacroIDCheck,
    ExecOrder => [ $MacroActionIDCheck ],
    UserID    => 1,
);
$Self->True(
    $UpdateCheck,
    'Check: MacroUpdate - ExecOrder',
);

# create macro checking usage of root object id
my $MacroIDRoot = $Kernel::OM->Get('Automation')->MacroAdd(
    Name    => 'ExecuteMacro - Macro Root',
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $MacroIDRoot,
    'Root: MacroAdd',
);
my $MacroActionIDRoot = $Kernel::OM->Get('Automation')->MacroActionAdd(
    MacroID    => $MacroIDRoot,
    Type       => 'ExecuteMacro',
    Parameters => {
        MacroID  => $MacroIDCheck,
        ObjectID => $TicketID2,
    },
    ValidID    => 1,
    UserID     => 1,
);
$Self->True(
    $MacroActionIDRoot,
    'Root: MacroActionAdd',
);
my $UpdateRoot = $Kernel::OM->Get('Automation')->MacroUpdate(
    ID        => $MacroIDRoot,
    ExecOrder => [ $MacroActionIDRoot ],
    UserID    => 1,
);
$Self->True(
    $UpdateRoot,
    'Root: MacroUpdate - ExecOrder',
);

# create macro checking usage of current object id
my $MacroIDCurrent = $Kernel::OM->Get('Automation')->MacroAdd(
    Name    => 'ExecuteMacro - Macro Current',
    Type    => 'Synchronisation',
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $MacroIDCurrent,
    'Current: MacroAdd',
);
my $MacroActionIDCurrent = $Kernel::OM->Get('Automation')->MacroActionAdd(
    MacroID    => $MacroIDCurrent,
    Type       => 'ExecuteMacro',
    Parameters => {
        MacroID  => $MacroIDCheck,
        ObjectID => $TicketID2,
    },
    ValidID    => 1,
    UserID     => 1,
);
$Self->True(
    $MacroActionIDCurrent,
    'Current: MacroActionAdd',
);
my $UpdateCurrent = $Kernel::OM->Get('Automation')->MacroUpdate(
    ID        => $MacroIDCurrent,
    ExecOrder => [ $MacroActionIDCurrent ],
    UserID    => 1,
);
$Self->True(
    $UpdateRoot,
    'Current: MacroUpdate - ExecOrder',
);

# run test checking usage of root object id
my $ExecuteRoot = $Kernel::OM->Get('Automation')->MacroExecute(
    ID       => $MacroIDRoot,
    ObjectID => $TicketID1,
    UserID   => 1,
);
$Self->True(
    $ExecuteRoot,
    'Root: MacroExecute',
);
$Self->Is(
    $Kernel::OM->Get('Automation')->{MacroVariables}->{Variable},
    $TicketID1,
    'Root: MacroExecute - macro variables "Variable" has correct value',
);

# run test checking usage of current object id
my $ExecuteCurrent = $Kernel::OM->Get('Automation')->MacroExecute(
    ID       => $MacroIDCurrent,
    ObjectID => $TicketID1,
    UserID   => 1,
);
$Self->True(
    $ExecuteCurrent,
    'Current: MacroExecute',
);
$Self->Is(
    $Kernel::OM->Get('Automation')->{MacroVariables}->{Variable},
    $TicketID2,
    'Current: MacroExecute - macro variables "Variable" has correct value',
);

# rollback transaction on database
$Helper->Rollback();

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
