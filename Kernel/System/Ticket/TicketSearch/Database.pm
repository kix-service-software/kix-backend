# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Ticket::TicketSearch::Database;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::Ticket::TicketSearch::Database - ticket search lib

=head1 SYNOPSIS

All ticket search functions.

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $SearchBackendObject = $Kernel::OM->Get('Ticket::TicketSearch::Database');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # 0=off; 1=on;
    $Self->{Debug} = $Param{Debug} || 0;

    # get needed objects
    my $ConfigObject  = $Kernel::OM->Get('Config');
    my $MainObject    = $Kernel::OM->Get('Main');
    $Self->{DBObject} = $Kernel::OM->Get('DB');

    # load backend modules
    my $Backends = $ConfigObject->Get('TicketSearch::Database::Module');

    if ( !IsHashRefWithData($Backends) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No database search backend modules found!",
        );
        return;
    }

    BACKEND:
    foreach my $Backend ( sort keys %{$Backends} ) {

        my $Object = $Kernel::OM->Get($Backends->{$Backend}->{Module});

        # register module for each supported attribute
        my $SupportedAttributes = $Object->GetSupportedAttributes();
        if ( !IsHashRefWithData($SupportedAttributes) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "SupportedAttributes return by module $Backends->{$Backend}->{Module} are not a HashRef!",
            );
            next BACKEND;
        }

        foreach my $Type ( qw(Search Sort) ) {
            if ( ref($SupportedAttributes->{$Type}) ne 'ARRAY' ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "SupportedAttributes->{$Type} return by module $Backends->{$Backend}->{Module} is not an ArrayRef!",
                );
                next BACKEND;
            }
            foreach my $Attribute ( @{$SupportedAttributes->{$Type}} ) {
                $Self->{AttributeModules}->{$Type}->{$Attribute} = $Object;
            }
        }
    }

    return $Self;
}

=item TicketSearch()

To find tickets in your system.

    my @TicketIDs = $TicketObject->TicketSearch(
        # result (required)
        Result => 'ARRAY' || 'HASH' || 'COUNT',

        # result limit
        Limit => 100,

        # the search params
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
        },

        # sort option
        Sort => [
            {
                Field => '...',                              # see list of filterable fields
                Direction => 'ascending' || 'descending'
            },
            ...
        ]

        # user search (UserID and UserType are required)
        UserID     => 123,
        UserType   => 'Agent' || 'Customer',
        Permission => 'ro' || 'rw',

        # CacheTTL, cache search result in seconds (optional)
        CacheTTL => 60 * 15,
    );

Filterable fields and possible operators, values and sortablility:
    => see manual of REST API

Returns:

Result: 'ARRAY'

    @TicketIDs = ( 1, 2, 3 );

Result: 'HASH'

    %TicketIDs = (
        1 => '2010102700001',
        2 => '2010102700002',
        3 => '2010102700003',
    );

Result: 'COUNT'

    $TicketIDs = 123;

=cut

sub TicketSearch {
    my ( $Self, %Param ) = @_;

    my @TicketIDs = $Self->_TicketSearch(
        %Param
    );

    return if !@TicketIDs;

    return $Self->_TicketSort(
        %Param,
        TicketIDs => \@TicketIDs
    );
}

=begin Internal:

=cut

