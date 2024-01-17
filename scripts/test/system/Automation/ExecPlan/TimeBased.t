# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get ExecPlan object
my $AutomationObject = $Kernel::OM->Get('Automation');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my $NameRandom  = $Helper->GetRandomID();

my @DayMap = qw/Sun Mon Tue Wed Thu Fri Sat/;

# get current time
my ($Sec, $Min, $Hour, $Day, $Month, $Year, $WeekDay) = $Kernel::OM->Get('Time')->SystemTime2Date(
    SystemTime => $Kernel::OM->Get('Time')->SystemTime()
);

# test data
my @TestData = (
    {
        Test              => 'check day is different from planned day',
        Time              => "$Year-$Month-".($Day ? $Day-1 : $Day+1)." 09:45:00",
        LastExecutionTime => "$Year-$Month-$Day 09:40:00",
        ExpectedResult    => 0
    },
    {
        Test              => 'check time before first planned time',
        Time              => "$Year-$Month-$Day 09:45:00",
        LastExecutionTime => "$Year-$Month-$Day 09:40:00",
        ExpectedResult    => 0
    },
    {
        Test              => 'check time at first planned time',
        Time              => "$Year-$Month-$Day 10:30:00",
        LastExecutionTime => "$Year-$Month-$Day 09:40:00",
        ExpectedResult    => 1
    },
    {
        Test              => 'check time at first planned time, but job already run',
        Time              => "$Year-$Month-$Day 10:30:00",
        LastExecutionTime => "$Year-$Month-$Day 10:30:00",
        ExpectedResult    => 0
    },
    {
        Test              => 'check time after first planned time, but job not run',
        Time              => "$Year-$Month-$Day 10:45:00",
        LastExecutionTime => "$Year-$Month-$Day 09:40:00",
        ExpectedResult    => 1
    },
    {
        Test              => 'check time after first planned time, but job already run',
        Time              => "$Year-$Month-$Day 10:45:00",
        LastExecutionTime => "$Year-$Month-$Day 10:30:00",
        ExpectedResult    => 0
    },
    {
        Test              => 'check time before second planned time',
        Time              => "$Year-$Month-$Day 10:45:00",
        LastExecutionTime => "$Year-$Month-$Day 09:40:00",
        ExpectedResult    => 1
    },
    {
        Test              => 'check time at second planned time',
        Time              => "$Year-$Month-$Day 11:00:00",
        LastExecutionTime => "$Year-$Month-$Day 09:40:00",
        ExpectedResult    => 1
    },
    {
        Test              => 'check time before second planned time, but job already run at first planned time',
        Time              => "$Year-$Month-$Day 10:55:00",
        LastExecutionTime => "$Year-$Month-$Day 10:30:00",
        ExpectedResult    => 0
    },
    {
        Test              => 'check time at second planned time, but job already run at first planned time',
        Time              => "$Year-$Month-$Day 11:00:00",
        LastExecutionTime => "$Year-$Month-$Day 10:30:00",
        ExpectedResult    => 1
    },
    {
        Test              => 'check time after second planned time, but job not run',
        Time              => "$Year-$Month-$Day 11:15:00",
        LastExecutionTime => "$Year-$Month-$Day 09:40:00",
        ExpectedResult    => 1
    },
    {
        Test              => 'check time after second planned time, but job already run',
        Time              => "$Year-$Month-$Day 11:15:00",
        LastExecutionTime => "$Year-$Month-$Day 11:00:00",
        ExpectedResult    => 0
    },
);

# add valid timebased execplan
my $ExecPlanID = $AutomationObject->ExecPlanAdd(
    Name       => 'execplan-timebased-'.$NameRandom,
    Type       => 'TimeBased',
    Parameters => {
        Weekday => [
            $DayMap[$WeekDay],
        ],
        Time => [
            '10:30',
            '11:00'
        ]
    },
    ValidID    => 1,
    UserID     => 1,
);

$Self->True(
    $ExecPlanID,
    'ExecPlanAdd() for new execution plan',
);

# add job
my $JobID = $AutomationObject->JobAdd(
    Name       => 'job-'.$NameRandom,
    Type       => 'Ticket',
    ValidID    => 1,
    UserID     => 1,
);

$Self->True(
    $JobID,
    'JobAdd() for new job',
);

# check different times
foreach my $Test ( @TestData ) {
    # set last execution time in job
    my $Success = $AutomationObject->_JobLastExecutionTimeSet(
        ID         => $JobID,
        UserID     => 1,
        Time       => $Test->{LastExecutionTime},
    );

    my $CanExecute = $AutomationObject->ExecPlanCheck(
        %{$Test},
        ID      => $ExecPlanID,
        JobID   => $JobID,
        UserID  => 1,
    );

    $Self->Is(
        $CanExecute,
        $Test->{ExpectedResult},
        'ExecPlanCheck() for '.$Test->{Test},
    );
}

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
