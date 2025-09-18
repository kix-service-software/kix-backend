# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::Organisation;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::Organisation - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        OrganisationID => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EMPTY','EQ','NE','IN','!IN','GT','GTE','LT','LTE'],
            ValueType      => 'NUMERIC'
        },
        Organisation => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EMPTY','EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        OrganisationNumber => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EMPTY','EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        }
    };
}

sub AttributePrepare {
    my ( $Self, %Param ) = @_;

    # map search attributes to table attributes
    my %AttributeDefinition = (
        OrganisationID     => {
            Column       => 'st.organisation_id',
            ConditionDef => {
                ValueType => 'NUMERIC',
                NULLValue => 1
            }
        },
        Organisation       => {
            Column       => 'torg.name',
            ConditionDef => {
                CaseInsensitive => 1,
                NULLValue       => 1
            }
        },
        OrganisationNumber => {
            Column       => 'torg.number',
            ConditionDef => {
                CaseInsensitive => 1,
                NULLValue       => 1
            }
        }
    );

    # check for needed joins
    my @SQLJoin = ();
    if (
        $Param{Attribute} eq 'Organisation'
        || $Param{Attribute} eq 'OrganisationNumber'
    ) {
        if ( !$Param{Flags}->{JoinMap}->{TicketOrganisation} ) {
            push( @SQLJoin, 'LEFT OUTER JOIN organisation torg ON torg.id = st.organisation_id' );

            $Param{Flags}->{JoinMap}->{TicketOrganisation} = 1;
        }
    }

    my %Attribute = (
        Column => $AttributeDefinition{ $Param{Attribute} }->{Column},
        SQLDef => {
            Join => \@SQLJoin,
        }
    );
    if ( $Param{PrepareType} eq 'Condition' ) {
        $Attribute{ConditionDef} = $AttributeDefinition{ $Param{Attribute} }->{ConditionDef};
    }
    elsif ( $Param{PrepareType} eq 'Sort' ) {
        if (
            $Param{Attribute} eq 'Organisation'
            || $Param{Attribute} eq 'OrganisationNumber'
        ) {
            $Attribute{Column} = 'LOWER(' . $Attribute{Column} . ')';
        }
    }

    return \%Attribute;
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
