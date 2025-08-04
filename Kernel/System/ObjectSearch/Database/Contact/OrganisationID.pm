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
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN'],
            ValueType      => 'NUMERIC'
        },
        OrganisationIDs => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN'],
            ValueType      => 'NUMERIC'
        },
        Organisation => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        OrganisationNumber => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        PrimaryOrganisationID => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN'],
            ValueType      => 'NUMERIC'
        },
        PrimaryOrganisation => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        PrimaryOrganisationNumber => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        }
    };
}

sub AttributePrepare {
    my ( $Self, %Param ) = @_;

    my %JoinData = $Self->_JoinGet(
        Flags     => $Param{Flags},
        Attribute => $Param{Attribute}
    );

    # map search attributes to table attributes
    my %AttributeDefinition = (
        OrganisationID => {
            Column    => "$JoinData{OCAlias}.org_id",
            ConditionDef => {
                ValueType => 'NUMERIC'
            }
        },
        OrganisationIDs => {
            Column    => "$JoinData{OCAlias}.org_id",
                ConditionDef => {
                ValueType => 'NUMERIC'
            }
        },
        Organisation => {
            Column          =>"$JoinData{OAlias}.name",
            ConditionDef => {
                ValueType       => 'STRING',
                CaseInsensitive => 1
            }
        },
        OrganisationNumber => {
            Column          => "$JoinData{OAlias}.number",
            ConditionDef => {
                ValueType       => 'STRING',
                CaseInsensitive => 1
            }
        },
        PrimaryOrganisationID => {
            Column    => "$JoinData{POCAlias}.org_id",
                ConditionDef => {
                ValueType => 'NUMERIC'
            }
        },
        PrimaryOrganisation => {
            Column          => "$JoinData{POAlias}.name",
            ConditionDef => {
                ValueType       => 'STRING',
                CaseInsensitive => 1
            }
        },
        PrimaryOrganisationNumber => {
            Column          => "$JoinData{POAlias}.number",
            ConditionDef => {
                ValueType       => 'STRING',
                CaseInsensitive => 1
            }
        }
    );

    my %Attribute = (
        Column => $AttributeDefinition{ $Param{Attribute} }->{Column},
        SQLDef => {
            Join => $JoinData{Join},
        }
    );
    if ( $Param{PrepareType} eq 'Condition' ) {
        $Attribute{ConditionDef} = $AttributeDefinition{ $Param{Attribute} }->{ConditionDef};
    }

    return \%Attribute;
}

sub _JoinGet {
    my ( $Self, %Param ) = @_;

    my @SQLJoin;

    my $OrgaContactAlias = $Param{Flags}->{JoinMap}->{OrganisationContactJoin} // 'co';
    if (
        !$Param{Flags}->{JoinMap}->{OrganisationContactJoin}
        && $Param{Attribute} !~ m/^Primary/sm
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
        && $Param{Attribute} =~ m/^Primary/sm
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
        && $Param{Attribute} !~ m/ID(?:s|)$/sm
        && $Param{Attribute} !~ m/^Primary/sm
    ) {
        push(
            @SQLJoin,
            "LEFT JOIN organisation $OrgaAlias ON $OrgaContactAlias.org_id = $OrgaAlias.id"
        );
        $Param{Flags}->{JoinMap}->{OrganisationJoin} = $OrgaAlias;
    }

    my $POrgaAlias = $Param{Flags}->{JoinMap}->{POrganisationJoin} // 'po';
    if (
        !$Param{Flags}->{JoinMap}->{POrganisationJoin}
        && $Param{Attribute} !~ m/ID(?:s|)$/sm
        && $Param{Attribute} =~ m/^Primary/sm
    ) {
        push(
            @SQLJoin,
            "LEFT JOIN organisation $POrgaAlias ON $POrgaContactAlias.org_id = $POrgaAlias.id"
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
