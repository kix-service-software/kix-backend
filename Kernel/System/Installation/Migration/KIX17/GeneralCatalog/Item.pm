# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Installation::Migration::KIX17::GeneralCatalog::Item;

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
            'general_catalog'
        ],
        Depends => {
            'create_by' => 'users',
            'change_by' => 'users',
        }
    }
}

=item Run()

create a new item in the DB

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # get source data
    my $SourceData = $Self->GetSourceData(Type => 'general_catalog', OrderBy => 'id');

    # bail out if we don't have something to todo
    return if !IsArrayRefWithData($SourceData);

    $Self->InitProgress(Type => $Param{Type}, ItemCount => scalar(@{$SourceData}));

    foreach my $Item ( @{$SourceData} ) {

        # check if this object is already mapped
        my $MappedID = $Self->GetOIDMapping(
            ObjectType     => 'general_catalog',
            SourceObjectID => $Item->{id}
        );
        if ( $MappedID ) {
            $Self->UpdateProgress($Param{Type}, 'Ignored');
            next;
        }

        # check if this item already exists (i.e. some initial data)
        LOOKUP:
        my $ID = $Self->Lookup(
            Table        => 'general_catalog',
            PrimaryKey   => 'id',
            Item         => $Item,
            RelevantAttr => [
                'general_catalog_class',
                'name'
            ],
            NoOIDMapping => 1,
        );

        # some special handling for CI classes if one already exists
        if ( $ID && $Item->{general_catalog_class} eq 'ITSM::ConfigItem::Class' ) {
            $Item->{name} = 'Migration-'.$Item->{name};
            # clear lookup cache for this object type
            $Kernel::OM->Get('Cache')->CleanUp(
                Type => 'MigrationLookup_general_catalog'
            );
            # do the lookup again
            goto LOOKUP;
        }

        # insert row
        if ( !$ID ) {
            $ID = $Self->Insert(
                Table          => 'general_catalog',
                PrimaryKey     => 'id',
                Item           => $Item,
                AutoPrimaryKey => 1,
                NoOIDMapping   => 1,
            );
        }

        if ( $ID ) {
            # create OID mapping
            $Self->CreateOIDMapping(
                ObjectType     => 'general_catalog',
                ObjectID       => $ID,
                SourceObjectID => $Item->{id},
            );

            $Self->UpdateProgress($Param{Type}, 'OK');
        }
        else {
            $Self->UpdateProgress($Param{Type}, 'Error');
        }
    }

    # clear GC cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Kernel::OM->Get('GeneralCatalog')->{CacheType},
    );

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
