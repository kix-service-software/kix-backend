# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Automation::Macro;

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

Kernel::System::Automation::Macro - macro extension for automation lib

=head1 SYNOPSIS

All macro functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item MacroLookup()

get id for macro name

    my $MacroID = $AutomationObject->MacroLookup(
        Name => '...',
    );

get name for macro id

    my $MacroName = $AutomationObject->MacroLookup(
        ID => '...',
    );

=cut

sub MacroLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Name} && !$Param{ID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Got no Name or ID!',
        );
        return;
    }

    # get macro list
    my %MacroList = $Self->MacroList(
        Valid => 0,
    );

    return $MacroList{ $Param{ID} } if $Param{ID};

    # create reverse list
    my %MacroListReverse = reverse %MacroList;

    return $MacroListReverse{ $Param{Name} };
}

=item MacroGet()

returns a hash with the macro data

    my %MacroData = $AutomationObject->MacroGet(
        ID => 2,
    );

This returns something like:

    %MacroData = (
        'ID'         => 2,
        'Type'       => 'Ticket',
        'Name'       => 'Test'
        'ExecOrder'  => [],
        'Comment'    => '...',
        'ValidID'    => '1',
        'CreateTime' => '2010-04-07 15:41:15',
        'CreateBy'   => 1,
        'ChangeTime' => '2010-04-07 15:41:15',
        'ChangeBy'   => 1
    );

=cut

sub MacroGet {
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
    my $CacheKey = 'MacroGet::' . $Param{ID};
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    return if !$Kernel::OM->Get('DB')->Prepare( 
        SQL   => "SELECT id, name, type, exec_order, comments, valid_id, create_time, create_by, change_time, change_by FROM macro WHERE id = ?",
        Bind => [ \$Param{ID} ],
    );

    my %Result;

    # fetch the result
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        %Result = (
            ID         => $Row[0],
            Name       => $Row[1],
            Type       => $Row[2],
            ExecOrder  => $Row[3],
            Comment    => $Row[4],
            ValidID    => $Row[5],
            CreateTime => $Row[6],
            CreateBy   => $Row[7],
            ChangeTime => $Row[8],
            ChangeBy   => $Row[9],
        );

        # prepare ExecOrder
        my @ExecOrder = map {0 + $_} split(/,/, ($Result{ExecOrder} || ''));
        $Result{ExecOrder} = \@ExecOrder;
    }

    # no data found...
    if ( !%Result ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Macro with ID $Param{ID} not found!",
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

=item MacroAdd()

adds a new macro

    my $ID = $AutomationObject->MacroAdd(
        Name       => 'test',
        Type       => 'Ticket',
        Comment    => '...',                                   # optional
        ValidID    => 1,                                       # optional
        UserID     => 123,
    );

=cut

sub MacroAdd {
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
    my $ID = $Self->MacroLookup( 
        Name => $Param{Name},
    );
    if ( $ID ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "A macro with the same name already exists.",
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # insert
    return if !$DBObject->Do(
        SQL => 'INSERT INTO macro (name, type, comments, valid_id, create_time, create_by, change_time, change_by) '
             . 'VALUES (?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Name}, \$Param{Type}, \$Param{Comment}, \$Param{ValidID}, \$Param{UserID}, \$Param{UserID}
        ],
    );

    # get new id
    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM macro WHERE name = ?',
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
        Namespace => 'Macro',
        ObjectID  => $ID,
    );

    return $ID;
}

=item MacroUpdate()

updates a macro

    my $Success = $AutomationObject->MacroUpdate(
        ID         => 123,
        Name       => 'test'
        Type       => 'Ticket',                                 # optional
        ExecOrder  => [],                                       # optional
        Comment    => '...',                                    # optional
        ValidID    => 1,                                        # optional
        UserID     => 123,
    );

=cut

sub MacroUpdate {
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
    my %Data = $Self->MacroGet(
        ID => $Param{ID},
    );

    # check if this is a duplicate after the change
    my $ID = $Self->MacroLookup( 
        Name => $Param{Name} || $Data{Name},
    );
    if ( $ID && $ID != $Param{ID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "A macro with the same name already exists.",
        );
        return;
    }

    # set default value
    $Param{Comment} ||= '';

    # check if update is required
    my $ChangeRequired;
    KEY:
    for my $Key ( qw(Type Name Comment ValidID) ) {

        next KEY if defined $Data{$Key} && $Data{$Key} eq $Param{$Key};

        $ChangeRequired = 1;

        last KEY;
    }

    my $ExecOrder;
    if ( ref $Param{ExecOrder} eq 'ARRAY') {
        $ExecOrder = join(',', @{$Param{ExecOrder}});
        if ( $ExecOrder ne join(',', @{ $Data{ExecOrder} || [] }) ) {
            $ChangeRequired = 1;
        }
    } else {
        $ExecOrder = join(',', @{ $Data{ExecOrder} || [] });
    }

    return 1 if !$ChangeRequired;

    $Param{Type} ||= $Data{Type};

    # update Macro in database
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE macro SET type = ?, name = ?, exec_order = ?, comments = ?, valid_id = ?, change_time = current_timestamp, change_by = ? WHERE id = ?',
        Bind => [
            \$Param{Type}, \$Param{Name}, \$ExecOrder, \$Param{Comment}, \$Param{ValidID}, \$Param{UserID}, \$Param{ID}
        ],
    );

    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp();

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Macro',
        ObjectID  => $Param{ID},
    );

    return 1;
}

