# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Installation::Migration::KIX17::Common;

use strict;
use warnings;

use URI::Escape qw();
use Time::HiRes;

BEGIN { $SIG{ __WARN__} = sub { return if $_[0] =~ /in cleanup/ }; }

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'Cache',
    'DB',
    'Log',
    'User',
    'Valid',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    foreach ( qw(Config Async MigrationID Options Source SourceID Debug) ) {
        $Self->{$_} = $Param{$_};
    }

    # init some more things
    $Self->{Mapping} = undef;

    return $Self;
}

sub Count {
    my ( $Self, %Param ) = @_;

    # check needed params
    for my $Needed (qw(Type)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my $WebUserAgentObject = $Kernel::OM->Get('WebUserAgent');

    if ( $Self->{Filter}->{$Param{Type}} ) {
        # we've got a given filter so add it to the where clause
        $Param{Where} .= ' AND ' if $Param{Where};
        $Param{Where} .= $Self->{Filter}->{$Param{Type}};
    }

    my @URLExt = (
        'PSK=' . $Self->{Options}->{PSK}
    );

    if ( $Param{Type} ) {
        push @URLExt, 'Type='.$Param{Type};
    }
    if ( $Param{Where} ) {
        push @URLExt, 'Where='.URI::Escape::uri_escape_utf8($Param{Where});
    }

    my $URL = $Self->{Options}->{URL} . '?Result=COUNT;' . join(';', @URLExt);

    if ( $Self->{Debug} ) {
        $Self->_Debug("[$Param{Type}](Count) executing HTTP request \"GET $URL\"");
    }

    my %Response = $WebUserAgentObject->Request(
        URL                 => $URL,
        SkipSSLVerification => 1,
    );

    # bail out, if we can't successfully perform the request
    return if !$Response{Success} || !IsStringWithData(${$Response{Content}});

    my $Data = $Kernel::OM->Get('JSON')->Decode(
        Data => ${$Response{Content}}
    );

    return $Data->{$Param{Type}};
}

sub GetSourceData {
    my ( $Self, %Param ) = @_;

    if ( !$Param{NoProgress} ) {
        $Self->UpdateProgressStatus($Param{Type}, Kernel::Language::Translatable('loading data from source'));
    }

    if ( IsArrayRefWithData($Self->{Options}->{Ignore}) ) {
        foreach my $Ignore ( @{$Self->{Options}->{Ignore}} ) {
            return [] if ( $Param{Type} =~ /$Ignore/ );
        }
    }

    my $WebUserAgentObject = $Kernel::OM->Get('WebUserAgent');

    if ( $Self->{Filter}->{$Param{Type}} ) {
        # we've got a given filter so add it to the where clause
        $Param{Where} .= ' AND ' if $Param{Where};
        $Param{Where} .= $Self->{Filter}->{$Param{Type}};
    }

    my @URLExt = (
        'PSK=' . $Self->{Options}->{PSK}
    );

    if ( $Param{Type} ) {
        push @URLExt, 'Type='.$Param{Type};
    }
    if ( $Param{ObjectID} ) {
        push @URLExt, 'ObjectID='.$Param{ObjectID};
    }
    if ( $Param{OrderBy} ) {
        push @URLExt, 'OrderBy='.URI::Escape::uri_escape_utf8($Param{OrderBy});
    }
    if ( $Param{Where} ) {
        push @URLExt, 'Where='.URI::Escape::uri_escape_utf8($Param{Where});
    }
    if ( $Param{What} ) {
        push @URLExt, 'What='.URI::Escape::uri_escape_utf8($Param{What});
    }
    if ( $Param{Limit} || $Self->{Options}->{Limit} ) {
        push @URLExt, 'Limit='.URI::Escape::uri_escape_utf8($Param{Limit} || $Self->{Options}->{Limit});
    }

    my $URL = $Self->{Options}->{URL} . '?' . join(';', @URLExt);

    if ( $Self->{Debug} ) {
        $Self->_Debug("[$Param{Type}](GetSourceData) executing HTTP request \"GET $URL\"");
    }

    my %Response = $WebUserAgentObject->Request(
        URL                 => $URL,
        SkipSSLVerification => 1,
    );

    # bail out, if we can't successfully perform the request
    if ( !$Response{Success} || !IsStringWithData(${$Response{Content}}) ) {
        $Self->UpdateProgressStatus($Param{Type}, $Response{Status});
        return;
    }

    my $Data = $Kernel::OM->Get('JSON')->Decode(
        Data => ${$Response{Content}}
    );

    # resolve dependencies
    my $Description = $Self->Describe();
    if ( IsArrayRefWithData($Data) && ((IsHashRefWithData($Description) && IsHashRefWithData($Description->{Depends})) || IsHashRefWithData($Param{References})) ) {
        my %Deps = %{$Param{References} || $Description->{Depends}};
        DATA:
        foreach my $Item ( @{$Data} ) {
            next DATA if !IsHashRefWithData($Item);

            foreach my $Dep ( sort keys %Deps ) {
                next if !$Item->{$Dep};

                if ( $Self->{Debug} ) {
                    $Self->_Debug("[$Param{Type}](GetSourceData) resolving dependency for property \"$Dep\" ($Deps{$Dep}.id=$Item->{$Dep})");
                }

                my $MappedID = $Self->GetOIDMapping(
                    ObjectType     => $Deps{$Dep},
                    SourceObjectID => $Item->{$Dep},
                );

                if ( !$MappedID ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => "Dependency for property \"$Dep\" cannot be resolved ($Deps{$Dep}: $Item->{$Dep})!"
                    );
                    if ( $Self->{Debug} ) {
                        $Self->_Debug("[$Param{Type}](GetSourceData) dependency for property \"$Dep\" ($Deps{$Dep}.id=$Item->{$Dep}) could not be resolved");
                    }
                    return;
                }

                # replace the original reference and safe the original
                $Item->{$Dep.'::raw'} = $Item->{$Dep};
                $Item->{$Dep}         = $MappedID;

                if ( $Self->{Debug} ) {
                    $Self->_Debug("[$Param{Type}](GetSourceData) resolved dependency for property \"$Dep\" ($Deps{$Dep}.id=$Item->{$Dep}) => $MappedID");
                }
            }
        }
    }

    return $Data;
}