sub _TicketSearch {
    my ( $Self, %Param ) = @_;

    my $CacheKey = $Kernel::OM->Get('JSON')->Encode(
        Data     => $Param{Search} || {},
        SortKeys => 1
    );

    my $CacheData = $Kernel::OM->Get('Cache')->Get(
        Type => 'TicketSearch',
        Key  => $CacheKey,
    );

    if ( defined $CacheData ) {
        if ( ref $CacheData eq 'ARRAY' ) {
            return @{$CacheData};
        }
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Invalid ref ' . ref($CacheData) . q{!}
        );
        return;
    }

    # the parts or SQL is comprised of
    my @SQLPartsDef = (
        {
            Name        => 'SQLAttrs',
            JoinBy      => q{, },
            JoinPreFix  => q{},
            JoinPostFix => q{},
            BeginWith   => q{,}
        },
        {
            Name        => 'SQLFrom',
            JoinBy      => q{, },
            JoinPreFix  => q{},
            JoinPostFix => q{},
        },
        {
            Name        => 'SQLJoin',
            JoinBy      => q{ },
            JoinPreFix  => q{},
            JoinPostFix => q{},
        },
        {
            Name        => 'SQLWhere',
            JoinBy      => ' AND ',
            JoinPreFix  => q{(},
            JoinPostFix => q{)},
            BeginWith   => 'WHERE'
        },
    );

    # empty SQL definition
    my %SQLDef = (
        SQLAttrs   => q{},
        SQLFrom    => q{},
        SQLJoin    => q{},
        SQLWhere   => q{},
    );

    if ( !$Param{UserType} ) {
        $Param{UserType} = 'Agent';
    }

    # init attribute backend modules
    foreach my $SearchableAttribute ( sort keys %{$Self->{AttributeModules}->{Search}} ) {
        $Self->{AttributeModules}->{Search}->{$SearchableAttribute}->Init();
    }

    # create basic SQL
    my $SQL = 'SELECT st.id';
    $SQLDef{SQLFrom}  = 'FROM ticket st';

    # check permission if UserID given and prepare relevat part of SQL statement (not needed for user with id 1)
    my $SQLWhere = ' 1=1 ';
    if (
        $Param{UserID}
        && $Param{UserID} != 1
    ) {
        my %PermissionSQL = $Self->_CreatePermissionSQL(
            %Param
        );
        if ( $PermissionSQL{From} ) {
            $SQLDef{SQLFrom} .= " $PermissionSQL{From}";
        }
        if ( $PermissionSQL{Where} ) {
            $SQLWhere = " $PermissionSQL{Where}";
        }
    }
    $SQLDef{SQLWhere} .= $SQLWhere;

    # filter
    if ( IsHashRefWithData($Param{Search}) ) {
        my %Result = $Self->_CreateAttributeSQL(
            SQLPartsDef => \@SQLPartsDef,
            %Param,
        );

        # return in case of error
        return if ( !%Result );

        foreach my $SQLPart ( @SQLPartsDef ) {
            next if !$Result{$SQLPart->{Name}};
            $SQLDef{$SQLPart->{Name}} .= $SQLPart->{JoinBy}
                . $Result{$SQLPart->{Name}};
        }
    }

    # generate SQL
    foreach my $SQLPart ( @SQLPartsDef ) {
        next if !$SQLDef{$SQLPart->{Name}};
        $SQL .= q{ }
            . ($SQLPart->{BeginWith} || q{})
            . q{ }
            . $SQLDef{$SQLPart->{Name}};
    }

    # database query
    return if !$Self->{DBObject}->Prepare(
        SQL => $SQL
    );

    my %Tickets;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $Tickets{$Row[0]} = 1;
    }

    my @TicketIDs = sort {$a <=> $b} keys %Tickets;

    $Kernel::OM->Get('Cache')->Set(
        Type  => 'TicketSearch',
        Key   => $CacheKey,
        Value => \@TicketIDs,
        TTL   => $Param{CacheTTL} || 60 * 4,
    );

    return @TicketIDs;
}

