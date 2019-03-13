# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DynamicField;

use strict;
use warnings;

use base qw(Kernel::System::EventHandler);

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::Valid',
    'Kernel::System::YAML',
);

=head1 NAME

Kernel::System::DynamicField

=head1 SYNOPSIS

DynamicFields backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a DynamicField object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get the cache TTL (in seconds)
    $Self->{CacheTTL} = $Kernel::OM->Get('Kernel::Config')->Get('DynamicField::CacheTTL') || 3600;

    # set lower if database is case sensitive
    $Self->{Lower} = '';
    if ( $Kernel::OM->Get('Kernel::System::DB')->GetDatabaseFunction('CaseSensitive') ) {
        $Self->{Lower} = 'LOWER';
    }

    # init of event handler
    $Self->EventHandlerInit(
        Config => 'DynamicField::EventModulePost',
    );

    return $Self;
}

=item DynamicFieldAdd()

add new Dynamic Field config

returns id of new Dynamic field if successful or undef otherwise

    my $ID = $DynamicFieldObject->DynamicFieldAdd(
        InternalField => 0,             # optional, 0 or 1, internal fields are protected
        Name            => 'NameForField',  # mandatory
        Label           => 'a description', # mandatory, label to show
        FieldType       => 'Text',          # mandatory, selects the DF backend to use for this field
        ObjectType      => 'Article',       # this controls which object the dynamic field links to
                                        # allow only lowercase letters
        DisplayGroupID  => 123,          # optional
        Config          => $ConfigHashRef,  # it is stored on YAML format
                                        # to individual articles, otherwise to tickets
        Reorder         => 1,               # or 0, to trigger reorder function, default 1
        ValidID         => 1,
        UserID          => 123,
    );

Returns:

    $ID = 567;

=cut

sub DynamicFieldAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Key (qw(Name Label FieldType ObjectType Config ValidID UserID)) {
        if ( !$Param{$Key} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Key!"
            );
            return;
        }
    }

    # check needed structure for some fields
    if ( $Param{Name} !~ m{ \A [a-zA-Z\d]+ \z }xms ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Not valid letters on Name:$Param{Name}!"
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # check if Name already exists
    return if !$DBObject->Prepare(
        SQL   => "SELECT id FROM dynamic_field WHERE $Self->{Lower}(name) = $Self->{Lower}(?)",
        Bind  => [ \$Param{Name} ],
        Limit => 1,
    );

    my $NameExists;
    while ( my @Data = $DBObject->FetchrowArray() ) {
        $NameExists = 1;
    }

    if ($NameExists) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "The name $Param{Name} already exists for a dynamic field!"
        );
        return;
    }

    # dump config as string
    my $Config = $Kernel::OM->Get('Kernel::System::YAML')->Dump( Data => $Param{Config} );

    # Make sure the resulting string has the UTF-8 flag. YAML only sets it if
    #   part of the data already had it.
    utf8::upgrade($Config);

    my $InternalField = $Param{InternalField} ? 1 : 0;

    # sql
    return if !$DBObject->Do(
        SQL =>
            'INSERT INTO dynamic_field (internal_field, name, label, field_type, displaygroup_id, object_type,' .
            ' config, valid_id, create_time, create_by, change_time, change_by)' .
            ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$InternalField, \$Param{Name}, \$Param{Label}, \$Param{FieldType}, \$Param{DisplayGroupID},
            \$Param{ObjectType}, \$Config, \$Param{ValidID}, \$Param{UserID}, \$Param{UserID},
        ],
    );

    # get cache object
    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');

    # delete cache
    $CacheObject->CleanUp(
        Type => 'DynamicField',
    );
    $CacheObject->CleanUp(
        Type => 'DynamicFieldValue',
    );

    my $DynamicField = $Self->DynamicFieldGet(
        Name => $Param{Name},
    );

    return if !$DynamicField->{ID};

    # trigger event
    $Self->EventHandler(
        Event => 'DynamicFieldAdd',
        Data  => {
            NewData => $DynamicField,
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event    => 'CREATE',
        Object   => 'DynamicField',
        ObjectID => $DynamicField->{ID},
    );

    return $DynamicField->{ID};
}

=item DynamicFieldGet()

get Dynamic Field attributes

    my $DynamicField = $DynamicFieldObject->DynamicFieldGet(
        ID   => 123,             # ID or Name must be provided
        Name => 'DynamicField',
    );

