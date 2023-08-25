# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ImportExport::ObjectBackend::Contact;

use strict;
use warnings;

our @ObjectDependencies = qw(
    ImportExport
    Contact
    Log'
    Config
);

use Kernel::System::VariableCheck qw{:all};

=head1 NAME

Kernel::System::ImportExport::ObjectBackend::Contact - import/export backend for Contact

=head1 SYNOPSIS

All functions to import and export Contact entries

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $BackendObject = $Kernel::OM->Get('ImportExport::ObjectBackend::Contact');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item MappingObjectAttributesGet()

get the mapping attributes of an object as array/hash reference

    my $Attributes = $ObjectBackend->MappingObjectAttributesGet(
        TemplateID => 123,
        UserID     => 1,
    );

=cut

sub MappingObjectAttributesGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get object data
    my $ObjectData = $Kernel::OM->Get('ImportExport')->ObjectDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
        Silent     => $Param{Silent}
    );

    return [] if !$ObjectData;
    return [] if ref $ObjectData ne 'HASH';
    return [] if !defined $ObjectData->{DynamicField};

    my @ElementList = (
        {
            Key   => 'ID',
            Value => 'ID',
        },
        {
            Key   => 'UserID',
            Value => 'UserID',
        },
        {
            Key   => 'OrganisationID',
            Value => 'OrganisationID',
        },
        {
            Key   => 'PrimaryOrganisationID',
            Value => 'PrimaryOrganisationID',
        },
        {
            Key   => 'Firstname',
            Value => 'Firstname',
        },
        {
            Key   => 'Lastname',
            Value => 'Lastname',
        },
        {
            Key   => 'Email',
            Value => 'Email',
        },
        {
            Key   => 'Title',
            Value => 'Title',
        },
        {
            Key   => 'Phone',
            Value => 'Phone',
        },
        {
            Key   => 'Fax',
            Value => 'Fax',
        },
        {
            Key   => 'Mobile',
            Value => 'Mobile',
        },
        {
            Key   => 'Street',
            Value => 'Street',
        },
        {
            Key   => 'Zip',
            Value => 'Zip',
        },
        {
            Key   => 'City',
            Value => 'City',
        },
        {
            Key   => 'Country',
            Value => 'Country',
        },
        {
            Key   => 'Comment',
            Value => 'Comment',
        },
        {
            Key   => 'ValidID',
            Value => 'ValidID',
        },
        {
            Key   => 'AssignedUserID',
            Value => 'AssignedUserID',
        },
    );

    if ( $ObjectData->{DynamicField} ) {
        my $DynamicFields = $Kernel::OM->Get('DynamicField')->DynamicFieldListGet(
            ObjectType => 'Contact',
            Valid      => 0
        );

        if ( $DynamicFields ) {
            for my $Config ( @{$DynamicFields} ) {
                push(
                    @ElementList,
                    {
                        Key   => 'DynamicField_'.$Config->{Name},
                        Value => $Config->{Label} . 'DF'
                    }
                );
            }
        }
    }

    my $Attributes = [
        {
            Key   => 'Key',
            Name  => 'Key',
            Input => {
                Type         => 'Selection',
                Data         => \@ElementList,
                Required     => 1,
                Translation  => 0,
                PossibleNone => 1,
            },
        },
        {
            Key   => 'Identifier',
            Name  => 'Identifier',
            Input => {
                Type => 'Checkbox',
            },
        },
    ];

    return $Attributes;
}

=item SearchAttributesGet()

get the search object attributes of an object as array/hash reference

    my $AttributeList = $ObjectBackend->SearchAttributesGet(
        TemplateID => 123,
        UserID     => 1,
    );

=cut

sub SearchAttributesGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get object data
    my $ObjectData = $Kernel::OM->Get('ImportExport')->ObjectDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    return;
}

=item ExportDataGet()

get export data as 2D-array-hash reference

    my $ExportData = $ObjectBackend->ExportDataGet(
        TemplateID => 123,
        UserID     => 1,
    );

=cut

