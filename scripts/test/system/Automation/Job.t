# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get Job object
my $AutomationObject = $Kernel::OM->Get('Automation');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my $NameRandom  = $Helper->GetRandomID();
my %JobIDByJobName = (
    'test-job-' . $NameRandom . '-1' => undef,
    'test-job-' . $NameRandom . '-2' => undef,
    'test-job-' . $NameRandom . '-3' => undef,
);

# try to add jobs
for my $JobName ( sort keys %JobIDByJobName ) {
    my $JobID = $AutomationObject->JobAdd(
        Name    => $JobName,
        Type    => 'Ticket',
        ValidID => 1,
        UserID  => 1,
    );

    $Self->True(
        $JobID,
        'JobAdd() for new job ' . $JobName,
    );

    if ($JobID) {
        $JobIDByJobName{$JobName} = $JobID;
    }
}

# try to add already added jobs
for my $JobName ( sort keys %JobIDByJobName ) {
    my $JobID = $AutomationObject->JobAdd(
        Name    => $JobName,
        Type    => 'Ticket',
        ValidID => 1,
        UserID  => 1,
        Silent  => 1,
    );

    $Self->False(
        $JobID,
        'JobAdd() for already existing Job ' . $JobName,
    );
}

# try to fetch data of existing Jobs
for my $JobName ( sort keys %JobIDByJobName ) {
    my $JobID = $JobIDByJobName{$JobName};
    my %Job = $AutomationObject->JobGet( ID => $JobID );

    $Self->Is(
        $Job{Name},
        $JobName,
        'JobGet() for Job ' . $JobName,
    );
}

# look up existing Jobs
for my $JobName ( sort keys %JobIDByJobName ) {
    my $JobID = $JobIDByJobName{$JobName};

    my $FetchedJobID = $AutomationObject->JobLookup( Name => $JobName );
    $Self->Is(
        $FetchedJobID,
        $JobID,
        'JobLookup() for job name ' . $JobName,
    );

    my $FetchedJobName = $AutomationObject->JobLookup( ID => $JobID );
    $Self->Is(
        $FetchedJobName,
        $JobName,
        'JobLookup() for job ID ' . $JobID,
    );
}

# list Jobs
my %Jobs = $AutomationObject->JobList();
for my $JobName ( sort keys %JobIDByJobName ) {
    my $JobID = $JobIDByJobName{$JobName};

    $Self->True(
        exists $Jobs{$JobID} && $Jobs{$JobID} eq $JobName,
        'JobList() contains job ' . $JobName . ' with ID ' . $JobID,
    );
}

# change name of a single Job
my $JobNameToChange = 'test-job-' . $NameRandom . '-1';
my $ChangedJobName  = $JobNameToChange . '-changed';
my $JobIDToChange   = $JobIDByJobName{$JobNameToChange};

my $JobUpdateResult = $AutomationObject->JobUpdate(
    ID      => $JobIDToChange,
    Name    => $ChangedJobName,
    ValidID => 1,
    UserID  => 1,
);

$Self->True(
    $JobUpdateResult,
    'JobUpdate() for changing name of job ' . $JobNameToChange . ' to ' . $ChangedJobName,
);

$JobIDByJobName{$ChangedJobName} = $JobIDToChange;
delete $JobIDByJobName{$JobNameToChange};

# try to add job with previous name
my $JobID1 = $AutomationObject->JobAdd(
    Name    => $JobNameToChange,
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
);

$Self->True(
    $JobID1,
    'JobAdd() for new job ' . $JobNameToChange,
);

if ($JobID1) {
    $JobIDByJobName{$JobNameToChange} = $JobID1;
}

# try to add job with changed name
$JobID1 = $AutomationObject->JobAdd(
    Name    => $ChangedJobName,
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
    Silent  => 1,
);

$Self->False(
    $JobID1,
    'JobAdd() add job with existing name ' . $ChangedJobName,
);

my $JobName2 = $ChangedJobName . 'update';
my $JobID2   = $AutomationObject->JobAdd(
    Name    => $JobName2,
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
);

$Self->True(
    $JobID2,
    'JobAdd() add the second test job ' . $JobName2,
);

# try to update Job with existing name
my $JobUpdateWrong = $AutomationObject->JobUpdate(
    ID      => $JobID2,
    Name    => $ChangedJobName,
    ValidID => 2,
    UserID  => 1,
    Silent  => 1,
);

$Self->False(
    $JobUpdateWrong,
    'JobUpdate() update job with existing name ' . $ChangedJobName,
);

# delete an existing job
my $JobDelete = $AutomationObject->JobDelete(
    ID      => $JobIDToChange,
    UserID  => 1,
);

$Self->True(
    $JobDelete,
    'JobDelete() delete existing job',
);

# delete a non existent job
$JobDelete = $AutomationObject->JobDelete(
    ID     => 9999,
    UserID => 1,
    Silent => 1,
);

$Self->False(
    $JobDelete,
    'JobDelete() delete non existent job',
);

# create a job with filter
my $JobID = $AutomationObject->JobAdd(
    Name    => 'job-with-filter-'.$NameRandom,
    Type    => 'Ticket',
    Filter  => {
        AND => [
            { Field => 'Dummy', Operator => 'EQ', Value => 'this is a test' }
        ]
    },
    ValidID => 1,
    UserID  => 1,
);

