# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/ 
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

# create sub macro for failing macro action
my $SubMacroIDError = $Kernel::OM->Get('Automation')->MacroAdd(
    Name    => 'Sub Macro - Error',
    Type    => 'Synchronisation',
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $SubMacroIDError,
    'MacroAdd - Sub Error',
);
my $SubMacroActionIDError = $Kernel::OM->Get('Automation')->MacroActionAdd(
    MacroID    => $SubMacroIDError,
    Type       => 'VariableSet',
    Parameters => {
        Value => {
            'Test' => 2
        },
    },
    ValidID    => 1,
    UserID     => 1,
);
$Self->True(
    $SubMacroActionIDError,
    'MacroActionAdd - Sub Error',
);
my $Success = $Kernel::OM->Get('Automation')->MacroUpdate(
    ID        => $SubMacroIDError,
    ExecOrder => [ $SubMacroActionIDError ],
    UserID    => 1,
);
$Self->True(
    $Success,
    'MacroUpdate - Sub Error',
);

# create macro
my $MacroID = $Kernel::OM->Get('Automation')->MacroAdd(
    Name    => 'UnitTest Macro',
    Type    => 'Synchronisation',
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $MacroID,
    'MacroAdd',
);

# create failing macro action 
my $MacroActionIDError = $Kernel::OM->Get('Automation')->MacroActionAdd(
    MacroID    => $MacroID,
    Type       => 'Conditional',
    Parameters => {
        If      => 'Test',
        MacroID => $SubMacroIDError,
    },
    ValidID    => 1,
    UserID     => 1,
);
$Self->True(
    $MacroActionIDError,
    'MacroActionAdd - Error',
);

# create macro action to check execution after failing macro action
my $MacroActionIDCheck = $Kernel::OM->Get('Automation')->MacroActionAdd(
    MacroID    => $MacroID,
    Type       => 'VariableSet',
    Parameters => {
        Value => {
            'Test' => 1
        },
    },
    ValidID    => 1,
    UserID     => 1,
);
$Self->True(
    $MacroActionIDCheck,
    'MacroActionAdd - Check',
);

# update macro - set ExecOrder
$Success = $Kernel::OM->Get('Automation')->MacroUpdate(
    ID        => $MacroID,
    ExecOrder => [ $MacroActionIDError,  $MacroActionIDCheck ],
    UserID    => 1,
);
$Self->True(
    $Success,
    'MacroUpdate - ExecOrder',
);

# execute macro
$Success = $Kernel::OM->Get('Automation')->MacroExecute(
    ID       => $MacroID,
    ObjectID => 1,
    UserID   => 1,
);
$Self->True(
    $Success,
    'MacroExecute',
);

# check MacroVariables
$Self->IsDeeply(
    $Kernel::OM->Get('Automation')->{MacroVariables}->{Variable},
    {
        'Test' => 1
    },
    'Check MacroVariables',
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
