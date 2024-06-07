# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database - object search backend

=head1 SYNOPSIS

All object search backend functions.

=over 4

=cut

=item new()

Do not use it directly, instead configure 'ObjectSearch::Backend' to use Module 'ObjectSearch::Database'
and use ObjectSearch with its provided functions:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $ObjectSearch = $Kernel::OM->Get('ObjectSearch');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get registered object types
    my $RegisteredObjectTypes = $Kernel::OM->Get('Config')->Get('ObjectSearch::Database::ObjectType') || {};

    # prepare mapping for object type modules and normalized object type names
    $Self->{NormalizedObjectTypes} = {};
    $Self->{ObjectTypeModules}     = {};
    for my $ObjectType ( keys( %{ $RegisteredObjectTypes } ) ) {
        $Self->{NormalizedObjectTypes}->{ lc( $ObjectType ) } = $ObjectType;
        $Self->{ObjectTypeModules}->{ $ObjectType }           = $RegisteredObjectTypes->{ $ObjectType };
    }

    # init hash for used object backend
    $Self->{ObjectTypeBackends} = {};

    # set object search debug
    $Self->{Debug} = $Kernel::OM->Get('Config')->Get('ObjectSearch::Debug') || 0;

    return $Self;
}

=item NormalizedObjectType()

provides normalized name of object type
    my $ObjectType = $ObjectSearch->{Backend}->NormalizedObjectType(
        ObjectType => 'ticket',
    );

Returns:
    $ObjectType = 'Ticket'

=cut

sub NormalizedObjectType {
    my ( $Self, %Param ) = @_;

    # return value from normalized mapping
    return $Self->{NormalizedObjectTypes}->{ lc( $Param{ObjectType} ) };
}

=item Search()

search for objects in backend

    my %Result = $ObjectSearch->{Backend}->Search(
        ObjectType => 'Ticket',             # registered object type of this search backend
        Result     => 'HASH',               # Optional. Default: HASH; Possible values: HASH, ARRAY, COUNT
        Search     => { ... },              # Optional. HashRef with SearchParams
        Sort       => [ ... ],              # Optional. ArrayRef of hashes with SortParams
        Limit      => 100,                  # Optional. Limit provided resultes. Use '0' to search without limit
        CacheTTL   => 60,                   # Optional. Default: 240; Time is seconds the result will be cached. Use '0' if result should not be cached.
        Language   => 'de',                 # Optional. Default: en; Language used for sorting of several attributes
        UserType   => 'Agent',              # type of requesting user. Used for permission checks. Agent or Customer
        UserID     => 1,                    # ID of requesting user. Used for permission checks
    );

SearchParams:
    Search => {
        AND => [        # optional, if not given, OR must be used
            {
                Field    => '...',      # see list of filterable fields
                Operator => '...'       # see list of filterable fields
                Value    => ...         # see list of filterable fields
            },
            ...
        ]
        OR => [         # optional, if not given, AND must be used
            ...         # structure of field filter identical to AND
        ]
    }

SortParams:
    Sort => [
        {
            Field => '...',                              # see list of filterable fields
            Direction => 'ascending' || 'descending'
        },
        ...
    ]

Returns:
    Result HASH
    %Result = (
        1 => 123,
        2 => 456
    )

    Result ARRAY
    @Result = (
        1,
        2
    )

    Result COUNT
    $Result = 2

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    # get relevant object type backend
    my $ObjectTypeBackend;
    if ( $Self->{ObjectTypeBackends}->{ $Param{ObjectType} } ) {
        $ObjectTypeBackend = $Self->{ObjectTypeBackends}->{ $Param{ObjectType} };
    }
    else {
        # create backend object
        $ObjectTypeBackend = $Self->_GetObjectTypeBackend(
            ObjectType => $Param{ObjectType}
        );
    }
    return if ( !$ObjectTypeBackend );

    # init relative flag
    my $IsRelative;

    # prepare sql defintion
    my $SQLDef = $Self->_PrepareSQLDef(
        Backend  => $ObjectTypeBackend,
        Search   => $Param{Search},
        Sort     => $Param{Sort},
        Language => $Param{Language},
        UserType => $Param{UserType},
        UserID   => $Param{UserID},
        Silent   => $Param{Silent}
    );
    return if ( ref( $SQLDef ) ne 'HASH' );

    $IsRelative = delete( $SQLDef->{IsRelative} );

    # generate SQL statement
    my $SQL = $Self->_PrepareSQLStatement(
        SQLDef => $SQLDef,
        Silent => $Param{Silent}
    );
    return if ( !$SQL );

    if ( $Self->{Debug} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'debug',
            Message  => <<"END"
ObjectSearch SQL-Statement: $SQL
END
        );
    }

    # prepare database query
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL => $SQL
    );

    my %Objects;
    my @ObjectIDs;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        next if $Objects{ $Row[0] };
        push( @ObjectIDs, $Row[0] );
        $Objects{ $Row[0] } = $Row[1];

        last if (
            $Param{Limit}
            && $Param{Limit} == scalar( @ObjectIDs )
        );
    }

    # return COUNT
    if ( $Param{Result} eq 'COUNT' ) {
        return ( scalar(@ObjectIDs), $IsRelative );
    }
    # return HASH
    elsif ( $Param{Result} eq 'HASH' ) {
        return ( \%Objects, $IsRelative );
    }
    # return ARRAY
    else {
        return ( \@ObjectIDs, $IsRelative );
    }
}