Returns:

    $DynamicField = {
        ID            => 123,
        InternalField => 0,
        Name          => 'NameForField',
        Label         => 'The label to show',
        FieldType     => 'Text',
        ObjectType    => 'Article',
        Config        => $ConfigHashRef,
        DisplayGroupID => 123,
        ValidID       => 1,
        CreateBy      => 1,
        CreateTime    => '2011-02-08 15:08:00',
        ChangeBy      => 1,
        ChangeTime    => '2011-06-11 17:22:00',
    };

=cut

sub DynamicFieldGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ID} && !$Param{Name} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need ID or Name!'
        );
        return;
    }

    # get cache object
    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');

    # check cache
    my $CacheKey;
    if ( $Param{ID} ) {
        $CacheKey = 'DynamicFieldGet::ID::' . $Param{ID};
    }
    else {
        $CacheKey = 'DynamicFieldGet::Name::' . $Param{Name};

    }
    my $Cache = $CacheObject->Get(
        Type => 'DynamicField',
        Key  => $CacheKey,
    );
    return $Cache if $Cache;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # sql
    if ( $Param{ID} ) {
        return if !$DBObject->Prepare(
            SQL =>
                'SELECT id, internal_field, name, label, field_type, displaygroup_id, object_type, config,'
                .
                ' valid_id, create_by, create_time, change_by, change_time ' .
                'FROM dynamic_field WHERE id = ?',
            Bind => [ \$Param{ID} ],
        );
    }
    else {
        return if !$DBObject->Prepare(
            SQL =>
                'SELECT id, internal_field, name, label, field_type, displaygroup_id, object_type, config,'
                .
                ' valid_id, create_by, create_time, change_by, change_time ' .
                'FROM dynamic_field WHERE name = ?',
            Bind => [ \$Param{Name} ],
        );
    }

    # get yaml object
    my $YAMLObject = $Kernel::OM->Get('Kernel::System::YAML');

    my %Data;
    while ( my @Data = $DBObject->FetchrowArray() ) {

        my $Config = $YAMLObject->Load( Data => $Data[7] );

        %Data = (
            ID              => $Data[0],
            InternalField   => $Data[1],
            Name            => $Data[2],
            Label           => $Data[3],
            FieldType       => $Data[4],
            DisplayGroupID  => $Data[5],
            ObjectType      => $Data[6],
            Config          => $Config,
            ValidID         => $Data[8],
            CreateBy        => $Data[9],
            CreateTime      => $Data[10],
            ChangeBy        => $Data[11],
            ChangeTime      => $Data[12],
        );
    }

    if (%Data) {

        # Set the cache only, if the YAML->Load was successful (see bug#12483).
        if ( $Data{Config} ) {

            $CacheObject->Set(
                Type  => 'DynamicField',
                Key   => $CacheKey,
                Value => \%Data,
                TTL   => $Self->{CacheTTL},
            );
        }

        $Data{Config} ||= {};
    }

    return \%Data;
}

=item DynamicFieldUpdate()

update Dynamic Field content into database

returns 1 on success or undef on error

    my $Success = $DynamicFieldObject->DynamicFieldUpdate(
        ID              => 1234,            # mandatory
        Name            => 'NameForField',  # mandatory
        Label           => 'a description', # mandatory, label to show
        FieldType       => 'Text',          # mandatory, selects the DF backend to use for this field
        DisplayGroupID  => 123,          # optional
        ObjectType      => 'Article',       # this controls which object the dynamic field links to
                                        # allow only lowercase letters
        Config          => $ConfigHashRef,  # it is stored on YAML format
                                        # to individual articles, otherwise to tickets
        ValidID         => 1,
        Reorder         => 1,               # or 0, to trigger reorder function, default 1
        UserID          => 123,
    );
    );

=cut

