# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Reporting::Report;

use strict;
use warnings;

use Digest::MD5;

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

Kernel::System::Reporting::Report - report extension for reporting lib

=head1 SYNOPSIS

All report functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item ReportGet()

returns a hash with the report data

    my %ReportData = $ReportingObject->ReportGet(
        ID             => 2,
        IncludeResults => 0|1,            # optional, default: 0
        IncludeResultContent => 0|1,      # optional, default: 0
    );

This returns something like:

    %ReportData = (
        'ID'           => 2,
        'DefinitionID' => 123
        'Config'       => {},
        'Parameters'   => {},
        'Results'      => [],                         # if parameter "IncludeResults" is 1
        'CreateTime'   => '2010-04-07 15:41:15',
        'CreateBy'     => 1,
    );

=cut

sub ReportGet {
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

    my $IncludeResults = $Param{IncludeResults};
    $IncludeResults //= 0;

    # check cache
    my $CacheKey = 'ReportGet::' . $Param{ID}.'::'.$IncludeResults;
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL   => "SELECT id, definition_id, config, create_time, create_by FROM report WHERE id = ?",
        Bind => [ \$Param{ID} ],
    );

    my %Result;

    # fetch the result
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        %Result = (
            ID              => $Row[0],
            DefinitionID    => $Row[1],
            Config          => $Row[2],
            CreateTime      => $Row[3],
            CreateBy        => $Row[4],
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
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Report with ID $Param{ID} not found!",
            );
        }
        return;
    }

    if ( $Param{IncludeResults} ) {
        $Result{Results} //= [];

        my @ReportResultList = $Self->ReportResultList(
            ReportID => $Param{ID}
        );

        foreach my $ResultID ( @ReportResultList ) {
            my %ResultData = $Self->ReportResultGet(
                ID             => $ResultID,
                IncludeContent => $Param{IncludeResultContent}
            );
            if ( !%ResultData ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unable to get report result with ID $ResultID!",
                );
            }
            push @{$Result{Results}}, \%ResultData;
        }
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

=item ReportCreate()

create a new report

    my $ID = $ReportingObject->ReportCreate(
        DefinitionID  => 123
        Config        => HashRef,
        UserID        => 123,
    );

parameter "Parameters" has to have the following structure:

    Config => {
        Parameters => {                                              # optional
            # specific parameters for the data source
            ...
        },
        OutputFormats => [ 'CSV', 'PDF' ]   # the report should be created for these two output formats
    }

=cut

