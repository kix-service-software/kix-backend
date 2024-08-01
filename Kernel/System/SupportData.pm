# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SupportData;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = qw(
    ClientRegistration
    Cache
    DB
    Log
);

=head1 NAME

Kernel::System::SupportData - collect helpful support data

=head1 SYNOPSIS

Provides functionality to collect support data

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $SupportDataObject = $Kernel::OM->Get('SupportData');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );


    return $Self;
}

=item SupportDataCollect()

collect the support data and return it as a hash

    my %Result = $SupportDataObject->SupportDataCollect();

=cut

sub SupportDataCollect {
    my ( $Self, %Param ) = @_;
    my %Result;

    $Result{Database}            = $Self->_CollectDB();
    $Result{ConcurrentUsers}     = $Self->_CollectConcurrentUsers();
    $Result{Plugins}             = $Self->_CollectPlugins();
    $Result{Config}              = $Self->_CollectConfig();
    $Result{SystemInfo}          = $Self->_CollectSystemInfo();
    $Result{ClientRegistrations} = $Self->_CollectClientRegistrations();
    $Result{Redis}               = $Self->_CollectRedis();
    $Result{LogFile}             = $Self->_CollectLogFileContent();
    $Result{NoticableAPIMetrics} = $Self->_CollectAPIMetrics();
    $Result{ConsoleCommands}     = $Self->_CollectConsoleCommands();

    return %Result;
}

=item SupportDataSend()

collect and send the support data

    my $Success = $SupportDataObject->SupportDataSend();

=cut

sub SupportDataSend {
    my ( $Self, %Param ) = @_;

    my %Data;

    if ( IsHashRefWithData($Param{SupportData}) ) {
        %Data = %{$Param{SupportData}};
    }
    else {
        %Data = $Self->SupportDataCollect();
    }

    my $SupportDataConfig = $Kernel::OM->Get('Config')->Get('SupportData');

    my %AddressList = $Kernel::OM->Get('SystemAddress')->SystemAddressList();

    my $From = $AddressList{(sort keys %AddressList)[0]};

    my $LogFile = delete $Data{LogFile};

    # convert to JSON
    my $DataAsJSON = $Kernel::OM->Get('JSON')->Encode(
        Data => \%Data
    );

    my $Sent = $Kernel::OM->Get('Email')->Send(
        From          => $From,
        To            => $SupportDataConfig->{SendTo},
        Subject       => 'Support Data',
        Charset       => 'utf-8',
        MimeType      => 'text/plain',
        Body          => 'see attachments',
        Attachment   => [
            {
                Filename    => "Systeminfo.json",
                Content     => $DataAsJSON,
                ContentType => "application/json",
                Disposition => 'attachment',
            },
            {
                Filename    => "log.txt",
                Content     => $LogFile->{LastLines},
                ContentType => "text/plain",
                Disposition => 'attachment',
            },
            {
                Filename    => "log_error.txt",
                Content     => $LogFile->{LastErrors},
                ContentType => "text/plain",
                Disposition => 'attachment',
            },
            {
                Filename    => "log_warning.txt",
                Content     => $LogFile->{LastWarnings},
                ContentType => "text/plain",
                Disposition => 'attachment',
            },
            {
                Filename    => "log_debug.txt",
                Content     => $LogFile->{LastDebugs},
                ContentType => "text/plain",
                Disposition => 'attachment',
            },
        ],
    );

    return $Sent;
}

=begin Internal:

=cut

