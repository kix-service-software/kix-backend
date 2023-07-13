# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));
use Kernel::System::VariableCheck qw(:all);

# get automation object
my $AutomationObject = $Kernel::OM->Get('Automation');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my %TestMacros = ();

# add macros and reference them (7 => 1; 6 => 5; 5 => 4; 4 => 3,2; 2 => 1)
for my $MacroNumber ( 1..7 ) {
    my $MacroID = $AutomationObject->MacroAdd(
        Name    => 'test-macro-' . $MacroNumber,
        Type    => 'Ticket',
        ValidID => 1,
        UserID  => 1,
    );

    $Self->True(
        $MacroID || 0,
        'MacroAdd() for new macro ' . $MacroNumber,
    );

    if ($MacroID) {
        $TestMacros{'test-macro-' . $MacroNumber} = $MacroID;
    }

    next if ($MacroNumber == 3 || $MacroNumber == 1 || $MacroNumber == 7);
    _AddMacroAction(
        MacroID    => $TestMacros{'test-macro-' . $MacroNumber},
        RefMacroID => $TestMacros{'test-macro-' . ($MacroNumber - 1)}
    );
}
_AddMacroAction(
    MacroID    => $TestMacros{'test-macro-4'},
    RefMacroID => $TestMacros{'test-macro-2'}
);
_AddMacroAction(
    MacroID    => $TestMacros{'test-macro-7'},
    RefMacroID => $TestMacros{'test-macro-1'}
);

##### check references ########################################################
# check if some references exists
my @AllSubMacros = $AutomationObject->GetAllSubMacros();
# filter all possible unknown ids (macros not from this test)
@AllSubMacros = $Helper->CombineLists(
    ListA   => \@AllSubMacros,
    ListB   => [values %TestMacros],
);
$Self->True(
    IsArrayRefWithData(\@AllSubMacros) || 0,
    'GetAllSubMacros()',
);
$Self->Is(
    scalar(@AllSubMacros),
    5,
    'GetAllSubMacros() - length',
);
# check if 3 is a sub macro
my $IsSubMacro = $AutomationObject->IsSubMacro( ID => $TestMacros{'test-macro-3'} );
$Self->True(
    $IsSubMacro || 0,
    'IsSubMacro()',
);
# check if 1 is sub macro of 6
my $IsSubMacroOf = $AutomationObject->IsSubMacroOf(
    ID     => $TestMacros{'test-macro-1'},
    IDList => [$TestMacros{'test-macro-6'}]
);
$Self->True(
    $IsSubMacroOf || 0,
    'IsSubMacroOf()',
);
# check sub macros of 4 (all = 3, 2, 1)
my @AllSubMacrosOf = $AutomationObject->GetAllSubMacrosOf( MacroIDs => [$TestMacros{'test-macro-4'}] );
$Self->True(
    IsArrayRefWithData(\@AllSubMacrosOf) || 0,
    'GetAllSubMacrosOf()',
);
$Self->Is(
    scalar(@AllSubMacrosOf),
    3,
    'GetAllSubMacrosOf() - length',
);
# check sub macros of 4 (only chiledren = 3, 2)
my @AllSubMacrosOfChild = $AutomationObject->GetAllSubMacrosOf(
    MacroIDs  => [$TestMacros{'test-macro-4'}],
    Recursive => 0
);
$Self->True(
    IsArrayRefWithData(\@AllSubMacrosOfChild) || 0,
    'GetAllSubMacrosOf() - only children',
);
$Self->Is(
    scalar(@AllSubMacrosOfChild),
    2,
    'GetAllSubMacrosOf() - only children - length',
);

#### delete check ########################################################

# check macro 4 (referenced by 5)
my $IsMacroDeletable4 = $AutomationObject->MacroIsDeletable(
    ID => $TestMacros{'test-macro-4'}
);
$Self->False(
    $IsMacroDeletable4,
    'IsMacroDeletable() - 4 should not be deletable, because 5 references it',
);
my $MacroDelete4 = $AutomationObject->MacroDelete(
    ID => $TestMacros{'test-macro-4'}
);
$Self->False(
    $MacroDelete4,
    'MacroDelete() - 4 should not be deleted, because 5 references it',
);
my $MacroName4 = $AutomationObject->MacroLookup(
    ID => $TestMacros{'test-macro-4'}
);
$Self->True(
    $MacroName4 || 0,
    'MacroLookup() - 4 is still there',
);
my $MacroName3 = $AutomationObject->MacroLookup(
    ID => $TestMacros{'test-macro-3'}
);
$Self->True(
    $MacroName3 || 0,
    'MacroLookup() - 3 is still there',
);

