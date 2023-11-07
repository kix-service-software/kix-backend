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

    if (
        !defined $Param{ObjectType}
        || !$Param{ObjectType}
    ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need ObjectType'
        );
        return;
    }

    $Self->_GetSearchBackend(
        %Param
    );

    # execute ticket search in backend
    return $Self->{SearchBackendObject}->{$Param{ObjectType}}->Search(
        %Param,
    );
}

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return if !$Self->_GetSearchBackend(
        %Param
    );

    my %List;
    for my $ObjectType ( sort keys %{$Self->{SearchBackendObject}} ) {
        $List{$ObjectType} = $Self->{SearchBackendObject}->{$ObjectType}->GetSupportedAttributes();
    }

    return \%List;
}

sub _GetSearchBackend {
    my ( $Self, %Param ) = @_;

    my $ObjectTypes = $Kernel::OM->Get('Config')->Get('Object::Types');

    if ( !IsHashRefWithData($ObjectTypes) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'No enabled ObjectTypes for the search!'
        );
        return;
    }

    my $Type = $Param{ObjectType} ? ucfirst $Param{ObjectType} : undef;

    if (
        $Type
        && !$ObjectTypes->{$Type}
    ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Given object type is not allowed!'
        );
        return;
    }

    return 1 if !$Type && IsHashRefWithData($Self->{SearchBackendObject});
    return 1 if $Type && $Self->{SearchBackendObject}->{$Type};

    my $Backend = $Kernel::OM->Get('Config')->Get('Object::SearchBackend');

    # if the backend require failed we will exit
    if ( !$Kernel::OM->Get('Main')->Require($Backend) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to require search backend!",
        );
        return;
    }

    for my $ObjectType ( sort keys %{$ObjectTypes} ) {
        next if !$ObjectTypes->{$ObjectType};
        next if $Type && $ObjectType ne $Type;

        my $BackendObject = $Backend->new(
            %{$Self},
            ObjectType => $ObjectType
        );

        # if the backend constructor failed we will exit
        if ( ref $BackendObject ne $Backend ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to create search backend object!",
            );
            return;
        }

        $Self->{SearchBackendObject}->{$ObjectType} = $BackendObject;

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
