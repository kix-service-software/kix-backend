# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Automation::Job;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'Cache',
    'DB',
    'Log',
    'User',
    'Valid',
);

=head1 NAME

Kernel::System::Automation::Job - job extension for automation lib

=head1 SYNOPSIS

All job functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item JobLookup()

get id for job name

    my $JobID = $AutomationObject->JobLookup(
        Name => '...',
    );

get name for job id

    my $JobName = $AutomationObject->JobLookup(
        ID => '...',
    );

=cut

sub JobLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Name} && !$Param{ID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Got no Name or ID!',
        );
        return;
    }

    # get job list
    my %JobList = $Self->JobList(
        Valid => 0,
    );

    return $JobList{ $Param{ID} } if $Param{ID};

    # create reverse list
    my %JobListReverse = reverse %JobList;

    return $JobListReverse{ $Param{Name} };
}

=item JobGet()

returns a hash with the job data

    my %JobData = $AutomationObject->JobGet(
        ID => 2,
    );

This returns something like:

    %JobData = (
        'ID'                => 2,
        'Type'              => 'Ticket',
        'Name'              => 'Test',
        'Filter'            => {},
        'Comment'           => '...',
        'LastExecutionTime' => '2019-10-21 12:00:00',
        'ValidID'           => '1',
        'CreateTime'        => '2010-04-07 15:41:15',
        'CreateBy'          => 1,
        'ChangeTime'        => '2010-04-07 15:41:15',
        'ChangeBy'          => 1
    );

=cut

sub JobGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need ID!'
        );
        return;
    }

    # check cache
    my $CacheKey = 'JobGet::' . $Param{ID};
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;
    
    return if !$Kernel::OM->Get('DB')->Prepare( 
        SQL   => "SELECT id, name, type, filter, comments, valid_id, last_exec_time, create_time, create_by, change_time, change_by FROM job WHERE id = ?",
        Bind => [ \$Param{ID} ],
    );

    my %Result;
    
    # fetch the result
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        %Result = (
            ID                => $Row[0],
            Name              => $Row[1],
            Type              => $Row[2],
            Filter            => $Row[3],
            Comment           => $Row[4],
            ValidID           => $Row[5],
            LastExecutionTime => $Row[6],
            CreateTime        => $Row[7],
            CreateBy          => $Row[8],
            ChangeTime        => $Row[9],
            ChangeBy          => $Row[10],
        );

        if ( $Result{Filter} ) {
            # decode JSON
            $Result{Filter} = $Kernel::OM->Get('JSON')->Decode(
                Data => $Result{Filter}
            );
        }
    }
    
    # no data found...
    if ( !%Result ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Job with ID $Param{ID} not found!",
        );
        return;
    }
    
    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Result,
    ); 

    return %Result;
}

=item JobAdd()

adds a new job

    my $ID = $AutomationObject->JobAdd(
        Name       => 'test',
        Type       => 'Ticket',
        Filter     => {                                         # optional
            Queue => [ 'SomeQueue' ],
        },
        Comment    => '...',                                    # optional
        ValidID    => 1,                                        # optional
        UserID     => 123,
    );

=cut

sub JobAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Name Type UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    if ( !defined $Param{ValidID} ) {
        $Param{ValidID} = 1;
    }

    # check if this is a duplicate after the change
    my $ID = $Self->JobLookup( 
        Name => $Param{Name},
    );
    if ( $ID ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "A job with the same name already exists.",
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # prepare filter as JSON
    my $Filter;
    if ( $Param{Filter} ) {
        $Filter = $Kernel::OM->Get('JSON')->Encode(
            Data => $Param{Filter}
        );
    }

    # insert
    return if !$DBObject->Do(
        SQL => 'INSERT INTO job (name, type, filter, comments, valid_id, create_time, create_by, change_time, change_by) '
             . 'VALUES (?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Name}, \$Param{Type}, \$Filter, \$Param{Comment}, \$Param{ValidID}, \$Param{UserID}, \$Param{UserID}
        ],
    );

    # get new id
    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM job WHERE name = ?',
        Bind => [ 
            \$Param{Name}, 
        ],
    );

    # fetch the result
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ID = $Row[0];
    }

    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp();

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'Job',
        ObjectID  => $ID,
    );

    return $ID;
}

