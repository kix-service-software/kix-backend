# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Installation::Migration::KIX17::Asset::Item;

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

=item Describe()

describe what is supported and what is required

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    return {
        Supports => [
            'configitem'
        ],
        DependsOnType => [
            'configitem_definition',
        ],
        Depends => {
            'change_by'         => 'users',
            'create_by'         => 'users',
            'class_id'          => 'general_catalog',
            'cur_depl_state_id' => 'general_catalog',
            'cur_inci_state_id' => 'general_catalog',
        },
    }
}

=item Run()

create a new item in the DB

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # only cache the following types in memory not redis
    $Self->SetCacheOptions(
        ObjectType     => ['configitem', 'configitem_history'],
        CacheInMemory  => 1,
        CacheInBackend => 0,
    );

    # get source data
    my $SourceData = $Self->GetSourceData(Type => 'configitem', OrderBy => 'id');

    # bail out if we don't have something to todo
    return if !IsArrayRefWithData($SourceData);

    $Self->InitProgress(Type => $Param{Type}, ItemCount => scalar(@{$SourceData}));

    my $Result = $Self->_RunParallel(
        $Self->{WorkerSubRef} || \&_Run,
        Items => $SourceData,
        %Param,
    );

    # we need to cleanup the relevant caches to update the counters correctly
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Kernel::OM->Get('ITSMConfigItem')->{CacheType},
    );
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Kernel::OM->Get('GeneralCatalog')->{CacheType},
    );

    my $Success = $Kernel::OM->Get('ITSMConfigItem')->UpdateCounters(
        UserID => 1,
    );

    if ( !$Success ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to update counters\"!"
        );
    }

    return $Result;
}

sub _Run {
    my ( $Self, %Param ) = @_;
    my $Result;

    my $Item = $Param{Item};

    # check if this object is already mapped
    my $MappedID = $Self->GetOIDMapping(
        ObjectType     => 'configitem',
        SourceObjectID => $Item->{id},
    );
    if ( $MappedID ) {
        return 'Ignored';
    }

    # check if this item already exists (i.e. some initial data)
    my $ID = $Self->Lookup(
        Table        => 'configitem',
        PrimaryKey   => 'id',
        Item         => $Item,
        RelevantAttr => [
            'configitem_number',
            'class_id',
        ],
    );

    # insert row
    if ( !$ID ) {
        # remove reference to last version to prevent ring dependency
        delete $Item->{last_version_id};

        $ID = $Self->Insert(
            Table          => 'configitem',
            PrimaryKey     => 'id',
            Item           => $Item,
            AutoPrimaryKey => 1,
            AdditionalData => {
                'class_id::raw' => $Item->{'class_id::raw'},
                'class_id'      => $Item->{'class_id'},
            },
        );
    }

    if ( $ID ) {
        $Result = 'OK';

        $Self->_MigrateHistory(
            AssetID       => $ID,
            SourceAssetID => $Item->{id},
        );
    }
    else {
        $Result = 'Error';
    }

    return $Result;
}

sub _MigrateHistory {
    my ( $Self, %Param ) = @_;
    my %Result;

    # check needed params
    for my $Needed (qw(AssetID SourceAssetID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # get source data
    my $SourceData = $Self->GetSourceData(
        Type => 'configitem_history',
        Where => "configitem_id = $Param{SourceAssetID}",
        OrderBy => 'id',
        References => {
            'configitem_id' => 'configitem',
            'create_by'     => 'users',
        },
        NoProgress => 1
    );

    # bail out if we don't have something to todo
    return %Result if !IsArrayRefWithData($SourceData);

    foreach my $Item ( @{$SourceData} ) {

        # check if this object is already mapped
        my $MappedID = $Self->GetOIDMapping(
            ObjectType     => 'configitem_history',
            SourceObjectID => $Item->{id}
        );
        next if $MappedID;

        # set new AssetID
        $Item->{configitem_id} = $Param{AssetID};

        # check if this item already exists (i.e. some initial data)
        my $ID = $Self->Lookup(
            Table        => 'configitem_history',
            PrimaryKey   => 'id',
            Item         => $Item,
            RelevantAttr => [
                'type_id',
                'configitem_id',
                'create_time'
            ]
        );

        # insert row
        if ( !$ID ) {
            $ID = $Self->Insert(
                Table          => 'configitem_history',
                PrimaryKey     => 'id',
                Item           => $Item,
                AutoPrimaryKey => 1,
            );
        }

        if ( $ID ) {
            $Result{OK}++;
        }
        else {
            $Result{Error}++;
        }
    }

    return %Result;
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
