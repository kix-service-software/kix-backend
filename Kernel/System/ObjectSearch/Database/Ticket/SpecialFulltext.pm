# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::SpecialFulltext;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::SpecialFulltext - contains special attribute fulltext module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        OwnerFulltext => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        ResponsibleFulltext => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        OrganisationFulltext => {
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

    my %AttributeMapping = (
        OwnerFulltext => {
            Fields => [
                'Owner',
                'OwnerName'
            ]
        },
        ResponsibleFulltext => {
            Fields => [
                'Responsible',
                'ResponsibleName'
            ]
        },
        OrganisationFulltext => {
            Fields => [
                'Organisation',
                'OrganisationNumber'
            ]
        }
    );

    # OR-combine relevant fields with requested operator and value
    for my $Field ( @{$AttributeMapping{$Param{Search}->{Field}}->{Fields}} ) {
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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