sub DynamicFieldUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Key (qw(ID Name Label FieldType ObjectType Config ValidID UserID)) {
        if ( !$Param{$Key} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Key!"
            );
            return;
        }
    }

    my $YAMLObject = $Kernel::OM->Get('Kernel::System::YAML');

    # dump config as string
    my $Config = $YAMLObject->Dump(
        Data => $Param{Config},
    );

    # Make sure the resulting string has the UTF-8 flag. YAML only sets it if
    #    part of the data already had it.
    utf8::upgrade($Config);

    return if !$YAMLObject->Load( Data => $Config );

    # check needed structure for some fields
    if ( $Param{Name} !~ m{ \A [a-zA-Z\d]+ \z }xms ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Not valid letters on Name:$Param{Name} or ObjectType:$Param{ObjectType}!",
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # check if Name already exists
    return if !$DBObject->Prepare(
        SQL => "SELECT id FROM dynamic_field "
            . "WHERE $Self->{Lower}(name) = $Self->{Lower}(?) "
            . "AND id != ?",
        Bind  => [ \$Param{Name}, \$Param{ID} ],
        LIMIT => 1,
    );

    my $NameExists;
    while ( my @Data = $DBObject->FetchrowArray() ) {
        $NameExists = 1;
    }

    if ($NameExists) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "The name $Param{Name} already exists for a dynamic field!",
        );
        return;
    }

    # get the old dynamic field data
    my $OldDynamicField = $Self->DynamicFieldGet(
        ID => $Param{ID},
    );

    # sql
    return if !$DBObject->Do(
        SQL => 'UPDATE dynamic_field SET name = ?, label = ?, field_type = ?, displaygroup_id = ?,'
            . 'object_type = ?, config = ?, valid_id = ?, change_time = current_timestamp, '
            . ' change_by = ? WHERE id = ?',
        Bind => [
            \$Param{Name}, \$Param{Label}, \$Param{FieldType}, \$Param{DisplayGroupID},
            \$Param{ObjectType}, \$Config, \$Param{ValidID}, \$Param{UserID}, \$Param{ID},
        ],
    );

    # get cache object
    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');

    # delete cache
    $CacheObject->CleanUp(
        Type => 'DynamicField',
    );
    $CacheObject->CleanUp(
        Type => 'DynamicFieldValue',
    );

    # get the new dynamic field data
    my $NewDynamicField = $Self->DynamicFieldGet(
        ID => $Param{ID},
    );

    # trigger event
    $Self->EventHandler(
        Event => 'DynamicFieldUpdate',
        Data  => {
            NewData => $NewDynamicField,
            OldData => $OldDynamicField,
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event    => 'UPDATE',
        Object   => 'DynamicField',
        ObjectID => $Param{ID},
    );

    return 1;
}

=item DynamicFieldDelete()

delete a Dynamic field entry. You need to make sure that all values are
deleted before calling this function, otherwise it will fail on DBMS which check
referential integrity.

returns 1 if successful or undef otherwise

    my $Success = $DynamicFieldObject->DynamicFieldDelete(
        ID      => 123,
        UserID  => 123,
        Reorder => 1,               # or 0, to trigger reorder function, default 1
    );

=cut

sub DynamicFieldDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Key (qw(ID UserID)) {
        if ( !$Param{$Key} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Key!"
            );
            return;
        }
    }

    # check if exists
    my $DynamicField = $Self->DynamicFieldGet(
        ID => $Param{ID},
    );
    return if !IsHashRefWithData($DynamicField);

    # delete dynamic field
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL  => 'DELETE FROM dynamic_field WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );

    # get cache object
    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');

    # delete cache
    $CacheObject->CleanUp(
        Type => 'DynamicField',
    );
    $CacheObject->CleanUp(
        Type => 'DynamicFieldValue',
    );

    # trigger event
    $Self->EventHandler(
        Event => 'DynamicFieldDelete',
        Data  => {
            NewData => $DynamicField,
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event    => 'DELETE',
        Object   => 'DynamicField',
        ObjectID => $Param{ID},
    );

    return 1;
}

=item DynamicFieldList()

get DynamicField list ordered by the the "Field Order" field in the DB

    my $List = $DynamicFieldObject->DynamicFieldList();

    or

    my $List = $DynamicFieldObject->DynamicFieldList(
        Valid => 0,             # optional, defaults to 1

        # object  type (optional) as STRING or as ARRAYREF
        ObjectType => 'Ticket',
        ObjectType => ['Ticket', 'Article'],

        ResultType => 'HASH',   # optional, 'ARRAY' or 'HASH', defaults to 'ARRAY'

        FieldFilter => {        # optional, only active fields (non 0) will be returned
            ItemOne   => 1,
            ItemTwo   => 2,
            ItemThree => 1,
            ItemFour  => 1,
            ItemFive  => 0,
        },

    );

