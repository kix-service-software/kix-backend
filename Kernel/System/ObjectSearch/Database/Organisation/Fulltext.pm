# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Organisation::Fulltext;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Organisation::Fulltext - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        Fulltext => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        }
    };
}

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    # init search parameter for fulltext search
    my %Search = (
        OR => []
    );

    # OR-combine relevant fields with requested operator and value
    for my $Field (
        qw(
            Name Number Street
            Zip City Country Url
        )
    ) {
        push (
            @{ $Search{OR} },
            {
                Field    => $Field,
                Operator => $Param{Search}->{Operator},
                Value    => $Param{Search}->{Value}
            }
        );
    }

    # return search def
    return {
        Search => \%Search,
    };
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