sub Insert {
    my ( $Self, %Param ) = @_;

    # check needed params
    for my $Needed (qw(Table Item)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    if ( !IsHashRefWithData($Param{Item}) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Parameter Item is not a Hash ref!"
        );
        return;
    }

    my $DBObject = $Kernel::OM->Get('DB');

    my %Columns = $Self->_GetTableColumnNames( Table => $Param{Table} );

    my %Item = %{$Param{Item}};
    if ( $Param{PrimaryKey} ) {
        # remove PK if set to auto
        delete $Item{$Param{PrimaryKey}} if $Param{AutoPrimaryKey};
    }
    # remove all attributes that are no part of the table
    foreach my $Attr ( sort keys %Item ) {
        delete $Item{$Attr} if !$Columns{$Attr};
    }

    if ( $Self->{Debug} ) {
        $Self->_Debug("[$Param{Table}](Insert) storing migrated data");
    }

    # prepare statements
    my $InsertSQL = "INSERT INTO $Param{Table} (" . join(',', sort keys %Item) . ') VALUES (' . (join(',', map {'?'} keys %Item)) . ')';
    my @InsertBind;
    foreach my $Attr ( sort keys %Item ) {
        push @InsertBind, \$Item{$Attr};
    }
    my @FetchBind;
    my @Where;
    foreach my $Attr ( sort keys %Item ) {
        next if !defined $Item{$Attr};

        push @FetchBind, \$Item{$Attr};
        push @Where, "$Attr = ?";
    }
    my $FetchSQL = "SELECT $Param{PrimaryKey} FROM $Param{Table} WHERE " . join(' AND ', @Where);

    # do the insert
    my $Result = $DBObject->Do(
        SQL  => $InsertSQL,
        Bind => \@InsertBind
    );
    if ( !$Result ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to execute SQL! Item = ".Data::Dumper::Dumper($Param{Item}),
        );
        return;
    }

    if ( $Param{PrimaryKey} ) {
        # get ID of new row
        return if !$DBObject->Prepare(
            SQL   => $FetchSQL,
            Bind  => \@FetchBind,
            Limit => 1,
        );

        my $ID;
        while ( my @Row = $DBObject->FetchrowArray() ) {
            $ID = $Row[0];
        }

        # create or replace OID mapping
        if ( $ID && !$Param{NoOIDMapping} ) {
            my $MappedID = $Self->GetOIDMapping(
                %Param,
                ObjectType     => $Param{Table},
                SourceObjectID => $Param{Item}->{$Param{PrimaryKey}} || $Param{SourceObjectID}
            );
            if ( !$MappedID ) {
                $Self->CreateOIDMapping(
                    ObjectType     => $Param{Table},
                    ObjectID       => $ID,
                    SourceObjectID => $Param{Item}->{$Param{PrimaryKey}} || $Param{SourceObjectID},
                    AdditionalData => $Param{AdditionalData},
                );
            }
            else {
                $Self->ReplaceOIDMapping(
                    ObjectType     => $Param{Table},
                    ObjectID       => $ID,
                    SourceObjectID => $Param{Item}->{$Param{PrimaryKey}} || $Param{SourceObjectID},
                    AdditionalData => $Param{AdditionalData},
                );
            }
        }

        if ( $Self->{Debug} ) {
            $Self->_Debug("[$Param{Table}](Insert) row ID: $ID");
        }

        return $ID;
    }

    return;
}