Returns:

    $List = {
        1 => 'ItemOne',
        2 => 'ItemTwo',
        3 => 'ItemThree',
        4 => 'ItemFour',
    };

    or

    $List = (
        1,
        2,
        3,
        4
    );

=cut

sub DynamicFieldList {
    my ( $Self, %Param ) = @_;

    # to store fieldIDs whitelist
    my %AllowedFieldIDs;

    if ( defined $Param{FieldFilter} && ref $Param{FieldFilter} eq 'HASH' ) {

        # fill the fieldIDs whitelist
        FIELDNAME:
        for my $FieldName ( sort keys %{ $Param{FieldFilter} } ) {
            next FIELDNAME if !$Param{FieldFilter}->{$FieldName};

            my $FieldConfig = $Self->DynamicFieldGet( Name => $FieldName );
            next FIELDNAME if !IsHashRefWithData($FieldConfig);
            next FIELDNAME if !$FieldConfig->{ID};

            $AllowedFieldIDs{ $FieldConfig->{ID} } = 1,
        }
    }

    # check cache
    my $Valid = 1;
    if ( defined $Param{Valid} && $Param{Valid} eq '0' ) {
        $Valid = 0;
    }

    # set cache key object type component depending on the ObjectType parameter
    my $ObjectType = 'All';
    if ( IsArrayRefWithData( $Param{ObjectType} ) ) {
        $ObjectType = join '_', sort @{ $Param{ObjectType} };
    }
    elsif ( IsStringWithData( $Param{ObjectType} ) ) {
        $ObjectType = $Param{ObjectType};
    }

    my $ResultType = $Param{ResultType} || 'ARRAY';
    $ResultType = $ResultType eq 'HASH' ? 'HASH' : 'ARRAY';

    # get cache object
    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');

    my $CacheKey = 'DynamicFieldList::Valid::'
        . $Valid
        . '::ObjectType::'
        . $ObjectType
        . '::ResultType::'
        . $ResultType;
    my $Cache = $CacheObject->Get(
        Type => 'DynamicField',
        Key  => $CacheKey,
    );

    if ($Cache) {

        # check if FieldFilter is not set
        if ( !defined $Param{FieldFilter} ) {

            # return raw data from cache
            return $Cache;
        }
        elsif ( ref $Param{FieldFilter} ne 'HASH' ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'FieldFilter must be a HASH reference!',
            );
            return;
        }

        # otherwise apply the filter
        my $FilteredData;

        # check if cache is ARRAY ref
        if ( $ResultType eq 'ARRAY' ) {

            FIELDID:
            for my $FieldID ( @{$Cache} ) {
                next FIELDID if !$AllowedFieldIDs{$FieldID};

                push @{$FilteredData}, $FieldID;
            }

            # return filtered data from cache
            return $FilteredData;
        }

        # otherwise is a HASH ref
        else {

            FIELDID:
            for my $FieldID ( sort keys %{$Cache} ) {
                next FIELDID if !$AllowedFieldIDs{$FieldID};

                $FilteredData->{$FieldID} = $Cache->{$FieldID}
            }
        }

        # return filtered data from cache
        return $FilteredData;
    }

    else {
        my $SQL = 'SELECT id, name FROM dynamic_field';

        # get database object
        my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

        if ($Valid) {

            # get valid object
            my $ValidObject = $Kernel::OM->Get('Kernel::System::Valid');

            $SQL .= ' WHERE valid_id IN (' . join ', ', $ValidObject->ValidIDsGet() . ')';

            if ( $Param{ObjectType} ) {
                if ( IsStringWithData( $Param{ObjectType} ) && $Param{ObjectType} ne 'All' ) {
                    $SQL .=
                        " AND object_type = '"
                        . $DBObject->Quote( $Param{ObjectType} ) . "'";
                }
                elsif ( IsArrayRefWithData( $Param{ObjectType} ) ) {
                    my $ObjectTypeString =
                        join ',',
                        map "'" . $DBObject->Quote($_) . "'",
                        @{ $Param{ObjectType} };
                    $SQL .= " AND object_type IN ($ObjectTypeString)";

                }
            }
        }
        else {
            if ( $Param{ObjectType} ) {
                if ( IsStringWithData( $Param{ObjectType} ) && $Param{ObjectType} ne 'All' ) {
                    $SQL .=
                        " WHERE object_type = '"
                        . $DBObject->Quote( $Param{ObjectType} ) . "'";
                }
                elsif ( IsArrayRefWithData( $Param{ObjectType} ) ) {
                    my $ObjectTypeString =
                        join ',',
                        map "'" . $DBObject->Quote($_) . "'",
                        @{ $Param{ObjectType} };
                    $SQL .= " WHERE object_type IN ($ObjectTypeString)";
                }
            }
        }

        $SQL .= " ORDER BY id";

        return if !$DBObject->Prepare( SQL => $SQL );

        if ( $ResultType eq 'HASH' ) {
            my %Data;

            while ( my @Row = $DBObject->FetchrowArray() ) {
                $Data{ $Row[0] } = $Row[1];
            }

            # set cache
            $CacheObject->Set(
                Type  => 'DynamicField',
                Key   => $CacheKey,
                Value => \%Data,
                TTL   => $Self->{CacheTTL},
            );

            # check if FieldFilter is not set
            if ( !defined $Param{FieldFilter} ) {

                # return raw data from DB
                return \%Data;
            }
            elsif ( ref $Param{FieldFilter} ne 'HASH' ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => 'FieldFilter must be a HASH reference!',
                );
                return;
            }

            my %FilteredData;
            FIELDID:
            for my $FieldID ( sort keys %Data ) {
                next FIELDID if !$AllowedFieldIDs{$FieldID};

                $FilteredData{$FieldID} = $Data{$FieldID};
            }

            # return filtered data from DB
            return \%FilteredData;
        }

        else {

            my @Data;
            while ( my @Row = $DBObject->FetchrowArray() ) {
                push @Data, $Row[0];
            }

            # set cache
            $CacheObject->Set(
                Type  => 'DynamicField',
                Key   => $CacheKey,
                Value => \@Data,
                TTL   => $Self->{CacheTTL},
            );

            # check if FieldFilter is not set
            if ( !defined $Param{FieldFilter} ) {

                # return raw data from DB
                return \@Data;
            }
            elsif ( ref $Param{FieldFilter} ne 'HASH' ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => 'FieldFilter must be a HASH reference!',
                );
                return;
            }

            my @FilteredData;
            FIELDID:
            for my $FieldID (@Data) {
                next FIELDID if !$AllowedFieldIDs{$FieldID};

                push @FilteredData, $FieldID;
            }

            # return filtered data from DB
            return \@FilteredData;
        }
    }

    return;
}

