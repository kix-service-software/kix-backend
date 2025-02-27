# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::Job;

use strict;
use warnings;

use Time::HiRes qw(time);

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::AsynchronousExecutor);

our @ObjectDependencies = qw(
    Cache
    ClientRegistration
    Config
    DB
    JSON
    Log
    Main
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
        ID                => 2,
        Type              => 'Ticket',
        Name              => 'Test',
        Filter            => [],
        SortOrder         => {},
        IsAsynchronous    => 0|1,
        Comment           => '...',
        LastExecutionTime => '2019-10-21 12:00:00',
        ValidID           => '1',
        CreateTime        => '2010-04-07 15:41:15',
        CreateBy          => 1,
        ChangeTime        => '2010-04-07 15:41:15',
        ChangeBy          => 1
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
        SQL   => "SELECT id, name, type, filter, sort_order, comments, is_async, valid_id, last_exec_time, create_time, create_by, change_time, change_by FROM job WHERE id = ?",
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
            SortOrder         => $Row[4],
            Comment           => $Row[5],
            IsAsynchronous    => $Row[6],
            ValidID           => $Row[7],
            LastExecutionTime => $Row[8],
            CreateTime        => $Row[9],
            CreateBy          => $Row[10],
            ChangeTime        => $Row[11],
            ChangeBy          => $Row[12],
        );

        if ( $Result{Filter} ) {
            # decode JSON
            $Result{Filter} = $Kernel::OM->Get('JSON')->Decode(
                Data => $Result{Filter}
            );
            if (!IsArrayRef($Result{Filter})) {
                $Result{Filter} = [$Result{Filter}];
            }
        }

        if ( $Result{SortOrder} ) {
            # decode JSON
            $Result{SortOrder} = $Kernel::OM->Get('JSON')->Decode(
                Data => $Result{SortOrder}
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
        Name           => 'test',
        Type           => 'Ticket',
        Filter         => [                                         # optional
            {
                AND => [
                    {
                        Field     => 'TypeID',
                        Operator  => 'EQ',
                        Value     => 2
                    }
                ]
            }
        ],
        SortOrder      => {                                         # optional
            Field     => 'QueueID',
            Direction => 'descending'
        }
        Comment        => '...',                                    # optional
        IsAsynchronous => 1,                                        # optional
        ValidID        => 1,                                        # optional
        UserID         => 123,
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

    $Param{ValidID}        //= 1;
    $Param{IsAsynchronous} //= 0;

    # check if this is a duplicate after the change
    my $ID = $Self->JobLookup(
        Name => $Param{Name},
    );
    if ( $ID ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "A job with the same name already exists.",
            );
        }
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # prepare filter as JSON
    my $Filter;
    if ( $Param{Filter} ) {
        if ( !IsArrayRef($Param{Filter}) ) {
            $Param{Filter} = [$Param{Filter}];
        }
        $Filter = $Kernel::OM->Get('JSON')->Encode(
            Data => $Param{Filter}
        );
        if ( !$Filter ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Could not add job, Filter is invalid.",
            );
            return;
        }
    }

    # prepare sortorder as JSON
    my $SortOrder;
    if ( $Param{SortOrder} ) {
        $SortOrder = $Kernel::OM->Get('JSON')->Encode(
            Data => $Param{SortOrder}
        );
        if ( !$SortOrder ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Could not add job, SortOrder is invalid.",
            );
            return;
        }
    }

    # insert
    return if !$DBObject->Do(
        SQL => 'INSERT INTO job (name, type, filter, sort_order, comments, is_async, valid_id, create_time, create_by, change_time, change_by) '
             . 'VALUES (?, ?, ?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Name}, \$Param{Type}, \$Filter, \$SortOrder, \$Param{Comment}, \$Param{IsAsynchronous}, \$Param{ValidID}, \$Param{UserID}, \$Param{UserID}
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

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'Job',
        ObjectID  => $ID,
    );

    return $ID;
}

