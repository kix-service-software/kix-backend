# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

my $TimeObject = $Kernel::OM->Get('Time');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# get module
if ( !$Kernel::OM->Get('Main')->Require('Kernel::System::Automation::VariableFilter::CSVUtil') ) {
        $Self->True(
        0,
        'Cannot find CSVUtil module!',
    );
    return;

}
my $Module = Kernel::System::Automation::VariableFilter::CSVUtil->new();
if ( !$Module ) {
        $Self->True(
        0,
        'Get module instance failed!',
    );
    return;
}

# get handler
if ( !$Module->can('GetFilterHandler') ) {
    $Self->True(
        0,
        "Module cannot \"GetFilterHandler\"!"
    );
    return;
}
my %Handler = $Module->GetFilterHandler();
$Self->True(
    IsHashRefWithData(\%Handler) || 0,
    'GetFilterHandler()',
);
if (!IsHashRefWithData(\%Handler)) {
    $Self->True(
        0,
        'GetFilterHandler()',
    );
}
$Self->True(
    (keys %Handler) == 12,
    'GetFilterHandler() returns 2 handler',
);

# check AsArrayList
if (!$Handler{'CSVUtil.AsArrayList'}) {
    $Self->True(
        0,
        '"AsArrayList" handler is missing',
    );
} else {
    my @AsArrayListTests = (
        {
            Name      => 'Undefined value',
            Value     => undef,
            Parameter => undef,
            Expected  => undef,
            Silent    => 1
        },
        {
            Name      => 'Empty string',
            Value     => '',
            Parameter => undef,
            Expected  => '',
            Silent    => 1
        },
        {
            Name      => 'Invalid CSV',
            Value     => <<'END',
"Column1";"Col
END
            Parameter => undef,
            Expected  => [],
            Silent    => 1
        },
        {
            Name      => 'Empty CSV',
            Value     => <<'END',

END
            Parameter => undef,
            Expected  => [['']],
            Silent    => 0
        },
        {
            Name      => 'CSV with content, without parameter',
            Value     => <<'END',
"Column1";"Column2";"Column3"
"Value1_1";"Value1_2";"Value1_3"
"Value2_1";"Value2_2";"Value2_3"
END
            Parameter => undef,
            Expected  => [
                ["Column1","Column2","Column3"],
                ["Value1_1","Value1_2","Value1_3"],
                ["Value2_1","Value2_2","Value2_3"]
            ],
            Silent    => 0
        },
        {
            Name      => 'CSV with content, with parameter',
            Value     => <<'END',
"Column1","Column2","Column3"
"Value1_1","Value1_2","Value1_3"
"Value2_1","Value2_2","Value2_3"
END
            Parameter => ',',
            Expected  => [
                ["Column1","Column2","Column3"],
                ["Value1_1","Value1_2","Value1_3"],
                ["Value2_1","Value2_2","Value2_3"]
            ],
            Silent    => 0
        }
    );
    for my $Test ( @AsArrayListTests ) {
        my $Result = $Handler{'CSVUtil.AsArrayList'}->(
            {},
            Value     => $Test->{Value},
            Parameter => $Test->{Parameter},
            Silent    => $Test->{Silent}
        );

        $Self->IsDeeply(
            $Result,
            $Test->{Expected},
            'CSVUtil.AsArrayList:' . $Test->{Name}
        );
    }
}

