# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
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

# create check macro
my $MacroIDCheck = $Kernel::OM->Get('Automation')->MacroAdd(
    Name    => 'Loop - Check Macro',
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $MacroIDCheck,
    'Check MacroAdd',
);

# create macro action
my $MacroActionIDCheck = $Kernel::OM->Get('Automation')->MacroActionAdd(
    MacroID    => $MacroIDCheck,
    Type       => 'VariableSet',
    Parameters => {
        Value => '${ObjectID}',
    },
    ValidID    => 1,
    UserID     => 1,
);
$Self->True(
    $MacroActionIDCheck,
    'Check MacroActionAdd',
);

# update macro - set ExecOrder
my $Success = $Kernel::OM->Get('Automation')->MacroUpdate(
    ID        => $MacroIDCheck,
    ExecOrder => [ $MacroActionIDCheck ],
    UserID    => 1,
);
$Self->True(
    $Success,
    'Check MacroUpdate - ExecOrder',
);

# create macro
my $MacroID = $Kernel::OM->Get('Automation')->MacroAdd(
    Name    => 'Loop - Macro',
    Type    => 'Synchronisation',
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $MacroID,
    'MacroAdd',
);

# create macro action
my $MacroActionID = $Kernel::OM->Get('Automation')->MacroActionAdd(
    MacroID    => $MacroID,
    Type       => 'Loop',
    Parameters => {
        Values  => '',
        MacroID => $MacroIDCheck,
    },
    ValidID    => 1,
    UserID     => 1,
);
$Self->True(
    $MacroActionID,
    'MacroActionAdd',
);

# update macro - set ExecOrder
$Success = $Kernel::OM->Get('Automation')->MacroUpdate(
    ID        => $MacroID,
    ExecOrder => [ $MacroActionID ],
    UserID    => 1,
);
$Self->True(
    $Success,
    'MacroUpdate - ExecOrder',
);

my @Tests = (
    {
        Name   => 'Check empty string',
        Values => '',
        Result => undef,
    },
    {
        Name   => 'Check empty array',
        Values => [],
        Result => undef,
    },
    {
        Name   => 'Check array containing empty strings',
        Values => ['',''],
        Result => '0',
    },
    {
        Name   => 'Check array containing single value',
        Values => ['1'],
        Result => '1',
    },
    {
        Name   => 'Check array containing multiple values',
        Values => ['1','2'],
        Result => '2',
    },
    {
        Name   => 'Check array containing zero value',
        Values => ['0'],
        Result => '0',
    },
    {
        Name   => 'Check single value',
        Values => '1',
        Result => '1',
    },
    {
        Name   => 'Check comma separated values',
        Values => '1,2',
        Result => '2',
    },
    {
        Name   => 'Check zero value',
        Values => '0',
        Result => '0',
    }
);

for my $Test ( @Tests ) {
    if ( $Test->{FixedTimeSet} ) {
        $Helper->FixedTimeSet(
            $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
                String => $Test->{FixedTimeSet},
            ),
        );
    }

    # update parameters of MacroAction
    $Success = $Kernel::OM->Get('Automation')->MacroActionUpdate(
        ID         => $MacroActionID,
        Parameters => {
            Values  => $Test->{Values},
            MacroID => $MacroIDCheck,
        },
        UserID  => 1,
        ValidID => 1,
    );
    $Self->True(
        $Success,
        $Test->{Name} . ': MacroActionUpdate',
    );

    # check if placeholder is used
    $Success = $Kernel::OM->Get('Automation')->MacroExecute(
        ID       => $MacroID,
        ObjectID => 1,
        UserID   => 1,
    );
    $Self->True(
        $Success,
        $Test->{Name} . ': MacroExecute',
    );

    if ( ref( $Test->{Result} ) ) {
        $Self->IsDeeply(
            $Kernel::OM->Get('Automation')->{MacroVariables}->{Variable},
            $Test->{Result},
            $Test->{Name} . ': MacroExecute - macro variables "Variable" of check macro',
        );
    }
    else {
        $Self->Is(
            $Kernel::OM->Get('Automation')->{MacroVariables}->{Variable},
            $Test->{Result},
            $Test->{Name} . ': MacroExecute - macro variables "Variable" of check macro',
        );
    }

    if ( $Test->{FixedTimeSet} ) {
        $Helper->FixedTimeUnset();
    }
}

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