=item JobUpdate()

updates a job

    my $Success = $AutomationObject->JobUpdate(
        ID             => 123,
        Name           => 'test'
        Type           => 'Ticket',                                 # optional
        Filter         => [                                         # optional
            {
                AND => [
                    {
                        Field     => 'TypeID',
                        Operator  => 'EQ',
                        Value     => 2
                    }
                ]
            }
        ],
        SortOrder      => {                                         # optional
            Field     => 'QueueID',
            Direction => 'ascending'
        },
        Comment        => '...',                                    # optional
        IsAsynchronous => 1,                                        # optional
        ValidID        => 1,                                        # optional
        UserID         => 123,
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
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "A job with the same name already exists.",
            );
        }
        return;
    }

    # set default value
    $Param{Comment} ||= '';

    if ( $Param{Filter} && !IsArrayRef($Param{Filter}) ) {
        $Param{Filter} = [$Param{Filter}];
    }

    # check if update is required
    my $ChangeRequired;
    KEY:
    for my $Key ( qw(Type Name Filter SortOrder Comment IsAsynchronous ValidID) ) {

        next KEY if (
            (
                !defined( $Data{ $Key } )
                && !defined( $Param{ $Key } )
            )
            || (
                defined( $Data{ $Key } )
                && defined( $Param{ $Key } )
                && $Data{ $Key } eq $Param{ $Key }
            )
        );

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
        if ( !$Filter ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Could not update job, Filter is invalid.",
            );
            return;
        }
    }

    # prepare sortorder as JSON
    my $SortOrder;
    if ( $Param{SortOrder} ) {
        $SortOrder = $Kernel::OM->Get('JSON')->Encode(
            Data => $Param{SortOrder}
        );
        if ( !$SortOrder ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Could not update job, SortOrder is invalid.",
            );
            return;
        }
    }

    # update Job in database
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE job SET type = ?, name = ?, filter = ?, sort_order = ?, comments = ?, is_async = ?, valid_id = ?, change_time = current_timestamp, change_by = ? WHERE id = ?',
        Bind => [
            \$Param{Type}, \$Param{Name}, \$Filter, \$SortOrder, \$Param{Comment}, \$Param{IsAsynchronous}, \$Param{ValidID}, \$Param{UserID}, \$Param{ID}
        ],
    );

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Job',
        ObjectID  => $Param{ID},
    );

    return 1;
}

=item JobList()