=item MacroList()

returns a hash of all macros

    my %Macros = $AutomationObject->MacroList(
        Valid => 1          # optional
    );

the result looks like

    %Macros = (
        1 => 'test',
        2 => 'dummy',
        3 => 'domesthing'
    );

=cut

sub MacroList {
    my ( $Self, %Param ) = @_;

    # set default value
    my $Valid = $Param{Valid} ? 1 : 0;

    # create cache key
    my $CacheKey = 'MacroList::' . $Valid;

    # read cache
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    my $SQL = 'SELECT id, name FROM macro';

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

=item MacroDelete()

deletes a macro

    my $Success = $AutomationObject->MacroDelete(
        ID => 123,
    );

=cut

sub MacroDelete {
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

    # check if this macro exists
    my $ID = $Self->MacroLookup( 
        ID => $Param{ID},
    );
    if ( !$ID ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "A macro with the ID $Param{ID} does not exist.",
        );
        return;
    }

    # delete macro actions
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'DELETE FROM macro_action WHERE macro_id = ?',
        Bind => [ \$Param{ID} ],
    );

    # delete relations with Jobs
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'DELETE FROM job_macro WHERE macro_id = ?',
        Bind => [ \$Param{ID} ],
    );

    # delete macro
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'DELETE FROM macro WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );

    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp();

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Macro',
        ObjectID  => $Param{ID},
    );

    return 1;

}

=item MacroIsExecutable()

checks if a macro is executable. Return 0 or 1.

    my $Result = $AutomationObject->MacroIsExecutable(
        ID       => 123,        # the ID of the macro
        UserID    => 1
    );

=cut

sub MacroIsExecutable {
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

    # get Macro data
    my %Macro = $Self->MacroGet(
        ID => $Param{ID}
    );

    if ( !%Macro ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No such macro with ID $Param{ID}!"
        );
        return;        
    }

    return IsArrayRefWithData($Macro{ExecOrder});
}

=item MacroExecute()

executes a macro

    my $Success = $AutomationObject->MacroExecute(
        ID       => 123,        # the ID of the macro
        ObjectID => 123,        # the ID of the object to execute the macro onto
        UserID    => 1
    );

=cut

sub MacroExecute {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID ObjectID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # add MacroID for log reference
    $Self->{MacroID}  = $Param{ID};
    $Self->{ObjectID} = $Param{ObjectID};

    # get Macro data
    my %Macro = $Self->MacroGet(
        ID => $Param{ID}
    );

    if ( !%Macro ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No such macro with ID $Param{ID}!"
        );
        return;        
    }

    if ( !IsArrayRefWithData($Macro{ExecOrder}) ) {
        $Self->LogInfo(
            Message  => "Macro \"$Macro{Name}\" has no executable actions. Aborting macro execution.",
            UserID   => $Param{UserID},
        );
        return 1;
    }

    $Self->LogInfo(
        Message  => "executing macro \"$Macro{Name}\" with ".(scalar(@{$Macro{ExecOrder}}))." macro actions on ObjectID $Param{ObjectID}.",
        UserID   => $Param{UserID},
    );

    # load type backend module
    my $BackendObject = $Self->_LoadMacroTypeBackend(
        Name => $Macro{Type},
    );
    return if !$BackendObject;

    # add referrer data
    $BackendObject->{MacroID}  = $Param{ID};
    $BackendObject->{ObjectID} = $Param{ObjectID};

    my $BackendResult = $BackendObject->Run(
        ObjectID  => $Param{ObjectID},
        ExecOrder => $Macro{ExecOrder},
        UserID    => $Param{UserID}
    );

    # remove IDs from log reference
    delete $Self->{MacroID};
    delete $Self->{ObjectID};

    return $BackendResult;
}

sub _LoadMacroTypeBackend {
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
    $Self->{MacroTypeModules} //= {};

    if ( !$Self->{MacroTypeModules}->{$Param{Name}} ) {
        my $Backend = 'Automation::Macro::' . $Param{Name};

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

        $Self->{MacroTypeModules}->{$Param{Name}} = $BackendObject;        
    }

    return $Self->{MacroTypeModules}->{$Param{Name}};
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
