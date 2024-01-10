# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Contact::Valid;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our @ObjectDependencies = qw(
    Log
);

=head1 NAME

Kernel::System::ObjectSearch::Database::Contact::Valid - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item GetSupportedAttributes()

defines the list of attributes this module is supporting

    my $AttributeList = $Object->GetSupportedAttributes();

    $Result = {
        Property => {
            IsSortable     => 0|1,
            IsSearchable => 0|1,
            Operators     => []
        },
    };

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

=item Search()

run this module and return the SQL extensions

    my $Result = $Object->Search(
        Search => {}
    );

    $Result = {
        Where   => [ ],
    };

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    my @SQLWhere;
    my @SQLJoin;

    # check params
    return if !$Self->_CheckSearchParams(%Param);

    # map search attributes to table attributes
    my %AttributeMapping = (
        Valid   => 'v.name',
        ValidID => 'c.valid_id',
    );

    if (
        $Param{Search}->{Field} eq 'Valid'
        && !$Param{Flags}->{ValidJoin}
    ) {
        push( @SQLJoin, 'INNER JOIN valid v ON c.valid_id = v.id' );
        $Param{Flags}->{ValidJoin} = 1;
    }

    my $Condition = $Self->_GetCondition(
        Operator      => $Param{Search}->{Operator},
        Column        => $AttributeMapping{$Param{Search}->{Field}},
        Value         => $Param{Search}->{Value}
    );

    return if ( !$Condition );



    return {
        Join  => \@SQLJoin,
        Where => [ $Condition ]
    };
}

=item Sort()

run this module and return the SQL extensions

    my $Result = $Object->Sort(
        Attribute => '...'      # required
    );

    $Result = {
        Select   => [ ],          # optional
        OrderBy  => [ ]           # optional
    };

=cut

sub Sort {
    my ( $Self, %Param ) = @_;

    # check params
    return if !$Self->_CheckSortParams(%Param);

    # map search attributes to table attributes
    my %AttributeMapping = (
        Valid   => 'v.name',
        ValidID => 'c.valid_id',
    );

    my %Join;
    if (
        $Param{Attribute} eq 'Valid'
        && !$Param{Flags}->{ValidJoin}
    ) {
        $Join{Join} = ['INNER JOIN valid v ON c.valid_id = v.id'];
        $Param{Flags}->{ValidJoin} = 1;
    }

    return {
        Select  => [$AttributeMapping{$Param{Attribute}}],
        OrderBy => [$AttributeMapping{$Param{Attribute}}],
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