returns a hash of all relevant jobs

    my %Jobs = $AutomationObject->JobList(
        Valid => 1                  # optional
        Event => 'TicketCreate'     # optional
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
    my $CacheKey = 'JobList::' . $Valid . '::' . ($Param{Event}||'');

    # read cache
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    my $SQL = 'SELECT j.id, j.name FROM job j';

    if ( $Param{Valid} ) {
        $SQL .= ' WHERE j.valid_id = 1'
    }
    if ( $Param{Event} ) {
        # quote event string with surrounding quotes
        # TODO: quote % in event string as well
        my $EventString = '%' . $Kernel::OM->Get('DB')->Quote( '"' . $Param{Event} . '"', 'Like' ) . '%';

        $SQL .= " AND EXISTS (
                    SELECT ep.id FROM job_exec_plan jep, exec_plan ep
                     WHERE jep.job_id = j.id AND jep.exec_plan_id = ep.id AND ep.type = 'EventBased' AND ep.parameters LIKE '$EventString')";
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
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "A job with the ID $Param{ID} does not exist.",
            );
        }
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # delete log entries
    return if !$Self->LogDelete(
        JobID => $Param{ID},
    );

    # delete runs
    return if !$DBObject->Do(
        SQL  => 'DELETE FROM job_run WHERE job_id = ?',
        Bind => [ \$Param{ID} ],
    );

    # remove exec plans
    my @ExecPlanIDs = $Self->JobExecPlanList(
        JobID => $Param{ID},
    );
    if (IsArrayRefWithData(\@ExecPlanIDs)) {

        # delete exec plan assignments
        return if !$DBObject->Do(
            SQL  => 'DELETE FROM job_exec_plan WHERE job_id = ?',
            Bind => [ \$Param{ID} ],
        );

        # delete exec plans if possible
        for my $ExecPlanID (@ExecPlanIDs) {
            if (
                $Self->ExecPlanIsDeletable(
                    ID => $ExecPlanID
                )
            ) {
                $Self->ExecPlanDelete(
                    ID => $ExecPlanID,
                );
            }
        }
    }

    # remove macros
    my @MacroIDs = $Self->JobMacroList(
        JobID => $Param{ID},
    );
    if (IsArrayRefWithData(\@MacroIDs)) {

        # delete macro assignments
        return if !$DBObject->Do(
            SQL  => 'DELETE FROM job_macro WHERE job_id = ?',
            Bind => [ \$Param{ID} ],
        );

        # delete macros if possible
        for my $MacroID (@MacroIDs) {
            if (
                $Self->MacroIsDeletable(
                    ID => $MacroID
                )
            ) {
                $Self->MacroDelete(
                    ID => $MacroID,
                );
            }
        }
    }

    # remove job from database
    return if !$DBObject->Do(
        SQL  => 'DELETE FROM job WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
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
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    # check cache
    my $CacheKey = 'JobMacroList::' . $Param{JobID};
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return @{$Cache} if $Cache;

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL   => 'SELECT macro_id FROM job_macro WHERE job_id = ?',
        Bind => [ \$Param{JobID} ],
    );

    my @Result;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        push(@Result, $Row[0]);
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \@Result,
    );

    return @Result;
}

=item AllUsedMacroIDList()

returns a list of all Macro ids assigned to Jobs

    my @MacroIDs = $AutomationObject->AllUsedMacroIDList();

=cut

sub AllUsedMacroIDList {
    my ( $Self, %Param ) = @_;

    # check cache
    my $CacheKey = 'AllUsedMacroIDList';
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return @{$Cache} if $Cache;

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL => 'SELECT macro_id FROM job_macro'
    );

    my @Result;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        push(@Result, $Row[0]);
    }

    # remove duplicates
    @Result = $Kernel::OM->Get('Main')->GetUnique(@Result);

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \@Result,
    );

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

        # delete cache
        $Kernel::OM->Get('Cache')->CleanUp(
            Type => $Self->{CacheType},
        );

        # push client callback event
        $Kernel::OM->Get('ClientNotification')->NotifyClients(
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

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
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

    # check cache
    my $CacheKey = 'JobExecPlanList::' . $Param{JobID};
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return @{$Cache} if $Cache;

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL   => 'SELECT exec_plan_id FROM job_exec_plan WHERE job_id = ?',
        Bind => [ \$Param{JobID} ],
    );

    my @Result;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        push(@Result, $Row[0]);
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \@Result,
    );

    return @Result;
}

=item AllUsedExecPlanIDList()

returns a list of all ExecPlan ids assigned to Jobs

    my @ExecPlanIDs = $AutomationObject->AllUsedExecPlanIDList();

=cut