=item DynamicFieldListGet()

get DynamicField list with complete data ordered by the "Field Order" field in the DB

    my $List = $DynamicFieldObject->DynamicFieldListGet();

    or

    my $List = $DynamicFieldObject->DynamicFieldListGet(
        Valid        => 0,            # optional, defaults to 1

        # object  type (optional) as STRING or as ARRAYREF
        ObjectType => 'Ticket',
        ObjectType => ['Ticket', 'Article'],

        FieldFilter => {        # optional, only active fields (non 0) will be returned
            nameforfield => 1,
            fieldname    => 2,
            other        => 0,
            otherfield   => 0,
        },

    );

Returns:

    $List = (
        {
            ID          => 123,
            InternalField => 0,
            Name        => 'nameforfield',
            Label       => 'The label to show',
            FieldType   => 'Text',
            ObjectType  => 'Article',
            Config      => $ConfigHashRef,
            ValidID     => 1,
            CreateTime  => '2011-02-08 15:08:00',
            ChangeTime  => '2011-06-11 17:22:00',
        },
        {
            ID            => 321,
            InternalField => 0,
            Name          => 'fieldname',
            Label         => 'It is not a label',
            FieldType     => 'Text',
            ObjectType    => 'Ticket',
            Config        => $ConfigHashRef,
            ValidID       => 1,
            CreateTime    => '2010-09-11 10:08:00',
            ChangeTime    => '2011-01-01 01:01:01',
        },
        ...
    );

=cut

