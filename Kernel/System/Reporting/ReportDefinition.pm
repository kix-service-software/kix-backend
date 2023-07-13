# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Reporting::ReportDefinition;

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

Kernel::System::Reporting::ReportDefinition - report definition extension for automation lib

=head1 SYNOPSIS

All Report ReportDefinition functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item ReportDefinitionLookup()

get id for ReportDefinition name

    my $ReportDefinitionID = $ReportingObject->ReportDefinitionLookup(
        Name => '...',
    );

get name for ReportDefinition id

    my $ReportDefinitionName = $ReportingObject->ReportDefinitionLookup(
        ID => '...',
    );

=cut

sub ReportDefinitionLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Name} && !$Param{ID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Got no Name or ID!',
        );
        return;
    }

    # get ExecPLan list
    my %ReportDefinitionList = $Self->ReportDefinitionList(
        Valid => 0,
    );

    return $ReportDefinitionList{ $Param{ID} } if $Param{ID};

    # create reverse list
    my %ReportDefinitionListReverse = reverse %ReportDefinitionList;

    return $ReportDefinitionListReverse{ $Param{Name} };
}

=item ReportDefinitionGet()

returns a hash with the ReportDefinition data

    my %ReportDefinitionData = $ReportingObject->ReportDefinitionGet(
        ID => 2,
    );

This returns something like:

    %ReportDefinitionData = (
        'ID'            => 2,
        'Name'          => 'Test',
        'DataSource'    => 'TicketList',
        'Config'        => { ... },
        'IsPeriodic'    => 1|0,
        'MaxReports'    => ...,
        'Comment'       => '...',
        'ValidID'       => '1',
        'CreateTime'    => '2010-04-07 15:41:15',
        'CreateBy'      => 1,
        'ChangeTime'    => '2010-04-07 15:41:15',
        'ChangeBy'      => 1
    );

=cut

sub ReportDefinitionGet {
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
    my $CacheKey = 'ReportDefinitionGet::' . $Param{ID};
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;
    
    return if !$Kernel::OM->Get('DB')->Prepare( 
        SQL   => "SELECT id, name, datasource, config, is_periodic, max_reports, comments, valid_id, create_time, create_by, change_time, change_by FROM report_definition WHERE id = ?",
        Bind => [ \$Param{ID} ],
    );

    my %Result;

    # fetch the result
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        %Result = (
            ID         => $Row[0],
            Name       => $Row[1],
            DataSource => $Row[2],
            Config     => $Row[3],
            IsPeriodic => $Row[4],
            MaxReports => $Row[5],
            Comment    => $Row[6],
            ValidID    => $Row[7],
            CreateTime => $Row[8],
            CreateBy   => $Row[9],
            ChangeTime => $Row[10],
            ChangeBy   => $Row[11],
        );

        if ( $Result{Config} ) {
            # decode JSON
            $Result{Config} = $Kernel::OM->Get('JSON')->Decode(
                Data => $Result{Config}
            );
        }
    }

    # no data found...
    if ( !%Result ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "ReportDefinition with ID $Param{ID} not found!",
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

=item ReportDefinitionAdd()

adds a new Report ReportDefinition

    my $ID = $ReportingObject->ReportDefinitionAdd(
        Name       => 'test',
        DataSource => 'TicketList',
        Config     => { ... },                      # optional
        IsPeriodic => 0|1,                          # optional
        MaxReports => ...,                          # optional
        Comment    => '...',                        # optional
        ValidID    => 1,                            # optional
        UserID     => 123,
    );

=cut

sub ReportDefinitionAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Name DataSource UserID)) {
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

    $Param{MaxReports} //= 0;
    $Param{IsPeriodic} //= 0;

    # check if this is a duplicate after the change
    my $ID = $Self->ReportDefinitionLookup(
        Name => $Param{Name},
    );
    if ( $ID ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "A report definition with the same name already exists.",
        );
        return;
    }

    # validate and prepare Config as JSON
    my $Config;
    if ( $Param{Config} ) {
        return if !$Self->_ValidateReportDefinition(
            DataSource => $Param{DataSource},
            Config     => $Param{Config}
        );
        $Config = $Kernel::OM->Get('JSON')->Encode(
            Data => $Param{Config}
        );
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # insert
    return if !$DBObject->Do(
        SQL => 'INSERT INTO report_definition (name, datasource, config, is_periodic, max_reports, comments, valid_id, create_time, create_by, change_time, change_by) '
             . 'VALUES (?, ?, ?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Name}, \$Param{DataSource}, \$Config, \$Param{IsPeriodic}, \$Param{MaxReports}, 
            \$Param{Comment}, \$Param{ValidID}, \$Param{UserID}, \$Param{UserID}
        ],
    );

    # get new id
    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM report_definition WHERE name = ?',
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
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'ReportDefinition',
        ObjectID  => $ID,
    );

    return $ID;
}

