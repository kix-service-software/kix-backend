# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ObjectSearch;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Cache
    Config
    JSON
    Log
    Main
);

use Kernel::System::VariableCheck qw(:all);

=head1 NAME

Kernel::System::ObjectSearch - object search lib

=head1 SYNOPSIS

All object search functions.

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $ObjectSearch = $Kernel::OM->Get('ObjectSearch');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get object search backend from config
    my $ObjectSearchBackend = $Kernel::OM->Get('Config')->Get('ObjectSearch::Backend');

    # get module name
    my $ObjectSearchModule  = $Kernel::OM->GetModuleFor( $ObjectSearchBackend->{Module} )
        || $ObjectSearchBackend->{Module};

    # require module
    return if ( !$Kernel::OM->Get('Main')->Require( $ObjectSearchModule ) );

    # create backend object
    $Self->{Backend} = $ObjectSearchModule->new( %{ $Self } );

    # set object search debug
    $Self->{Debug} = $Kernel::OM->Get('Config')->Get('ObjectSearch::Debug') || 0;

    return $Self;
}

=item Search()

search for objects

    my %Result = $ObjectSearch->Search(
        ObjectType => 'Ticket',             # registered object type of the search backend
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
            Field => '...',                             # see list of filterable fields
            Direction => 'ascending' || 'descending'    # optional
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

    # check needed stuff
    for my $Needed ( qw(ObjectType UserID) ) {
        if ( !$Param{ $Needed } ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!",
                );
            }
            return;
        }
    }

    # FIXME: Should be set, but not all functions provide the UserType
    $Param{UserType} //= 'Agent';

    # get normalized object type
    my $ObjectType = $Self->{Backend}->NormalizedObjectType(
        ObjectType => $Param{ObjectType},
    );
    if ( !$ObjectType ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Invalid ObjectType!",
            );
        }
        return;
    }

    # set defaults for undefined parameter
    if ( !defined( $Param{Result} ) ) {
        $Param{Result} = 'HASH';
    }
    if ( !defined( $Param{Search} ) ) {
        $Param{Search} = {};
    }
    if ( !defined( $Param{Sort} ) ) {
        $Param{Sort} = [];
    }
    if ( !defined( $Param{Limit} ) ) {
        $Param{Limit} = 0;
    }
    if ( !defined( $Param{CacheTTL} ) ) {
        $Param{CacheTTL} = 60 * 4;
    }
    if ( !defined( $Param{Language} ) ) {
        $Param{Language} = '';
    }

    # prepare result ref map
    my %ResultRefMap = (
        'ARRAY' => 'ARRAY',
        'COUNT' => q{},
        'HASH'  => 'HASH',
    );

    # normalize parameter result to uppercase
    $Param{Result} = uc( $Param{Result} );

    # check parameter
    if ( !defined( $ResultRefMap{ $Param{Result} } ) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Invalid Result!",
            );
        }
        return;
    }
    if ( ref( $Param{Search} ) ne 'HASH' ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Invalid Search!",
            );
        }
        return;
    }
    if ( ref( $Param{Sort} ) ne 'ARRAY' ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Invalid Sort!",
            );
        }
        return;
    }
    if ( $Param{Limit} !~ m/^[0-9]+$/ ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Invalid Limit!",
            );
        }
        return;
    }
    if ( $Param{CacheTTL} !~ m/^[0-9]+$/ ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Invalid CacheTTL!",
            );
        }
        return;
    }
    if ( $Param{UserType} !~ m/^(?:Agent|Customer)$/ ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Invalid UserType!",
            );
        }
        return;
    }

    # prepare cache key data
    my $CacheKeyData = {
        Result   => $Param{Result},
        Search   => $Param{Search},
        Sort     => $Param{Sort},
        Limit    => $Param{Limit},
        Language => $Param{Language},
        UserType => $Param{UserType},
        UserID   => $Param{UserID},
    };

    # prepare cache key
    my $CacheKey = $Kernel::OM->Get('JSON')->Encode(
        Data     => $CacheKeyData,
        SortKeys => 1
    );

    if ( $Self->{Debug} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'debug',
            Message  => 'ObjectSearch CacheKey:'
                . Data::Dumper::Dumper($CacheKeyData)
        );
    }

    # check for existing cache value
    my $CacheData = $Kernel::OM->Get('Cache')->Get(
        Type => 'ObjectSearch_' . $ObjectType,
        Key  => $CacheKey,
    );
    if ( defined( $CacheData ) ) {
        # check result ref of cache data
        if ( ref( $CacheData ) ne $ResultRefMap{ $Param{Result} } ) {
            # delete invalid cache
            $Kernel::OM->Get('Cache')->Delete(
                Type => 'ObjectSearch_' . $ObjectType,
                Key  => $CacheKey,
            );
        }
        else {
            # handle return type of cached result
            if ( ref( $CacheData ) eq 'HASH' ) {
                return %{ $CacheData };
            }
            elsif ( ref( $CacheData ) eq 'ARRAY' ) {
                return @{ $CacheData };
            }
            return $CacheData;
        }
    }

    # let backend process search
    my ( $SearchResult, $IsRelative ) = $Self->{Backend}->Search(
        %Param,
        ObjectType => $ObjectType
    );

    if ( !defined( $SearchResult ) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Got undefined search result!'
            );
        }
        return;
    }

    # check ref of result
    if ( ref( $SearchResult ) ne $ResultRefMap{ $Param{Result} } ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Got invalid ref of search result!'
            );
        }
        return;
    }

    # write cache
    if (
        !$IsRelative
        && $Param{CacheTTL}
    ) {
        $Kernel::OM->Get('Cache')->Set(
            Type  => 'ObjectSearch_' . $ObjectType,
            Key   => $CacheKey,
            Value => $SearchResult,
            TTL   => $Param{CacheTTL},
        );
    }

    # handle return type of result
    if ( ref( $SearchResult ) eq 'HASH' ) {
        return %{ $SearchResult };
    }
    elsif ( ref( $SearchResult ) eq 'ARRAY' ) {
        return @{ $SearchResult };
    }
    return $SearchResult;
}

=item GetSupportedAttributes()

get supported attributes for a given object type

    my $Result = $ObjectSearch->GetSupportedAttributes(
        ObjectType => 'Ticket',             # registered object type of the search backend
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
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed ( qw(ObjectType) ) {
        if ( !$Param{ $Needed } ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!",
                );
            }
            return;
        }
    }

    # get normalized object type
    my $ObjectType = $Self->{Backend}->NormalizedObjectType(
        ObjectType => $Param{ObjectType},
    );
    if ( !$ObjectType ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Invalid ObjectType!",
            );
        }
        return;
    }

    return $Self->{Backend}->GetSupportedAttributes(
        ObjectType => $ObjectType
    );
}

1;

=end Internal:

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