sub AllUsedExecPlanIDList {
    my ( $Self, %Param ) = @_;

    # check cache
    my $CacheKey = 'AllUsedExecPlanIDList';
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return @{$Cache} if $Cache;

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL => 'SELECT exec_plan_id FROM job_exec_plan'
    );

    my @Result;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        push(@Result, $Row[0]);
    }

    # remove duplicates
    @Result = $Kernel::OM->Get('Main')->GetUnique(@Result);

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \@Result,
    );

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

        # delete cache
        $Kernel::OM->Get('Cache')->CleanUp(
            Type => $Self->{CacheType},
        );

        # push client callback event
        $Kernel::OM->Get('ClientNotification')->NotifyClients(
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

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
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

    my $StartTime;
    if ( $Self->{Debug} ) {
        $StartTime = time();
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

    if ( $Self->{Debug} ) {
        $Self->_Debug(sprintf "    JobIsExecutable: checking %i execution plans took %i ms", scalar @ExecPlanList, (time() - $StartTime) * 1000);
    }

    return $CanExecute;
}

=item JobExecute()

executes a job

    my $Success = $AutomationObject->JobExecute(
        ID        => 123,       # the ID of the job
        Data      => {},        # optional, contains the relevant data given by an event or otherwise
        Async     => 0|1,       # optional, default 0
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

    my $Result;
    if ( $Param{Async} ) {
        if ( $Self->{Debug} ) {
            $Self->_Debug(sprintf "JobExecute: executing job %i asynchronously", $Param{ID});
        }
        # execute asynchronously
        $Self->AsyncCall(
            FunctionName   => '_JobExecute',
            FunctionParams => \%Param,
        );
    }
    else {
        # execute synchronously
        $Result = $Self->_JobExecute(
            %Param
        );
    }

    return $Result;
}

sub _JobExecute {
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

    my $StartTime;
    if ( $Self->{Debug} ) {
        $StartTime = time();
    }

    # update execution time of job
    my $Success = $Self->_JobLastExecutionTimeSet(
        ID         => $Param{ID},
        UserID     => $Param{UserID},
    );

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

    if ( $Self->{Debug} ) {
        $Self->_Debug(sprintf "    _JobExecute: preparations and creating job run took %i ms", (time() - $StartTime) * 1000);
    }

    # add RunID for log reference
    $Self->{RunID} = $RunID;

    if ( $Self->{Debug} ) {
        $StartTime = time();
    }

    # get all assigned macros
    my @MacroIDs = $Self->JobMacroList(
        JobID => $Param{ID}
    );

    if ( $Self->{Debug} ) {
        $Self->_Debug(sprintf "    _JobExecute: getting macro list took %i ms", (time() - $StartTime) * 1000);
    }

    # return success if we have nothing to do
    my $Warning = 0;
    if ( !IsArrayRefWithData(\@MacroIDs) ) {
        $Self->LogInfo(
            Message  => "Job \"$Job{Name}\" has no macros to execute.",
            UserID   => $Param{UserID},
        );
        $Warning = 1;
    } else {

        if ( $Self->{Debug} ) {
            $StartTime = time();
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
                Message  => "Job \"$Job{Name}\" has assigned macros but none of them is executable. Aborting job execution.",
                UserID   => $Param{UserID},
            );
            $Warning = 1;
        } else {

            # load type backend module
            my $BackendObject = $Self->_LoadJobTypeBackend(
                Name => $Job{Type},
            );

            my @ObjectIDs;
            if (!$BackendObject) {
                $Self->LogInfo(
                    Message  => "No backend object found for job type \"$Job{Type}\".",
                    UserID   => $Param{UserID},
                );
                $Warning = 1;
            } else {

                # execute backend object for given type to get the (real) list of objects (search or filter)
                @ObjectIDs = $BackendObject->Run(
                    Data      => $Param{Data},
                    Filter    => $Job{Filter},
                    SortOrder => $Job{SortOrder},
                    UserID    => $Param{UserID},
                );

                if ( !@ObjectIDs ) {
                    $Self->LogInfo(
                        Message  => "No relevant objects. Aborting job execution.",
                        UserID   => $Param{UserID},
                    );
                }
            }

            if (@ObjectIDs) {
                $Self->LogInfo(
                    Message  => "executing job \"$Job{Name}\" with $ExecutableMacroCount macros on ".(scalar(@ObjectIDs))." objects.",
                    UserID   => $Param{UserID},
                );

                # execute any macro with the list of objects
                foreach my $MacroID ( sort @MacroIDs ) {
                    foreach my $ObjectID ( @ObjectIDs ) {
                        my $Result = $Self->MacroExecute(
                            ID        => $MacroID,
                            ObjectID  => $ObjectID,
                            EventData => $Param{Data},
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
                if ( $Self->{Debug} ) {
                    $Self->_Debug(sprintf "    _JobExecute: executing %i macros took %i ms", scalar @MacroIDs, (time() - $StartTime) * 1000);
                }
            }
        }
    }

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

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'Job.JobRun',
        ObjectID  => $Param{ID}.'::'.$RunID,
    );

    return 1;
}

=item JobDump()

gets the "script code" of a job

    my $Code = $AutomationObject->JobDump(
        ID => 123,       # the ID of the job
    );

=cut

sub JobDump {
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

    my %Job = $Self->JobGet(
        ID => $Param{ID}
    );
    if ( !%Job ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Job with ID $Param{ID} not found!"
        );
        return;
    }

    my $Name = $Job{Name};
    $Name =~ s/"/\\\"/g;
    my $Script = "Job \"$Name\"";

    foreach my $Attr ( qw(Type Comment) ) {
        next if !$Job{$Attr};
        my $Value = $Job{$Attr};
        $Value =~ s/"/\\\"/g;
        $Script .= ' --'.$Attr.' "'.$Value.'"';
    }

    $Script .= "\n";

    # dump exec plans
    my @ExecPlanIDs = $Self->JobExecPlanList(
        JobID => $Param{ID}
    );
    foreach my $ExecPlanID ( @ExecPlanIDs ) {
        my $ExecPlanCode = $Self->ExecPlanDump(
            ID => $ExecPlanID,
        );
        foreach my $Line ( split /\n/, $ExecPlanCode) {
            $Script .= $Self->{DumpConfig}->{Indent} . $Line . "\n";
        }
    }

    $Script .= "\n";

    # dump filter
    if ( IsHashRefWithData($Job{Filter}) ) {
        $Script .= $Self->{DumpConfig}->{Indent}.'Filter "';
        foreach my $BoolOperator ( sort keys %{$Job{Filter}} ) {
            $Script .= '(' if $BoolOperator eq 'AND';
            my @FilterItems = @{$Job{Filter}->{$BoolOperator}};
            while ( @FilterItems ) {
                my $FilterItem = shift @FilterItems;

                my $Operator = $FilterItem->{Operator};
                $Operator = "!$Operator" if $FilterItem->{Not};
                if ( IsArrayRef($FilterItem->{Value}) ) {
                    $Script .= $FilterItem->{Field}.' '.$Operator.' ['.join(',', @{$FilterItem->{Value}})."]";
                }
                else {
                    $Script .= $FilterItem->{Field}.' '.$Operator.' '.$FilterItem->{Value};
                }
                $Script .= ' '.$BoolOperator.' ' if @FilterItems;
            }
            $Script .= ')' if $BoolOperator eq 'AND';
        }
        $Script .= "\"\n\n";
    }

    # dump macros
    my @MacroIDs = $Self->JobMacroList(
        JobID => $Param{ID}
    );
    foreach my $MacroID ( @MacroIDs ) {
        my $MacroCode = $Self->MacroDump(
            ID => $MacroID,
        );
        foreach my $Line ( split /\n/, $MacroCode) {
            $Script .= $Self->{DumpConfig}->{Indent} . $Line . "\n";
        }
    }

    $Script .= "End\n";

    return $Script;
}

=item JobRunList()

returns a hash of all runs (ID + StateID) for a given job

    my %JobRunIDs = $AutomationObject->JobRunList(
        JobID => 123
    );

=cut

sub JobRunList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(JobID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # create cache key
    my $CacheKey = 'JobRunList::' . $Param{JobID};

    # read cache
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'SELECT id, state_id FROM job_run WHERE job_id = ?',
        Bind => [ \$Param{JobID} ]
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

=item JobRunGet()

returns a hash with the run data

    my %JobRunData = $AutomationObject->JobRunGet(
        ID => 2,
    );

This returns something like:

    %JobRunData = (
        'ID'          => 123,
        'JobID'       => 2,
        'StateID'     => 1,
        'Filter'      => {},
        'StartTime'   => '2019-10-21 12:00:00',
        'EndTime'     => '2019-10-21 12:30:00',
        'CreateBy'    => 1,
    );

=cut

sub JobRunGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ID} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Need ID!'
            );
        }
        return;
    }

    # check cache
    my $CacheKey = 'JobRunGet::' . $Param{ID};
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL   => "SELECT id, job_id, filter, state_id, start_time, end_time, create_by FROM job_run WHERE id = ?",
        Bind => [ \$Param{ID} ],
    );

    my %Result;

    # fetch the result
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        %Result = (
            ID          => $Row[0],
            JobID       => $Row[1],
            Filter      => $Row[2],
            StateID     => $Row[3],
            StartTime   => $Row[4],
            EndTime     => $Row[5],
            CreateBy    => $Row[6],
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
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "JobRun with ID $Param{ID} not found!",
            );
        }
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

