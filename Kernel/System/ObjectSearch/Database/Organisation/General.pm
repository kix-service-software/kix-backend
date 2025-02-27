# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ObjectSearch::Database::Organisation::General;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Organisation::General - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        Name => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Number => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Street => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        City => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Zip => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Country => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Url => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Comment => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        }
    };
}

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    # init mapping
    my %AttributeMapping = (
        Name    => {
            Column    => 'o.name'
        },
        Number  => {
            Column    => 'o.number'
        },
        Street  => {
            Column    => 'o.street',
            NULLValue => 1
        },
        City    => {
            Column    => 'o.city',
            NULLValue => 1
        },
        Zip     => {
            Column    => 'o.zip',
            NULLValue => 1
        },
        Country => {
            Column    => 'o.country',
            NULLValue => 1
        },
        Url     => {
            Column    => 'o.url',
            NULLValue => 1
        },
        Comment => {
            Column    => 'o.comments',
            NULLValue => 1
        }
    );

    # prepare condition
    my $Condition = $Self->_GetCondition(
        Operator        => $Param{Search}->{Operator},
        Column          => $AttributeMapping{ $Param{Search}->{Field} }->{Column},
        NULLValue       => $AttributeMapping{ $Param{Search}->{Field} }->{NULLValue},
        Value           => $Param{Search}->{Value},
        CaseInsensitive => 1,
        Silent          => $Param{Silent}
    );
    return if ( !$Condition );

    # return search def
    return {
        Where => [ $Condition ]
    };
}

sub Sort {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSortParams( %Param ) );

    # init mapping
    my %AttributeMapping = (
        Name    => {
            Select  => ['o.name'],
            OrderBy => ['LOWER(o.name)']
        },
        Number  => {
            Select  => ['o.number'],
            OrderBy => ['LOWER(o.number)']
        },
        Street  => {
            Select  => ['LOWER(COALESCE(o.street,\'\')) AS SortStreet'],
            OrderBy => ['SortStreet']
        },
        City    => {
            Select  => ['LOWER(COALESCE(o.city,\'\')) AS SortCity'],
            OrderBy => ['SortCity']
        },
        Zip     => {
            Select  => ['LOWER(COALESCE(o.zip,\'\')) AS SortZip'],
            OrderBy => ['SortZip']
        },
        Country => {
            Select  => ['LOWER(COALESCE(o.country,\'\')) AS SortCountry'],
            OrderBy => ['SortCountry']
        },
        Url     => {
            Select  => ['LOWER(COALESCE(o.url,\'\')) AS SortUrl'],
            OrderBy => ['SortUrl']
        },
        Comment => {
            Select  => ['LOWER(COALESCE(o.comments,\'\')) AS SortComment'],
            OrderBy => ['SortComment']
        }
    );

    # return sort def
    return {
        Select  => $AttributeMapping{ $Param{Attribute} }->{Select},
        OrderBy => $AttributeMapping{ $Param{Attribute} }->{OrderBy}
    };
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
