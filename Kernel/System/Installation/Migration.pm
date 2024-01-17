# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Installation::Migration;

use strict;
use warnings;

use List::Util qw(uniq);
use Time::HiRes qw(gettimeofday);

use Kernel::System::VariableCheck qw(:all);

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $MigrationObject = $Kernel::OM->Get('Migration');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item MigrationSupportedTypeList()

get the list of supported object types for the given source

    my @Result = $InstallationObject->MigrationSupportedTypeList(
        Source      => 'KIX17'          # the source
    );

=cut

sub MigrationSupportedTypeList {
    my ( $Self, %Param ) = @_;

    my $Home = $ENV{KIX_HOME} || $Kernel::OM->Get('Config')->Get('Home');

    # get all object handler modules
    my $SourceList = $Kernel::OM->Get('Config')->Get('Migration::Sources');
    if ( !IsHashRefWithData($SourceList) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'No registered sources available!',
        );
        return;
    }

    if ( !$SourceList->{$Param{Source}} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Source \"$Param{Source}\" not supported!",
        );
        return;
    }

    $Kernel::OM->ObjectParamAdd(
        $SourceList->{$Param{Source}}->{Module} => {
            %Param,
        },
    );

    my $BackendObject = $Kernel::OM->Get(
        $SourceList->{$Param{Source}}->{Module}
    );
    if ( !$BackendObject ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to load backend for source \"$Param{Source}\"!",
        );
        return;
    }

    return $BackendObject->ObjectTypeList(
        %Param,
    );
}

=item CountMigratableObjects()

count the number of migratable objects in the given data source

    my %Result = $InstallationObject->CountMigratableObjects(
        Source      => 'KIX17'          # the type of source to get the data from
        Options     => '...'            # optional, source specific
        ObjectType  => 'Ticket,FAQ'     # optional, if not given all supported objects will be migrated
    );

=cut

sub CountMigratableObjects {
    my ( $Self, %Param ) = @_;

    my $Home = $ENV{KIX_HOME} || $Kernel::OM->Get('Config')->Get('Home');

    # get all object handler modules
    my $SourceList = $Kernel::OM->Get('Config')->Get('Migration::Sources');
    if ( !IsHashRefWithData($SourceList) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'No registered sources available!',
        );
        return;
    }

    if ( !$SourceList->{$Param{Source}} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Source \"$Param{Source}\" not supported!",
        );
        return;
    }

    $Kernel::OM->ObjectParamAdd(
        $SourceList->{$Param{Source}}->{Module} => {
            %Param,
        },
    );

    my $BackendObject = $Kernel::OM->Get(
        $SourceList->{$Param{Source}}->{Module}
    );
    if ( !$BackendObject ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to load backend for source \"$Param{Source}\"!",
        );
        return;
    }

    return $BackendObject->Count(
        %Param,
    );
}

=item MigrationStart()

migrate the data from another source

    my $Result = $InstallationObject->MigrationStart(
        Source      => 'KIX17'          # the type of source to get the data from
        SourceID    => 'my-system123'   # the ID of the source
        Options     => '...'            # optional, source specific
        Filter      => '...'            # optional, source specific
        ObjectType  => 'Ticket,FAQ'     # optional, if not given all supported objects will be migrated
        MappingFile => 'mappings.json'  # optional
        Workers     => 4,               # optional, number of workers to used if something can be parallelly executed
        Async       => 1,               # optional, start migration as a background process
    );

=cut

sub MigrationStart {
    my ( $Self, %Param ) = @_;

    my $Home = $ENV{KIX_HOME} || $Kernel::OM->Get('Config')->Get('Home');

    # get all object handler modules
    my $SourceList = $Kernel::OM->Get('Config')->Get('Migration::Sources');
    if ( !IsHashRefWithData($SourceList) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'No registered sources available!',
        );
        return;
    }

    if ( !$SourceList->{$Param{Source}} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Source \"$Param{Source}\" not supported!",
        );
        return;
    }

    if ( !$Param{SourceID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "SourceID not given!",
        );
        return;
    }

    my $Mapping;
    if ( $Param{MappingFile} ) {
        my $Content = $Kernel::OM->Get('Main')->FileRead(
            Location => $Param{MappingFile}
        );
        if ( !$Content ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to open mapping file \"$Param{MappingFile}\"!",
            );
            return;
        }
        $Mapping = $Kernel::OM->Get('JSON')->Decode(
            Data => $$Content
        );
    }

    # create MigrationID
    my $Timestamp = gettimeofday();
    my $MigrationID = $$.'_'.$Timestamp;

    # clear metadata and init new cache entry
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => 'Migration'
    );
    $Kernel::OM->Get('Cache')->Set(
        Type  => 'Migration',
        Key   => $MigrationID,
        Value => {
            ID     => $MigrationID,
            Status => 'pending',
            %Param,
        }
    );

    if ( $Param{Async} ) {

        my $TaskID = $Self->AsyncCall(
            ObjectName     => $Kernel::OM->GetModuleFor('Installation'),
            FunctionName   => '_MigrationStart',
            FunctionParams => {
                %Param,
                BackendModule => $SourceList->{$Param{Source}}->{Module},
                MigrationID   => $MigrationID,
                Mapping       => $Mapping,
            },
            MaximumParallelInstances => 1,
        );

        return $MigrationID;
    }

    return $Self->_MigrationStart(
        %Param,
        BackendModule => $SourceList->{$Param{Source}}->{Module},
        MigrationID   => $MigrationID,
        Mapping       => $Mapping,
    );
}

