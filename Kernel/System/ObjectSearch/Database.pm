# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
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

Kernel::System::ObjectSearch::Database - ### TODO ###

=head1 SYNOPSIS

### TODO ###

=over 4

=cut

=item new()

### TODO ###

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

    return $Self;
}

=item NormalizedObjectType()

### TODO ###

=cut

sub NormalizedObjectType {
    my ( $Self, %Param ) = @_;

    # return value from normalized mapping
    return $Self->{NormalizedObjectTypes}->{ lc( $Param{ObjectType} ) };
}

=item Search()

### TODO ###

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

    # prepare sql defintion
    my $SQLDef = $Self->_PrepareSQLDef(
        Backend  => $ObjectTypeBackend,
        Search   => $Param{Search},
        Sort     => $Param{Sort},
        UserType => $Param{UserType},
        UserID   => $Param{UserID},
        Silent   => $Param{Silent}
    );
    return if ( ref( $SQLDef ) ne 'HASH' );

    # generate SQL statement
    my $SQL = $Self->_PrepareSQLStatement(
        SQLDef => $SQLDef,
        Silent => $Param{Silent}
    );
    return if ( !$SQL );

    # prepare database query
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL   => $SQL,
        Limit => $Param{Limit}
    );

    my %Objects;
    my @ObjectIDs;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        next if $Objects{ $Row[0] };
        push( @ObjectIDs, $Row[0] );
        $Objects{ $Row[0] } = $Row[1];
    }

    # return COUNT
    if ( $Param{Result} eq 'COUNT' ) {
        return scalar(@ObjectIDs);
    }
    # return HASH
    elsif ( $Param{Result} eq 'HASH' ) {
        return \%Objects;
    }
    # return ARRAY
    else {
        return \@ObjectIDs;
    }
}

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



=item _PrepareSQLDef()

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
        Select  => [],
        From    => [],
        Join    => [],
        Where   => [],
        OrderBy => []
    );

    # init backend
    my $InitSuccess = $Param{Backend}->Init(
        %Param
    );
    return if ( !$InitSuccess );

    # get base def from backend
    my $BaseDef = $Param{Backend}->GetBaseDef(
        %Param
    );
    return if ( ref( $BaseDef ) ne 'HASH' );

    # add base def to sql def
    for my $Key ( keys %{ $BaseDef } ) {
        push( @{ $SQLDef{ $Key } }, @{ $BaseDef->{ $Key } } );
    }

    # check permission if UserID given and prepare relevant part of SQL statement (not needed for user with id 1)
    if ( $Param{UserID} != 1 ) {
        # get permission def from backend
        my $PermissionDef = $Self->GetPermissionDef(
            %Param
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
            %Param
        );
        return if ( ref( $SearchDef ) ne 'HASH' );

        # add search def to sql def
        for my $Key ( keys %{ $SearchDef } ) {
            push( @{ $SQLDef{ $Key } }, @{ $SearchDef->{ $Key } } );
        }
    }

    # check if search parameter has data
    if ( IsArrayRefWithData( $Param{Sort} ) ) {
        # get sort def from backend
        my $SortDef = $Param{Backend}->GetSortDef(
            %Param
        );
        return if ( ref( $SortDef ) ne 'HASH' );

        # add sort def to sql def
        for my $Key ( keys %{ $SortDef } ) {
            push( @{ $SQLDef{ $Key } }, @{ $SortDef->{ $Key } } );
        }
    }

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
            BeginWith   => 'SELECT',
            JoinBy      => q{, },
            JoinPreFix  => q{},
            JoinPostFix => q{},
            Required    => 1,
        },
        {
            Name        => 'From',
            BeginWith   => 'FROM',
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
            BeginWith   => 'WHERE',
            JoinBy      => ' AND ',
            JoinPreFix  => q{(},
            JoinPostFix => q{)},
            Required    => 0,
        },
        {
            Name        => 'OrderBy',
            BeginWith   => 'ORDER BY',
            JoinBy      => q{, },
            JoinPreFix  => q{},
            JoinPostFix => q{},
            Required    => 0,
        },
    );

    my $SQL = '';
    for my $SQLPart ( @SQLPartsDef ) {
        if (
            ref( $Param{SQLDef}->{ $SQLPart->{Name} } ) ne 'ARRAY'
            || !@{ $Param{SQLDef}->{ $SQLPart->{Name} } }
        ) {
            if ( $SQLPart->{Required} ) {
                if ( !$Param{Silent} ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => 'Missing required sql part "' . $SQLPart->{Name} . '"!',
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
            . q{ }
            . $SQLPart->{JoinPreFix}
            . join( $SQLPart->{JoinBy}, @{ $Param{SQLDef}->{ $SQLPart->{Name} } } )
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
