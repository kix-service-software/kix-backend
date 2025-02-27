# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Installation::Migration::KIX17::FAQ::Category;

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
            'faq_category'
        ],
        Depends => {
            'created_by' => 'users',
            'changed_by' => 'users',
        }
    }
}

=item Run()

create a new item in the DB

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # get source data
    my $SourceData = $Self->GetSourceData(Type => 'faq_category', OrderBy => 'id');

    # bail out if we don't have something to todo
    return if !IsArrayRefWithData($SourceData);

    my %CategoryListSource = map { $_->{id} => $_ } @{$SourceData};

    # get category list
    my %CategoryList = reverse %{
        $Kernel::OM->Get('FAQ')->CategoryTreeList(
            UserID => 1,
        )
    };

    $Self->InitProgress(Type => $Param{Type}, ItemCount => scalar(@{$SourceData}));

    my %CategoryReferenceMapping;

    foreach my $Item ( @{$SourceData} ) {

        # check if this object is already mapped
        my $MappedID = $Self->GetOIDMapping(
            ObjectType     => 'faq_category',
            SourceObjectID => $Item->{id}
        );
        if ( $MappedID ) {
            $Self->UpdateProgress($Param{Type}, 'Ignored');
            next;
        }

        # check if this item already exists (i.e. some initial data)
        # we can't use our Lookup method here, since we need to look at the (virtual) fullname
        my @NamePartsSource;
        my $TmpItem = $Item;
        while ( $TmpItem) {

            push @NamePartsSource, $TmpItem->{name};
            $TmpItem = $CategoryListSource{$TmpItem->{parent_id}};
        }
        my $SourceName = join('::', reverse @NamePartsSource);

        my $ID = $CategoryList{$SourceName};

        # insert row
        if ( !$ID ) {
            my $ParentID = $Item->{parent_id};

            $ID = $Self->Insert(
                Table          => 'faq_category',
                PrimaryKey     => 'id',
                Item           => $Item,
                AutoPrimaryKey => 1,
            );

            # add the new category to the lookup list
            $CategoryList{$SourceName} = $ID;

            # build the mapping for later
            $CategoryReferenceMapping{$ID} = {
                parent_id => $ParentID,
            };
        }
        else {
            # create OID mapping
            $Self->CreateOIDMapping(
                ObjectType     => 'faq_category',
                ObjectID       => $ID,
                SourceObjectID => $Item->{id},
            );
        }

        if ( $ID ) {
            $Self->UpdateProgress($Param{Type}, 'OK');
        }
        else {
            $Self->UpdateProgress($Param{Type}, 'Error');
        }
    }

    if ( %CategoryReferenceMapping ) {
        foreach my $ID ( sort keys %CategoryReferenceMapping ) {
            my %Item = (
                id => $ID,
            );
            foreach my $RefAttr ( sort keys %{$CategoryReferenceMapping{$ID}} ) {
                next if !$CategoryReferenceMapping{$ID}->{$RefAttr};

                my $MappedID = $Self->GetOIDMapping(
                    ObjectType     => 'faq_category',
                    SourceObjectID => $CategoryReferenceMapping{$ID}->{$RefAttr},
                );
                $Item{$RefAttr} = $MappedID;
            }

            next if keys %Item == 1;

            # update the references
            $Self->Update(
                Table      => 'faq_category',
                PrimaryKey => 'id',
                Item       => \%Item,
            );
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
