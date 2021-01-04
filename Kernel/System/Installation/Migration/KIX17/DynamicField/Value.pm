# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Installation::Migration::KIX17::DynamicField::Value;

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

my %ObjectTypeReferenceMapping = (
    'Article'        => 'article',
    'Ticket'         => 'ticket',
    'ITSMConfigItem' => 'configitem',
    'FAQ'            => 'faq_item',
);

my %FieldTypeReferenceMapping = (
    'TicketReference'         => 'ticket',
    'ITSMConfigItemReference' => 'configitem',
);

=item Describe()

describe what is supported and what is required 

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    return {
        Supports => [
            'dynamic_field_value'
        ],
        DependsOnType => [
            'dynamic_field',
            'ticket',
            'faq_item',
            'configitem'
        ],
    }
}

=item Run()

create a new item in the DB

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # only cache the following types in memory not redis 
    $Self->SetCacheOptions(
        ObjectType     => ['dynamic_field_value'],
        CacheInMemory  => 1,
        CacheInBackend => 0,
    );

    # get source data
    my $SourceData = $Self->GetSourceData(Type => 'dynamic_field_value', OrderBy => 'id');

    # bail out if we don't have something to todo
    return if !IsArrayRefWithData($SourceData);

    # get source data
    my $DynamicFieldData = $Self->GetSourceData(Type => 'dynamic_field', NoProgress => 1);

    # map DF types
    my %DynamicFieldObjectTypes = map { $_->{id} => $_->{object_type} } @{$DynamicFieldData};
    my %DynamicFieldTypes       = map { $_->{id} => $_->{field_type} } @{$DynamicFieldData};

    # get the list of types contained in the values to preload the OIDs
    my %TypesToPreload = map { $ObjectTypeReferenceMapping{$DynamicFieldObjectTypes{$_->{field_id}}} => 1 } @{$SourceData};
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
        sub {
            my ( $Self, %Param ) = @_;
            my $Result;

            my $Item = $Param{Item};

            # check if this object is already mapped
            my $MappedID = $Self->GetOIDMapping(
                ObjectType     => 'dynamic_field_value',
                SourceObjectID => $Item->{id}
            );
            if ( $MappedID ) {
                return 'Ignored';
            }

            # check if this item already exists (i.e. some initial data)
            my $ID = $Self->Lookup(
                Table        => 'dynamic_field_value',
                PrimaryKey   => 'id',
                Item         => $Item,
                RelevantAttr => [
                    'field_id',
                    'object_id',
                ]
            );

            # insert row
            if ( !$ID ) {
                # map the object ID
                my $ObjectType = $ObjectTypeReferenceMapping{$DynamicFieldObjectTypes{$Item->{field_id}}};
                if ( !$ObjectType ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => "Unable to migrate dynamic field type \"$DynamicFieldObjectTypes{$Item->{field_id}}\"!"
                    );
                    return "Ignored";
                }
                my $ReferencedID = $Self->GetOIDMapping(
                    ObjectType     => $ObjectType,
                    SourceObjectID => $Item->{object_id}
                );
                if ( !$ReferencedID ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => "Can't find the referenced $DynamicFieldObjectTypes{$Item->{field_id}} object with ID $Item->{object_id}!"
                    );
                    return 'Error';
                }
                $Item->{object_id} = $ReferencedID;

                # map the field_id
                $Item->{field_id} = $Self->GetOIDMapping(
                    ObjectType     => 'dynamic_field',
                    SourceObjectID => $Item->{field_id}
                );

                # special handling for value if needed
                if ( $DynamicFieldTypes{$Item->{field_id}} eq 'Checkbox' ) {
                    $Item->{value_text} = $Item->{value_int};
                    $Item->{value_int} = undef;
                }
                elsif ( $FieldTypeReferenceMapping{$DynamicFieldTypes{$Item->{field_id}}} ) {
                    # map the value to the new object
                    $Item->{value_text} = $Self->GetOIDMapping(
                        ObjectType     => $FieldTypeReferenceMapping{$DynamicFieldTypes{$Item->{field_id}}},
                        SourceObjectID => $Item->{value_text}
                    );
                }

                $ID = $Self->Insert(
                    Table          => 'dynamic_field_value',
                    PrimaryKey     => 'id',
                    Item           => $Item,
                    AutoPrimaryKey => 1,
                );
            }

            if ( $ID ) {
                $Result = 'OK';
            }
            else {
                $Result = 'Error';
            }

            return $Result;
        },
        Items => $SourceData, 
        %Param,
    );
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