sub ExportDataGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            return if $Param{Silent};

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get object data
    my $ObjectData = $Kernel::OM->Get('ImportExport')->ObjectDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # check object data
    if (
        !$ObjectData
        || ref $ObjectData ne 'HASH'
        || !defined $ObjectData->{DynamicField}
    ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No object data found for the template id $Param{TemplateID}",
        );
        return;
    }

    # get the mapping list
    my $MappingList = $Kernel::OM->Get('ImportExport')->MappingList(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
        Silent     => $Param{Silent}
    );

    # check the mapping list
    if (
        !$MappingList
        || ref $MappingList ne 'ARRAY'
        || !@{$MappingList}
    ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No valid mapping list found for the template id $Param{TemplateID}",
        );
        return;
    }

    # create the mapping object list
    my @MappingObjectList;
    for my $MappingID ( @{$MappingList} ) {

        # get mapping object data
        my $MappingObjectData = $Kernel::OM->Get('ImportExport')->MappingObjectDataGet(
            MappingID => $MappingID,
            UserID    => $Param{UserID},
        );

        # check mapping object data
        if (
            !$MappingObjectData
            || ref $MappingObjectData ne 'HASH'
        ) {
            return if $Param{Silent};

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No valid mapping list found for the template id $Param{TemplateID}",
            );
            return;
        }

        push( @MappingObjectList, $MappingObjectData );
    }


    # get search data
    my $SearchData = $Kernel::OM->Get('ImportExport')->SearchDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
        Silent     => $Param{Silent}
    );

    return if !$SearchData || ref $SearchData ne 'HASH';

    my %SearchParams;
    foreach my $SearchItem ( keys %{$SearchData} ) {
        my $Value = $SearchData->{$SearchItem};
        if ( $SearchItem =~ /^(?:Login|UserLogin)$/smg ) {
            $SearchParams{$SearchItem} = $Value;
            next;
        }

        if ( $SearchItem eq 'OrganisationIDs' ) {
            if ( IsArrayRefWithData($Value) ) {
                $SearchParams{$SearchItem} = $Value;
            }
            else {
                @{$SearchParams{$SearchItem}} = split(/(?:\s+|)[,;](?:\s+|)/sm, $Value);
            }
            next;
        }

        if ($SearchItem =~ /^(?:User|)ID$/smg) {
            $SearchParams{ID} = $Value;
            next;
        }

        if ($SearchItem =~ /^(?:Assigned|Valid)ID$/smg) {
            $SearchParams{$SearchItem} = $Value;
            next;
        }

        if ( $SearchItem =~ /^(?:Title|(?:First|Last)name)$/smg ) {
            $SearchParams{$SearchItem} = $Value;
            next;
        }

        if ( $SearchItem =~ /^(?:City|Country|Fax|Mobil|Phone|Street|Zip)$/smg ) {
            $SearchParams{$SearchItem} = $Value;
            next;
        }

        if ( $SearchItem eq 'Email' ) {
            $SearchParams{Email} = $Value;
            next;
        }

        if ( $SearchItem eq 'PrimaryOrganisationID' ) {
            $SearchParams{OrganisationID} = $Value;
            next;
        }

        $SearchParams{Search} = $Value;
    }

    my %SearchResult = $Kernel::OM->Get('Contact')->ContactSearch(
        %SearchParams,
        Valid => 0,
        Limit => 0,
    );
    my @SearchTypeResult = %SearchResult ? @{[keys %SearchResult]} : ();

    my @ExportData;
    CONTACT:
    for my $ContactID ( @SearchTypeResult ) {

        # get last version
        my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
            ID => $ContactID,
        );

        # add data to the export data array
        my @Item;
        MAPPINGOBJECT:
        for my $MappingObject (@MappingObjectList) {

            # extract key
            my $Key = $MappingObject->{Key};

            # handle empty key
            if ( !$Key ) {
                push @Item, q{};
                next MAPPINGOBJECT;
            }

            # handle config item number
            if ( $Key eq 'OrganisationIDs' ) {
                push @Item, join(q{,}, $Contact{OrganisationIDs});
                next MAPPINGOBJECT;
            }

            # handle all data elements
            push @Item, $Contact{$Key};
        }

        push @ExportData, \@Item;
    }

    return \@ExportData;
}

=item ImportDataSave()

import one row of the import data

    my $ConfigItemID = $ObjectBackend->ImportDataSave(
        TemplateID    => 123,
        ImportDataRow => $ArrayRef,
        UserID        => 1,
    );

=cut