sub _MigrationStart {
    my ($Self, %Param) = @_;

    $Kernel::OM->ObjectParamAdd(
        $Param{BackendModule} => {
            %Param,
        },
        ClientRegistration => {
            DisableClientNotifications => 1,
        },
    );

    my $BackendObject = $Kernel::OM->Get(
        $Param{BackendModule}
    );
    if ( !$BackendObject ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to load backend for source \"$Param{Source}\"!",
        );
        return;
    }

    my $Result = $BackendObject->Run(
        %Param,
    );

    # clearing cache to use new data
    $Kernel::OM->Get('Cache')->CleanUp();

    # enable client notifications again
    $Kernel::OM->Get('ClientRegistration')->{DisableClientNotifications} = 0;

    # send notification to clients
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'CLEAR_CACHE',
        Namespace => 'Migration',
    );

    return 1;
}

sub MigrationList {
    my ($Self, %Param) = @_;
    my @Result;

    my @MigrationList = $Kernel::OM->Get('Cache')->GetKeysForType(
        Type => 'Migration',
    );

    my $Running;
    foreach my $MigrationID ( @MigrationList ) {
        my $MigrationData = $Kernel::OM->Get('Cache')->Get(
            Type      => 'Migration',
            Key       => $MigrationID,
            UseRawKey => 1,
        );

        push @Result, $MigrationData;
    }

    return @Result;
}

sub MigrationStop {
    my ($Self, %Param) = @_;

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

    my $Migration = $Kernel::OM->Get('Cache')->Get(
        Type      => 'Migration',
        Key       => $Param{ID},
    );
    return if !IsHashRefWithData($Migration);

    $Migration->{Status} = $Migration->{Status} !~ /^(pending|finished)$/ ? Kernel::Language::Translatable('aborting') : Kernel::Language::Translatable('aborted');

    return $Kernel::OM->Get('Cache')->Set(
        Type  => 'Migration',
        Key   => $Param{ID},
        Value => $Migration,
    );
}

