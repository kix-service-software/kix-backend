# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
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

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        OrganisationID => {
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN'],
            ValueType      => 'NUMERIC'
        },
        OrganisationIDs => {
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN'],
            ValueType      => 'NUMERIC'
        },
        Organisation => {
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        OrganisationNumber => {
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        PrimaryOrganisationID => {
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN'],
            ValueType      => 'NUMERIC'
        },
        PrimaryOrganisation => {
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        PrimaryOrganisationNumber => {
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        }
    };
}

sub Sort {
    my ( $Self, %Param ) = @_;

    # check params
    return if !$Self->_CheckSortParams( %Param );

    my %JoinData = $Self->_JoinGet(
        %Param
    );

    # map search attributes to table attributes
    my %AttributeDefinition = (
        OrganisationID            => "$JoinData{OCAlias}.org_id",
        OrganisationIDs           => "$JoinData{OCAlias}.org_id",
        Organisation              => "$JoinData{OAlias}.name",
        OrganisationNumber        => "$JoinData{OAlias}.number",
        PrimaryOrganisationID     => "$JoinData{POCAlias}.org_id",
        PrimaryOrganisation       => "$JoinData{POAlias}.name",
        PrimaryOrganisationNumber => "$JoinData{POAlias}.number",
    );

    return {
        Select  => [ $AttributeDefinition{ $Param{Attribute} } ],
        OrderBy => [ $AttributeDefinition{ $Param{Attribute} } ],
        Join    => $JoinData{Join}
    };
}

sub AttributePrepare {
    my ( $Self, %Param ) = @_;

    my %JoinData = $Self->_JoinGet(
        %Param
    );

    # map search attributes to table attributes
    my %Attributes = (
        OrganisationID => {
            Column    => "$JoinData{OCAlias}.org_id",
            ValueType => 'NUMERIC'
        },
        OrganisationIDs => {
            Column    => "$JoinData{OCAlias}.org_id",
            ValueType => 'NUMERIC'
        },
        Organisation => {
            Column          =>"$JoinData{OAlias}.name",
            ValueType       => 'STRING',
            CaseInsensitive => 1
        },
        OrganisationNumber => {
            Column          => "$JoinData{OAlias}.number",
            ValueType       => 'STRING',
            CaseInsensitive => 1
        },
        PrimaryOrganisationID => {
            Column    => "$JoinData{POCAlias}.org_id",
            ValueType => 'NUMERIC'
        },
        PrimaryOrganisation => {
            Column          => "$JoinData{POAlias}.name",
            ValueType       => 'STRING',
            CaseInsensitive => 1
        },
        PrimaryOrganisationNumber => {
            Column          => "$JoinData{POAlias}.number",
            ValueType       => 'STRING',
            CaseInsensitive => 1
        }
    );

    return {
        ConditionDef => $Attributes{ $Param{Search}->{Field} },
        SQLDef       => {
            Join => $JoinData{Join},
        }
    };
}

sub _JoinGet {
    my ( $Self, %Param ) = @_;

    my $Attribute = $Param{Search}->{Field} || $Param{Attribute};
    my @SQLJoin;

    my $OrgaContactAlias = $Param{Flags}->{JoinMap}->{OrganisationContactJoin} // 'co';
    if (
        !$Param{Flags}->{JoinMap}->{OrganisationContactJoin}
        && $Attribute !~ m/^Primary/sm
    ) {
        push(
            @SQLJoin,
            "LEFT JOIN contact_organisation $OrgaContactAlias ON $OrgaContactAlias.contact_id = c.id"
        );

        $Param{Flags}->{JoinMap}->{OrganisationContactJoin} = $OrgaContactAlias;
    }

    my $POrgaContactAlias = $Param{Flags}->{JoinMap}->{POrganisationContactJoin} // 'cpo';
    if (
        !$Param{Flags}->{JoinMap}->{POrganisationContactJoin}
        && $Attribute =~ m/^Primary/sm
    ) {
        push(
            @SQLJoin,
            "LEFT JOIN contact_organisation $POrgaContactAlias ON $POrgaContactAlias.contact_id = c.id",
            "AND $POrgaContactAlias.is_primary = 1"
        );

        $Param{Flags}->{JoinMap}->{POrganisationContactJoin} = $POrgaContactAlias;
    }

    my $OrgaAlias = $Param{Flags}->{JoinMap}->{OrganisationJoin} // 'o';
    if (
        !$Param{Flags}->{JoinMap}->{OrganisationJoin}
        && $Attribute !~ m/ID(?:s|)$/sm
        && $Attribute !~ m/^Primary/sm
    ) {
        push(
            @SQLJoin,
            "INNER JOIN organisation $OrgaAlias ON $OrgaContactAlias.org_id = $OrgaAlias.id"
        );
        $Param{Flags}->{JoinMap}->{OrganisationJoin} = $OrgaAlias;
    }

    my $POrgaAlias = $Param{Flags}->{JoinMap}->{POrganisationJoin} // 'po';
    if (
        !$Param{Flags}->{JoinMap}->{POrganisationJoin}
        && $Attribute !~ m/ID(?:s|)$/sm
        && $Attribute =~ m/^Primary/sm
    ) {
        push(
            @SQLJoin,
            "INNER JOIN organisation $POrgaAlias ON $POrgaContactAlias.org_id = $POrgaAlias.id"
        );
        $Param{Flags}->{JoinMap}->{POrganisationJoin} = $POrgaAlias;
    }

    return (
        Join     => \@SQLJoin,
        POAlias  => $POrgaAlias,
        POCAlias => $POrgaContactAlias,
        OCAlias  => $OrgaContactAlias,
        OAlias   => $OrgaAlias
    );
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