=item GetSupportedAttributes()

get supported attributes for a given object type

    my $Result = $ObjectSearch->{Backend}->GetSupportedAttributes(
        ObjectType => 'Ticket',             # registered object type of this search backend
    );

Returns:
    $Result = [
        {
            ObjectType      => 'Ticket',
            Property        => 'TicketID,
            ObjectSpecifics => undef,
            IsSearchable    => 1,
            IsSortable      => 1,
            Operators       => [
                'EQ','IN','!IN','NE','LT','LTE','GT','GTE'
            ]
        },
        ...
    ]

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param) =  @_;

    # get relevant object type backend
    my $ObjectTypeBackend;
    if ( $Self->{ObjectTypeBackends}->{ $Param{ObjectType} } ) {
        $ObjectTypeBackend = $Self->{ObjectTypeBackends}->{ $Param{ObjectType} };
    }
    else {
        # create backend object
        $ObjectTypeBackend = $Self->_GetObjectTypeBackend(
            ObjectType => $Param{ObjectType}
        );
    }

    return $ObjectTypeBackend->GetSupportedAttributes();
}

=begin Internal:

=cut



=item _GetObjectTypeBackend()

### TODO ###

=cut

sub _GetObjectTypeBackend {
    my ( $Self, %Param ) = @_;

    # get module name
    my $ObjectTypeModule = $Kernel::OM->GetModuleFor( $Self->{ObjectTypeModules}->{ $Param{ObjectType} }->{Module} )
        || $Self->{ObjectTypeModules}->{ $Param{ObjectType} }->{Module};

    # require module
    return if ( !$Kernel::OM->Get('Main')->Require( $ObjectTypeModule ) );

    # create backend object
    $Self->{ObjectTypeBackends}->{ $Param{ObjectType} } = $ObjectTypeModule->new(
        %{ $Self },
        ObjectType => $Param{ObjectType}
    );

    # return object type backend
    return $Self->{ObjectTypeBackends}->{ $Param{ObjectType} };
}

=item _PrepareSQLDef()

### TODO ###

=cut

