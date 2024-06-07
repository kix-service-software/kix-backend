# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
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
    Name    => 'ExecuteMacro - Check Macro',
    Type    => 'Synchronisation',
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
    Type       => 'AssembleObject',
    Parameters => {
        Type       => 'JSON',
        Definition => '"True"',
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
    Name    => 'ExecuteMacro - Macro',
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
    Type       => 'ExecuteMacro',
    Parameters => {
        MacroID  => $MacroIDCheck,
        ObjectID => 1,
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
        Name   => 'Only MacroID',
        Input  => {
            MacroID => $MacroIDCheck,
        },
        Silent => 1,
        Result => undef,
    },
    {
        Name   => 'Valid MacroID',
        Input  => {
            MacroID  => $MacroIDCheck,
            ObjectID => 1,
        },
        Result => 'True',
    },
    {
        Name   => 'Valid MacroID, string as ObjectID',
        Input  => {
            MacroID  => $MacroIDCheck,
            ObjectID => 'Test',
        },
        Result => 'True',
    },
    {
        Name   => 'Invalid MacroID',
        Input  => {
            MacroID  => -1,
            ObjectID => 1,
        },
        Silent => 1,
    },
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
        ID      => $MacroActionID,
        Parameters => {
            %{ $Test->{Input} },
        },
        Silent  => $Test->{Silent},
        UserID  => 1,
        ValidID => 1,
    );

    if ( exists( $Test->{Result} ) ) {
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
                $Kernel::OM->Get('Automation')->{MacroResults}->{Object}->{Object},
                $Test->{Result},
                $Test->{Name} . ': MacroExecute - macro result "Object.Object" of check macro',
            );
        }
        else {
            $Self->Is(
                $Kernel::OM->Get('Automation')->{MacroResults}->{Object}->{Object},
                $Test->{Result},
                $Test->{Name} . ': MacroExecute - macro result "Object.Object" of check macro',
            );
        }
    }
    else {
        $Self->False(
            $Success,
            $Test->{Name} . ': MacroActionUpdate fails',
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