sub _CollectDB {
    my ( $Self, %Param ) = @_;
    my %Result;

    my $DBObject = $Kernel::OM->Get('DB');

    $Result{'DB::Type'}     = $DBObject->{Backend}->{'DB::Type'};
    $Result{'DatabaseHost'} = $Kernel::OM->Get('Config')->Get('DatabaseHost');

    # get size
    my $SQL;
    if ( $DBObject->{Backend}->{'DB::Type'} eq 'postgresql' ) {
        $SQL = 'SELECT pg_size_pretty(pg_database_size(current_database()))';
    }
    elsif ( $DBObject->{Backend}->{'DB::Type'} eq 'mysql' ) {
        $SQL = 'SELECT ROUND((SUM(data_length + index_length) / 1024 / 1024 / 1024),3) FROM information_schema.TABLES';
    }
    $DBObject->Prepare(
        SQL   => $SQL,
        Limit => 1,
    );
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Result{Size} = $Row[0]
    }

    # get db schema
    my $DBSchema = $DBObject->GetSchemaInformation();
    $Result{DBSchema} = $DBSchema;

    # get all table counts
    TABLE:
    foreach my $Table ( sort keys %{$DBSchema} ) {
        $Result{Counts}->{$Table} = '???';

        next TABLE if !$DBObject->Prepare(
            SQL => "SELECT count(*) FROM $Table",
            Limit => 1,
        );

        while ( my @Row = $DBObject->FetchrowArray() ) {
            $Result{Counts}->{$Table} = $Row[0]
        }
    }

    # get valid counts
    TABLE:
    foreach my $Table ( sort ('queue', 'organisation', 'contact', 'workflow_ruleset') ) {
        $Result{ValidCounts}->{$Table} = '???';

        next TABLE if !$DBSchema->{$Table};
        next TABLE if !$DBObject->Prepare(
            SQL => "SELECT count(*) FROM $Table WHERE valid_id = 1",
            Limit => 1,
        );

        while ( my @Row = $DBObject->FetchrowArray() ) {
            $Result{ValidCounts}->{$Table} = $Row[0]
        }
    }

    # get special counts
    my @Definition = (
        {
            Key       => 'TicketsByStateType',
            Statement => 'SELECT tst.name, count(t.id) FROM ticket t JOIN ticket_state ts ON ts.id = t.ticket_state_id JOIN ticket_state_type tst ON ts.type_id  = tst.id GROUP BY tst.name',
            Columns   => [ 'StateType', 'Count' ],
        },
        {
            Key       => 'TicketsByQueue',
            Statement => 'SELECT q.name, tst.name, count(t.id) FROM ticket t JOIN queue q ON q.id = t.queue_id JOIN ticket_state ts ON ts.id = t.ticket_state_id JOIN ticket_state_type tst ON ts.type_id = tst.id GROUP BY q.name, tst.name',
            Columns   => [ 'Queue', 'StateType', 'Count' ],
        },
        {
            Key       => 'NewTicketsWithinLast1h',
            Statement => {
                postgresql => 'SELECT count(id) FROM ticket WHERE create_time >= NOW() - \'1 hour\'::INTERVAL',
                mysql      => 'SELECT count(id) FROM ticket WHERE create_time >= NOW() -  INTERVAL 1 HOUR',
            },
            Columns   => [ 'Count' ],
        },
        {
            Key       => 'NewTicketsWithinLast24h',
            Statement => {
                postgresql => 'SELECT count(id) FROM ticket WHERE create_time >= NOW() - \'1 day\'::INTERVAL',
                mysql      => 'SELECT count(id) FROM ticket WHERE create_time >= NOW() -  INTERVAL 1 DAY',
            },
            Columns   => [ 'Count' ],
        },
        {
            Key       => 'NewTicketsWithinLast1w',
            Statement => {
                postgresql => 'SELECT count(id) FROM ticket WHERE create_time >= NOW() - \'1 week\'::INTERVAL',
                mysql      => 'SELECT count(id) FROM ticket WHERE create_time >= NOW() -  INTERVAL 1 WEEK',
            },
            Columns   => [ 'Count' ],
        },
        {
            Key       => 'NewTicketsWithinLast1M',
            Statement => {
                postgresql => 'SELECT count(id) FROM ticket WHERE create_time >= NOW() - \'1 month\'::INTERVAL',
                mysql      => 'SELECT count(id) FROM ticket WHERE create_time >= NOW() -  INTERVAL 1 MONTH',
            },
            Columns   => [ 'Count' ],
        },
        {
            Key       => 'JobCountByLastExecTime',
            Statement => 'SELECT last_exec_time, count(*) FROM job GROUP BY last_exec_time',
            Columns   => [ 'LastExecTime', 'Count' ],
        },
        {
            Key       => 'JobsByLastExecTime',
            Statement => 'SELECT last_exec_time, name FROM job',
            Columns   => [ 'LastExecTime', 'Name' ],
        },
        {
            Key       => 'JobsTimeBased',
            Statement => 'SELECT j.name, ep.parameters FROM job_exec_plan jep JOIN exec_plan ep ON jep.exec_plan_id = ep.id JOIN job j ON j.id = jep.job_id WHERE ep.type = \'TimeBased\' ORDER BY j.id',
            Columns   => [ 'Name', 'Parameters' ],
        },
        {
            Key       => 'JobsOnTicketCreate',
            Statement => 'SELECT j.name, ep.parameters FROM job_exec_plan jep JOIN exec_plan ep ON jep.exec_plan_id = ep.id JOIN job j ON j.id = jep.job_id WHERE ep.type = \'EventBased\' AND ep.parameters like \'%TicketCreate%\' ORDER BY j.id',
            Columns   => [ 'Name', 'Parameters' ],
        },
        {
            Key       => 'JobRunsInWarningState',
            Statement => 'SELECT count(id) FROM job_run WHERE state_id = 3',
            Columns   => [ 'Count' ],
        },
        {
            Key       => 'AutomationLogErrorCount',
            Statement => 'SELECT count(id) FROM automation_log WHERE priority=\'error\'',
            Columns   => [ 'Count' ],
        },
        {
            Key       => 'AgentUsersByValidID',
            Statement => 'SELECT valid_id, count(id) FROM users WHERE is_agent=1 GROUP BY valid_id',
            Columns   => [ 'ValidID', 'Count' ],
        },
        {
            Key       => 'CustomerUsersByValidID',
            Statement => 'SELECT valid_id, count(id) FROM users WHERE is_customer=1 GROUP BY valid_id',
            Columns   => [ 'ValidID', 'Count' ],
        },
    );

    DEFINITION:
    foreach my $Def ( @Definition ) {
        $Result{SpecialCounts}->{$Def->{Key}} = '???';

        my $SQL = $Def->{Statement};
        if ( IsHashRefWithData($SQL) ) {
            $SQL = $SQL->{$DBObject->{Backend}->{'DB::Type'}}
        }
        next DEFINITION if ( !$SQL );

        next DEFINITION if !$DBObject->Prepare(
            SQL => $SQL
        );

        my $Data = $DBObject->FetchAllArrayRef(
            Columns => $Def->{Columns}
        );
        $Result{SpecialCounts}->{$Def->{Key}} = @{$Data} == 1 ? $Data->[0] : $Data;
    }

    return \%Result;
}

