# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::FAQArticle::Valid;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::FAQArticle::Valid - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        Valid => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN']
        },
        ValidID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN'],
            ValueType    => 'NUMERIC'
        }
    };
}

sub Search {
    my ( $Self, %Param ) = @_;

    my @SQLJoin;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    # map search attributes to table attributes
    my %AttributeMapping = (
        Valid   => 'v.name',
        ValidID => 'f.valid_id',
    );

    if (
        $Param{Search}->{Field} eq 'Valid'
        && !$Param{Flags}->{ValidJoin}
    ) {
        push( @SQLJoin, 'INNER JOIN valid v ON f.valid_id = v.id' );
        $Param{Flags}->{ValidJoin} = 1;
    }

    my $ValueType = q{};
    if ( $Param{Search}->{Field} eq 'ValidID' ) {
        $ValueType = 'NUMERIC';
    }
    my $Condition = $Self->_GetCondition(
        Operator      => $Param{Search}->{Operator},
        Column        => $AttributeMapping{$Param{Search}->{Field}},
        Value         => $Param{Search}->{Value},
        ValueType     => $ValueType
    );

    return if ( !$Condition );

    return {
        Join  => \@SQLJoin,
        Where => [ $Condition ]
    };
}

sub Sort {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSortParams( %Param ) );

    # map search attributes to table attributes
    my %AttributeMapping = (
        Valid   => 'v.name',
        ValidID => 'f.valid_id',
    );

    my %Join;
    if (
        $Param{Attribute} eq 'Valid'
        && !$Param{Flags}->{ValidJoin}
    ) {
        $Join{Join} = ['INNER JOIN valid v ON f.valid_id = v.id'];
        $Param{Flags}->{ValidJoin} = 1;
    }

    return {
        Select => [
            $AttributeMapping{$Param{Attribute}}
        ],
        OrderBy => [
            $AttributeMapping{$Param{Attribute}}
        ],
        %Join
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