=item JobUpdate()

updates a job

    my $Success = $AutomationObject->JobUpdate(
        ID         => 123,
        Name       => 'test'
        Type       => 'Ticket',                                 # optional
        Filter     => {                                         # optional
            Queue => [ 'SomeQueue' ],
        },
        Comment    => '...',                                    # optional
        ValidID    => 1,                                        # optional
        UserID     => 123,
    );

=cut

sub JobUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    # get current data
    my %Data = $Self->JobGet(
        ID => $Param{ID},
    );

    # check if this is a duplicate after the change
    my $ID = $Self->JobLookup( 
        Name => $Param{Name} || $Data{Name},
    );
    if ( $ID && $ID != $Param{ID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "A job with the same name already exists.",
        );
        return;
    }

    # set default value
    $Param{Comment} ||= '';

    # check if update is required
    my $ChangeRequired;
    KEY:
    for my $Key ( qw(Type Name Filter Comment ValidID) ) {

        next KEY if defined $Data{$Key} && $Data{$Key} eq $Param{$Key};

        $ChangeRequired = 1;

        last KEY;
    }

    return 1 if !$ChangeRequired;

    $Param{Type} ||= $Data{Type};

    # prepare filter as JSON
    my $Filter;
    if ( $Param{Filter} ) {
        $Filter = $Kernel::OM->Get('JSON')->Encode(
            Data => $Param{Filter}
        );
    }

    # update Job in database
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE job SET type = ?, name = ?, filter = ?, comments = ?, valid_id = ?, change_time = current_timestamp, change_by = ? WHERE id = ?',
        Bind => [
            \$Param{Type}, \$Param{Name}, \$Filter, \$Param{Comment}, \$Param{ValidID}, \$Param{UserID}, \$Param{ID}
        ],
    );

    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp();

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Job',
        ObjectID  => $Param{ID},
    );

    return 1;
}

=item JobList()

returns a hash of all jobs

    my %Jobs = $AutomationObject->JobList(
        Valid => 1          # optional
    );

the result looks like

    %Jobs = (
        1 => 'test',
        2 => 'dummy',
        3 => 'domesthing'
    );

=cut

sub JobList {
    my ( $Self, %Param ) = @_;

    # set default value
    my $Valid = $Param{Valid} ? 1 : 0;

    # create cache key
    my $CacheKey = 'JobList::' . $Valid;

    # read cache
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    my $SQL = 'SELECT id, name FROM job';

    if ( $Param{Valid} ) {
        $SQL .= ' WHERE valid_id = 1'
    }

    return if !$Kernel::OM->Get('DB')->Prepare( 
        SQL => $SQL
    );

    my %Result;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        $Result{$Row[0]} = $Row[1];
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        Key   => $CacheKey,
        Value => \%Result,
        TTL   => $Self->{CacheTTL},
    );

    return %Result;
}

=item JobDelete()

deletes a job

    my $Success = $AutomationObject->JobDelete(
        ID => 123,
    );

=cut

sub JobDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check if this job exists
    my $ID = $Self->JobLookup( 
        ID => $Param{ID},
    );
    if ( !$ID ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "A job with the ID $Param{ID} does not exist.",
        );
        return;
    }

    # delete relations with ExecPlans
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'DELETE FROM job_exec_plan WHERE job_id = ?',
        Bind => [ \$Param{ID} ],
    );

    # delete relations with Macros
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'DELETE FROM job_macro WHERE job_id = ?',
        Bind => [ \$Param{ID} ],
    );

    # remove from database
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'DELETE FROM job WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );
   
    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp();

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Job',
        ObjectID  => $Param{ID},
    );

    return 1;

}

=item JobMacroList()

returns a list of all Macro ids assigned to given Job

    my @MacroIDs = $AutomationObject->JobMacroList(
        ID => 123
    );

=cut

sub JobMacroList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(JobID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    return if !$Kernel::OM->Get('DB')->Prepare( 
        SQL   => 'SELECT macro_id FROM job_macro WHERE job_id = ?',
        Bind => [ \$Param{JobID} ],
    );

    my @Result;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        push(@Result, $Row[0]);
    }

    return @Result;
}

=item JobMacroAdd()

