# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Automation::MacroAction;

use strict;
use warnings;

use Digest::MD5;
use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = qw(
    ClientRegistration
    Config
    Cache
    DB
    Log
    User
    Valid
);

=head1 NAME

Kernel::System::Automation::MacroAction - macro action extension for automation lib

=head1 SYNOPSIS

All Execution Plan functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item MacroActionTypeGet()

get a description of the given MacroAction type

    my %MacroActionType = $AutomationObject->MacroActionTypeGet(
        MacroType => 'Ticket',
        Name      => '...',
    );

=cut

sub MacroActionTypeGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(MacroType Name)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # load type backend module
    my $BackendObject = $Self->_LoadMacroActionTypeBackend(
        %Param
    );
    return if !$BackendObject;

    return $BackendObject->DefinitionGet();
}

=item MacroActionGet()

returns a hash with the macro_action data

    my %MacroActionData = $AutomationObject->MacroActionGet(
        ID => 2,
    );

This returns something like:

    %MacroActionData = (
        'ID'         => 2,
        'Type'       => '...'
        'Parameters' => {},
        'ResultVariables' => {},
        'Comment'    => '...',
        'ValidID'    => '1',
        'CreateTime' => '2010-04-07 15:41:15',
        'CreateBy'   => 1,
        'ChangeTime' => '2010-04-07 15:41:15',
        'ChangeBy'   => 1
    );

=cut

sub MacroActionGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # check cache
    my $CacheKey = 'MacroActionGet::' . $Param{ID};
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL   => "SELECT id, macro_id, type, parameters, result_variables, comments, valid_id, create_time, create_by, change_time, change_by, referenced_macro_id FROM macro_action WHERE id = ?",
        Bind => [ \$Param{ID} ],
    );

    my %Result;

    # fetch the result
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        %Result = (
            ID                => $Row[0],
            MacroID           => $Row[1],
            Type              => $Row[2],
            Parameters        => $Row[3],
            ResultVariables   => $Row[4],
            Comment           => $Row[5],
            ValidID           => $Row[6],
            CreateTime        => $Row[7],
            CreateBy          => $Row[8],
            ChangeTime        => $Row[9],
            ChangeBy          => $Row[10],
            ReferencedMacroID => $Row[11]
        );

        if ( $Result{Parameters} ) {
            # decode JSON
            $Result{Parameters} = $Kernel::OM->Get('JSON')->Decode(
                Data => $Result{Parameters}
            );
        }

        if ( $Result{ResultVariables} ) {
            # decode JSON
            $Result{ResultVariables} = $Kernel::OM->Get('JSON')->Decode(
                Data => $Result{ResultVariables}
            );
        }
    }

    # no data found...
    if ( !%Result ) {
        if (
            !defined $Param{Silent}
            || !$Param{Silent}
        ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Macro action with ID $Param{ID} not found!",
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

=item MacroActionAdd()

adds a new MacroAction

    my $ID = $AutomationObject->MacroActionAdd(
        MacroID         => 123
        Type            => 'test',
        Parameters      => HashRef,                                  # optional
        ResultVariables => HashRef,                                  # optional
        Comment         => '...',                                    # optional
        ValidID         => 1,                                        # optional
        UserID          => 123,
    );

=cut

sub MacroActionAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(MacroID Type UserID)) {
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

    # get macro data
    my %Macro = $Self->MacroGet(
        ID => $Param{MacroID}
    );
    if ( !%Macro ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Macro with ID $Param{MacroID} doesn't exist!"
        );
        return;
    }

    # validate Parameters
    my $BackendObject = $Self->_LoadMacroActionTypeBackend(
        MacroType => $Macro{Type},
        Name      => $Param{Type},
    );
    return if !$BackendObject;

    $Param{Parameters} = $Param{Parameters} || {};
    my $IsValid = $BackendObject->ValidateConfig(
        Config => $Param{Parameters},
        Silent => $Param{Silent}
    );

    if ( !$IsValid ) {
        if ( !$Param{Silent} ) {
            my $LogMessage = $Kernel::OM->Get('Log')->GetLogEntry(
                Type => 'error',
                What => 'Message',
            );
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "MacroAction config is invalid ($LogMessage)!"
            );
        }
        return;
    }

    my $ReferencedMacroID = $Param{Parameters}->{MacroID};
    return if !$Self->_ReferencedMacroCheck(
        MacroID           => $Param{MacroID},
        ReferencedMacroID => $ReferencedMacroID,
        Silent            => $Param{Silent},
    );

    # prepare Parameters as JSON
    my $Parameters;
    if ( $Param{Parameters} ) {
        $Parameters = $Kernel::OM->Get('JSON')->Encode(
            Data => $Param{Parameters}
        );
    }
    # prepare ResultVariables as JSON
    my $ResultVariables;
    if ( $Param{ResultVariables} ) {
        $ResultVariables = $Kernel::OM->Get('JSON')->Encode(
            Data => $Param{ResultVariables}
        );
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # insert
    return if !$DBObject->Do(
        SQL => 'INSERT INTO macro_action (macro_id, referenced_macro_id, type, parameters, result_variables, comments, valid_id, create_time, create_by, change_time, change_by) '
             . 'VALUES (?, ?, ?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{MacroID}, \$ReferencedMacroID, \$Param{Type}, \$Parameters, \$ResultVariables, \$Param{Comment}, \$Param{ValidID}, \$Param{UserID}, \$Param{UserID}
        ],
    );

    # get new id
    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM macro_action WHERE macro_id = ? and type = ? ORDER BY id',
        Bind => [
            \$Param{MacroID}, \$Param{Type},
        ]
    );

    # fetch the result
    my $ID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ID = $Row[0]
    }

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'Macro.MacroAction',
        ObjectID  => $Param{MacroID}.'::'.$ID,
    );

    return $ID;
}

