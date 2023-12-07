# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DynamicField;

use strict;
use warnings;

use base qw(Kernel::System::EventHandler);

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = qw(
    ClientRegistration
    Config
    Cache
    DB
    Log
    Valid
    YAML
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
    my $DynamicFieldObject = $Kernel::OM->Get('DynamicField');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get the cache TTL (in seconds)
    $Self->{CacheTTL} = $Kernel::OM->Get('Config')->Get('DynamicField::CacheTTL') || 3600;

    # set lower if database is case sensitive
    $Self->{Lower} = '';
    if ( $Kernel::OM->Get('DB')->GetDatabaseFunction('CaseSensitive') ) {
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
        Comment         => 'a comment'    , #optional
        FieldType       => 'Text',          # mandatory, selects the DF backend to use for this field
        ObjectType      => 'Article',       # this controls which object the dynamic field links to
                                        # allow only lowercase letters
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
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Key!"
                );
            }
            return;
        }
    }

    # check needed structure for some fields
    if ( $Param{Name} !~ m{ \A [a-zA-Z\d]+ \z }xms ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Not valid letters on Name:$Param{Name}!"
            );
        }
        return;
    }

    # check CustomerVisible
    $Param{CustomerVisible} = $Param{CustomerVisible} ? 1 : 0;

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

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
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "The name $Param{Name} already exists for a dynamic field!"
            );
        }
        return;
    }

    # dump config as string
    my $Config = $Kernel::OM->Get('YAML')->Dump( Data => $Param{Config} );

    # Make sure the resulting string has the UTF-8 flag. YAML only sets it if
    #   part of the data already had it.
    utf8::upgrade($Config);

    my $InternalField = $Param{InternalField} ? 1 : 0;

    # sql
    return if !$DBObject->Do(
        SQL =>
            'INSERT INTO dynamic_field (internal_field, name, label, field_type, comments, object_type,' .
            ' config, customer_visible, valid_id, create_time, create_by, change_time, change_by)' .
            ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$InternalField, \$Param{Name}, \$Param{Label}, \$Param{FieldType}, \$Param{Comment},
            \$Param{ObjectType}, \$Config, \$Param{CustomerVisible}, \$Param{ValidID}, \$Param{UserID}, \$Param{UserID},
        ],
    );

    # get cache object
    my $CacheObject = $Kernel::OM->Get('Cache');

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
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'DynamicField',
        ObjectID  => $DynamicField->{ID},
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
        ID              => 123,
        InternalField   => 0,
        Name            => 'NameForField',
        Label           => 'The label to show',
        FieldType       => 'Text',
        ObjectType      => 'Article',
        Config          => $ConfigHashRef,
        Comment         => '...',
        CustomerVisible => 0,
        ValidID         => 1,
        CreateBy        => 1,
        CreateTime      => '2011-02-08 15:08:00',
        ChangeBy        => 1,
        ChangeTime      => '2011-06-11 17:22:00',
    };

=cut

