# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Installation::Migration::KIX17::Link::Relation;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::Installation::Migration::KIX17::Common
);

our @ObjectDependencies = (
    'Config',
    'DB',
    'Log',
);

my %LinkObjectTypeMapping = (
    'Article'        => 'article',
    'Ticket'         => 'ticket',
    'ITSMConfigItem' => 'configitem',
    'FAQ'            => 'faq_item',
    'ConfigItem'     => 'configitem',       # new one
    'FAQArticle'     => 'faq_item',         # new one
);

=item Describe()

describe what is supported and what is required

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    return {
        Supports => [
            'link_relation'
        ],
        DependsOnType => [
            'ticket',
            'faq_item',
            'configitem'
        ],
        Depends => {
            'source_object_id' => 'link_object',
            'target_object_id' => 'link_object',
            'type_id'          => 'link_type',
            'create_by'        => 'users',
        }
    }
}

=item Run()

create a new item in the DB

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # only cache the following types in memory not redis
    $Self->SetCacheOptions(
        ObjectType     => ['link_relation'],
        CacheInMemory  => 1,
        CacheInBackend => 0,
    );

    # get source data
    my $SourceData = $Self->GetSourceData(Type => 'link_relation');

    # bail out if we don't have something to todo
    return if !IsArrayRefWithData($SourceData);

    my $LinkObjectData = $Self->GetSourceData(Type => 'link_object', NoProgress => 1);
    my %LinkObjects = map { $_->{id} => $_->{name} } @{$LinkObjectData};

    # get the list of types contained in the values to preload the OIDs
    my %TypesToPreload;
    foreach my $Item ( @{$SourceData} ) {
        next if !$LinkObjectTypeMapping{$LinkObjects{$Item->{source_object_id}}};
        $TypesToPreload{$LinkObjectTypeMapping{$LinkObjects{$Item->{source_object_id}}}} = 1;

        next if !$LinkObjectTypeMapping{$LinkObjects{$Item->{target_object_id}}};
        $TypesToPreload{$LinkObjectTypeMapping{$LinkObjects{$Item->{target_object_id}}}} = 1;
    }

    if ( %TypesToPreload ) {
        $Self->SetCacheOptions(
            ObjectType     => [ keys %TypesToPreload ],
            CacheInMemory  => 1,
            CacheInBackend => 0,
        );
        $Self->PreloadOIDMappings( ObjectType => [ keys %TypesToPreload ] );
    }

    $Self->InitProgress(Type => $Param{Type}, ItemCount => scalar(@{$SourceData}));

    return $Self->_RunParallel(
        $Self->{WorkerSubRef} || \&_Run,
        Items => $SourceData,
        %Param,
    );
}

sub _Run {
    my ( $Self, %Param ) = @_;
    my $Result;

    my $Item = $Param{Item};

    my $SourceObjectID = $Item->{'type_id::raw'}.'::'.$Item->{'source_object_id::raw'}.'::'.$Item->{source_key}.'::'.$Item->{'target_object_id::raw'}.'::'.$Item->{target_key};

    # check if this object is already mapped
    my $MappedID = $Self->GetOIDMapping(
        ObjectType     => 'link_relation',
        SourceObjectID => $SourceObjectID
    );
    if ( $MappedID ) {
        return 'Ignored';
    }

    # check if this item already exists (i.e. some initial data)
    my $ID = $Self->Lookup(
        Table        => 'link_relation',
        PrimaryKey   => 'id',
        Item         => $Item,
        RelevantAttr => [
            'type_id',
            'source_object_id',
            'source_key',
            'target_object_id',
            'target_key',
        ]
    );

    # insert row
    if ( !$ID ) {
        # map source object
        $Item->{source_key} = $Self->_MapObjectKey(
            ObjectID => $Item->{source_object_id},
            Key      => $Item->{source_key},
        );
        if ( !$Item->{source_key} ) {
            return 'Ignored';
        }

        # map target object
        $Item->{target_key} = $Self->_MapObjectKey(
            ObjectID => $Item->{target_object_id},
            Key      => $Item->{target_key},
        );
        if ( !$Item->{target_key} ) {
            return 'Ignored'
        }

        # map the type
        $Item->{type_id} = $Self->_MapLinkType(
            Item => $Item
        );

        $ID = $Self->Insert(
            Table          => 'link_relation',
            PrimaryKey     => 'id',
            Item           => $Item,
            AutoPrimaryKey => 1,
            SourceObjectID => $SourceObjectID,
        );
    }

    if ( $ID ) {
        $Result = 'OK';
    }
    else {
        $Result = 'Error';
    }

    return $Result;
}