sub _PrepareSQLDef {
    my ( $Self, %Param ) = @_;

    # init sql def hash
    my %SQLDef = (
        Select     => [],
        From       => [],
        Join       => [],
        Where      => [],
        GroupBy    => [],
        Having     => [],
        OrderBy    => [],
        IsRelative => 0
    );

    # init flags
    my %Flags = ();

    # init backend
    my $InitSuccess = $Param{Backend}->Init(
        %Param,
        Flags => \%Flags
    );
    return if ( !$InitSuccess );

    # get base def from backend
    my $BaseDef = $Param{Backend}->GetBaseDef(
        %Param,
        Flags => \%Flags
    );
    return if ( ref( $BaseDef ) ne 'HASH' );

    # add base def to sql def
    my $BaseOrderBy;
    for my $Key ( keys %{ $BaseDef } ) {
        # remember OrderBy of base in separate variable
        if ( $Key eq 'OrderBy' ) {
            $BaseOrderBy = $BaseDef->{ $Key };
        }
        else {
            push( @{ $SQLDef{ $Key } }, @{ $BaseDef->{ $Key } } );
        }
    }

    # check permission if UserID given and prepare relevant part of SQL statement (not needed for user with id 1)
    if ( $Param{UserID} != 1 ) {
        # get permission def from backend
        my $PermissionDef = $Param{Backend}->GetPermissionDef(
            %Param,
            Flags => \%Flags
        );
        return if ( ref( $PermissionDef ) ne 'HASH' );

        # add permission def to sql def
        for my $Key ( keys %{ $PermissionDef } ) {
            push( @{ $SQLDef{ $Key } }, @{ $PermissionDef->{ $Key } } );
        }
    }

    # check if search parameter has data
    if ( IsHashRefWithData( $Param{Search} ) ) {
        # get search def from backend
        my $SearchDef = $Param{Backend}->GetSearchDef(
            %Param,
            Flags => \%Flags
        );
        return if ( ref( $SearchDef ) ne 'HASH' );

        # add search def to sql def
        for my $Key ( keys %{ $SearchDef } ) {
            if ( $Key eq 'IsRelative' ) {
                if ( $SearchDef->{ $Key } ) {
                    $SQLDef{ $Key } = $SearchDef->{ $Key };
                }
            }
            else {
                push( @{ $SQLDef{ $Key } }, @{ $SearchDef->{ $Key } } );
            }
        }
    }

    # check if sort parameter has data
    if ( IsArrayRefWithData( $Param{Sort} ) ) {
        # get sort def from backend
        my $SortDef = $Param{Backend}->GetSortDef(
            %Param,
            Flags => \%Flags
        );
        return if ( ref( $SortDef ) ne 'HASH' );

        # add sort def to sql def
        for my $Key ( keys %{ $SortDef } ) {
            push( @{ $SQLDef{ $Key } }, @{ $SortDef->{ $Key } } );
        }
    }

    # add OrderBy from base
    if ( IsArrayRefWithData( $BaseOrderBy ) ) {
        push( @{ $SQLDef{OrderBy} }, @{ $BaseOrderBy } );
    }

    # make sure every field is only sorted in one direction
    my @OrderByList   = ();
    my %OrderByFields = ();
    for my $OrderByEntry ( @{ $SQLDef{OrderBy} } ) {
        # split entry in field and direction
        my ($OrderByField, $OrderByDirection) = split( ' ', $OrderByEntry );

        # skip known fields
        next if ( $OrderByFields{ $OrderByField } );

        # add entry to list
        push( @OrderByList, $OrderByEntry );

        # remember field
        $OrderByFields{ $OrderByField } = 1;
    }
    $SQLDef{OrderBy} = \@OrderByList;

    # return ref of result
    return \%SQLDef;
}

=item _PrepareSQLStatement()

### TODO ###

=cut

sub _PrepareSQLStatement {
    my ( $Self, %Param ) = @_;

    # the parts or SQL is comprised of
    my @SQLPartsDef = (
        {
            Name        => 'Select',
            BeginWith   => 'SELECT ',
            JoinBy      => q{, },
            JoinPreFix  => q{},
            JoinPostFix => q{},
            Required    => 1,
        },
        {
            Name        => 'From',
            BeginWith   => 'FROM ',
            JoinBy      => q{, },
            JoinPreFix  => q{},
            JoinPostFix => q{},
            Required    => 1,
        },
        {
            Name        => 'Join',
            BeginWith   => q{},
            JoinBy      => q{ },
            JoinPreFix  => q{},
            JoinPostFix => q{},
            Required    => 0,
        },
        {
            Name        => 'Where',
            BeginWith   => 'WHERE ',
            JoinBy      => ' AND ',
            JoinPreFix  => q{(},
            JoinPostFix => q{)},
            Required    => 0,
        },
        {
            Name        => 'GroupBy',
            BeginWith   => 'GROUP BY ',
            JoinBy      => q{, },
            JoinPreFix  => q{},
            JoinPostFix => q{},
            Required    => 0,
        },
        {
            Name        => 'Having',
            BeginWith   => 'HAVING ',
            JoinBy      => ' AND ',
            JoinPreFix  => q{(},
            JoinPostFix => q{)},
            Required    => 0,
        },
        {
            Name        => 'OrderBy',
            BeginWith   => 'ORDER BY ',
            JoinBy      => q{, },
            JoinPreFix  => q{},
            JoinPostFix => q{},
            Required    => 0,
        },
    );

    my $SQL = q{};
    for my $SQLPart ( @SQLPartsDef ) {
        if (
            ref( $Param{SQLDef}->{ $SQLPart->{Name} } ) ne 'ARRAY'
            || !@{ $Param{SQLDef}->{ $SQLPart->{Name} } }
        ) {
            if ( $SQLPart->{Required} ) {
                if ( !$Param{Silent} ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => 'Missing required sql part "' . $SQLPart->{Name} . q{"!},
                    );
                }
                return;
            }
            else {
                next;
            }
        }

        if ( $SQL ) {
            $SQL .= q{ };
        }

        $SQL .= $SQLPart->{BeginWith}
            . $SQLPart->{JoinPreFix}
            . join( $SQLPart->{JoinBy}, $Kernel::OM->Get('Main')->GetUnique( @{ $Param{SQLDef}->{ $SQLPart->{Name} } } ) )
            . $SQLPart->{JoinPostFix};
    }

    return $SQL;
}

1;

=end Internal:



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