sub _TicketSort {
    my ( $Self, %Param ) = @_;

    my $Result = $Param{Result} || 'HASH';
    my $Limit  = $Param{Limit}  || q{};

    # check cache
    my $CacheKey  = $Kernel::OM->Get('JSON')->Encode(
        Data    => {
            TicketIDs => $Param{TicketIDs} || [],
            Sort      => $Param{Sort}      || {},
            Limit     => $Limit,
            Result    => $Result
        },
        SortKeys => 1
    );

    my $CacheData = $Kernel::OM->Get('Cache')->Get(
        Type => 'TicketSearch',
        Key  => $CacheKey,
    );

    if ( defined $CacheData ) {
        if ( ref $CacheData eq 'HASH' ) {
            return %{$CacheData};
        }
        elsif ( ref $CacheData eq 'ARRAY' ) {
            return @{$CacheData};
        }
        elsif ( ref $CacheData eq q{} ) {
            return $CacheData;
        }
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Invalid ref ' . ref($CacheData) . q{!}
        );
        return;
    }

    # the parts or SQL is comprised of
    my @SQLPartsDef = (
        {
            Name        => 'SQLAttrs',
            JoinBy      => q{, },
            JoinPreFix  => q{},
            JoinPostFix => q{},
            BeginWith   => q{,}
        },
        {
            Name        => 'SQLFrom',
            JoinBy      => q{, },
            JoinPreFix  => q{},
            JoinPostFix => q{},
        },
        {
            Name        => 'SQLJoin',
            JoinBy      => q{ },
            JoinPreFix  => q{},
            JoinPostFix => q{},
        },
        {
            Name        => 'SQLWhere',
            JoinBy      => ' AND ',
            JoinPreFix  => q{(},
            JoinPostFix => q{)},
            BeginWith   => 'WHERE'
        },
        {
            Name        => 'SQLOrderBy',
            JoinBy      => q{, },
            JoinPreFix  => q{},
            JoinPostFix => q{},
            BeginWith   => 'ORDER BY'
        },
    );

    # empty SQL definition
    my %SQLDef = (
        SQLAttrs   => q{},
        SQLFrom    => q{},
        SQLJoin    => q{},
        SQLWhere   => q{},
        SQLOrderBy => q{},
    );

    if ( !$Param{UserType} ) {
        $Param{UserType} = 'Agent';
    }
    # create basic SQL
    my $SQL = 'SELECT st.id, st.tn';
    $SQLDef{SQLFrom}  = 'FROM ticket st';
    $SQLDef{SQLJoin} .= ' INNER JOIN unnest(ARRAY['
        . join( q{,}, @{$Param{TicketIDs}} )
        . ']) AS tid ON tid = st.id';

    # sorting
    if ( IsArrayRefWithData($Param{Sort}) ) {
        my %Result = $Self->_CreateOrderBySQL(
            Sort => $Param{Sort}
        );

        # return in case of error
        return if ( !IsHashRef(\%Result) );

        if (IsArrayRefWithData($Result{OrderBy})) {
            $SQLDef{SQLOrderBy} .= join(q{, }, @{$Result{OrderBy}});
        }
        if (IsArrayRefWithData($Result{Attrs})) {
            $SQLDef{SQLAttrs}   .= join(q{, }, @{$Result{Attrs}});
        }
        if (IsArrayRefWithData($Result{Join})) {
            $SQLDef{SQLJoin}    .= join(q{ }, @{$Result{Join}});
        }
    }

    # generate SQL
    foreach my $SQLPart ( @SQLPartsDef ) {
        next if !$SQLDef{$SQLPart->{Name}};
        $SQL .= q{ }
            . ($SQLPart->{BeginWith} || q{})
            . q{ }
            . $SQLDef{$SQLPart->{Name}};
    }

    # database query
    my %Tickets;
    my @TicketIDs;
    return if !$Self->{DBObject}->Prepare(
        SQL   => $SQL,
        Limit => $Limit
    );

    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        next if ($Tickets{ $Row[0] });
        $Tickets{ $Row[0] } = $Row[1];
        push( @TicketIDs, $Row[0] );
    }

    my $Count = scalar(@TicketIDs);

    # return COUNT
    if ( $Result eq 'COUNT' ) {
        $Kernel::OM->Get('Cache')->Set(
            Type  => 'TicketSearch',
            Key   => $CacheKey,
            Value => $Count,
            TTL   => $Param{CacheTTL} || 60 * 4,
        );
        return $Count;
    }

    # return HASH
    elsif ( $Result eq 'HASH' ) {
        $Kernel::OM->Get('Cache')->Set(
            Type  => 'TicketSearch',
            Key   => $CacheKey,
            Value => \%Tickets,
            TTL   => $Param{CacheTTL} || 60 * 4,
        );
        return %Tickets;
    }

    # return ARRAY
    else {
        $Kernel::OM->Get('Cache')->Set(
            Type  => 'TicketSearch',
            Key   => $CacheKey,
            Value => \@TicketIDs,
            TTL   => $Param{CacheTTL} || 60 * 4,
        );
        return @TicketIDs;
    }
}

