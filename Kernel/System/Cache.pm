# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Cache;

use strict;
use warnings;

use Storable qw();
use Time::HiRes qw(time);

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = qw(
    ClientRegistration
    Config
    Log
);

=head1 NAME

Kernel::System::Cache - Key/value based data cache for KIX

=head1 SYNOPSIS

This is a simple data cache. It can store key/value data both
in memory and in a configured cache backend for persistent caching.

This can be controlled via the config settings C<Cache::InMemory> and
C<Cache::InBackend>. The backend can also be selected with the config setting
C<Cache::Module> and defaults to file system based storage for permanent caching.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $CacheObject = $Kernel::OM->Get('Cache');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # Store backend in $Self for fastest access.
    $Self->{CacheObject} = $Kernel::OM->Get($Param{Backend} || 'Kernel::System::Cache::Redis');

    $Self->{CacheInBackend} = $Param{CacheInBackend} // 1;
    $Self->{CacheInMemory}  = $Param{CacheInMemory} // 0;

    $Self->{IgnoreTypes} = {};

    $Self->{StatsEnabled} = $Param{StatsEnabled} // 0;

    $Self->{Debug} = 0;
    $Self->{DebugInitialized} = 0;

    return $Self;
}

=item Configure()

change cache configuration settings at runtime. You can use this to disable the cache in
environments where it is not desired, such as in long running scripts.

please, to turn CacheInMemory off in persistent environments.

    $CacheObject->Configure(
        CacheInMemory  => 1,    # optional
        CacheInBackend => 1,    # optional
    );

=cut

sub Configure {
    my ( $Self, %Param ) = @_;

    SETTING:
    for my $Setting (qw(CacheInMemory CacheInBackend)) {
        next SETTING if !exists $Param{$Setting};
        $Self->{$Setting} = $Param{$Setting} ? 1 : 0;
    }

    return;
}

=item Set()

store a value in the cache.

    $CacheObject->Set(
        Type     => 'ObjectName',      # only [a-zA-Z0-9_] chars usable
        Depends  => [],                # optional, invalidate this cache key if one of these cachetypes will be cleared or keys deleted
        Key      => 'SomeKey',
        Value    => 'Some Value',
        TTL      => 60 * 60 * 24 * 20, # seconds, this means 20 days
    );

The Type here refers to the group of entries that should be cached and cleaned up together,
usually this will represent the KIX object that is supposed to be cached, like 'Ticket'.

The Key identifies the entry (together with the type) for retrieval and deletion of this value.

The TTL controls when the cache will expire. Please note that the in-memory cache is not persistent
and thus has no TTL/expiry mechanism.

Please note that if you store complex data, you have to make sure that the data is not modified
in other parts of the code as the in-memory cache only refers to it. Otherwise also the cache would
contain the modifications. If you cannot avoid this, you can disable the in-memory cache for this
value:

    $CacheObject->Set(
        Type  => 'ObjectName',
        Key   => 'SomeKey',
        Value => { ... complex data ... },

        TTL            => 60 * 60 * 24 * 1,  # optional, default 20 days
        CacheInMemory  => 0,                 # optional, defaults to 1
        CacheInBackend => 1,                 # optional, defaults to 1
        NoStatsUpdate  => 1,                 # optional, don't update cache stats (i.e. for internal cache keys)
    );

=cut

