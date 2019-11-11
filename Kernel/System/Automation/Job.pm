# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
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
    'Kernel::Config',
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::User',
    'Kernel::System::Valid',
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
        $Kernel::OM->Get('Kernel::System::Log')->Log(
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
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need ID!'
        );
        return;
    }

    # check cache
    my $CacheKey = 'JobGet::' . $Param{ID};
    my $Cache    = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;
    
    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare( 
        SQL   => "SELECT id, name, type, filter, comments, valid_id, last_exec_time, create_time, create_by, change_time, change_by FROM job WHERE id = ?",
        Bind => [ \$Param{ID} ],
    );

    my %Result;
    
    # fetch the result
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
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
            $Result{Filter} = $Kernel::OM->Get('Kernel::System::JSON')->Decode(
                Data => $Result{Filter}
            );
        }
    }
    
    # no data found...
    if ( !%Result ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Job with ID $Param{ID} not found!",
        );
        return;
    }
    
    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
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
            $Kernel::OM->Get('Kernel::System::Log')->Log(
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
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "A job with the same name already exists.",
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # prepare filter as JSON
    my $Filter;
    if ( $Param{Filter} ) {
        $Filter = $Kernel::OM->Get('Kernel::System::JSON')->Encode(
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
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp();

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
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
            $Kernel::OM->Get('Kernel::System::Log')->Log(
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
        $Kernel::OM->Get('Kernel::System::Log')->Log(
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
        $Filter = $Kernel::OM->Get('Kernel::System::JSON')->Encode(
            Data => $Param{Filter}
        );
    }

    # update Job in database
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'UPDATE job SET type = ?, name = ?, filter = ?, comments = ?, valid_id = ?, change_time = current_timestamp, change_by = ? WHERE id = ?',
        Bind => [
            \$Param{Type}, \$Param{Name}, \$Filter, \$Param{Comment}, \$Param{ValidID}, \$Param{UserID}, \$Param{ID}
        ],
    );

    # delete whole cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp();

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
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
    my $Cache = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    my $SQL = 'SELECT id, name FROM job';

    if ( $Param{Valid} ) {
        $SQL .= ' WHERE valid_id = 1'
    }

    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare( 
        SQL => $SQL
    );

    my %Result;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        $Result{$Row[0]} = $Row[1];
    }

    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
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
            $Kernel::OM->Get('Kernel::System::Log')->Log(
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
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "A job with the ID $Param{ID} does not exist.",
        );
        return;
    }

    # delete relations with ExecPlans
    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL  => 'DELETE FROM job_exec_plan WHERE job_id = ?',
        Bind => [ \$Param{ID} ],
    );

    # delete relations with Macros
    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL  => 'DELETE FROM job_macro WHERE job_id = ?',
        Bind => [ \$Param{ID} ],
    );

    # remove from database
    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL  => 'DELETE FROM job WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );
   
    # delete whole cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp();

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Job',
        ObjectID  => $Param{ID},
    );

    return 1;

}

=item LastExecutionTimeSet()

updates last execution time of a job

    my $Success = $AutomationObject->LastExecutionTimeSet(
        ID         => 123,
        UserID     => 123,
    );

=cut

sub LastExecutionTimeSet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    # update ExecPlan in database
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'UPDATE job SET last_exec_time = current_timestamp WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );

    # delete whole cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp();

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Job',
        ObjectID  => $Param{ID},
    );

    return 1;
}

=item JobMacroList()

returns a list of all Macro ids assigned to given Job

    my @MacroIDs = $AutomationObject->JobMacroList(
        JobID => 123
    );

=cut

sub JobMacroList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(JobID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare( 
        SQL   => 'SELECT macro_id FROM job_macro WHERE job_id = ?',
        Bind => [ \$Param{JobID} ],
    );

    my @Result;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
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
            $Kernel::OM->Get('Kernel::System::Log')->Log(
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
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Cannot assign Macro to Job. A Job with ID $Param{JobID} does not exists.",
        );
        return;
    }

    my $MacroName = $Self->MacroLookup(
        ID => $Param{MacroID},
    );
    if ( !$MacroName) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
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
        return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
            SQL => 'INSERT INTO job_macro (job_id, macro_id, create_time, create_by, change_time, change_by) '
                . 'VALUES (?, ?, current_timestamp, ?, current_timestamp, ?)',
            Bind => [
                \$Param{JobID}, \$Param{MacroID}, \$Param{UserID}, \$Param{UserID}
            ],
        );

        # delete whole cache
        $Kernel::OM->Get('Kernel::System::Cache')->CleanUp();

        # push client callback event
        $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
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
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # remove from database
    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL  => 'DELETE FROM job_macro WHERE job_id = ? AND macro_id = ?',
        Bind => [ \$Param{JobID}, \$Param{MacroID} ],
    );
   
    # delete whole cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp();

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
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
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare( 
        SQL   => 'SELECT exec_plan_id FROM job_exec_plan WHERE job_id = ?',
        Bind => [ \$Param{JobID} ],
    );

    my @Result;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
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
            $Kernel::OM->Get('Kernel::System::Log')->Log(
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
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Cannot assign ExecPlan to Job. A Job with ID $Param{JobID} does not exists.",
        );
        return;
    }

    my $ExecPlanName = $Self->ExecPlanLookup(
        ID => $Param{ExecPlanID},
    );
    if ( !$ExecPlanName) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
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
        return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
            SQL => 'INSERT INTO job_exec_plan (job_id, exec_plan_id, create_time, create_by, change_time, change_by) '
                . 'VALUES (?, ?, current_timestamp, ?, current_timestamp, ?)',
            Bind => [
                \$Param{JobID}, \$Param{ExecPlanID}, \$Param{UserID}, \$Param{UserID}
            ],
        );

        # delete whole cache
        $Kernel::OM->Get('Kernel::System::Cache')->CleanUp();

        # push client callback event
        $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
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
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # remove from database
    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL  => 'DELETE FROM job_exec_plan WHERE job_id = ? AND exec_plan_id = ?',
        Bind => [ \$Param{JobID}, \$Param{ExecPlanID} ],
    );
   
    # delete whole cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp();

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Job.ExecPlan',
        ObjectID  => $Param{JobID}.'::'.$Param{ExecPlanID},
    );

    return 1;
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