assigns a Macro to a Job

    my $Result = $AutomationObject->JobMacroAdd(
        JobID    => 123,
        MacroID  => 321,
        UserID   => 123
    );

=cut

sub JobMacroAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(JobID MacroID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    my $JobName = $Self->JobLookup(
        ID => $Param{JobID},
    );
    if ( !$JobName) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Cannot assign Macro to Job. A Job with ID $Param{JobID} does not exists.",
        );
        return;
    }

    my $MacroName = $Self->MacroLookup(
        ID => $Param{MacroID},
    );
    if ( !$MacroName) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Cannot assign Macro to Job. A Macro with ID $Param{MacroID} does not exists.",
        );
        return;
    }

    my @MacroIDs = $Self->JobMacroList(
        JobID => $Param{JobID},
    );
    my %MacroIDs = map { $_ => $_ } @MacroIDs;
    
    if ( !$MacroIDs{$Param{MacroID}} ) {

        # insert
        return if !$Kernel::OM->Get('DB')->Do(
            SQL => 'INSERT INTO job_macro (job_id, macro_id, create_time, create_by, change_time, change_by) '
                . 'VALUES (?, ?, current_timestamp, ?, current_timestamp, ?)',
            Bind => [
                \$Param{JobID}, \$Param{MacroID}, \$Param{UserID}, \$Param{UserID}
            ],
        );

        # delete whole cache
        $Kernel::OM->Get('Cache')->CleanUp();

        # push client callback event
        $Kernel::OM->Get('ClientRegistration')->NotifyClients(
            Event     => 'CREATE',
            Namespace => 'Job.Macro',
            ObjectID  => $Param{JobID}.'::'.$Param{MacroID},
        );
    }

    return 1;
}

=item JobMacroDelete()

unassigns a Macro from a Job

    my $Success = $AutomationObject->JobMacroDelete(
        JobID   => 123,
        MacroID => 312,
    );

=cut

sub JobMacroDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(JobID MacroID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # remove from database
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'DELETE FROM job_macro WHERE job_id = ? AND macro_id = ?',
        Bind => [ \$Param{JobID}, \$Param{MacroID} ],
    );
   
    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp();

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Job.Macro',
        ObjectID  => $Param{JobID}.'::'.$Param{MacroID},
    );

    return 1;

}

=item JobExecPlanList()

returns a list of all ExecPlan ids assigned to given Job

    my @ExecPlanIDs = $AutomationObject->JobExecPlanList(
        JobID => 123
    );

=cut

sub JobExecPlanList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(JobID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    return if !$Kernel::OM->Get('DB')->Prepare( 
        SQL   => 'SELECT exec_plan_id FROM job_exec_plan WHERE job_id = ?',
        Bind => [ \$Param{JobID} ],
    );

    my @Result;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        push(@Result, $Row[0]);
    }

    return @Result;
}

=item JobExecPlanAdd()

assigns a ExecPlan to a Job

    my $Result = $AutomationObject->JobExecPlanAdd(
        JobID      => 123,
        ExecPlanID => 321,
        UserID     => 123
    );

=cut

sub JobExecPlanAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(JobID ExecPlanID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    my $JobName = $Self->JobLookup(
        ID => $Param{JobID},
    );
    if ( !$JobName) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Cannot assign ExecPlan to Job. A Job with ID $Param{JobID} does not exists.",
        );
        return;
    }

    my $ExecPlanName = $Self->ExecPlanLookup(
        ID => $Param{ExecPlanID},
    );
    if ( !$ExecPlanName) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Cannot assign ExecPlan to Job. A ExecPlan with ID $Param{ExecPlanID} does not exists.",
        );
        return;
    }

    my @ExecPlanIDs = $Self->JobExecPlanList(
        JobID => $Param{JobID},
    );
    my %ExecPlanIDs = map { $_ => $_ } @ExecPlanIDs;
    
    if ( !$ExecPlanIDs{$Param{ExecPlanID}} ) {

        # insert
        return if !$Kernel::OM->Get('DB')->Do(
            SQL => 'INSERT INTO job_exec_plan (job_id, exec_plan_id, create_time, create_by, change_time, change_by) '
                . 'VALUES (?, ?, current_timestamp, ?, current_timestamp, ?)',
            Bind => [
                \$Param{JobID}, \$Param{ExecPlanID}, \$Param{UserID}, \$Param{UserID}
            ],
        );

        # delete whole cache
        $Kernel::OM->Get('Cache')->CleanUp();

        # push client callback event
        $Kernel::OM->Get('ClientRegistration')->NotifyClients(
            Event     => 'CREATE',
            Namespace => 'Job.ExecPlan',
            ObjectID  => $Param{JobID}.'::'.$Param{ExecPlanID},
        );
    }

    return 1;
}

