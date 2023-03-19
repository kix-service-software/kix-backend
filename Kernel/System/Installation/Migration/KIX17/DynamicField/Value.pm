# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
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
    'Article'         => 'article',
    'Ticket'          => 'ticket',
    'ITSMConfigItem'  => 'configitem',
    'FAQ'             => 'faq_item',
    'CustomerUser'    => 'contact',
    'CustomerCompany' => 'organisation',
);

my %FieldTypeReferenceMapping = (
    'TicketReference'         => 'ticket',
    'ITSMConfigItemReference' => 'configitem',
    'ContactReference'        => 'contact',
    'OrganisationReference'   => 'organisation',
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
    $Self->{DynamicFieldTypesSrc} = { map { $_->{id} => $_->{field_type} } @{$DynamicFieldData} };
    $Self->{DynamicFieldObjectTypes} = { map { $_->{id} => $_->{object_type} } @{$DynamicFieldData} };
    $Self->{DynamicFields} = $Kernel::OM->Get('DynamicField')->DynamicFieldListGet(
        Valid => 0
    );
    $Self->{DynamicFieldTypes} = { map { $_->{ID} => $_->{FieldType} } @{$Self->{DynamicFields}} };

    # get the list of types contained in the values to preload the OIDs
    my %TypesToPreload = map { $ObjectTypeReferenceMapping{$Self->{DynamicFieldObjectTypes}->{$_->{field_id}}} => 1 } @{$SourceData};
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

    # check if this object is already mapped
    my $MappedID = $Self->GetOIDMapping(
        ObjectType     => 'dynamic_field_value',
        SourceObjectID => $Item->{id}
    );

    if ( $MappedID ) {
        return 'Ignored';
    }

    my $ObjectID = $Item->{object_id} || $Item->{object_id_text};

    # map the object ID
    my $ObjectType = $ObjectTypeReferenceMapping{$Self->{DynamicFieldObjectTypes}->{$Item->{field_id}}};
    if ( !$ObjectType ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to migrate dynamic field type \"$Self->{DynamicFieldObjectTypes}->{$Item->{field_id}}\"!"
        );
        return "Ignored";
    }
    my $ReferencedID;
    if ( $Self->{DynamicFieldObjectTypes}->{$Item->{field_id}} eq 'CustomerUser' ) {
        # some special handling here
        my $ContactID = $Kernel::OM->Get('Contact')->ContactLookup(
            UserLogin => $ObjectID,
            Silent    => 1,
        );

        if ( !$ContactID ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Can't find the referenced Contact object with user login \"$ObjectID\"!"
            );
            return 'Error';
        }

        $ReferencedID = $Self->GetOIDMapping(
            ObjectType => 'Contact',
            ObjectID   => $ContactID,
        ) || $ContactID;
    }
    else {
        $ReferencedID = $Self->GetOIDMapping(
            ObjectType     => $ObjectType,
            SourceObjectID => $ObjectID,
        );
    }

    if ( !$ReferencedID ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Can't find the referenced $Self->{DynamicFieldObjectTypes}->{$Item->{field_id}} ($ObjectType) object with ID $ObjectID!"
        );
        return 'Error';
    }
    $Item->{object_id} = $ReferencedID;

    my $FieldIDSrc = $Item->{field_id};

    # map the field_id
    $Item->{field_id} = $Self->GetOIDMapping(
        ObjectType     => 'dynamic_field',
        SourceObjectID => $Item->{field_id}
    );

    # # check if this item already exists (i.e. some initial data)
    # my $ID = $Self->Lookup(
    #     Table        => 'dynamic_field_value',
    #     PrimaryKey   => 'id',
    #     Item         => $Item,
    #     RelevantAttr => [
    #         'field_id',
    #         'object_id',
    #     ]
    # );

    # special handling for value if needed
    if ( $Self->{DynamicFieldTypesSrc}->{$FieldIDSrc} eq 'Checkbox' ) {
        $Item->{value_text} = $Item->{value_int};
        $Item->{value_int} = undef;
    }
    if ( $Self->{DynamicFieldTypes}->{$Item->{field_id}} eq 'ContactReference' ) {
        $Item->{value_text} = $Kernel::OM->Get('Contact')->ContactLookup(
            UserLogin => $Item->{value_text},
        );
    }
    elsif ( $Self->{DynamicFieldTypes}->{$Item->{field_id}} eq 'OrganisationReference' ) {
        $Item->{value_text} = $Kernel::OM->Get('Organisation')->OrganisationLookup(
            Number => $Item->{value_text},
        );
    }
    elsif ( $FieldTypeReferenceMapping{$Self->{DynamicFieldTypes}->{$Item->{field_id}}} ) {
        # map the value to the new object
        ATTR:
        foreach my $Attr ( qw(value_text value_int) ) {
            next ATTR if !$Item->{$Attr};
            $Item->{$Attr} = $Self->GetOIDMapping(
                ObjectType     => $FieldTypeReferenceMapping{$Self->{DynamicFieldTypes}->{$Item->{field_id}}},
                SourceObjectID => $Item->{$Attr}
            );
        }
    }

    my $ID = $Self->Insert(
        Table          => 'dynamic_field_value',
        PrimaryKey     => 'id',
        Item           => $Item,
        AutoPrimaryKey => 1,
    );

    if ( $ID ) {
        $Result = 'OK';
    }
    else {
        $Result = 'Error';
    }

    return $Result;
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
