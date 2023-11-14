# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
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
    my $ObjectSearchModule  = $Kernel::OM->GetModuleFor( $ObjectSearchBackend );

    # require module
    return if ( !$Kernel::OM->Get('Main')->Require( $ObjectSearchModule ) );

    # create backend object
    $Self->{Backend} = $ObjectSearchModule->new( %{ $Self } );

    return $Self;
}

=item Search()

### TODO ###

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed ( qw(ObjectType UserType UserID) ) {
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

    # prepare result ref map
    my %ResultRefMap = (
        'ARRAY' => 'ARRAY',
        'COUNT' => '',
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

    # prepare cache key
    my $CacheKey = $Kernel::OM->Get('JSON')->Encode(
        Data     => {
            Result   => $Param{Result},
            Search   => $Param{Search},
            Sort     => $Param{Sort},
            Limit    => $Param{Limit},
            UserType => $Param{UserType},
            UserID   => $Param{UserID},
        },
        SortKeys => 1
    );

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
    my $SearchResult = $Self->{Backend}->Search(
        %Param,
        ObjectType => $ObjectType,
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
    if ( $Param{CacheTTL} ) {
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

### TODO ###

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

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

sub _GetSearchBackend {
    my ( $Self, %Param ) = @_;

    my $ObjectTypes = $Kernel::OM->Get('Config')->Get('ObjectSearch::Types');

    if ( !IsHashRefWithData($ObjectTypes) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'No enabled ObjectTypes for the search!'
        );
        return;
    }
    if ( !$Param{ObjectType} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'No object type given!'
        );
        return;
    }

    my $Backend = $Kernel::OM->Get('Config')->Get('ObjectSearch::Backend');

    # if the backend require failed we will exit
    if ( !$Kernel::OM->Get('Main')->Require($Backend) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to require search backend!",
        );
        return;
    }

    for my $ObjectType ( sort keys %{$ObjectTypes} ) {

        next if lc($Param{ObjectType}) ne lc($ObjectType);
        next if !$ObjectTypes->{$ObjectType};

        return 1 if IsHashRefWithData($Self->{SearchBackend})
            && $Self->{SearchBackend}->{$ObjectType};


        my $Backend = $Backend->new(
            %{$Self},
            ObjectType => $ObjectType
        );

        # if the backend constructor failed we will exit
        if ( ref $Backend ne $Backend ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to create search backend object!",
            );
            return;
        }

        $Self->{SearchBackend}->{$ObjectType} = $Backend;

        last;
    }

    return 1;
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