=item _CreatePermissionSQL()

generate SQL for permission restrictions

    my %SQL = $Object->_CreatePermissionSQL(
        UserID    => ...,                    # required
        UserType  => 'Agent' | 'Customer'    # required
    );

=cut

sub _CreatePermissionSQL {
    my ( $Self, %Param ) = @_;
    my %Result;

    if ( !$Param{UserID} || !$Param{UserType} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'No user information for permission check!',
        );
        return;
    }

    my $QueueIDs = $Kernel::OM->Get('Ticket')->BasePermissionRelevantObjectIDList(
        %Param,
        Types        => ['Base::Ticket'],
        UsageContext => $Param{UserType},
        Permission   => 'READ',
    );

    if ( IsArrayRef($QueueIDs) ) {
        $Result{From}  = 'INNER JOIN queue q ON q.id = st.queue_id ';
        $Result{Where} = 'q.id IN (' . join(q{,}, @{$QueueIDs}) . q{)};
    }

    return %Result;
}

=item _CreateAttributeSQL()

generate SQL for attribute filtering

    my $SQLWhere = $Object->_CreateAttributeSQL(
        SQLPartsDef => []                      # required
        Search      => {},                     # required
        UserID      => ...,                    # required
        UserType    => 'Agent' | 'Customer'    # required
    );

=cut

sub _CreateAttributeSQL {
    my ( $Self, %Param ) = @_;
    my %SQLDef;

    if ( !IsArrayRefWithData($Param{SQLPartsDef}) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need SQLPartsDef!',
        );
        return;
    }

    if ( !IsHashRefWithData($Param{Search}) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'No Search definition given!',
        );
        return;
    }

    if ( !$Param{UserID} && !$Param{UserType} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'No user information for attribute search!',
        );
        return;
    }

    # generate SQL from attribute modules
    foreach my $BoolOperator ( keys %{$Param{Search}} ) {
        if ( !IsArrayRefWithData($Param{Search}->{$BoolOperator}) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Invalid Search for $BoolOperator!",
            );
            return;
        }

        my %SQLDefBoolOperator;

        foreach my $Search ( @{$Param{Search}->{$BoolOperator}} ) {
            my $AttributeModule;

            # check if we have a handling module for this field
            if ( !$Self->{AttributeModules}->{Search}->{$Search->{Field}} ) {
                # we don't have any directly registered handling module for this field, check if we have a handling module matching a pattern
                foreach my $SearchableAttribute ( sort keys %{$Self->{AttributeModules}->{Search}} ) {
                    next if $Search->{Field} !~ /$SearchableAttribute/g;
                    $AttributeModule = $Self->{AttributeModules}->{Search}->{$SearchableAttribute};
                    last;
                }
            }
            else {
                $AttributeModule = $Self->{AttributeModules}->{Search}->{$Search->{Field}};
            }

            # ignore this attribute if we don't have a module for it
            if ( !$AttributeModule ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unable to search for attribute $Search->{Field}. Don't know how to handle it!",
                );
                return;
            }

            # execute attribute module to prepare SQL
            my $Result = $AttributeModule->Search(
                UserID       => $Param{UserID},
                UserType     => $Param{UserType},
                BoolOperator => $BoolOperator,
                Search       => $Search,
                WholeSearch  => $Param{Search}->{$BoolOperator}   # forward "whole" search, e.g. if behavior depends on other attributes
            );

            if ( !IsHashRefWithData($Result) ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Attribute module for $Search->{Field} returned an error!",
                );
                return;
            }

            foreach my $SQLPart ( @{$Param{SQLPartsDef}} ) {
                next if !IsArrayRefWithData($Result->{$SQLPart->{Name}});

                # add each entry to the corresponding SQL part
                if ( !IsArrayRefWithData($SQLDefBoolOperator{$SQLPart->{Name}}) ) {
                    $SQLDefBoolOperator{$SQLPart->{Name}} = [];
                }

                # join the parts
                $SQLDefBoolOperator{$SQLPart->{Name}} = [
                    @{$SQLDefBoolOperator{$SQLPart->{Name}}},
                    @{$Result->{$SQLPart->{Name}}},
                ];
            }
        }

        foreach my $SQLPart ( @{$Param{SQLPartsDef}} ) {
            next if !IsArrayRefWithData($SQLDefBoolOperator{$SQLPart->{Name}});

            # add each entry to the corresponding SQL part
            if ( $SQLDef{$SQLPart->{Name}} ) {
                $SQLDef{$SQLPart->{Name}} .= $SQLPart->{JoinBy};
            }
            my $JoinOperator = q{ };
            if ( $SQLPart->{Name} eq 'SQLWhere' ) {
                $JoinOperator = " $BoolOperator "
            }
            $SQLDef{$SQLPart->{Name}} .= $SQLPart->{JoinPreFix}.(join($JoinOperator, @{$SQLDefBoolOperator{$SQLPart->{Name}}})).$SQLPart->{JoinPostFix};
        }
    }

    return %SQLDef;
}