=item MacroActionUpdate()

updates an MacroAction

    my $Success = $AutomationObject->MacroActionUpdate(
        ID              => 123,
        MacroID         => 123,                                      # optional
        Type            => 'test',                                   # optional
        Parameters      => HashRef,                                  # optional
        ResultVariables => HashRef,                                  # optional
        Comment         => '...',                                    # optional
        ValidID         => 1,                                        # optional
        UserID          => 123,
    );

=cut

sub MacroActionUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID UserID)) {
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

    # get current data
    my %Data = $Self->MacroActionGet(
        ID => $Param{ID},
    );

    # validate parameters if given
    if ( $Param{Parameters} ) {
        # get macro data
        my %Macro = $Self->MacroGet(
            ID => $Param{MacroID} || $Data{MacroID}
        );
        if ( !%Macro ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Macro with ID $Data{MacroID} doesn't exist!"
                );
            }
            return;
        }

        # validate Parameters
        my $BackendObject = $Self->_LoadMacroActionTypeBackend(
            MacroType => $Macro{Type},
            Name      => $Param{Type} || $Data{Type},
        );
        return if !$BackendObject;

        my $IsValid = $BackendObject->ValidateConfig(
            Config => $Param{Parameters},
            Silent => $Param{Silent},
        );

        if ( !$IsValid ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "MacroAction config is invalid!"
                );
            }
            return;
        }
    }

    # set default value
    $Param{Comment} //= $Param{Comment} || '';
    $Param{MacroID} ||= $Data{MacroID};
    $Param{Type}    ||= $Data{Type};
    $Param{ValidID} ||= $Data{ValidID};
    $Param{ResultVariables} //= $Data{ResultVariables};
    $Param{Parameters}      //= $Data{Parameters};

    # check if update is required
    my $ChangeRequired;
    KEY:
    for my $Key ( qw(MacroID Type Parameters ResultVariables Comment ValidID) ) {

        next KEY if defined $Data{$Key} && defined $Param{Key} && $Data{$Key} eq $Param{$Key};

        $ChangeRequired = 1;

        last KEY;
    }

    return 1 if !$ChangeRequired;

    my $ReferencedMacroID = $Param{Parameters}->{MacroID};
    return if !$Self->_ReferencedMacroCheck(
        MacroID           => $Param{MacroID},
        ReferencedMacroID => $ReferencedMacroID,
        Silent            => $Param{Silent},
    );

    # prepare Parameters as JSON
    my $Parameters;
    if ( $Param{Parameters} ) {
        $Parameters = $Kernel::OM->Get('JSON')->Encode(
            Data => $Param{Parameters}
        );
    }

    # prepare ResultVariables as JSON
    my $ResultVariables;
    if ( $Param{ResultVariables} ) {
        $ResultVariables = $Kernel::OM->Get('JSON')->Encode(
            Data => $Param{ResultVariables}
        );
    }

    # update MacroAction in database
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE macro_action SET macro_id = ?, referenced_macro_id = ?, type = ?, parameters = ?, result_variables = ?, comments = ?, valid_id = ?, change_time = current_timestamp, change_by = ? WHERE id = ?',
        Bind => [
            \$Param{MacroID}, \$ReferencedMacroID, \$Param{Type}, \$Parameters, \$ResultVariables, \$Param{Comment}, \$Param{ValidID}, \$Param{UserID}, \$Param{ID}
        ],
    );

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'MacroAction',
        ObjectID  => $Param{ID},
    );

    return 1;
}