sub _CollectConcurrentUsers {
    my ( $Self, %Param ) = @_;
    my %Result;

    for my $Since ( qw(1m 5m 15m) ) {
        my %UniqueUsers = $Kernel::OM->Get('Token')->CountUniqueUsers(
            Since => $Since,
        );
        $Result{$Since} = \%UniqueUsers;
    }

    return \%Result;
}

sub _CollectPlugins {
    my ( $Self, %Param ) = @_;

    my @PluginList = $Kernel::OM->Get('Installation')->PluginList(
        Valid     => 0,
        InitOrder => 1,
    );

    return \@PluginList;
}

sub _CollectConfig {
    my ( $Self, %Param ) = @_;
    my %Result;

    $Result{Local}  = $Kernel::OM->Get('Config')->GetLocalConfig();
    my %AllModified = $Kernel::OM->Get('SysConfig')->ValueGetAll(
        Modified => 1
    );
    $Result{Modified} = \%AllModified;

    return \%Result;
}

sub _CollectSystemInfo {
    my ( $Self, %Param ) = @_;
    my %Result;

    foreach my $Key ( qw(Product Version BuildDate BuildHost BuildNumber PatchNumber) ) {
        $Result{$Key} = $Kernel::OM->Get('Config')->Get($Key);
    }

    use DateTime::TimeZone;
    my $TimeZoneObject = DateTime::TimeZone->new( name => 'local' );
    $Result{TimeZone} = $TimeZoneObject->name();
    $Result{TimeZoneOffset} = $TimeZoneObject->offset_for_datetime(DateTime->now);

    $Result{CPU} = `lscpu`;
    $Result{Memory} = `free`;

    return \%Result;
}