=item ReportDefinitionUpdate()

updates a report definition

    my $Success = $ReportingObject->ReportDefinitionUpdate(
        ID         => 123,
        Name       => 'test',                       # optional
        DataSource => 'TicketList',                 # optional
        Config     => { ... },                      # optional
        IsPeriodic => 0|1,                          # optional
        MaxReports => ...,                          # optional
        Comment    => '...',                        # optional
        ValidID    => 1,                            # optional
        UserID     => 123,
    );

=cut

sub ReportDefinitionUpdate {
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

    $Param{MaxReports} //= 0;
    $Param{IsPeriodic} //= 0;

    # get current data
    my %Data = $Self->ReportDefinitionGet(
        ID => $Param{ID},
    );

    # check if this is a duplicate after the change
    my $ID = $Self->ReportDefinitionLookup(
        Name => $Param{Name} || $Data{Name},
    );
    if ( $ID && $ID != $Param{ID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "A report definition with the same name already exists.",
        );
        return;
    }

    # validate and prepare Config as JSON
    my $Config;
    if ( $Param{Config} ) {
        return if !$Self->_ValidateReportDefinition(
            DataSource => $Data{DataSource},
            Config     => $Param{Config}
        );

        $Config = $Kernel::OM->Get('JSON')->Encode(
            Data => $Param{Config}
        );
    }

    # set default value
    $Param{Comment} ||= '';

    # check if update is required
    my $ChangeRequired;
    KEY:
    for my $Key ( qw(Name DataSource Config IsPeriodic MaxReports Comment ValidID) ) {

        next KEY if defined $Data{$Key} && $Data{$Key} eq $Param{$Key};

        $ChangeRequired = 1;

        last KEY;
    }

    return 1 if !$ChangeRequired;

    $Param{DataSource} ||= $Data{DataSource};

    # update ReportDefinition in database
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE report_definition SET name = ?, datasource = ?, config = ?, is_periodic = ?, max_reports = ?,'
            .  'comments = ?, valid_id = ?, change_time = current_timestamp, change_by = ? WHERE id = ?',
        Bind => [
            \$Param{Name}, \$Param{DataSource}, \$Config, \$Param{IsPeriodic}, \$Param{MaxReports},
            \$Param{Comment}, \$Param{ValidID}, \$Param{UserID}, \$Param{ID}
        ],
    );

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'ReportDefinition',
        ObjectID  => $Param{ID},
    );

    # cleanup if max reports is configured
    $Self->_RemoveExcessReports(
        DefinitionID => $Param{ID},
    );

    return 1;
}

=item ReportDefinitionList()

returns a hash of all report definitions

    my %ReportDefinitions = $ReportingObject->ReportDefinitionList(
        DataSource => 'TicketList'   # optional
        Valid      => 1              # optional
    );

the result looks like

    %ReportDefinitions = (
        1 => 'test',
        2 => 'dummy',
        3 => 'domesthing'
    );

=cut