=item MacroActionList()

returns a hash of all MacroActions to a given MacroID

    my %MacroActions = $AutomationObject->MacroActionList(
        MacroID => 123,
        Valid   => 1          # optional
    );

the result looks like

    %MacroActions = (
        1 => 'test',
        2 => 'dummy',
        3 => 'domesthing'
    );

=cut

sub MacroActionList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(MacroID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    # set default value
    my $Valid = $Param{Valid} ? 1 : 0;

    # create cache key
    my $CacheKey = 'MacroActionList::' . $Param{MacroID} . '::' . $Valid;

    # read cache
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    my $SQL = 'SELECT id, type FROM macro_action WHERE macro_id = ?';

    if ( $Param{Valid} ) {
        $SQL .= ' AND valid_id = 1'
    }

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => $SQL,
        Bind => [
            \$Param{MacroID}
        ]
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

=item MacroActionDelete()

deletes an MacroAction

    my $Success = $AutomationObject->MacroActionDelete(
        ID => 123,
    );

=cut

sub MacroActionDelete {
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

    # check if this macro_action exists
    my %Data = $Self->MacroActionGet(
        ID     => $Param{ID},
        Silent => $Param{Silent} || 0
    );
    if ( !IsHashRefWithData(\%Data) ) {
        if (
            !defined $Param{Silent}
            || !$Param{Silent}
        ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "An macro action with the ID $Param{ID} does not exist.",
            );
        }
        return;
    }

    # delete log entries
    return if !$Self->LogDelete(
        MacroActionID => $Param{ID},
    );

    # get database object
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'DELETE FROM macro_action WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # delete sub macro (after action, because referenced_macro_id is a foreign key)
    if (
        $Data{ReferencedMacroID} &&
        $Self->MacroIsDeletable(
            ID => $Data{ReferencedMacroID}
        )
    ) {
        my $Success = $Self->MacroDelete(
            ID => $Data{ReferencedMacroID}
        );
        if (!$Success) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Could not delete sub macro ($Data{ReferencedMacroID}) of deleted macro action!",
            );
        }
    }

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'MacroAction',
        ObjectID  => $Param{ID},
    );

    return 1;

}

=item MacroActionListDelete()

deletes MacroActions of a Macro

    my $Success = $AutomationObject->MacroActionListDelete(
        MacroID => 123,
    );

=cut

sub MacroActionListDelete {
    my ( $Self, %Param ) = @_;

    # get all macro actions
    my %MacroActionList = $Self->MacroActionList(
        MacroID => $Param{MacroID},
        Valid   => 0,
    );

    if (IsHashRefWithData(\%MacroActionList)) {
        for my $ActionID (keys %MacroActionList) {
            return if !$Self->MacroActionDelete(
                ID => $ActionID
            );
        }
    }

    return 1;
}