=item JobRunLogList()

returns a list of all logs items for a given run

    my @Logs = $AutomationObject->JobRunLogList(
        RunID => 123
    );

=cut

sub JobRunLogList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(RunID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # create cache key
    my $CacheKey = 'JobRunLogList::' . $Param{RunID};

    # read cache
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return @{$Cache} if $Cache;

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'SELECT id, job_id, run_id, macro_id, macro_action_id, object_id, priority, message, create_time, create_by FROM automation_log WHERE run_id = ? ORDER BY id',
        Bind => [ \$Param{RunID} ]
    );

    my $Data = $Kernel::OM->Get('DB')->FetchAllArrayRef(
        Columns => [ 'ID', 'JobID', 'RunID', 'MacroID', 'MacroActionID', 'ObjectID', 'Priority', 'Message', 'CreateTime', 'CreateBy' ],
    );

    # data found...
    my @Result;
    if ( IsArrayRefWithData($Data) ) {
        @Result = @{$Data};
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        Key   => $CacheKey,
        Value => \@Result,
        TTL   => $Self->{CacheTTL},
    );

    return @Result;
}

=item JobRunStateList()

returns a hash of all run state items

    my %States = $AutomationObject->JobRunStateList();

This returns a list like:

    %States = {
        1 => {
            'ID'          => 1,
            'Name'        => 'running',
            'Comment'     => 'The job is running',
            'ValidID'     => 1,
            'CreateTime'  => '2020-02-14 12:00:00',
            'CreateBy'    => 1,
            'ChangeTime'  => '2020-02-14 12:00:00',
            'ChangeBy'    => 1
        },
        2 => { ... }
    };

=cut

sub JobRunStateList {
    my ( $Self, %Param ) = @_;


    # create cache key
    my $CacheKey = 'JobRunStateList';

    # read cache
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'SELECT id, name, comments, valid_id, create_time, create_by, change_time, change_by FROM job_run_state'
    );

    my $Data = $Kernel::OM->Get('DB')->FetchAllArrayRef(
        Columns => [ 'ID', 'Name', 'Comment', 'ValidID', 'CreateTime', 'CreateBy', 'ChangeTime', 'ChangeBy' ],
    );

    # data found...
    my %Result;
    if ( IsArrayRefWithData($Data) ) {
        %Result = map { $_->{ID} => $_ } @{$Data};
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

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
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
        # load backend modules
        my $Backends = $Kernel::OM->Get('Config')->Get('Automation::JobType');

        if ( !IsHashRefWithData($Backends) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No job backend modules found!",
            );
            return;
        }

        my $Backend = $Backends->{$Param{Name}}->{Module};

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

        # add referrer data
        $BackendObject->{JobID} = $Self->{JobID};
        $BackendObject->{RunID} = $Self->{RunID};
        $BackendObject->{Debug} = $Self->{Debug};

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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