sub Update {
    my ( $Self, %Param ) = @_;

    # check needed params
    for my $Needed (qw(Table PrimaryKey Item)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    if ( !IsHashRefWithData($Param{Item}) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Parameter Item is not a Hash ref!"
        );
        return;
    }

    my %Columns = $Self->_GetTableColumnNames( Table => $Param{Table} );

    # prepare statements
    my @Bind;
    my @AttrSQL;
    foreach my $Attr ( sort keys %{$Param{Item}} ) {
        next if ($Attr eq $Param{PrimaryKey}) || !$Columns{$Attr};

        push @AttrSQL, "$Attr = ?";
        push @Bind, \$Param{Item}->{$Attr};
    }
    my $SQL = "UPDATE $Param{Table} SET ".(join(',', @AttrSQL))." WHERE $Param{PrimaryKey} = ?";
    push @Bind, \$Param{Item}->{$Param{PrimaryKey}};

    # do the update
    my $Result = $Kernel::OM->Get('DB')->Do(
        SQL  => $SQL,
        Bind => \@Bind
    );
    if ( !$Result ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to execute SQL! Item = ".Data::Dumper::Dumper($Param{Item}),
        );
        return;
    }

    return 1;
}

sub SetMapping {
    my ( $Self, %Param ) = @_;

    # check needed params
    for my $Needed (qw(Type Mapping)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    $Self->{Mapping} //= {};

    $Self->{Mapping}->{$Param{Type}} = $Param{Mapping};

    return 1;
}

sub SetFilter {
    my ( $Self, %Param ) = @_;

    # check needed params
    for my $Needed (qw(Type Filter)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    $Self->{Filter}->{$Param{Type}} = $Param{Filter};

    return 1;
}

sub ParseOptions {
    my ( $Self, %Param ) = @_;

    # parse options
    $Self->{Options} = {};
    foreach my $OptionDef ( split(/,/, ($Param{Options} || '')) ) {
        my ($Option, $Value) = split(/=/, $OptionDef);
        $Self->{Options}->{$Option} = $Value;
    }

    if ( !$Self->{Options}->{URL} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Got no URL!',
        );
        return;
    }

    if ( $Self->{Options}->{Ignore} ) {
        $Self->{Options}->{Ignore} = [ split(/,/, $Self->{Options}->{Ignore}) ];
    }

    return 1;
}

sub InitProgress {
    my ( $Self, %Param ) = @_;

    if ( $Self->{Debug} ) {
        $Self->_Debug("[$Param{Type}](InitProgress) initializing progress data (count: $Param{ItemCount})");
    }

    my $MigrationState = $Self->_GetMigrationState();

    if ( !IsHashRefWithData($MigrationState->{State}->{Progress}->{$Param{Type}}) ) {
        my %Progress = (
            ElapsedTime => 0,
            Current     => 0,
            ItemCount   => $Param{ItemCount},
            OK          => 0,
            Error       => 0,
            Ignored     => 0,
            Status      => Kernel::Language::Translatable('pending'),
        );
        $MigrationState->{State}->{Progress}->{$Param{Type}} = \%Progress;
    }
    else {
        $MigrationState->{State}->{Progress}->{$Param{Type}}->{ItemCount} = $Param{ItemCount};
    }

    # update the state of the migration in cache
    $Self->_UpdateMigrationState($MigrationState);
}

sub UpdateProgress {
    my ( $Self, $Type, $Result ) = @_;

    my $MigrationState = $Self->_GetMigrationState();

    # abort if we don't have a state
    return if $MigrationState->{Status} eq 'aborting';

    my $Progress = $MigrationState->{State}->{Progress}->{$Type};

    $Progress->{Current}++;
    $Progress->{$Result}++;

    $Progress->{ElapsedTime} = Time::HiRes::time() - $Progress->{StartTime};
    $Progress->{Status}      = Kernel::Language::Translatable('in progress');

    if ( $Progress->{ElapsedTime} > 10 ) {
        # add forecast after 10 seconds
        $Progress->{AvgPerMinute} = $Progress->{Current} / $Progress->{ElapsedTime} * 60;

        my $TimeRemaining = ($Progress->{ItemCount} - $Progress->{Current}) / $Progress->{AvgPerMinute} * 60;
        my $RemainingHours = int($TimeRemaining / 3600);
        my $RemainingMins  = int(($TimeRemaining - $RemainingHours * 3600) / 60);
        $Progress->{TimeRemaining} = sprintf "%i:%02i:%02i", $RemainingHours, $RemainingMins, $TimeRemaining - ($RemainingHours * 3600 + $RemainingMins * 60);
    }

    # update the state of the migration in cache
    $Self->_UpdateMigrationState($MigrationState);

    # we don't need to write the output to the console if we are running in background
    return if $Self->{Async} || $MigrationState->{Status} ne 'in progress';

    $Self->OutputProgress($Type);
}

sub UpdateProgressStatus {
    my ( $Self, $Type, $Status ) = @_;

    my $MigrationState = $Self->_GetMigrationState();

    $MigrationState->{State}->{Progress}->{$Type}->{Status} = $Status;

    # update the state of the migration in cache
    $Self->_UpdateMigrationState($MigrationState);

    # we don't need to write the output to the console if we are running in background
    return if $Self->{Async};

    $Self->OutputProgress($Type);
}

sub StopProgress {
    my ( $Self, $Type, $Summary ) = @_;

    my $MigrationState = $Self->_GetMigrationState();
    my $Progress = $MigrationState->{State}->{Progress}->{$Type};

    $Progress->{EndTime} = Time::HiRes::time();
    $Progress->{AvgPerMinute} = $Progress->{Current} / ($Progress->{EndTime} - $Progress->{StartTime}) * 60;
    $Progress->{Status}  = $MigrationState->{Status} eq 'aborting' ? Kernel::Language::Translatable('aborted') : Kernel::Language::Translatable('finished');

    # delete obsolete information
    foreach ( qw(ElapsedTime TimeRemaining) ) {
        delete $Progress->{$_};
    }

    # update the state of the migration in cache
    $Self->_UpdateMigrationState($MigrationState);


    # we don't need to write the output to the console if we are running in background
    return 1 if $Self->{Async};

    $Self->OutputProgress($Type);
    print "\n";

    return 1;
}

sub OutputProgress {
    my ( $Self, $Type ) = @_;

    STDOUT->autoflush(1);

    my $MigrationState = $Self->_GetMigrationState();
    my $Progress = $MigrationState->{State}->{Progress}->{$Type};

    my $Output = sprintf "  %7i %s", $Progress->{ItemCount}, $Type;
    $Output = sprintf "%s%s ", $Output, '.' x ( 50 - length($Output) );

    my $Forecast = '';
    if ( $Progress->{AvgPerMinute} || $Progress->{TimeRemaining} ) {
        $Forecast = sprintf "(average: %i/min, time remaining: %s)", $Progress->{AvgPerMinute}, $Progress->{TimeRemaining};
    }
    if ( $Progress->{Status} eq 'in progress' ) {
        printf "%s%s %i %s%s\r", $Output, $Progress->{Status}, $Progress->{Current}, $Forecast, ' ' x 60;
    }
    elsif ( $Progress->{Status} eq 'finished' ) {
        printf "%s%s (%i ms, %i OK / %i error / %i ignored)%s\r", $Output, $Progress->{Status}, ($Progress->{EndTime} - $Progress->{StartTime}) * 1000, $Progress->{OK}, $Progress->{Error}, $Progress->{Ignored}, ' ' x 60;
    }
    else {
        printf "%s%s%s\r", $Output, $Progress->{Status}, ' ' x 60;
    }
}

sub SetWorkers {
    my ( $Self, %Param ) = @_;

    $Self->{Workers} = $Param{Workers};
}

sub _GetTableColumnNames {
    my ( $Self, %Param ) = @_;

    $Self->{ColumnNames} //= {};

    if ( !IsHashRefWithData($Self->{ColumnNames}->{$Param{Table}}) ) {

        $Kernel::OM->Get('DB')->Prepare(
            SQL   => 'SELECT * FROM ' . $Param{Table},
            Limit => 1,
        ) || die "Unable to execute SQL statement!";

        my @Names = $Kernel::OM->Get('DB')->GetColumnNames();
        $Self->{ColumnNames}->{$Param{Table}} = { map { $_ => 1 } @Names };
    }

    return %{$Self->{ColumnNames}->{$Param{Table}}};
}

sub _RunParallel {
    my ( $Self, $Sub, %Param ) = @_;

    # check needed stuff
    if ( !ref $Sub eq 'CODE' ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Sub as a function ref!",
        );
        return;
    }

    for my $Needed (qw(Items)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    $SIG{INT} = sub {
        print "exiting threads\n";

        foreach my $t ( threads->list() ) {
            $t->kill('INT');
        }
        foreach my $t ( threads->list() ) {
            $t->join();
        }

        exit 0;
    };

    use threads;
    use threads::shared;
    use Thread::Queue;
    use Thread::Semaphore;

    my $WorkQueue : shared;
    $WorkQueue = Thread::Queue->new();
    my $ResultQueue : shared;
    $ResultQueue = Thread::Queue->new();

    my $MainPID = $$;
    my $Semaphore = Thread::Semaphore->new();

    # create parallel instances
    my %Workers;
    foreach my $WorkerID ( 1..$Self->{Workers} ) {
        $Workers{$WorkerID}, threads->create(
            sub {
                my ( $Self, %Param ) = @_;

                $SIG{'INT'} = sub {
                    print "Thread exit\n";
                    threads->exit();
                };

                my $DBDPg_VERSION = $DBD::Pg::{VERSION};

                local $Kernel::OM = Kernel::System::ObjectManager->new(
                    'Log' => {
                        LogPrefix => 'migration-worker#'.$Param{WorkerID},
                    },
                    ClientRegistration => {
                        DisableClientNotifications => 1,
                    },
                    Migration => {
                        Debug => $Param{Debug},
                    }
                );
                $Kernel::OM->Get('DB')->Disconnect();
                $DBD::Pg::VERSION = $DBDPg_VERSION;

                $Self->{Debug} = $Param{Debug};

                while ( (my $Item = $Param{WorkQueue}->dequeue) ne "END_OF_QUEUE") {
                    my $Result;
                    eval {
                        $Result = $Sub->($Self, Item => $Item, %Param);
                    };
                    if ( !defined( $Result ) ) {
                        $Kernel::OM->Get('Log')->Log(
                            Priority => 'error',
                            Message  => 'Undefined result. Item = ' . Data::Dumper::Dumper( $Item )
                        );

                        # handle entries with undefined result as error
                        $Result = 'Error';
                    }

                    # abort if we don't have a state
                    last if $Self->_GetMigrationState()->{Status} eq 'aborting';

                    # update the progress
                    $Semaphore->down();
                    $Self->UpdateProgress($Param{Type}, $Result);
                    $Semaphore->up();
                }
            },
            $Self,
            %Param,
            Debug       => $Self->{Debug},
            WorkQueue   => $WorkQueue,
            ResultQueue => $ResultQueue,
            WorkerID    => $WorkerID,
        );
    }

    $WorkQueue->enqueue(@{$Param{Items}});

    foreach ( 1..$Self->{Workers} ) {
        $WorkQueue->enqueue("END_OF_QUEUE");
    }

    while (threads->list()) {
        my @Joinable = threads->list(threads::joinable);
        if (@Joinable) {
            $_->join for @Joinable;
        } else {
            sleep(0.050);
        }
    }

    return 1;
}

sub _GetMigrationState {
    my ( $Self, %Param ) = @_;

    my $State = $Kernel::OM->Get('Cache')->Get(
        Type      => 'Migration',
        Key       => $Self->{MigrationID},
    );

    return $State;
}

sub _UpdateMigrationState {
    my ( $Self, $State ) = @_;

    return $Kernel::OM->Get('Cache')->Set(
        Type      => 'Migration',
        Key       => $Self->{MigrationID},
        Value     => $State,
    );
}

#
# convenience wrappers
# 

sub SetCacheOptions {
    my ( $Self, %Param ) = @_;

    return $Kernel::OM->Get('Migration')->SetCacheOptions(
        Source   => $Self->{Source},
        SourceID => $Self->{SourceID},
        %Param,
    );
}

sub Lookup {
    my ( $Self, %Param ) = @_;

    my $Mapping = $Self->{Mapping};
    if ( !$Mapping ) {
        $Mapping = {
            $Param{Table} => $Self->Describe()->{Mapping}
        }
    }

    return $Kernel::OM->Get('Migration')->Lookup(
        Source   => $Self->{Source},
        SourceID => $Self->{SourceID},
        Mapping  => $Mapping,
        %Param,
    );
}

sub GetOIDMapping {
    my ( $Self, %Param ) = @_;

    return $Kernel::OM->Get('Migration')->GetOIDMapping(
        Source   => $Self->{Source},
        SourceID => $Self->{SourceID},
        %Param,
    );
}

sub GetOIDAdditionalData {
    my ( $Self, %Param ) = @_;

    return $Kernel::OM->Get('Migration')->GetOIDAdditionalData(
        Source   => $Self->{Source},
        SourceID => $Self->{SourceID},
        %Param,
    );
}

sub CreateOIDMapping {
    my ( $Self, %Param ) = @_;

    return $Kernel::OM->Get('Migration')->CreateOIDMapping(
        Source   => $Self->{Source},
        SourceID => $Self->{SourceID},
        %Param,
    );
}

sub ReplaceOIDMapping {
    my ( $Self, %Param ) = @_;

    return $Kernel::OM->Get('Migration')->ReplaceOIDMapping(
        Source   => $Self->{Source},
        SourceID => $Self->{SourceID},
        %Param,
    );
}

sub PreloadOIDMappings {
    my ( $Self, %Param ) = @_;

    return $Kernel::OM->Get('Migration')->PreloadOIDMappings(
        Source   => $Self->{Source},
        SourceID => $Self->{SourceID},
        %Param,
    );
}

sub _Debug {
    my ( $Self, $Message ) = @_;

    return if !$Self->{Debug};

    $Kernel::OM->Get('Migration')->_Debug($Message);
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
