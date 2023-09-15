# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ImportExport::ObjectBackend::Organisation;

use strict;
use warnings;
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'Organisation',
    'ImportExport',
    'Log',
);

=head1 NAME

Kernel::System::ImportExport::ObjectBackend::Organisation - import/export backend for Organisation

=head1 SYNOPSIS

All functions to import and export Organisation entries

=over 4

=cut

=item new()

create an object

    use Kernel::Config;
    use Kernel::System::DB;
    use Kernel::System::Log;
    use Kernel::System::Main;
    use Kernel::System::ImportExport::ObjectBackend::Organisation;

    my $ConfigObject = Kernel::Config->new();
    my $LogObject = Kernel::System::Log->new(
        ConfigObject => $ConfigObject,
    );
    my $MainObject = Kernel::System::Main->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
    );
    my $DBObject = Kernel::System::DB->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
        MainObject   => $MainObject,
    );
    my $BackendObject = Kernel::System::ImportExport::ObjectBackend::Organisation->new(
        ConfigObject       => $ConfigObject,
        LogObject          => $LogObject,
        DBObject           => $DBObject,
        MainObject         => $MainObject,
        ImportExportObject => $ImportExportObject,
    );

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
            Key   => 'Number',
            Value => 'Number',
        },
        {
            Key   => 'Name',
            Value => 'Name',
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
        }
    );

    if ( $ObjectData->{DynamicField} ) {
        my $DynamicFields = $Kernel::OM->Get('DynamicField')->DynamicFieldListGet(
            ObjectType => 'Organisation',
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

        if ($SearchItem =~ /^(?:Name|Number)$/smg) {
            $SearchParams{$SearchItem} = $Value;
            next;
        }

        if ($SearchItem =~ /^ValidID$/smg) {
            $SearchParams{$SearchItem} = $Value;
            next;
        }

        if ( $SearchItem =~ /^(?:Title|(?:First|Last)name)$/smg ) {
            $SearchParams{$SearchItem} = $Value;
            next;
        }

        if ( $SearchItem =~ /^(?:City|Country|Street|Zip)$/smg ) {
            $SearchParams{$SearchItem} = $Value;
            next;
        }

        $SearchParams{Search} = $Value;
    }

    my %SearchResult = $Kernel::OM->Get('Organisation')->OrganisationSearch(
        %SearchParams,
        Valid => 0,
        Limit => 0,
    );
    my @SearchTypeResult = %SearchResult ? @{[keys %SearchResult]} : ();

    my @ExportData;
    CONTACT:
    for my $OrgaID ( @SearchTypeResult ) {

        # get last version
        my %Orga = $Kernel::OM->Get('Organisation')->OrganisationGet(
            ID => $OrgaID,
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

            # handle all data elements
            push @Item, $Orga{$Key};
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
    my @OrgaIDs;
    if (%Identifier) {

        my %SearchParams;
        foreach my $SearchItem ( keys %Identifier ) {
            my $Value = $Identifier{$SearchItem};
            if ($SearchItem =~ /^(?:Name|Number)$/smg) {
                $SearchParams{$SearchItem} = $Value;
                next;
            }

            if ($SearchItem =~ /^ValidID$/smg) {
                $SearchParams{$SearchItem} = $Value;
                next;
            }

            if ( $SearchItem =~ /^(?:Title|(?:First|Last)name)$/smg ) {
                $SearchParams{$SearchItem} = $Value;
                next;
            }

            if ( $SearchItem =~ /^(?:City|Country|Street|Zip)$/smg ) {
                $SearchParams{$SearchItem} = $Value;
                next;
            }

            $SearchParams{Search} = $Value;
        }

        my %SearchResult = $Kernel::OM->Get('Organisation')->OrganisationSearch(
            %SearchParams,
            Valid => 0,
            Limit => 1,
        );

        @OrgaIDs = %SearchResult ? @{[keys %SearchResult]} : ();
    }

    # get contact
    my %Organisation;
    my $OrgaID;
    if (scalar @OrgaIDs) {
        %Organisation = $Kernel::OM->Get('Organisation')->OrganisationGet(
            ID     => $OrgaIDs[0],
            Silent => $Param{Silent}
        );
        $OrgaID = $OrgaIDs[0];
    }

    $RowIndex = 0;
    for my $MappingObjectData (@MappingObjectList) {

        # just for convenience
        my $Key   = $MappingObjectData->{Key};
        my $Value = $Param{ImportDataRow}->[ $RowIndex++ ];

        # Import does not override the Organisation ID/UserID/AssignedUserID
        next if $Key eq 'ID';
        next if $Key eq 'UserID';
        next if $Key eq 'AssignedUserID';

        if ( $Key =~ /^(?:Name|Number)$/sm ) {

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
                $Organisation{$Key} = $Value;
            }
        } else{
            if ( !$Value && $EmptyFieldsLeaveTheOldValues ) {

                # do nothing, keep the old value
            }
            else {
                $Organisation{$Key} = $Value;
            }
        }
    }

    my $RetCode = $OrgaID ? 'Changed' : 'Created';

    if (!$OrgaID) {
        # no config item was found, so add new config item
        $OrgaID = $Kernel::OM->Get('Organisation')->OrganisationAdd(
            %Organisation,
            UserID  => $Param{UserID},
            Silent  => $Param{Silent}
        );

        # check the new config item id
        if ( !$OrgaID ) {
            return (undef, $RetCode) if $Param{Silent};

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message =>
                    "Can't import entity $Param{Counter}: "
                    . "Error when adding the new organisation.",
            );
            return (undef, $RetCode);
        }
    }
    else {
        # Organisation was found, so updated it
        my $Success = $Kernel::OM->Get('Organisation')->OrganisationUpdate(
            %Organisation,
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
                    . "Error when updating the organisation.",
            );
            return (undef, $RetCode);
        }
    }

    return ($OrgaID, $RetCode);
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