# check macro 6 (not referenced)
my $IsMacroDeletable6 = $AutomationObject->MacroIsDeletable(
    ID => $TestMacros{'test-macro-6'}
);
$Self->True(
    $IsMacroDeletable6 || 0,
    'IsMacroDeletable() - 6 should be deletable',
);
my $MacroDelete6 = $AutomationObject->MacroDelete(
    ID => $TestMacros{'test-macro-6'}
);
$Self->True(
    $MacroDelete6 || 0,
    'MacroDelete() - 6 should be deleted',
);
my $MacroName6 = $AutomationObject->MacroLookup(
    ID => $TestMacros{'test-macro-6'}
);
$Self->False(
    $MacroName6,
    'MacroLookup() - 6 is gone',
);
my $MacroName4_2nd = $AutomationObject->MacroLookup(
    ID => $TestMacros{'test-macro-4'}
);
$Self->False(
    $MacroName4_2nd,
    'MacroLookup() - 4 is gone too, (deletion was recursive)',
);
my $MacroName1 = $AutomationObject->MacroLookup(
    ID => $TestMacros{'test-macro-1'}
);
$Self->True(
    $MacroName1 || 0,
    'MacroLookup() - 1 should not be deleted, because 7 references it',
);
@AllSubMacros = $AutomationObject->GetAllSubMacros();
@AllSubMacros = $Helper->CombineLists(
    ListA   => \@AllSubMacros,
    ListB   => [values %TestMacros],
);
$Self->Is(
    scalar(@AllSubMacros),
    1,
    'GetAllSubMacros() - length after deletion of 6',
);

# check macro 7
my %MacroActionsOf7 = $AutomationObject->MacroActionList(
    MacroID => $TestMacros{'test-macro-7'}
);
$Self->True(
    IsHashRefWithData(\%MacroActionsOf7) || 0,
    'MacroActionList() - 7 has actions',
);
my @MacroActionListOf7 = map {$_} keys %MacroActionsOf7;
$Self->Is(
    scalar(@MacroActionListOf7),
    1,
    'MacroActionList() - 7 has one action',
);
my $IsMacroDeletable7 = $AutomationObject->MacroIsDeletable(
    ID => $TestMacros{'test-macro-7'}
);
$Self->True(
    $IsMacroDeletable7 || 0,
    'IsMacroDeletable() - 7 should be deletable',
);
my $MacroDelete7 = $AutomationObject->MacroDelete(
    ID => $TestMacros{'test-macro-7'}
);
$Self->True(
    $MacroDelete7 || 0,
    'MacroDelete() - 7 should be deleted',
);
my $MacroName7 = $AutomationObject->MacroLookup(
    ID => $TestMacros{'test-macro-7'}
);
$Self->False(
    $MacroName7,
    'MacroLookup() - 7 is gone',
);
my $MacroName1_2nd = $AutomationObject->MacroLookup(
    ID => $TestMacros{'test-macro-1'}
);
$Self->False(
    $MacroName1_2nd,
    'MacroLookup() - 1 is gone, too (deletion was recursive)',
);
@AllSubMacros = $AutomationObject->GetAllSubMacros();
@AllSubMacros = $Helper->CombineLists(
    ListA   => \@AllSubMacros,
    ListB   => [values %TestMacros],
);
$Self->Is(
    scalar(@AllSubMacros),
    0,
    'GetAllSubMacros() - length after deletion of 7',
);
%MacroActionsOf7 = $AutomationObject->MacroActionList(
    MacroID => $TestMacros{'test-macro-7'}
);
$Self->True(
    !IsHashRefWithData(\%MacroActionsOf7),
    'MacroActionList() - action of 7 is gone, too',
);

#### check ignore param
my $IgnoreMacroID = $AutomationObject->MacroAdd(
    Name    => 'test-macro-ignore',
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $IgnoreMacroID || 0,
    'MacroAdd() for new macro (ignore)'
);
my $IsIgnoreMacroDeletable = $AutomationObject->MacroIsDeletable(
    ID => $IgnoreMacroID
);
$Self->True(
    $IsIgnoreMacroDeletable,
    'IsMacroDeletable() - macro (ignore) should be deletable',
);
# set ignore param
$AutomationObject->{IgnoreMacroIDsForDelete} = [$IgnoreMacroID];
my $IsIgnoreMacroDeletable = $AutomationObject->MacroIsDeletable(
    ID => $IgnoreMacroID
);
$Self->False(
    $IsIgnoreMacroDeletable,
    'IsMacroDeletable() - macro (ignore) should NOT be deletable anymore',
);

