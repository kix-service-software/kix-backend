# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation;

use strict;
use warnings;

use Time::HiRes qw(time);

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::Automation::ExecPlan
    Kernel::System::Automation::Job
    Kernel::System::Automation::Macro
    Kernel::System::Automation::MacroAction
);

our @ObjectDependencies = (
    'DB',
    'JSON',
    'Log',
);

=head1 NAME

Kernel::System::Automation - automation lib

=head1 SYNOPSIS

All role functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $AutomationObject = $Kernel::OM->Get('Automation');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{CacheType} = 'Automation';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    $Self->{Debug} = $Kernel::OM->Get('Config')->Get('Automation::Debug') || 0;

    $Self->{DumpConfig} = $Kernel::OM->Get('Config')->Get('Automation::DumpConfig') || { Indent => '  ' };

    $Self->{MinimumLogLevel} = $Param{MinimumLogLevel} || $Kernel::OM->Get('Config')->Get('Automation::MinimumLogLevel');

    # load all logging backends
    my $LogHandlers = $Kernel::OM->Get('Config')->Get('Automation::Logging');
    if ( !IsHashRefWithData($LogHandlers) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'No log handlers available!',
        );
        return;
    }
    foreach my $Type ( keys %{$LogHandlers} ) {
        my $HandlerObject = $Kernel::OM->Get(
            $LogHandlers->{$Type}->{Module}
        );
        if ( !$HandlerObject ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to load handler backend for $Type!",
            );
            next;
        }

        $HandlerObject->{Config} = $LogHandlers->{$Type};

        foreach my $Key ( keys %{$HandlerObject->{Config}} ) {
            # replace placeholders
            $HandlerObject->{Config}->{$Key} = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
                Text     => $HandlerObject->{Config}->{$Key},
                Data     => {},
                RichText => 0,
                UserID   => 1,
            );
        }

        $Self->{LogHandler}->{$Type} = $HandlerObject;
    }

    return $Self;
}

=item ExecuteJobsForEvent()

Execute all relevant eventbased jobs for a given type

Example:
    my $Success = $Object->ExecuteJobsForEvent(
        Type      => 'Ticket',
        Event     => 'TicketCreate',
        Data      => {
            ...
        },
        Config    => {},
        UserID    => 123,
    );

=cut

sub ExecuteJobsForEvent {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Type Event UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    if ( $Self->{Debug} ) {
        $Self->_Debug(sprintf "ExecuteJobsForEvent: executing jobs for event \"%s\"", $Param{Event});
    }

    my $StartTime;
    if ( $Self->{Debug} ) {
        $StartTime = time();
    }

    # get all relevant jobs
    my %JobList = $Self->JobList(
        Event => $Param{Event},
        Valid => 1
    );

    if ( $Self->{Debug} ) {
        $Self->_Debug(sprintf "  ExecuteJobsForEvent: checking %i jobs for execution", scalar keys %JobList);
    }

    my $ExecutedJobCount = 0;

    # sort by names to enable simple ordering by user
    foreach my $JobID ( sort { $JobList{$a} cmp $JobList{$b} } keys %JobList ) {

        if ( $Self->{Debug} ) {
            $Self->_Debug(sprintf "  ExecuteJobsForEvent: determining if job \"%s\" is executable", $JobList{$JobID});
        }

        my $JobStartTime;
        if ( $Self->{Debug} ) {
            $JobStartTime = time();
        }

        my %Job = $Self->JobGet(
            ID => $JobID
        );

        # ignore jobs of non-relevant types
        next if $Job{Type} ne $Param{Type};

        my $CanExecute = $Self->JobIsExecutable(
            ID => $JobID,
            %Param,
        );

        if ( $Self->{Debug} ) {
            $Self->_Debug(sprintf "  ExecuteJobsForEvent: executable check took %i ms", (time() - $JobStartTime) * 1000);
        }

        if ( $CanExecute ) {

            my $JobStartTime;
            if ( $Self->{Debug} ) {
                $JobStartTime = time();
                $Self->_Debug(sprintf "  ExecuteJobsForEvent: executing job \"%s\"", $Job{Name});
            }

            # execute the job in a new Automation instance
            my $AutomationObject = $Kernel::OM->GetModuleFor('Automation')->new(%{$Self});

            $ExecutedJobCount++;
            my $Result = $AutomationObject->JobExecute(
                ID => $JobID,
                Async => $Job{IsAsynchronous},
                %Param,
            );
            if ( $Self->{Debug} ) {
                $Self->_Debug(sprintf "  ExecuteJobsForEvent: executed job \"%s\" in %i ms", $Job{Name}, (time() - $JobStartTime) * 1000);
            }
        }
    }

    if ( $Self->{Debug} ) {
        $Self->_Debug(sprintf "ExecuteJobsForEvent: executing %i jobs took %i ms", $ExecutedJobCount, (time() - $StartTime) * 1000);
    }

    return 1;
}

