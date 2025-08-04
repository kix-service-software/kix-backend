# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::Contact;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::Contact - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        ContactID => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','GT','GTE','LT','LTE'],
            ValueType      => 'NUMERIC'
        },
        Contact => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        }
    };
}

sub AttributePrepare {
    my ( $Self, %Param ) = @_;

    # map search attributes to table attributes
    my %AttributeDefinition = (
        ContactID => {
            Column       => 'st.contact_id',
            ConditionDef => {
                ValueType => 'NUMERIC',
                NULLValue => 1
            }
        },
        Contact => {
            Column          => ['tcon.lastname','tcon.firstname'],
            ConditionDef => {
                CaseInsensitive => 1,
                NULLValue       => 1
            }
        },
    );

    # check for needed joins
    my @SQLJoin = ();
    if ( $Param{Attribute} eq 'Contact' ) {
        if ( !$Param{Flags}->{JoinMap}->{TicketContact} ) {
            push( @SQLJoin, 'LEFT OUTER JOIN contact tcon ON tcon.id = st.contact_id' );

            $Param{Flags}->{JoinMap}->{TicketContact} = 1;
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
        if ( $Param{Attribute} eq 'Contact' ) {
            for my $Column ( @{ $Attribute{Column} } ) {
                $Column = 'LOWER(' . $Column . ')';
            }
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