=item MacroActionExecute()

executes a macro action

    my $Success = $AutomationObject->MacroActionExecute(
        ID     => 123,       # the ID of the macro action
        UserID => 1
        ....
    );

=cut

sub MacroActionExecute {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ID UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # add MacroActionID for log reference
    $Self->{MacroActionID} = $Param{ID};

    # get MacroAction data
    my %MacroAction = $Self->MacroActionGet(
        ID => $Param{ID}
    );

    if ( !%MacroAction ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No such macro action with ID $Param{ID}!"
        );
        return;
    }

    # return success if action has been marked to be skipped
    if ( $MacroAction{ValidID} != 1 ) {
        $Self->LogInfo(
            Message  => "Macro action \"$MacroAction{Type}\" has been marked to be skipped.",
            UserID   => $Param{UserID},
        );
        return 1;
    }

    # get macro to determine type
    my %Macro = $Self->MacroGet(
        ID => $MacroAction{MacroID}
    );

    if ( !%Macro ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No such macro with ID $MacroAction{MacroID}!"
        );
        return;
    }

    # load type backend module
    my $BackendObject = $Self->_LoadMacroActionTypeBackend(
        MacroType => $Macro{Type},
        Name      => $MacroAction{Type},
    );
    return if !$BackendObject;

    # call init for backend
    $BackendObject->Init();

    # add referrer data
    for my $CommonParam ( qw(JobID RunID MacroID MacroActionID) ) {
        $BackendObject->{$CommonParam} = $Self->{$CommonParam};
    }

    # fallback if not already known
    $Self->{MacroResults} //= {
        RootObjectID => $Self->{RootObjectID},
        ObjectID     => $Param{ObjectID},
        EventData    => $Self->{EventData}
    };

    # we need the result variables and macro results for the assignments
    $BackendObject->{MacroResults} = $Self->{MacroResults};
    $BackendObject->{ResultVariables} = $MacroAction{ResultVariables} || {};

    # add root object id
    $BackendObject->{RootObjectID} = $Self->{RootObjectID};

    # add event data
    $BackendObject->{EventData} = $Self->{EventData};

    do {
        # unset RepeatExecution of backend
        $BackendObject->UnsetRepeatExecution();

        my %Parameters = %{$MacroAction{Parameters} || {}};

        # set defaults - do it now if variables are used as defaults
        $BackendObject->SetDefaults(
            Config => \%Parameters
        );

        # replace result variables
        if (IsHashRefWithData($Self->{MacroResults})) {
            $Self->_ReplaceResultVariables(
                Data   => \%Parameters,
                UserID => $Param{UserID}
            );
        }

        my $Success = $BackendObject->Run(
            %Param,
            MacroType         => $Macro{Type},
            Config            => \%Parameters,
            ConfigRaw         => \%{$MacroAction{Parameters} || {}},
        );

        if ( !$Success ) {
            # get last error message from system log
            my $Message = $Kernel::OM->Get('Log')->GetLogEntry(
                Type => 'error',
                What => 'Message',
            );
            $Self->LogError(
                Message  => "Macro action \"$MacroAction{Type}\" returned execution error.",
                UserID   => $Param{UserID},
            );

            last;
        }
    } while ( $BackendObject->RepeatExecution() );

    # remove MacroActionID from log reference
    delete $Self->{MacroActionID};

    return 1;
}

=item GetAllSubMacros()

collects all IDs of sub macros

    my @Result = $AutomationObject->GetAllSubMacros();

=cut

sub GetAllSubMacros {
    my ( $Self, %Param ) = @_;

    # create cache key
    my $CacheKey = 'GetAllSubMacros';

    # read cache
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return @{$Cache} if $Cache;

    my $SQL = 'SELECT referenced_macro_id FROM macro_action';

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL => $SQL
    );

    my @SubMacroIDs;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        if ($Row[0]) {
            push(@SubMacroIDs, $Row[0]);
        }
    }

    # remove duplicates
    @SubMacroIDs = $Kernel::OM->Get('Main')->GetUnique(@SubMacroIDs);

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        Key   => $CacheKey,
        Value => \@SubMacroIDs,
        TTL   => $Self->{CacheTTL},
    );

    return @SubMacroIDs;
}