$Self->True(
    $JobID,
    'JobAdd() for new job with filter',
);

# get this job
my %Job = $AutomationObject->JobGet(
    ID => $JobID
);

$Self->IsDeeply(
    $Job{Filter},
    [
        {
            AND => [
                {
                    Field    => 'Dummy',
                    Operator => 'EQ',
                    Value    => 'this is a test'
                }
            ]
        }
    ],
    'JobGet() for new job with filter',
);

# update this job
my $Result = $AutomationObject->JobUpdate(
    ID => $JobID,
    %Job,
    Filter  => {
        AND => [
            { Field => 'Dummy', Operator => 'EQ', Value => 'this is a test' },
            { Field => 'Dummy2', Operator => 'EQ', Value => 'this is a second test' }
        ]
    },
    UserID  => 1,
);

$Self->True(
    $Result,
    'JobUpdate() for new job with filter',
);

# create job with execplan assignment
my $ExecPlanID = $AutomationObject->ExecPlanAdd(
    Name    => 'execplan-'.$NameRandom,
    Type    => 'EventBased',
    Parameters => {
        Event => [ 'TicketCreate' ]
    },
    ValidID => 1,
    UserID  => 1,
);

$Self->True(
    $ExecPlanID,
    'ExecPlanAdd() for new execution plan',
);

$Result = $AutomationObject->JobExecPlanAdd(
    JobID   => $JobID,
    ExecPlanID => $ExecPlanID,
    ValidID => 1,
    UserID  => 1,
);

$Self->True(
    $Result,
    'JobExecPlanAdd() for execution plan assignment',
);

# get this assigment
my @ExecPlanIDs = $AutomationObject->JobExecPlanList(
    JobID => $JobID
);

$Self->IsDeeply(
    \@ExecPlanIDs,
    [ $ExecPlanID ],
    'JobExecPlanList() for new job with execution plan assignment',
);

# create job with macro assignment
my $MacroID = $AutomationObject->MacroAdd(
    Name    => 'macro-'.$NameRandom,
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
);

$Self->True(
    $MacroID,
    'MacroAdd() for new macro',
);

$Result = $AutomationObject->JobMacroAdd(
    JobID   => $JobID,
    MacroID => $MacroID,
    ValidID => 1,
    UserID  => 1,
);

$Self->True(
    $Result,
    'JobMacroAdd() for macro assignment',
);

# get this assigment
my @MacroIDs = $AutomationObject->JobMacroList(
    JobID => $JobID
);

$Self->IsDeeply(
    \@MacroIDs,
    [ $MacroID ],
    'JobMacroList() for new job with macro assignment',
);

# some additional filter tests
# create a job with valid filter
my $JobID = $AutomationObject->JobAdd(
    Name    => 'job-with-valid filter-'.$NameRandom,
    Type    => 'Ticket',
    Filter  => {
        AND => [
            { Field => 'Dummy', Operator => 'EQ', Value => 'this is a test' }
        ]
    },
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $JobID,
    'JobAdd() for new job with valid filter',
);
my %Job = $AutomationObject->JobGet(
    ID => $JobID
);
$Self->IsDeeply(
    $Job{Filter},
    [
        {
            AND => [
                {
                    Field    => 'Dummy',
                    Operator => 'EQ',
                    Value    => 'this is a test'
                }
            ]
        }
    ],
    'JobGet() for new job with valid filter',
);
# set empty filter
my $Result = $AutomationObject->JobUpdate(
    ID => $JobID,
    %Job,
    Filter  => [],
    UserID  => 1,
);
$Self->True(
    $JobID,
    'JobAdd() for new job with valid filter',
);
my %Job = $AutomationObject->JobGet(
    ID => $JobID
);
$Self->IsDeeply(
    $Job{Filter},
    [],
    'JobGet() for upddated job with valid (now empty) filter',
);
# create a job with empty filter
my $JobID = $AutomationObject->JobAdd(
    Name    => 'job-with-empty filter-'.$NameRandom,
    Type    => 'Ticket',
    Filter  => [],
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $JobID,
    'JobAdd() for new job with empty filter',
);
my %Job = $AutomationObject->JobGet(
    ID => $JobID
);
$Self->IsDeeply(
    $Job{Filter},
    [],
    'JobGet() for new job with empty filter',
);
# create a job with filter list
my $JobID = $AutomationObject->JobAdd(
    Name    => 'job-with-list filter-'.$NameRandom,
    Type    => 'Ticket',
    Filter  => [
        {
            AND => [
                { Field => 'Dummy', Operator => 'EQ', Value => 'this is a test' }
            ]
        },
        {
            AND => [
                { Field => 'Dummy2', Operator => 'EQ', Value => 'this is a test 2' }
            ]
        }
    ],
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $JobID,
    'JobAdd() for new job with filter list',
);
my %Job = $AutomationObject->JobGet(
    ID => $JobID
);
$Self->IsDeeply(
    $Job{Filter},
    [
        {
            AND => [
                { Field => 'Dummy', Operator => 'EQ', Value => 'this is a test' }
            ]
        },
        {
            AND => [
                { Field => 'Dummy2', Operator => 'EQ', Value => 'this is a test 2' }
            ]
        }
    ],
    'JobGet() for new job with filter list',
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