# check AsObjectList
if (!$Handler{'CSVUtil.AsObjectList'}) {
    $Self->True(
        0,
        '"AsObjectList" handler is missing',
    );
} else {
    my @AsObjectListTests = (
        {
            Name      => 'Undefined value',
            Value     => undef,
            Parameter => undef,
            Expected  => undef,
            Silent    => 1
        },
        {
            Name      => 'Empty string',
            Value     => '',
            Parameter => undef,
            Expected  => '',
            Silent    => 1
        },
        {
            Name      => 'Invalid CSV',
            Value     => <<'END',
"Column1";"Col
END
            Parameter => undef,
            Expected  => [],
            Silent    => 1
        },
        {
            Name      => 'Empty CSV',
            Value     => <<'END',

END
            Parameter => undef,
            Expected  => [],
            Silent    => 0
        },
        {
            Name      => 'CSV with content, without parameter',
            Value     => <<'END',
"Column1";"Column2";"Column3"
"Value1_1";"Value1_2";"Value1_3"
"Value2_1";"Value2_2";"Value2_3"
END
            Parameter => undef,
            Expected  => [
                {"Column1" => "Value1_1","Column2" => "Value1_2","Column3" => "Value1_3"},
                {"Column1" => "Value2_1","Column2" => "Value2_2","Column3" => "Value2_3"}
            ],
            Silent    => 0
        },
        {
            Name      => 'CSV with content, with parameter',
            Value     => <<'END',
"Column1","Column2","Column3"
"Value1_1","Value1_2","Value1_3"
"Value2_1","Value2_2","Value2_3"
END
            Parameter => ',',
            Expected  => [
                {"Column1" => "Value1_1","Column2" => "Value1_2","Column3" => "Value1_3"},
                {"Column1" => "Value2_1","Column2" => "Value2_2","Column3" => "Value2_3"}
            ],
            Silent    => 0
        }
    );
    for my $Test ( @AsObjectListTests ) {
        my $Result = $Handler{'CSVUtil.AsObjectList'}->(
            {},
            Value     => $Test->{Value},
            Parameter => $Test->{Parameter},
            Silent    => $Test->{Silent}
        );

        $Self->IsDeeply(
            $Result,
            $Test->{Expected},
            'CSVUtil.AsObjectList:' . $Test->{Name}
        );
    }
}

# check if filter is used in macro execution
my $AutomationObject = $Kernel::OM->Get('Automation');
my $MacroID          = $AutomationObject->MacroAdd(
    Name    => 'test-macro-for-filter-check',
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $MacroID || 0,
    'MacroAdd()',
);
my $MacroActionID_1 = $AutomationObject->MacroActionAdd(
    MacroID => $MacroID,
    Type    => 'VariableSet',
    Parameters      => {
        Value => <<'END',
"Column1";"Column2";"Column3"
"Value1_1";"Value1_2";"Value1_3"
"Value2_1";"Value2_2";"Value2_3"
END
    },
    ResultVariables => { Variable => 'Set_A'},
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $MacroActionID_1 || 0,
    'MacroActionAdd() 1',
);
my $MacroActionID_2 = $AutomationObject->MacroActionAdd(
    MacroID => $MacroID,
    Type    => 'VariableSet',
    # check also if camelcase is irrelevant (AsArrayList "=" asarraylist)
    Parameters      => { Value => '${Set_A|CSVUtil.asarraylist}' },
    ResultVariables => { Variable => 'Set_B'},
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $MacroActionID_2 || 0,
    'MacroActionAdd() 2',
);
my $MacroActionID_3 = $AutomationObject->MacroActionAdd(
    MacroID => $MacroID,
    Type    => 'VariableSet',
    # check with unknown filter (no change should be done)
    Parameters      => { Value => '${Set_A|CSVUtil.unknown}' },
    ResultVariables => { Variable => 'Set_C'},
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $MacroActionID_3 || 0,
    'MacroActionAdd() 3',
);
my $MacroUpdateResult = $AutomationObject->MacroUpdate(
    ID        => $MacroID,
    ExecOrder => [$MacroActionID_1, $MacroActionID_2, $MacroActionID_3],
    UserID    => 1
);
$Self->True(
    $MacroUpdateResult || 0,
    'MacroUpdate()',
);
my $Success = $AutomationObject->MacroExecute(
    ID       => $MacroID,
    ObjectID => 9999,
    UserID   => 1
);
$Self->True(
    $Success || 0,
    'MacroExecute()',
);
$Self->True(
    IsHashRefWithData($AutomationObject->{MacroVariables}) || 0,
    'MacroVariables is hash ref',
);
$Self->IsDeeply(
    $AutomationObject->{MacroVariables}->{Set_B},
    [
        ["Column1","Column2","Column3"],
        ["Value1_1","Value1_2","Value1_3"],
        ["Value2_1","Value2_2","Value2_3"]
    ],
    'Result of 2nd action',
);
$Self->IsDeeply(
    $AutomationObject->{MacroVariables}->{Set_C},
    <<'END',
"Column1";"Column2";"Column3"
"Value1_1";"Value1_2";"Value1_3"
"Value2_1";"Value2_2";"Value2_3"
END
    "Result of 3nd action",
);

# rollback transaction on database
$Helper->Rollback();

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut



