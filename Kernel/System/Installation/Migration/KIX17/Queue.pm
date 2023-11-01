# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Installation::Migration::KIX17::Queue;

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
            'queue'
        ],
        Depends => {
            'system_address_id' => 'system_address',
            'create_by'         => 'users',
            'change_by'         => 'users',
        }
    }
}

=item Run()

create a new item in the DB

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # get source data
    my $SourceData = $Self->GetSourceData(Type => 'queue');

    # bail out if we don't have something to todo
    return if !IsArrayRefWithData($SourceData);

    # get signatures
    my $SignatureData = $Self->GetSourceData(Type => 'signature', NoProgress => 1);

    # map signature
    my %Signatures = map { $_->{id} => $_->{text} } @{$SignatureData};

    $Self->InitProgress(Type => $Param{Type}, ItemCount => scalar(@{$SourceData}));

    foreach my $Item ( @{$SourceData} ) {

        # check if this object is already mapped
        my $MappedID = $Self->GetOIDMapping(
            ObjectType     => 'queue',
            SourceObjectID => $Item->{id}
        );
        if ( $MappedID ) {
            $Self->UpdateProgress($Param{Type}, 'Ignored');
            next;
        }

        # check if this item already exists (i.e. some initial data)
        my $ID = $Self->Lookup(
            Table        => 'queue',
            PrimaryKey   => 'id',
            Item         => $Item,
            RelevantAttr => [
                'name'
            ]
        );

        # insert row
        if ( !$ID ) {
            $Item->{signature} = $Signatures{$Item->{signature_id}};
            $Item->{signature} =~ s/<OTRS_/<KIX_/g;

            $ID = $Self->Insert(
                Table          => 'queue',
                PrimaryKey     => 'id',
                Item           => $Item,
                AutoPrimaryKey => 1,
            );
        }

        if ( $ID ) {
            $Self->UpdateProgress($Param{Type}, 'OK');
        }
        else {
            $Self->UpdateProgress($Param{Type}, 'Error');
        }
    }

    # delete queue cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Kernel::OM->Get('Queue')->{CacheType},
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