sub DynamicFieldGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ID} && !$Param{Name} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need ID or Name!'
        );
        return;
    }

    # get cache object
    my $CacheObject = $Kernel::OM->Get('Cache');

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
    my $DBObject = $Kernel::OM->Get('DB');

    # sql
    if ( $Param{ID} ) {
        return if !$DBObject->Prepare(
            SQL =>
                'SELECT id, internal_field, name, label, field_type, comments, object_type, config, customer_visible,'
                .
                ' valid_id, create_by, create_time, change_by, change_time ' .
                'FROM dynamic_field WHERE id = ?',
            Bind => [ \$Param{ID} ],
        );
    }
    else {
        return if !$DBObject->Prepare(
            SQL =>
                'SELECT id, internal_field, name, label, field_type, comments, object_type, config, customer_visible,'
                .
                ' valid_id, create_by, create_time, change_by, change_time ' .
                'FROM dynamic_field WHERE name = ?',
            Bind => [ \$Param{Name} ],
        );
    }

    # get yaml object
    my $YAMLObject = $Kernel::OM->Get('YAML');

    my %Data;
    while ( my @Data = $DBObject->FetchrowArray() ) {

        my $Config = $YAMLObject->Load( Data => $Data[7] );
        my $CustomerVisible = $Data[8] ? 1 : 0;

        %Data = (
            ID              => $Data[0],
            InternalField   => $Data[1],
            Name            => $Data[2],
            Label           => $Data[3],
            FieldType       => $Data[4],
            Comment         => $Data[5],
            ObjectType      => $Data[6],
            Config          => $Config,
            CustomerVisible => $CustomerVisible,
            ValidID         => $Data[9],
            CreateBy        => $Data[10],
            CreateTime      => $Data[11],
            ChangeBy        => $Data[12],
            ChangeTime      => $Data[13]
        );
    }

    # get display name
    if ( %Data && defined $Data{FieldType} && $Data{FieldType} ) {

        # get config object
        my $ConfigObject = $Kernel::OM->Get('Config');

        # get the Dynamic Field Backends configuration
        my $DynamicFieldsConfig = $ConfigObject->Get('DynamicFields::Driver');

        if ( defined $DynamicFieldsConfig->{$Data{FieldType}}->{DisplayName} && $DynamicFieldsConfig->{$Data{FieldType}}->{DisplayName} ) {
            $Data{FieldTypeDisplayName} = $DynamicFieldsConfig->{$Data{FieldType}}->{DisplayName};
        }
        else {
            $Data{FieldTypeDisplayName} = $Data{FieldType};
        }
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
        Comment         => 'a comment',     # optional
        ObjectType      => 'Article',       # this controls which object the dynamic field links to
                                        # allow only lowercase letters
        Config          => $ConfigHashRef,  # it is stored on YAML format
                                        # to individual articles, otherwise to tickets
        CustomerVisible => 0,
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
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Key!"
                );
            }
            return;
        }
    }

    my $YAMLObject = $Kernel::OM->Get('YAML');

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
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Not valid letters on Name:$Param{Name} or ObjectType:$Param{ObjectType}!",
            );
        }
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

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
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "The name $Param{Name} already exists for a dynamic field!",
            );
        }
        return;
    }

    # get the old dynamic field data
    my $OldDynamicField = $Self->DynamicFieldGet(
        ID => $Param{ID},
    );

    # sql
    return if !$DBObject->Do(
        SQL => 'UPDATE dynamic_field SET name = ?, label = ?, field_type = ?, comments = ?,'
            . 'object_type = ?, config = ?, customer_visible = ?, valid_id = ?, change_time = current_timestamp, '
            . ' change_by = ? WHERE id = ?',
        Bind => [
            \$Param{Name}, \$Param{Label}, \$Param{FieldType}, \$Param{Comment},
            \$Param{ObjectType}, \$Config, \$Param{CustomerVisible}, \$Param{ValidID}, \$Param{UserID}, \$Param{ID},
        ],
    );

    # get cache object
    my $CacheObject = $Kernel::OM->Get('Cache');

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
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'DynamicField',
        ObjectID  => $Param{ID},
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
            $Kernel::OM->Get('Log')->Log(
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
    return if !$Kernel::OM->Get('DB')->Do(
        SQL  => 'DELETE FROM dynamic_field WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );

    # get cache object
    my $CacheObject = $Kernel::OM->Get('Cache');

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
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'DynamicField',
        ObjectID  => $Param{ID},
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

        # field  type (optional) as STRING or as ARRAYREF
        FieldType => 'Text',
        FieldType => [
            'Text', 'Textarea', 'Date', 'DateTime', 'ITSMConfigItemReference',
            'Multiselect', 'CheckList', 'TicketReference', 'Dropdown', ...
        ],

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

    if (
        defined $Param{FieldFilter}
        && ref $Param{FieldFilter} eq 'HASH'
    ) {

        # fill the fieldIDs whitelist
        FIELDNAME:
        for my $FieldName ( sort keys %{ $Param{FieldFilter} } ) {
            next FIELDNAME if !$Param{FieldFilter}->{$FieldName};

            my $FieldConfig = $Self->DynamicFieldGet( Name => $FieldName );
            next FIELDNAME if !IsHashRefWithData($FieldConfig);
            next FIELDNAME if !$FieldConfig->{ID};

            $AllowedFieldIDs{ $FieldConfig->{ID} } = 1;
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
        $ObjectType = join( '_', sort @{ $Param{ObjectType} } );
    }
    elsif ( IsStringWithData( $Param{ObjectType} ) ) {
        $ObjectType = $Param{ObjectType};
    }

    # set cache key field type component depending on the FieldType parameter
    my $FieldType = 'All';
    if ( IsArrayRefWithData( $Param{FieldType} ) ) {
        $FieldType = join( '_', sort @{ $Param{FieldType} } );
    }
    elsif ( IsStringWithData( $Param{FieldType} ) ) {
        $FieldType = $Param{FieldType};
    }

    my $ResultType = $Param{ResultType} || 'ARRAY';
    $ResultType = $ResultType eq 'HASH' ? 'HASH' : 'ARRAY';

    # get cache object
    my $CacheObject = $Kernel::OM->Get('Cache');

    my $CacheKey = 'DynamicFieldList::Valid::'
        . $Valid
        . '::ObjectType::'
        . $ObjectType
        . '::FieldType::'
        . $FieldType
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
            $Kernel::OM->Get('Log')->Log(
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
        my $DBObject = $Kernel::OM->Get('DB');

        if ($Valid) {

            # get valid object
            my $ValidObject = $Kernel::OM->Get('Valid');

            $SQL .= ' WHERE valid_id IN (' . join ', ', $ValidObject->ValidIDsGet() . ')';

            if ( $Param{ObjectType} ) {
                if (
                    IsStringWithData( $Param{ObjectType} )
                    && $Param{ObjectType} ne 'All'
                ) {
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

            if ( $Param{FieldType} ) {
                if (
                    IsStringWithData( $Param{FieldType} )
                    && $Param{FieldType} ne 'All'
                ) {
                    $SQL .=
                        " AND field_type = '"
                        . $DBObject->Quote( $Param{FieldType} ) . "'";
                }
                elsif ( IsArrayRefWithData( $Param{FieldType} ) ) {
                    my $FieldTypeString =
                        join ',',
                        map "'" . $DBObject->Quote($_) . "'",
                        @{ $Param{FieldType} };
                    $SQL .= " AND field_type IN ($FieldTypeString)";

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

            if ( $Param{FieldType} ) {
                if ( IsStringWithData( $Param{FieldType} ) && $Param{FieldType} ne 'All' ) {
                    $SQL .=
                        " WHERE field_type = '"
                        . $DBObject->Quote( $Param{FieldType} ) . "'";
                }
                elsif ( IsArrayRefWithData( $Param{FieldType} ) ) {
                    my $FieldTypeString =
                        join ',',
                        map "'" . $DBObject->Quote($_) . "'",
                        @{ $Param{FieldType} };
                    $SQL .= " WHERE field_type IN ($FieldTypeString)";
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
                $Kernel::OM->Get('Log')->Log(
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
                $Kernel::OM->Get('Log')->Log(
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
            ID              => 123,
            InternalField   => 0,
            Name            => 'nameforfield',
            Label           => 'The label to show',
            FieldType       => 'Text',
            ObjectType      => 'Article',
            Config          => $ConfigHashRef,
            CustomerVisible => 0,
            ValidID         => 1,
            CreateTime      => '2011-02-08 15:08:00',
            ChangeTime      => '2011-06-11 17:22:00',
        },
        {
            ID              => 321,
            InternalField   => 0,
            Name            => 'fieldname',
            Label           => 'It is not a label',
            FieldType       => 'Text',
            ObjectType      => 'Ticket',
            Config          => $ConfigHashRef,
            CustomerVisible => 0,
            ValidID         => 1,
            CreateTime      => '2010-09-11 10:08:00',
            ChangeTime      => '2011-01-01 01:01:01',
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
    my $CacheObject = $Kernel::OM->Get('Cache');
    my $CacheKeyJSON = $Kernel::OM->Get('JSON')->Encode(
        SortKeys => 1,
        Data     => {
            %Param,
            Valid      => $Valid,
            ObjectType => $ObjectType
        }
    );
    my $CacheKey = "DynamicFieldListGet::$CacheKeyJSON";
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
            $Kernel::OM->Get('Log')->Log(
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
    my $DBObject = $Kernel::OM->Get('DB');

    my @Data;
    my $SQL = 'SELECT id, name FROM dynamic_field WHERE ';
    my @SQLWhere;

    if ($Valid) {
        push (
            @SQLWhere,
            ' valid_id IN ('
                . join( q{, } , $Kernel::OM->Get('Valid')->ValidIDsGet())
                . q{)}
        );
    }

    if ( $Param{ObjectType} ) {
        if (
            IsStringWithData( $Param{ObjectType} )
            && $Param{ObjectType} ne 'All'
        ) {
            push (
                @SQLWhere,
                "object_type = '"
                    . $DBObject->Quote( $Param{ObjectType} )
                    . q{'}
            );
        }
        elsif ( IsArrayRefWithData( $Param{ObjectType} ) ) {
            my @ObjectTypes      = map { q{'} . $DBObject->Quote($_) . q{'} } @{ $Param{ObjectType}};
            my $ObjectTypeString = join( q{,}, @ObjectTypes);

            push (
                @SQLWhere,
                "object_type IN ($ObjectTypeString)"
            );
        }
    }

    if ( $Param{FieldType} ) {
        if (
            IsStringWithData( $Param{FieldType} )
            && $Param{FieldType} ne 'All'
        ) {
            push (
                @SQLWhere,
                "field_type = '"
                    . $DBObject->Quote( $Param{FieldType} )
                    . q{'}
            );
        }
        elsif ( IsArrayRefWithData( $Param{FieldType} ) ) {
            my @FieldTypes      =  map {q{'} . $DBObject->Quote($_) . q{'}} @{ $Param{FieldType} };
            my $FieldTypeString = join( q{,}, @FieldTypes );

            push (
                @SQLWhere,
                "field_type IN ($FieldTypeString)"
            );
        }
    }

    if ( @SQLWhere ) {
        $SQL .= join ( ' AND ', @SQLWhere );
    }
    else {
        $SQL .= ' 1=1 ';
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
        $Kernel::OM->Get('Log')->Log(
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
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
