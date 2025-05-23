# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DB;

use strict;
use warnings;

use DBI;
use List::Util();
use Time::HiRes qw(time);

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'Encode',
    'Log',
    'Main',
    'Time',
);

our $UseSlaveDB = 0;

=head1 NAME

Kernel::System::DB - global database interface

=head1 SYNOPSIS

All database functions to connect/insert/update/delete/... to a database.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create database object, with database connect..
Usually you do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new(
        'DB' => {
            # if you don't supply the following parameters, the ones found in
            # Kernel/Config.pm are used instead:
            DatabaseDSN  => 'DBI:odbc:database=123;host=localhost;',
            DatabaseUser => 'user',
            DatabasePw   => 'somepass',
            Type         => 'mysql',
            Attribute => {
                LongTruncOk => 1,
                LongReadLen => 100*1024,
            },
        },
    );
    my $DBObject = $Kernel::OM->Get('DB');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    # 0=off; 1=updates; 2=+selects; 3=+Connects;
    $Self->{Debug} = $Param{Debug} || $ConfigObject->Get('DB::Debug');
    $Self->{DebugMethods} = $ConfigObject->Get('DB::Debug::Methods');

    # get config data
    $Self->{DSN}  = $Param{DatabaseDSN}  || $ConfigObject->Get('DatabaseDSN');
    $Self->{USER} = $Param{DatabaseUser} || $ConfigObject->Get('DatabaseUser');
    $Self->{PW}   = $Param{DatabasePw}   || $ConfigObject->Get('DatabasePw');

    $Self->{IsSlaveDB} = $Param{IsSlaveDB};

    $Self->{SlowLog} = $Param{'Database::SlowLog'}
        || $ConfigObject->Get('Database::SlowLog');

    # decrypt pw (if needed)
    if ( $Self->{PW} =~ /^\{(.*)\}$/ ) {
        $Self->{PW} = $Self->_Decrypt($1);
    }

    # get database type (auto detection)
    if ( $Self->{DSN} =~ /:mysql/i ) {
        $Self->{'DB::Type'} = 'mysql';
    }
    elsif ( $Self->{DSN} =~ /:pg/i ) {
        $Self->{'DB::Type'} = 'postgresql';
    }
    elsif ( $Self->{DSN} =~ /:oracle/i ) {
        $Self->{'DB::Type'} = 'oracle';
    }
    elsif ( $Self->{DSN} =~ /:db2/i ) {
        $Self->{'DB::Type'} = 'db2';
    }
    elsif ( $Self->{DSN} =~ /(mssql|sybase|sql server)/i ) {
        $Self->{'DB::Type'} = 'mssql';
    }

    # get database type (config option)
    if ( $ConfigObject->Get('Database::Type') ) {
        $Self->{'DB::Type'} = $ConfigObject->Get('Database::Type');
    }

    # get database type (overwrite with params)
    if ( $Param{Type} ) {
        $Self->{'DB::Type'} = $Param{Type};
    }

    # load backend module
    if ( $Self->{'DB::Type'} ) {
        my $GenericModule = $Kernel::OM->GetModuleFor('DB::' . $Self->{'DB::Type'});
        return if !$Kernel::OM->Get('Main')->Require($GenericModule);
        $Self->{Backend} = $GenericModule->new( %{$Self} );

        # set database functions
        $Self->{Backend}->LoadPreferences();
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'Error',
            Message  => 'Unknown database type! Set option Database::Type in '
                . 'Kernel/Config.pm to (mysql|postgresql|oracle|mssql).',
        );
        return;
    }

    # check/get extra database configuration options
    # (overwrite auto-detection with config options)
    for my $Setting (
        qw(
            Type Limit DirectBlob Attribute QuoteSingle QuoteBack
            Connect Encode CaseSensitive LcaseLikeInLargeText
        )
    ) {
        if (
            defined $Param{$Setting}
            || defined $ConfigObject->Get("Database::$Setting")
        ) {
            $Self->{Backend}->{"DB::$Setting"} = $Param{$Setting}
                // $ConfigObject->Get("Database::$Setting");
        }
    }

    return $Self;
}

=item Connect()

to connect to a database

    $DBObject->Connect();

=cut

sub Connect {
    my $Self   = shift;
    my $Silent = shift;

    # check database handle
    if ( $Self->{dbh} ) {

        my $PingTimeout = 10;        # Only ping every 10 seconds (see bug#12383).
        my $CurrentTime = time();    ## no critic

        if ( $CurrentTime - ( $Self->{LastPingTime} // 0 ) < $PingTimeout ) {
            return $Self->{dbh};
        }

        # Ping to see if the connection is still alive.
        if ( $Self->{dbh}->ping() ) {
            $Self->{LastPingTime} = $CurrentTime;
            return $Self->{dbh};
        }

        # Ping failed: cause a reconnect.
        delete $Self->{dbh};
    }

    my $StartTime;
    if ( $Self->{Debug} && $Self->{DebugMethods}->{Connect} ) {
        $StartTime = Time::HiRes::time();
    }

    # db connect
    $Self->{dbh} = DBI->connect(
        $Self->{DSN},
        $Self->{USER},
        $Self->{PW},
        $Self->{Backend}->{'DB::Attribute'},
    );

    if ( !$Self->{dbh} ) {
        if ( !$Silent ) {
            $Kernel::OM->Get('Log')->Log(
                Caller   => 1,
                Priority => 'Error',
                Message  => $DBI::errstr,
            );
        }
        return;
    }

    if ( $Self->{Backend}->{'DB::Connect'} ) {
        $Self->Do(
            SQL              => $Self->{Backend}->{'DB::Connect'},
            SkipConnectCheck => 1,
        );
    }

    # set utf-8 on for PostgreSQL
    if ( $Self->{Backend}->{'DB::Type'} eq 'postgresql' ) {
        $Self->{dbh}->{pg_enable_utf8} = 1;
    }

    if ( $Self->{SlaveDBObject} ) {
        $Self->{SlaveDBObject}->Connect();
    }

    if ( $Self->{Debug} && $Self->{DebugMethods}->{Connect} ) {
        $Self->_Debug(
            sprintf(
                "Connect [DSN: %s, User: %s, Pw: %s, DB Type: %s] took %i ms",
                $Self->{DSN},
                $Self->{USER},
                $Self->{PW},
                $Self->{'DB::Type'},
                (Time::HiRes::time() - $StartTime) * 1000)
            );
    }

    return $Self->{dbh};
}

=item Disconnect()

to disconnect from a database

    $DBObject->Disconnect();

=cut

sub Disconnect {
    my $Self = shift;

    # do disconnect
    if ( $Self->{dbh} ) {
        $Self->{dbh}->disconnect();
        delete $Self->{dbh};
        delete $Self->{Cursor};
    }

    if ( $Self->{SlaveDBObject} ) {
        $Self->{SlaveDBObject}->Disconnect();
    }

    return 1;
}

=item Version()

to get the database version

    my $DBVersion = $DBObject->Version();

    returns: "MySQL 5.1.1";

=cut

sub Version {
    my ( $Self, %Param ) = @_;

    my $Version = 'unknown';

    if ( $Self->{Backend}->{'DB::Version'} ) {
        $Self->Prepare( SQL => $Self->{Backend}->{'DB::Version'} );
        while ( my @Row = $Self->FetchrowArray() ) {
            $Version = $Row[0];
        }
    }

    return $Version;
}

=item GetSchemaInformation()

get the information about relations and their attributes

    my $DBSchema = $DBObject->GetSchemaInformation();

    returns: a complex structure ;)

