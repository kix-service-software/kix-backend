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

# get ExecPlan object
my $AutomationObject = $Kernel::OM->Get('Automation');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my $NameRandom  = $Helper->GetRandomID();
my %ExecPlanIDByExecPlanName = (
    'test-execplan-' . $NameRandom . '-1' => undef,
    'test-execplan-' . $NameRandom . '-2' => undef,
    'test-execplan-' . $NameRandom . '-3' => undef,
);

# try to add execplans
for my $ExecPlanName ( sort keys %ExecPlanIDByExecPlanName ) {
    my $ExecPlanID = $AutomationObject->ExecPlanAdd(
        Name    => $ExecPlanName,
        Type    => 'EventBased',
        Parameters => {
            Event => [ 'TicketCreate' ]
        },
        ValidID => 1,
        UserID  => 1,
    );

    $Self->True(
        $ExecPlanID,
        'ExecPlanAdd() for new execution plan ' . $ExecPlanName,
    );

    if ($ExecPlanID) {
        $ExecPlanIDByExecPlanName{$ExecPlanName} = $ExecPlanID;
    }
}

# try to add already added execplans
for my $ExecPlanName ( sort keys %ExecPlanIDByExecPlanName ) {
    my $ExecPlanID = $AutomationObject->ExecPlanAdd(
        Name    => $ExecPlanName,
        Type    => 'EventBased',
        Parameters  => {
            Event => [ 'TicketCreate' ]
        },
        ValidID => 1,
        UserID  => 1,
        Silent  => 1
    );

    $Self->False(
        $ExecPlanID,
        'ExecPlanAdd() for already existing ExecPlan ' . $ExecPlanName,
    );
}

# try to fetch data of existing ExecPlans
for my $ExecPlanName ( sort keys %ExecPlanIDByExecPlanName ) {
    my $ExecPlanID = $ExecPlanIDByExecPlanName{$ExecPlanName};
    my %ExecPlan = $AutomationObject->ExecPlanGet( ID => $ExecPlanID );

    $Self->Is(
        $ExecPlan{Name},
        $ExecPlanName,
        'ExecPlanGet() for ExecPlan ' . $ExecPlanName,
    );
}

# look up existing ExecPlans
for my $ExecPlanName ( sort keys %ExecPlanIDByExecPlanName ) {
    my $ExecPlanID = $ExecPlanIDByExecPlanName{$ExecPlanName};

    my $FetchedExecPlanID = $AutomationObject->ExecPlanLookup( Name => $ExecPlanName );
    $Self->Is(
        $FetchedExecPlanID,
        $ExecPlanID,
        'ExecPlanLookup() for execution plan name ' . $ExecPlanName,
    );

    my $FetchedExecPlanName = $AutomationObject->ExecPlanLookup( ID => $ExecPlanID );
    $Self->Is(
        $FetchedExecPlanName,
        $ExecPlanName,
        'ExecPlanLookup() for execution plan ID ' . $ExecPlanID,
    );
}

# list ExecPlans
my %ExecPlans = $AutomationObject->ExecPlanList();
for my $ExecPlanName ( sort keys %ExecPlanIDByExecPlanName ) {
    my $ExecPlanID = $ExecPlanIDByExecPlanName{$ExecPlanName};

    $Self->True(
        exists $ExecPlans{$ExecPlanID} && $ExecPlans{$ExecPlanID} eq $ExecPlanName,
        'ExecPlanList() contains execution plan ' . $ExecPlanName . ' with ID ' . $ExecPlanID,
    );
}

# change name of a single ExecPlan
my $ExecPlanNameToChange = 'test-execplan-' . $NameRandom . '-1';
my $ChangedExecPlanName  = $ExecPlanNameToChange . '-changed';
my $ExecPlanIDToChange   = $ExecPlanIDByExecPlanName{$ExecPlanNameToChange};

my %ExecPlan = $AutomationObject->ExecPlanGet(
    ID => $ExecPlanIDToChange
);

