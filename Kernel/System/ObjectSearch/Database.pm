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

Kernel::System::ObjectSearch::Database - ticket search lib

=head1 SYNOPSIS

All ticket search functions.

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $SearchBackendObject = $Kernel::OM->Get('ObjectSearch::Database');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # 0=off; 1=on;
    $Self->{Debug} = $Param{Debug} || 0;

    # check module
    my $ModuleStrg = 'Kernel::System::ObjectSearch::Database::' . $Param{ObjectType} . '::Base';
    if ( !$Kernel::OM->Get('Main')->Require($ModuleStrg) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message => "Can't load module $ModuleStrg",
        );
        return;    # bail out, this will generate 500 Error
    }

    $Self->{ObjectType}   = $Param{ObjectType};
    $Self->{SearchModule} = $Kernel::OM->Get($ModuleStrg);

    # load backend modules
    $Self->{AttributeModules} = $Self->{SearchModule}->GetBackends();

    return $Self;
}

=item Search()

To find objects in your system.

    my @ObjectIDs = $SearchObject->Search(
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

    @ObjectIDs = ( 1, 2, 3 );

Result: 'HASH'

    %ObjectIDs = (
        1 => '2010102700001',
        2 => '2010102700002',
        3 => '2010102700003',
    );

Result: 'COUNT'

    $ObjectIDs = 123;

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    my $Result = $Param{Result} || 'HASH';
    my $Limit  = $Param{Limit}  || q{};


    my $CacheKey = $Kernel::OM->Get('JSON')->Encode(
        Data     => {
            Search => $Param{Search} || {},
            Sort   => $Param{Sort}   || {},
            Result => $Result,
            Limit  => $Limit
        },
        ObjectType => $Param{ObjectType},
        SortKeys   => 1
    );

    my $CacheData = $Kernel::OM->Get('Cache')->Get(
        Type => "ObjectSearch_$Param{ObjectType}",
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

    # init attribute backend modules
    foreach my $SearchableAttribute ( sort keys %{$Self->{AttributeModules}} ) {
        $Self->{AttributeModules}->{$SearchableAttribute}->{Object}->Init();
    }

    # create basic SQL
    my $BaseSQL = $Self->{SearchModule}->BaseSQL();
    my $SQL = $BaseSQL->{Select};
    $SQLDef{SQLFrom}  = $BaseSQL->{From};
    $SQLDef{SQLWhere} = $BaseSQL->{Where};

    # check and set basic flags of object type
    $Self->{BaseFlags} = $Self->{SearchModule}->BaseFlags(
        %Param
    );

    # check permission if UserID given and prepare relevat part of SQL statement (not needed for user with id 1)
    if ($Param{UserID} && $Param{UserID} != 1) {
        my %PermissionSQL = $Self->_CreatePermissionSQL(
            %Param
        );
        if ( $PermissionSQL{From} ) {
            $SQLDef{SQLFrom} .= " $PermissionSQL{From}";
        }
        if ( $PermissionSQL{Where} ) {
            $SQLDef{SQLWhere} = " $PermissionSQL{Where}";
        }
    }

    # filter
    if ( IsHashRefWithData($Param{Search}) ) {
        my %Result = $Self->_CreateAttributeSQL(
            SQLPartsDef => \@SQLPartsDef,
            %Param,
        );
        if ( !%Result ) {
            # return in case of error
            return;
        }
        foreach my $SQLPart ( @SQLPartsDef ) {
            next if !$Result{$SQLPart->{Name}};
            $SQLDef{$SQLPart->{Name}} .= $SQLPart->{JoinBy}.$Result{$SQLPart->{Name}};
        }
    }

    # sorting
    if ( IsArrayRefWithData($Param{Sort}) ) {
        my %Result = $Self->_CreateOrderBySQL(
            Sort   => $Param{Sort},
            UserID => $Param{UserID}
        );
        if ( !IsHashRef(\%Result) ) {
            # return in case of error
            return;
        }

        if (IsArrayRefWithData($Result{OrderBy})) {
            if ( $SQLDef{SQLOrderBy} ) {
                $SQLDef{SQLOrderBy} .= q{, };
            }
            $SQLDef{SQLOrderBy} .= join(q{, }, @{$Result{OrderBy}});
        }
        if (IsArrayRefWithData($Result{Attrs})) {
            if ( $SQLDef{SQLAttrs} ) {
                $SQLDef{SQLAttrs} .= q{, };
            }
            $SQLDef{SQLAttrs}   .= join(q{, }, @{$Result{Attrs}});
        }
        if (IsArrayRefWithData($Result{Join})) {
            if ( $SQLDef{SQLJoin} ) {
                $SQLDef{SQLJoin} .= q{ };
            }
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
    my %Objects;
    my @ObjectIDs;
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL   => $SQL,
        Limit => $Param{Limit}
    );
print STDERR Data::Dumper::Dumper($SQL);
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        next if $Objects{ $Row[0] };
        push( @ObjectIDs, $Row[0] );
        $Objects{ $Row[0] } = $Row[1];
    }

    my $Count = scalar(@ObjectIDs);

    # return COUNT
    if ( $Result eq 'COUNT' ) {
        $Kernel::OM->Get('Cache')->Set(
            Type  => "ObjectSearch_$Param{ObjectType}",
            Key   => $CacheKey,
            Value => $Count,
            TTL   => $Param{CacheTTL} || 60 * 4,
        );
        return $Count;
    }

    # return HASH
    elsif ( $Result eq 'HASH' ) {
        $Kernel::OM->Get('Cache')->Set(
            Type  => "ObjectSearch_$Param{ObjectType}",
            Key   => $CacheKey,
            Value => \%Objects,
            TTL   => $Param{CacheTTL} || 60 * 4,
        );
        return %Objects;
    }

    # return ARRAY
    else {
        $Kernel::OM->Get('Cache')->Set(
            Type  => "ObjectSearch_$Param{ObjectType}",
            Key   => $CacheKey,
            Value => \@ObjectIDs,
            TTL   => $Param{CacheTTL} || 60 * 4,
        );
        return @ObjectIDs;
    }
}

=begin Internal:

=cut

=item _CreatePermissionSQL()

generate SQL for permission restrictions

    my %SQL = $Object->_CreatePermissionSQL(
        UserID    => ...,                    # required
        UserType  => 'Agent' | 'Customer'    # required
    );

=cut

sub _CreatePermissionSQL {
    my ( $Self, %Param ) = @_;

    return $Self->{SearchModule}->CreatePermissionSQL(
        %Param
    );
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
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need SQLPartsDef!',
        );
        return;
    }

    if ( !IsHashRefWithData($Param{Search}) ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'No Search definition given!',
        );
        return;
    }

    if ( !$Param{UserID} && !$Param{UserType} ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'No user information for attribute search!',
        );
        return;
    }

    # generate SQL from attribute modules
    foreach my $BoolOperator ( sort keys %{$Param{Search}} ) {
        if ( !IsArrayRefWithData($Param{Search}->{$BoolOperator}) ) {
            return if $Param{Silent};

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
            if ( !$Self->{AttributeModules}->{$Search->{Field}}->{IsSearchable} ) {
                # we don't have any directly registered handling module for this field, check if we have a handling module matching a pattern
                foreach my $SearchableAttribute ( sort keys %{$Self->{AttributeModules}} ) {

                    next if $Search->{Field} !~ /$SearchableAttribute/g;
                    next if !$Self->{AttributeModules}->{$SearchableAttribute}->{IsSearchable};

                    $AttributeModule = $Self->{AttributeModules}->{$SearchableAttribute}->{Object};
                    last;
                }
            }
            else {
                $AttributeModule = $Self->{AttributeModules}->{$Search->{Field}}->{Object};
            }

            # ignore this attribute if we don't have a module for it
            if ( !$AttributeModule ) {
                return if $Param{Silent};

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
                WholeSearch  => $Param{Search}->{$BoolOperator},   # forward "whole" search, e.g. if behavior depends on other attributes
                Silent       => $Param{Silent} || 0,
                Flags        => $Self->{BaseFlags}
            );

            if ( !IsHashRefWithData($Result) ) {
                return if $Param{Silent};

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
        if ( !$Self->{AttributeModules}->{$Attribute}->{IsSortable} ) {
            # we don't have any directly registered search module for this field, check if we have a search module matching a pattern
            foreach my $SortableAttribute ( sort keys %{$Self->{AttributeModules}} ) {
                next if $Attribute !~ /$SortableAttribute/g;
                next if !$Self->{AttributeModules}->{$SortableAttribute}->{IsSortable};
                $AttributeModule = $Self->{AttributeModules}->{$SortableAttribute}->{Object};
                last;
            }
        }
        else {
            $AttributeModule = $Self->{AttributeModules}->{$Attribute}->{Object};
        }

        # ignore this attribute if we don't have a module for it
        if ( !$AttributeModule ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to sort attribute. Don't know how to handle it!\n" . Data::Dumper::Dumper($SortDef),
            );
            return;
        }

        my $Language = $Kernel::OM->Get('User')->GetUserLanguage(
            UserID => $Param{UserID}
        ) || 'en';

        # execute attribute module to prepare SQL
        my $Result = $AttributeModule->Sort(
            Attribute => $Attribute,
            Language  => $Language,
            Flags     => $Self->{BaseFlags}
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
                push(  @OrderBy, $Element . q{ } . $Order);
            }
        }
    }

    return (
        Attrs   => \@AttrList,
        Join    => \@JoinList,
        OrderBy => \@OrderBy
    );
}

sub GetSupportedAttributes {
    my ( $Self, %Param) =  @_;

    return $Self->{SearchModule}->SupportedList();
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