=cut

sub GetSchemaInformation {
    my ( $Self, %Param ) = @_;

    my $SchemaInfo;

    $Self->Connect() || die "Unable to connect to database!";

    my $SchemaName = $Self->{'DB::Type'} eq 'postgresql' ? 'public' : undef;
    my $Catalog    = $Self->{'DB::Type'} eq 'postgresql' ? q{} : undef;

    # get tables
    my @Tables = map {
        my $Table = (split(/\./, $_))[1]; $Table =~ s/\`//g; $Table
    } $Self->{dbh}->tables(q{}, $SchemaName, q{}, 'TABLE');

    foreach my $Table ( sort @Tables ) {
        # get column infos
        my $Handle = $Self->{dbh}->column_info( $Catalog, $SchemaName, $Table, undef );
        if ( defined $Handle ) {
            my $ColumnInfos = $Handle->fetchall_arrayref({
                COLUMN_NAME => 1,
                TYPE_NAME => 1,
            });

            $SchemaInfo->{$Table}->{Columns} = [];

            foreach my $Column ( @{$ColumnInfos} ) {
                push(
                    @{$SchemaInfo->{$Table}->{Columns}},
                    {
                        Name => $Column->{COLUMN_NAME},
                        Type => $Column->{TYPE_NAME},
                    }
                );
            }
        }
        else {
            $Self->Prepare(
                SQL   => "SELECT * FROM $Table",
                Limit => 1
            );

            my @ColumnNames = $Self->GetColumnNames();

            $SchemaInfo->{$Table}->{Columns} = [];

            for my $Column ( @ColumnNames ) {
                push (
                    @{$SchemaInfo->{$Table}->{Columns}},
                    {
                        Name => $Column,
                    }
                );
            }
        }

        # get primary key infos
        $Handle = $Self->{dbh}->primary_key_info( $Catalog, $SchemaName, $Table );
        if ( $Handle ) {
            my $PrimaryKeyInfos = $Handle->fetchall_arrayref({COLUMN_NAME => 1});
            $SchemaInfo->{$Table}->{PrimaryKey} = [];

            foreach my $Column ( @{$PrimaryKeyInfos} ) {
                push(
                    @{$SchemaInfo->{$Table}->{PrimaryKey}},
                    $Column->{COLUMN_NAME}
                );
            }
        }

        # get foreign key infos
        $Handle = $Self->{dbh}->foreign_key_info( q{}, $SchemaName, $Table, q{}, $SchemaName, undef );
        if ( $Handle ) {
            my $ForeignKeyInfos = $Handle->fetchall_arrayref({});

            foreach my $Column ( @{$ForeignKeyInfos} ) {
                my $PKColumnName = $Column->{UK_COLUMN_NAME} || $Column->{PKCOLUMN_NAME};
                my $FKColumnName = $Column->{FK_COLUMN_NAME} || $Column->{FKCOLUMN_NAME};
                my $FKTableName  = $Column->{FK_TABLE_NAME}  || $Column->{FKTABLE_NAME};

                $SchemaInfo->{$Table}->{ForeignKeys}->{$PKColumnName} //= [];
                push(
                    @{$SchemaInfo->{$Table}->{ForeignKeys}->{$PKColumnName}},
                    "$FKTableName.$FKColumnName"
                );
            }
        }
    }

    return $SchemaInfo;
}

=item Quote()

to quote sql parameters

    quote strings, date and time:
    =============================
    my $DBString = $DBObject->Quote( "This isn't a problem!" );

    my $DBString = $DBObject->Quote( "2005-10-27 20:15:01" );

    quote integers:
    ===============
    my $DBString = $DBObject->Quote( 1234, 'Integer' );

    quote numbers (e. g. 1, 1.4, 42342.23424):
    ==========================================
    my $DBString = $DBObject->Quote( 1234, 'Number' );

=cut

sub Quote {
    my ( $Self, $Text, $Type, $Silent ) = @_;

    # return undef if undef
    return if !defined $Text;

    # quote strings
    if ( !defined $Type ) {
        return ${ $Self->{Backend}->Quote( \$Text ) };
    }

    # quote integers
    if ( $Type eq 'Integer' ) {
        if ( $Text !~ m{\A [+-]? \d{1,16} \z}xms ) {
            return if $Silent;
            $Kernel::OM->Get('Log')->Log(
                Caller   => 1,
                Priority => 'error',
                Message  => "Invalid integer in query '$Text'!",
            );
            return;
        }
        return $Text;
    }

    # quote numbers
    if ( $Type eq 'Number' ) {
        if ( $Text !~ m{ \A [+-]? \d{1,20} (?:\.\d{1,20})? \z}xms ) {
            return if $Silent;

            $Kernel::OM->Get('Log')->Log(
                Caller   => 1,
                Priority => 'error',
                Message  => "Invalid number in query '$Text'!",
            );
            return;
        }
        return $Text;
    }

    # quote like strings
    if ( $Type eq 'Like' ) {
        return ${ $Self->{Backend}->Quote( \$Text, $Type ) };
    }

    return if $Silent;

    $Kernel::OM->Get('Log')->Log(
        Caller   => 1,
        Priority => 'error',
        Message  => "Invalid quote type '$Type'!",
    );

    return;
}

=item Error()

to retrieve database errors

    my $ErrorMessage = $DBObject->Error();

=cut

sub Error {
    my $Self = shift;

    return $DBI::errstr;
}

=item Do()

to insert, update or delete values

    $DBObject->Do( SQL => "INSERT INTO table (name) VALUES ('dog')" );

    $DBObject->Do( SQL => "DELETE FROM table" );

    you also can use DBI bind values (used for large strings):

    my $Var1 = 'dog1';
    my $Var2 = 'dog2';

    $DBObject->Do(
        SQL  => "INSERT INTO table (name1, name2) VALUES (?, ?)",
        Bind => [ \$Var1, \$Var2 ],
    );

=cut

sub Do {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{SQL} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need SQL!',
        );
        return;
    }

    my $StartTime;
    if ( $Self->{Debug} && $Self->{DebugMethods}->{Do} ) {
        $StartTime = Time::HiRes::time();
    }

    if ( $Self->{Backend}->{'DB::PreProcessSQL'} ) {
        $Self->{Backend}->PreProcessSQL( \$Param{SQL} );
    }

    # check bind params
    my @Array;
    if ( $Param{Bind} ) {
        for my $Data ( @{ $Param{Bind} } ) {
            if ( ref $Data eq 'SCALAR' ) {
                push @Array, $$Data;
            }
            else {
                use Data::Dumper;
                $Kernel::OM->Get('Log')->Log(
                    Caller   => 1,
                    Priority => 'Error',
                    Message  => 'No SCALAR param in Bind!' . ( $Self->{Debug} ? ( ' Bind: ' . Data::Dumper::Dumper( $Param{Bind} ) ) : q{} ),
                );
                return;
            }
        }
        if ( @Array && $Self->{Backend}->{'DB::PreProcessBindData'} ) {
            $Self->{Backend}->PreProcessBindData( \@Array );
        }
    }

    # Replace current_timestamp with real time stamp.
    # - This avoids time inconsistencies of app and db server
    # - This avoids timestamp problems in Postgresql servers where
    #   the timestamp is sometimes 1 second off the perl timestamp.
    my $Timestamp = $Kernel::OM->Get('Time')->CurrentTimestamp();
    $Param{SQL} =~ s{
        (?<= \s | \( | , )  # lookahead
        current_timestamp   # replace current_timestamp by 'yyyy-mm-dd hh:mm:ss'
        (?=  \s | \) | , )  # lookbehind
    }
    {
        '$Timestamp'
    }xmsg;

    if ( !$Param{SkipConnectCheck} ) {
        return if !$Self->Connect();
    }

    # send sql to database
    if ( !$Self->{dbh}->do( $Param{SQL}, undef, @Array ) ) {
        $Kernel::OM->Get('Log')->Log(
            Caller   => 1,
            Priority => 'error',
            Message  => "$DBI::errstr, SQL: '$Param{SQL}'",
        );
        return;
    }

    if ( $Self->{Debug} && $Self->{DebugMethods}->{Do} ) {
        $Self->_Debug(sprintf("Do [SQL: %s] took %i ms", $Param{SQL}, (Time::HiRes::time() - $StartTime) * 1000));
    }

    return 1;
}

sub _InitSlaveDB {
    my ( $Self, %Param ) = @_;

    # Run only once!
    return $Self->{SlaveDBObject} if $Self->{_InitSlaveDB}++;

    my $ConfigObject = $Kernel::OM->Get('Config');
    my $MasterDSN    = $ConfigObject->Get('DatabaseDSN');

    # Don't create slave if we are already in a slave, or if we are not in the master,
    #   such as in an external customer user database handle.
    if ( $Self->{IsSlaveDB} || $MasterDSN ne $Self->{DSN} ) {
        return $Self->{SlaveDBObject};
    }

    my %SlaveConfiguration = (
        %{ $ConfigObject->Get('Core::MirrorDB::AdditionalMirrors') // {} },
        0 => {
            DSN      => $ConfigObject->Get('Core::MirrorDB::DSN'),
            User     => $ConfigObject->Get('Core::MirrorDB::User'),
            Password => $ConfigObject->Get('Core::MirrorDB::Password'),
        }
    );

    return $Self->{SlaveDBObject} if !%SlaveConfiguration;

    SLAVE_INDEX:
    for my $SlaveIndex ( List::Util::shuffle( keys %SlaveConfiguration ) ) {

        my %CurrentSlave = %{ $SlaveConfiguration{$SlaveIndex} // {} };
        next SLAVE_INDEX if !%CurrentSlave;

        # If a slave is configured and it is not already used in the current object
        #   and we are actually in the master connection object: then create a slave.
        if (
            $CurrentSlave{DSN}
            && $CurrentSlave{User}
            && $CurrentSlave{Password}
        ) {
            my $SlaveDBObject = Kernel::System::DB->new(
                DatabaseDSN  => $CurrentSlave{DSN},
                DatabaseUser => $CurrentSlave{User},
                DatabasePw   => $CurrentSlave{Password},
                IsSlaveDB    => 1,
            );

            if ( $SlaveDBObject->Connect( $Param{Silent} ) ) {
                $Self->{SlaveDBObject} = $SlaveDBObject;
                return $Self->{SlaveDBObject};
            }
        }
    }

    # no connect was possible.
    return;
}

=item Prepare()

to prepare a SELECT statement

    $DBObject->Prepare(
        SQL   => "SELECT id, name FROM table",
        Limit => 10,
    );

or in case you want just to get row 10 until 30

    $DBObject->Prepare(
        SQL   => "SELECT id, name FROM table",
        Start => 10,
        Limit => 20,
    );

in case you don't want utf-8 encoding for some columns, use this:

    $DBObject->Prepare(
        SQL    => "SELECT id, name, content FROM table",
        Encode => [ 1, 1, 0 ],
    );

you also can use DBI bind values, required for large strings:

    my $Var1 = 'dog1';
    my $Var2 = 'dog2';

    $DBObject->Prepare(
        SQL    => "SELECT id, name, content FROM table WHERE name_a = ? AND name_b = ?",
        Encode => [ 1, 1, 0 ],
        Bind   => [ \$Var1, \$Var2 ],
    );

=cut

sub Prepare {
    my ( $Self, %Param ) = @_;

    my $SQL   = $Param{SQL};
    my $Limit = $Param{Limit} || q{};
    my $Start = $Param{Start} || q{};

    # check needed stuff
    if ( !$Param{SQL} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Need SQL!',
            );
        }
        return;
    }

    my $StartTime;
    if ( $Self->{Debug} && $Self->{DebugMethods}->{Prepare} ) {
        $StartTime = Time::HiRes::time();
    }

    $Self->{_PreparedOnSlaveDB} = 0;

    # Route SELECT statements to the DB slave if requested and a slave is configured.
    if (
        $UseSlaveDB
        && !$Self->{IsSlaveDB}
        && $Self->_InitSlaveDB( Silent => $Param{Silent} )    # this is very cheap after the first call (cached)
        && $SQL =~ m{\A\s*SELECT}xms
    ) {
        $Self->{_PreparedOnSlaveDB} = 1;
        return $Self->{SlaveDBObject}->Prepare(%Param);
    }

    if ( defined $Param{Encode} ) {
        $Self->{Encode} = $Param{Encode};
    }
    else {
        $Self->{Encode} = undef;
    }

    $Self->{Limit}        = 0;
    $Self->{LimitStart}   = 0;
    $Self->{LimitCounter} = 0;

    # build final select query
    if ($Limit) {
        if ($Start) {
            $Limit = $Limit + $Start;
            $Self->{LimitStart} = $Start;
        }

        if ( $Self->{Backend}->{'DB::Limit'} eq 'limit' ) {
            $SQL .= " LIMIT $Limit";
        }
        elsif ( $Self->{Backend}->{'DB::Limit'} eq 'top' ) {
            $SQL =~ s{ \A \s* (SELECT ([ ]DISTINCT|)) }{$1 TOP $Limit}xmsi;
        }
        else {
            $Self->{Limit} = $Limit;
        }
    }

    if ( $Self->{Backend}->{'DB::PreProcessSQL'} ) {
        $Self->{Backend}->PreProcessSQL( \$SQL );
    }

    # check bind params
    my @Array;
    if ( $Param{Bind} ) {
        for my $Data ( @{ $Param{Bind} } ) {
            if ( ref $Data eq 'SCALAR' ) {
                push @Array, $$Data;
            }
            else {
                if ( !$Param{Silent} ) {
                    $Kernel::OM->Get('Log')->Log(
                        Caller   => 1,
                        Priority => 'Error',
                        Message  => 'No SCALAR param in Bind!' . ( $Self->{Debug} ? ( ' Bind: ' . Data::Dumper::Dumper( $Param{Bind} ) ) : q{} ),
                    );
                }
                return;
            }
        }
        if ( @Array && $Self->{Backend}->{'DB::PreProcessBindData'} ) {
            $Self->{Backend}->PreProcessBindData( \@Array );
        }
    }

    return if !$Self->Connect();

    # do
    if ( !( $Self->{Cursor} = $Self->{dbh}->prepare($SQL) ) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Caller   => 1,
                Priority => 'Error',
                Message  => "$DBI::errstr, SQL: '$SQL'",
            );
        }
        return;
    }

    if ( !$Self->{Cursor}->execute(@Array) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Caller   => 1,
                Priority => 'Error',
                Message  => "$DBI::errstr, SQL: '$SQL'",
            );
        }
        return;
    }

    if ( $Self->{Debug} && $Self->{DebugMethods}->{Prepare} ) {
        $Self->_Debug(sprintf("Prepare [SQL: %s] took %i ms", $SQL, (Time::HiRes::time() - $StartTime) * 1000));
    }

    return 1;
}

=item FetchrowArray()

to process the results of a SELECT statement

    $DBObject->Prepare(
        SQL   => "SELECT id, name FROM table",
        Limit => 10
    );

    while (my @Row = $DBObject->FetchrowArray()) {
        print "$Row[0]:$Row[1]\n";
    }

=cut

sub FetchrowArray {
    my $Self = shift;

    my $StartTime;
    if ( $Self->{Debug} && $Self->{DebugMethods}->{FetchrowArray} ) {
        $StartTime = Time::HiRes::time();
    }

    if ( $Self->{_PreparedOnSlaveDB} ) {
        return $Self->{SlaveDBObject}->FetchrowArray();
    }

    # work with cursors if database don't support limit
    if ( !$Self->{Backend}->{'DB::Limit'} && $Self->{Limit} ) {
        if ( $Self->{Limit} <= $Self->{LimitCounter} ) {
            $Self->{Cursor}->finish();
            return;
        }
        $Self->{LimitCounter}++;
    }

    # fetch first not used rows
    if ( $Self->{LimitStart} ) {
        for ( 1 .. $Self->{LimitStart} ) {
            my @Row = $Self->{Cursor}->fetchrow_array();
            if ( !@Row ) {
                $Self->{LimitStart} = 0;
                return ();
            }
            $Self->{LimitCounter}++;
        }
        $Self->{LimitStart} = 0;
    }

    # return
    my @Row = $Self->{Cursor}->fetchrow_array();

    if ( !$Self->{Backend}->{'DB::Encode'} ) {
        return @Row;
    }

    # get encode object
    my $EncodeObject = $Kernel::OM->Get('Encode');

    # e. g. set utf-8 flag
    my $Counter = 0;
    ELEMENT:
    for my $Element (@Row) {

        next ELEMENT if !defined $Element;

        if ( !defined $Self->{Encode} || ( $Self->{Encode} && $Self->{Encode}->[$Counter] ) ) {
            $EncodeObject->EncodeInput( \$Element );
        }
    }
    continue {
        $Counter++;
    }

    if ( $Self->{Debug} && $Self->{DebugMethods}->{FetchrowArray} ) {
        $Self->_Debug(sprintf("FetchrowArray took %i ms", (Time::HiRes::time() - $StartTime) * 1000));
    }

    return @Row;
}

=item FetchAllArrayRef()

to process the results of a SELECT statement

    $DBObject->Prepare(
        SQL   => "SELECT id, name FROM table",
        Limit => 10
    );

    my $Rows = $DBObject->FetchAllArrayRef(
        Columns => [ 'ID', 'Name' ]
    );

=cut

sub FetchAllArrayRef {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !IsArrayRefWithData($Param{Columns}) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Columns!',
        );
        return;
    }

    my $StartTime;
    if ( $Self->{Debug} && $Self->{DebugMethods}->{FetchAllArrayRef} ) {
        $StartTime = Time::HiRes::time();
    }

    if ( $Self->{_PreparedOnSlaveDB} ) {
        return $Self->{SlaveDBObject}->FetchAllArrayRef();
    }

    # work with cursors if database don't support limit
    if ( !$Self->{Backend}->{'DB::Limit'} && $Self->{Limit} ) {
        if ( $Self->{Limit} <= $Self->{LimitCounter} ) {
            $Self->{Cursor}->finish();
            return;
        }
        $Self->{LimitCounter}++;
    }

    # fetch
    my $Rows = $Self->{Cursor}->fetchall_arrayref();

    # get encode object
    my $EncodeObject = $Kernel::OM->Get('Encode');

    my $DoEncode = $Self->{Backend}->{'DB::Encode'};

    # map columns
    my @Result;
    foreach my $Row ( @{$Rows} ) {
        my %RowData;
        my $Counter = 0;
        foreach my $Column ( @{$Param{Columns}} ) {
            $RowData{$Column} = $Row->[$Counter++];
            if ( $DoEncode ) {
                # set utf-8 flag
                $EncodeObject->EncodeInput( \$RowData{$Column} );
            }
        }
        push(@Result, \%RowData);
    }

    if ( $Self->{Debug} && $Self->{DebugMethods}->{FetchAllArrayRef} ) {
        $Self->_Debug(
            sprintf("FetchAllArrayRef [Columns: %s] took %i ms",
            join(q{,}, @{$Param{Columns}}), (Time::HiRes::time() - $StartTime) * 1000)
        );
    }

    return \@Result;
}

=item GetColumnNames()

to retrieve the column names of a database statement

    $DBObject->Prepare(
        SQL   => "SELECT * FROM table",
        Limit => 10
    );

    my @Names = $DBObject->GetColumnNames();

=cut

sub GetColumnNames {
    my $Self = shift;

    my $ColumnNames = $Self->{Cursor}->{NAME};

    my @Result;
    if ( ref $ColumnNames eq 'ARRAY' ) {
        @Result = @{$ColumnNames};
    }

    return @Result;
}

=item SelectAll()

returns all available records of a SELECT statement.
In essence, this calls Prepare() and FetchrowArray() to get all records.

    my $ResultAsArrayRef = $DBObject->SelectAll(
        SQL   => "SELECT id, name FROM table",
        Limit => 10
    );

You can pass the same arguments as to the Prepare() method.

Returns undef (if query failed), or an array ref (if query was successful):

  my $ResultAsArrayRef = [
    [ 1, 'itemOne' ],
    [ 2, 'itemTwo' ],
    [ 3, 'itemThree' ],
    [ 4, 'itemFour' ],
  ];

=cut

sub SelectAll {
    my ( $Self, %Param ) = @_;

    return if !$Self->Prepare(%Param);

    my @Records;
    while ( my @Row = $Self->FetchrowArray() ) {
        push @Records, \@Row;
    }
    return \@Records;
}

=item GetDatabaseFunction()

to get database functions like
    o Limit
    o DirectBlob
    o QuoteSingle
    o QuoteBack
    o QuoteSemicolon
    o NoLikeInLargeText
    o CurrentTimestamp
    o Encode
    o Comment
    o ShellCommit
    o ShellConnect
    o Connect
    o LikeEscapeString

    my $What = $DBObject->GetDatabaseFunction('DirectBlob');

=cut

sub GetDatabaseFunction {
    my ( $Self, $What ) = @_;

    return $Self->{Backend}->{ 'DB::' . $What };
}

=item SQLProcessor()

generate database-specific sql syntax (e. g. CREATE TABLE ...)

    my @SQL = $DBObject->SQLProcessor(
        Database => [
            {
                Tag     => 'TableCreate',
                Name    => 'table_name',
                TagType => 'Start'
            },
            {
                Tag      => 'Column',
                Name     => 'col_name',
                Type     => 'VARCHAR',
                Required => 'false',
                Size     => 150,
                TagType  => 'Start'
            },
            {
                Tag     => 'Column',
                Name    => 'col_name2',
                Type    => 'INTEGER',
                TagType => 'Start'
            },
            {
                Tag     => 'TableCreate',
                TagType => 'End'
            }
        ]
    );

=cut

sub SQLProcessor {
    my ( $Self, %Param ) = @_;

    my @SQL;
    if ( $Param{Database} && ref $Param{Database} eq 'ARRAY' ) {
        my @Table;
        for my $Tag ( @{ $Param{Database} } ) {

            # create table
            if ( $Tag->{Tag} eq 'Table' || $Tag->{Tag} eq 'TableCreate' ) {
                if ( $Tag->{TagType} eq 'Start' ) {
                    $Self->_NameCheck($Tag);
                }
                push @Table, $Tag;
                if ( $Tag->{TagType} eq 'End' ) {
                    push @SQL, $Self->{Backend}->TableCreate(@Table);
                    @Table = ();
                }
            }

            # unique
            elsif (
                $Tag->{Tag} eq 'Unique'
                || $Tag->{Tag} eq 'UniqueCreate'
                || $Tag->{Tag} eq 'UniqueDrop'
            ) {
                push @Table, $Tag;
            }

            elsif ( $Tag->{Tag} eq 'UniqueColumn' ) {
                push @Table, $Tag;
            }

            # index
            elsif (
                $Tag->{Tag} eq 'Index'
                || $Tag->{Tag} eq 'IndexCreate'
                || $Tag->{Tag} eq 'IndexDrop'
            ) {
                push @Table, $Tag;
            }

            elsif ( $Tag->{Tag} eq 'IndexColumn' ) {
                push @Table, $Tag;
            }

            # primary
            elsif (
                $Tag->{Tag} eq 'Primary'
                || $Tag->{Tag} eq 'PrimaryCreate'
                || $Tag->{Tag} eq 'PrimaryColumn'
                || $Tag->{Tag} eq 'PrimaryDrop' ) {
                push @Table, $Tag;
            }

            # foreign keys
            elsif (
                $Tag->{Tag} eq 'ForeignKey'
                || $Tag->{Tag} eq 'ForeignKeyCreate'
                || $Tag->{Tag} eq 'ForeignKeyDrop'
            ) {
                push @Table, $Tag;
            }
            elsif ( $Tag->{Tag} eq 'Reference' && $Tag->{TagType} eq 'Start' ) {
                push @Table, $Tag;
            }

            # alter table
            elsif ( $Tag->{Tag} eq 'TableAlter' ) {
                push @Table, $Tag;
                if ( $Tag->{TagType} eq 'End' ) {
                    push @SQL, $Self->{Backend}->TableAlter(@Table);
                    @Table = ();
                }
            }

            # column
            elsif ( $Tag->{Tag} eq 'Column' && $Tag->{TagType} eq 'Start' ) {

                # type check
                $Self->_TypeCheck($Tag);
                push @Table, $Tag;
            }
            elsif ( $Tag->{Tag} eq 'ColumnAdd' && $Tag->{TagType} eq 'Start' ) {

                # type check
                $Self->_TypeCheck($Tag);
                push @Table, $Tag;
            }
            elsif ( $Tag->{Tag} eq 'ColumnChange' && $Tag->{TagType} eq 'Start' ) {

                # type check
                $Self->_TypeCheck($Tag);
                push @Table, $Tag;
            }
            elsif ( $Tag->{Tag} eq 'ColumnDrop' && $Tag->{TagType} eq 'Start' ) {

                # type check
                $Self->_TypeCheck($Tag);
                push @Table, $Tag;
            }

            # drop table
            elsif ( $Tag->{Tag} eq 'TableDrop' && $Tag->{TagType} eq 'Start' ) {
                push @Table, $Tag;
                push @SQL,   $Self->{Backend}->TableDrop(@Table);
                @Table = ();
            }

            # insert
            elsif ( $Tag->{Tag} eq 'Insert' ) {
                push @Table, $Tag;
                if ( $Tag->{TagType} eq 'End' ) {
                    push @Table, $Tag;
                    push @SQL,   $Self->{Backend}->Insert(@Table);
                    @Table = ();
                }
            }
            elsif ( $Tag->{Tag} eq 'Data' && $Tag->{TagType} eq 'Start' ) {
                push @Table, $Tag;
            }
        }
    }

    return @SQL;
}

=item SQLProcessorPost()

generate database-specific sql syntax, post data of SQLProcessor(),
e. g. foreign keys

    my @SQL = $DBObject->SQLProcessorPost();

=cut

sub SQLProcessorPost {
    my ( $Self, %Param ) = @_;

    if ( $Self->{Backend}->{Post} ) {
        my @Return = @{ $Self->{Backend}->{Post} };
        undef $Self->{Backend}->{Post};
        return @Return;
    }

    return ();
}

# GetTableData()
#
# !! DONT USE THIS FUNCTION !!
#
# Due to compatibility reason this function is still available and it will be removed
# in upcoming releases.

sub GetTableData {
    my ( $Self, %Param ) = @_;

    my $Table = $Param{Table};
    my $What  = $Param{What};
    my $Where = $Param{Where} || q{};
    my $Valid = $Param{Valid} || q{};
    my $Clamp = $Param{Clamp} || q{};
    my %Data;

    my $SQL = "SELECT $What FROM $Table ";
    if ($Where) {
        $SQL .= ' WHERE ' . $Where;
    }

    if ( !$Where && $Valid ) {
        my @ValidIDs;

        return if !$Self->Prepare( SQL => 'SELECT id FROM valid WHERE name = \'valid\'' );
        while ( my @Row = $Self->FetchrowArray() ) {
            push @ValidIDs, $Row[0];
        }

        $SQL .= " WHERE valid_id IN ( ${\(join ', ', @ValidIDs)} )";
    }

    $Self->Prepare( SQL => $SQL );

    while ( my @Row = $Self->FetchrowArray() ) {
        if ( $Row[3] ) {
            if ($Clamp) {
                $Data{ $Row[0] } = "$Row[1] $Row[2] ($Row[3])";
            }
            else {
                $Data{ $Row[0] } = "$Row[1] $Row[2] $Row[3]";
            }
        }
        elsif ( $Row[2] ) {
            if ($Clamp) {
                $Data{ $Row[0] } = "$Row[1] ( $Row[2] )";
            }
            else {
                $Data{ $Row[0] } = "$Row[1] $Row[2]";
            }
        }
        else {
            $Data{ $Row[0] } = $Row[1];
        }
    }

    return %Data;
}

=item QueryCondition()

generate SQL condition query based on a search expression

    my $SQL = $DBObject->QueryCondition(
        Key   => 'some_col',
        Value => '(ABC+DEF)',
    );

    Ignores replacement of the wildcard “*”, except SearchPrefix and SearchSuffix

    my $SQL = $DBObject->QueryCondition(
        Key        => 'some_col',
        Value      => '(ABC*+DEF)',
        NoWildcard => 1
    );

    add SearchPrefix and SearchSuffix to search, in this case
    for "(ABC*+DEF*)"

    my $SQL = $DBObject->QueryCondition(
        Key          => 'some_col',
        Value        => '(ABC+DEF)',
        SearchPrefix => q{},
        SearchSuffix => '*'
        Extended     => 1, # use also " " as "&&", e.g. "bob smith" -> "bob&&smith"
    );

    example of a more complex search condition

    my $SQL = $DBObject->QueryCondition(
        Key   => 'some_col',
        Value => '((ABC&&DEF)&&!GHI)',
    );

    for a earch condition over more columns

    my $SQL = $DBObject->QueryCondition(
        Key   => [ 'some_col_a', 'some_col_b' ],
        Value => '((ABC&&DEF)&&!GHI)',
    );

    Returns the SQL string or "1=0" if the query could not be parsed correctly.

    my $SQL = $DBObject->QueryCondition(
        Key      => [ 'some_col_a', 'some_col_b' ],
        Value    => '((ABC&&DEF)&&!GHI)',
        BindMode => 1,
    );

    return the SQL String with ?-values and a array with values references:

Note that the comparisons are usually performed case insensitively.
Only VARCHAR colums with a size less or equal 3998 are supported,
as for locator objects the functioning of SQL function LOWER() can't
be guaranteed.

=cut

sub QueryCondition {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Key} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Key!"
        );
        return;
    }
    if ( !$Param{Value} && $Param{Value} != 0 ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need valid Value!"
        );
        return;
    }

    # get like escape string needed for some databases (e.g. oracle)
    my $LikeEscapeString = $Self->GetDatabaseFunction('LikeEscapeString');

    # search prefix/suffix check
    my $SearchPrefix  = $Param{SearchPrefix}  || q{};
    my $SearchSuffix  = $Param{SearchSuffix}  || q{};
    my $CaseSensitive = $Param{CaseSensitive} || 0;
    my $BindMode      = $Param{BindMode}      || 0;
    my @BindValues;


    # replace * with % (for SearchPrefix)
    if ( $SearchPrefix ) {
        $SearchPrefix =~ s/\*/%/g;
    }

    # replace * with % (for SearchSuffix)
    if ( $SearchSuffix ) {
        $SearchSuffix =~ s/\*/%/g;
    }

    # remove leading/trailing spaces
    $Param{Value} =~ s/^\s+//g;
    $Param{Value} =~ s/\s+$//g;

    # add base brackets
    if (
        $Param{Value} !~ /^(?<!\\)\(/
        || $Param{Value} !~ /(?<!\\)\)$/
    ) {
        $Param{Value} = '(' . $Param{Value} . ')';
    }

    # quote ".+?" expressions
    # for example ("some and me" AND !some), so "some and me" is used for search 1:1
    my $Count = 0;
    my %Expression;
    $Param{Value} =~ s{
        "(.+?)"
    }
    {
        $Count++;
        my $Item = $1;
        $Expression{"###$Count###"} = $Item;
        "###$Count###";
    }egx;

    # remove empty parentheses
    $Param{Value} =~ s/(?<!\\)\(\s*(?<!\\)\)//g;

    # remove double spaces
    $Param{Value} =~ s/\s+/ /g;

    # replace + by &&
    $Param{Value} =~ s/\+/&&/g;

    # replace AND by &&
    $Param{Value} =~ s/(\s|(?<!\\)\)|(?<!\\)\()AND(\s|(?<!\\)\(|(?<!\\)\))/$1&&$2/g;

    # replace OR by ||
    $Param{Value} =~ s/(\s|(?<!\\)\)|(?<!\\)\()OR(\s|(?<!\\)\(|(?<!\\)\))/$1||$2/g;

    # replace * with % (for SQL)
    if ( !$Param{NoWildcard} ) {
        $Param{Value} =~ s/\*/%/g;
    }

    # remove double %% (also if there is only whitespace in between)
    $Param{Value} =~ s/%\s*%/%/g;

    # replace '%!%' by '!%' (done if * is added by search frontend)
    $Param{Value} =~ s/\%!\%/!%/g;

    # replace '%!' by '!%' (done if * is added by search frontend)
    $Param{Value} =~ s/\%!/!%/g;

    # remove leading/trailing conditions
    $Param{Value} =~ s/(&&|\|\|)(?<!\\)\)$/)/g;
    $Param{Value} =~ s/^(?<!\\)\((&&|\|\|)/(/g;

    # clean up not needed spaces in condistions
    # removed spaces examples
    # # [SPACE](, [SPACE]), [SPACE]|, [SPACE]&
    # [SPACE](, [SPACE]), [SPACE]||, [SPACE]&&
    # example not removed spaces
    # [SPACE]\\(, [SPACE]\\), [SPACE]\\&
    $Param{Value} =~ s{(
        \s
        (
              (?<!\\) \(
            | (?<!\\) \)
            |         \|\|
            | (?<!\\) &&
        )
    )}{$2}xg;

    # removed spaces examples
    # # )[SPACE], )[SPACE], |[SPACE], &[SPACE]
    # )[SPACE], )[SPACE], ||[SPACE], &&[SPACE]
    # example not removed spaces
    # \\([SPACE], \\)[SPACE], \\&[SPACE]
    $Param{Value} =~ s{(
        (
              (?<!\\) \(
            | (?<!\\) \)
            |         \|\|
            | (?<!\\) &&
        )
        \s
    )}{$2}xg;

    # use extended condition mode
    # 1. replace " " by "&&"
    if ( $Param{Extended} ) {
        $Param{Value} =~ s/\s/&&/g;
    }

    if ( $Param{NoWildcard} ) {
        $Param{Value} = $Self->Quote(
            $Param{Value},
            'Like',
            $Param{Silent}
        );
    }

    # get col.
    my @Keys;
    if ( ref $Param{Key} eq 'ARRAY' ) {
        @Keys = @{ $Param{Key} };
    }
    else {
        @Keys = ( $Param{Key} );
    }

    # for syntax check
    my $Open  = 0;
    my $Close = 0;

    # for processing
    my @Array     = split( // , $Param{Value} );
    my $SQL       = q{};
    my $Word      = q{};
    my $Not       = 0;
    my $Backslash = 0;

    my $SpecialCharacters = $Self->_SpecialCharactersGet();

    POSITION:
    for my $Position ( 0 .. $#Array ) {

        # find word
        if ($Backslash) {
            $Word .= $Array[$Position];
            $Backslash = 0;
            next POSITION;
        }

        # remember if next token is a part of word
        elsif (
            $Array[$Position] eq q{\\}
            && $Position < $#Array
            && (
                $SpecialCharacters->{ $Array[ $Position + 1 ] }
                || $Array[ $Position + 1 ] eq q{\\}
            )
        ) {
            $Backslash = 1;
            next POSITION;
        }

        # remember if it's a NOT condition
        elsif ( $Word eq q{} && $Array[$Position] eq q{!} ) {
            $Not = 1;
            next POSITION;
        }
        elsif ( $Array[$Position] eq q{&} ) {
            if ( $Position >= 1 && $Array[ $Position - 1 ] eq q{&} ) {
                next POSITION;
            }
            if ( $Position == $#Array || $Array[ $Position + 1 ] ne q{&} ) {
                $Word .= $Array[$Position];
                next POSITION;
            }
        }
        elsif ( $Array[$Position] eq q{|} ) {
            if ( $Position >= 1 && $Array[ $Position - 1 ] eq q{|} ) {
                next POSITION;
            }
            if ( $Position == $#Array || $Array[ $Position + 1 ] ne q{|} ) {
                $Word .= $Array[$Position];
                next POSITION;
            }
        }
        elsif ( !$SpecialCharacters->{ $Array[$Position] } ) {
            $Word .= $Array[$Position];
            next POSITION;
        }

        # if word exists, do something with it
        if ( $Word ne q{} ) {

            # remove escape characters from $Word
            $Word =~ s{\\}{}smxg;

            # replace word if it's an "some expression" expression
            if ( $Expression{$Word} ) {
                $Word = $Expression{$Word};
            }

            # database quote
            $Word = $SearchPrefix . $Word . $SearchSuffix;

            if ( !$Param{NoWildcard} ) {
                $Word =~ s/\*/%/g;
                $Word =~ s/%%/%/g;
                $Word =~ s/%%/%/g;
            }

            # perform quoting depending on query type (only if not in bind mode)
            if ( !$BindMode ) {
                if ( $Word =~ m/%/ ) {
                    $Word = $Self->Quote( $Word, 'Like' );
                }
                else {
                    $Word = $Self->Quote($Word);
                }
            }

            # if it's a NOT LIKE condition
            if ($Not) {
                $Not = 0;

                my $SQLA;
                for my $Key (@Keys) {
                    if ($SQLA) {
                        $SQLA .= ' AND ';
                    }

                    # check if like is used
                    my $Type = 'NOT LIKE';
                    if ( $Word !~ m/%/ ) {
                        $Type = q{!=};
                    }

                    my $WordSQL = $Word;
                    if ($BindMode) {
                        $WordSQL = q{?};
                    }
                    else {
                        $WordSQL = q{'} . $WordSQL . q{'};
                    }

                    # check if database supports LIKE in large text types
                    # the first condition is a little bit opaque
                    # CaseSensitive of the database defines, if the database handles case sensitivity or not
                    # and the parameter $CaseSensitive defines, if the customer database should do case sensitive statements or not.
                    # so if the database dont support case sensitivity or the configuration of the customer database want to do this
                    # then we prevent the LOWER() statements.
                    if ( !$Self->GetDatabaseFunction('CaseSensitive') || $CaseSensitive ) {
                        $SQLA .= "$Key $Type $WordSQL";
                    }
                    elsif ( $Self->GetDatabaseFunction('LcaseLikeInLargeText') ) {

                        if ( $Param{StaticDB} ) {
                            $SQLA .= "$Key $Type LCASE($WordSQL)";
                        }
                        else {
                            $SQLA .= "LCASE($Key) $Type LCASE($WordSQL)";
                        }
                    }
                    else {
                        if ( $Param{StaticDB} ) {
                            $SQLA .= "$Key $Type LOWER($WordSQL)";
                        }
                        else {
                            $SQLA .= "LOWER($Key) $Type LOWER($WordSQL)";
                        }
                    }

                    if ( $Type eq 'NOT LIKE' ) {
                        $SQLA .= " $LikeEscapeString";
                    }

                    if ($BindMode) {
                        push @BindValues, $Word;
                    }
                }
                $SQL .= '(' . $SQLA . ') ';
            }

            # if it's a LIKE condition
            else {
                my $SQLA;
                for my $Key (@Keys) {
                    if ($SQLA) {
                        $SQLA .= ' OR ';
                    }

                    # check if like is used
                    my $Type = 'LIKE';
                    if ( $Word !~ m/%/ ) {
                        $Type = q{=};
                    }

                    my $WordSQL = $Word;
                    if ($BindMode) {
                        $WordSQL = q{?};
                    }
                    else {
                        $WordSQL = q{'} . $WordSQL . q{'};
                    }

                    # check if database supports LIKE in large text types
                    # the first condition is a little bit opaque
                    # CaseSensitive of the database defines, if the database handles case sensitivity or not
                    # and the parameter $CaseSensitive defines, if the customer database should do case sensitive statements or not.
                    # so if the database dont support case sensitivity or the configuration of the customer database want to do this
                    # then we prevent the LOWER() statements.
                    if ( !$Self->GetDatabaseFunction('CaseSensitive') || $CaseSensitive ) {
                        $SQLA .= "$Key $Type $WordSQL";
                    }
                    elsif ( $Self->GetDatabaseFunction('LcaseLikeInLargeText') ) {

                        if ( $Param{StaticDB} ) {
                            $SQLA .= "$Key $Type LCASE($WordSQL)";
                        }
                        else {
                            $SQLA .= "LCASE($Key) $Type LCASE($WordSQL)";
                        }
                    }
                    else {
                        if ( $Param{StaticDB} ) {
                            $SQLA .= "$Key $Type LOWER($WordSQL)";
                        }
                        else {
                            $SQLA .= "LOWER($Key) $Type LOWER($WordSQL)";
                        }
                    }

                    if ( $Type eq 'LIKE' ) {
                        $SQLA .= " $LikeEscapeString";
                    }

                    if ($BindMode) {
                        push @BindValues, $Word;
                    }
                }
                $SQL .= '(' . $SQLA . ') ';
            }

            # reset word
            $Word = q{};
        }

        # check AND and OR conditions
        if ( $Array[ $Position + 1 ] ) {

            # if it's an AND condition
            if ( $Array[$Position] eq q{&} && $Array[ $Position + 1 ] eq q{&} ) {
                if ( $SQL =~ m/ OR $/ ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'notice',
                        Message =>
                            "Invalid condition '$Param{Value}', simultaneous usage both AND and OR conditions!",
                    );
                    return "1=0";
                }
                elsif ( $SQL !~ m/ AND $/ ) {
                    $SQL .= ' AND ';
                }
            }

            # if it's an OR condition
            elsif ( $Array[$Position] eq q{|} && $Array[ $Position + 1 ] eq q{|} ) {
                if ( $SQL =~ m/ AND $/ ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'notice',
                        Message =>
                            "Invalid condition '$Param{Value}', simultaneous usage both AND and OR conditions!",
                    );
                    return "1=0";
                }
                elsif ( $SQL !~ m/ OR $/ ) {
                    $SQL .= ' OR ';
                }
            }
        }

        # add ( or ) for query
        if ( $Array[$Position] eq '(' ) {
            if ( $SQL ne q{} && $SQL !~ /(?: (?:AND|OR) |\(\s*)$/ ) {
                $SQL .= ' AND ';
            }
            $SQL .= $Array[$Position];

            # remember for syntax check
            $Open++;
        }
        if ( $Array[$Position] eq ')' ) {
            $SQL .= $Array[$Position];
            if (
                $Position < $#Array
                && ( $Position > $#Array - 1 || $Array[ $Position + 1 ] ne ')' )
                && (
                    $Position > $#Array - 2
                    || $Array[ $Position + 1 ] ne q{&}
                    || $Array[ $Position + 2 ] ne q{&}
                )
                && (
                    $Position > $#Array - 2
                    || $Array[ $Position + 1 ] ne q{|}
                    || $Array[ $Position + 2 ] ne q{|}
                )
            ) {
                $SQL .= ' AND ';
            }

            # remember for syntax check
            $Close++;
        }
    }

    # check syntax
    if ( $Open != $Close ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "Invalid condition '$Param{Value}', $Open open and $Close close!",
        );
        if ($BindMode) {
            return (
                'SQL'    => "1=0",
                'Values' => [],
            );
        }
        return "1=0";
    }

    if ($BindMode) {
        my $BindRefList = [ map { \$_ } @BindValues ];
        return (
            'SQL'    => $SQL,
            'Values' => $BindRefList,
        );
    }

    return $SQL;
}

=item QueryStringEscape()

escapes special characters within a query string

    my $QueryStringEscaped = $DBObject->QueryStringEscape(
        QueryString => 'customer with (brackets) and & and -',
    );

    Result would be a string in which all special characters are escaped.
    Special characters are those which are returned by _SpecialCharactersGet().

    $QueryStringEscaped = 'customer with \(brackets\) and \& and \-';

=cut

sub QueryStringEscape {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Key (qw(QueryString)) {
        if ( !defined $Param{$Key} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Key!"
            );
            return;
        }
    }

    # Merge all special characters into one string, separated by \\
    my $SpecialCharacters = q{\\} . join( q{\\} , keys %{ $Self->_SpecialCharactersGet() });

    # Use above string of special characters as character class
    # note: already escaped special characters won't be escaped again
    $Param{QueryString} =~ s{(?<!\\)([$SpecialCharacters])}{\\$1}smxg;

    return $Param{QueryString};
}

=item Ping()

checks if the database is reachable

    my $Success = $DBObject->Ping(
        AutoConnect => 0,  # default 1
    );

=cut

sub Ping {
    my ( $Self, %Param ) = @_;

    my $StartTime;
    if ( $Self->{Debug} && $Self->{DebugMethods}->{Ping} ) {
        $StartTime = Time::HiRes::time();
    }

    if ( !defined $Param{AutoConnect} || $Param{AutoConnect} ) {
        return if !$Self->Connect();
    }
    else {
        return if !$Self->{dbh};
    }

    my $Result = $Self->{dbh}->ping();

    if ( $Self->{Debug} && $Self->{DebugMethods}->{Ping} ) {
        $Self->_Debug(sprintf("Ping took %i ms", (Time::HiRes::time() - $StartTime) * 1000));
    }

    return $Result;
}

=begin Internal:

=cut

sub _Decrypt {
    my ( $Self, $Pw ) = @_;

    my $Length = length($Pw) * 4;
    $Pw = pack "h$Length", $1;
    $Pw = unpack "B$Length", $Pw;
    $Pw =~ s/1/A/g;
    $Pw =~ s/0/1/g;
    $Pw =~ s/A/0/g;
    $Pw = pack "B$Length", $Pw;

    return $Pw;
}

sub _Encrypt {
    my ( $Self, $Pw ) = @_;

    my $Length = length($Pw) * 8;
    chomp $Pw;

    # get bit code
    my $T = unpack( "B$Length", $Pw );

    # crypt bit code
    $T =~ s/1/A/g;
    $T =~ s/0/1/g;
    $T =~ s/A/0/g;

    # get ascii code
    $T = pack( "B$Length", $T );

    # get hex code
    my $H = unpack( "h$Length", $T );

    return $H;
}

sub _TypeCheck {
    my ( $Self, $Tag ) = @_;

    if (
        $Tag->{Type}
        && $Tag->{Type} !~ /^(?:DATE|SMALLINT|BIGINT|INTEGER|DECIMAL|VARCHAR|LONGBLOB)$/i
    ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'Error',
            Message  => "Unknown data type '$Tag->{Type}'!",
        );
    }

    return 1;
}

sub _NameCheck {
    my ( $Self, $Tag ) = @_;

    if ( $Tag->{Name} && length $Tag->{Name} > 30 ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'Error',
            Message  => "Table names should not have more the 30 chars ($Tag->{Name})!",
        );
    }

    return 1;
}

sub _SpecialCharactersGet {
    my ( $Self, %Param ) = @_;

    my %SpecialCharacter = (
        '('  => 1,
        ')'  => 1,
        q{&} => 1,
        q{|} => 1,
    );

    return \%SpecialCharacter;
}

sub DESTROY {
    my $Self = shift;

    # cleanup open statement handle if there is any and then disconnect from DB
    if ( $Self->{Cursor} ) {
        $Self->{Cursor}->finish();
    }
    $Self->Disconnect();

    return 1;
}

sub _Debug {
    my ( $Self, $Message ) = @_;

    return if !$Self->{Debug};

    printf( STDERR "%f (%5i) %-15s %s\n", Time::HiRes::time(), $$, "[DB]", $Message);
}


1;

=end Internal:





=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