sub ReportCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(DefinitionID Config UserID)) {
        if ( !$Param{$Needed} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!"
                );
            }
            return;
        }
    }

    # get definition
    my %Definition = $Self->ReportDefinitionGet(
        ID => $Param{DefinitionID}
    );
    if ( !%Definition ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Report definition with ID $Param{DefinitionID} doesn't exist!"
            );
        }
        return;
    }

    return if !$Self->_ValidateReport(
        Definition => \%Definition,
        %Param,
    );

    # prepare Config as JSON
    my $Config;
    if ( $Param{Config} ) {
        $Config = $Kernel::OM->Get('JSON')->Encode(
            Data => $Param{Config}
        );
    }

    # prepare parameters
    my %Parameters;
    if ( IsHashRefWithData($Param{Config}->{Parameters}) ) {
        %Parameters = %{$Param{Config}->{Parameters}};
    }
    # add defaults for all missing parameters
    if ( IsArrayRefWithData($Definition{Config}->{Parameters}) ) {
        foreach my $Parameter ( @{$Definition{Config}->{Parameters}} ) {
            next if exists $Parameters{$Parameter->{Name}};
            next if ! exists $Parameter->{Default};

            $Parameters{$Parameter->{Name}} = $Parameter->{Default};
        }
    }

    # get data from data source
    my $Data = $Self->DataSourceGetData(
        Source     => $Definition{DataSource},
        Config     => $Definition{Config} || {},
        Parameters => \%Parameters,
        UserID     => $Param{UserID},
    );
    if ( !IsHashRefWithData($Data) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to create report! Datasource backend didn't return anything useful!"
            );
        }
        return;
    }
    if ( IsHashRefWithData($Data->{Columns}) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to create report! Datasource backend didn't return any column information!"
            );
        }
        return;
    }

    # init data with empty array if not given (fallback to produce empty report)
    $Data->{Data} = [] if !IsArrayRef($Data->{Data});

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # insert
    return if !$DBObject->Do(
        SQL => 'INSERT INTO report (definition_id, config, create_time, create_by) '
             . 'VALUES (?, ?, current_timestamp, ?)',
        Bind => [
            \$Param{DefinitionID}, \$Config, \$Param{UserID}
        ],
    );

    # get new id
    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM report WHERE definition_id = ? and create_by = ? ORDER BY id desc',
        Bind => [
            \$Param{DefinitionID}, \$Param{UserID},
        ],
        Limit => 1,
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
        Namespace => 'ReportDefinition.Report',
        ObjectID  => $Param{DefinitionID} . '::' . $ID,
    );

    # cleanup if max reports is configured
    $Self->_RemoveExcessReports(
        DefinitionID => $Param{DefinitionID},
    );

    my @OutputFormats;
    if ( IsHashRefWithData($Definition{Config}->{OutputFormats}) ) {
        OUTPUTFORMAT:
        foreach my $OutputFormat ( @{$Param{Config}->{OutputFormats}} ) {
            next OUTPUTFORMAT if !$Definition{Config}->{OutputFormats}->{$OutputFormat};
            push @OutputFormats, $OutputFormat;
        }
    }
    else {
        # if no explicit config is given in the definition, we just use the requested formats
        @OutputFormats = @{$Param{Config}->{OutputFormats}}
    }

    if ( !@OutputFormats ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No output formats available for report!"
            );
        }
        return;
    }

    # create results
    OUTPUTFORMAT:
    foreach my $OutputFormat ( @OutputFormats ) {
        # generate the output for this format
        my $Output = $Self->GenerateOutput(
            Format     => $OutputFormat,
            Config     => $Definition{Config} || {},
            Parameters => \%Parameters,
            Data       => $Data,
        );
        if ( !IsHashRefWithData($Output) ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unable to generate output for format \"$OutputFormat\"!"
                );
            }
            next OUTPUTFORMAT;
        }

        # store the generated output as a report result in DB
        my $Success = $Self->ReportResultAdd(
            ReportID => $ID,
            Format   => $OutputFormat,
            UserID   => $Param{UserID},
            %{$Output},
        );
        if ( !$Success ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unable to store output for format \"$OutputFormat\" in database!"
                );
            }
            next OUTPUTFORMAT;
        }
    }

    return $ID;
}

=item ReportList()

returns a list of all ReportIDs for a given DefinitionID

    my @ReportIDs = $ReportingObject->ReportList(
        DefinitionID => 123,    # optional
    );

=cut

sub ReportList {
    my ( $Self, %Param ) = @_;

    # create cache key
    my $CacheKey = 'ReportList::' . ($Param{DefinitionID} || '');

    # read cache
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return @{$Cache} if $Cache;

    my $SQL = 'SELECT id FROM report WHERE 1=1';

    my @Bind;
    if ( $Param{DefinitionID} ) {
        $SQL .= ' AND definition_id = ?';
        push @Bind, \$Param{DefinitionID};
    }

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => $SQL,
        Bind => \@Bind,
    );

    my @Result;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        push @Result, $Row[0];
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

=item ReportDelete()

deletes a report

    my $Success = $ReportingObject->ReportDelete(
        ID     => 123,          # required
        Silent => 0|1           # optional, default 0
    );

=cut

sub ReportDelete {
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

    # check if this report exists
    my %Report = $Self->ReportGet(
        ID => $Param{ID},
    );
    if ( !%Report ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "A report with the ID $Param{ID} does not exist.",
            );
        }
        return;
    }

    # delete results for this report
    my @ReportResultList = $Self->ReportResultList(
        ReportID => $Param{ID}
    );
    foreach my $ResultID ( @ReportResultList ) {
        my $Success = $Self->ReportResultDelete(
            ID => $ResultID
        );
        if ( !$Success ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to delete report result with ID $ResultID!",
            );
        }
    }

    # delete object in database
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'DELETE FROM report WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Report',
        ObjectID  => $Param{ID},
    );

    return 1;

}