sub ImportDataSave {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(TemplateID ImportDataRow Counter UserID)) {
        if ( !$Param{$Argument} ) {
            return if $Param{Silent};
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # check import data row
    if ( ref $Param{ImportDataRow} ne 'ARRAY' ) {
        return if $Param{Silent};
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message =>
                "Can't import entity $Param{Counter}: "
                . "ImportDataRow must be an array reference",
        );
        return;
    }

    # get object data
    my $ObjectData = $Kernel::OM->Get('ImportExport')->ObjectDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
        Silent     => $Param{Silent}
    );

    # check object data
    if (
        !$ObjectData
        || ref $ObjectData ne 'HASH'
    ) {
        return if $Param{Silent};
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message =>
                "Can't import entity $Param{Counter}: "
                . "No object data found for the template id '$Param{TemplateID}'",
        );
        return;
    }

    # just for convenience
    my $EmptyFieldsLeaveTheOldValues = $ObjectData->{EmptyFieldsLeaveTheOldValues};

    # get the mapping list
    my $MappingList = $Kernel::OM->Get('ImportExport')->MappingList(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
        Silent     => $Param{Silent}
    );

    # check the mapping list
    if (
        !$MappingList
        || ref $MappingList ne 'ARRAY'
        || !@{$MappingList}
    ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message =>
                "Can't import entity $Param{Counter}: "
                . "No valid mapping list found for the template id '$Param{TemplateID}'",
        );
        return;
    }

    # create the mapping object list
    my @MappingObjectList;
    for my $MappingID ( @{$MappingList} ) {

        # get mapping object data
        my $MappingObjectData = $Kernel::OM->Get('ImportExport')->MappingObjectDataGet(
            MappingID => $MappingID,
            UserID    => $Param{UserID},
            Silent    => $Param{Silent}
        );

        # check mapping object data
        if (
            !$MappingObjectData
            || ref $MappingObjectData ne 'HASH'
        ) {
            return if $Param{Silent};

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message =>
                    "Can't import entity $Param{Counter}: "
                    . "No mapping object data found for the mapping id '$MappingID'",
            );
            return;
        }

        push @MappingObjectList, $MappingObjectData;
    }

    # check and remember the Identifiers
    # the Identifiers identify the config item that should be updated
    my %Identifier;
    my $RowIndex = 0;
    MAPPINGOBJECTDATA:
    for my $MappingObjectData (@MappingObjectList) {

        next MAPPINGOBJECTDATA if !$MappingObjectData->{Identifier};

        # check if identifier already exists
        if ( $Identifier{ $MappingObjectData->{Key} } ) {
            return if $Param{Silent};

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message =>
                    "Can't import entity $Param{Counter}: "
                    . "'$MappingObjectData->{Key}' has been used multiple times as an identifier",
            );
            return;
        }

        # set identifier value
        $Identifier{ $MappingObjectData->{Key} } = $Param{ImportDataRow}->[$RowIndex];

        next MAPPINGOBJECTDATA if $MappingObjectData->{Key} && $Param{ImportDataRow}->[$RowIndex];

        return if $Param{Silent};
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message =>
                "Can't import entity $Param{Counter}: "
                . "Identifier field is empty",
        );

        return;
    }
    continue {
        $RowIndex++;
    }

    # try to get ids, when there are identifiers
    my @ContactIDs;
    if (%Identifier) {

        my %SearchParams;
        foreach my $SearchItem ( keys %Identifier ) {
            my $Value = $Identifier{$SearchItem};
            if ( $SearchItem =~ /^(?:Login|UserLogin)$/smg ) {
                $SearchParams{$SearchItem} = $Value;
                next;
            }

            if ( $SearchItem eq 'OrganisationIDs' ) {
                if ( IsArrayRefWithData($Value) ) {
                    $SearchParams{$SearchItem} = $Value;
                }
                else {
                    @{$SearchParams{$SearchItem}} = split(/(?:\s+|)[,;](?:\s+|)/sm, $Value);
                }
                next;
            }

            if ($SearchItem =~ /^(?:(?:Assigned|)User|Valid|)ID$/smg) {
                $SearchParams{$SearchItem eq 'ID' ? 'UserID' : $SearchItem} = $Value;
                next;
            }

            if ( $SearchItem =~ /^(?:Title|(?:First|Last)name)$/smg ) {
                $SearchParams{$SearchItem} = $Value;
                next;
            }

            if ( $SearchItem =~ /^(?:City|Country|Fax|Mobil|Phone|Street|Zip)$/smg ) {
                $SearchParams{$SearchItem} = $Value;
                next;
            }

            if ( $SearchItem eq 'Email' ) {
                $SearchParams{Email} = $Value;
                next;
            }

            if ( $SearchItem eq 'PrimaryOrganisationID' ) {
                $SearchParams{OrganisationID} = $Value;
                next;
            }

            $SearchParams{Search} = $Value;
        }

        my %SearchResult = $Kernel::OM->Get('Contact')->ContactSearch(
            %SearchParams,
            Valid => 0,
            Limit => 1,
        );

        @ContactIDs = %SearchResult ? @{[keys %SearchResult]} : ();
    }

    # get contact
    my %Contact;
    my $ContactID;
    if (scalar @ContactIDs) {
        %Contact = $Kernel::OM->Get('Contact')->ContactGet(
            ID     => $ContactIDs[0],
            Silent => $Param{Silent}
        );
        $ContactID = $ContactIDs[0];
    }

    $RowIndex = 0;
    for my $MappingObjectData (@MappingObjectList) {

        # just for convenience
        my $Key   = $MappingObjectData->{Key};
        my $Value = $Param{ImportDataRow}->[ $RowIndex++ ];

        # Import does not override the Contact ID/UserID/AssignedUserID
        next if $Key eq 'ID';
        next if $Key eq 'UserID';
        next if $Key eq 'AssignedUserID';

        if ( $Key eq 'OrganisationIDs' ) {
            if ( !$Value &&  $EmptyFieldsLeaveTheOldValues ) {

                # do nothing, keep the old value
            }
            elsif ( !$Value ) {
                $Contact{OrganisationIDs} = undef;
            }
            else {
                @{$Contact{OrganisationIDs}} = split(/(?:\s+|)[,;](?:\s+|)/sm, $Value);
            }
        }
        elsif ( $Key =~ /^(?:Firstname|Lastname)$/sm ) {

            if ( !$Value && $EmptyFieldsLeaveTheOldValues ) {

                # do nothing, keep the old value
            }
            elsif ( !$Value ) {
                return if $Param{Silent};
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message =>
                        "Can't import entity $Param{Counter}: "
                        . "The $Key is needed!",
                );
                return;
            }
            else {
                $Contact{$Key} = $Value;
            }
        } else{
            if ( !$Value && $EmptyFieldsLeaveTheOldValues ) {

                # do nothing, keep the old value
            }
            else {
                $Contact{$Key} = $Value;
            }
        }
    }

    my $RetCode = $ContactID ? 'Changed' : 'Created';

    # check if the feature to check for a unique email is enabled
    if (
        $Contact{Email}
        && $Kernel::OM->Get('Config')->Get('ContactEmailUniqueCheck')
    ) {

        if ( $Kernel::OM->Get('Config')->{Debug} > 0 ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message  => "Checking for duplicate email (Email: $Contact{Email}, ContactID: " . $ContactID || 'NEW' . ')',
            );
        }
        my $ExistingContactID = $Kernel::OM->Get('Contact')->ContactLookup(
            Email  => $Contact{Email},
            Silent => 1,
        );
        if (
            $ContactID
            && $ExistingContactID
            && $ExistingContactID != $ContactID
        ) {
            $RetCode = "DuplicateEmail '$Contact{Email}'";

            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message =>
                        "Can't import entity $Param{Counter}: "
                        . "Different Contact with this email already exists.",
                );
            }

            # return undef for the contact id so it will be counted as 'Failed'
            return (undef, $RetCode);
        }
        elsif (
            !$ContactID
            && $ExistingContactID
        ) {
            $RetCode = "DuplicateEmail '$Contact{Email}'";

            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message =>
                        "Can't import entity $Param{Counter}: "
                        . "Different Contact with this email already exists.",
                );
            }

            # return undef for the contact id so it will be counted as 'Failed'
            return (undef, $RetCode);
        }
    }

    if (!$ContactID) {
        # no config item was found, so add new config item
        $ContactID = $Kernel::OM->Get('Contact')->ContactAdd(
            %Contact,
            UserID  => $Param{UserID},
            Silent  => $Param{Silent}
        );

        # check the new config item id
        if ( !$ContactID ) {
            return (undef, $RetCode) if $Param{Silent};

                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message =>
                        "Can't import entity $Param{Counter}: "
                        . "Error when adding the new contact.",
                );
            return (undef, $RetCode);
        }
    }
    else {
        # Contact was found, so updated it
        my $Success = $Kernel::OM->Get('Contact')->ContactUpdate(
            %Contact,
            UserID  => $Param{UserID},
            Silent  => $Param{Silent}
        );

        # check if success
        if ( !$Success ) {
            return (undef, $RetCode) if $Param{Silent};

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message =>
                    "Can't import entity $Param{Counter}: "
                    . "Error when updating the contact.",
            );
            return (undef, $RetCode);
        }
    }

    return ($ContactID, $RetCode);
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