sub SetCacheOptions {
    my ( $Self, %Param ) = @_;

    # check needed params
    for my $Needed (qw(Source SourceID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # check needed stuff
    if ( !IsArrayRefWithData($Param{ObjectType}) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need ObjectType as ArrayRef!",
        );
        return;
    }

    $Self->{CacheOptions}->{$Param{Source}}->{$Param{SourceID}} = { map { $_ => { CacheInMemory => $Param{CacheInMemory}, CacheInBackend => $Param{CacheInBackend} } } @{$Param{ObjectType}} };
}

sub GetOIDMappingList {
    my ( $Self, %Param ) = @_;

    # check needed params
    for my $Needed (qw(Source SourceID ObjectType)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # get the items
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'SELECT id, source_object_id, object_id FROM migration WHERE source = ? AND source_id = ? AND object_type = ? ORDER BY id',
        Bind => [
            \$Param{Source}, \$Param{SourceID}, \$Param{ObjectType}
        ],
    );

    # fetch the result
    my $Result = $Kernel::OM->Get('DB')->FetchAllArrayRef(
        Columns => [ 'ID', 'SourceObjectID', 'ObjectID' ],
    );

    if ( !IsArrayRefWithData($Result) ) {
        return;
    }
    
    return $Result;
}

sub GetOIDMapping {
    my ( $Self, %Param ) = @_;

    # check needed params
    for my $Needed (qw(Source SourceID ObjectType)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    if ( !$Param{SourceObjectID} && !$Param{ObjectID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need SourceObjectID or ObjectID!"
        );
        return;
    }

    # check whether we have a preloaded mapping
    my $PreloadedOIDMappings = $Kernel::OM->Get('Cache')->Get(
        Type           => 'MigrationOIDMapping',
        Key            => 'PreloadedOIDMappings',
        CacheInMemory  => 1,
        CacheInBackend => 0,
    ); 
    if ( IsHashRefWithData($PreloadedOIDMappings) ) {
        if ( $Param{SourceObjectID} && $PreloadedOIDMappings->{$Param{ObjectType}}->{SourceObjectID}->{$Param{SourceObjectID}} ) {
            return $PreloadedOIDMappings->{$Param{ObjectType}}->{SourceObjectID}->{$Param{SourceObjectID}};
        }
        elsif ( $Param{ObjectID} && $PreloadedOIDMappings->{$Param{ObjectType}}->{ObjectID}->{$Param{ObjectID}} ) {
            return $PreloadedOIDMappings->{$Param{ObjectType}}->{ObjectID}->{$Param{ObjectID}};
        }
    }

    # check cache
    my $CacheType = 'MigrationOIDMapping_'.$Param{ObjectType};
    my $CacheKey  = $Param{Source} . '::' . $Param{SourceID} . '::' . $Param{ObjectType} . '::' . ($Param{SourceObjectID}||'') . '::' . ($Param{ObjectID}||'');
    if ( !$Param{NoCache} ) {
        my $Cache = $Kernel::OM->Get('Cache')->Get(
            Type => $CacheType,
            Key  => $CacheKey,
            %{$Self->{CacheOptions}->{$Param{Source}}->{$Param{SourceID}}->{$Param{ObjectType}} || {}},
        );
        return $Cache if $Cache;
    }

    # get the mapped ID
    if ( $Param{SourceObjectID} ) {
        return if !$Kernel::OM->Get('DB')->Prepare(
            SQL  => 'SELECT object_id FROM migration WHERE source = ? AND source_id = ? AND object_type = ? AND source_object_id = ?',
            Bind => [
                \$Param{Source}, \$Param{SourceID}, \$Param{ObjectType}, \$Param{SourceObjectID},
            ],
            Limit => 1,
        );
    }
    else {
        return if !$Kernel::OM->Get('DB')->Prepare(
            SQL  => 'SELECT source_object_id FROM migration WHERE source = ? AND source_id = ? AND object_type = ? AND object_id = ?',
            Bind => [
                \$Param{Source}, \$Param{SourceID}, \$Param{ObjectType}, \$Param{ObjectID},
            ],
            Limit => 1,
        );
    }

    my $ID;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        $ID = $Row[0];
    }

    if ( !$Param{NoCache} && $ID ) {
        # set cache
        $Kernel::OM->Get('Cache')->Set(
            Type  => $CacheType,
            TTL   => undef,
            Key   => $CacheKey,
            Value => $ID,
            %{$Self->{CacheOptions}->{$Param{Source}}->{$Param{SourceID}}->{$Param{ObjectType}} || {}},
        ); 
    }
    
    return $ID;
}

sub CreateOIDMapping {
    my ( $Self, %Param ) = @_;

    # check needed params
    for my $Needed (qw(Source SourceID ObjectType ObjectID SourceObjectID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my $AdditionalData;
    if ( IsHashRefWithData($Param{AdditionalData}) ) {
        $AdditionalData = $Kernel::OM->Get('JSON')->Encode(
            Data => $Param{AdditionalData}
        );
    }

    # save the mapping
    my $Result = $Kernel::OM->Get('DB')->Do(
        SQL  => 'INSERT INTO migration (source, source_id, object_type, object_id, source_object_id, additional_data) VALUES (?,?,?,?,?,?)',
        Bind => [
            \$Param{Source}, \$Param{SourceID}, \$Param{ObjectType}, \$Param{ObjectID}, \$Param{SourceObjectID}, \$AdditionalData
        ]
    );
    if ( !$Result ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to create object id mapping!"
        );
        return;
    }

    return 1;
}

sub ReplaceOIDMapping {
    my ( $Self, %Param ) = @_;

    # check needed params
    for my $Needed (qw(Source SourceID ObjectType ObjectID SourceObjectID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my $AdditionalData;
    if ( IsHashRefWithData($Param{AdditionalData}) ) {
        $AdditionalData = $Kernel::OM->Get('JSON')->Encode(
            Data => $Param{AdditionalData}
        );
    }

    # save the mapping
    my $Result = $Kernel::OM->Get('DB')->Do(
        SQL  => 'UPDATE migration SET object_id = ?, additional_data = ? WHERE source = ? AND source_id = ? AND object_type = ? AND source_object_id = ?',
        Bind => [
            \$Param{ObjectID}, \$AdditionalData, \$Param{Source}, \$Param{SourceID}, 
            \$Param{ObjectType}, \$Param{SourceObjectID},
        ]
    );
    if ( !$Result ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to update object id mapping!"
        );
        return;
    }

    return 1;
}

sub PreloadOIDMappings {
    my ( $Self, %Param ) = @_;

    # check needed params
    for my $Needed (qw(Source SourceID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # check needed stuff
    if ( !IsArrayRefWithData($Param{ObjectType}) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need ObjectType as ArrayRef!",
        );
        return;
    }

    my %PreloadedOIDMappings;
    foreach my $ObjectType ( @{$Param{ObjectType}} ) {
        my $Result = $Kernel::OM->Get('DB')->Prepare(
            SQL  => 'SELECT source_object_id, object_id FROM migration WHERE source = ? AND source_id = ? AND object_type = ?',
            Bind => [
                \$Param{Source}, \$Param{SourceID}, \$ObjectType,
            ],
        );
        my $Data = $Kernel::OM->Get('DB')->FetchAllArrayRef(
            Columns => [ 'SourceObjectID', 'ObjectID' ],
        );
        foreach my $Row ( @{$Data} ) {
            $PreloadedOIDMappings{$ObjectType}->{SourceObjectID}->{$Row->{SourceObjectID}} = $Row->{ObjectID};
            $PreloadedOIDMappings{$ObjectType}->{ObjectID}->{$Row->{ObjectID}} = $Row->{SourceObjectID};
        }
    }

    if ( %PreloadedOIDMappings ) {
        # set cache
        $Kernel::OM->Get('Cache')->Set(
            Type           => 'MigrationOIDMapping',
            TTL            => undef,
            Key            => 'PreloadedOIDMappings',
            Value          => \%PreloadedOIDMappings,
            CacheInMemory  => 1,
            CacheInBackend => 0,
        ); 
    }

    return 1;
}

sub Lookup {
    my ( $Self, %Param ) = @_;

    # check needed params
    for my $Needed (qw(Source SourceID Table PrimaryKey RelevantAttr Item)) {
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

    # check cache
    my $CacheType = 'MigrationLookup_'.$Param{Table};
    my $CacheKey  = join('::', values %Param);
    if ( !$Param{NoCache} ) {
        my $Cache = $Kernel::OM->Get('Cache')->Get(
            Type => $CacheType,
            Key  => $CacheKey,
            %{$Self->{CacheOptions}->{$Param{Source}}->{$Param{SourceID}}->{$Param{Table}} || {}},
        );
        return $Cache if $Cache;
    }

    my $DBObject = $Kernel::OM->Get('DB');

    my $Mapping = IsHashRefWithData($Param{Mapping}) ? $Param{Mapping}->{$Param{Table}} || {} : {};

    # prepare select statement
    my @Bind;
    my @Where;
    foreach my $Attr ( @{$Param{RelevantAttr}} ) {
        my $Value = $Param{Item}->{$Attr};
        next if !defined $Value;

        # map value if defined
        $Value = $Mapping->{$Value} if $Mapping->{$Value};

        # should we search case insensitive ?
        $Value = $Param{IgnoreCase} ? lc($Value) : $Value;

        push @Bind, \$Value;
        push @Where, $Param{IgnoreCase} ? "lower($Attr) = ?" : "$Attr = ?";
    }
    my $SQL = "SELECT $Param{PrimaryKey} FROM $Param{Table} WHERE " . join(' AND ', @Where);

    # lookup ID of existing object
    return if !$DBObject->Prepare(
        SQL   => $SQL,
        Bind  => \@Bind,
    );

    my @Result;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @Result, $Row[0];
    }

    return if @Result > 1;

    if ( $Result[0] && !$Param{NoOIDMapping} && ( $Param{Item}->{$Param{PrimaryKey}} || $Param{SourceObjectID} ) ) {
        # check if OID mapping exists and create one if not or replace it
        my $MappedID = $Self->GetOIDMapping(
            %Param,
            ObjectType     => $Param{Table},
            SourceObjectID => $Param{Item}->{$Param{PrimaryKey}} || $Param{SourceObjectID}
        );
        if ( !$MappedID ) {
            $Self->CreateOIDMapping(
                Source         => $Param{Source},
                SourceID       => $Param{SourceID},
                ObjectType     => $Param{Table},
                ObjectID       => $Result[0],
                SourceObjectID => $Param{Item}->{$Param{PrimaryKey}} || $Param{SourceObjectID}
            );
        }
        else {
            $Self->ReplaceOIDMapping(
                Source         => $Param{Source},
                SourceID       => $Param{SourceID},
                ObjectType     => $Param{Table},
                ObjectID       => $Result[0],
                SourceObjectID => $Param{Item}->{$Param{PrimaryKey}} || $Param{SourceObjectID}
            );
        }
    }

    if ( !$Param{NoCache} && $Result[0] ) {
        # set cache
        $Kernel::OM->Get('Cache')->Set(
            Type  => $CacheType,
            TTL   => undef,
            Key   => $CacheKey,
            Value => $Result[0],
            %{$Self->{CacheOptions}->{$Param{Source}}->{$Param{SourceID}}->{$Param{Table}} || {}},
        ); 
    }

    return $Result[0];
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
