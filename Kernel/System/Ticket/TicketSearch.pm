# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::TicketSearch;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::Ticket::TicketSearch - ticket search lib

=head1 SYNOPSIS

All ticket search functions.

=over 4

=cut

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
    => see manual of REST-API (look for "Search Tickets")

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

    if ( !$Self->{SearchBackendObject} ) {
        my $Backend = $Kernel::OM->Get('Config')->Get('Ticket::SearchBackend');

        # if the backend require failed we will exit
        if ( !$Kernel::OM->Get('Main')->Require($Backend) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to require search backend!",
            );
            return;
        }
        my $BackendObject = $Backend->new( %{$Self} );

        # if the backend constructor failed we will exit
        if ( ref $BackendObject ne $Backend ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to create search backend object!",
            );
            return;
        }

        $Self->{SearchBackendObject} = $BackendObject;
    }

    # execute ticket search in backend
    return $Self->{SearchBackendObject}->TicketSearch(
        %Param,
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