=item GetAllSubMacrosOf()

collects all IDs of sub macros of a macro list

    my @Result = $AutomationObject->GetAllSubMacrosOf(
        MacroIDs  => [1,2,3],        # the IDs of the macro which should contain the sub macros
        Recursive => 0               # if only children or grandchildren and so on should be considered - default is 1
    );

=cut

sub GetAllSubMacrosOf {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(MacroIDs)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my @SubMacroIDs;

    $Param{Recursive} //= 1;

    if (IsArrayRefWithData($Param{MacroIDs})) {
        my $IDString = join q{,}, map {'?'} @{ $Param{MacroIDs} };
        my @Bind     = map { \$_ } @{ $Param{MacroIDs} };

        my $SQL = "SELECT referenced_macro_id FROM macro_action WHERE macro_id IN ($IDString)";

        return if !$Kernel::OM->Get('DB')->Prepare(
            SQL => $SQL,
            Bind => \@Bind
        );

        while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
            if ($Row[0]) {
                push(@SubMacroIDs, $Row[0]);
            }
        }

        # remove duplicates
        @SubMacroIDs = $Kernel::OM->Get('Main')->GetUnique(@SubMacroIDs);

        # go deeper if requested
        if ($Param{Recursive} && IsArrayRefWithData(\@SubMacroIDs)) {
            my @ChildSubMacroIDs = $Self->GetAllSubMacrosOf(
                MacroIDs  => \@SubMacroIDs
            );

            if (IsArrayRefWithData(\@ChildSubMacroIDs)) {
                push(@SubMacroIDs, @ChildSubMacroIDs);
            }
        }
    }

    # remove duplicates
    @SubMacroIDs = $Kernel::OM->Get('Main')->GetUnique(@SubMacroIDs);

    return @SubMacroIDs;
}

=item MacroActionDump()

gets the "script code" of a macro action

    my $Code = $AutomationObject->MacroActionDump(
        ID => 123,       # the ID of the macro action
    );

=cut

sub MacroActionDump {
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

    my %MacroAction = $Self->MacroActionGet(
        ID => $Param{ID}
    );
    if ( !%MacroAction ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "MacroAction with ID $Param{ID} not found!"
        );
        return;
    }

    my $Script = $MacroAction{Type};

    if ( $MacroAction{Comment} ) {
        my $Comment = $MacroAction{Comment};
        $Comment =~ s/"/\\\"/g;
        $Script .= " --Comment \"$Comment\"";
    }

    foreach my $ResultVariable ( sort keys %{$MacroAction{ResultVariables} || {}} ) {
        $Script .= " --Result $ResultVariable:$MacroAction{ResultVariables}->{$ResultVariable}";
    }
    foreach my $Parameter ( sort keys %{$MacroAction{Parameters} || {}} ) {
        my $Value = $MacroAction{Parameters}->{$Parameter};
        if ( IsArrayRef($Value) || IsHashRef($Value) ) {
            $Value = $Kernel::OM->Get('JSON')->Encode(
                Data => $Value
            );
        }
        if ( $Parameter ne 'MacroID' ) {
            $Value =~ s/"/\\\"/g;
            $Script .= " --$Parameter \"$Value\"";
        }
    }
    # dump the macro if we have a reference
    if ( $MacroAction{Parameters}->{MacroID} ) {
        $Script .= "\n";
        my $MacroCode = $Self->MacroDump(
            ID => $MacroAction{Parameters}->{MacroID},
        );
        foreach my $Line ( split /\n/, $MacroCode) {
            $Script .= $Self->{DumpConfig}->{Indent}.$Line . "\n";
        }
    }

    return $Script;
}