sub _MapObjectKey {
    my ( $Self, %Param) = @_;

    # check needed params
    for my $Needed (qw(ObjectID Key)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    if ( !$Self->{LinkObjects} ) {
        # get object types
        my $Result = $Kernel::OM->Get('DB')->Prepare(
            SQL  => 'SELECT id, name FROM link_object',
        );
        if ( !$Result ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to load link_object relation!"
            );
            return;
        }
        # fetch the result
        while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
            $Self->{LinkObjects}->{$Row[0]} = $Row[1];
        }
    }

    # get the correct object type to the id
    my $ObjectType = $LinkObjectTypeMapping{$Self->{LinkObjects}->{$Param{ObjectID}}};
    # if we don't have a mapping we will ignore this
    return if !$ObjectType;

    my $ReferencedID = $Self->GetOIDMapping(
        ObjectType     => $ObjectType,
        SourceObjectID => $Param{Key}
    );
    if ( !$ReferencedID ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Can't find the referenced $Self->{LinkObjects}->{$Param{ObjectID}} object with ID $Param{Key}!"
        );
        return;
    }

    return $ReferencedID;
}

sub _MapLinkType {
    my ( $Self, %Param) = @_;

    # check needed params
    for my $Needed (qw(Item)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    if ( !$Self->{LinkObjects} ) {
        # get object types
        my $Result = $Kernel::OM->Get('DB')->Prepare(
            SQL  => 'SELECT id, name FROM link_object',
        );
        if ( !$Result ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to load link_object relation!"
            );
            return;
        }
        # fetch the result
        while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
            $Self->{LinkObjects}->{$Row[0]} = $Row[1];
        }
    }

    if ( !$Self->{LinkTypes} ) {
        # get object types
        my $Result = $Kernel::OM->Get('DB')->Prepare(
            SQL  => 'SELECT id, name FROM link_type',
        );
        if ( !$Result ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to load link_type relation!"
            );
            return;
        }
        # fetch the result
        while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
            $Self->{LinkTypes}->{$Row[0]} = $Row[1];
        }

        $Self->{LinkTypesReverse} = { reverse %{$Self->{LinkTypes}} };
    }

    # map to RelevantTo if type cannot be found
    return $Self->{LinkTypesReverse}->{RelevantTo} if !$Self->{LinkTypes}->{$Param{Item}->{type_id}};

    my $SourceObject = $Self->{LinkObjects}->{$Param{Item}->{source_object_id}};
    my $TargetObject = $Self->{LinkObjects}->{$Param{Item}->{target_object_id}};

    if ( !$Self->{PossibleLinkTypes} || !$Self->{PossibleLinkTypes}->{$SourceObject} || !$Self->{PossibleLinkTypes}->{$SourceObject}->{$TargetObject} ) {
        my %PossibleTypesList = $Kernel::OM->Get('LinkObject')->PossibleTypesList(
            Object1 => $SourceObject,
            Object2 => $TargetObject,
        );
        $Self->{PossibleLinkTypes}->{$SourceObject}->{$TargetObject} = \%PossibleTypesList;
    }

    my $Type = $Self->{LinkTypes}->{$Param{Item}->{type_id}};

    my $TypeID = $Param{Item}->{type_id};

    # if the current type is no longer possible for the combination of objects, fall back to RelevantTo
    if ( !IsHashRefWithData($Self->{PossibleLinkTypes}->{$SourceObject}->{$TargetObject}) || !$Self->{PossibleLinkTypes}->{$SourceObject}->{$TargetObject}->{$Type} ) {
        $TypeID = $Self->{LinkTypesReverse}->{RelevantTo}
    }

    return $TypeID;
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
