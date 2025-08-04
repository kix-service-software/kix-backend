# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::Priority;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::Priority - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        PriorityID => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','GT','GTE','LT','LTE'],
            ValueType      => 'NUMERIC'
        },
        Priority => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        }
    };
}

sub AttributePrepare {
    my ( $Self, %Param ) = @_;

    # init Definition
    my %AttributeDefinition = (
        PriorityID => {
            Column       => 'st.ticket_priority_id',
            ConditionDef => {
                ValueType => 'NUMERIC'
            }
        },
        Priority   => {
            Column       => 'tp.name',
            ConditionDef => {}
        }
    );

    # check for needed joins
    my $TableAliasTLP = 'tlp' . ( $Param{Flags}->{JoinMap}->{TranslationTicketPriority} // '' );
    my $TableAliasTL  = 'tl' . ( $Param{Flags}->{JoinMap}->{TranslationTicketPriority} // '' );
    my @SQLJoin = ();
    if ( $Param{Attribute} eq 'Priority' ) {
        if ( !$Param{Flags}->{JoinMap}->{TicketPriority} ) {
            push( @SQLJoin, 'INNER JOIN ticket_priority tp ON tp.id = st.ticket_priority_id' );

            $Param{Flags}->{JoinMap}->{TicketPriority} = 1;
        }

        if ( $Param{PrepareType} eq 'Sort' ) {
            if ( !defined( $Param{Flags}->{JoinMap}->{TranslationTicketPriority} ) ) {
                my $Count = $Param{Flags}->{TranslationJoinCounter}++;
                $TableAliasTLP .= $Count;
                $TableAliasTL  .= $Count;

                push( @SQLJoin, "LEFT OUTER JOIN translation_pattern $TableAliasTLP ON $TableAliasTLP.value = tp.name" );
                push( @SQLJoin, "LEFT OUTER JOIN translation_language $TableAliasTL ON $TableAliasTL.pattern_id = $TableAliasTLP.id AND $TableAliasTL.language = '$Param{Language}'" );

                $Param{Flags}->{JoinMap}->{TranslationTicketPriority} = $Count;
            }
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
        if ( $Param{Attribute} eq 'Priority' ) {
            $Attribute{Column} = 'LOWER(COALESCE(' . $TableAliasTL . '.value, tp.name))';
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