=item _CreateOrderBySQL()

generate SQL for ordering

    my $SQLWhere = $Object->_CreateOrderBySQL(
        Sort => [],     # required
    );

=cut

sub _CreateOrderBySQL {
    my ( $Self, %Param ) = @_;

    if ( !IsArrayRefWithData($Param{Sort}) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'No Sort definition given!',
        );
        return;
    }

    my @OrderBy;
    my @AttrList;
    my @JoinList;
    foreach my $SortDef ( @{$Param{Sort}} ) {

        my $Attribute = $SortDef->{Field};

        # check if we have a handling module for this field in case of sorting
        my $AttributeModule;
        if ( !$Self->{AttributeModules}->{Sort}->{$Attribute} ) {
            # we don't have any directly registered search module for this field, check if we have a search module matching a pattern
            foreach my $SortableAttribute ( sort keys %{$Self->{AttributeModules}->{Sort}} ) {
                next if $Attribute !~ /$SortableAttribute/g;
                $AttributeModule = $Self->{AttributeModules}->{Sort}->{$SortableAttribute};
                last;
            }
        }
        else {
            $AttributeModule = $Self->{AttributeModules}->{Sort}->{$Attribute};
        }

        # ignore this attribute if we don't have a module for it
        if ( !$AttributeModule ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to sort attribute. Don't know how to handle it!\n" . Data::Dumper::Dumper($SortDef),
            );
            return;
        }

        # execute attribute module to prepare SQL
        my $Result = $AttributeModule->Sort(
            Attribute => $Attribute
        );

        if ( !IsHashRefWithData($Result) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Attribute module for sort returned an error!\n" . Data::Dumper::Dumper($SortDef),
            );
            return;
        }

        if ( IsArrayRefWithData($Result->{SQLAttrs}) ) {
            push( @AttrList, @{$Result->{SQLAttrs}} )
        }
        if ( IsArrayRefWithData($Result->{SQLJoin}) ) {
            push( @JoinList, @{$Result->{SQLJoin}} )
        }
        if ( IsArrayRefWithData($Result->{SQLOrderBy}) ) {
            my $Order = 'ASC';
            if ( uc($SortDef->{Direction}) eq 'DESCENDING' ) {
                $Order = 'DESC';
            }

            if ( $Result->{OrderBySwitch} ) {
                $Order = $Order eq 'ASC' ? 'DESC' : 'ASC';
            }

            foreach my $Element ( @{$Result->{SQLOrderBy}} ) {
                push(  @OrderBy, $Element.q{ }.$Order);
            }
        }
    }

    return (
        Attrs   => \@AttrList,
        Join    => \@JoinList,
        OrderBy => \@OrderBy
    );
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
