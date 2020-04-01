# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Automation::MacroAction;

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
        SQL   => "SELECT id, macro_id, type, parameters, comments, valid_id, create_time, create_by, change_time, change_by FROM macro_action WHERE id = ?",
        Bind => [ \$Param{ID} ],
    );

    my %Result;
    
    # fetch the result
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        %Result = (
            ID         => $Row[0],
            MacroID    => $Row[1],
            Type       => $Row[2],
            Parameters => $Row[3],
            Comment    => $Row[4],
            ValidID    => $Row[5],
            CreateTime => $Row[6],
            CreateBy   => $Row[7],
            ChangeTime => $Row[8],
            ChangeBy   => $Row[9],
        );

        if ( $Result{Parameters} ) {
            # decode JSON
            $Result{Parameters} = $Kernel::OM->Get('JSON')->Decode(
                Data => $Result{Parameters}
            );
        }
    }
    
    # no data found...
    if ( !%Result ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Macro action with ID $Param{ID} not found!",
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

=item MacroActionAdd()

adds a new MacroAction

    my $ID = $AutomationObject->MacroActionAdd(
        MacroID    => 123
        Type       => 'test',
        Parameters => HashRef,                                  # optional
        Comment    => '...',                                    # optional
        ValidID    => 1,                                        # optional
        UserID     => 123,
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
        Config => $Param{Parameters}
    );

    if ( !$IsValid ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "MacroAction config is invalid!"
        );
        return;
    }

    # prepare Parameters as JSON
    my $Parameters;
    if ( $Param{Parameters} ) {
        $Parameters = $Kernel::OM->Get('JSON')->Encode(
            Data => $Param{Parameters}
        );
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # insert
    return if !$DBObject->Do(
        SQL => 'INSERT INTO macro_action (macro_id, type, parameters, comments, valid_id, create_time, create_by, change_time, change_by) '
             . 'VALUES (?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{MacroID}, \$Param{Type}, \$Parameters, \$Param{Comment}, \$Param{ValidID}, \$Param{UserID}, \$Param{UserID}
        ],
    );

    # get new id
    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM macro_action WHERE macro_id = ? and type = ?',
        Bind => [ 
            \$Param{MacroID}, \$Param{Type}, 
        ],
    );

    # fetch the result
    my $ID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ID = $Row[0]
    }

    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp();

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'Macro.MacroAction',
        ObjectID  => $Param{MacroID}.'::'.$ID,
    );

    return $ID;
}

=item MacroActionUpdate()

updates an MacroAction

    my $Success = $AutomationObject->MacroActionUpdate(
        ID         => 123,        
        MacroID    => 123,                                      # optional
        Type       => 'test',                                   # optional
        Parameters => HashRef,                                  # optional
        Comment    => '...',                                    # optional
        ValidID    => 1,                                        # optional
        UserID     => 123,
    );

=cut

sub MacroActionUpdate {
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
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Macro with ID $Data{MacroID} doesn't exist!"
            );
            return;
        }

        # validate Parameters
        my $BackendObject = $Self->_LoadMacroActionTypeBackend(
            MacroType => $Macro{Type},
            Name      => $Param{Type} || $Data{Type},
        );
        return if !$BackendObject;

        my $IsValid = $BackendObject->ValidateConfig(
            Config => $Param{Parameters}
        );

        if ( !$IsValid ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "MacroAction config is invalid!"
            );
            return;
        }
    }

    # set default value
    $Param{Comment} ||= '';

    # check if update is required
    my $ChangeRequired;
    KEY:
    for my $Key ( qw(MacroID Type Parameters Comment ValidID) ) {

        next KEY if defined $Data{$Key} && $Data{$Key} eq $Param{$Key};

        $ChangeRequired = 1;

        last KEY;
    }

    return 1 if !$ChangeRequired;

    $Param{MacroID} ||= $Data{MacroID};
    $Param{Type} ||= $Data{Type};

    # prepare Parameters as JSON
    my $Parameters;
    if ( $Param{Parameters} ) {
        $Parameters = $Kernel::OM->Get('JSON')->Encode(
            Data => $Param{Parameters}
        );
    }

    # update MacroAction in database
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE macro_action SET macro_id = ?, type = ?, parameters = ?, comments = ?, valid_id = ?, change_time = current_timestamp, change_by = ? WHERE id = ?',
        Bind => [
            \$Param{MacroID}, \$Param{Type}, \$Parameters, \$Param{Comment}, \$Param{ValidID}, \$Param{UserID}, \$Param{ID}
        ],
    );

    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp();

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
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
    my $Data = $Self->MacroActionGet( 
        ID => $Param{ID},
    );
    if ( !$Data ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "An macro action with the ID $Param{ID} does not exist.",
        );
        return;
    }

    # get database object
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'DELETE FROM macro_action WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );
   
    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp();

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'MacroAction',
        ObjectID  => $Param{ID},
    );

    return 1;

}

=item MacroActionExecute()

executes a macro action

    my $Success = $AutomationObject->MacroActionExecute(
        ID        => 123,       # the ID of the macro action
        UserID    => 1
        ....
    );

=cut

sub MacroActionExecute {
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

    # add referrer data
    for ( qw(JobID RunID MacroID MacroActionID) ) {
        $BackendObject->{$_} = $Self->{$_};
    }

    my $BackendResult = $BackendObject->Run(
        %Param,
        Config => $MacroAction{Parameters}
    );

    if ( !$BackendResult ) {
        # get last error message from system log
        my $Message = $Kernel::OM->Get('Log')->GetLogEntry(
            Type => 'error',
            What => 'Message',
        );            
        $Self->LogError(
            Message  => "Macro action \"$MacroAction{Type}\" returned execution error.",
            UserID   => $Param{UserID},
        );
    }

    # remove MacroActionID from log reference
    delete $Self->{MacroActionID};

    return $BackendResult;
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
        my $Backend = 'Automation::MacroAction::' . $Param{MacroType} . '::' . $Param{Name};

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

        $Self->{MacroActionTypeModules}->{$Param{MacroType}}->{$Param{Name}} = $BackendObject;
    }

    return $Self->{MacroActionTypeModules}->{$Param{MacroType}}->{$Param{Name}};
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