sub _ValidateReport {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Definition)) {
        if ( !$Param{$_} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $_!"
                );
            }
            return;
        }
    }

    # validate data source config
    my $IsValid = $Self->DataSourceValidateConfig(
        Source => $Param{Definition}->{DataSource},
        Config => $Param{Definition}->{Config} || {},
    );
    if ( !$IsValid ) {
        if ( !$Param{Silent} ) {
            my $LogMessage = $Kernel::OM->Get('Log')->GetLogEntry(
                Type => 'error',
                What => 'Message',
            );
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "DataSource configuration is invalid! ($LogMessage)"
            );
        }
        return;
    }

    foreach my $OutputFormat ( sort keys %{$Param{Definition}->{Config}->{OutputFormats} || {}} ) {
        my $IsValid = $Self->OutputFormatValidateConfig(
            Format     => $OutputFormat,
            Config     => $Param{Definition}->{Config}->{OutputFormats}->{$OutputFormat} || {},
        );
        if ( !$IsValid ) {
            if ( !$Param{Silent} ) {
                my $LogMessage = $Kernel::OM->Get('Log')->GetLogEntry(
                    Type => 'error',
                    What => 'Message',
                );
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Output format config for \"$OutputFormat\" is invalid! ($LogMessage)"
                );
            }
            return;
        }
    }

    # validate output format parameters / selection
    if ( !IsArrayRefWithData($Param{Config}->{OutputFormats}) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No output formats requested!"
            );
        }
        return;
    }

    # validate if we have a config for each requested output format
    if ( IsHashRefWithData($Param{Definition}->{Config}->{OutputFormats}) ) {
        my @AcceptedOutputFormats;
        OUTPUTFORMAT:
        foreach my $OutputFormat ( @{$Param{Config}->{OutputFormats}} ) {
            if ( !exists $Param{Definition}->{Config}->{OutputFormats}->{$OutputFormat} ) {
                if ( !$Param{Silent} ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'notice',
                        Message  => "Requested output format \"$OutputFormat\" not available for this report! It will be ignored!"
                    );
                }
                next OUTPUTFORMAT;
            }
            push @AcceptedOutputFormats, $OutputFormat;
        }

        if ( !@AcceptedOutputFormats ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "No output formats are available for this report!"
                );
            }
            return;
        }
    }

    # validate report parameters
    if ( IsArrayRefWithData($Param{Definition}->{Config}->{Parameters}) ) {
        $IsValid = $Self->ReportDefinitionValidateParameters(
            Config     => $Param{Definition}->{Config} || {},
            Parameters => $Param{Config}->{Parameters} || {},
        );
        if ( !$IsValid ) {
            if ( !$Param{Silent} ) {
                my $LogMessage = $Kernel::OM->Get('Log')->GetLogEntry(
                    Type => 'error',
                    What => 'Message',
                );
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Report parameters are invalid! ($LogMessage)"
                );
            }
            return;
        }

        # check if all required parameters without defaults are given
        my $Parameters = $Param{Config}->{Parameters} || {};
        foreach my $Parameter ( @{$Param{Definition}->{Config}->{Parameters}} ) {
            next if !$Parameter->{Required} || $Parameter->{Default};

            if ( !exists $Parameters->{$Parameter->{Name}} || !defined $Parameters->{$Parameter->{Name}} ) {
                if ( !$Param{Silent} ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => "Required report parameter \"$Parameter->{Name}\" is missing!"
                    );
                }
                return;
            }
        }
    }

    return 1;
}

sub _RemoveExcessReports {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(DefinitionID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my %Definition = $Self->ReportDefinitionGet(
        ID => $Param{DefinitionID}
    );

    return 1 if !$Definition{MaxReports};

    my @Reports = $Self->ReportList(
        DefinitionID => $Param{DefinitionID}
    );
    @Reports = sort {$a <=> $b} @Reports;

    while ( @Reports > $Definition{MaxReports} ) {
        my $ReportID = shift @Reports;
        $Self->ReportDelete(
            ID     => $ReportID,
            Silent => 1,
        );
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