=item LogDebug()

Logs a debug message.

Example:
    my $Success = $Object->LogDebug(
        Message  => '...',
        UserID   => 123,
    );

=cut

sub LogDebug {
    my ( $Self, %Param ) = @_;

    return $Self->_Log(
        %Param,
        Priority => 'debug',
    )
}

=item LogInfo()

Logs an information message.

Example:
    my $Success = $Object->LogInfo(
        Message  => '...',
        UserID   => 123,
    );

=cut

sub LogInfo {
    my ( $Self, %Param ) = @_;

    return $Self->_Log(
        %Param,
        Priority => 'info',
    )
}

=item LogNotice()

Logs a notice message.

Example:
    my $Success = $Object->LogNotice(
        Message  => '...',
        UserID   => 123,
    );

=cut

sub LogNotice {
    my ( $Self, %Param ) = @_;

    return $Self->_Log(
        %Param,
        Priority => 'notice',
    )
}

=item LogError()

Logs an error message.

Example:
    my $Success = $Object->LogError(
        Message  => '...',
        UserID   => 123,
    );

=cut

sub LogError {
    my ( $Self, %Param ) = @_;

    return $Self->_Log(
        %Param,
        Priority => 'error',
    );
}

=item _Log()

Logs a message.

Example:
    my $Success = $Object->_Log(
        Priority => '...'               # see Kernel::System::Log::LogLevel
        Message  => '...',
        UserID   => 123,
    );

=cut

sub _Log {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Message Priority UserID)) {
        if ( !$Param{$_} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $_!",
                );
            }
            return;
        }
    }

    # check desired log level
    my $LogObject = $Kernel::OM->Get('Log');
    my $MinimumLogLevel = $Self->{MinimumLogLevel} || 'error';
    my $MinimumLogLevelNum = $LogObject->GetNumericLogLevel( Priority => $MinimumLogLevel);
    my $PriorityNum = $LogObject->GetNumericLogLevel( Priority => $Param{Priority} );
    return 1 if $PriorityNum < $MinimumLogLevelNum;

    my %LogData;
    foreach my $ReferenceID ( qw(JobID RunID MacroID MacroActionID ObjectID) ) {
        $LogData{$ReferenceID} = ($Param{Referrer} ? $Param{Referrer}->{$ReferenceID} : undef) || $Self->{$ReferenceID};
    }

    my $ObjectID = $LogData{ObjectID};
    if ( ref $ObjectID ) {
        $ObjectID = $Kernel::OM->Get('JSON')->Encode(
            Data => $ObjectID
        );
    }

    # get job info
    $LogData{JobInfo} = '-';
    if ( $LogData{JobID} ) {
        $LogData{Job} = { $Self->JobGet(
            ID => $LogData{JobID}
        ) };
        $LogData{JobInfo} = "$LogData{Job}->{Name} ($LogData{Job}->{ID})";
    }

    # get macro info
    $LogData{MacroInfo} = '-';
    if ( $LogData{MacroID} ) {
        $LogData{Macro} = { $Self->MacroGet(
            ID => $LogData{MacroID}
        ) };
        $LogData{MacroInfo} = "$LogData{Macro}->{Name} ($LogData{Macro}->{ID})";
    }

    # get macro info
    $LogData{MacroActionInfo} = '-';
    if ( $LogData{MacroActionID} ) {
        $LogData{MacroAction} = { $Self->MacroActionGet(
            ID => $LogData{MacroActionID}
        ) };
        $LogData{MacroActionInfo} = "$LogData{MacroAction}->{Type} ($LogData{MacroAction}->{ID})";
    }

    my $Type = $LogData{Job}->{Type} || $LogData{Macro}->{Type} || 'Default';

    # execute logging handler
    my $LogHandler = $Self->{LogHandler}->{$Type} || $Self->{LogHandler}->{Default};
    my $Success = $LogHandler->Log(
        LogData => \%LogData,
        %Param,
    );

    return 1;
}

