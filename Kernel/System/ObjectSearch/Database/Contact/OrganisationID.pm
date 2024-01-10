# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Contact::OrganisationID;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our @ObjectDependencies = qw(
    Log
);

=head1 NAME

Kernel::System::ObjectSearch::Database::Contact::OrganisationID - attribute module for database object search

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
        OrganisationID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN'],
            ValueType    => 'NUMERIC'
        },
        OrganisationIDs => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN'],
            ValueType    => 'NUMERIC'
        },
        Organisation => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        OrganisationNumber => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        PrimaryOrganisationID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN'],
            ValueType    => 'NUMERIC'
        },
        PrimaryOrganisation => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        PrimaryOrganisationNumber => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
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
    my @SQLJoin;

    # check params
    return if !$Self->_CheckSearchParams(%Param);

    my $TableAlias = $Param{Flags}->{OrganisationJoin}->{$Param{Search}->{Field}} // 'cor';
    if ( !$Param{Flags}->{OrganisationJoin}->{$Param{Search}->{Field}} ) {
        my $Count = $Param{Flags}->{OrganisationJoinCounter}++;
        $TableAlias .= $Count;

        push(
            @SQLJoin,
            "LEFT JOIN contact_organisation $TableAlias ON $TableAlias.contact_id = c.id"
        );

        if ( $Param{Search}->{Field} =~ m/^Primary/sm ) {
            push(
                @SQLJoin,
                "AND $TableAlias.is_primary = 1"
            );
        }

        if ( $Param{Search}->{Field} !~ m/ID(?:s|)$/sm ) {
            push(
                @SQLJoin,
                "INNER JOIN organisation o ON $TableAlias.org_id = o.id"
            );
        }
        $Param{Flags}->{OrganisationJoin}->{$Param{Search}->{Field}} = $TableAlias;
    }

    # map search attributes to table attributes
    my %AttributeMapping = (
        OrganisationID            => "$TableAlias.org_id",
        OrganisationIDs           => "$TableAlias.org_id",
        Organisation              => 'o.name',
        OrganisationNumber        => 'o.number',
        PrimaryOrganisationID     => "$TableAlias.org_id",
        PrimaryOrganisation       => 'o.name',
        PrimaryOrganisationNumber => 'o.number'
    );

    # map search attributes to type attributes
    my %AttributeTypeMapping = (
        OrganisationID            => 'NUMERIC',
        OrganisationIDs           => 'NUMERIC',
        Organisation              => 'STRING',
        OrganisationNumber        => 'STRING',
        PrimaryOrganisationID     => 'NUMERIC',
        PrimaryOrganisation       => 'STRING',
        PrimaryOrganisationNumber => 'STRING'
    );

    my $Condition = $Self->_GetCondition(
        Operator  => $Param{Search}->{Operator},
        Column    => $AttributeMapping{$Param{Search}->{Field}},
        Value     => $Param{Search}->{Value},
        ValueType => $AttributeTypeMapping{$Param{Search}->{Field}}
    );



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
        OrderBy => [ ]           # optional
    };

=cut

sub Sort {
    my ( $Self, %Param ) = @_;

    # check params
    return if !$Self->_CheckSortParams( %Param );

    my @SQLJoin    = ();
    my $TableAlias = $Param{Flags}->{OrganisationJoin}->{ $Param{Attribute} } || 'cor';

    if ( !$Param{Flags}->{OrganisationJoin}->{ $Param{Attribute} } ) {
        my $Count = $Param{Flags}->{OrganisationJoinCounter}++;
        $TableAlias .= $Count;

        push(
            @SQLJoin,
            "LEFT JOIN contact_organisation $TableAlias ON $TableAlias.contact_id = c.id"
        );

        if ( $Param{Attribute} =~ m/^Primary/sm ) {
            push(
                @SQLJoin,
                "AND $TableAlias.is_primary = 1"
            );
        }

        if ( $Param{Attribute} !~ m/ID(?:s|)$/sm ) {
            push(
                @SQLJoin,
                "INNER JOIN organisation o ON $TableAlias.org_id = o.id"
            );
        }
        $Param{Flags}->{OrganisationJoin}->{ $Param{Attribute} } = $TableAlias;
    }

    # map search attributes to table attributes
    my %AttributeMapping = (
        OrganisationID            => "$TableAlias.org_id",
        OrganisationIDs           => "$TableAlias.org_id",
        Organisation              => 'o.name',
        OrganisationNumber        => 'o.number',
        PrimaryOrganisationID     => "$TableAlias.org_id",
        PrimaryOrganisation       => 'o.name',
        PrimaryOrganisationNumber => 'o.number',
    );

    return {
        Select  => [ $AttributeMapping{ $Param{Attribute} } ],
        OrderBy => [ $AttributeMapping{ $Param{Attribute} } ],
        Join    => \@SQLJoin
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