=item JobExecPlanDelete()

unassigns a ExecPlan from a Job

    my $Success = $AutomationObject->JobExecPlanDelete(
        JobID      => 123,
        ExecPlanID => 312,
    );

=cut

sub JobExecPlanDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(JobID ExecPlanID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # remove from database
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'DELETE FROM job_exec_plan WHERE job_id = ? AND exec_plan_id = ?',
        Bind => [ \$Param{JobID}, \$Param{ExecPlanID} ],
    );
   
    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp();

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Job.ExecPlan',
        ObjectID  => $Param{JobID}.'::'.$Param{ExecPlanID},
    );

    return 1;
}

=item JobIsExecutable()

checks if a job is executable. Return 0 or 1.

    my $Result = $AutomationObject->JobIsExecutable(
        ID       => 123,        # the ID of the job
        UserID    => 1
        ...
    );

=cut

sub JobIsExecutable {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my @ExecPlanList = $Self->JobExecPlanList(
        JobID => $Param{ID}
    );

    my $CanExecute = 0;
    foreach my $ExecPlanID ( @ExecPlanList ) {
        $CanExecute = $Self->ExecPlanCheck(
            %Param,
            JobID => $Param{ID},
            ID    => $ExecPlanID,
        );
        last if $CanExecute;
    }

    return $CanExecute;
}

=item JobExecute()

executes a job

    my $Success = $AutomationObject->JobExecute(
        ID        => 123,       # the ID of the job
        Data      => {},        # optional, contains the relevant data given by an event or otherwise
        UserID    => 1
    );

=cut

sub JobExecute {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # add JobID for log reference
    $Self->{JobID} = $Param{ID};

    # get Job data
    my %Job = $Self->JobGet(
        ID => $Param{ID}
    );

    if ( !%Job ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No such job with ID $Param{ID}!"
        );
        return;        
    }

    # create job run
    my $RunID = $Self->_JobRunAdd(
        %Param,
        JobID => $Param{ID},
    );

    if ( !$RunID ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to create a new run for job with ID $Param{ID}!"
        );
        return;        
    }

    # add RunID for log reference
    $Self->{RunID} = $RunID;

    # get all assigned macros
    my @MacroIDs = $Self->JobMacroList(
        JobID => $Param{ID}
    );

    # return success if we have nothing to do
    if ( !IsArrayRefWithData(\@MacroIDs) ) {
        $Self->LogInfo(
            Message  => "Job \"$Job{Name}\" has no macros to execute.",
            UserID   => $Param{UserID},
        );
        return 1;
    }

    # check the macro if they are executable, return success if not
    my $ExecutableMacroCount = 0;
    foreach my $MacroID ( @MacroIDs ) {
         $ExecutableMacroCount++ if $Self->MacroIsExecutable(
            ID     => $MacroID,
            UserID => $Param{UserID},
        );
    }
    if ( !$ExecutableMacroCount ) {
        $Self->LogInfo(
            Message  => "Job \"$Job{Name}\" has assigned macros but non of them is executable. Aborting job execution.",
            UserID   => $Param{UserID},
        );
    }

    # load type backend module
    my $BackendObject = $Self->_LoadJobTypeBackend(
        Name => $Job{Type},
    );
    return if !$BackendObject;

    # add referrer data
    $BackendObject->{JobID} = $Self->{JobID};
    $BackendObject->{RunID} = $Self->{RunID};

    # execute backend object for given type to get the (real) list of objects (search or filter)
    my @ObjectIDs = $BackendObject->Run(
        Data      => $Param{Data},
        Filter    => $Job{Filter},
        UserID    => $Param{UserID},
    );

    if ( !@ObjectIDs ) {
        $Self->LogInfo(
            Message  => "No relevant objects. Aborting job execution.",
            UserID   => $Param{UserID},
        );
        return;
    }

    # update execution time of job
    my $Success = $Self->_JobLastExecutionTimeSet(
        ID         => $Param{ID},
        UserID     => $Param{UserID},
    );

    $Self->LogInfo(
        Message  => "executing job \"$Job{Name}\" with $ExecutableMacroCount macros on ".(scalar(@ObjectIDs))." objects.",
        UserID   => $Param{UserID},
    );

    # execute any macro with the list of objects
    my $Warning = 0;
    foreach my $MacroID ( sort @MacroIDs ) {
        foreach my $ObjectID ( @ObjectIDs ) {
            my $Result = $Self->MacroExecute(
                ID        => $MacroID,
                ObjectID  => $ObjectID,
                UserID    => $Param{UserID},
            );

            if ( !$Result ) {
                my %Macro = $Self->MacroGet(
                    ID        => $MacroID,
                    UserID    => $Param{UserID},
                );

                $Self->LogError(
                    Message  => "Macro $Macro{Name} returned execution error for ObjectID $ObjectID.",
                    UserID   => $Param{UserID},
                );
                $Warning = 1;
            }
        }
    }

    $Self->LogInfo(
        Message  => "job execution finished successfully.",
        UserID   => $Param{UserID},
    );

    # update job run
    my $StateID = 2;        # finished 
    if ( $Warning ) {
        $StateID = 3        # finished with errors
    }
    $Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE job_run SET end_time = current_timestamp, state_id = ? WHERE id = ?',
        Bind => [ \$StateID, \$RunID ],
    );

    # remove JobID and RunID from log reference
    delete $Self->{JobID};
    delete $Self->{RunID};

    return 1;
}

