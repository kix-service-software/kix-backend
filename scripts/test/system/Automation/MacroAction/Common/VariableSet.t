# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
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

# create macro
my $MacroID = $Kernel::OM->Get('Automation')->MacroAdd(
    Name    => 'VariableSet - Macro',
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
    Type       => 'VariableSet',
    Parameters => {},
    ValidID    => 1,
    UserID     => 1,
);
$Self->True(
    $MacroActionID,
    'MacroActionAdd',
);

# update macro - set ExecOrder
my $Success = $Kernel::OM->Get('Automation')->MacroUpdate(
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
        Name   => 'No parameters',
        Input  => {},
        Result => undef,
    },
    {
        Name  => 'Unknown parameter',
        Input => {
            Unknown => 'Test',
        },
        Result => undef,
    },
    {
        Name  => 'Parameter Value with undef value',
        Input => {
            Value => undef,
        },
        Result => undef,
    },
    {
        Name  => 'Parameter Value with scalar value',
        Input => {
            Value => 'Test',
        },
        Result => 'Test',
    },
    {
        Name  => 'Parameter Value with hash ref value',
        Input => {
            Value => {
                'Test' => 1
            },
        },
        Result => {
                'Test' => 1
            },
    },
    {
        Name  => 'Parameter Value with array ref value',
        Input => {
            Value => [ 'Test' ],
        },
        Result => [ 'Test' ],
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
        ID         => $MacroActionID,
        Parameters => {
            %{ $Test->{Input} },
        },
        UserID     => 1,
        ValidID    => 1,
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
            $Kernel::OM->Get('Automation')->{MacroResults}->{Variable},
            $Test->{Result},
            $Test->{Name} . ': MacroExecute - macro result "Variable" of check macro',
        );
    }
    else {
        $Self->Is(
            $Kernel::OM->Get('Automation')->{MacroResults}->{Variable},
            $Test->{Result},
            $Test->{Name} . ': MacroExecute - macro result "Variable" of check macro',
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