sub _ReferencedMacroCheck {
    my ( $Self, %Param ) = @_;

    if ($Param{ReferencedMacroID}) {
        if ($Param{MacroID} == $Param{ReferencedMacroID}) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Cannot use current macro ($Param{ReferencedMacroID}) as sub macro (child) of itself)!"
                );
            }
            return;
        }
        if (
            !$Self->MacroLookup(
                ID => $Param{ReferencedMacroID}
            )
        ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Referenced macro does not exists!"
                );
            }
            return;
        }
        if (
            $Self->IsSubMacroOf(
                ID     => $Param{MacroID},
                IDList => [$Param{ReferencedMacroID}]
            )
        ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Cannot use parent macro ($Param{ReferencedMacroID}) as sub macro (child) of current macro ($Param{MacroID})!"
                );
            }
            return;
        }
    }

    return 1;
}

sub _LoadMacroActionTypeBackend {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(MacroType Name)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    $Self->{MacroActionTypeModules} //= {};

    if ( !$Self->{MacroActionTypeModules}->{$Param{MacroType}} || !$Self->{MacroActionTypeModules}->{$Param{MacroType}}->{$Param{Name}} ) {
        # load backend modules
        my $Backends = $Kernel::OM->Get('Config')->Get('Automation::MacroActionType::'.$Param{MacroType});

        # fallback to Common
        if ( !IsHashRefWithData($Backends) || !IsHashRefWithData($Backends->{$Param{Name}}) ) {
            $Backends = $Kernel::OM->Get('Config')->Get('Automation::MacroActionType::Common');

            if ( !IsHashRefWithData($Backends) ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "No macro action backend modules for macro type \"$Param{MacroType}\" found!",
                );
                return;
            }
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

        # give the macro action backend module it's own config to work with
        $BackendObject->{ModuleConfig} = $Backends->{$Param{Name}};
        $BackendObject->{Debug}        = $Self->{Debug};

        $Self->{MacroActionTypeModules}->{$Param{MacroType}}->{$Param{Name}} = $BackendObject;
    }

    return $Self->{MacroActionTypeModules}->{$Param{MacroType}}->{$Param{Name}};
}

# recursively replace result variables
sub _ReplaceResultVariables {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Data};

    if ( IsHashRefWithData($Param{Data}) ) {
        foreach my $Key ( sort keys %{$Param{Data}} ) {
            $Param{Data}->{$Key} = $Self->_ReplaceResultVariables(
                Data   => $Param{Data}->{$Key},
                UserID => $Param{UserID}
            );
        }
    }
    elsif ( IsArrayRefWithData($Param{Data}) ) {
        foreach my $Item ( @{$Param{Data}} ) {
            $Item = $Self->_ReplaceResultVariables(
                Data   => $Item,
                UserID => $Param{UserID}
            );
        }
    }
    else {
        # init index for temp variables
        my $VariableFilterValueIndex = 0;

        # let leading be greedy - start with innermost variable
        while ( $Param{Data} =~ /^(.*)(\$\{([a-zA-Z0-9_.,: ]+)(?:\|(.*?))?\})(.*?)$/xs ) {
            my $Leading    = $1;
            my $Expression = $2;
            my $Variable   = $3;
            my $Filter     = $4;
            my $Trailing   = $5;

            my $Value = $Kernel::OM->Get('Main')->ResolveValueByKey(
                Key  => $Variable,
                Data => $Self->{MacroResults},
            );

            if ( $Filter ) {
                $Value = $Self->_ExecuteVariableFilters(
                    Data   => $Value,
                    Filter => $Filter,
                    UserID => $Param{UserID}
                );
            }

            # variable is part of a string, we have to do a string replace
            if ( $Leading || $Trailing ) {
                # value is a data structure, replace with temp variable
                if ( ref( $Value ) ) {
                    # increment index
                    $VariableFilterValueIndex += 1;

                    # store value in MacroResults
                    $Self->{MacroResults}->{VariableFilterValue}->{ $VariableFilterValueIndex } = $Value;

                    # replace current variable with variable filter value
                    $Param{Data} =~ s/\Q$Expression\E/<VariableFilterValue$VariableFilterValueIndex>/gxs;
                }
                # replace value as string
                else {
                    $Param{Data} =~ s/\Q$Expression\E/$Value/gxs;
                }
            }
            else {
                # variable is an assignment, we can replace it with the actual value (i.e. Object)
                $Param{Data} = $Value;
            }
        }

        # remove temp variables from MacroResult
        delete( $Self->{MacroResults}->{VariableFilterValue} );
    }

    return $Param{Data};
}