=item _LastExecutionTimeSet()

updates last execution time of a job

    my $Success = $AutomationObject->_JobLastExecutionTimeSet(
        ID         => 123,
        UserID     => 123,
        Time       => '...',        # optional, set explicit time instead of current timestamp        
    );

=cut

sub _JobLastExecutionTimeSet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    # update ExecPlan in database
    if ( $Param{Time} ) {
        return if !$Kernel::OM->Get('DB')->Do(
            SQL => 'UPDATE job SET last_exec_time = ? WHERE id = ?',
            Bind => [ \$Param{Time}, \$Param{ID} ],
        );
    }
    else {
        return if !$Kernel::OM->Get('DB')->Do(
            SQL => 'UPDATE job SET last_exec_time = current_timestamp WHERE id = ?',
            Bind => [ \$Param{ID} ],
        );
    }

    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp();

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Job',
        ObjectID  => $Param{ID},
    );

    return 1;
}

sub _LoadJobTypeBackend {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Name)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # load type backend
    $Self->{JobTypeModules} //= {};

    if ( !$Self->{JobTypeModules}->{$Param{Name}} ) {
        my $Backend = 'Automation::Job::' . $Param{Name};

        if ( !$Kernel::OM->Get('Main')->Require($Backend) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to require $Backend!"
            );   
            return;
        }

        my $BackendObject = $Backend->new( %{$Self} );
        if ( !$BackendObject ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to create instance of $Backend!"
            );        
            return;
        }

        $Self->{JobTypeModules}->{$Param{Name}} = $BackendObject;
    }

    return $Self->{JobTypeModules}->{$Param{Name}};
}

sub _JobRunAdd {    
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(JobID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get Job data
    my %Job = $Self->JobGet(
        ID => $Param{JobID}
    );

    if ( !%Job ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No such job with ID $Param{JobID}!"
        );
        return;        
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # prepare filter as JSON
    my $Filter;
    if ( $Job{Filter} ) {
        $Filter = $Kernel::OM->Get('JSON')->Encode(
            Data => $Job{Filter}
        );
    }    

    return if !$DBObject->Do(
        SQL => 'INSERT INTO job_run (job_id, filter, state_id, start_time, create_by) '
             . 'VALUES (?, ?, 1, current_timestamp, ?)',
        Bind => [
            \$Param{JobID}, \$Filter, \$Param{UserID}
        ],
    );

    # get new id
    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM job_run WHERE job_id = ? ORDER by id DESC',
        Bind => [ 
            \$Param{JobID}, 
        ],
        Limit => 1,
    );

    # fetch the result
    my $ID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ID = $Row[0];
    }    

    return $ID;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