# check with sub
my $IgnoreMacroID_Sub = $AutomationObject->MacroAdd(
    Name    => 'test-macro-ignore-sub',
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $IgnoreMacroID_Sub || 0,
    'MacroAdd() for new macro (ignore sub)'
);
_AddMacroAction(
    MacroID    => $IgnoreMacroID,
    RefMacroID => $IgnoreMacroID_Sub
);
my $IsSubMacroOfIgnore = $AutomationObject->IsSubMacroOf(
    ID     => $IgnoreMacroID_Sub,
    IDList => [$IgnoreMacroID]
);
$Self->True(
    $IsSubMacroOfIgnore || 0,
    'IsSubMacroOf() - ignore',
);
# set ignore param
$AutomationObject->{IgnoreMacroIDsForDelete} = [$IgnoreMacroID_Sub];
my $IsIgnoreMacroDeletable_2nd = $AutomationObject->MacroIsDeletable(
    ID => $IgnoreMacroID
);
$Self->True(
    $IsIgnoreMacroDeletable_2nd,
    'IsMacroDeletable() - macro (ignore) should be deletable again',
);
my $IgnoreMacroDelete = $AutomationObject->MacroDelete(
    ID => $IgnoreMacroID
);
$Self->True(
    $IgnoreMacroDelete || 0,
    'MacroDelete() - ignore macro (parent) should be deleted',
);
my $IgnoreMacroName = $AutomationObject->MacroLookup(
    ID => $IgnoreMacroID
);
$Self->False(
    $IgnoreMacroName,
    'MacroLookup() - ingore macro (parent) is gone',
);
my $IgnoreMacroName_Sub = $AutomationObject->MacroLookup(
    ID => $IgnoreMacroID_Sub
);
$Self->True(
    $IgnoreMacroName_Sub || 0,
    'MacroLookup() - sub ingore macro (child) is still there',
);

# clean up
delete $AutomationObject->{IgnoreMacroIDsForDelete};
my $IgnoreMacroDelete_Sub = $AutomationObject->MacroDelete(
    ID => $IgnoreMacroID_Sub
);
$Self->True(
    $IgnoreMacroDelete_Sub || 0,
    'MacroDelete() - sub ignore macro (child) shoukd be deleted',
);

#### some negativ checks ########################################################
%TestMacros = ();
for my $MacroNumber ( 1..2 ) {
    my $MacroID = $AutomationObject->MacroAdd(
        Name    => 'test-macro-' . $MacroNumber,
        Type    => 'Ticket',
        ValidID => 1,
        UserID  => 1,
    );

    $Self->True(
        $MacroID || 0,
        'MacroAdd() for new macro ' . $MacroNumber,
    );

    if ($MacroID) {
        $TestMacros{'test-macro-' . $MacroNumber} = $MacroID;
    }
}
# reference to unknown
_AddMacroAction(
    MacroID    => $TestMacros{'test-macro-1'},
    RefMacroID => 999999
);
my %MacroActionsOf1 = $AutomationObject->MacroActionList(
    MacroID => $TestMacros{'test-macro-1'}
);
$Self->True(
    !IsHashRefWithData(\%MacroActionsOf1),
    'MacroActionList() - 1 should have no actions',
);
# reference to itself
_AddMacroAction(
    MacroID    => $TestMacros{'test-macro-1'},
    RefMacroID => $TestMacros{'test-macro-1'}
);
%MacroActionsOf1 = $AutomationObject->MacroActionList(
    MacroID => $TestMacros{'test-macro-1'}
);
$Self->True(
    !IsHashRefWithData(\%MacroActionsOf1),
    'MacroActionList() - 1 should have no actions',
);
# reference to parent
_AddMacroAction(
    MacroID    => $TestMacros{'test-macro-1'},
    RefMacroID => $TestMacros{'test-macro-2'}
);
%MacroActionsOf1 = $AutomationObject->MacroActionList(
    MacroID => $TestMacros{'test-macro-1'}
);
$Self->True(
    IsHashRefWithData(\%MacroActionsOf1) || 0,
    'MacroActionList() - 1 should have the new actions',
);
_AddMacroAction(
    MacroID    => $TestMacros{'test-macro-2'},
    RefMacroID => $TestMacros{'test-macro-1'}
);
my %MacroActionsOf2 = $AutomationObject->MacroActionList(
    MacroID => $TestMacros{'test-macro-2'}
);
# clean up
my $NegativeMacroDelete1 = $AutomationObject->MacroDelete(
    ID => $TestMacros{'test-macro-1'}
);
$Self->True(
    $NegativeMacroDelete1 || 0,
    'MacroDelete() - 1 should be deleted',
);
my $NegativeMacroName1 = $AutomationObject->MacroLookup(
    ID => $TestMacros{'test-macro-1'}
);
$Self->False(
    $NegativeMacroName1,
    'MacroLookup() - 1 is gone',
);
my $NegativeMacroName2 = $AutomationObject->MacroLookup(
    ID => $TestMacros{'test-macro-2'}
);
$Self->False(
    $NegativeMacroName2,
    'MacroLookup() - 2 is gone, too',
);