$AutomationObject->ExecPlanUpdate(
    ID      => $ExecPlanIDToChange,
    %ExecPlan,
    Name    => $ChangedExecPlanName,
    UserID  => 1,
);

my $ExecPlanUpdateResult = $AutomationObject->ExecPlanLookup(
    Name => $ChangedExecPlanName,
);

$Self->True(
    $ExecPlanUpdateResult,
    'ExecPlanUpdate() for changing name of execution plan ' . $ExecPlanNameToChange . ' to ' . $ChangedExecPlanName,
);

# fetches current data of the ExecPlan with new name
%ExecPlan = $AutomationObject->ExecPlanGet(
    ID => $ExecPlanIDToChange
);

# update parameters of a single ExecPlan
$ExecPlanUpdateResult = $AutomationObject->ExecPlanUpdate(
    ID      => $ExecPlanIDToChange,
    %ExecPlan,
    Parameters => {
        Event => [ 'ArticleCreate ']
    },
    ValidID => 1,
    UserID  => 1,
);

my %ExecPlanChanged = $AutomationObject->ExecPlanGet( ID => $ExecPlanIDToChange );

$Self->IsNotDeeply(
    \%ExecPlan,
    \%ExecPlanChanged,
    'ExecPlanUpdate() for changing parameters of execution plan.',
);

$ExecPlanIDByExecPlanName{$ChangedExecPlanName} = $ExecPlanIDToChange;
delete $ExecPlanIDByExecPlanName{$ExecPlanNameToChange};

# try to add execution plan with previous name
my $ExecPlanID1 = $AutomationObject->ExecPlanAdd(
    Name    => $ExecPlanNameToChange,
    Type    => 'TimeBased',
    ValidID => 1,
    UserID  => 1,
    Silent  => 1
);

$Self->False(
    $ExecPlanID1,
    'ExecPlanAdd() for new execution plan ' . $ExecPlanNameToChange . ' without config',
);

if ($ExecPlanID1) {
    $ExecPlanIDByExecPlanName{$ExecPlanNameToChange} = $ExecPlanID1;
}

# try to add execution plan with changed name
$ExecPlanID1 = $AutomationObject->ExecPlanAdd(
    Name    => $ChangedExecPlanName,
    Type    => 'EventBased',
    Parameters => {
        Event => [ 'TicketCreate' ]
    },
    ValidID => 1,
    UserID  => 1,
    Silent  => 1
);

$Self->False(
    $ExecPlanID1,
    'ExecPlanAdd() add execution plan with existing name ' . $ChangedExecPlanName,
);

my $ExecPlanName2 = $ChangedExecPlanName . 'update';
my $ExecPlanID2   = $AutomationObject->ExecPlanAdd(
    Name    => $ExecPlanName2,
    Type    => 'EventBased',
    Parameters => {
        Event => [ 'TicketCreate' ]
    },
    ValidID => 1,
    UserID  => 1,
);

$Self->True(
    $ExecPlanID2,
    'ExecPlanAdd() add the second test execution plan ' . $ExecPlanName2,
);

# try to update ExecPlan with existing name
my $ExecPlanUpdateWrong = $AutomationObject->ExecPlanUpdate(
    ID      => $ExecPlanID2,
    Name    => $ChangedExecPlanName,
    ValidID => 2,
    UserID  => 1,
    Silent  => 1
);

$Self->False(
    $ExecPlanUpdateWrong,
    'ExecPlanUpdate() update execution plan with existing name ' . $ChangedExecPlanName,
);

# delete an existing execplan
my $ExecPlanDelete = $AutomationObject->ExecPlanDelete(
    ID      => $ExecPlanIDToChange,
    UserID  => 1,
);

$Self->True(
    $ExecPlanDelete,
    'ExecPlanDelete() delete existing execplan',
);

# delete a non existent execplan
$ExecPlanDelete = $AutomationObject->ExecPlanDelete(
    ID      => 9999,
    UserID  => 1,
    Silent  => 1
);

$Self->False(
    $ExecPlanDelete,
    'ExecPlanDelete() delete non existent execplan',
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
