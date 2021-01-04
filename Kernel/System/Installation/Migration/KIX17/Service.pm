# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Installation::Migration::KIX17::Service;

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
            'service'
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
    my $SourceData = $Self->GetSourceData(Type => 'service');

    # bail out if we don't have something to todo
    return if !IsArrayRefWithData($SourceData);

    # lookup ID of class "Service"
    my $ClassID = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
        Class => 'ITSM::ConfigItem::Class',
        Name  => 'Service',
    );

    $Self->InitProgress(Type => $Param{Type}, ItemCount => scalar(@{$SourceData}));

    foreach my $Item ( @{$SourceData} ) {

        # check if this object is already mapped
        my $MappedID = $Self->GetOIDMapping(
            ObjectType     => 'service',
            SourceObjectID => $Item->{id}
        );
        if ( $MappedID ) {
            $Self->UpdateProgress($Param{Type}, 'Ignored');
            next;
        }

        # check if this item already exists (i.e. some initial data)
        my @ConfigItems = $Kernel::OM->Get('ConfigItem')->ConfigItemSearch(
            Name         => $Item->{name},
            ClassIDs     => [ $ClassID ],
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