=item LogDelete()

Delete entries of the log

Example:
    my $Success = $Object->LogDelete(
        JobID         => 123,               # JobID, RunID, MacroID, or MacroActionID is needed
        RunID         => 123,
        MacroID       => 123,
        MacroActionID => 123,
    );

=cut

sub LogDelete {
    my ( $Self, %Param ) = @_;

    # check params
    if (
        !$Param{JobID}
        && !$Param{RunID}
        && !$Param{MacroID}
        && !$Param{MacroActionID}
    ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need JobID, RunID, MacroID, or MacroActionID!",
        );
        return;
    }

    # prepare mapping of references
    my %ReferenceMap  = (
        'JobID'         => 'job_id',
        'RunID'         => 'run_id',
        'MacroID'       => 'macro_id',
        'MacroActionID' => 'macro_action_id'
    );

    # init params
    my $SQL  = 'DELETE FROM automation_log WHERE ';
    my @Bind = ();

    # prepare reference data
    my @WhereClauses = ();
    for my $Reference ( qw(JobID RunID MacroID MacroActionID) ) {
        if ( $Param{ $Reference } ) {
            my $WhereClause = $ReferenceMap{ $Reference } . ' = ?';

            push( @WhereClauses, $WhereClause );
            push( @Bind, \$Param{ $Reference } );
        }
    }

    # prepare statement
    $SQL .= join( ' AND ', @WhereClauses );

    # execute statement
    return if !$Kernel::OM->Get('DB')->Do(
        SQL  => $SQL,
        Bind => \@Bind,
    );

    return 1;
}

=item GetLogCount()

Returns the log entry count

Example:
    my $Count = $Object->GetLogCount(
        JobID         => 123,               # optional
        RunID         => 123,               # optional
        MacroID       => 123,               # optional
        MacroActionID => 123,               # optional
        Priority      => 'error'            # optional
    );

=cut

sub GetLogCount {
    my ( $Self, %Param ) = @_;

    # prepare mapping of references
    my %ReferenceMap  = (
        'JobID'         => 'job_id',
        'RunID'         => 'run_id',
        'MacroID'       => 'macro_id',
        'MacroActionID' => 'macro_action_id',
        'Priority'      => 'priority'
    );

    # init params
    my $SQL  = 'SELECT count(*) FROM automation_log WHERE 1=1';
    my @Bind = ();

    # prepare reference data
    my @WhereClauses = ();
    for my $Reference ( qw(JobID RunID MacroID MacroActionID Priority) ) {
        if ( $Param{ $Reference } ) {
            my $WhereClause = $ReferenceMap{ $Reference } . ' = ?';

            push( @WhereClauses, $WhereClause );
            push( @Bind, \$Param{ $Reference } );
        }
    }

    # prepare statement
    $SQL .= join( ' AND ', @WhereClauses );

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # fetch sla_id from ticket
    return if !$DBObject->Prepare(
        SQL => $SQL,
        Bind => \@Bind,
    );

    my $Count = 0;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Count = $Row[0];
    }

    return $Count;
}

sub _Debug {
    my ( $Self, $Message ) = @_;

    return if !$Self->{Debug};

    printf STDERR "%f (%5i) %-15s %s\n", time(), $$, "[Automation]", "$Message";
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