sub ReportDefinitionList {
    my ( $Self, %Param ) = @_;

    # set default value
    my $Valid = $Param{Valid} ? 1 : 0;
    my $DateSource  = $Param{DateSource} ? $Param{DateSource} : '';

    # create cache key
    my $CacheKey = 'ReportDefinitionList::' . $Valid . '::' . $DateSource;

    # read cache
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    my $SQL = 'SELECT id, name FROM report_definition WHERE 1=1';

    if ( $Param{Valid} ) {
        $SQL .= ' AND valid_id = 1';
    }

    my @Bind;
    if ( $Param{DateSource} ) {
        $SQL .= ' AND datasource = ?';
        push @Bind, \$DateSource;
    }

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => $SQL,
        Bind => \@Bind,
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

=item ReportDefinitionDelete()

deletes an report definition

    my $Success = $ReportingObject->ReportDefinitionDelete(
        ID => 123,
    );

=cut

sub ReportDefinitionDelete {
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

    # check if this report definition exists
    my $ID = $Self->ReportDefinitionLookup(
        ID => $Param{ID},
    );
    if ( !$ID ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "A report definition with the ID $Param{ID} does not exist.",
        );
        return;
    }

    # delete reports for this definition
    my @ReportList = $Self->ReportList(
        DefinitionID => $Param{ID}
    );
    foreach my $ReportID ( @ReportList ) {
        my $Success = $Self->ReportDelete(
            ID => $ReportID
        );
        if ( !$Success ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to delete report with ID $ReportID!",
            );
        }
    }

    # remove from database
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'DELETE FROM report_definition WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'ReportDefinition',
        ObjectID  => $Param{ID},
    );

    return 1;

}

=item ReportDefinitionValidateParameters()

validate the given parameters

    my $IsValid = $ReportingObject->ReportDefinitionValidateParameters(
        Config     => { ... }
    );

=cut

sub ReportDefinitionValidateParameters {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Config)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    if ( exists $Param{Config}->{Parameters} && !IsArrayRefWithData($Param{Config}->{Parameters}) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No parameters defined!"
        );
        return;
    }

    my %Parameters = map { $_->{Name} => $_ } @{$Param{Config}->{Parameters} || []};

    # check if we have a parameter in the data source config which is not defined in the parameters config
    my $FlatConfig = $Kernel::OM->Get('Main')->Flatten(
        Data => $Param{Config}->{DataSource}
    );
    foreach my $Key ( keys %{$FlatConfig} ) {
        next if $FlatConfig->{$Key} !~ /\$\{Parameters.(\w+)\}/;
        my $Parameter = $1;

        if ( !exists $Parameters{$Parameter} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Parameter \"$Parameter\" used but not defined!"
            );
            return;
        }

        # validate parameter config
        foreach my $Required ( qw(Name DataType) ) {
            if ( !$Parameters{$Parameter}->{$Required} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Definition for parameter \"$Parameter\" invalid - \"$Required\" missing!"
                );
                return;
            }
        }

        if ( $Parameters{$Parameter}->{DataType} !~ /^(STRING|NUMERIC|DATE|TIME|DATETIME)$/gi ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Definition for parameter \"$Parameter\" invalid - unsupported DataType \"$Parameters{$Parameter}->{DataType}\"!"
            );
            return;
        }
    }

    return 1;
}

sub _ValidateReportDefinition {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(DataSource Config)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my $IsValid = $Self->DataSourceValidateConfig(
        Source => $Param{DataSource},
        Config => $Param{Config}
    );

    if ( !$IsValid ) {
        my $LogMessage = $Kernel::OM->Get('Log')->GetLogEntry(
            Type => 'error',
            What => 'Message',
        );
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Report definition config for given data source is invalid! ($LogMessage)"
        );
        return;
    }

    foreach my $OutputFormat ( sort keys %{$Param{Config}->{OutputFormats} || {}} ) {
        my $IsValid = $Self->OutputFormatValidateConfig(
            Format     => $OutputFormat,
            Config     => $Param{Config}->{OutputFormats}->{$OutputFormat} || {},
        );
        if ( !$IsValid ) {
            my $LogMessage = $Kernel::OM->Get('Log')->GetLogEntry(
                Type => 'error',
                What => 'Message',
            );
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Report definition config for output format \"$OutputFormat\" is invalid! ($LogMessage)"
            );
            return;
        }
    }

    $IsValid = $Self->ReportDefinitionValidateParameters(
        Config => $Param{Config}
    );
    if ( !$IsValid ) {
        my $LogMessage = $Kernel::OM->Get('Log')->GetLogEntry(
            Type => 'error',
            What => 'Message',
        );
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Parameter definition config is invalid! ($LogMessage)"
        );
        return;
    }

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