#### job tests ########################################################
my %TestJobs= ();
# add macro
my $JobMacroID = $AutomationObject->MacroAdd(
    Name    => 'test-macro-for-jobs',
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $JobMacroID || 0,
    'MacroAdd() for jobs',
);
# add exec plan
my $JobExecPlanID = $AutomationObject->ExecPlanAdd(
    Name    => 'test-exec-pan-for-jobs',
    Type    => 'EventBased',
    Parameters => {
        Event => [ 'TicketCreate' ]
    },
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $JobExecPlanID || 0,
    'ExecPlanAdd() for jobs',
);
# add jobs
for my $Number ( 1..2 ) {
    my $ID = $AutomationObject->JobAdd(
        Name    => 'test-job-' . $Number,
        Type    => 'Ticket',
        ValidID => 1,
        UserID  => 1,
    );

    $Self->True(
        $ID || 0,
        'JobAdd() for new job ' . $Number,
    );

    if ($ID) {
        $TestMacros{'test-job-' . $Number} = $ID;

        # reference macro
        my $Result = $AutomationObject->JobMacroAdd(
            JobID   => $ID,
            MacroID => $JobMacroID,
            UserID  => 1
        );
        my @JobMacroIDs = $AutomationObject->JobMacroList(
            JobID => $ID
        );
        $Self->True(
            IsArrayRefWithData(\@JobMacroIDs) || 0,
            'JobMacroList() - of job ' . $Number,
        );
        $Self->Is(
            scalar(@JobMacroIDs),
            1,
            'JobMacroList() - length',
        );
        $Self->Is(
            $JobMacroIDs[0],
            $JobMacroID,
            'JobMacroList() - is right id',
        );

        # reference exec plan
        my $Result = $AutomationObject->JobExecPlanAdd(
            JobID      => $ID,
            ExecPlanID => $JobExecPlanID,
            UserID     => 1
        );
        my @JobExecPlanIDs = $AutomationObject->JobExecPlanList(
            JobID => $ID
        );
        $Self->True(
            IsArrayRefWithData(\@JobExecPlanIDs) || 0,
            'JobExecPlanList() - of job ' . $Number,
        );
        $Self->Is(
            scalar(@JobExecPlanIDs),
            1,
            'JobExecPlanList() - length',
        );
        $Self->Is(
            $JobExecPlanIDs[0],
            $JobExecPlanID,
            'JobMacroList() - is right id',
        );
    }
}
# try to delete macro and exec plan
my $IsJobMacroDeletable = $AutomationObject->MacroIsDeletable(
    ID => $JobMacroID
);
$Self->False(
    $IsJobMacroDeletable,
    'IsMacroDeletable() - job macro should not be deletable, because it is referenced',
);
my $IsJobExecPlanDeletable = $AutomationObject->ExecPlanIsDeletable(
    ID => $JobExecPlanID
);
$Self->False(
    $IsJobExecPlanDeletable,
    'ExecPlanIsDeletable() - job exec plan should not be deletable, because it is referenced',
);
# delete job 1
my $JobDelete1 = $AutomationObject->JobDelete(
    ID => $TestMacros{'test-job-1'},
);
$Self->True(
    $JobDelete1 || 0,
    'JobDelete() - of job 1',
);
my $JobMacroName = $AutomationObject->MacroLookup(
    ID => $JobMacroID
);
$Self->True(
    $JobMacroName || 0,
    'MacroLookup() - job macro is still there (referenced by 2, too)',
);
my $JobExecPlanName = $AutomationObject->ExecPlanLookup(
    ID => $JobExecPlanID
);
$Self->True(
    $JobExecPlanName || 0,
    'ExecPlanLookup() - job exec plan is still there (referenced by 2, too)',
);
# delete job 2
my $JobDelete2 = $AutomationObject->JobDelete(
    ID => $TestMacros{'test-job-2'},
);
$Self->True(
    $JobDelete2 || 0,
    'JobDelete() - of job 2',
);
my $JobMacroName_2nd = $AutomationObject->MacroLookup(
    ID => $JobMacroID
);
$Self->False(
    $JobMacroName_2nd,
    'MacroLookup() - job macro is gone',
);
my $JobExecPlanName_2nd = $AutomationObject->ExecPlanLookup(
    ID => $JobExecPlanID
);
$Self->False(
    $JobExecPlanName_2nd,
    'ExecPlanLookup() - job exec plan is gone',
);

#### helper functions
sub _AddMacroAction {
    my ( %Param ) = @_;

    my $MacroActionID = $AutomationObject->MacroActionAdd(
        MacroID => $Param{MacroID},
        Type    => 'ExecuteMacro',
        Parameters => { MacroID => $Param{RefMacroID} },
        ValidID => 1,
        UserID  => 1,
    );
}

# cleanup is done by RestoreDatabase

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