sub _ExecuteVariableFilters {
    my ( $Self, %Param ) = @_;

    return $Param{Data} if !$Param{Filter};

    my @Filters = split(/\|/, $Param{Filter});

    my $Value = $Param{Data};

    foreach my $Filter ( @Filters ) {
        next if !$Filter;

        if ( $Filter =~ /^(?:JSON|ToJSON)$/i ) {
            if ( defined( $Value ) ) {
                $Value = $Kernel::OM->Get('JSON')->Encode(
                    Data => $Value
                );
                $Value =~ s/^"//;
                $Value =~ s/"$//;
            }
            else {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "\"$Filter\" need defined data!"
                );
            }
        }
        elsif ( $Filter =~ /^FromJSON$/i ) {
            if ( IsStringWithData( $Value ) ) {
                $Value = $Kernel::OM->Get('JSON')->Decode(
                    Data => $Value
                );
            }
            else {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "\"$Filter\" need string with data!"
                );
            }
        }
        elsif ( $Filter =~ /^jq\((.*)\)$/i ) {
            my $JqExpression = $1;
            if ( $JqExpression ) {
                if ( IsStringWithData( $Value ) ) {
                    $JqExpression =~ s/\s+::\s+/|/g;
                    $JqExpression =~ s/&quot;/"/g;
                    $Value = `echo '$Value' | jq -r '$JqExpression'`;
                    chomp $Value;

                    # special characters must be re-encoded because the result is decoded twice after the system call
                    $Kernel::OM->Get('Encode')->EncodeInput( \$Value );
                }
                else {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => "\"$Filter\" need string with data!"
                    );
                }
            }
            else {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "\"$Filter\" has no jq expression!"
                );
            }
        }
        elsif ( $Filter =~ /^(?:base64|ToBase64)$/i ) {
            if ( defined( $Value ) ) {
                $Value = MIME::Base64::encode_base64($Value);
                $Value =~ s/\n//g;
            }
            else {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "\"$Filter\" need defined data!"
                );
            }
        }
        elsif ( $Filter =~ /^FromBase64$/i ) {
            if ( IsStringWithData( $Value ) ) {
                $Value = MIME::Base64::decode_base64($Value);
            }
            else {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "\"$Filter\" need string with data!"
                );
            }
        }
        elsif (IsHashRefWithData($Self->{VariableFilter})) {
            $Filter =~ s/(?<filter>.+?)\((?<parameter>.+)\)/$+{filter}/;
            my $Parameter = $+{parameter};

            # check for stored variable filter value
            if ( $Parameter =~ m/^<VariableFilterValue([1-9][0-9]*)>$/xms ) {
                my $VariableFilterValueIndex = $1;
                $Parameter = $Kernel::OM->Get('Main')->ResolveValueByKey(
                    Key  => $VariableFilterValueIndex,
                    Data => $Self->{MacroResults}->{VariableFilterValue},
                );
            }

            my $Handler;
            for my $HandlerName ( %{$Self->{VariableFilter}} ) {
                if (lc($HandlerName) eq lc($Filter)) {
                    $Handler = $Self->{VariableFilter}->{$HandlerName};
                    last;
                }
            }
            if ($Handler && ref $Handler eq 'CODE') {
                $Value = $Handler->(
                    $Self,
                    Value     => $Value,
                    Parameter => $Parameter
                )
            } else {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unknown filter \"$Filter\"!"
                );
            }
        } else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unknown filter \"$Filter\"!"
            );
        }
    }

    return $Value;
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