sub _CollectClientRegistrations {
    my ( $Self, %Param ) = @_;
    my @Result;

    my @ClientList = $Kernel::OM->Get('ClientRegistration')->ClientRegistrationList();
    foreach my $ClientID ( sort @ClientList ) {
        my %ClientRegistration = $Kernel::OM->Get('ClientRegistration')->ClientRegistrationGet(
            ClientID => $ClientID
        );
        push @Result, \%ClientRegistration;
    }

    return \@Result;
}

sub _CollectRedis {
    my ( $Self, %Param ) = @_;

    my $Result = $Kernel::OM->Get('Cache')->{CacheObject}->_RedisCall(
        'info',
        'all'
    );

    return $Result;
}

sub _CollectLogFileContent {
    my ( $Self, %Param ) = @_;
    my %Result;

    my $LogFile = $Kernel::OM->Get('Log')->{Backend}->{LogFile};

    $Result{LastLines} = `tail -n 100 $LogFile`;
    $Result{LastErrors} = `grep -a -E '\\[Error\\]' $LogFile | tail -n 100`;
    $Result{LastWarnings} = `grep -a -E '\\[Notice\\]' $LogFile | tail -n 100`;
    $Result{LastDebugs} = `grep -a -E '\\[Debug\\]' $LogFile | tail -n 100`;

    return \%Result;
}

sub _CollectInstallation {
    my ( $Self, %Param ) = @_;
    my %Result;

    my $Home = $Kernel::OM->Get('Config')->Get('Home');

    $Result{DiffFiles} = [ split /\n/, `perl $Home/bin/kix.CheckSum.pl -a compare -b $Home/ARCHIVE -d $Home | sed -e 's/^Notice: Dif //g'` ];

    return \%Result;
}

sub _CollectAPIMetrics {
    my ( $Self, %Param ) = @_;
    my @Result;

    my $Home = $Kernel::OM->Get('Config')->Get('Home');

    # analyze API metrics logs of past 2 days
    my $Today = (split / /, $Kernel::OM->Get('Time')->CurrentTimestamp())[0];
    my $Yesterday = (split / /, $Kernel::OM->Get('Time')->SystemTime2TimeStamp(
        SystemTime => $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
            String => $Today . ' 00:00:00 -1d',
        )
    ))[0];

    my @Files = (
        "$Home/var/log/metrics/api_metrics.log.$Yesterday",
        "$Home/var/log/metrics/api_metrics.log.$Today"
    );

    FILE:
    foreach my $File (@Files) {
        next FILE if ( !-e $File );

        my $Content = $Kernel::OM->Get('Main')->FileRead(
            Location => $File,
            Mode     => 'utf8',
            Result   => 'ARRAY',
        );

        LINE:
        foreach my $Line ( @{$Content||[]} ) {
            chomp $Line;
            my @Columns = split /\t/, $Line;
            next LINE if $Columns[3] < 150;
            push @Result, $Line;
        }
    }

    return \@Result;
}

sub _CollectConsoleCommands {
    my ( $Self, %Param ) = @_;
    my %Result;

    my $Home = $Kernel::OM->Get('Config')->Get('Home');

    my @Definition = (
        'Admin::Role::List',
        'Admin::Automation::Job::List',
        'Admin::Automation::Macro::List',
        'Maint::Daemon::Summary',
    );

    foreach my $Command ( sort @Definition ) {
        $Result{$Command} = `$Home/bin/kix.Console.pl $Command --allow-root `;
    }

    return \%Result;
}

=end Internal:


1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
