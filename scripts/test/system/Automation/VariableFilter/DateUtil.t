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

my $TimeObject = $Kernel::OM->Get('Time');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# get module
if ( !$Kernel::OM->Get('Main')->Require('Kernel::System::Automation::VariableFilter::DateUtil') ) {
        $Self->True(
        0,
        'Cannot find DateUtil module!',
    );
    return;

}
my $Module = Kernel::System::Automation::VariableFilter::DateUtil->new();
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
    (keys %Handler) >= 5,
    'GetFilterHandler() returns at least 5 handlers',
);

my $TestDate     = "2022-04-20 12:00:00";
my $TestDateUnix = $TimeObject->TimeStamp2SystemTime( String => $TestDate );

# check bob
if (!$Handler{'DateUtil.BOB'}) {
    $Self->True(
        0,
        '"BOB" handler is missing',
    );
} else {
    my $BOB = $Handler{'DateUtil.BOB'}->(
        {},
        Value => $TestDate
    );
    $Self->True(
        $BOB || 0,
        'BOB has value',
    );
    $Self->IsNot(
        $BOB,
        $TestDate,
        "BOB is not TestDate ($TestDate)",
    );
    my $TimeBOB = $TimeObject->BOB( String => $TestDate );
    $Self->Is(
        $BOB,
        $TimeBOB,
        'BOB is BOB',
    );
    my $BOBUnix = $Handler{'DateUtil.BOB'}->(
        {},
        Value => $TestDateUnix
    );
    $Self->Is(
        $BOB,
        $BOBUnix,
        'BOB is BOB (given as unix)',
    );
    # use wrong value
    my $BOBWrong = $Handler{'DateUtil.BOB'}->(
        {},
        Value  => 'wrong string',
        Silent => 1,
    );
    $Self->Is(
        $BOBWrong,
        'wrong string',
        "Wrong value is not changed",
    );
}

# check eob
if (!$Handler{'DateUtil.EOB'}) {
    $Self->True(
        0,
        '"EOB" handler is missing',
    );
} else {
    my $EOB = $Handler{'DateUtil.EOB'}->(
        {},
        Value => $TestDate
    );
    $Self->True(
        $EOB || 0,
        'BOB has value',
    );
    $Self->IsNot(
        $EOB,
        $TestDate,
        "EOB is not TestDate ($TestDate)",
    );
    my $TimeEOB = $TimeObject->EOB( String => $TestDate );
    $Self->Is(
        $EOB,
        $TimeEOB,
        'EOB is EOB',
    );
    my $EOBUnix = $Handler{'DateUtil.EOB'}->(
        {},
        Value => $TestDateUnix
    );
    $Self->Is(
        $EOB,
        $EOBUnix,
        'EOB is EOB (given as unix)',
    );
}

# check unixTime
if (!$Handler{'DateUtil.UnixTime'}) {
    $Self->True(
        0,
        '"UnixTime" handler is missing',
    );
} else {
    my $UnixTime = $Handler{'DateUtil.UnixTime'}->(
        {},
        Value => $TestDate
    );
    $Self->True(
        $UnixTime || 0,
        'UnixTime has value',
    );
    $Self->Is(
        $UnixTime,
        $TestDateUnix,
        "UnixTime is TestDateUnix ($TestDateUnix)",
    );
}

# check timeStamp
if (!$Handler{'DateUtil.TimeStamp'}) {
    $Self->True(
        0,
        '"TimeStamp" handler is missing',
    );
} else {
    my $TimeStamp = $Handler{'DateUtil.TimeStamp'}->(
        {},
        Value => $TestDateUnix
    );
    $Self->True(
        $TimeStamp || 0,
        'TimeStamp has value',
    );
    $Self->Is(
        $TimeStamp,
        $TestDate,
        "TimeStamp is TestDate ($TestDate)",
    );
}

# check calc
if (!$Handler{'DateUtil.Calc'}) {
    $Self->True(
        0,
        '"Calc" handler is missing',
    );
} else {
    my $NewDateTime = $Handler{'DateUtil.Calc'}->(
        {},
        Value     => $TestDate,
        Parameter => '+1d -2h +15m'
    );
    $Self->True(
        $NewDateTime || 0,
        'NewDateTime has value',
    );
    $Self->Is(
        $NewDateTime,
        '2022-04-21 10:15:00',
        "NewDateTime has right value (\"2022-04-21 10:15:00\")",
    );
    my $NewDateUnix = $Handler{'DateUtil.Calc'}->(
        {},
        Value     => $TestDateUnix,
        Parameter => '+1d -2h +15m',
        Silent    => 1,
    );
    $Self->Is(
        $NewDateUnix,
        '2022-04-21 10:15:00',
        "NewDateTime has right value (\"2022-04-21 10:15:00\") - given as unix",
    );
    # wrong parameter (missing + on 1d)
    my $NewDateMissing = $Handler{'DateUtil.Calc'}->(
        {},
        Value     => $TestDate,
        Parameter => '1d -2h +15m',
        Silent    => 1,
    );
    $Self->Is(
        $NewDateMissing,
        '2022-04-20 10:15:00',
        "NewDateTime has right value (\"2022-04-20 10:15:00\")",
    );
}

# check if filter is used in macro execution
my $ExecuteTestDate  = '2022-04-20 12:00:00';
my $FilterDoneCheck  = $TimeObject->TimeStamp2SystemTime( String => $TimeObject->BOB( String => $ExecuteTestDate) );
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
    Parameters      => { Value => '2022-04-20 12:00:00' },
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
    # check also if camelcase is irrelevant (BOB "=" bob)
    Parameters      => { Value => '${Set_A|DateUtil.bob|DateUtil.UnixTime}' },
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
    Parameters      => { Value => '${Set_A|DateUtil.unknown}' },
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
$Self->Is(
    $AutomationObject->{MacroVariables}->{Set_B},
    $FilterDoneCheck,
    "Result of 2nd action is correct (should be '$FilterDoneCheck')",
);
$Self->Is(
    $AutomationObject->{MacroVariables}->{Set_C},
    $ExecuteTestDate,
    "Result of 3nd action should be input value",
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
