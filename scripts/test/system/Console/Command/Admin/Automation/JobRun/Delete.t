# --
# Modified version of the work: Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

my $CommandObject = $Kernel::OM->Get('Console::Command::Admin::Automation::JobRun::Delete');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# silence console output
local *STDOUT;
local *STDERR;
open STDOUT, '>>', "/dev/null";
open STDERR, '>>', "/dev/null";

my $ExitCode = $CommandObject->Execute();

$Self->Is(
    $ExitCode,
    1,
    "Admin::Automation::JobRun::Delete exit code without options",
);

# check command with options --all-jobs (missing runs-options)
$ExitCode = $CommandObject->Execute( '--all-jobs' );
$Self->Is(
    $ExitCode,
    1,
    "Option '--all-jobs' (missing runs-options)",
);

# check command with options --all-runs (missing jobs-options)
$ExitCode = $CommandObject->Execute( '--all-runs' );
$Self->Is(
    $ExitCode,
    1,
    "Option '--all-runs' (missing jobs-options)",
);

# check command with options --job-id 9990 --all-runs (invalid jobs-options)
$ExitCode = $CommandObject->Execute( '--job-id', '9999', '--all-runs' );
$Self->Is(
    $ExitCode,
    1,
    "Options '--job-id 9999 --all-runs' (invalid jobs-options)",
);

# set fixed time to have predetermined verifiable results
my $SystemTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
    String => '2014-01-01 12:00:00',
);
$Helper->FixedTimeSet($SystemTime);
my $JobName1 = 'UnitTest1';
my $JobID1   = $Kernel::OM->Get('Automation')->JobAdd(
    Name    => $JobName1,
    Type    => 'Synchronisation',
    ValidID => 1,
    UserID  => 1,
    Silent  => 1,
);
$Self->True(
    $JobID1,
    'Created first job'
);
my $JobName2 = 'UnitTest2';
my $JobID2   = $Kernel::OM->Get('Automation')->JobAdd(
    Name    => $JobName2,
    Type    => 'Synchronisation',
    ValidID => 1,
    UserID  => 1,
    Silent  => 1,
);
$Self->True(
    $JobID2,
    'Created second job'
);
my $JobRunID1_1 = $Kernel::OM->Get('Automation')->JobExecute(
    ID     => $JobID1,
    UserID => 1
);
$Self->True(
    $JobRunID1_1,
    'First job run for first job executed'
);
my $JobRunID2_1 = $Kernel::OM->Get('Automation')->JobExecute(
    ID     => $JobID2,
    UserID => 1
);
$Self->True(
    $JobRunID2_1,
    'First job run for second job executed'
);
$Helper->FixedTimeAddSeconds(86400);
my $JobRunID1_2 = $Kernel::OM->Get('Automation')->JobExecute(
    ID     => $JobID1,
    UserID => 1
);
$Self->True(
    $JobRunID1_2,
    'Second job run for first job executed'
);
my $JobRunID2_2 = $Kernel::OM->Get('Automation')->JobExecute(
    ID     => $JobID2,
    UserID => 1
);
$Self->True(
    $JobRunID2_2,
    'Second job run for second job executed'
);
$Helper->FixedTimeAddSeconds(86400);
my $JobRunID1_3 = $Kernel::OM->Get('Automation')->JobExecute(
    ID     => $JobID1,
    UserID => 1
);
$Self->True(
    $JobRunID1_3,
    'Third job run for first job executed'
);
my $JobRunID2_3 = $Kernel::OM->Get('Automation')->JobExecute(
    ID     => $JobID2,
    UserID => 1
);
$Self->True(
    $JobRunID2_3,
    'Third job run for second job executed'
);
$Helper->FixedTimeAddSeconds(1);

my @Tests = (
    {
        'Name'      => 'No runs to remove',
        'Parameter' => [ '--all-jobs', '--older-than-days', '3'],
        'Expected'  => [
            $JobRunID1_1,
            $JobRunID2_1,
            $JobRunID1_2,
            $JobRunID2_2,
            $JobRunID1_3,
            $JobRunID2_3
        ]
    },
    {
        'Name'      => 'Remove oldest run on first job',
        'Parameter' => [ '--job-id', $JobID1, '--older-than-days', '2'],
        'Expected'  => [
            $JobRunID2_1,
            $JobRunID1_2,
            $JobRunID2_2,
            $JobRunID1_3,
            $JobRunID2_3
        ]
    },
    {
        'Name'      => 'Remove older runs on first and second job',
        'Parameter' => [ '--job-id', $JobID1, '--job-id', $JobID2, '--older-than-days', '1'],
        'Expected'  => [
            $JobRunID1_3,
            $JobRunID2_3
        ]
    },
    {
        'Name'      => 'Remove all runs on second job',
        'Parameter' => [ '--job-id', $JobID2, '--all-runs'],
        'Expected'  => [
            $JobRunID1_3
        ]
    },
    {
        'Name'      => 'Remove all runs on all jobs',
        'Parameter' => [ '--all-jobs', '--all-runs'],
        'Expected'  => []
    }
);

for my $Test ( @Tests ) {
    $ExitCode = $CommandObject->Execute( @{ $Test->{Parameter} } );
    $Self->Is(
        $ExitCode,
        0,
        $Test->{Name} . ': Execution successful',
    );

    my @JobRunIDs = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Automation_JobRun',
        Result     => 'ARRAY',
        Search     => {
            'AND' => [
                {
                    Field    => 'JobID',
                    Operator => 'IN',
                    Value    => [$JobID1,$JobID2]
                }
            ]
        },
        UserType   => 'Agent',
        UserID     => 1
    );
    $Self->IsDeeply(
        \@JobRunIDs,
        $Test->{Expected},
        $Test->{Name} . ': Expected run list',
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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