sub Set {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(Type Key Value)) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    return if $Self->{IgnoreTypes}->{$Param{Type}};

    # we have to initialize it here instead of the constructor, to prevent a deep recursion
    if ( !$Self->{DebugInitialized} ) {
        $Self->{Debug} = $Kernel::OM->Get('Config')->Get('Cache::Debug');
        $Self->{DebugInitialized} = 1;
    }

    # set default TTL to 20 days
    $Param{TTL} //= 60 * 60 * 24 * 20;

    # Enforce cache type restriction to make sure it works properly on all file systems.
    if ( $Param{Type} !~ m{ \A [a-zA-Z0-9_]+ \z}smx ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Cache Type '$Param{Type}' contains invalid characters, use [a-zA-Z0-9_] only!",
            );
        }
        return;
    }

    # debug
    if ( $Self->{Debug} ) {
        $Self->_Debug('', "Set Key:$Param{Key} TTL:$Param{TTL}!");
    }

    # store TypeDependencies information
    if (ref $Param{Depends} eq 'ARRAY') {
        if ( !$Self->{TypeDependencies} ) {
            # load information from backend
            $Self->{TypeDependencies} = $Self->{CacheObject}->Get(
                Type => 'Cache',
                Key  => 'TypeDependencies',
            );
        }
        my $Changed = 0;
        foreach my $Type (@{$Param{Depends}}) {
            # ignore same type as dependency
            next if $Type eq $Param{Type};

            if ( !exists $Self->{TypeDependencies}->{$Type} || !exists $Self->{TypeDependencies}->{$Type}->{$Param{Type}} ) {
                $Changed = 1;
                if ( $Self->{Debug} ) {
                    $Self->_Debug('', "adding dependent cache type \"$Param{Type}\" to cache type \"$Type\".");
                }
                $Self->{TypeDependencies}->{$Type}->{$Param{Type}} = 1;
            }
        }

        if ( $Changed && $Self->{CacheInBackend} && $Param{CacheInBackend} // 1 && $Self->{TypeDependencies} ) {
            # update cache dependencies in backend only if something has changed
            if ( $Self->{Debug} ) {
                use Data::Dumper;
                $Self->_Debug('', "updating gobal cache dependency information: ".Dumper($Self->{TypeDependencies}));
            }
            $Self->{CacheObject}->Set(
                Type => 'Cache',
                Key  => 'TypeDependencies',
                Value => $Self->{TypeDependencies},
                TTL   => 60 * 60 * 24 * 20,         # 20 days
            );
        }
    }

    # Set in-memory cache.
    if ( $Self->{CacheInMemory} && ( $Param{CacheInMemory} // 1 ) ) {
        if ( $Self->{Debug} ) {
            $Self->_Debug('', "set in-memory cache key \"$Param{Key}\"");
        }
        $Self->{Cache}->{ $Param{Type} }->{ $Param{Key} } = $Param{Value};
    }

    # If in-memory caching is not active, make sure the in-memory
    #   cache is not in an inconsistent state.
    else {
        delete $Self->{Cache}->{ $Param{Type} }->{ $Param{Key} };
    }

    # update stats
    if ( !$Param{NoStatsUpdate} && $Self->{StatsEnabled} ) {
        $Self->_UpdateCacheStats(
            Operation => 'Set',
            %Param,
        );
    }

    # Set persistent cache.
    if ( $Self->{CacheInBackend} && ( $Param{CacheInBackend} // 1 ) ) {
        return $Self->{CacheObject}->Set(%Param);
    }

    # If persistent caching is not active, make sure the persistent
    #   cache is not in an inconsistent state.
    else {
        return $Self->{CacheObject}->Delete(%Param);
    }

    return 1;
}

=item Get()

fetch a value from the cache.

    my $Value = $CacheObject->Get(
        Type => 'ObjectName',       # only [a-zA-Z0-9_] chars usable
        Key  => 'SomeKey',
    );

Please note that if you store complex data, you have to make sure that the data is not modified
in other parts of the code as the in-memory cache only refers to it. Otherwise also the cache would
contain the modifications. If you cannot avoid this, you can disable the in-memory cache for this
value:

    my $Value = $CacheObject->Get(
        Type => 'ObjectName',
        Key  => 'SomeKey',

        CacheInMemory  => 0,    # optional, defaults to 1
        CacheInBackend => 1,    # optional, defaults to 1
        NoStatsUpdate  => 1,    # optional, don't update cache stats (i.e. for internal cache keys)
    );


=cut

sub Get {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(Type Key)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    return if $Self->{IgnoreTypes}->{$Param{Type}};

    # check in-memory cache
    if ( $Self->{CacheInMemory} && ( $Param{CacheInMemory} // 1 ) ) {
        if ( exists $Self->{Cache}->{ $Param{Type} }->{ $Param{Key} } ) {
            if ( !$Param{NoStatsUpdate} && $Self->{StatsEnabled} ) {
                $Self->_UpdateCacheStats(
                    Operation => 'Get',
                    Result    => 'HIT',
                    %Param,
                );
            }
            return $Self->{Cache}->{ $Param{Type} }->{ $Param{Key} };
        }
    }

    if ( !$Self->{CacheInBackend} || !( $Param{CacheInBackend} // 1 ) ) {
        if ( !$Param{NoStatsUpdate} && $Self->{StatsEnabled} ) {
            $Self->_UpdateCacheStats(
                Operation => 'Get',
                Result    => 'MISS',
                %Param,
            );
        }
        return;
    }

    # check persistent cache
    my $Value = $Self->{CacheObject}->Get(%Param);

    # set in-memory cache
    if ( defined $Value ) {
        if ( !$Param{NoStatsUpdate} && $Self->{StatsEnabled} ) {
            $Self->_UpdateCacheStats(
                Operation => 'Get',
                Result    => 'HIT',
                %Param,
            );
        }
        if ( $Self->{CacheInMemory} && ( $Param{CacheInMemory} // 1 ) ) {
            $Self->{Cache}->{ $Param{Type} }->{ $Param{Key} } = $Value;
        }
    }
    else {
        if ( !$Param{NoStatsUpdate} && $Self->{StatsEnabled} ) {
            $Self->_UpdateCacheStats(
                Operation => 'Get',
                Result    => 'MISS',
                %Param,
            );
        }
    }

    return $Value;
}

=item GetMulti()

Fetches values for multiple keys from cache backend. Works like Get and returns an ArrayRef

    my $Values = $CacheObject->GetMulti(
        Type => 'ObjectName',       # only [a-zA-Z0-9_] chars usable
        Keys => [ 'SomeKey1', 'SomeKey2' ]
    );

=cut

sub GetMulti {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(Type Keys)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    return if $Self->{IgnoreTypes}->{$Param{Type}};

    # check in-memory cache
    if ( $Self->{CacheInMemory} && ( $Param{CacheInMemory} // 1 ) ) {
        my @Results;
        foreach my $Key ( @{$Param{Keys}} ) {
            if ( exists $Self->{Cache}->{ $Param{Type} }->{$Key} ) {
                if ( !$Param{NoStatsUpdate} && $Self->{StatsEnabled} ) {
                    $Self->_UpdateCacheStats(
                        Operation => 'Get',
                        Result    => 'HIT',
                        %Param,
                    );
                }
                push(@Results, $Self->{Cache}->{ $Param{Type} }->{$Key});
            }
        }
        return \@Results if IsArrayRefWithData(\@Results);
    }

    if ( !$Self->{CacheInBackend} || !( $Param{CacheInBackend} // 1 ) ) {
        foreach my $Key ( @{$Param{Keys}} ) {
            next if $Param{NoStatsUpdate} || !$Self->{StatsEnabled};

            $Self->_UpdateCacheStats(
                Operation => 'Get',
                Result    => 'MISS',
                %Param,
                Key       => $Key,
            );
        }
        return;
    }

    # check persistent cache
    my  @Values = $Self->{CacheObject}->GetMulti(%Param);

    # set in-memory cache
    if ( @Values ) {
        my $Index = 0;
        foreach my $Key ( @{$Param{Keys}} ) {
            if ( !$Param{NoStatsUpdate} && $Self->{StatsEnabled} ) {
                $Self->_UpdateCacheStats(
                    Operation => 'Get',
                    Result    => 'HIT',
                    %Param,
                    Key       => $Key,
                );
            }
            if ( $Self->{CacheInMemory} && ( $Param{CacheInMemory} // 1 ) ) {
                $Self->{Cache}->{ $Param{Type} }->{ $Key } = $Values[$Index++];
            }
        }
    }
    else {
        foreach my $Key ( @{$Param{Keys}} ) {
            next if $Param{NoStatsUpdate} || $Self->{StatsEnabled};

            $Self->_UpdateCacheStats(
                Operation => 'Get',
                Result    => 'MISS',
                %Param,
                Key       => $Key,
            );
        }
    }

    return @Values;
}

=item Delete()

deletes a single value from the cache.

    $CacheObject->Delete(
        Type           => 'ObjectName',       # only [a-zA-Z0-9_] chars usable
        Key            => 'SomeKey',
        NoStatsUpdate  => 1,                  # optional, don't update cache stats (i.e. for internal cache keys)
    );

Please note that despite the cache configuration, Delete and CleanUp will always
be executed both in memory and in the backend to avoid inconsistent cache states.

=cut

sub Delete {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(Type Key)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    return if $Self->{IgnoreTypes}->{$Param{Type}};

    # we have to initialize it here instead of the constructor, to prevent a deep recursion
    if ( !$Self->{DebugInitialized} ) {
        $Self->{Debug} = $Kernel::OM->Get('Config')->Get('Cache::Debug');
        $Self->{DebugInitialized} = 1;
    }

    $Param{Indent} = $Param{Indent} || '';

    # Delete and cleanup operations should also be done if the cache is disabled
    #   to avoid inconsistent states.

    # delete from in-memory cache
    delete $Self->{Cache}->{ $Param{Type} }->{ $Param{Key} };

    # delete from persistent cache
    return if !$Self->{CacheObject}->Delete(%Param);

    # check and delete depending caches
    $Self->_HandleDependingCacheTypes(
        Type   => $Param{Type},
        Indent => $Param{Indent}.'    '
    );

    if ( !$Param{NoStatsUpdate} && $Self->{StatsEnabled} ) {
        $Self->_UpdateCacheStats(
            Operation => 'Delete',
            %Param,
        );
    }

    return 1;
}

=item CleanUp()

delete parts of the cache or the full cache data.

To delete the whole cache:

    $CacheObject->CleanUp();

To delete the data of only one cache type:

    $CacheObject->CleanUp(
        Type => 'ObjectName',   # only [a-zA-Z0-9_] chars usable
    );

To delete all data except of some types:

    $CacheObject->CleanUp(
        KeepTypes => ['Object1', 'Object2'],
    );

To delete only expired cache data:

    $CacheObject->CleanUp(
        Expired => 1,   # optional, defaults to 0
    );

Type/KeepTypes and Expired can be combined to only delete expired data of a single type
or of all types except the types to keep.

Please note that despite the cache configuration, Delete and CleanUp will always
be executed both in memory and in the backend to avoid inconsistent cache states.

=cut

sub CleanUp {
    my ( $Self, %Param ) = @_;
    my $NotifyClients = 0;

    $Param{Indent} = $Param{Indent} || '';

    # we have to initialize it here instead of the constructor, to prevent a deep recursion
    if ( !$Self->{DebugInitialized} ) {
        $Self->{Debug} = $Kernel::OM->Get('Config')->Get('Cache::Debug');
        $Self->{DebugInitialized} = 1;
    }

    if ( $Param{KeepTypes} && $Self->{Debug} ) {
        $Self->_Debug($Param{Indent}, "cleaning up everything except: ".join(', ', @{$Param{KeepTypes}}));
    }

    # save to prevent cleanup loops
    $Self->{CleanupTypesSeen}->{$Param{Type}} = 1 if $Param{Type};

    # cleanup in-memory cache
    # We don't have TTL/expiry information here, so just always delete to be sure.
    if ( $Param{Type} ) {
        delete $Self->{Cache}->{ $Param{Type} };

        # check and delete depending caches
        $Self->_HandleDependingCacheTypes(
            Type   => $Param{Type},
            Indent => $Param{Indent}.'    '
        );

        if ( !$Param{NoStatsUpdate} && $Self->{StatsEnabled} ) {
            $Self->_UpdateCacheStats(
                Operation => 'CleanUp',
                %Param,
            );
        }
    }
    elsif ( $Param{KeepTypes} ) {
        my %KeepTypeLookup;
        @KeepTypeLookup{ ( @{ $Param{KeepTypes} || [] } ) } = undef;
        TYPE:
        for my $Type ( sort keys %{ $Self->{Cache} || {} } ) {
            next TYPE if exists $KeepTypeLookup{$Type};

            delete $Self->{Cache}->{$Type};

            # check and delete depending caches
            $Self->_HandleDependingCacheTypes(
                Type   => $Type,
                Indent => $Param{Indent}.'    '
            );

            if ( !$Param{NoStatsUpdate} && $Self->{StatsEnabled} ) {
                $Self->_UpdateCacheStats(
                    Operation => 'CleanUp',
                    Type      => $Type
                );
            }
        }
    }
    else {
        my @AdditionalKeepTypes;
        my $AlwaysKeepTypes = $Kernel::OM->Get('Config')->Get('Cache::AlwaysKeepTypesOnCompleteCleanUp');
        if ( IsHashRefWithData($AlwaysKeepTypes) ) {
            # extend relevant param with the list of activated types
            @AdditionalKeepTypes = grep { defined $_ } map { $AlwaysKeepTypes->{$_} ? $_ : undef } keys %{$AlwaysKeepTypes};
            if ( @AdditionalKeepTypes ) {
                $Param{KeepTypes} = \(@{$Param{KeepTypes} || []}, @AdditionalKeepTypes);
            }
        }

        delete $Self->{Cache};
        delete $Self->{TypeDependencies};

        # delete persistent cache
        if ( $Self->{CacheInBackend} ) {
            $Self->{CacheObject}->Delete(
                Type => 'Cache',
                Key  => 'TypeDependencies',
            );
        }

        # some debug output
        if ( $Self->{Debug} ) {
            if ( !$Param{KeepTypes} ) {
                $Self->_Debug($Param{Indent}, "cleaning up everything");
            }
            else {
                $Self->_Debug($Param{Indent}, "cleaning up everything except: ".join(', ', @{$Param{KeepTypes}}));
            }
        }

        if ( !$Param{NoStatsUpdate} && $Self->{StatsEnabled} ) {
            $Self->_UpdateCacheStats(
                Operation => 'CleanUp',
                %Param,
            );
        }

        $NotifyClients = 1;
    }

    # clear loop prevention for this type
    $Self->{CleanupTypesSeen}->{$Param{Type}} = 0 if $Param{Type};

    # cleanup persistent cache
    my $Result = $Self->{CacheObject}->CleanUp(%Param);

    if ( $Result && $NotifyClients ) {
        # send notification to clients
        $Kernel::OM->Get('ClientNotification')->NotifyClients(
            Event     => 'CLEAR_CACHE',
            Namespace => 'Migration',
        );
    }

    return $Result;
}

=item GetCacheStats()

return the cache statistics

    my $HashRef = $CacheObject->GetCacheStats();

=cut

sub GetCacheStats {
    my ( $Self, %Param ) = @_;
    my $Result;

    my @Keys = $Self->{CacheObject}->GetKeysForType(
        Type => 'CacheStats'
    );

    foreach my $Key (@Keys) {
        my $CacheStats = $Self->{CacheObject}->Get(
            Type      => 'CacheStats',
            Key       => $Key,
            UseRawKey => 1,
        );
        if ( $CacheStats ) {
            foreach my $Type (keys %{$CacheStats}) {
                if (!exists $Result->{$Type}) {
                    $Result->{$Type}->{AccessCount}  = 0;
                    $Result->{$Type}->{HitCount}     = 0;
                    $Result->{$Type}->{CleanupCount} = 0;
                    $Result->{$Type}->{DeleteCount}  = 0;
                }
                $Result->{$Type}->{AccessCount}  += $CacheStats->{$Type}->{AccessCount} || 0;
                $Result->{$Type}->{HitCount}     += $CacheStats->{$Type}->{HitCount} || 0;
                $Result->{$Type}->{KeyCount}     += $CacheStats->{$Type}->{KeyCount} || 0;
                $Result->{$Type}->{CleanupCount} += $CacheStats->{$Type}->{CleanupCount} || 0;
                $Result->{$Type}->{DeleteCount}  += $CacheStats->{$Type}->{DeleteCount} || 0;
            }
        }
    }

    return $Result;
}

=item DeleteCacheStats()

delete the cache statistics

    my $Result = $CacheObject->DeleteCacheStats();

=cut

sub DeleteCacheStats {
    my ( $Self, %Param ) = @_;

    return $Self->{CacheObject}->CleanUp(
        Type => 'CacheStats'
    );
}

=item GetKeysForType()

get a list of keys for a given cache type

    my @Keys = $CacheObject->GetKeysForType(
        Type => '...'           # required
    );

=cut

sub GetKeysForType {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(Type)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    return () if $Self->{IgnoreTypes}->{$Param{Type}};

    return $Self->{CacheObject}->GetKeysForType(
        Type => $Param{Type}
    );
}

=item SetSemaphore()

create a semaphore

    my $Success = $CacheObject->SetSemaphore(
        ID      => '...',
        Value   => '...',
        Timeout => 123,
    );

=cut

sub SetSemaphore {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(ID Timeout Value)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    return 1 if !$Self->{CacheObject}->can('SetSemaphore');

    my $Success;
    do {
        $Success = $Self->{CacheObject}->SetSemaphore(
            %Param
        );
        if ( !$Success ) {
            Time::HiRes::sleep 0.01;
        }
    }
    while ( !$Success );

    return 1;
}

=item ClearSemaphore()

clear a semaphore

    my $Success = $CacheObject->ClearSemaphore(
        ID    => '...',
        Value => '...'
    );

=cut

sub ClearSemaphore {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(ID Value)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    return 1 if !$Self->{CacheObject}->can('SetSemaphore');

    return $Self->{CacheObject}->ClearSemaphore(
        %Param
    );
}

=item _HandleDependingCacheTypes()

deletes relevant keys of depending cache types

    $CacheObject->_HandleDependingCacheTypes(
        Type => '...'
    );

=cut

sub _HandleDependingCacheTypes {
    my ( $Self, %Param ) = @_;

    $Param{Indent} = $Param{Indent} || '';

    # load information from backend - do not use list in self (necessary for scheduler tasks)
    $Self->{TypeDependencies} = $Self->{CacheObject}->Get(
        Type => 'Cache',
        Key  => 'TypeDependencies',
    );

    if ( $Self->{TypeDependencies} && IsHashRefWithData($Self->{TypeDependencies}->{$Param{Type}}) ) {
        if ( $Self->{Debug} ) {
            $Self->_Debug($Param{Indent}, "type \"$Param{Type}\" of deleted key affects other cache types: ".join(', ', keys %{$Self->{TypeDependencies}->{$Param{Type}}}));
        }

        foreach my $DependentType ( keys %{$Self->{TypeDependencies}->{$Param{Type}}} ) {
            if ( $Self->{Debug} ) {
                $Self->_Debug($Param{Indent}, "    cleaning up depending cache type \"$DependentType\"");
            }

            delete $Self->{TypeDependencies}->{$Param{Type}}->{$DependentType};

            # delete whole type if all keys are deleted
            if ( !IsHashRefWithData($Self->{TypeDependencies}->{$Param{Type}}) ) {
                if ( $Self->{Debug} ) {
                    $Self->_Debug($Param{Indent}, "        no dependencies left for type $Param{Type}, deleting entry");
                }
                delete $Self->{TypeDependencies}->{$Param{Type}};
            }

            if ( !IsHashRefWithData($Self->{TypeDependencies}) ) {
                $Self->{TypeDependencies} = undef;
            }

            # don't do another loop, if we've seen this type already
            next if $Self->{CleanupTypesSeen}->{$DependentType};

            $Self->CleanUp(
                Type => $DependentType,
            );
        }
    }

    return 1;
}

=item _UpdateCacheStats()

update the cache statistics

    $CacheObject->_UpdateCacheStats(
        Type => '...'
    );

=cut

sub _UpdateCacheStats {
    my ( $Self, %Param ) = @_;

    # do nothing if cache stats are not enabled
    return if !$Self->{StatsEnabled};

    # read stats
    my $CacheStats = $Self->{CacheObject}->Get(
        Type          => 'CacheStats',
        Key           => $$,
        NoStatsUpdate => 1,
    ) || {};

    # add to stats
    if ( $Param{Operation} eq 'Set' ) {
        $CacheStats->{$Param{Type}}->{KeyCount}++;
    }
    elsif ( $Param{Operation} eq 'Get' ) {
        $CacheStats->{$Param{Type}}->{AccessCount}++;
        if ($Param{Result} eq 'HIT') {
            $CacheStats->{$Param{Type}}->{HitCount}++
        }
    }
    elsif ( $Param{Operation} eq 'Delete' ) {
        if ($CacheStats->{$Param{Type}}->{KeyCount}) {
            $CacheStats->{$Param{Type}}->{KeyCount}--;
        }
        $CacheStats->{$Param{Type}}->{DeleteCount}++;
    }
    elsif ( $Param{Operation} eq 'CleanUp' ) {
        if ( $Param{Type} ) {
            $CacheStats->{$Param{Type}}->{KeyCount} = 0;
            $CacheStats->{$Param{Type}}->{CleanupCount}++;
        }
        else {
            # clear stats of each type and incease cleanup counter
            foreach my $Type ( keys %{$CacheStats} ) {
                foreach my $Key ( keys %{$CacheStats->{$Type}} ) {
                    next if $Key eq 'CleanupCount';
                    $CacheStats->{$Type}->{$Key} = 0;
                }
                $CacheStats->{$Type}->{CleanupCount}++;
            }
        }
    }

    # store updated stats
    $Self->{CacheObject}->Set(
        Type          => 'CacheStats',
        Key           => $$,
        Value         => $CacheStats,
        NoStatsUpdate => 1,
    );

    return 1;
}

sub _Debug {
    my ( $Self, $Indent, $Message ) = @_;

    return if !$Self->{Debug};
    return if !$Message;

    $Indent ||= '';

    printf STDERR "%f (%5i) %-15s %s%s\n", Time::HiRes::time(), $$, "[Cache]", $Indent, $Message;
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
