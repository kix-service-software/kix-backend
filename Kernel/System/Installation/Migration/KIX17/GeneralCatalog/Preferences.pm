# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Installation::Migration::KIX17::GeneralCatalog::Preferences;

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
            'general_catalog_preferences'
        ],
        Depends => {
            'general_catalog_id' => 'general_catalog',
            'created_by'         => 'users',
            'changed_by'         => 'users',
        }
    }
}

=item Run()

create a new item in the DB

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # get source data
    my $SourceData = $Self->GetSourceData(Type => 'general_catalog_preferences');

    # bail out if we don't have something to todo
    return if !IsArrayRefWithData($SourceData);

    $Self->InitProgress(Type => $Param{Type}, ItemCount => scalar(@{$SourceData}));

    foreach my $Item ( @{$SourceData} ) {

        # check if this item already exists (i.e. some initial data)
        my $ID = $Self->Lookup(
            Table        => 'general_catalog_preferences',
            PrimaryKey   => 'id',
            Item         => $Item,
            RelevantAttr => [
                'general_catalog_id',
                'pref_key'
            ]
        );

        # insert row
        if ( !$ID ) {
            $ID = $Self->Insert(
                Table          => 'general_catalog_preferences',
                PrimaryKey     => 'id',
                Item           => $Item,
                AutoPrimaryKey => 1,
                NoOIDMapping   => 1,
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