sub DynamicFieldListGet {
    my ( $Self, %Param ) = @_;

    # check cache
    my $Valid = 1;
    if ( defined $Param{Valid} && $Param{Valid} eq '0' ) {
        $Valid = 0;
    }

    # set cache key object type component depending on the ObjectType parameter
    my $ObjectType = 'All';
    if ( IsArrayRefWithData( $Param{ObjectType} ) ) {
        $ObjectType = join '_', sort @{ $Param{ObjectType} };
    }
    elsif ( IsStringWithData( $Param{ObjectType} ) ) {
        $ObjectType = $Param{ObjectType};
    }

    # get cache object
    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');

    my $CacheKey = 'DynamicFieldListGet::Valid::' . $Valid . '::ObjectType::' . $ObjectType;
    my $Cache    = $CacheObject->Get(
        Type => 'DynamicField',
        Key  => $CacheKey,
    );

    if ($Cache) {

        # check if FieldFilter is not set
        if ( !defined $Param{FieldFilter} ) {

            # return raw data from cache
            return $Cache;
        }
        elsif ( ref $Param{FieldFilter} ne 'HASH' ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'FieldFilter must be a HASH reference!',
            );
            return;
        }

        my $FilteredData;

        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{$Cache} ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
            next DYNAMICFIELD if !$DynamicFieldConfig->{Name};
            next DYNAMICFIELD if !$Param{FieldFilter}->{ $DynamicFieldConfig->{Name} };

            push @{$FilteredData}, $DynamicFieldConfig,
        }

        # return filtered data from cache
        return $FilteredData;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    my @Data;
    my $SQL = 'SELECT id, name FROM dynamic_field';

    if ($Valid) {

        # get valid object
        my $ValidObject = $Kernel::OM->Get('Kernel::System::Valid');

        $SQL .= ' WHERE valid_id IN (' . join ', ', $ValidObject->ValidIDsGet() . ')';

        if ( $Param{ObjectType} ) {
            if ( IsStringWithData( $Param{ObjectType} ) && $Param{ObjectType} ne 'All' ) {
                $SQL .=
                    " AND object_type = '" . $DBObject->Quote( $Param{ObjectType} ) . "'";
            }
            elsif ( IsArrayRefWithData( $Param{ObjectType} ) ) {
                my $ObjectTypeString =
                    join ',',
                    map "'" . $DBObject->Quote($_) . "'",
                    @{ $Param{ObjectType} };
                $SQL .= " AND object_type IN ($ObjectTypeString)";

            }
        }
    }
    else {
        if ( $Param{ObjectType} ) {
            if ( IsStringWithData( $Param{ObjectType} ) && $Param{ObjectType} ne 'All' ) {
                $SQL .=
                    " WHERE object_type = '" . $DBObject->Quote( $Param{ObjectType} ) . "'";
            }
            elsif ( IsArrayRefWithData( $Param{ObjectType} ) ) {
                my $ObjectTypeString =
                    join ',',
                    map "'" . $DBObject->Quote($_) . "'",
                    @{ $Param{ObjectType} };
                $SQL .= " WHERE object_type IN ($ObjectTypeString)";
            }
        }
    }

    $SQL .= " ORDER BY id";

    return if !$DBObject->Prepare( SQL => $SQL );

    my @DynamicFieldIDs;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @DynamicFieldIDs, $Row[0];
    }

    for my $ItemID (@DynamicFieldIDs) {

        my $DynamicField = $Self->DynamicFieldGet(
            ID => $ItemID,
        );
        push @Data, $DynamicField;
    }

    # set cache
    $CacheObject->Set(
        Type  => 'DynamicField',
        Key   => $CacheKey,
        Value => \@Data,
        TTL   => $Self->{CacheTTL},
    );

    # check if FieldFilter is not set
    if ( !defined $Param{FieldFilter} ) {

        # return raw data from DB
        return \@Data;
    }
    elsif ( ref $Param{FieldFilter} ne 'HASH' ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'FieldFilter must be a HASH reference!',
        );
        return;
    }

    my $FilteredData;

    DYNAMICFIELD:
    for my $DynamicFieldConfig (@Data) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
        next DYNAMICFIELD if !$DynamicFieldConfig->{Name};
        next DYNAMICFIELD if !$Param{FieldFilter}->{ $DynamicFieldConfig->{Name} };

        push @{$FilteredData}, $DynamicFieldConfig,
    }

    # return filtered data from DB
    return $FilteredData;
}

sub DESTROY {
    my $Self = shift;

    # execute all transaction events
    $Self->EventHandlerTransaction();

    return 1;
}

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
