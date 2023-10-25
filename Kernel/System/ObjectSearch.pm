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
    Config
    Main
    Log
);

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

    return $Self;
}

=item Search()

To find tickets in your system.

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
    => see manual of REST-API (look for "Search Tickets")

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

    $Self->_GetSearchBackend(
        %Param
    );

    # execute ticket search in backend
    return $Self->{SearchBackendObject}->Search(
        %Param,
    );
}

sub GetSupportedSortList {
    my ( $Self, %Param ) = @_;

    my @List;

    if (
        $Self->_GetSearchBackend(
            %Param
        )
    ) {
        @List = $Self->{SearchBackendObject}->GetSupportedSortList();
    }

    return @List;
}

sub _GetSearchBackend {
    my ( $Self, %Param ) = @_;

    if (
        !defined $Param{ObjectType}
        || !$Param{ObjectType}
    ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need ObjectType!'
        );
        return;
    }

    return 1 if $Self->{SearchBackendObject};

    my $Backend = $Kernel::OM->Get('Config')->Get('Object::SearchBackend');

    # if the backend require failed we will exit
    if ( !$Kernel::OM->Get('Main')->Require($Backend) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to require search backend!",
        );
        return;
    }
    my $BackendObject = $Backend->new(
        %{$Self},
        ObjectType => $Param{ObjectType}
    );

    # if the backend constructor failed we will exit
    if ( ref $BackendObject ne $Backend ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to create search backend object!",
        );
        return;
    }

    $Self->{SearchBackendObject} = $BackendObject;

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
